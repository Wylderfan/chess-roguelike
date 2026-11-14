# Sandbox menu and evaluation extension validation

All checks below ran on Linux with Godot 4.6.3 and .NET SDK 10.0.404.
No engine strength, budgets, default difficulty, or core rules were changed.

## Check-history regression

Before the change, `e4 f6 Qh5+` at 1100 x 812 moved Previous from y=600
at ply 2 to y=636 at ply 3 (36 pixels). See check-jump-before.log.
The new reserved check row and fixed single-line status keep all three navigation
rectangles identical across four Previous/Next cycles at 1100x812, 1180x812,
1000x800, 700x820 and 600x760. See menu.log (81 checks).

## Tests

- Native self-test: 156 checks, including 15 optional evaluation contribution checks.
- Menu/settings/navigation: 81; setup: 112; rules: 37; inspection: 10;
  engine: 34; bridge: 56; piece upgrades: 73; piece bridge: 64; Retreat: 36.
- Existing UI: 9; engine UI: 21; native UI: 7; UX: 62; profiles: 9;
  extra armies: 70; Retreat UI: 15.
- Godot independent standard reference: 545 positions / 1652 checks;
  Retreat: 260 / 840; piece reference: 168 / 528.
- Native standard and Conservative references: each 545 positions / 1678 checks;
  Retreat: 260 / 840; piece reference: 168 / 696.
- Native protocol: 37; profile protocol: 16; Retreat protocol: 22;
  per-piece protocol: 18. Retreat playtest: 52 engine plies, zero failures.
- Clean ZIP extraction to a path with spaces: all manifests/hashes/path integrity,
  Linux executable modes, exported startup, native self-test, fresh project import,
  menu, upgrade, bridge, Retreat UI and standard reference tests passed.

## Actual Linux GUI walkthrough

Launched the extracted standalone from /tmp. Desktop window was 1180x812;
resized to 700x812 for the narrow checks. Visually verified:

1. Boot presents Create Sandbox Game, Settings and Quit, with no running match.
2. Settings shows one functional preference: Show board coordinates. Toggling it
   off hides file/rank labels. Back returns to menu; persistence is also tested
   using a fresh scene and an isolated preference file.
3. Create and cancel setup; then select e2 in Workshop, equip Pawn Retreat and
   Legendary rarity (one equipped ability, two reserved slots). Start, play e4,
   receive native Nf6, and right-click the pawn to inspect retreat destinations.
4. New Game opens the starting-army draft. Start requests confirmation. Cancel
   confirmation and cancel draft preserve the e4/Nf6 match and history.
5. Quit to Menu prompts; Cancel preserves match; confirm returns to the menu.
6. Start a local normal game, play e4 f6 Qh5+, repeatedly click Previous/Next
   across the check. Buttons remain at the same visible coordinates.
7. Resize narrow, scroll to history, repeat the same clicks without repositioning.
   Open New Game, scroll to placement tools, add a white knight on e3; cancel
   returns to the unedited historical position. Setup controls remain reachable.
8. Confirm Quit to Menu and click Quit; the game window disappears.

No GDScript/runtime game errors occurred. The desktop driver reports unsupported
VSync changes, and Godot prints existing native popup focus/tree disconnect
messages (also present in the previous build's GUI log); no observed functional
failure accompanied them. gui.log retains these diagnostics.

## Fresh import compatibility

An independent clean checkout rebuilt the native engine and passed 156 checks,
then Godot crashed during concurrent font import with a cross-thread node
notification error. The project now sets `editor/import/use_multiple_threads=false`
([Godot setting](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-editor-import-use-multiple-threads)).
Removing the generated cache and importing sequentially passed, followed by all
81 menu and 64 piece-bridge checks. The initial failure and successful rerun are
retained. This editor-only setting does not change native search threading.

## Platform limits

Windows x64 was cross-built/exported with its matching self-contained native
engine, and ZIP integrity/manifests and PE architecture were checked. It was not
executed on Windows; Linux GUI/native tests do not establish Windows execution.
There is no verified Elo claim and no new ability or progression system.
