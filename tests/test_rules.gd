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
func move(g, uci: String) -> bool:
	return g.play({"from": Rules.square(uci.substr(0,2)), "to": Rules.square(uci.substr(2,2)), "promotion": " pnbrqk".find(uci[4]) if uci.length() == 5 else 0})
func has(g, uci: String) -> bool:
	for m in g.legal_moves():
		if m.from == Rules.square(uci.substr(0,2)) and m.to == Rules.square(uci.substr(2,2)): return true
	return false
func perft(g, depth: int) -> int:
	if depth == 0: return 1
	var count = 0
	for m in g.legal_moves():
		var c = g.copy_position()
		c.apply_unchecked(m)
		count += perft(c, depth - 1)
	return count
func _initialize() -> void:
	var g = Rules.new()
	check(perft(g,1) == 20, "Initial perft depth 1: 20")
	check(perft(g,2) == 400, "Initial perft depth 2: 400")
	check(perft(g,3) == 8902, "Initial perft depth 3: 8902")
	g = position("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(perft(g,1) == 48, "Kiwipete depth 1: 48")
	check(perft(g,2) == 2039, "Kiwipete depth 2: 2039")
	g = position("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(perft(g,3) == 2812, "Endgame/en-passant perft depth 3: 2812")
	g = position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	check(has(g,"e1g1") and has(g,"e1c1"), "Both castles available")
	check(move(g,"e1g1") and g.board[61] == 4 and g.board[63] == 0 and not g.rights.contains("K"), "Castling relocates rook and removes rights")
	g = position("4kr2/8/8/8/8/8/8/4K2R w K - 0 1")
	check(not has(g,"e1g1"), "Cannot castle across attacked f1")
	g = position("4k1r1/8/8/8/8/8/8/4K2R w K - 0 1")
	check(not has(g,"e1g1"), "Cannot castle into check")
	g = position("4r1k1/8/8/8/8/8/8/4K2R w K - 0 1")
	check(not has(g,"e1g1"), "Cannot castle out of check")
	g = position("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
	move(g,"h1h2"); move(g,"e8e7"); move(g,"h2h1"); move(g,"e7e8")
	check(not has(g,"e1g1"), "Rook return does not restore castling rights")
	g = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	check(move(g,"e5d6") and g.board[Rules.square("d5")] == 0, "En passant removes captured pawn")
	g = position("k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	check(not has(g,"e5d6"), "Pinned en passant is illegal")
	var key = g.position_key()
	g.ep = -1
	check(key == g.position_key(), "Illegal en passant does not alter repetition identity")
	g = position("4k3/8/8/r4pPK/8/8/8/8 w - f6 0 1")
	check(not has(g,"g5f6"), "En passant cannot expose horizontal rook check")
	g = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	key = g.position_key(); g.ep = -1
	check(key != g.position_key(), "Legal en passant changes repetition identity")
	g = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	move(g,"e1f1"); move(g,"e8f8")
	check(not has(g,"e5d6"), "En passant expires after one turn")
	g = position("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	var promotions = 0
	for m in g.legal_moves():
		if m.from == 8: promotions += 1
	check(promotions == 4 and move(g,"a7a8n") and g.board[0] == 2, "Four promotion choices and knight underpromotion")
	g = position("4k3/8/8/8/8/8/p7/4K3 b - - 0 1")
	check(move(g,"a2a1q") and g.board[56] == -5, "Black promotion")
	g = Rules.new()
	move(g,"f2f3"); move(g,"e7e5"); move(g,"g2g4"); move(g,"d8h4")
	check(g.result == "Black wins — checkmate", "Fool's mate")
	check(not move(g,"a2a3"), "No moves after game end")
	g = position("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	g.update_result()
	check(g.result == "Draw — stalemate", "Stalemate")
	g = position("4k3/8/8/8/8/8/4r3/4K3 w - - 0 1")
	check(has(g,"e1e2"), "King may capture an unprotected checking rook")
	g = position("8/8/8/8/8/4k3/4r3/4K3 w - - 0 1")
	check(not has(g,"e1e2"), "King cannot capture protected piece")
	g = Rules.new()
	check(not move(g,"e2e5"), "Reject illegal move")
	for cycle in 2:
		move(g,"g1f3"); move(g,"g8f6"); move(g,"f3g1"); move(g,"f6g8")
	check(g.claim_reason() == "threefold repetition" and g.result == "", "Threefold is claimable, not automatic")
	check(g.claim_draw() and g.result.contains("threefold"), "Threefold claim ends game")
	g = Rules.new()
	for cycle in 4:
		move(g,"g1f3"); move(g,"g8f6"); move(g,"f3g1"); move(g,"f6g8")
	check(g.result == "Draw — fivefold repetition", "Fivefold is automatic")
	g = position("4k3/8/8/8/8/8/8/R3K3 w - - 99 1")
	move(g,"a1a2")
	check(g.claim_reason() == "50-move rule", "50-move claim threshold")
	g = position("4k3/8/8/8/8/8/8/R3K3 w - - 149 1")
	move(g,"a1a2")
	check(g.result == "Draw — 75-move rule", "75-move automatic threshold")
	g = position("7k/8/5KQ1/8/8/8/8/8 w - - 149 1")
	move(g,"g6g7")
	check(g.result == "White wins — checkmate", "Checkmate takes precedence over 75-move draw")
	for fen in ["4k3/8/8/8/8/8/8/4K3 w - - 0 1", "4k3/8/8/8/8/8/8/2B1K3 w - - 0 1", "4k3/8/8/8/8/8/8/2N1K3 w - - 0 1", "4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1"]:
		g = position(fen)
		check(g.insufficient_material(), "Recognized dead material: " + fen)
	g = position("4k3/8/8/8/8/8/8/1NN1K3 w - - 0 1")
	check(not g.insufficient_material(), "Two knights are not automatically dead")
	print("RULES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
