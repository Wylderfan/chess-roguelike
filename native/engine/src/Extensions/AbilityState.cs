using System;
namespace Chess.Core;

// Schema foundation only. No abilities are registered/enabled by v0.3.
// Value semantics allow cheap snapshots in GameState and exact unmake/copy.
public readonly record struct AbilityState(ulong WhiteUsed, ulong BlackUsed,
    ulong WhiteMask, ulong BlackMask)
{
    public const int SchemaVersion = 0;
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
    // These zero-effect hooks are the documented seam, not activated powers.
    // Do not OR candidate moves into legal moves without king/pin/check validation.
    public static ulong AdditionalDestinations(Board board, int square) => 0;
    public static ulong AdditionalThreats(Board board, int square) => 0;
    public static AbilityState AfterStandardMove(AbilityState state, Move move) => state;

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
