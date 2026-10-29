# Knight Chess v0.4 — Godot 4.6.3

**Ready-to-play package:** download [the complete v0.4 ZIP](dist/Knight-Chess-v0.4-Godot-4.6.3.zip) using GitHub’s Download raw button, then follow the instructions below. The ZIP contains the self-contained Windows/Linux engines. A source-only checkout must build the engine using `native/build.ps1` or `native/build.sh`, or copy `native/bin` from the ZIP. Native build outputs are intentionally not committed separately.

Normal chess with Sebastian Lague's compiled C# engine, a medieval-inspired board,
and right-click inspection of either army. Local two-player mode remains available.
This release adds dragging, a move chronicle and material tracking. The inactive
ability-state foundation remains unchanged; no powers or progression are enabled.

## Windows: extract, import, play

1. Extract the entire ZIP into a writable folder. Keep the `native` folder beside
   `project.godot`; do not run the project from inside the ZIP viewer.
2. Download **Godot 4.6.3 Standard for Windows x64** from the official archive:
   https://godotengine.org/download/archive/4.6.3-stable/
3. Open Godot's Project Manager, select **Import**, and choose `project.godot`.
4. Wait for font import, then click **Run Project** (F5).
5. Choose your side and a time budget. The matching compiled engine starts
   automatically. **No .NET installation, Python, Unity, or Godot .NET is needed
   to play on Windows x64.**

The included `native/bin/win-x64/KnightEngine.exe` is self-contained. It was
cross-built and its Windows x64 executable format checked on Linux; actual
Windows execution has not yet been tested here. This is a source project to
run in Godot, not an exported/signed Windows application or an in-browser game.
Windows ARM-native Godot requires a separately built win-arm64 engine; see
`native/INTEGRATION.md`. No architecture is silently emulated by the bridge.

Linux x64 binary is also included and tested. After extraction, if execute
permissions were lost, run `chmod +x native/bin/linux-x64/KnightEngine`.
Mac binaries are not included; build the matching osx-arm64/osx-x64 target using
`native/build.sh` and the official .NET 10 SDK. Mac execution is unverified.

## Controls

- Drag a piece onto a green legal destination, or click your piece and then its
  destination. An illegal/off-board drop makes no move; Escape or right-click
  cancels dragging. Gold marks the last move; red marks check. Both input methods
  offer all four promotion choices before committing the move.
- The **Chronicle** records standard algebraic notation (SAN), including captures,
  castling, disambiguation, promotions, check and mate. Select a move or use
  Previous/Next (Left/Right arrows); Home reviews the starting position.
  History is **read-only**. The engine pauses/cancels its pending search while
  you review. **Return to live** or End resumes the unchanged live game and AI.
  Even the latest reviewed position remains read-only until you return to live.
  Right-click inspection works on the displayed historical position.
- Captured pieces are recorded from actual captures, including en passant and
  captured promoted pieces. **Material** counts pieces on the displayed board:
  pawn 1, knight/bishop 3, rook 5, queen 9; kings excluded. A positive lead is
  labelled by side, equal material is Even. This is **not an engine evaluation**:
  position, king safety and tactics are not included. Promotion changes material
  without incorrectly adding a captured pawn. History shows historical totals.
- Right-click either army to inspect without selecting a playable piece.
  **Blue dots/rings:** king-safe destinations. **Amber diamonds:** attacked or
  protected squares, including friendly occupied endpoints. These are different
  concepts: pinned pieces still attack, pawns attack diagonally, and kings attack
  adjacent squares they may not legally enter.
- Off-turn inspection means “if that side moved now on the unchanged board,” not
  a prediction. It retains castling rights/safety checks but clears en passant.
  Castling is a move, not a king attack. Pawn attacks remain visible even when an
  en-passant capture would expose its king. Left-click starts a fresh selection;
  an inspection destination alone never executes a move.
- Inspection remains responsive while the engine thinks and after game end.
  Right-click the same piece again, or Esc, to clear.
- Play as Black rotates the board. New game, side, or mode changes reset play.
  Changing the time budget keeps the position and cancels/replaces pending work.
- Narrow windows stack the board and scrollable controls. Local mode supports
  two players and agreed draws. Claim draw appears for qualifying current positions.

## What changed in the opponent

The weak GDScript search is replaced by the **Chess-V2-UCI** branch of Sebastian
Lague's Chess-Coding-Adventure, pinned to
`f346d2d2ee92422614de063724796537337d702b`, retaining its optimized C# bitboards,
transposition table, ordering, reductions, extensions and evaluation.
Full MIT source and notices are included. The former engine remains only as a
clearly named test baseline, never a silent fallback opponent.

Quick/Balanced/Deep use real **300/1100/2600 ms search budgets**. They are not Elo
or artificial skill levels. Startup/rules verification adds roughly 140–180 ms
on the build machine. The engine can finish early when it finds a forced mate.
No rating is claimed: the upstream author's Lichess description is not a verified
rating for this build, nor a chess.com rating.

Evidence: all seven existing tactical fixtures passed; opening searches reached
completed depths 8/10/11 at the three budgets in one sample. In four controlled
150 ms-per-side games, this engine beat v0.2 **4–0**, with two openings and colors
reversed. That is a small regression comparison, not an Elo estimate. Complete
move sequences and measured logs are in `validation/`.

The UI validates the engine's full legal-move sets and piece threat masks before
each search, preserves repetition history, and revalidates each returned move.
A process failure or rules disagreement pauses engine play with a visible error;
choose Local or New game to recover. There is no network engine dependency.

## Normal-chess scope

Ordinary legal moves, king safety, checkmate/stalemate, both castlings with rights
and attacked-transit checks, en passant including discovered checks, and all
four promotions are supported.

Threefold repetition and the 50-move rule are claimable **in the current position**.
Fivefold repetition and 75 moves per player without pawn movement/capture are
automatic; checkmate takes priority. Repetition includes turn, castling rights
and a legally usable en-passant target. The engine receives initial FEN plus all
moves, not a history-free current FEN.

Recognized dead material: kings only, one bishop/knight versus king, and
king/bishop-only positions with all bishops on the same square color. Two knights
are not automatically dead. No exhaustive solver for unusual blocked dead
positions or prospective draw claims before an intended move. No clocks, touch
move, arbiter penalties, undo, save/load UI, PGN import/export or resignation button. This is
not a complete tournament adjudicator. Internal FEN loading is for trusted tests.

## Source and future abilities

- `main.gd`: medieval board, drag/click input, independent review snapshots,
  SAN chronicle, capture ledger, material display and AI lifecycle controls.
- `rules.gd`: Godot standard rules and inspection, history transport and empty
  ability-state placeholder.
- `engine.gd`: nonblocking UCI bridge; no GDScript search.
- `native/engine/src/Core`: optimized compiled upstream core with targeted fixes.
- `native/engine/src/Extensions/AbilityState.cs`: inactive masks/state hooks.
- `native/INTEGRATION.md`: exact source pin, changes, protocol, licenses,
  platform/build requirements and the required future ability audit.
- `tests/` and `validation/`: reproducible suites, comparison and observed results.

Future ability state must affect copies, make/unmake/null moves, hashes and
repetition as well as bitboards. These seams are tested now but all gameplay
hooks have zero effect. Before enabling abilities, migrate their play/inspection
legality to the shared compiled protocol; never independently duplicate custom
rules in Godot and the engine. Nonempty or unknown ability schemas currently fail
closed. See the integration document for move flags and search-rule audit points.

## Re-run validation

Use your Godot executable in place of `godot`. These require no Python:

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --script res://tests/test_inspection.gd
godot --headless --path . --script res://tests/test_engine.gd
godot --headless --path . --script res://tests/test_ui.gd
godot --headless --path . --script res://tests/test_ui_engine.gd
godot --headless --path . --script res://tests/test_bridge.gd
godot --headless --path . --script res://tests/test_ui_native.gd
godot --headless --path . --script res://tests/test_ux.gd
native/bin/win-x64/KnightEngine.exe --selftest
```

Optional Python protocol suite and four-game comparison are described in
VALIDATION.md. All scripts return nonzero on test failure. Godot creates a local
`.godot` cache on import; caches and native build intermediates are not shipped.
The bundled DejaVu fonts retain their original license. No external artwork.
