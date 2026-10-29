class_name BaselineChessEngine
extends RefCounted
# Pure rules objects only: this worker never touches the scene or live game.
# Future abilities belong in ChessRules' legal moves, attacks and transitions.
# Update evaluation()/move_score() for new strategic values, not move legality.
const Rules = preload("res://rules.gd")
const MATE = 100000
const INF = 1000000
const VALUES = [0, 100, 320, 335, 500, 900, 0]
var mutex = Mutex.new()
var canceled = false
var deadline = 0
var nodes = 0
var stopped = false
var table: Dictionary = {}
var root_best: Dictionary = {}

func cancel() -> void:
	mutex.lock()
	canceled = true
	mutex.unlock()

func should_stop() -> bool:
	mutex.lock()
	var stop = canceled
	mutex.unlock()
	if stop or Time.get_ticks_msec() >= deadline:
		stopped = true
	return stopped

# Called on a Thread by the scene, or synchronously by benchmark scripts.
func search(position: ChessRules, milliseconds: int, max_depth: int = 6) -> Dictionary:
	var start = Time.get_ticks_msec()
	deadline = start + milliseconds
	nodes = 0
	stopped = false
	table.clear()
	var moves = ordered(position, position.legal_moves())
	var output = {"move": {}, "depth": 0, "nodes": 0, "score": 0, "elapsed_ms": 0, "claim": false}
	if moves.is_empty() or position.result != "": return output
	output.move = moves[0] # A legal fallback even if no iteration completes.
	for depth in range(1, max_depth + 1):
		root_best = {}
		var score = negamax(position, depth, -INF, INF, 0)
		if stopped: break
		output.depth = depth
		output.score = score
		if not root_best.is_empty(): output.move = root_best
		# Drawing is an option, never a forced result at the claim threshold.
		output.claim = position.claim_reason() != "" and score <= 0
		if abs(score) >= MATE - 100: break
	output.nodes = nodes
	output.elapsed_ms = Time.get_ticks_msec() - start
	return output

func child(g: ChessRules, m: Dictionary) -> ChessRules:
	var c = g.copy_position(true)
	c.apply_unchecked(m)
	var key = c.position_key()
	c.history[key] = c.history.get(key, 0) + 1
	return c

func automatic_draw(g: ChessRules) -> bool:
	return g.halfmove >= 150 or g.history.get(g.position_key(), 0) >= 5 or g.insufficient_material()

func negamax(g: ChessRules, depth: int, alpha_in: int, beta: int, ply: int) -> int:
	nodes += 1
	if should_stop(): return 0
	if depth <= 0: return quiescence(g, alpha_in, beta, ply, 0)
	var moves = g.legal_moves()
	if moves.is_empty(): return -MATE + ply if g.in_check(g.turn) else 0
	if automatic_draw(g): return 0
	var alpha = alpha_in
	var best = -INF
	if g.claim_reason() != "":
		best = 0
		alpha = maxi(alpha, 0)
		if alpha >= beta: return alpha
	var key = g.position_key()
	var preferred: Dictionary = table.get(key, {})
	var best_move: Dictionary = {}
	for m in ordered(g, moves, preferred):
		var score = -negamax(child(g, m), depth - 1, -beta, -alpha, ply + 1)
		if stopped: return 0
		if score > best:
			best = score
			best_move = m
			if ply == 0: root_best = m
		alpha = maxi(alpha, score)
		if alpha >= beta: break
	# Store ordering only: scores would require history-aware draw keys and bounds.
	if not best_move.is_empty(): table[key] = best_move
	return best

func quiescence(g: ChessRules, alpha_in: int, beta: int, ply: int, qdepth: int) -> int:
	nodes += 1
	if should_stop(): return 0
	var moves = g.legal_moves()
	var checked = g.in_check(g.turn)
	if moves.is_empty(): return -MATE + ply if checked else 0
	if automatic_draw(g): return 0
	var alpha = alpha_in
	if g.claim_reason() != "":
		alpha = maxi(alpha, 0)
		if alpha >= beta: return alpha
	var stand = evaluation(g)
	# Bounded extension keeps perpetual checks from exhausting the call stack.
	if qdepth >= 10: return maxi(alpha, stand)
	if not checked:
		if stand >= beta: return stand
		alpha = maxi(alpha, stand)
	for m in ordered(g, moves):
		if not checked and not is_tactical(g, m): continue
		var score = -quiescence(child(g, m), -beta, -alpha, ply + 1, qdepth + 1)
		if stopped: return 0
		if score >= beta: return score
		alpha = maxi(alpha, score)
	return alpha

func is_tactical(g: ChessRules, m: Dictionary) -> bool:
	return g.board[m.to] != 0 or m.promotion != 0 or (abs(g.board[m.from]) == Rules.PAWN and m.to == g.ep)

func ordered(g: ChessRules, moves: Array, preferred: Dictionary = {}) -> Array:
	var scored: Array = []
	for m in moves:
		var score = move_score(g, m)
		if m == preferred: score += 100000
		scored.append({"move": m, "score": score})
	scored.sort_custom(func(a, b): return a.score > b.score)
	var out: Array = []
	for entry in scored: out.append(entry.move)
	return out

func move_score(g: ChessRules, m: Dictionary) -> int:
	var victim = abs(g.board[m.to])
	if abs(g.board[m.from]) == Rules.PAWN and m.to == g.ep: victim = Rules.PAWN
	return (10000 + VALUES[victim] * 10 - VALUES[abs(g.board[m.from])] if victim else 0) + VALUES[m.promotion]

func evaluation(g: ChessRules) -> int:
	var score = 0
	var non_pawn = 0
	for p in g.board:
		if abs(p) in [Rules.KNIGHT, Rules.BISHOP, Rules.ROOK, Rules.QUEEN]: non_pawn += VALUES[abs(p)]
	var bishop_count = {1: 0, -1: 0}
	for s in 64:
		var piece: int = g.board[s]
		if piece == 0: continue
		var side = int(sign(piece))
		var p = abs(piece)
		var x = s % 8
		var y = s / 8 if side == 1 else 7 - s / 8
		var center = 7 - (absi(2 * x - 7) + absi(2 * y - 7)) / 2
		var bonus = 0
		match p:
			Rules.PAWN:
				bonus = (6 - y) * 9 + center * 3
				if x in [3,4]: bonus += (6 - y) * 5
			Rules.KNIGHT: bonus = center * 11 - (18 if y == 7 else 0)
			Rules.BISHOP:
				bonus = center * 6
				bishop_count[side] += 1
			Rules.ROOK: bonus = 18 if y == 1 else 0
			Rules.QUEEN: bonus = center * 3
			Rules.KING:
				if non_pawn < 2200: bonus = center * 12
				else:
					bonus = -center * 10
					if y == 7 and x in [1,2,6]: bonus += 45
		score += side * (VALUES[p] + bonus)
	if bishop_count[1] >= 2: score += 30
	if bishop_count[-1] >= 2: score -= 30
	return score * g.turn
