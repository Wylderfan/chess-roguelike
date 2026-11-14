# v0.7 verification — November 4, 2026

- Godot standard reference: 545 positions / 1,652 checks, all 17 published perft/divide cases passed.
- Native standard and conservative profiles: each 545 positions / 1,678 checks, same published matrix passed.
- Independent variant oracle: Godot and native each match 260 positions / 840 checks, including 60 variant depth/divide cases.
- Focused Godot Pawn Retreat: 36 checks; scene integration: 8 checks.
- Existing Godot rule/UI/engine/setup suite logs retained here; all final runs pass.
- Native selftests: 114; lifecycle 37; profile protocol 16; retreat protocol 22 passed.
- Two engine selfplay exercises seeded with e2e4 e7e5 e4e3 completed 52 subsequent engine plies without bridge disagreement or invalid move. One ended early on repetition; no additional retreat was selected by the engine in this small sample. This tests compatibility, not improved playing strength or Elo.
- Windows x64 binary cross-built and PE format checked; no Windows execution. Linux x64 used for execution.

Initial execution attempts without writable XDG directories crashed before tests; rerun with disposable writable XDG data/config/cache succeeded. Variant-oracle development initially included king captures in impossible off-turn previews, and an inconsistent EP FEN with occupied double-push origin; those oracle errors were corrected, not treated as product failures. The synthetic EP-target transition remains a focused Godot/native board test. No test threshold was relaxed.

## Actual desktop GUI pass

Independent Linux Godot GUI playtest: both Pawn Retreat toggles checked without label shift; e2-e4, engine Nf6, White e4-e3 accepted and shown explicitly in Chronicle, followed by engine Nc6. Previous/Next showed pre/post-retreat pawn squares correctly; Return to live and Setup Cancel preserved the game. New setup with toggles off reset history and ordinary chess: attempted e4-e3 was rejected, e5 remained legal. No observed app bug. Black retreat was covered in automated tests but not this manual GUI pass. No Windows GUI or long match execution.
