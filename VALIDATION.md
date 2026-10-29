# v0.3 validation — 2026-10-29

Godot **4.6.3.stable.official.7d41c59c4**, Linux x86_64. Compiled engine built with
Microsoft .NET SDK **10.0.403**, self-contained runtime **10.0.14**. Exact upstream
commit and licenses are in `native/UPSTREAM.txt` and `native/INTEGRATION.md`.

## Passed

**226 explicit checks**, plus per-node assertions during native perft and four
controlled games:

| Suite | Checks | Coverage |
| --- | ---: | --- |
| Existing Godot rules | 37 | Initial perft 20/400/8902, Kiwipete 48/2039, endgame perft 2812; special moves, king safety and draws |
| Existing inspection | 10 | Both sides, pins, pawns, protected endpoints, kings/castling and en-passant semantics |
| Existing tactical engine | 34 | Legal output/state invariance; mate 1/2, hanging queen, recapture avoidance, mate defense, queen/rook promotions, time bounds, cancellation/terminal |
| Existing scene | 9 | Actual viewport mouse events, selection, moves, promotion, restart and mate/draw feedback |
| Existing threaded scene | 21 | Inspection during search, stale results, restart/mode/side/budget cancellation, draw/game end, AI promotion, layout |
| Native core | 15 | Perft with hash/make-unmake checks at every traversed node; state copy/null/hash, inactive masks, all promotions/reserved flags, terminal root |
| UCI protocol | 37 | Handshake, mate/stalemate, special legal sets, repeated-vs-isolated history, 12 rapid stop/new-position pairs, old timer rejection, explicit depth command, quit |
| Bridge differential/failure | 56 | Exact both-side legal and threat agreement on 12 fixtures plus 40 deterministic history positions, inactive schema identity, fail-closed behavior/process death |
| Native UI | 7 | Black-side first move/rotation, responsive inspection, visible process-error recovery, unchanged board, local recovery and successful new engine game |

All suites were rerun after extracting the release ZIP into a clean directory;
fresh Godot import and main-scene startup also passed. No `.godot`, native `obj`,
intermediate `bin`, SDK, or repository metadata is included in the archive.

One existing assertion was adapted transparently: difficulty previously meant
homemade maximum depth 2; it now verifies that the new 300 ms budget completes
within 1000 ms including startup and makes progress. The UI does not advertise
unsupported skill or depth settings. All other original suite assertions remain.

Native roundtrip assertions validate incremental versus full Zobrist recomputation
and restore FEN/hash/ability state at every node in initial depth-3, Kiwipete
depth-2, and en-passant endgame depth-3 trees, plus promotion and nonempty test-only
schema trees. Nonempty schema changes identity but has no movement effect and
cannot be enabled through the gameplay bridge.

## Measured strength and responsiveness

Representative new compiled-engine run (includes process startup, protocol
verification and shutdown in reported elapsed time):

| Fixture | Move | Completed depth | Nodes | Elapsed |
| --- | --- | ---: | ---: | ---: |
| Mate in one | g6g7 | 1 | 1 | 155 ms |
| Mate in two | f6g6 | 3 | 870 | 137 ms |
| Hanging queen, 1.1 s search | d2d4 | 16 | 3,508,907 | 1,240 ms |
| Defend immediate mate, 2.6 s | d8e7 | 10 | 6,175,870 | 2,764 ms |
| Rook underpromotion | c7c8r | 4 | 762 | 138 ms |
| Initial board, 300 ms | b1c3 | 8 | 192,370 | 453 ms |
| Initial board, 1.1 s | e2e4 | 10 | 2,737,223 | 1,259 ms |
| Initial board, 2.6 s | e2e4 | 11 | 6,689,707 | 2,751 ms |

Node counters cover search calls, not constructor warmup; a warmup TT entry can
make a trivial depth-1 result use one measured node. Timings/depths vary by load.
The old GDScript opening search reached depth 3 at 1.1 and 2.6 seconds here.

Controlled baseline comparison: **4 wins, 0 losses, 0 draws, 0 capped games** for
v0.3 versus v0.2. Both received a 150 ms search budget (native process startup
adds wall time), two fixed openings (e4/e5 and d4/d5), each with colors reversed,
100-ply cap. Every game ended in checkmate. Complete move sequences are retained
in `validation/comparison.txt`; `tests/compare_baseline.gd` reproduces the setup.
This tiny sample does not establish Elo or general tournament strength.

Responsive native-scene sample: **404 frames over 2,779 ms**, maximum headless
frame gap **8 ms**. Restart cancellation passed the existing 400 ms bound.
Process death was deliberately induced; the UI displayed an error without moving,
then recovered through Local and New game. No tests rely on a hidden fallback AI.

## Reproduce

See README for the seven Godot suites. Additional commands from project root:

```text
native/bin/win-x64/KnightEngine.exe --selftest
python tests/native/test_protocol.py native/bin/win-x64/KnightEngine.exe
godot --headless --path . --script res://tests/compare_baseline.gd
```

Linux substitutes `native/bin/linux-x64/KnightEngine`. Python's standard library
is sufficient; Python is not a gameplay dependency. All test scripts exit nonzero
on failure. Runtime logs for this revision are retained under `validation/`.

## Not verified / limits

Windows x64: successfully cross-published self-contained binary; inspected as
PE32+ x86-64. **Not executed on Windows here.** No direct Mac/Windows gameplay or
v0.3 graphical screenshot QA was available in this executor. Parent independent
visual QA is separate. Linux headless native execution and scene input were tested.
No Mac/ARM binaries included; documented source builds remain unverified targets.

No abilities/progression implemented, no rated match testing, no claim of exact
Lichess/chess.com Elo. Existing current-position draw-claim and dead-position
limits remain in README. The upstream search's repetition evaluation is heuristic;
Godot adjudicates actual game results.

## Historical evidence preserved separately

**Previous baseline v1, October 28:** independent QA reran 37 rules and 9 scene
checks in Godot 4.6.3; inspected graphical Linux screenshots around 1180×812 and
1000×800; actual e2-e4, e7-e5, g1-f3 clicks checked hints, turn/last move, draw
cancel and restart. Graphical special-move/promotion playthrough was not repeated;
automated suites covered those. Real Mac import/run was not tested.

**v0.2, internal Library version 3:** parent reports independent graphical Linux
QA and documentation-only updates; code matched internal version 2. This prior
QA is preserved as historical evidence, not proof for the changed v0.3 engine.
The previous 111 headless checks and four-game comparison baseline source are
retained/retested as described above. Retrieval of the prior ZIP's exact expanded
QA prose was unavailable in this executor, so this summary does not invent
additional graphical scenarios or claim Windows/Mac testing.
