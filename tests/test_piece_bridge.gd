extends SceneTree
const Rules = preload("res://rules.gd")
const Bridge = preload("res://engine.gd")
# Record the actual handshake, retaining the production verifier's complete
# both-side legal-move and every-piece geometric-attack comparisons.
class RecordingBridge:
	extends "res://engine.gd"
	var observed_snapshot: Dictionary = {}
	func verify_snapshot(g: ChessRules, data: Dictionary) -> String:
		observed_snapshot = data.duplicate(true)
		return super.verify_snapshot(g, data)

var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else: print("PASS: " + message)
func play(g, uci: String) -> bool:
	for m in g.legal_moves():
		if Rules.uci_name(m) == uci: return g.play(m)
	return false
func fixture(label: String, fen: String, initial_markers: Array, moves: Array, current_markers: Array) -> void:
	var g = Rules.new()
	g.load_fen(fen)
	for square in initial_markers:
		check(g.set_piece_ability(Rules.square(square),Rules.PAWN_RETREAT,true), label + ": equip " + square)
	var original = g.initial_piece_data.duplicate(true)
	for uci in moves:
		if not play(g,uci):
			check(false,label + ": legal replay move " + uci)
			return
	check(g.move_log == moves and not g.move_log.is_empty(),label + ": exact nonempty move history retained")
	check(g.initial_fen == fen and g.initial_piece_data == original and g.initial_retreat_squares == initial_markers,label + ": immutable original FEN and upgrades retained")
	check(g.retreat_squares() == current_markers and g.supported_abilities(),label + ": current effective markers correct")
	var bridge = RecordingBridge.new()
	bridge.rules_profile = "standard"
	check(bridge.effective_profile(g) == "conservative",label + ": original upgrades force Conservative after replay")
	var answer = bridge.search(g.copy_position(true),50)
	check(answer.error == "" and not answer.canceled and not answer.move.is_empty() and g.legal_moves().has(answer.move),label + ": real engine returns legal move; " + answer.error)
	var snapshot = bridge.observed_snapshot
	check(not snapshot.is_empty(),label + ": actual native handshake observed")
	check(snapshot.get("profile","") == "conservative",label + ": actual native profile remains Conservative")
	check(snapshot.get("schema",-1) == (0 if current_markers.is_empty() else 2) and snapshot.get("abilities_empty",false) == current_markers.is_empty(),label + ": actual native current schema/empty flag correct")
	check(snapshot.get("retreat_squares",[]) == current_markers,label + ": actual native current marker squares match")
	check(not snapshot.is_empty() and bridge.verify_snapshot(g,snapshot) == "",label + ": exact both-side legality and all threats agree after replay")
	check(g.move_log == moves and g.initial_piece_data == original,label + ": engine search leaves original game untouched")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# An earlier backward move makes replay dependent on the initial marker,
	# even though the snapshot at the end must have schema 0 and no markers.
	fixture("Capture last upgrade",
		"7k/8/8/8/4P3/r7/8/1K6 w - - 0 1",["e4"],
		["e4e3","a3e3"],[])
	fixture("Promotion removes last upgrade",
		"7k/P7/8/8/8/8/8/1K6 w - - 0 1",["a7"],
		["a7a6","h8h7","a6a7","h7g6","a7a8q"],[])
	# Black first retreats to its home rank, then double-pushes and is taken
	# en passant by an ordinary pawn. No upgraded pawn remains.
	fixture("EP removes last upgrade",
		"7k/8/3p4/4P3/8/8/8/K7 b - - 0 1",["d6"],
		["d6d7","a1a2","d7d5","e5d6"],[])
	fixture("EP preserves capturing upgrade",
		"7k/8/8/3pP3/8/8/8/K7 w - d6 0 1",["d5","e5"],
		["e5d6"],["d6"])
	fixture("Mixed pawns on both sides",
		"7k/8/3pp3/8/3PP3/8/8/K7 w - - 0 1",["d6","e4"],
		["e4e3","d6d7","d4d5","e6e5","e3e4","d7d6"],["d6","e4"])
	var ordinary = Rules.new()
	var bridge = RecordingBridge.new()
	var answer = bridge.search(ordinary,50)
	check(answer.error == "" and not answer.move.is_empty(),"Ordinary game still searches successfully: " + answer.error)
	check(bridge.observed_snapshot.get("schema",-1) == 0 and bridge.observed_snapshot.get("profile","") == "standard","Fresh ordinary game does not inherit previous Conservative/upgrade configuration")
	print("PIECE BRIDGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
