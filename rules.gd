class_name ChessRules
extends RefCounted
# Squares are 0=a8 ... 63=h1. Positive pieces are White.
const PAWN = 1
const KNIGHT = 2
const BISHOP = 3
const ROOK = 4
const QUEEN = 5
const KING = 6
var board: Array = []
var turn: int = 1
var rights: String = "KQkq"
var ep: int = -1
var halfmove: int = 0
var fullmove: int = 1
var history: Dictionary = {}
var result: String = ""
var initial_fen: String = ""
var move_log: Array = []
# Empty schema only. Non-empty abilities are rejected by the v0.3 bridge.
var ability_state: Dictionary = {}

func _init(setup: bool = true) -> void:
	if not setup: return
	load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

func load_fen(fen: String) -> void:
	initial_fen = fen
	move_log = []
	ability_state = {}
	var fields = fen.split(" ")
	board.clear()
	for c in fields[0]:
		if c == "/": continue
		if c.is_valid_int():
			for n in int(c): board.append(0)
		else:
			var p = " pnbrqk".find(c.to_lower())
			board.append(p if c == c.to_upper() else -p)
	turn = 1 if fields[1] == "w" else -1
	rights = fields[2].replace("-", "")
	ep = -1 if fields[3] == "-" else square(fields[3])
	halfmove = int(fields[4]) if fields.size() > 4 else 0
	fullmove = int(fields[5]) if fields.size() > 5 else 1
	result = ""
	history = {}
	history[position_key()] = 1

static func square(s: String) -> int:
	return (8 - int(s[1])) * 8 + "abcdefgh".find(s[0])

static func name_of(s: int) -> String:
	return "abcdefgh"[s % 8] + str(8 - s / 8)

func copy_position(include_history: bool = false) -> ChessRules:
	var c = ChessRules.new(false)
	c.board = board.duplicate()
	c.turn = turn
	c.rights = rights
	c.ep = ep
	c.halfmove = halfmove
	c.fullmove = fullmove
	c.initial_fen = initial_fen
	c.move_log = move_log.duplicate()
	c.ability_state = ability_state.duplicate(true)
	if include_history: c.history = history.duplicate()
	return c

# Geometric attacks include friendly occupied endpoints, pawn diagonals and
# pinned pieces. They exclude pawn pushes, castling and en-passant destinations.
# King safety and inspection both use this single definition of an attack.
func piece_attacks(a: int, target: int) -> bool:
	var piece: int = board[a]
	if piece == 0 or a == target: return false
	var dx = target % 8 - a % 8
	var dy = target / 8 - a / 8
	var p = abs(piece)
	if p == PAWN: return dy == -sign(piece) and abs(dx) == 1
	if p == KNIGHT: return abs(dx) * abs(dy) == 2
	if p == KING: return maxi(abs(dx), abs(dy)) == 1
	var diagonal = abs(dx) == abs(dy) and dx != 0
	var straight = (dx == 0) != (dy == 0)
	if (diagonal and p in [BISHOP, QUEEN]) or (straight and p in [ROOK, QUEEN]):
		var step = sign(dx) + 8 * sign(dy)
		var j = a + step
		while j != target and board[j] == 0: j += step
		return j == target
	return false

func attacked(s: int, by: int) -> bool:
	for i in 64:
		if board[i] * by > 0 and piece_attacks(i, s): return true
	return false

func inspect_piece(a: int) -> Dictionary:
	var preview = {"moves": [], "attacks": [], "hypothetical": false}
	if a < 0 or a >= 64 or board[a] == 0: return preview
	var side = int(sign(board[a]))
	preview.hypothetical = side != turn
	var c = copy_position()
	c.turn = side
	# The other side cannot inherit this turn's one-move en-passant right.
	if side != turn: c.ep = -1
	for m in c.legal_moves():
		if m.from == a: preview.moves.append(m)
	for target in 64:
		if piece_attacks(a, target): preview.attacks.append(target)
	return preview

func in_check(side: int) -> bool:
	var king = board.find(side * KING)
	return king == -1 or attacked(king, -side)

func add_move(moves: Array, a: int, b: int) -> void:
	if abs(board[a]) == PAWN and b / 8 in [0, 7]:
		for p in [QUEEN, ROOK, BISHOP, KNIGHT]: moves.append({"from": a, "to": b, "promotion": p})
	else: moves.append({"from": a, "to": b, "promotion": 0})

func pseudo_moves() -> Array:
	var moves: Array = []
	for a in 64:
		if board[a] * turn <= 0: continue
		var p = abs(board[a])
		var x = a % 8
		var y = a / 8
		if p == PAWN:
			var b = a - 8 * turn
			if b >= 0 and b < 64 and board[b] == 0:
				add_move(moves, a, b)
				if y == (6 if turn == 1 else 1) and board[a - 16 * turn] == 0: add_move(moves, a, a - 16 * turn)
			for dx in [-1, 1]:
				b = a - 8 * turn + dx
				if x + dx < 0 or x + dx > 7 or b < 0 or b > 63: continue
				if (board[b] * turn < 0 and abs(board[b]) != KING) or (b == ep and board[b] == 0 and board[b + 8 * turn] == -turn * PAWN): add_move(moves, a, b)
			continue
		var directions: Array = []
		if p == KNIGHT: directions = [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]
		else:
			if p in [BISHOP, QUEEN, KING]: directions.append_array([Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)])
			if p in [ROOK, QUEEN, KING]: directions.append_array([Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)])
		for d in directions:
			var pos = Vector2i(x,y) + d
			while pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8:
				var b = pos.y * 8 + pos.x
				if board[b] * turn > 0 or abs(board[b]) == KING: break
				add_move(moves, a, b)
				if board[b] != 0 or p in [KNIGHT, KING]: break
				pos += d
		if p == KING:
			var home = 60 if turn == 1 else 4
			if a != home or in_check(turn): continue
			for king_side in [true, false]:
				var right = ("K" if king_side else "Q") if turn == 1 else ("k" if king_side else "q")
				var rook = home + (3 if king_side else -4)
				var direction = 1 if king_side else -1
				if not rights.contains(right) or board[rook] != turn * ROOK: continue
				var clear = true
				for j in range(home + direction, rook, direction):
					if board[j] != 0: clear = false
				if clear and not attacked(home + direction, -turn) and not attacked(home + 2 * direction, -turn): add_move(moves, home, home + 2 * direction)
	return moves

func legal_moves() -> Array:
	var moves: Array = []
	for m in pseudo_moves():
		var c = copy_position()
		c.apply_unchecked(m)
		if not c.in_check(turn): moves.append(m)
	return moves

# Internal simulation only. Public play() validates against legal moves.
func apply_unchecked(m: Dictionary) -> void:
	var a: int = m.from
	var b: int = m.to
	var piece: int = board[a]
	var captured: int = board[b]
	if abs(piece) == PAWN and b == ep and captured == 0: board[b + 8 * turn] = 0
	board[b] = piece if m.promotion == 0 else turn * int(m.promotion)
	board[a] = 0
	if abs(piece) == KING:
		if abs(b - a) == 2:
			var rook = a + (3 if b > a else -4)
			board[a + (1 if b > a else -1)] = board[rook]
			board[rook] = 0
		rights = rights.replace("K" if turn == 1 else "k", "").replace("Q" if turn == 1 else "q", "")
	for pair in [[0,"q"],[7,"k"],[56,"Q"],[63,"K"]]:
		if a == pair[0] or b == pair[0]: rights = rights.replace(pair[1], "")
	ep = (a + b) / 2 if abs(piece) == PAWN and abs(a - b) == 16 else -1
	halfmove = 0 if abs(piece) == PAWN or captured != 0 else halfmove + 1
	if turn == -1: fullmove += 1
	turn = -turn

func position_key() -> String:
	# An en-passant target only distinguishes repetitions if capture is legal.
	var effective_ep = -1
	if ep != -1:
		for m in legal_moves():
			if m.to == ep and abs(board[m.from]) == PAWN and m.from % 8 != ep % 8: effective_ep = ep
	return str(board) + str(turn) + rights + str(effective_ep) + (str(ability_state) if not ability_state.is_empty() else "")

func play(m: Dictionary) -> bool:
	if result != "" or not legal_moves().has(m): return false
	apply_unchecked(m)
	move_log.append(uci_name(m))
	var key = position_key()
	history[key] = history.get(key, 0) + 1
	update_result()
	return true

func insufficient_material() -> bool:
	var minors: Array = []
	for i in 64:
		var p = abs(board[i])
		if p in [PAWN, ROOK, QUEEN]: return false
		if p in [BISHOP, KNIGHT]: minors.append(i)
	if minors.size() <= 1: return true
	var color = -1
	for i in minors:
		if abs(board[i]) != BISHOP: return false
		var c = (i % 8 + i / 8) % 2
		if color != -1 and color != c: return false
		color = c
	return true

func claim_reason() -> String:
	if history.get(position_key(), 0) >= 3: return "threefold repetition"
	if halfmove >= 100: return "50-move rule"
	return ""

func claim_draw() -> bool:
	var reason = claim_reason()
	if result != "" or reason == "": return false
	result = "Draw — " + reason
	return true

func update_result() -> void:
	if legal_moves().is_empty():
		result = ("Black" if turn == 1 else "White") + " wins — checkmate" if in_check(turn) else "Draw — stalemate"
	elif insufficient_material(): result = "Draw — insufficient material"
	elif history.get(position_key(), 0) >= 5: result = "Draw — fivefold repetition"
	elif halfmove >= 150: result = "Draw — 75-move rule"

static func uci_name(m: Dictionary) -> String:
	return name_of(m.from) + name_of(m.to) + (" pnbrqk"[m.promotion] if m.promotion else "")

func uci_position() -> String:
	return "position fen " + initial_fen + (" moves " + " ".join(move_log) if not move_log.is_empty() else "")

# SAN and material reporting use the same legal moves and transitions as play.
func captured_piece(m: Dictionary) -> int:
	var victim: int = board[m.to]
	if abs(board[m.from]) == PAWN and m.to == ep and victim == 0 and m.from % 8 != m.to % 8:
		victim = board[m.to + 8 * turn]
	return victim

func material_balance() -> int:
	var values = [0, 1, 3, 3, 5, 9, 0]
	var balance = 0
	for piece in board: balance += int(sign(piece)) * values[abs(piece)]
	return balance

func san(m: Dictionary) -> String:
	var moves = legal_moves()
	if not moves.has(m): return ""
	var piece = abs(board[m.from])
	var capture = captured_piece(m) != 0
	var text = ""
	if piece == KING and abs(m.to - m.from) == 2:
		text = "O-O" if m.to > m.from else "O-O-O"
	else:
		if piece != PAWN:
			text = "  NBRQK"[piece]
			var ambiguous = false
			var same_file = false
			var same_rank = false
			for other in moves:
				if other.from != m.from and other.to == m.to and board[other.from] == board[m.from]:
					ambiguous = true
					same_file = same_file or other.from % 8 == m.from % 8
					same_rank = same_rank or other.from / 8 == m.from / 8
			if ambiguous:
				if not same_file: text += name_of(m.from)[0]
				elif not same_rank: text += name_of(m.from)[1]
				else: text += name_of(m.from)
		elif capture: text = name_of(m.from)[0]
		if capture: text += "x"
		text += name_of(m.to)
		if m.promotion != 0: text += "=" + "  NBRQK"[m.promotion]
	var after = copy_position()
	after.apply_unchecked(m)
	if after.in_check(after.turn): text += "#" if after.legal_moves().is_empty() else "+"
	return text
