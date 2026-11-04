using System;
using System.Linq;
namespace Chess.Core;

// Shared native bounds for editor armies, promotions and search storage.
public static class PositionLimits
{
    public const int MaxPiecesPerSide = 32;
    // One king <=10 destinations including castling; each other piece <=27.
    // Pawns have <=12 promotion moves. 31*27+10 = 847 < 1024.
    public const int MaxMoves = 1024;
    public const int MaxSearchPly = 256;

    public static void ValidateFen(string fen)
    {
        var f = fen.Split(' ');
        if (f.Length != 6) throw new ArgumentException("FEN requires six fields");
        var ranks = f[0].Split('/');
        if (ranks.Length != 8) throw new ArgumentException("FEN requires eight ranks");
        foreach (var row in ranks)
        {
            int width = 0;
            foreach (char c in row)
            {
                if (c >= '1' && c <= '8') width += c - '0';
                else if ("pnbrqkPNBRQK".Contains(c)) width++;
                else throw new ArgumentException("Invalid FEN piece");
            }
            if (width != 8) throw new ArgumentException("Invalid FEN rank width");
        }
        if (f[1] != "w" && f[1] != "b") throw new ArgumentException("Invalid FEN turn");
        if (f[2] != "-" && (f[2].Length == 0 || f[2].Distinct().Count() != f[2].Length || f[2].Any(c => !"KQkq".Contains(c)))) throw new ArgumentException("Invalid castling field");
        if (f[3] != "-" && (f[3].Length != 2 || f[3][0] < 'a' || f[3][0] > 'h' || f[3][1] != (f[1] == "w" ? '6' : '3'))) throw new ArgumentException("Invalid en passant field");
        if (!int.TryParse(f[4],out int half) || half < 0 || half > 1000000 || !int.TryParse(f[5],out int full) || full < 1 || full > 1000000) throw new ArgumentException("Invalid FEN counters");
    }
    // External UCI positions only. Internal opposite-turn previews intentionally
    // do not use this history/turn constraint.
    public static void ValidatePlayableTurn(Board board)
    {
        // A FEN target records a just-completed double push, even if no pawn
        // can capture it. Check the board evidence, not capturer availability.
        int epFile = board.CurrentGameState.enPassantFile;
        if (epFile != 0)
        {
            int target = (board.IsWhiteToMove ? 40 : 16) + epFile - 1;
            int direction = board.IsWhiteToMove ? 8 : -8;
            int pawn = Piece.MakePiece(Piece.Pawn, board.IsWhiteToMove ? Piece.Black : Piece.White);
            if (board.Square[target] != 0 || board.Square[target - direction] != pawn || board.Square[target + direction] != 0)
                throw new ArgumentException("En passant requires empty target/origin and the opposing double-pushed pawn");
        }
        int king=board.KingSquare[1-board.MoveColourIndex];
        for(int square=0;square<64;square++)
            if(Piece.IsColour(board.Square[square],board.MoveColour) && ((AbilityRules.ThreatMask(board,square)>>king)&1)!=0)
                throw new ArgumentException("Side not to move is in check");
    }
    public static void ValidateInventory(FenUtility.PositionInfo p)
    {
        int[] counts = new int[2], kings = new int[2], kingSquares = new int[2];
        for (int s=0;s<64;s++)
        {
            int piece=p.squares[s];
            if(piece==0) continue;
            int side=Piece.IsWhite(piece)?0:1, type=Piece.PieceType(piece);
            if(type<1 || type>6) throw new ArgumentException("Invalid piece type");
            counts[side]++;
            if(type==Piece.King){ kings[side]++; kingSquares[side]=s; }
            if(type==Piece.Pawn && (s/8==0 || s/8==7)) throw new ArgumentException("Pawn on promotion rank");
        }
        for(int side=0;side<2;side++)
            if(counts[side]>MaxPiecesPerSide || kings[side]!=1) throw new ArgumentException("Maximum 32 pieces and exactly one king per side required");
        if(Math.Max(Math.Abs(kingSquares[0]%8-kingSquares[1]%8),Math.Abs(kingSquares[0]/8-kingSquares[1]/8))<=1) throw new ArgumentException("Adjacent kings");
        foreach(var r in new[]{(p.whiteCastleKingside,4,7,Piece.White),(p.whiteCastleQueenside,4,0,Piece.White),(p.blackCastleKingside,60,63,Piece.Black),(p.blackCastleQueenside,60,56,Piece.Black)})
            if(r.Item1 && (p.squares[r.Item2]!=Piece.MakePiece(Piece.King,r.Item4) || p.squares[r.Item3]!=Piece.MakePiece(Piece.Rook,r.Item4))) throw new ArgumentException("Castling requires home king and rook");
    }
}
