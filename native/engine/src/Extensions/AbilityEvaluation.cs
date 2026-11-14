using System;
using System.Collections.Generic;
namespace Chess.Core;

// Read-only evaluation view: no move execution or mutable Board is exposed.
// Scores are white-centric centipawns; the pipeline converts once to side-to-move.
public readonly struct AbilityEvaluationPosition
{
    readonly Board board;
    internal AbilityEvaluationPosition(Board board) { this.board = board; }
    public int PieceAt(int square) => board.Square[square];
    public bool WhiteToMove => board.IsWhiteToMove;
    public AbilityState Abilities => board.Abilities;
    public bool CanRetreat(int square) => board.Abilities.CanRetreat(square);
}

// Configure before constructing a Searcher. Each searcher takes an immutable
// snapshot: toggles/removals cannot invalidate an in-flight search or its TT.
// There are deliberately no production registrations or default balance terms.
public sealed class AbilityEvaluationRegistry
{
    readonly Dictionary<string, (Func<AbilityEvaluationPosition, int> Score, bool Enabled)> terms = new(StringComparer.Ordinal);
    readonly object gate = new();
    public void Register(string id, Func<AbilityEvaluationPosition, int> score, bool enabled = false)
    {
        if (string.IsNullOrWhiteSpace(id)) throw new ArgumentException("Contribution id is required");
        ArgumentNullException.ThrowIfNull(score);
        lock (gate) terms.Add(id, (score, enabled)); // Duplicate ids fail explicitly.
    }
    public void SetEnabled(string id, bool enabled)
    {
        lock (gate) { var term = terms[id]; terms[id] = (term.Score, enabled); }
    }
    public bool Remove(string id) { lock (gate) return terms.Remove(id); }
    public AbilityEvaluation Snapshot()
    {
        lock (gate)
        {
            var enabled = new List<Func<AbilityEvaluationPosition, int>>();
            foreach (var term in terms.Values) if (term.Enabled) enabled.Add(term.Score);
            return new AbilityEvaluation(enabled.ToArray());
        }
    }
}

public sealed class AbilityEvaluation
{
    public static readonly AbilityEvaluation Empty = new(Array.Empty<Func<AbilityEvaluationPosition, int>>());
    readonly Func<AbilityEvaluationPosition, int>[] terms;
    internal AbilityEvaluation(Func<AbilityEvaluationPosition, int>[] terms) { this.terms = terms; }
    public int Evaluate(Board board)
    {
        if (terms.Length == 0) return 0; // Preserve ordinary evaluation exactly.
        var position = new AbilityEvaluationPosition(board);
        long whiteScore = 0;
        foreach (var term in terms) whiteScore += term(position);
        // Extension scores must stay well outside the engine's mate-score band.
        if (Math.Abs(whiteScore) > 10000) throw new InvalidOperationException("Ability evaluation contributions exceed 10000 centipawns");
        return board.IsWhiteToMove ? (int)whiteScore : -(int)whiteScore;
    }
}
