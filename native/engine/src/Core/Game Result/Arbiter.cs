namespace Chess.Core
{
	using System.Linq;

	public static class Arbiter
	{
		public static bool IsDrawResult(GameResult result)
		{
			return result is GameResult.DrawByArbiter or GameResult.FiftyMoveRule or
				GameResult.Repetition or GameResult.Stalemate or GameResult.InsufficientMaterial;
		}

		public static bool IsWinResult(GameResult result)
		{
			return IsWhiteWinsResult(result) || IsBlackWinsResult(result);
		}

		public static bool IsWhiteWinsResult(GameResult result)
		{
			return result is GameResult.BlackIsMated or GameResult.BlackTimeout or GameResult.BlackIllegalMove;
		}

		public static bool IsBlackWinsResult(GameResult result)
		{
			return result is GameResult.WhiteIsMated or GameResult.WhiteTimeout or GameResult.WhiteIllegalMove;
		}


		public static GameResult GetGameState(Board board)
		{
			MoveGenerator moveGenerator = new MoveGenerator();
			var moves = moveGenerator.GenerateMoves(board);

			// Look for mate/stalemate
			if (moves.Length == 0)
			{
				if (moveGenerator.InCheck())
				{
					return (board.IsWhiteToMove) ? GameResult.WhiteIsMated : GameResult.BlackIsMated;
				}
				return GameResult.Stalemate;
			}

			// Fifty move rule
			if (board.FiftyMoveCounter >= 100)
			{
				return GameResult.FiftyMoveRule;
			}

			// Threefold repetition
			int repCount = board.RepetitionPositionHistory.Count((x => x == board.ZobristKey));
			if (repCount == 3)
			{
				return GameResult.Repetition;
			}

			// Look for insufficient material
			if (InsufficentMaterial(board))
			{
				return GameResult.InsufficientMaterial;
			}
			return GameResult.InProgress;
		}

		// Test for insufficient material (Note: not all cases are implemented)
		public static bool InsufficentMaterial(Board board)
		{
			// Can't have insufficient material with pawns on the board
			if (board.Pawns[Board.WhiteIndex].Count > 0 || board.Pawns[Board.BlackIndex].Count > 0)
			{
				return false;
			}

			// Can't have insufficient material with queens/rooks on the board
			if (board.FriendlyOrthogonalSliders != 0 || board.EnemyOrthogonalSliders != 0)
			{
				return false;
			}

			// If no pawns, queens, or rooks on the board, then consider knight and bishop cases
			int numWhiteBishops = board.Bishops[Board.WhiteIndex].Count;
			int numBlackBishops = board.Bishops[Board.BlackIndex].Count;
			int numWhiteKnights = board.Knights[Board.WhiteIndex].Count;
			int numBlackKnights = board.Knights[Board.BlackIndex].Count;
			int numWhiteMinors = numWhiteBishops + numWhiteKnights;
			int numBlackMinors = numBlackBishops + numBlackKnights;
			int numMinors = numWhiteMinors + numBlackMinors;

			// Lone kings or King vs King + single minor: is insuffient
			if (numMinors <= 1)
			{
				return true;
			}

			// Any number of bishops on one colour complex, with no knights.
			if (numWhiteKnights + numBlackKnights == 0)
			{
				bool? colour = null;
				foreach (var bishops in board.Bishops)
					for (int i=0;i<bishops.Count;i++)
					{
						bool squareColour = BoardHelper.LightSquare(bishops[i]);
						if (colour.HasValue && colour.Value != squareColour) return false;
						colour = squareColour;
					}
				return true;
			}

			return false;


		}
	}
}