# Integrated Windows playtest validation — 2026-11-14

## Source and compatibility diagnosis

Fresh checkout, without touching `chess-ability-work`. No repository `.agents/skills`,
AGENTS.md or CI workflows were present. PR #4 is merged into current main
`c964cd45f3991c40e5405ba0448895b255f1ddbd`. PR #5 head is
`61daacd7d322f5e27e662131bdcf7567798d2c0c`; PR #6 head is
`e2d1e62b450bb209bde88c3e711cdc324e82da84`. Both are ancestors of this branch.
PR #6 already includes main and #5, so integration fast-forwarded without conflicts.
All three PR comment timelines were empty when inspected. The user's precise Windows
error was unavailable; the following are reproduced/confirmed packaging issues,
not a claim that one specific error was reported:

- A clean source clone lacks ignored `native/bin` outputs. The first pre-build
  Retreat test failed four real bridge searches with “Engine binary is missing”.
  After rebuilding from the integrated source all 36 checks passed.
- The tracked distribution ZIP is older than the feature source. New source and
  old engines must not be combined. Packages now carry matching rebuilt engines,
  file hashes and a source commit manifest.
- The bridge assumed `res://native/bin` for every run. Exported PCKs cannot launch
  an embedded executable. Standalone builds now resolve the external native engine
  beside the actual executable, independent of the current working directory.
- There were no standalone export presets. During implementation the scene-only
  export omitted GDScript preloads/fonts and opened blank. Real GUI testing caught
  it; all-resources export with explicit exclusions fixed it. The automated ZIP
  verifier now checks exported startup for script/parse errors.

## Automated verification

Godot 4.6.3, .NET SDK 10.0.404, self-contained linux-x64 and win-x64 builds.
Existing nullable/redundant-pattern compiler warnings remain; no compile errors.
Logs (ANSI coloring and trailing whitespace removed) in this directory, rerunnable commands in README and test sources.

| Suite | Result |
| --- | --- |
| Native selftest | 141 checks |
| Native UCI / profiles / Retreat / per-piece protocols | 37 / 16 / 22 / 18 checks |
| Orthodox Godot oracle | 545 positions, 1,652 checks |
| Orthodox native standard and conservative | 545 positions, 1,678 checks each |
| Published orthodox perft/divides | 17 cases in each of the three runs |
| Legacy Retreat Godot and native oracle | 260 positions, 840 checks each |
| Per-piece Godot/native oracle | 168 positions, 528 / 696 checks |
| Piece metadata / actual bridge replay / Workshop UI | 73 / 64 / 15 checks |
| Rules / inspection / engine / bridge | 37 / 10 / 34 / 56 checks |
| UI / UI engine / UI native / UX | 9 / 21 / 7 / 62 checks |
| Setup / extra armies / profiles / Retreat | 112 / 70 / 9 / 36 checks |
| Seeded native playtest | 52 legal engine plies, zero disagreements |

All above passed with zero failures. Seeded games selected no additional retreats;
that is not evidence of strategic strength. Tests cover ordinary chess, both profiles,
difficulty/cancellation, both colors, castling/extra armies, inspection, history,
per-piece replay, captures/EP/promotion, placement, rarity and reserved extra slots.

`python3 scripts/verify_packages.py` extracts to a new directory whose path has
spaces, validates every manifest hash and archive paths, preserves/verifies Linux
execute bits with unzip, executes the extracted native selftest and standalone
headless startup from an unrelated cwd, imports the cache-free fallback project,
and runs upgrade, actual bridge, Workshop and orthodox oracle suites there.

## Actual graphical smoke test

Ran the cleanly extracted Linux standalone executable from `/tmp`, with a spaced
extraction path, on the supplied Linux desktop at 1180x812 (Mesa llvmpipe).
Observed board/fonts rendering, e2-e4 and native Black reply Nc6, right-click
Black knight inspection, side switch/rotation and native White opening e4.
Selected Conservative, opened Piece Workshop, equipped only Black e7 pawn,
confirmed Rare purple framing and `1 / 2` reserved socket, then Legendary gold
framing. Started upgraded position. An initial e5 pawn was captured normally;
restarted original upgraded army, played e7-e6 and then e6-e7 after White's
Nf3/Nc3. The engine replied Ne5 after retreat with no bridge fault. History showed
`e6-e7` and retained the gold frame/sigil. Erased the pawn in setup then canceled;
the live pawn and five-ply history remained unchanged.

The Linux desktop has no audio device and logs dummy-audio fallback and unsupported
VSync. Godot also logged popup focus/tree signal connect/disconnect warnings during
dropdown use. They did not block input or play; retained in `gui-export.log`.
No GDScript parse/runtime errors occurred in the corrected final export.

## Limits

Windows game and engine are PE32+ x86-64, cross-built and archive-checked only.
No Windows machine was available; no claim of Windows execution, SmartScreen,
signing, antivirus acceptance, or driver compatibility. Applications are unsigned.
Mac/ARM binaries are not included. No release, deployment, merge, closure of existing
PRs, progression, second ability or new strength claim is part of this change.
