# Compiled engine integration — v0.6

## Provenance and build

Source: https://github.com/SebLague/Chess-Coding-Adventure/tree/Chess-V2-UCI
Pinned commit: **f346d2d2ee92422614de063724796537337d702b**.
MIT: Copyright (c) 2021 Sebastian Lague. Full license retained in
LICENSE-SebLague.txt. Original README retained; its rating language is the
upstream author's claim, not a verified rating for this integration.

Upstream targets .NET 6; this integration targets **.NET 10 LTS**. Built using
Microsoft's official **SDK 10.0.403**, bundled runtime **10.0.14**. Runtime license
and third-party notices are retained. No Unity or Godot .NET editor is needed.
The self-contained program includes its runtime; players do not install .NET.

Included binaries:

- `bin/win-x64/KnightEngine.exe`: Windows x64, cross-published on Linux. PE x64
  verified; execution on actual Windows has not been verified here.
- `bin/linux-x64/KnightEngine`: Linux x64, executed and tested here.

macOS and ARM binaries are not included. Source can be built for those platforms,
but their runtime behavior is unverified. No binary or application is signed.

Build from this included source after installing the official .NET 10 SDK:

```powershell
# Windows, from the native directory
.\build.ps1 -Runtime win-x64
```

```sh
# Linux; substitute osx-arm64, osx-x64, win-arm64 etc. for another target.
./build.sh linux-x64
```

The scripts run `dotnet publish -c Release -r RID --self-contained true
-p:PublishSingleFile=true -p:DebugType=None`. NuGet downloads Microsoft's runtime
packages on first build. There are no third-party NuGet package dependencies.
Godot chooses the matching `native/bin/RID/KnightEngine[.exe]`; retain that layout.
A missing platform binary stops AI with an explicit message; local play remains
available. On Unix, retain/restore the executable permission after ZIP extraction.

## Changes to upstream

Retained compiled C# magic bitboards, piece lists, incremental board updates,
transposition table/bounds/depth, killer/history ordering, LMR, extensions and
material/pawn/king/endgame evaluation. Nothing was translated to GDScript.

- Search generates all four promotion choices rather than QueenAndKnight.
- Move.IsPromotion explicitly recognizes flags 4–7. Flags 8–15 are unknown,
  not promotions or enabled abilities; Board.MakeMove rejects them.
- Terminal roots return null safely instead of indexing an empty move list.
- Search accepts a per-request cancellation token, monotonic deadline and optional
  depth limit; includes node diagnostics. No timer closure accesses a later search.
- Replaced EngineUCI/Program with a serialized input controller and joined search
  tasks. Position/newgame/quit suppress old output and join before mutation;
  stop returns the current result. Invalid position moves are rejected atomically.
  EOF exits cleanly. The old Bot.cs is retained as upstream reference but excluded
  from compilation. Its unsafe background board/timer behavior is not used.
- Added inactive extension state and bitboard inspection protocol, described below.
- Opening-book data/source is retained under upstream MIT, but this controller does
  not use the book. Search strength measurements do not rely on book moves.

The search's upstream repetition/draw evaluation is a heuristic (including early
repetition avoidance). Godot remains the standard-game adjudicator with documented
claim/automatic-draw semantics. No new Elo or tournament-rule completeness claim.

## v0.6 extra-army safety changes

`PositionLimits` and the editor enforce 32 pieces per side including one king.
Each native pawn/knight/bishop/rook/queen list has capacity 32. Promotions do not
increase army size, so 30 queens plus pawn/king can promote safely to 31 queens.
The shared move/ordering capacity is 1024: at most 31 non-kings ×27 queen moves
plus 10 king destinations (including castling) gives the conservative bound 847;
pawns have at most 12 promotion choices. Tested stress positions actually exceed
the former 218-move/128-capture storage at 221 legal moves and 129 captures.

Main search and quiescence reuse lazily allocated **per-ply heap buffers**, not
large recursive stack allocations. A 256-ply defensive ceiling bounds check-evasion
cycles; quiescence detects path repetition, handles all legal evasions when checked
and restores board/path state with finally blocks. At the ceiling it returns a
static evaluation after checking for mate; this is a search safety fallback, not
an adjudicated game result. The constructor no longer runs an unbudgeted depth-1
warm-up; the requested search owns cancellation and time from its first node.

Repetition storage grows dynamically, including initialization from histories
longer than 256 entries. Isolated-pawn penalty lookup saturates at the last table
entry, preserving all existing values for 0–8 isolated pawns. Material/PST scoring
iterates all pieces, and phase weights already clamp; supported material scores
stay below mate scores. Fixed 64-square masks, killer-ply guards and move/history
indices remain appropriate. Same-color bishop-only dead-material detection now
handles arbitrary bishop counts, matching Godot; two knights/opposite-color
bishops are not falsely declared dead.

Native FEN validation rejects malformed structure, out-of-bound inventories,
missing/duplicate/adjacent kings, back-rank pawns and impossible castling pairs
before replacing the live board. External UCI input also rejects a checked side
not to move. That turn/history constraint is intentionally **not** applied to
internal opposite-turn inspection snapshots. King capture is explicitly rejected
before mutation. Invalid commands leave the prior live position intact.

`knight divide DEPTH` (1–4) is a diagnostic command returning per-root perft counts;
it uses a copied board and does not stop at draw adjudication. It is not a UI rule
or ability. See `tests/reference/README.md` for independent fixture comparisons.

## Process contract and fail-closed agreement

Godot's `engine.gd` is now a bridge. It runs nonblocking pipes on a worker thread,
with bounded startup/search/cleanup time and explicit errors. Each request owns a
fresh engine process, so there is no stale process result/TT/timer from another
request. This sacrifices TT reuse between moves and adds process/startup overhead
(measured in each release's logs), while retaining optimized search and TT reuse within a move.
The main scene additionally checks generation and position, then calls Rules.play.
Restart/side/mode/difficulty changes cancel old work and terminate the old process.

`position fen INITIAL_FEN moves FULL_MOVE_SEQUENCE` preserves the history from
that starting point. Sending only the current FEN would lose repetitions; the
bridge does not do that. A custom test FEN starts a new history by design.

Supported UCI: uci, isready, ucinewgame, position, go movetime, go depth,
go wtime/btime/winc/binc/movestogo, stop, quit. Depth is optional, not the UI
strength control. Unsupported UCI options are not advertised. UI levels map to
300/1100/2600 ms search ceilings. isready is readiness, not a stop/join barrier.
The protocol loop owns barriers for state-changing commands. Search-error lines
and illegal/no-result output stop engine play visibly; no silent weak-AI fallback.

`knight snapshot` stops/joins and returns one JSON line containing schema version,
current legal UCI moves, hypothetical opposite-side legal moves (EP cleared),
per-piece geometric threat squares, hash and repetition/history diagnostics.
The adapter compares **all** of these move/threat sets with Godot before every
search. Off-turn preview excludes captures of the opposing king in both systems.
Any discrepancy stops AI rather than choosing a move from incompatible rules.

## Ability bitboard/state foundation — inactive

`src/Extensions/AbilityState.cs` contains a small value schema: per-side used-state
bits and per-side masks, all zero for normal chess. No ability is registered and
no gameplay rule changes. Empty state hashes to zero, preserving original normal
chess keys. Nonempty test-only state has a deterministic contribution to identity.

- GameState snapshots contain AbilityState, so ordinary/null unmake restores it.
- Copying carries initial state and replays moves. Setup-only state changes reset
  root state/history; ordinary transitions carry state through AfterStandardMove.
- MakeMove includes the old/new ability hash delta. Full Zobrist recomputation
  includes the same contribution. Repetition uses the combined key.
- AdditionalDestinations/AdditionalThreats return zero and are **not yet wired
  into legal generation**. ThreatMask exposes the
  existing pawn/knight/king masks and magic slider masks, including protected
  endpoints. Core bit 0 is **a1**; Godot index 0 is **a8**. The protocol uses square
  names to avoid accidental inversion or loss of 64-bit precision in JSON.
- Godot has an empty copied/keyed placeholder. The bridge rejects nonempty ability
  state or unknown schema: it must not pretend standard UCI supports custom state.
- Move flags are classified explicitly. No flag is assigned to a future ability.

Before enabling a real ability, make the compiled rules/protocol authoritative
for BOTH play and inspection, including state transport and legal/threat masks.
Godot's standard generator is currently a checked independent implementation;
do not maintain two separate ability implementations. Version the protocol and
serialize charges/cooldowns/once-per-match history, not only board masks. Audit
pin/check shortcuts, king safety and castling interactions, make/unmake and null
moves, repetition/hash/TT identity, move encoding/classification, captures and
promotions, quiescence/quiet reductions/extensions, evaluation and book policy.
The setup checkbox intent is kept outside runtime AbilityState even when selected.
Keep the default no-op branch passing all published orthodox perft/divides; enabled
powers require separately specified move/threat/execute/state/hash fixtures, not
orthodox counts forced onto altered rules. Revisit PositionLimits and the move
bound before adding spawns, extra destinations or new move encodings. Add
roundtrip/perft/differential/tactical tests before allowing a nonempty schema.
These are concrete extension seams, not a promise that arbitrary abilities can
be implemented by simply OR-ing a mask into legal moves.

## Native tests

```text
bin/win-x64/KnightEngine.exe --selftest
python tests/native/test_protocol.py native/bin/win-x64/KnightEngine.exe
```

The second command is run from the project root. Python is needed only for that
protocol test, not to play. Linux uses `native/bin/linux-x64/KnightEngine`.
Native perft tests check incremental hashes and complete make/unmake roundtrips
at every traversed node, including castling, en passant and promotions. They also
exercise inactive state, copying, null moves, reserved flags and terminal roots.
See the root VALIDATION.md and `validation/` logs for measured results.

## Functional compatibility profiles (v0.6 revision)

UCI: `setoption name RulesProfile value standard` (default) or `conservative`.
`knight profile` returns the active settings; snapshots include the profile name,
which Godot verifies. Profile changes stop/join/suppress existing search before
changing configuration. Diagnostics report actual LMR, TT probe/store and chosen
evaluation counters. The UI exposes the same two profiles independently of
inactive ability checkbox intent. Unknown profiles/options are errors.

`Extensions/RuleProfile.cs` defines the registered capability combinations and
`IRuleContract` candidate/threat/make/unmake seam. Only `OrthodoxContract` is
registered. Conservative candidates come directly from bitboard geometry and
pawn/castling rules, without the fast generator's pin/check pruning. Each is
made, its mover's king checked against geometric opposing attacks, and unmade in
`finally`. Castling checks origin and simulated transit separately from the final
king/rook move; EP removes its victim before checking; promotions include all four
choices; kings cannot be captured. The same contract is used in conservative
search, snapshots, replay validation and perft. Current custom-state validation
accepts only empty schema 0; the state foundation can still be unit-tested through
explicit make/unmake without allowing it into playable search/generation.

Standard retains the existing fast generator and search policy. Conservative
bypasses all TT probes/stores and cached-move ordering, disables LMR, and evaluates
only signed material P100/N300/B320/R500/Q900. It retains alpha-beta, iterative
deepening, move ordering, ordinary check/pawn extensions and check-aware quiescence.
These retained rules are standard-specific too: future contract authors must
review extensions, tactical classification, evaluation and repetition before
registering a new profile. Repetition/hashes remain active even with TT disabled.
A fresh search owns its profile and table, so incompatible evaluations never share
cached entries. A full custom contract needs state identity/serialization and move
bounds audited; this does not claim arbitrary powers work today.

External en-passant validation requires an empty target, opposing double-pushed
pawn behind it, and empty vacated origin, with the correct side/rank. A capturer
is **not** required: valid FENs retain EP targets even when no legal EP capture
exists. Rejected commands preserve the previous live board. Off-turn snapshots
continue clearing EP before constructing the hypothetical board.

Profile protocol tests: `python tests/native/test_profiles.py native/bin/linux-x64/KnightEngine`.
Use the Windows executable path on Windows. Native self-tests also assert profile
control counters, legal results, cancellation and hash restoration.
