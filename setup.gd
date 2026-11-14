class_name ChessSetup
extends RefCounted
const MAX_PIECES_PER_SIDE = 32
const Rules = preload("res://rules.gd")
const PLANNED_ABILITIES = ["Pawn Dash", "Bishop Sidestep", "Queen Exchange"]
var position = Rules.new()
# Configuration intent only: NEVER copied into ChessRules.ability_state or UCI.
var planned = {"white": [], "black": []}

func reset_standard() -> void:
	position = Rules.new()

func edit(square: int, piece: int) -> void:
	if square < 0 or square >= 64 or abs(piece) > Rules.KING: return
	clear_touched_rights(square)
	position.board[square] = piece
	position.ep = -1

func relocate(source: int, target: int) -> void:
	if source == target or source < 0 or target < 0 or source >= 64 or target >= 64: return
	clear_touched_rights(source)
	clear_touched_rights(target)
	position.board[target] = position.board[source]
	position.board[source] = 0
	position.ep = -1

func clear_rights() -> void:
	position.rights = ""
	position.ep = -1

const CASTLING_PAIRS = {"K": [60,63,1], "Q": [60,56,1], "k": [4,7,-1], "q": [4,0,-1]}

func clear_touched_rights(square: int) -> void:
	for right in CASTLING_PAIRS:
		if square in [CASTLING_PAIRS[right][0], CASTLING_PAIRS[right][1]]:
			position.rights = position.rights.replace(right, "")

func eligible_castling(right: String) -> bool:
	var pair = CASTLING_PAIRS[right]
	return position.board[pair[0]] == pair[2] * Rules.KING and position.board[pair[1]] == pair[2] * Rules.ROOK

func set_castling(right: String, enabled: bool) -> void:
	position.rights = position.rights.replace(right, "")
	if enabled and eligible_castling(right): position.rights += right
	# Canonical FEN order; explicit opt-in is never inferred from replacement pieces.
	var ordered = ""
	for key in ["K","Q","k","q"]:
		if key in position.rights: ordered += key
	position.rights = ordered
	position.ep = -1

func allow_home_castling(enabled: bool) -> void:
	for right in CASTLING_PAIRS: set_castling(right, enabled)

func odds(piece: int, human_side: int) -> void:
	reset_standard()
	if piece == 0: return
	# Always start from standard, so presets never accidentally stack removals.
	var square = {Rules.PAWN: 13, Rules.KNIGHT: 1, Rules.ROOK: 0, Rules.QUEEN: 3}[piece]
	if human_side == -1: square = square ^ 56
	edit(square, 0)

func set_planned(side: String, ability: String, enabled: bool) -> void:
	if not planned.has(side) or not ability in PLANNED_ABILITIES: return
	planned[side].erase(ability)
	if enabled: planned[side].append(ability)

func fen() -> String:
	var rows: Array[String] = []
	for rank in 8:
		var row = ""
		var empty = 0
		for file in 8:
			var piece: int = position.board[rank * 8 + file]
			if piece == 0: empty += 1
			else:
				if empty > 0: row += str(empty); empty = 0
				var letter = " pnbrqk"[abs(piece)]
				row += letter.to_upper() if piece > 0 else letter
		if empty > 0: row += str(empty)
		rows.append(row)
	return "/".join(rows) + (" w " if position.turn == 1 else " b ") + (position.rights if position.rights != "" else "-") + " - 0 1"

func validation_error() -> String:
	for side in [1, -1]:
		var name = "White" if side == 1 else "Black"
		if position.board.count(side * Rules.KING) != 1: return name + " needs exactly one king."
	var white: int = position.board.find(Rules.KING)
	var black: int = position.board.find(-Rules.KING)
	if maxi(abs(white % 8 - black % 8), abs(white / 8 - black / 8)) <= 1: return "Kings cannot be adjacent."
	for square in 64:
		if abs(position.board[square]) == Rules.PAWN and square / 8 in [0,7]: return "Pawns cannot start on ranks 1 or 8."
	# Promotion changes type, not army size. The compiled engine enforces this cap too.
	for side in [1,-1]:
		var count = 0
		for piece in position.board:
			if piece * side > 0: count += 1
		if count > MAX_PIECES_PER_SIDE: return ("White" if side == 1 else "Black") + " exceeds the limit of 32 pieces including its king."
	if position.in_check(1) and position.in_check(-1): return "Both kings cannot be in check."
	if position.in_check(-position.turn): return "The side not to move cannot be in check. Change the turn or board."
	if position.legal_moves().is_empty(): return "No legal moves: " + ("checkmate." if position.in_check(position.turn) else "stalemate.") + " Adjust the setup before starting."
	if position.insufficient_material(): return "This setup is already drawn by insufficient material. Add material to play."
	return ""

func create_game() -> ChessRules:
	var fresh = Rules.new()
	fresh.load_fen(fen())
	fresh.update_result()
	return fresh
