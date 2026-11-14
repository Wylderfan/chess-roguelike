# Ability evaluation contributions

`Searcher.EvaluatePosition()` now composes the unchanged ordinary evaluator with
an optional `AbilityEvaluation` snapshot. Standard retains Sebastian's positional
evaluation; Conservative retains the existing material values. No production
contributions are registered or enabled, and the existing 300/1100/2600 ms budgets
and default Balanced difficulty are unchanged. Pawn Retreat still forces
Conservative through the existing Godot bridge/native rule-profile path.

## Add, enable, disable or remove an evaluation term

1. Create an `AbilityEvaluationRegistry` before constructing the searcher.
2. `Register("your.unique.term", scoreFunction)` registers a disabled term by default.
   Duplicate IDs throw. Give each independently configurable contribution its own ID.
3. The function receives `AbilityEvaluationPosition`, a read-only view with
   `PieceAt`, `WhiteToMove`, immutable `Abilities` and per-piece `CanRetreat`.
   Return **White-centric centipawns**, including negative scores for Black advantages.
   Check actual active/per-piece state; an unequipped pawn must not get a bonus.
   Functions must be pure, deterministic, and must not capture mutable game state.
4. `SetEnabled(id, true/false)` changes only registry configuration, not ability rules.
   `Remove(id)` removes only the score contribution. Unknown toggle IDs throw;
   removal returns false for absent IDs.
5. Pass `registry.Snapshot()` as the third constructor argument to a **new**
   `Searcher(board, profile, snapshot)`. The snapshot copies the enabled delegate
   set, so later registry edits cannot affect an in-flight search or its cached scores.
   Cancel/join any old search before installing a replacement. Never mutate a closure
   behind a snapshot. Ordinary callers omit the third argument and get the empty set.

The pipeline converts the sum once to side-to-move perspective. Its empty path
returns exactly zero. Total extra evaluation is restricted to ±10,000 cp, outside
the engine's mate band; violating this contract throws. This is a developer API,
not a player setting or new UCI option. No evaluation tuning is enabled by default.

`NativeTests.AbilityEvaluationTests` uses a **test-only** 25 cp contribution per
marked pawn. It covers empty/disabled/no-op sets, active/inactive pieces, both
colors, sign conversion, enabling/disabling/removal, snapshot isolation, legal-set
identity, board/hash restoration and an actual search. It is not a Retreat buff.

## Evaluation is not ability implementation

For a genuine new ability, independently implement and test all applicable seams:

- Godot per-piece metadata, setup validation, slots, history and presentation.
- Native registered ability schema and protocol/handshake transport.
- Legal candidates and attacks (which are distinct), king safety, checks and pins.
- Make/unmake, capture, en passant, promotion, copy, null moves and replay.
- Zobrist identity, repetition and draw semantics; cache compatibility.
- Search profile/optimizations, cancellation and bridge agreement for both sides.
- Independent expected move/threat/perft fixtures and graphical playtesting.

Only then add optional evaluation if warranted. Removing a score term does not
remove that ability from pieces or disable its legal moves. Retiring an ability
requires migration/rejection of stored metadata and protocol state plus the same
rule/lifecycle audit. See INTEGRATION.md for those existing contracts.
