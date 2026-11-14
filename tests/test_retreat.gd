extends SceneTree
const Rules = preload("res://rules.gd")
const Setup = preload("res://setup.gd")
const Bridge = preload("res://engine.gd")
var checks = 0
var failures = 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + msg)
func names(g) -> Array:
	var out = []
	for m in g.legal_moves(): out.append(Rules.uci_name(m))
	return out
func position(fen: String, ability: String = "both"):
	var g = Rules.new(); g.load_fen(fen); g.configure_retreat(ability); return g
func play(g, move: String) -> bool:
	for m in g.legal_moves():
		if Rules.uci_name(m) == move: return g.play(m)
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1")
	check("e4e3" in names(g), "White can retreat")
	check(not g.piece_attacks(Rules.square("e4"), Rules.square("e3")), "Retreat is not an attack")
	check(g.piece_attacks(Rules.square("e4"), Rules.square("d5")), "Forward attacks unchanged")
	check(play(g, "e4e3") and g.halfmove == 0 and g.ep == -1, "Retreat executes and resets pawn clock")
	check("e5e6" in names(g), "Black can retreat")
	check(play(g, "e5e6"), "Black retreat executes")
	g = position("7k/8/8/8/4P3/4n3/8/K7 w - - 0 1")
	check(not "e4e3" in names(g), "No backward capture")
	g = position("7k/8/8/8/4P3/4N3/8/K7 w - - 0 1")
	check(not "e4e3" in names(g), "Friendly blocker")
	g = position("7k/4p3/8/8/8/8/4P3/K7 w - - 0 1")
	check(not "e2e1" in names(g), "White cannot enter rank 1")
	g.turn = -1
	check(not "e7e8" in names(g), "Black cannot enter rank 8")
	g = position("7k/8/8/8/r3P2K/8/8/8 w - - 0 1")
	check(not "e4e3" in names(g), "Retreat cannot expose king")
	g = position("7k/8/8/8/4P3/r6K/8/8 w - - 0 1")
	check("e4e3" in names(g), "Retreat may block check")
	g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1", "white")
	check("e4e3" in names(g), "White-only ability")
	g.turn = -1
	check(not "e5e6" in names(g), "Black has no ability")
	g = position("7k/8/8/8/8/4P3/8/K7 w - - 0 1")
	check(play(g,"e3e2") and play(g,"h8g8") and "e2e4" in names(g), "Return to start rank permits forward double push")
	g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1")
	for i in 2:
		for move in ["e4e3", "e5e6", "e3e4", "e6e5"]: check(play(g,move), "Cycle " + move)
	check(g.claim_reason() == "threefold repetition", "Reversible pawns preserve repetition")
	check(g.copy_position(true).ability_state == g.ability_state, "History copies retain ability")
	g = position("7k/4P3/8/4p3/8/8/8/K7 w - e6 0 1")
	check(play(g, "e7e6") and g.board[Rules.square("e5")] == -Rules.PAWN, "Retreat onto EP target is not an EP capture")
	g = position("7k/8/8/8/4P3/8/8/K7 w - - 0 1")
	for m in g.legal_moves():
		if Rules.uci_name(m) == "e4e3": check(g.san(m) == "e4-e3", "Retreat notation includes source")
	var standard = Rules.new()
	check(standard.ability_state.is_empty() and names(standard).size() == 20, "Off baseline unchanged")
	var setup = Setup.new(); setup.set_retreat("white",true)
	check(setup.create_game().retreat_setting() == "white", "Setup transfers active rule")
	setup.reset_standard()
	check(setup.position.retreat_setting() == "none", "Board reset creates ordinary replacement pieces")
	var bridge = Bridge.new()
	check(bridge.effective_profile(g) == "conservative", "Ability forces conservative")
	check(bridge.effective_profile(standard) == "standard", "Off retains standard")
	# Real bridge searches also compare every legal move and attack for both sides.
	for ability in ["white", "black", "both"]:
		g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1", ability)
		var answer = Bridge.new().search(g,100)
		check(answer.error == "" and not answer.move.is_empty(), "Bridge " + ability + ": " + answer.error)
	g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1")
	play(g,"e4e3")
	var answer = Bridge.new().search(g,100)
	check(answer.error == "" and not answer.move.is_empty(), "Bridge replays backward history: " + answer.error)
	print("RETREAT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
