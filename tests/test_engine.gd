extends SceneTree
const Rules = preload("res://rules.gd")
const EngineAI = preload("res://engine.gd")
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
func uci(m: Dictionary) -> String:
	if m.is_empty(): return "none"
	return Rules.name_of(m.from) + Rules.name_of(m.to) + (" pnbrqk"[m.promotion] if m.promotion else "")
func analyze(g, budget = 1100, depth = 4) -> Dictionary:
	var state = [g.board.duplicate(), g.turn, g.rights, g.ep, g.halfmove, g.history.duplicate(), g.result]
	var answer = EngineAI.new().search(g.copy_position(true), budget, depth)
	check(state == [g.board, g.turn, g.rights, g.ep, g.halfmove, g.history, g.result], "Search preserves all live position state")
	check(answer.move.is_empty() or g.legal_moves().has(answer.move), "Search returns a legal move")
	print("BENCH move=%s depth=%d nodes=%d elapsed_ms=%d score=%d" % [uci(answer.move), answer.depth, answer.nodes, answer.elapsed_ms, answer.score])
	return answer
func _initialize() -> void:
	var g = position("7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
	var answer = analyze(g)
	g.play(answer.move)
	check(g.result == "White wins — checkmate", "Find mate in one")
	# Queen mate in two: no mate in one, but Qg5 forces Kh7 and Qg7#.
	g = position("7k/8/5K2/4Q3/8/8/8/8 w - - 0 1")
	answer = analyze(g, 2600, 5)
	check(answer.score == EngineAI.MATE - 3, "See forced mate in two")
	g = position("4k3/8/8/8/3q4/8/3R4/4K3 w - - 0 1")
	answer = analyze(g)
	check(uci(answer.move) == "d2d4", "Capture hanging queen")
	# A defended pawn is poison for the queen; quiescence sees the rook recapture.
	g = position("3rk3/8/8/3p4/8/8/3Q4/4K3 w - - 0 1")
	answer = analyze(g)
	check(uci(answer.move) != "d2d5", "Avoid poisoned pawn / immediate recapture")
	# Scholar's mate threat, with Qxf7# available unless Black responds.
	g = position("r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 1")
	answer = analyze(g, 2600, 4)
	g.play(answer.move)
	var allows_mate = false
	for m in g.legal_moves():
		var c = g.copy_position(true)
		c.play(m)
		if c.result.contains("checkmate"): allows_mate = true
	check(not allows_mate, "Avoid immediate mate when defense exists")
	g = position("7k/P7/8/8/8/8/8/4K3 w - - 0 1")
	answer = analyze(g)
	check(answer.move.promotion == Rules.QUEEN, "Choose ordinary queen promotion")
	# c8=Q is stalemate; c8=R forces Ka6 and Ra8#.
	g = position("8/k1P5/2K5/8/8/8/8/1N6 w - - 0 1")
	answer = analyze(g, 2600, 5)
	check(uci(answer.move) == "c7c8r" and answer.score == EngineAI.MATE - 3, "Rook underpromotion avoids stalemate and forces mate")
	g = Rules.new()
	for pair in [[300,2],[1100,4],[2600,6]]:
		answer = analyze(g, pair[0], pair[1])
		check(answer.elapsed_ms < pair[0] + 300, "Search respects budget with bounded node completion")
	var engine = EngineAI.new()
	engine.cancel()
	answer = engine.search(g.copy_position(true), 2600, 6)
	check(answer.depth == 0 and answer.elapsed_ms < 100, "Pre-canceled search exits promptly")
	g = position("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	answer = analyze(g)
	check(answer.move.is_empty(), "No move in stalemate")
	print("ENGINE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
