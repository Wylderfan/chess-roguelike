# Independent move-generation regression

`positions.json` was generated with python-chess **1.11.2**, seed **6062026**.
It holds 541 positions: 480 deterministic plies across eight standard games,
crafted rule/extra-army fixtures and deterministic extra-army walks. All have
structurally valid kings/pawns/turn/check state. Only python-chess's orthodox
piece/pawn-count status flags are waived for intentionally extra armies. Their
legal moves and attacks still use the reference's standard movement rules.

The reference is independent of Sebastian's core and the Godot rules. The GPL
python-chess package is a **separate test-only install**, not bundled in the
project/ZIP or used by the game/native binary. `generate.py` is our test driver;
`positions.json` contains generated position/move/count facts, not library code.
Normal saved-fixture checks need no python-chess installation.

Sources:
- https://python-chess.readthedocs.io/en/latest/ (API/license/install)
- https://www.chessprogramming.org/Perft_Results (published lower-depth counts)
- https://github.com/official-stockfish/Stockfish/blob/ff7cee4244ec96ea488c402669e3674c0574dce6/tests/perft.sh (published standard fixture selection; no Stockfish code bundled)

Verified published matrix for both Godot and native (17 depth/divide cases):

| Position | Depths and node counts |
| --- | --- |
| Initial | 1:20, 2:400, 3:8902, 4:197281 |
| Kiwipete | 1:48, 2:2039, 3:97862 |
| EP endgame (position 3) | 1:14, 2:191, 3:2812, 4:43238 |
| Promotions (position 4) | 1:6, 2:264, 3:9467 |
| Check evasions (position 5) | 1:44, 2:1486, 3:62379 |

Perft does **not** stop at draw claims, repetition or move-count adjudication.
Every root move's subtree count (divide), not just the total, must match. Failures
print the fixture name, depth, actual and expected divides for diagnosis. The
fixture data also compares both-side legal sets and every piece's geometric
attacks/protected squares. Opposite-turn previews clear EP and exclude king
captures; these are hypothetical previews, not claims of legal game history.

Measured stress fixtures have 221 legal moves and 129 captures, exceeding the old
218/128 buffers. Other fixtures reach 32 pieces per side, 64 occupied squares,
31 pawns and promotion to 31 queens. Extra armies use independent expected sets;
they are not forced to match orthodox starting-position perft totals.

Run from the project root:

```sh
godot --headless --path . --script tests/test_reference.gd
python tests/reference/check_native.py native/bin/linux-x64/KnightEngine
```

Use `native/bin/win-x64/KnightEngine.exe` for native checks on Windows. To regenerate
outside the product runtime, install `chess==1.11.2` in a separate Python environment
and run `python tests/reference/generate.py`. No guarantee of exhaustive correctness
is implied: this corpus is finite, seeded, and excludes Chess960 and active powers.

Future abilities must keep the default no-op/abilities-off path passing this
orthodox matrix. Enabled custom movement needs its own expected positions/counts;
see `native/INTEGRATION.md`. Current checkboxes remain inactive even when selected.
