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
            bool unsupported=false;
            try { new MoveGenerator().GenerateMoves(b); } catch(ArgumentException){unsupported=true;}
            Check(unsupported,"nonempty unregistered rule state fails closed");
            var stateKey=b.ZobristKey;
            foreach(var value in moves){var m=new Move(value);b.MakeMove(m,true);b.UnmakeMove(m,true);}
            Check(b.ZobristKey==stateKey && b.ZobristKey==Zobrist.CalculateZobristKey(b),"ability snapshot make/unmake roundtrips remain exact");
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

            Check(MoveGenerator.MaxMoves >= 31*27+10, "shared move bound covers any supported army");
            foreach(var fen in new[]{
                "7k/8/8/8/P1P1P3/P1P1P3/P1P1P3/6K1 w - - 0 1",
                "QQQQQQnk/Q4Qpp/2Q3Q1/Q5QQ/3Q3Q/QQ1Q3Q/PPQ4Q/KN1QQQQQ w - - 0 1",
                "qQqQQqnk/qQqQqQpp/QQqQqQqQ/qqqQqQqQ/1QQQqqqq/QqqqQQQQ/PPQqQqqq/KNQqQqQQ w - - 0 1",
                "7k/2P3pp/8/8/QQQQQQQ1/QQQQQQQQ/QQQQQQQQ/KQQQQQQQ w - - 0 1"})
            {
                b=Board.CreateBoard(fen);
                var original=FenUtility.CurrentFen(b); var originalKey=b.ZobristKey;
                Check(Math.Abs(new Evaluation().Evaluate(b))<99000,"extra-army evaluation finite and below mate range");
                Check(Perft(b,2)>0,"extra-army perft + full hash/unmake restoration");
                var engine=new Searcher(b);
                Check(engine.Nodes==0,"constructor performs no unbudgeted search");
                engine.StartSearch(30);
                Check(!engine.BestMoveSoFar.IsNull && FenUtility.CurrentFen(b)==original && b.ZobristKey==originalKey,"budgeted extra-army search restores board and hash");
                using var cancelled=new System.Threading.CancellationTokenSource(); cancelled.Cancel();
                engine.StartSearch(1000,cancelled.Token);
                Check(FenUtility.CurrentFen(b)==original && b.ZobristKey==originalKey,"cancelled search leaves original state intact");
            }
            b=Board.CreateBoard("QQQQQQnk/Q4Qpp/2Q3Q1/Q5QQ/3Q3Q/QQ1Q3Q/PPQ4Q/KN1QQQQQ w - - 0 1");
            Check(new MoveGenerator().GenerateMoves(b).Length==221,"independent 221 legal move stress fixture exceeds old 218");
            b=Board.CreateBoard("qQqQQqnk/qQqQqQpp/QQqQqQqQ/qqqQqQqQ/1QQQqqqq/QqqqQQQQ/PPQqQqqq/KNQqQqQQ w - - 0 1");
            Check(new MoveGenerator().GenerateMoves(b,true).Length==129,"independent 129 capture fixture exceeds old q buffer");
            b=Board.CreateBoard("7k/2P3pp/8/8/QQQQQQQ1/QQQQQQQQ/QQQQQQQQ/KQQQQQQQ w - - 0 1");
            foreach(var m in new MoveGenerator().GenerateMoves(b).ToArray().Where(m=>m.IsPromotion))
            {
                var k=b.ZobristKey; b.MakeMove(m,true);
                Check(b.ZobristKey==Zobrist.CalculateZobristKey(b) && b.Pawns[0].Count==0,"maximum inventory promotion headroom and hash");
                b.UnmakeMove(m,true); Check(b.ZobristKey==k && b.Queens[0].Count==30,"maximum promotion unmake restores list");
            }
            b=Board.CreateBoard();
            for(int i=0;i<600;i++) b.RepetitionPositionHistory.Push((ulong)i+1000);
            var repetition=new RepetitionTable(); repetition.Init(b);
            for(int i=0;i<600;i++) repetition.Push((ulong)i+2000,false);
            Check(repetition.Contains(1001),"repetition history/search safely exceed 256 entries");
            for(int i=0;i<600;i++) repetition.TryPop();
            Check(repetition.Contains(1001),"dynamic repetition push/pop preserves original history");
            foreach(var fen in new[]{"4k3/8/8/8/8/8/8/4K3 w K - 0 1","4k3/8/8/8/8/8/4K3/7R w K - 0 1","9/8/8/8/8/8/8/4K2k w - - 0 1","8/8/8/8/8/8/8/4K3 w - - 0 1"})
            {
                bool rejected=false; try{Board.CreateBoard(fen);}catch(ArgumentException){rejected=true;}
                Check(rejected,"malformed/native castling input rejected before board mutation");
            }
            Check(Arbiter.InsufficentMaterial(Board.CreateBoard("7k/8/8/6B1/8/4B3/8/K1B5 w - - 0 1")),"multiple same-color bishops recognized dead");
            Check(!Arbiter.InsufficentMaterial(Board.CreateBoard("7k/8/8/8/8/8/8/KNN5 w - - 0 1")),"two knights not automatically dead");
            Check(!Arbiter.InsufficentMaterial(Board.CreateBoard("7k/8/8/8/8/8/8/KBB5 w - - 0 1")),"opposite-color bishops not dead");

            b=Board.CreateBoard("4k3/8/8/8/8/8/8/K3R3 w - - 0 1");
            var forbiddenKey=b.ZobristKey; bool kingRejected=false;
            try { b.MakeMove(new Move(4,60),true); } catch(ArgumentException){kingRejected=true;}
            Check(kingRejected && b.ZobristKey==forbiddenKey && b.Square[60]==Piece.BlackKing,"king capture rejected before mutation");
            bool overCap=false;
            try { Board.CreateBoard("7k/8/NN6/NNNNNNNN/NNNNNNNN/NNNNNNNN/NNNNNNNN/K7 w - - 0 1"); } catch(ArgumentException){overCap=true;}
            Check(overCap,"native rejects over-cap inventory before piece-list construction");
            foreach(var fen in new[]{"7k/8/8/4P3/8/8/8/K7 w - d6 0 1","7k/8/8/8/4p3/8/8/K7 b - d3 0 1","7k/8/8/3PP3/8/8/8/K7 w - d6 0 1","7k/8/8/8/3pp3/8/8/K7 b - d3 0 1","7k/8/3N4/3pP3/8/8/8/K7 w - d6 0 1","7k/8/8/8/3Pp3/3n4/8/K7 b - d3 0 1","7k/3n4/8/3pP3/8/8/8/K7 w - d6 0 1","7k/8/8/8/3Pp3/8/3N4/K7 b - d3 0 1"})
            {
                bool rejected=false;
                try { PositionLimits.ValidatePlayableTurn(Board.CreateBoard(fen)); } catch(ArgumentException){rejected=true;}
                Check(rejected,"inconsistent external en passant rejected");
            }
            foreach(var fen in new[]{"7k/8/8/3p4/8/8/8/K7 w - d6 0 1","7k/8/8/8/3P4/8/8/K7 b - d3 0 1","7k/8/8/3pP3/8/8/8/K7 w - d6 0 1","7k/8/8/8/3Pp3/8/8/K7 b - d3 0 1"})
            {
                var epBoard=Board.CreateBoard(fen); PositionLimits.ValidatePlayableTurn(epBoard);
                Check(epBoard.CurrentGameState.enPassantFile==4,"valid external en passant retained with or without capturer");
            }
            foreach(var profile in new[]{RuleProfile.Standard,RuleProfile.Conservative})
            {
                b=Board.CreateBoard(); var initialFen=FenUtility.CurrentFen(b); var initialKey=b.ZobristKey;
                var generator=new MoveGenerator { Profile=profile };
                var legal=generator.GenerateMoves(b).ToArray();
                Check(legal.Length==20 && b.ZobristKey==initialKey && FenUtility.CurrentFen(b)==initialFen,"profile generation restores board/hash");
                var engine=new Searcher(b,profile); engine.StartSearch(2000,default,4);
                Check(legal.Any(m=>Move.SameMove(m,engine.BestMoveSoFar)),"profile search returns legal move");
                Check(b.ZobristKey==initialKey && b.ZobristKey==Zobrist.CalculateZobristKey(b) && FenUtility.CurrentFen(b)==initialFen,"profile search restores board/hash");
                Check(profile.LateMoveReductions ? engine.Reductions>0 : engine.Reductions==0,"LMR profile gate honored");
                Check(profile.TranspositionCache ? engine.CacheProbes>0 && engine.CacheStores>0 : engine.CacheProbes==0 && engine.CacheStores==0,"TT profile gate honored");
                Check(profile.PositionalEvaluation ? engine.PositionalEvaluations>0 && engine.MaterialEvaluations==0 : engine.MaterialEvaluations>0 && engine.PositionalEvaluations==0,"evaluation profile gate honored");
                using var cancel=new System.Threading.CancellationTokenSource();cancel.Cancel();
                engine.StartSearch(1000,cancel.Token);
                Check(legal.Any(m=>Move.SameMove(m,engine.BestMoveSoFar)) && b.ZobristKey==initialKey,"profile cancellation retains legal fallback and original state");
                bool badSchema=false;try{profile.Validate(b,1);}catch(ArgumentException){badSchema=true;}
                Check(badSchema,"unregistered ability schema fails closed in both profiles");
            }
            Console.WriteLine($"NATIVE: {checks} checks, 0 failures");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine("FAIL " + ex); return 1; }
    }
}
