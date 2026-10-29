# Changes

## v0.6 — 2026-10-29

- Simplified side choices to White/Black and fixed checkbox icon/padding geometry across all states.
- Allowed extra standard pieces up to 32 per side; hardened native list/move/search/repetition/evaluation bounds and rebuilt Windows/Linux engines.
- Fixed setup castling: unrelated edits retain rights, touched king/rook rights clear, and four explicit valid-pair toggles replace the aggregate control.
- Added native input/king-capture guards, bounded cancellable search without constructor warm-up, and extra-bishop draw parity.
- Added independent python-chess legal/threat comparisons over 541 positions and 17 published perft/divides; added capacity, promotion, checkbox and castling regressions.
- Planned abilities remain inactive; documented future extension gates and test-only reference licensing.

## v0.5 — 2026-10-29

- Added a pre-game editor with move/place/erase tools, side-to-move selection and material-odds presets for either human color.
- Validate standard inventory, kings, pawn ranks, checks and terminal positions before starting; edits clear castling/EP, with explicit home-square castling opt-in.
- Start uses a fresh FEN/history; Cancel preserves the live game. Captures start empty and material reflects the edited board.
- Added separate White/Black planned ability checkboxes with no gameplay effect or nonempty native ability state.
- Kept native engine/source/binaries and v0.4 play/inspection/history behavior unchanged.
- Added 112 setup checks including eight three-ply native odds games and lifecycle tests.

## v0.4 — 2026-10-29

- Added drag-and-drop while retaining click-to-move, promotion choice and illegal-drop cancellation.
- Added SAN move chronicle and read-only history with previous/next/start/live navigation. Reviewing pauses AI; returning live resumes it.
- Added actual capture ledger and conventional material balance for the displayed position, including en passant and promotions.
- Kept right-click legal/threat previews, medieval board, side rotation, check/last-move highlights and compiled engine unchanged.
- Added 62 UX/notation/history assertions and graphical Linux validation; previous 226 checks retained.

## v0.3 — 2026-10-29

- Replaced the playable GDScript AI with pinned Sebastian Lague V2 compiled C# UCI.
- Included self-contained Windows x64 and Linux x64 engines, full MIT source, runtime notices and build scripts.
- Hardened cancellation/stop/join, position mutation, terminal roots, history transport and all-four promotion handling.
- Added exact runtime agreement for both-side legal previews and geometric threats; failures stop visibly.
- Added inactive ability-state/mask seams with tested copy/make-unmake/null/hash identity and explicit move classification. No powers enabled.
- Preserved medieval UI, right-click previews, local play, side rotation and responsiveness. Difficulty is now a true time budget.
- Added native/protocol/bridge/failure tests and a controlled four-game comparison.


## Inspection, AI and medieval interface — 2026-10-28

- Right-click either army for clearly separate move/attack inspection, including
  off-turn labeling, pinned-piece attacks and en-passant policy.
- Added an original threaded GDScript AI with three search budgets; local/AI mode,
  side selection, automatic board rotation and live search measurements.
- Added generation-based cancellation and stale-result rejection on restart,
  mode/side/difficulty changes and terminal game events.
- Redesigned the board and controls with parchment, wood, brass and forest tones,
  licensed serif/symbol fonts, responsive placement and scrollable controls.
- Kept standard rules and original suites; added inspection, tactical engine and
  threaded scene tests. Documented extension points and honest strength limits.
- Preserved the previous baseline's independent Linux QA as historical evidence,
  separately from this revision's testing. No Mac/Windows testing is claimed.

## Previous baseline and Library version 1

Local two-player standard chess and tests. Version 1 changed documentation only
to record independent graphical Linux QA; the code was identical to version 0.
