extends SceneTree
const Rules = preload("res://rules.gd")
var failures = 0
var checks = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else: print("PASS: " + label)
func position(fen: String):
	var g = Rules.new()
	g.load_fen(fen)
	return g
func targets(preview: Dictionary) -> Array:
	var result: Array = []
	for m in preview.moves: result.append(m.to)
	return result
func _initialize() -> void:
	var g = Rules.new()
	var state = [g.board.duplicate(),g.turn,g.rights,g.ep,g.halfmove,g.history.duplicate()]
	var p = g.inspect_piece(Rules.square("e7"))
	check(p.hypothetical and Rules.square("e5") in targets(p) and Rules.square("e6") in targets(p), "Off-turn pawn shows hypothetical pushes")
	check(Rules.square("d6") in p.attacks and Rules.square("f6") in p.attacks and not Rules.square("e6") in p.attacks, "Pawn attacks empty diagonals, not push squares")
	check(state == [g.board,g.turn,g.rights,g.ep,g.halfmove,g.history], "Inspection preserves complete state")
	p = g.inspect_piece(Rules.square("b1"))
	check(Rules.square("d2") in p.attacks and not Rules.square("d2") in targets(p), "Knight protects friendly piece without legal capture")
	g = position("4r1k1/8/8/8/8/8/4N3/4K3 w - - 0 1")
	p = g.inspect_piece(Rules.square("e2"))
	check(p.moves.is_empty() and p.attacks.size() > 0, "Pinned knight still attacks but cannot legally move")
	g = position("4kr2/8/8/8/8/8/8/4K2R w K - 0 1")
	p = g.inspect_piece(Rules.square("e1"))
	check(not Rules.square("g1") in targets(p) and not Rules.square("f1") in targets(p) and Rules.square("f1") in p.attacks, "King attacks differ from safe moves and castling transit")
	g = position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
	p = g.inspect_piece(Rules.square("e1"))
	check(Rules.square("g1") in targets(p) and not Rules.square("g1") in p.attacks, "Castling is a move, not a king attack")
	g = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	p = g.inspect_piece(Rules.square("e5"))
	check(Rules.square("d6") in targets(p), "On-turn legal en passant shown")
	g.turn = -1
	p = g.inspect_piece(Rules.square("e5"))
	check(p.hypothetical and not Rules.square("d6") in targets(p), "Off-turn preview never inherits en passant")
	g = position("k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	p = g.inspect_piece(Rules.square("e5"))
	check(not Rules.square("d6") in targets(p) and Rules.square("d6") in p.attacks, "Illegal pinned en passant remains a pawn attack only")
	print("INSPECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
