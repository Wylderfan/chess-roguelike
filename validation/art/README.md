# Castle Print visual candidate

Baseline: v0.9 / 78d5e1615d133201acb36fca3ca26ca4e35d970f.
This branch contains presentation changes only. The v0.9 branch and all its
Library artifacts are preserved.

## Art and comparison

Compared the actual v0.9 GUI (centered small menu on a plain green field, font
chessmen, rounded brown controls) with actual desktop renders of this candidate.
The new title screen uses an asymmetrical parchment title-page composition and
an original illustrated castle-room knight. Live play is deliberately quieter:
blue-black ink, an engraved copper frame, ivory/slate squares, original chessmen
and a copper history selection. Setup/settings share this skin.

After the first GUI inspection, refined the hero knight's eye/cheek cuts,
strengthened focus borders, and increased green/blue move-marker contrast with
ink rims so both light and dark squares remain readable. No idle movement or
camera/board motion is added; hover/focus changes supply restrained response.
No game rules, time budgets, engine code, ability state, or upgrade graphics
semantics were edited. Native engine hashes are identical to v0.9.

Original asset provenance and retained font licensing: assets/art/SOURCES.md.

## Verification

Godot 4.6.3 Linux; existing suites all pass:
- Menu/check-history: 81 checks across 1100x812, 1180x812, 1000x800, 700x820,
  600x760. All Previous/Next/Live rects remain fixed across check transitions.
- Rules 37; bridge 56; per-piece bridge 64; setup 112; inspection 10;
  piece upgrades 73; UX 62; Retreat UI 15.

Actual Linux source and standalone GUI inspection at 1180x812 and 700x812:
menu composition, keyboard focus/Enter, hover, Settings and coordinate toggle,
opening sandbox, Workshop Legendary Retreat, e4 and native Nf6 reply,
right-click inspection, local e4 f6 Qh5+, repeated Previous/Next at both widths,
check/readability and return-to-menu confirmation. Screenshots are captures of
the actual standalone game window, not mockups, scene-only renders or overlays.

Windows x64 is a fresh standalone export with the unchanged matching native
engine. The separate package script checks ZIP CRC/path integrity, fresh
extraction in a path with spaces, every manifest hash, PE x64 machine types,
and the native binary against the baseline digest. Windows was not executed.
The existing Linux driver VSync and Godot popup diagnostics remain environmental
limits; see retained GUI logs. No merge, release or deployment is performed.

Final Windows export was repeated from an independent clean Git checkout with
a fresh .godot import cache. Import/export passed with no errors or tracked
changes. Both preview PNGs are 1180x812 and below 140 KB.
