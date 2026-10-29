namespace Chess.Core
{
	using System;
	using static System.Math;

	public class Searcher
	{
		// Constants
		const int transpositionTableSizeMB = 64;
		const int maxExtentions = 16;

		const int immediateMateScore = 100000;
		const int positiveInfinity = 9999999;
		const int negativeInfinity = -positiveInfinity;

		public event Action<Move>? OnSearchComplete;

		// State
		readonly Move[][] moveBuffers = new Move[PositionLimits.MaxSearchPly + 1][];
		readonly System.Collections.Generic.HashSet<ulong> quiescencePath = new();
		Span<Move> MoveBuffer(int ply) => moveBuffers[ply] ??= new Move[MoveGenerator.MaxMoves];
		public int CurrentDepth;
		public Move BestMoveSoFar => bestMove;
		public int BestEvalSoFar => bestEval;
		bool isPlayingWhite;
		Move bestMoveThisIteration;
		int bestEvalThisIteration;
		Move bestMove;
		int bestEval;
		bool hasSearchedAtLeastOneMove;
		volatile bool searchCancelled;
		System.Threading.CancellationToken cancellation;
		long deadline;
		int depthLimit = 64;
		public long Nodes { get; private set; }
		bool ShouldStop() => searchCancelled || cancellation.IsCancellationRequested || (deadline != 0 && System.Diagnostics.Stopwatch.GetTimestamp() >= deadline);

		// Diagnostics
		public SearchDiagnostics searchDiagnostics;
		int currentIterationDepth;
		System.Diagnostics.Stopwatch searchIterationTimer;
		System.Diagnostics.Stopwatch searchTotalTimer;
		public string debugInfo;

		// References
		readonly TranspositionTable transpositionTable;
		readonly RepetitionTable repetitionTable;
		readonly MoveGenerator moveGenerator;
		readonly MoveOrdering moveOrderer;
		readonly Evaluation evaluation;
		readonly Board board;

		public Searcher(Board board)
		{
			this.board = board;

			evaluation = new Evaluation();
			moveGenerator = new MoveGenerator();
			transpositionTable = new TranspositionTable(board, transpositionTableSizeMB);
			moveOrderer = new MoveOrdering(moveGenerator, transpositionTable);
			repetitionTable = new RepetitionTable();

			moveGenerator.promotionsToGenerate = MoveGenerator.PromotionMode.All;

			// No unbudgeted warm-up: StartSearch owns every searched node and cancellation.

		}

		public void StartSearch(int milliseconds = 1000, System.Threading.CancellationToken token = default, int maxDepth = 64)
		{
			// Initialize search
			cancellation = token;
			deadline = System.Diagnostics.Stopwatch.GetTimestamp() + (long)(milliseconds / 1000.0 * System.Diagnostics.Stopwatch.Frequency);
			depthLimit = maxDepth;
			Nodes = 0;
			bestEvalThisIteration = bestEval = 0;
			bestMoveThisIteration = bestMove = Move.NullMove;

			isPlayingWhite = board.IsWhiteToMove;

			moveOrderer.ClearHistory();
			repetitionTable.Init(board);

			// Initialize debug info
			CurrentDepth = 0;
			debugInfo = "Starting search with FEN " + FenUtility.CurrentFen(board);
			searchCancelled = false;
			searchDiagnostics = new SearchDiagnostics();
			searchIterationTimer = new System.Diagnostics.Stopwatch();
			searchTotalTimer = System.Diagnostics.Stopwatch.StartNew();

			// Safe terminal root: no fallback indexing and no pointless 256 iterations.
			if (moveGenerator.GenerateMoves(board).Length == 0)
			{
				OnSearchComplete?.Invoke(Move.NullMove);
				return;
			}
			RunIterativeDeepeningSearch();


			// Finish up
			// In the unlikely event that the search is cancelled before a best move can be found, take any move
			if (bestMove.IsNull)
			{
				bestMove = moveGenerator.GenerateMoves(board)[0];
			}
			OnSearchComplete?.Invoke(bestMove);
			searchCancelled = false;
		}

		// Run iterative deepening. This means doing a full search with a depth of 1, then with a depth of 2, and so on.
		// This allows the search to be cancelled at any time and still yield a useful result.
		// Thanks to the transposition table and move ordering, this idea is not nearly as terrible as it sounds.
		void RunIterativeDeepeningSearch()
		{
			for (int searchDepth = 1; searchDepth <= depthLimit; searchDepth++)
			{
				hasSearchedAtLeastOneMove = false;
				debugInfo += "\nStarting Iteration: " + searchDepth;
				searchIterationTimer.Restart();
				currentIterationDepth = searchDepth;
				Search(searchDepth, 0, negativeInfinity, positiveInfinity);

				if (ShouldStop())
				{
					if (hasSearchedAtLeastOneMove)
					{
						bestMove = bestMoveThisIteration;
						bestEval = bestEvalThisIteration;
						searchDiagnostics.move = MoveUtility.GetMoveNameUCI(bestMove);
						searchDiagnostics.eval = bestEval;
						searchDiagnostics.moveIsFromPartialSearch = true;
						debugInfo += "\nUsing partial search result: " + MoveUtility.GetMoveNameUCI(bestMove) + " Eval: " + bestEval;
					}

					debugInfo += "\nSearch aborted";
					break;
				}
				else
				{
					CurrentDepth = searchDepth;
					bestMove = bestMoveThisIteration;
					bestEval = bestEvalThisIteration;

					debugInfo += "\nIteration result: " + MoveUtility.GetMoveNameUCI(bestMove) + " Eval: " + bestEval;
					if (IsMateScore(bestEval))
					{
						debugInfo += " Mate in ply: " + NumPlyToMateFromScore(bestEval);
					}

					bestEvalThisIteration = int.MinValue;
					bestMoveThisIteration = Move.NullMove;

					// Update diagnostics
					searchDiagnostics.numCompletedIterations = searchDepth;
					searchDiagnostics.move = MoveUtility.GetMoveNameUCI(bestMove);
					searchDiagnostics.eval = bestEval;
					// Exit search if found a mate within search depth.
					// A mate found outside of search depth (due to extensions) may not be the fastest mate.
					if (IsMateScore(bestEval) && NumPlyToMateFromScore(bestEval) <= searchDepth)
					{
						debugInfo += "\nExitting search due to mate found within search depth";
						break;
					}
				}
			}
		}

		public (Move move, int eval) GetSearchResult()
		{
			return (bestMove, bestEval);
		}

		public void EndSearch()
		{
			searchCancelled = true;
		}


		int Search(int plyRemaining, int plyFromRoot, int alpha, int beta, int numExtensions = 0, Move prevMove = default, bool prevWasCapture = false)
		{
			Nodes++;
			if (ShouldStop())
			{
				return 0;
			}

			if (plyFromRoot > 0)
			{
				// Detect draw by three-fold repetition.
				// (Note: returns a draw score even if this position has only appeared once for sake of simplicity)
				if (board.CurrentGameState.fiftyMoveCounter >= 100 || repetitionTable.Contains(board.CurrentGameState.zobristKey))
				{
					/*
					const int contempt = 50;
					// So long as not in king and pawn ending, prefer a slightly worse position over game ending in a draw
					if (board.totalPieceCountWithoutPawnsAndKings > 0)
					{
						bool isAITurn = board.IsWhiteToMove == aiPlaysWhite;
						return isAITurn ? -contempt : contempt;
					}
					*/
					return 0;
				}

				// Skip this position if a mating sequence has already been found earlier in the search, which would be shorter
				// than any mate we could find from here. This is done by observing that alpha can't possibly be worse
				// (and likewise beta can't  possibly be better) than being mated in the current position.
				alpha = Max(alpha, -immediateMateScore + plyFromRoot);
				beta = Min(beta, immediateMateScore - plyFromRoot);
				if (alpha >= beta)
				{
					return alpha;
				}
			}

			// Try looking up the current position in the transposition table.
			// If the same position has already been searched to at least an equal depth
			// to the search we're doing now,we can just use the recorded evaluation.
			int ttVal = transpositionTable.LookupEvaluation(plyRemaining, plyFromRoot, alpha, beta);
			if (ttVal != TranspositionTable.LookupFailed)
			{
				if (plyFromRoot == 0)
				{
					bestMoveThisIteration = transpositionTable.TryGetStoredMove();
					bestEvalThisIteration = transpositionTable.entries[transpositionTable.Index].value;
				}
				return ttVal;
			}

			if (plyRemaining == 0 || plyFromRoot >= PositionLimits.MaxSearchPly)
			{
				int evaluation = QuiescenceSearch(alpha, beta, plyFromRoot);
				return evaluation;
			}

			Span<Move> moves = MoveBuffer(plyFromRoot);
			moveGenerator.GenerateMoves(board, ref moves, capturesOnly: false);
			Move prevBestMove = plyFromRoot == 0 ? bestMove : transpositionTable.TryGetStoredMove();
			moveOrderer.OrderMoves(prevBestMove, board, moves, moveGenerator.opponentAttackMap, moveGenerator.opponentPawnAttackMap, false, plyFromRoot);
			// Detect checkmate and stalemate when no legal moves are available
			if (moves.Length == 0)
			{
				if (moveGenerator.InCheck())
				{
					int mateScore = immediateMateScore - plyFromRoot;
					return -mateScore;
				}
				else
				{
					return 0;
				}
			}

			if (plyFromRoot > 0)
			{
				bool wasPawnMove = Piece.PieceType(board.Square[prevMove.TargetSquare]) == Piece.Pawn;
				repetitionTable.Push(board.CurrentGameState.zobristKey, prevWasCapture || wasPawnMove);
			}

			int evaluationBound = TranspositionTable.UpperBound;
			Move bestMoveInThisPosition = Move.NullMove;

			for (int i = 0; i < moves.Length; i++)
			{
				Move move = moves[i];
				int capturedPieceType = Piece.PieceType(board.Square[move.TargetSquare]);
				bool isCapture = capturedPieceType != Piece.None;
				board.MakeMove(moves[i], inSearch: true);

				// Extend the depth of the search in certain interesting cases
				int extension = 0;
				if (numExtensions < maxExtentions)
				{
					int movedPieceType = Piece.PieceType(board.Square[move.TargetSquare]);
					int targetRank = BoardHelper.RankIndex(move.TargetSquare);
					if (board.IsInCheck())
					{
						extension = 1;
					}
					else if (movedPieceType == Piece.Pawn && (targetRank == 1 || targetRank == 6))
					{
						extension = 1;
					}
				}

				bool needsFullSearch = true;
				int eval = 0;
				// Reduce the depth of the search for moves later in the move list as these are less likely to be good
				// (assuming our move ordering isn't terrible)
				if (extension == 0 && plyRemaining >= 3 && i >= 3 && !isCapture)
				{
					const int reduceDepth = 1;
					eval = -Search(plyRemaining - 1 - reduceDepth, plyFromRoot + 1, -alpha - 1, -alpha, numExtensions, move, isCapture);
					// If the evaluation is better than expected, we'd better to a full-depth search to get a more accurate evaluation
					needsFullSearch = eval > alpha;
				}
				// Perform a full-depth search
				if (needsFullSearch)
				{
					eval = -Search(plyRemaining - 1 + extension, plyFromRoot + 1, -beta, -alpha, numExtensions + extension, move, isCapture);
				}
				board.UnmakeMove(moves[i], inSearch: true);

				if (ShouldStop())
				{
					return 0;
				}

				// Move was *too* good, opponent will choose a different move earlier on to avoid this position.
				// (Beta-cutoff / Fail high)
				if (eval >= beta)
				{
					// Store evaluation in transposition table. Note that since we're exiting the search early, there may be an
					// even better move we haven't looked at yet, and so the current eval is a lower bound on the actual eval.
					transpositionTable.StoreEvaluation(plyRemaining, plyFromRoot, beta, TranspositionTable.LowerBound, moves[i]);

					// Update killer moves and history heuristic (note: don't include captures as theres are ranked highly anyway)
					if (!isCapture)
					{
						if (plyFromRoot < MoveOrdering.maxKillerMovePly)
						{
							moveOrderer.killerMoves[plyFromRoot].Add(move);
						}
						int historyScore = plyRemaining * plyRemaining;
						moveOrderer.History[board.MoveColourIndex, moves[i].StartSquare, moves[i].TargetSquare] += historyScore;
					}
					if (plyFromRoot > 0)
					{
						repetitionTable.TryPop();
					}

					searchDiagnostics.numCutOffs++;
					return beta;
				}

				// Found a new best move in this position
				if (eval > alpha)
				{
					evaluationBound = TranspositionTable.Exact;
					bestMoveInThisPosition = moves[i];

					alpha = eval;
					if (plyFromRoot == 0)
					{
						bestMoveThisIteration = moves[i];
						bestEvalThisIteration = eval;
						hasSearchedAtLeastOneMove = true;
					}
				}
			}

			if (plyFromRoot > 0)
			{
				repetitionTable.TryPop();
			}

			transpositionTable.StoreEvaluation(plyRemaining, plyFromRoot, alpha, evaluationBound, bestMoveInThisPosition);

			return alpha;

		}

		// Search capture moves until a 'quiet' position is reached.
		int QuiescenceSearch(int alpha, int beta, int ply)
		{
			Nodes++;
			if (ShouldStop()) return 0;
			if (!quiescencePath.Add(board.ZobristKey)) return 0;
			ulong key = board.ZobristKey;
			try
			{
				bool inCheck = board.IsInCheck();
				Span<Move> moves = MoveBuffer(ply);
				moveGenerator.GenerateMoves(board, ref moves, capturesOnly: !inCheck);
				if (inCheck && moves.Length == 0) return -immediateMateScore + ply;
				if (board.CurrentGameState.fiftyMoveCounter >= 100 || repetitionTable.Contains(key)) return 0;
				int eval = evaluation.Evaluate(board);
				searchDiagnostics.numPositionsEvaluated++;
				// Explicit ceiling also bounds quiet check evasions. No stack move arrays.
				if (ply >= PositionLimits.MaxSearchPly) return eval;
				if (!inCheck)
				{
					if (eval >= beta) return beta;
					alpha = Max(alpha, eval);
				}
				moveOrderer.OrderMoves(Move.NullMove, board, moves, moveGenerator.opponentAttackMap, moveGenerator.opponentPawnAttackMap, true, ply);
				for (int i = 0; i < moves.Length; i++)
				{
					board.MakeMove(moves[i], true);
					try { eval = -QuiescenceSearch(-beta, -alpha, ply + 1); }
					finally { board.UnmakeMove(moves[i], true); }
					if (ShouldStop()) return 0;
					if (eval >= beta) return beta;
					alpha = Max(alpha, eval);
				}
				return alpha;
			}
			finally { quiescencePath.Remove(key); }
		}


		public static bool IsMateScore(int score)
		{
			if (score == int.MinValue)
			{
				return false;
			}
			const int maxMateDepth = 1000;
			return Abs(score) > immediateMateScore - maxMateDepth;
		}

		public static int NumPlyToMateFromScore(int score)
		{
			return immediateMateScore - Abs(score);

		}

		public string AnnounceMate()
		{
			if (IsMateScore(bestEvalThisIteration))
			{
				int numPlyToMate = NumPlyToMateFromScore(bestEvalThisIteration);
				int numMovesToMate = (int)Ceiling(numPlyToMate / 2f);

				string sideWithMate = (bestEvalThisIteration * ((board.IsWhiteToMove) ? 1 : -1) < 0) ? "Black" : "White";

				return $"{sideWithMate} can mate in {numMovesToMate} move{((numMovesToMate > 1) ? "s" : "")}";
			}
			return "No mate found";
		}

		public void ClearForNewPosition()
		{
			transpositionTable.Clear();
			moveOrderer.ClearKillers();
		}

		public TranspositionTable GetTranspositionTable() => transpositionTable;

		[Serializable]
		public struct SearchDiagnostics
		{
			public int numCompletedIterations;
			public int numPositionsEvaluated;
			public ulong numCutOffs;

			public string moveVal;
			public string move;
			public int eval;
			public bool moveIsFromPartialSearch;
			public int NumQChecks;
			public int numQMates;

			public bool isBook;

			public int maxExtentionReachedInSearch;
		}

	}
}