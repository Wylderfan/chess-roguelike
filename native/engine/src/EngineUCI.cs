using Chess.Core;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace CodingAdventureBot;

// Input is serialized on the main thread. Position/newgame/quit suppress and
// join previous work before touching its board. Each search owns its token;
// no timer continuation can reach a subsequent search. stdout is UCI only.
public sealed class EngineUCI : IDisposable
{
    Board board = Board.CreateBoard();
    RuleProfile profile = RuleProfile.Standard;
    MoveGenerator Generator() => new MoveGenerator { Profile=profile };
    Task? work;
    CancellationTokenSource? cancellation;
    readonly object outputGate = new();
    int generation;
    public bool QuitRequested { get; private set; }
    static readonly JsonSerializerOptions json = new() { IncludeFields = true };

    void Respond(string text) { lock (outputGate) Console.WriteLine(text); }
    void StopJoin(bool suppress)
    {
        if (suppress) { lock (outputGate) generation++; }
        cancellation?.Cancel();
        work?.GetAwaiter().GetResult();
        cancellation?.Dispose();
        cancellation = null;
        work = null;
    }
    public void ReceiveCommand(string message)
    {
        var words = message.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return;
        try
        {
            switch (words[0])
            {
                case "uci":
                    Respond("id name Knight Chess v0.6 / SebLague V2 f346d2d");
                    Respond("id author Sebastian Lague; Knight Chess integration");
                    Respond("option name RulesProfile type combo default standard var standard var conservative");
                    Respond("uciok"); break;
                case "setoption":
                    StopJoin(true);
                    if(words.Length==5 && words[1]=="name" && words[2]=="RulesProfile" && words[3]=="value") profile=RuleProfile.Parse(words[4]);
                    else throw new ArgumentException("Unsupported option");
                    break;
                case "isready": Respond("readyok"); break;
                case "stop": StopJoin(false); break;
                case "quit": StopJoin(true); QuitRequested = true; break;
                case "ucinewgame": StopJoin(true); board = Board.CreateBoard(); break;
                case "position": SetPosition(words); break;
                case "go": Start(words); break;
                case "knight":
                    StopJoin(true);
                    if (words.Length > 1 && words[1] == "profile") Respond("profile " + JsonSerializer.Serialize(profile));
                    else if (words.Length > 1 && words[1] == "snapshot") Snapshot();
                    else if (words.Length > 2 && words[1] == "divide") Divide(Math.Clamp(int.Parse(words[2]),1,4));
                    break;
            }
        }
        catch (Exception ex) { Respond("info string error " + ex.GetType().Name + ": " + ex.Message.Replace('\n', ' ')); }
    }
    void SetPosition(string[] words)
    {
        StopJoin(true);
        int split = Array.IndexOf(words, "moves");
        int end = split < 0 ? words.Length : split;
        Board next = words.Length > 1 && words[1] == "startpos" ? Board.CreateBoard()
            : words.Length >= 8 && words[1] == "fen" ? Board.CreateBoard(string.Join(" ", words.Skip(2).Take(end - 2)))
            : throw new ArgumentException("position requires startpos or six-field fen");
        PositionLimits.ValidatePlayableTurn(next);
        if (split >= 0)
            foreach (string text in words.Skip(split + 1))
            {
                var candidates = Generator().GenerateMoves(next).ToArray();
                Move m = candidates.FirstOrDefault(m => Name(m) == text);
                if (m.IsNull) throw new ArgumentException("Illegal position move " + text);
                next.MakeMove(m);
            }
        board = next; // Commit only after entire command validated.
    }
    static int Number(string[] words, string key, int fallback)
    {
        int index = Array.IndexOf(words, key);
        return index >= 0 && index + 1 < words.Length && int.TryParse(words[index + 1], out int n) ? n : fallback;
    }
    void Start(string[] words)
    {
        StopJoin(true);
        int time = Number(words, "movetime", -1);
        int depth = Math.Clamp(Number(words, "depth", 64), 1, 64);
        if (time < 0)
        {
            int remaining = Number(words, board.IsWhiteToMove ? "wtime" : "btime", 30000);
            int increment = Number(words, board.IsWhiteToMove ? "winc" : "binc", 0);
            time = Math.Min(Math.Max(10, remaining / Math.Max(1, Number(words, "movestogo", 35)) + increment / 2), Math.Max(10, remaining / 3));
        }
        time = Math.Clamp(time, 1, 60000);
        cancellation = new CancellationTokenSource();
        var token = cancellation.Token;
        int id = generation;
        // Board is not mutated by input until StopJoin. No engine thread sees UI state.
        work = Task.Run(() =>
        {
            var watch = Stopwatch.StartNew();
            try
            {
                var legal = Generator().GenerateMoves(board).ToArray();
                Move chosen = Move.NullMove;
                if (legal.Length > 0)
                {
                    var search = new Searcher(board,profile);
                    search.StartSearch(time, token, depth);
                    chosen = search.BestMoveSoFar;
                    if (!legal.Any(m => Move.SameMove(m, chosen))) throw new InvalidOperationException("Search returned illegal move");
                    lock (outputGate)
                        if (id == generation)
                            Console.WriteLine($"info string profile {profile.Name} lmr {search.Reductions} tt_probes {search.CacheProbes} tt_stores {search.CacheStores} material_evals {search.MaterialEvaluations} positional_evals {search.PositionalEvaluations}");
                    lock (outputGate)
                        if (id == generation)
                            Console.WriteLine($"info depth {search.CurrentDepth} nodes {search.Nodes} time {watch.ElapsedMilliseconds} score cp {search.BestEvalSoFar}");
                }
                lock (outputGate)
                    if (id == generation) Console.WriteLine("bestmove " + (chosen.IsNull ? "0000" : Name(chosen)));
            }
            catch (Exception ex)
            {
                lock (outputGate) if (id == generation)
                {
                    Console.WriteLine("info string error search: " + ex.Message.Replace('\n', ' '));
                    Console.WriteLine("bestmove 0000");
                }
            }
        });
    }
    public static string Name(Move m) => MoveUtility.GetMoveNameUCI(m).Replace("=", "").ToLowerInvariant();
    string[] Legal(Board b) => Generator().GenerateMoves(b).ToArray().Where(m => Piece.PieceType(b.Square[m.TargetSquare]) != Piece.King).Select(Name).OrderBy(x => x, StringComparer.Ordinal).ToArray();
    void Snapshot()
    {
        var fen = FenUtility.CurrentFen(board).Split(' ');
        fen[1] = board.IsWhiteToMove ? "b" : "w";
        fen[3] = "-"; // Off-turn preview cannot inherit an en-passant opportunity.
        var other = Board.CreateBoard(string.Join(" ", fen));
        var threats = new Dictionary<string, string[]>();
        for (int s = 0; s < 64; s++) if (board.Square[s] != 0)
        {
            ulong mask = AbilityRules.ThreatMask(board, s);
            var squares = new List<string>();
            for (int t = 0; t < 64; t++) if (((mask >> t) & 1) != 0) squares.Add(BoardHelper.SquareNameFromIndex(t));
            threats[BoardHelper.SquareNameFromIndex(s)] = squares.OrderBy(x => x, StringComparer.Ordinal).ToArray();
        }
        Respond("knight " + JsonSerializer.Serialize(new {
            profile = profile.Name, schema = AbilityState.SchemaVersion, legal = Legal(board), other_legal = Legal(other), threats,
            hash = board.ZobristKey.ToString("x16"), history_count = board.RepetitionPositionHistory.Count,
            repetition_count = board.RepetitionPositionHistory.Count(k => k == board.ZobristKey),
            fen = FenUtility.CurrentFen(board), abilities_empty = board.Abilities.IsEmpty
        }, json));
    }
    long Perft(Board b, int depth)
    {
        if(depth==0) return 1;
        long nodes=0;
        foreach(var m in Generator().GenerateMoves(b).ToArray())
        {
            b.MakeMove(m,true);
            try { nodes += Perft(b,depth-1); }
            finally { b.UnmakeMove(m,true); }
        }
        return nodes;
    }
    void Divide(int depth)
    {
        var copy=Board.CreateBoard(board);
        var counts=new SortedDictionary<string,long>();
        foreach(var m in Generator().GenerateMoves(copy).ToArray())
        {
            copy.MakeMove(m,true);
            try { counts[Name(m)]=Perft(copy,depth-1); }
            finally { copy.UnmakeMove(m,true); }
        }
        Respond("divide " + JsonSerializer.Serialize(counts));
    }
    public void Dispose() => StopJoin(true);
}
