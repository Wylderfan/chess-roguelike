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
# Per-piece editor data. IDs and rarity are visual/progression metadata; only
# equipped abilities participate in legality, repetition and the native protocol.
const PAWN_RETREAT = "pawn_retreat"
const RARITIES = ["common", "rare", "legendary"]
var piece_data: Dictionary = {}
var initial_piece_data: Dictionary = {}
var initial_retreat_squares: Array = []
var next_piece_id: int = 1
# Schema 2: canonical CURRENT-square markers, empty for ordinary chess.
var ability_state: Dictionary = {}

func _init(setup: bool = true) -> void:
	if not setup: return
	load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

func load_fen(fen: String) -> void:
	initial_fen = fen
	move_log = []
	ability_state = {}
	piece_data = {}
	initial_piece_data = {}
	initial_retreat_squares = []
	next_piece_id = 1
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
	for s in board.size():
		if board[s] != 0: piece_data[s] = new_piece_data()
	refresh_initial_state()

static func ability_capacity(rarity: String) -> int:
	return 2 if rarity in ["rare", "legendary"] else (1 if rarity == "common" else 0)

static func ability_eligible(piece: int, ability: String) -> bool:
	return ability == PAWN_RETREAT and abs(piece) == PAWN

func new_piece_data() -> Dictionary:
	var used: Array = []
	for data in piece_data.values(): used.append(data.get("id", ""))
	while ("piece_%d" % next_piece_id) in used: next_piece_id += 1
	var data = {"id": "piece_%d" % next_piece_id, "rarity": "common", "abilities": []}
	next_piece_id += 1
	return data

func get_piece_data(s: int) -> Dictionary:
	return piece_data.get(s, {}).duplicate(true)

func piece_data_error() -> String:
	var ids: Array = []
	for s in piece_data:
		if not s is int or s < 0 or s >= 64 or board[s] == 0:
			return "Piece upgrades must belong to an occupied square."
		var data = piece_data[s]
		if not data is Dictionary or not data.get("id") is String or data.id.is_empty() or data.id in ids:
			return "Every placed piece needs a unique identity."
		ids.append(data.id)
		if not data.get("rarity") is String or not data.rarity in RARITIES:
			return "Piece rarity must be common, rare or legendary."
		if not data.get("abilities") is Array:
			return "Piece abilities must be a list."
		if data.abilities.size() > ability_capacity(data.rarity):
			return "This piece has more abilities than its rarity allows."
		var equipped: Array = []
		for ability in data.abilities:
			if not ability is String or not ability_eligible(board[s], ability):
				return "Pawn Retreat can only be assigned to a pawn; other abilities are not available."
			if ability in equipped: return "A piece cannot equip the same ability twice."
			equipped.append(ability)
	for s in board.size():
		if board[s] != 0 and not piece_data.has(s): return "Every placed piece needs upgrade metadata."
	return ""

func pawn_can_retreat(s: int) -> bool:
	if s < 0 or s >= board.size() or abs(board[s]) != PAWN: return false
	return PAWN_RETREAT in piece_data.get(s, {}).get("abilities", [])

func retreat_squares() -> Array:
	var squares: Array = []
	for s in board.size():
		if pawn_can_retreat(s): squares.append(name_of(s))
	squares.sort()
	return squares

func effective_ability_state() -> Dictionary:
	var squares = retreat_squares()
	return {} if squares.is_empty() else {PAWN_RETREAT: squares}

func sync_effective_abilities() -> void:
	ability_state = effective_ability_state()

# Only composition/fresh-game APIs capture the replay origin. Ordinary moves
# update current markers, leaving this initial snapshot immutable.
func refresh_initial_state() -> void:
	sync_effective_abilities()
	initial_piece_data = piece_data.duplicate(true)
	initial_retreat_squares = retreat_squares()
	history = {position_key(): 1}
	result = ""

func configure_piece_data(data: Dictionary) -> bool:
	if not move_log.is_empty(): return false
	var previous = piece_data
	piece_data = data.duplicate(true)
	if piece_data_error() != "":
		piece_data = previous
		return false
	for metadata in piece_data.values():
		var id: String = metadata.id
		if id.begins_with("piece_") and id.trim_prefix("piece_").is_valid_int():
			next_piece_id = maxi(next_piece_id, int(id.trim_prefix("piece_")) + 1)
	refresh_initial_state()
	return true

func set_piece_ability(s: int, ability: String, enabled: bool) -> bool:
	if not move_log.is_empty() or not piece_data.has(s) or not ability_eligible(board[s], ability): return false
	var data: Dictionary = piece_data[s]
	if enabled and not ability in data.abilities:
		if data.abilities.size() >= ability_capacity(data.rarity): return false
		data.abilities.append(ability)
	elif not enabled: data.abilities.erase(ability)
	refresh_initial_state()
	return true

func set_piece_rarity(s: int, rarity: String) -> bool:
	if not move_log.is_empty() or not piece_data.has(s) or not rarity in RARITIES: return false
	if piece_data[s].abilities.size() > ability_capacity(rarity): return false
	piece_data[s].rarity = rarity
	refresh_initial_state()
	return true

# Editor replacement is a new piece, even when replacing the same piece type.
func place_piece(s: int, piece: int) -> void:
	if not move_log.is_empty() or s < 0 or s >= 64 or abs(piece) > KING: return
	piece_data.erase(s)
	board[s] = piece
	if piece != 0: piece_data[s] = new_piece_data()
	refresh_initial_state()

func relocate_piece(source: int, target: int) -> void:
	if not move_log.is_empty() or source == target or source < 0 or target < 0 or source >= 64 or target >= 64 or board[source] == 0: return
	board[target] = board[source]
	board[source] = 0
	piece_data[target] = piece_data[source]
	piece_data.erase(source)
	refresh_initial_state()

# Compatibility convenience: equips the current starting pawn instances only.
# It never grants a side-wide power to pieces placed later.
func configure_retreat(value: String) -> void:
	assert(move_log.is_empty())
	assert(value in ["none", "white", "black", "both"])
	for s in piece_data:
		piece_data[s].abilities.erase(PAWN_RETREAT)
		if abs(board[s]) == PAWN and value in ["both", "white" if board[s] > 0 else "black"]:
			piece_data[s].abilities.append(PAWN_RETREAT)
	refresh_initial_state()

func retreat_setting() -> String:
	var white = retreat_enabled(1)
	var black = retreat_enabled(-1)
	return "both" if white and black else ("white" if white else ("black" if black else "none"))

func retreat_enabled(side: int) -> bool:
	for s in board.size():
		if board[s] * side > 0 and pawn_can_retreat(s): return true
	return false

func supported_abilities() -> bool:
	if piece_data_error() != "" or ability_state != effective_ability_state(): return false
	# Fail closed if a replay marker list was corrupted independently of its
	# original piece snapshot. Current markers may legitimately now be empty.
	var expected_initial: Array = []
	for s in initial_piece_data:
		if not s is int or s < 0 or s >= 64: return false
		var data = initial_piece_data[s]
		if not data is Dictionary or not data.get("abilities") is Array: return false
		for ability in data.abilities:
			if ability != PAWN_RETREAT: return false
			if name_of(s) in expected_initial: return false
			expected_initial.append(name_of(s))
	expected_initial.sort()
	return initial_retreat_squares == expected_initial

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
	c.piece_data = piece_data.duplicate(true)
	c.initial_piece_data = initial_piece_data.duplicate(true)
	c.initial_retreat_squares = initial_retreat_squares.duplicate()
	c.next_piece_id = next_piece_id
	c.result = result
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
			var back = a + 8 * turn
			if pawn_can_retreat(a) and back >= 8 and back < 56 and board[back] == 0:
				add_move(moves, a, back)
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
	if abs(piece) == PAWN and b == ep and captured == 0 and a % 8 != b % 8:
		board[b + 8 * turn] = 0
		piece_data.erase(b + 8 * turn)
	piece_data[b] = piece_data[a]
	piece_data.erase(a)
	if m.promotion != 0:
		# Rarity/identity survive promotion; pawn-only abilities do not.
		var kept: Array = []
		for ability in piece_data[b].abilities:
			if ability_eligible(int(m.promotion), ability): kept.append(ability)
		piece_data[b].abilities = kept
	board[b] = piece if m.promotion == 0 else turn * int(m.promotion)
	board[a] = 0
	if abs(piece) == KING:
		if abs(b - a) == 2:
			var rook = a + (3 if b > a else -4)
			board[a + (1 if b > a else -1)] = board[rook]
			board[rook] = 0
			piece_data[a + (1 if b > a else -1)] = piece_data[rook]
			piece_data.erase(rook)
		rights = rights.replace("K" if turn == 1 else "k", "").replace("Q" if turn == 1 else "q", "")
	for pair in [[0,"q"],[7,"k"],[56,"Q"],[63,"K"]]:
		if a == pair[0] or b == pair[0]: rights = rights.replace(pair[1], "")
	ep = (a + b) / 2 if abs(piece) == PAWN and abs(a - b) == 16 else -1
	halfmove = 0 if abs(piece) == PAWN or captured != 0 else halfmove + 1
	if turn == -1: fullmove += 1
	turn = -turn
	sync_effective_abilities()

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
		elif (m.to - m.from) * turn == 8: text = name_of(m.from) + "-"
		if capture: text += "x"
		text += name_of(m.to)
		if m.promotion != 0: text += "=" + "  NBRQK"[m.promotion]
	var after = copy_position()
	after.apply_unchecked(m)
	if after.in_check(after.turn): text += "#" if after.legal_moves().is_empty() else "+"
	return text
