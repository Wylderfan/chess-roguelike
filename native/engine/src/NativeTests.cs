using Chess.Core;
using System;
using System.Linq;
namespace CodingAdventureBot;
public static class NativeTests
{
    static int checks;
    static void Check(bool ok, string label) { checks++; if (!ok) throw new Exception(label); Console.WriteLine("PASS " + label); }
    static long Perft(Board b, int depth)
    {
        if (depth == 0) return 1;
        long count = 0;
        foreach (var move in new MoveGenerator().GenerateMoves(b))
        {
            var before = b.ZobristKey;
            var fen = FenUtility.CurrentFen(b);
            var ability = b.Abilities;
            b.MakeMove(move, true);
            if (b.ZobristKey != Zobrist.CalculateZobristKey(b)) throw new Exception("incremental hash");
            count += Perft(b, depth - 1);
            b.UnmakeMove(move, true);
            if (b.ZobristKey != before || FenUtility.CurrentFen(b) != fen || b.Abilities != ability) throw new Exception("unmake roundtrip");
        }
        return count;
    }
    public static int Run()
    {
        try
        {
            var b = Board.CreateBoard();
            Check(Perft(b,3) == 8902, "start perft 8902 plus every move/hash/unmake roundtrip");
            b = Board.CreateBoard("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
            Check(Perft(b,2) == 2039, "Kiwipete perft 2039 roundtrips");
            b = Board.CreateBoard("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
            Check(Perft(b,3) == 2812, "en passant perft 2812 roundtrips");
            b = Board.CreateBoard("4k3/P7/8/8/8/8/8/4K3 w - - 0 1");
            Check(new MoveGenerator().GenerateMoves(b).ToArray().Count(m => m.IsPromotion) == 4, "all four promotion flags");
            Check(Perft(b,2) > 0, "promotion hash/unmake roundtrips");
            Check(!new Move(8,16,8).IsPromotion && !new Move(8,16,8).IsStandard, "reserved flag 8 is neither promotion nor playable");
            Check(default(AbilityState).Hash == 0, "empty ability state leaves standard hash unchanged");
            b = Board.CreateBoard();
            var standard = b.ZobristKey;
            var moves = new MoveGenerator().GenerateMoves(b).ToArray().Select(m=>m.Value).ToArray();
            b.SetAbilityStateForSetup(new AbilityState(1,2,4,8));
            Check(b.ZobristKey != standard && b.ZobristKey == Zobrist.CalculateZobristKey(b), "nonempty setup state contributes to identity");
            Check(moves.SequenceEqual(new MoveGenerator().GenerateMoves(b).ToArray().Select(m=>m.Value)), "schema state has no active gameplay effect");
            Check(Perft(b,2) == 400, "ability snapshot make/unmake roundtrips");
            var copy = Board.CreateBoard(b);
            Check(copy.Abilities == b.Abilities && copy.ZobristKey == b.ZobristKey, "copy retains state and hash");
            var key = b.ZobristKey;
            var state = b.Abilities;
            b.MakeNullMove();
            Check(b.ZobristKey == Zobrist.CalculateZobristKey(b), "null move hash includes state");
            b.UnmakeNullMove();
            Check(b.ZobristKey == key && b.Abilities == state, "null unmake restores state/hash");
            Check(AbilityRules.AdditionalDestinations(b,0)==0 && AbilityRules.AdditionalThreats(b,0)==0, "extension masks inactive");
            b = Board.CreateBoard("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1");
            var search = new Searcher(b);
            search.StartSearch(50);
            Check(search.BestMoveSoFar.IsNull, "terminal root safe no-move");
            Console.WriteLine($"NATIVE: {checks} checks, 0 failures");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine("FAIL " + ex); return 1; }
    }
}
