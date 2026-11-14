using System;
namespace Chess.Core;

// Only registered orthodox contracts are executable. A future ruleset must
// supply candidates, threats, reversible execution and complete state identity.
public sealed record RuleProfile(string Name, bool FastLegality, bool LateMoveReductions,
    bool TranspositionCache, bool PositionalEvaluation)
{
    public static readonly RuleProfile Standard = new("standard", true, true, true, true);
    public static readonly RuleProfile Conservative = new("conservative", false, false, false, false);
    public static RuleProfile Parse(string name) => name.ToLowerInvariant() switch {
        "standard" => Standard, "conservative" => Conservative,
        _ => throw new ArgumentException("Unknown RulesProfile") };
    public void Validate(Board board, int schema = AbilityState.SchemaVersion)
    {
        if (schema != 0 || !board.Abilities.IsEmpty || (this != Standard && this != Conservative))
            throw new ArgumentException("Unsupported rule contract or ability state/schema");
    }
}

public interface IRuleContract
{
    void Validate(Board board);
    ulong Threats(Board board, int square);
    int Candidates(Board board, Span<Move> output);
    void Make(Board board, Move move);
    void Unmake(Board board, Move move);
}

// Standard candidates from bitboard geometry, without fast pin/check masks.
// No arbitrary abilities are registered by this implementation.
public sealed class OrthodoxContract : IRuleContract
{
    public static readonly OrthodoxContract Instance = new();
    public void Validate(Board board) => RuleProfile.Conservative.Validate(board);
    public ulong Threats(Board board, int square) => AbilityRules.ThreatMask(board, square);
    public void Make(Board board, Move move) => board.MakeMove(move, true);
    public void Unmake(Board board, Move move) => board.UnmakeMove(move, true);
    public int Candidates(Board b, Span<Move> output)
    {
        int n=0, colour=b.MoveColour, forward=b.IsWhiteToMove?8:-8;
        for(int s=0;s<64;s++)
        {
            int piece=b.Square[s],type=Piece.PieceType(piece);
            if(!Piece.IsColour(piece,colour)) continue;
            if(type==Piece.Pawn)
            {
                int t=s+forward;
                if(t>=0 && t<64 && b.Square[t]==0)
                {
                    PawnMove(output,ref n,s,t);
                    if(s/8==(b.IsWhiteToMove?1:6) && b.Square[t+forward]==0)
                        output[n++]=new Move(s,t+forward,Move.PawnTwoUpFlag);
                }
                ulong targets=Threats(b,s);
                for(t=0;t<64;t++) if(((targets>>t)&1)!=0)
                {
                    if(Piece.IsColour(b.Square[t],b.OpponentColour) && Piece.PieceType(b.Square[t])!=Piece.King) PawnMove(output,ref n,s,t);
                    else if(b.CurrentGameState.enPassantFile==t%8+1 && t/8==(b.IsWhiteToMove?5:2) && b.Square[t]==0 && b.Square[t-forward]==Piece.MakePiece(Piece.Pawn,b.OpponentColour))
                        output[n++]=new Move(s,t,Move.EnPassantCaptureFlag);
                }
            }
            else
            {
                ulong targets=Threats(b,s);
                for(int t=0;t<64;t++) if(((targets>>t)&1)!=0 && !Piece.IsColour(b.Square[t],colour) && Piece.PieceType(b.Square[t])!=Piece.King)
                    output[n++]=new Move(s,t);
                int home=b.IsWhiteToMove?4:60;
                if(type==Piece.King && s==home)
                {
                    int rights=b.CurrentGameState.castlingRights, shift=b.IsWhiteToMove?0:2;
                    if((rights & (1<<shift))!=0 && b.Square[home+3]==Piece.MakePiece(Piece.Rook,colour) && b.Square[home+1]==0 && b.Square[home+2]==0) output[n++]=new Move(s,home+2,Move.CastleFlag);
                    if((rights & (2<<shift))!=0 && b.Square[home-4]==Piece.MakePiece(Piece.Rook,colour) && b.Square[home-1]==0 && b.Square[home-2]==0 && b.Square[home-3]==0) output[n++]=new Move(s,home-2,Move.CastleFlag);
                }
            }
        }
        return n;
    }
    static void PawnMove(Span<Move> output,ref int n,int s,int t)
    {
        if(t/8==0 || t/8==7) for(int flag=4;flag<=7;flag++) output[n++]=new Move(s,t,flag);
        else output[n++]=new Move(s,t);
    }
}

public static class SimulatedLegality
{
    public static bool InCheck(Board b,int side,IRuleContract rules)
    {
        ulong king=1UL<<b.KingSquare[side]; int enemy=side==0?Piece.Black:Piece.White;
        for(int s=0;s<64;s++) if(Piece.IsColour(b.Square[s],enemy) && (rules.Threats(b,s)&king)!=0) return true;
        return false;
    }
    public static int Generate(Board b,ref Span<Move> moves,bool capturesOnly,IRuleContract rules)
    {
        rules.Validate(b);
        int side=b.MoveColourIndex,count=rules.Candidates(b,moves),n=0;
        for(int i=0;i<count;i++)
        {
            Move m=moves[i];
            if(capturesOnly && b.Square[m.TargetSquare]==0 && m.MoveFlag!=Move.EnPassantCaptureFlag && !m.IsPromotion) continue;
            if(m.MoveFlag==Move.CastleFlag)
            {
                if(InCheck(b,side,rules))continue;
                Move transit=new(m.StartSquare,m.StartSquare+Math.Sign(m.TargetSquare-m.StartSquare));
                rules.Make(b,transit); bool safe;
                try { safe=!InCheck(b,side,rules); } finally { rules.Unmake(b,transit); }
                if(!safe)continue;
            }
            rules.Make(b,m); bool legal;
            try { legal=!InCheck(b,side,rules); } finally { rules.Unmake(b,m); }
            if(legal)moves[n++]=m;
        }
        moves=moves.Slice(0,n);return n;
    }
}
