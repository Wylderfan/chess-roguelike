# v0.8 verification — November 4, 2026

- Orthodox Godot reference: 545 positions / 1,652 checks; 17 published perft/divide cases.
- Native standard and conservative: each 545 positions / 1,678 checks; same published matrix.
- New individual-upgrade oracle: 168 positions, Godot 528 / native 696 checks, 24 variant divides. Independent test-only python-chess transition/attack oracle, mixed upgraded/ordinary pawns, both colors, capture, EP, promotion, pin and check evasion.
- Legacy Retreat oracle: Godot and native each 260 positions / 840 checks.
- Piece metadata: 73 checks, including identity, slots, duplicate/eligibility rejection, movement, capture, EP, promotion, copy/history, repetition, invalid metadata, reset and odds.
- Scene workshop tests: 15 checks, including real native engine reply with selective black upgrade.
- Native selftests 141; individual protocol 18; Retreat protocol 22; standard lifecycle 37; profile protocol 16.
- Independent read-only review found no concrete correctness regression. Eight extra scratch lifecycle checks passed (reopen from history, erase inspector target, invalid setup, cancel preservation, tool-switch drag cancellation and ordinary neighboring pieces).
- Existing rules/setup/inspection/bridge/engine/UI/UX/profile suites passed; raw logs retained.

Reset intentionally clears upgrades and opening Setup intentionally restores the original starting army. Two old extra-army test assertions originally failed because their fixture expected opening Setup to reset standard. The fixture now explicitly applies the normal-army preset before testing inactive planned checkboxes. No legal-move expectation was relaxed. Initial Godot launches without writable XDG cache failed before test execution; isolated disposable XDG directories solved this environment issue.

This is finite correctness/compatibility evidence, not a strength rating. No new gameplay ability beyond Pawn Retreat, actual loot/progression, save system, Windows execution or Mac binary. Windows x64 self-contained build and PE format are checked; Linux x64 executes the tests.

Actual bridge replay regression: 64 checks passed, including capture/promotion/EP consuming the final upgrade, schema 0 with Conservative retained, mixed colors and clean ordinary reset. Two short seeded native games completed 52 legal engine plies with no bridge disagreement; the engine selected no additional retreats in this sample.

Retained console logs normalize trailing whitespace only.

## Independent Linux GUI pass

Actual 1180×812 desktop play: equip e2 only while d2 remains Common/ordinary; Rare violet and Legendary gold frames plus hollow second socket; e2-e3-e2 retained its sigil; ordinary d3-d2 rejected. History artwork matched the viewed position. Direct White a3 and Black h6 upgraded placement worked. Removing White's king visibly rejected the draft. Cancel/reopen restored the original upgraded e2 starting army and discarded draft changes. Black-human e7-e6-e7 worked with White engine replies; Black engine replies also tested. No functional defect observed.

Narrow-width visual verification was not established: the desktop window remained 1180×812 despite resize/CLI/harness attempts. Automated narrow-layout tests pass, but are not a substitute for a manual narrow-window pass. No Windows GUI or long-match strength test.
