using System;
namespace Chess.Core;

// Schema 2 stores per-piece Pawn Retreat markers as per-colour square bitboards.
// Value semantics allow snapshots in GameState and exact unmake/copy.
public readonly record struct AbilityState(ulong WhiteUsed, ulong BlackUsed,
    ulong WhiteMask, ulong BlackMask)
{
    public const int SchemaVersion = 2;
    public int Schema => IsEmpty ? 0 : SchemaVersion;
    public bool IsSupported => WhiteUsed == 0 && BlackUsed == 0 && (WhiteMask & BlackMask) == 0;
    public bool CanRetreat(int square) => (((WhiteMask | BlackMask) >> square) & 1) != 0;
    public string RetreatName => WhiteMask != 0 ? (BlackMask != 0 ? "both" : "white") : (BlackMask != 0 ? "black" : "none");
    public string[] RetreatSquares {
        get {
            var names = new System.Collections.Generic.List<string>();
            for(int s=0;s<64;s++) if(CanRetreat(s)) names.Add(BoardHelper.SquareNameFromIndex(s));
            names.Sort(StringComparer.Ordinal); return names.ToArray();
        }
    }
    public static string ValidateLegacy(string value) => value.ToLowerInvariant() switch {
        "none" => "none", "white" => "white", "black" => "black", "both" => "both",
        _ => throw new ArgumentException("Unknown PawnRetreat value") };
    public static AbilityState ParseRetreat(string value, Board board)
    {
        value=ValidateLegacy(value); ulong white=0,black=0;
        for(int s=0;s<64;s++) {
            if(board.Square[s]==Piece.WhitePawn && (value=="white" || value=="both")) white|=1UL<<s;
            if(board.Square[s]==Piece.BlackPawn && (value=="black" || value=="both")) black|=1UL<<s;
        }
        return new(0,0,white,black);
    }
    public static ulong ParseSquares(string value)
    {
        if(value=="none")return 0;
        ulong mask=0;
        foreach(string square in value.Split(',')) {
            if(square.Length!=2 || square[0]<'a' || square[0]>'h' || square[1]<'2' || square[1]>'7') throw new ArgumentException("PawnRetreatSquares requires comma-separated squares on ranks 2-7 or none");
            int s=(square[1]-'1')*8+square[0]-'a';ulong bit=1UL<<s;
            if((mask&bit)!=0)throw new ArgumentException("Duplicate PawnRetreat square");
            mask|=bit;
        }
        return mask;
    }
    public static AbilityState FromSquares(ulong squares, Board board)
    {
        ulong white=0,black=0;
        for(int s=0;s<64;s++)if(((squares>>s)&1)!=0) {
            if(board.Square[s]==Piece.WhitePawn)white|=1UL<<s;
            else if(board.Square[s]==Piece.BlackPawn)black|=1UL<<s;
            else throw new ArgumentException("PawnRetreat marker must identify a pawn: "+BoardHelper.SquareNameFromIndex(s));
        }
        return new(0,0,white,black);
    }
    public void Validate(Board board)
    {
        if(!IsSupported)throw new ArgumentException("Unsupported ability state");
        for(int s=0;s<64;s++) {
            if(((WhiteMask>>s)&1)!=0 && board.Square[s]!=Piece.WhitePawn || ((BlackMask>>s)&1)!=0 && board.Square[s]!=Piece.BlackPawn)
                throw new ArgumentException("Ability marker must match pawn colour and square");
        }
    }
    public bool IsEmpty => (WhiteUsed | BlackUsed | WhiteMask | BlackMask) == 0;
    public ulong Hash => IsEmpty ? 0 : Mix(WhiteUsed ^ 0x517cc1b727220a95UL)
        ^ Mix(BlackUsed ^ 0x6eed0e9da4d94a4fUL)
        ^ Mix(WhiteMask ^ 0x9e3779b97f4a7c15UL)
        ^ Mix(BlackMask ^ 0x94d049bb133111ebUL);
    static ulong Mix(ulong x)
    {
        x ^= x >> 30; x *= 0xbf58476d1ce4e5b9UL;
        x ^= x >> 27; x *= 0x94d049bb133111ebUL;
        return x ^ (x >> 31);
    }
}

public static class AbilityRules
{
    // Registered candidate extension; threats remain ordinary forward diagonals.
    // Do not OR candidate moves into legal moves without king/pin/check validation.
    public static ulong AdditionalDestinations(Board board, int square)
    {
        int piece = board.Square[square];
        if (Piece.PieceType(piece) != Piece.Pawn || !board.Abilities.CanRetreat(square)) return 0;
        int target = square + (Piece.IsWhite(piece) ? -8 : 8);
        return target >= 8 && target < 56 && board.Square[target] == 0 ? 1UL << target : 0;
    }
    public static ulong AdditionalThreats(Board board, int square) => 0;
    public static AbilityState AfterStandardMove(AbilityState state, Move move, int movedPiece)
    {
        ulong start=1UL<<move.StartSquare,target=1UL<<move.TargetSquare;
        ulong clear=start|target;
        if(move.MoveFlag==Move.EnPassantCaptureFlag)
            clear|=1UL<<(move.TargetSquare+(Piece.IsWhite(movedPiece)?-8:8));
        ulong white=state.WhiteMask & ~clear,black=state.BlackMask & ~clear;
        if(!move.IsPromotion) {
            if((state.WhiteMask&start)!=0)white|=target;
            if((state.BlackMask&start)!=0)black|=target;
        }
        return new(state.WhiteUsed,state.BlackUsed,white,black);
    }

    // Bit 0=a1 (unlike Godot's a8 index). Includes protected occupied endpoints.
    // Exposes the SAME precomputed knight/pawn/king and magic slider masks used
    // by the compiled core, for inspection validation and future shared protocol.
    public static ulong ThreatMask(Board board, int square)
    {
        int p = board.Square[square];
        return Piece.PieceType(p) switch
        {
            Piece.Pawn => Piece.IsWhite(p) ? BitBoardUtility.WhitePawnAttacks[square] : BitBoardUtility.BlackPawnAttacks[square],
            Piece.Knight => BitBoardUtility.KnightAttacks[square],
            Piece.King => BitBoardUtility.KingMoves[square],
            Piece.Bishop => Magic.GetBishopAttacks(square, board.AllPiecesBitboard),
            Piece.Rook => Magic.GetRookAttacks(square, board.AllPiecesBitboard),
            Piece.Queen => Magic.GetBishopAttacks(square, board.AllPiecesBitboard) | Magic.GetRookAttacks(square, board.AllPiecesBitboard),
            _ => 0
        };
    }
}
