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
            foreach(var white in new[]{true,false})
            {
                string fen=white?"7k/8/8/8/8/4P3/8/K7 w - - 17 1":"7k/8/4p3/8/8/8/8/K7 b - - 17 1";
                b=Board.CreateBoard(fen);
                var ordinaryHash=b.ZobristKey;
                b.SetAbilityStateForSetup(AbilityState.ParseRetreat(white?"white":"black", b));
                string retreat=white?"e3e2":"e6e7";
                var generator=new MoveGenerator();
                var legal=generator.GenerateMoves(b).ToArray();
                Check(legal.Any(m=>EngineUCI.Name(m)==retreat),"per-side retreat generated through conservative safety path");
                Check(!generator.GenerateMoves(b,true).ToArray().Any(m=>EngineUCI.Name(m)==retreat),"retreat is quiet, not a capture or attack");
                Check(b.ZobristKey!=ordinaryHash && b.ZobristKey==Zobrist.CalculateZobristKey(b),"retreat capability participates in hash");
                Check(Perft(b,3)>0,"retreat tree incremental hashes and every unmake restore state");
                var before=b.ZobristKey;
                var move=legal.Single(m=>EngineUCI.Name(m)==retreat);
                b.MakeMove(move);
                Check(b.CurrentGameState.fiftyMoveCounter==0 && b.CurrentGameState.enPassantFile==0,"retreat resets halfmove clock and never creates en passant");
                Check(b.RepetitionPositionHistory.Contains(before),"reversible pawn move preserves repetition history");
                var copyRetreat=Board.CreateBoard(b);
                Check(copyRetreat.ZobristKey==b.ZobristKey && copyRetreat.Abilities==b.Abilities,"copy replays active retreat history");
                var searchRetreat=new Searcher(b,RuleProfile.Standard);
                var searchFen=FenUtility.CurrentFen(b);var searchKey=b.ZobristKey;
                searchRetreat.StartSearch(100,default,3);
                Check(searchRetreat.Profile==RuleProfile.Conservative && searchRetreat.CacheProbes==0 && searchRetreat.Reductions==0,"active ability forces conservative search");
                Check(new MoveGenerator().GenerateMoves(b).ToArray().Any(m=>Move.SameMove(m,searchRetreat.BestMoveSoFar)) && b.ZobristKey==searchKey && FenUtility.CurrentFen(b)==searchFen,"active search returns legal move and restores board");
            }
            foreach(var item in new[]{
                ("7k/8/8/8/8/4P3/4n3/K7 w - - 0 1","e3e2"),
                ("7k/8/8/8/8/4P3/4N3/K7 w - - 0 1","e3e2"),
                ("7k/8/8/8/8/8/4P3/K7 w - - 0 1","e2e1"),
                ("7k/4p3/8/8/8/8/8/K7 b - - 0 1","e7e8"),
                ("7k/8/1b6/8/8/4P3/5K2/8 w - - 0 1","e3e2")})
            {
                b=Board.CreateBoard(item.Item1);b.SetAbilityStateForSetup(AbilityState.ParseRetreat("both", b));
                Check(!new MoveGenerator().GenerateMoves(b).ToArray().Any(m=>EngineUCI.Name(m)==item.Item2),"retreat rejects occupied/end-rank/king-exposing destinations");
            }
            b=Board.CreateBoard("7k/8/4p3/8/8/4P3/8/K7 w - - 0 1");
            b.SetAbilityStateForSetup(AbilityState.ParseRetreat("both", b));var cycleKey=b.ZobristKey;
            foreach(var name in new[]{"e3e2","e6e7","e2e3","e7e6","e3e2","e6e7","e2e3","e7e6"})
                b.MakeMove(new MoveGenerator().GenerateMoves(b).ToArray().Single(m=>EngineUCI.Name(m)==name));
            Check(b.ZobristKey==cycleKey && b.RepetitionPositionHistory.Count(k=>k==cycleKey)==3,"forward/backward pawn cycles retain threefold identity");
            b=Board.CreateBoard("7k/8/8/8/8/4P3/8/K7 w - - 0 1");b.SetAbilityStateForSetup(AbilityState.ParseRetreat("black", b));
            Check(!new MoveGenerator().GenerateMoves(b).ToArray().Any(m=>EngineUCI.Name(m)=="e3e2"),"disabled side cannot retreat");
            b=Board.CreateBoard("7k/8/8/8/8/4P3/8/K7 w - - 0 1");b.SetAbilityStateForSetup(AbilityState.ParseRetreat("white", b));
            foreach(var name in new[]{"e3e2","h8g8"}) b.MakeMove(new MoveGenerator().GenerateMoves(b).ToArray().Single(m=>EngineUCI.Name(m)==name));
            Check(new MoveGenerator().GenerateMoves(b).ToArray().Any(m=>EngineUCI.Name(m)=="e2e4"),"return to starting rank restores rank-based double advance");
            b=Board.CreateBoard("7k/8/8/8/8/2P5/8/1b1K4 w - - 0 1");b.SetAbilityStateForSetup(AbilityState.ParseRetreat("white", b));
            // Pawn retreat can interpose on a checking bishop ray.
            b=Board.CreateBoard("7k/8/8/8/8/1bP5/8/3K4 w - - 0 1");b.SetAbilityStateForSetup(AbilityState.ParseRetreat("white", b));
            Check(new MoveGenerator().GenerateMoves(b).ToArray().Any(m=>EngineUCI.Name(m)=="c3c2"),"retreat can block check when king-safe");
            b=Board.CreateBoard("7k/4P3/8/4p3/8/8/8/K7 w - e6 0 1");b.SetAbilityStateForSetup(AbilityState.ParseRetreat("white", b));
            var epTargetRetreat=new MoveGenerator().GenerateMoves(b).ToArray().Single(m=>EngineUCI.Name(m)=="e7e6");
            Check(epTargetRetreat.MoveFlag==Move.NoFlag,"synthetic retreat onto EP target classified quiet");
            b.MakeMove(epTargetRetreat);
            Check(b.Square[36]==Piece.BlackPawn && b.CurrentGameState.enPassantFile==0,"synthetic EP target retreat preserves opposing pawn");
            b=Board.CreateBoard("7k/8/8/8/8/3PP3/8/K7 w - - 0 1");
            b.SetAbilityStateForSetup(AbilityState.FromSquares(AbilityState.ParseSquares("e3"),b));
            var individual=new MoveGenerator().GenerateMoves(b).ToArray().Select(EngineUCI.Name).ToArray();
            Check(individual.Contains("e3e2") && !individual.Contains("d3d2"),"only marked pawn gains retreat");
            Check(Perft(b,3)>0,"per-piece state follows every move and hash/unmake in tree");
            var individualKey=b.ZobristKey;var individualFen=FenUtility.CurrentFen(b);
            var individualSearch=new Searcher(b);individualSearch.StartSearch(150,default,4);
            Check(b.ZobristKey==individualKey && FenUtility.CurrentFen(b)==individualFen && b.Abilities.RetreatSquares.SequenceEqual(new[]{"e3"}),"search restores per-piece markers");
            foreach(var name in new[]{"e3e2","h8g8","e2e4"})b.MakeMove(new MoveGenerator().GenerateMoves(b).ToArray().Single(m=>EngineUCI.Name(m)==name));
            Check(b.Abilities.RetreatSquares.SequenceEqual(new[]{"e4"}),"marker follows retreat and two-square advance");
            Check(Board.CreateBoard(b).Abilities==b.Abilities,"copy replay reconstructs current individual location");
            foreach(var item in new[]{
                ("7k/8/8/8/8/3p4/4P3/K7 w - - 0 1","d3,e2","e2d3","d3"),
                ("7k/8/8/8/8/4p3/4R3/K7 w - - 0 1","e3","e2e3",""),
                ("7k/8/8/3pP3/8/8/8/K7 w - d6 0 1","d5,e5","e5d6","d6"),
                ("7k/8/8/8/3Pp3/8/8/K7 b - d3 0 1","d4,e4","e4d3","d3"),
                ("7k/P7/8/8/8/8/8/K7 w - - 0 1","a7","a7a8q",""),
                ("7k/8/8/8/8/8/p7/7K b - - 0 1","a2","a2a1n","")})
            {
                b=Board.CreateBoard(item.Item1);b.SetAbilityStateForSetup(AbilityState.FromSquares(AbilityState.ParseSquares(item.Item2),b));
                var beforeState=b.Abilities;var beforeHash=b.ZobristKey;var beforeFen=FenUtility.CurrentFen(b);
                var action=new MoveGenerator().GenerateMoves(b).ToArray().Single(m=>EngineUCI.Name(m)==item.Item3);
                b.MakeMove(action,true);
                Check(string.Join(",",b.Abilities.RetreatSquares)==item.Item4 && b.ZobristKey==Zobrist.CalculateZobristKey(b),"capture/EP/promotion updates per-piece state and hash "+item.Item3);
                b.UnmakeMove(action,true);
                Check(b.Abilities==beforeState && b.ZobristKey==beforeHash && FenUtility.CurrentFen(b)==beforeFen,"capture/EP/promotion unmake restores marker "+item.Item3);
            }
            b=Board.CreateBoard("7k/8/8/8/8/4P3/8/K7 w - - 0 1");
            foreach(var square in new[]{"a1","a8","e3,e3","E3","e9","e3,","unknown"})
            {
                bool rejected=false;try{AbilityState.ParseSquares(square);}catch(ArgumentException){rejected=true;}
                Check(rejected,"invalid per-piece marker syntax rejected "+square);
            }
            foreach(var square in new[]{"a2","h7"})
            {
                bool rejected=false;try{AbilityState.FromSquares(AbilityState.ParseSquares(square),b);}catch(ArgumentException){rejected=true;}
                Check(rejected,"non-pawn marker rejected "+square);
            }
            b.SetAbilityStateForSetup(new AbilityState(0,0,0,1UL<<20));
            bool wrongColour=false;try{new MoveGenerator().GenerateMoves(b);}catch(ArgumentException){wrongColour=true;}
            Check(wrongColour,"marker wrong colour fails closed");
            Console.WriteLine($"NATIVE: {checks} checks, 0 failures");
            return 0;
        }
        catch (Exception ex) { Console.Error.WriteLine("FAIL " + ex); return 1; }
    }
}
