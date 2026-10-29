class_name ChessSetup
extends RefCounted
const Rules = preload("res://rules.gd")
const PLANNED_ABILITIES = ["Pawn Dash", "Bishop Sidestep", "Queen Exchange"]
var position = Rules.new()
# Configuration intent only: NEVER copied into ChessRules.ability_state or UCI.
var planned = {"white": [], "black": []}

func reset_standard() -> void:
	position = Rules.new()

func edit(square: int, piece: int) -> void:
	if square < 0 or square >= 64 or abs(piece) > Rules.KING: return
	position.board[square] = piece
	clear_rights()

func relocate(source: int, target: int) -> void:
	if source == target or source < 0 or target < 0 or source >= 64 or target >= 64: return
	position.board[target] = position.board[source]
	position.board[source] = 0
	clear_rights()

func clear_rights() -> void:
	position.rights = ""
	position.ep = -1

func allow_home_castling(enabled: bool) -> void:
	clear_rights()
	if not enabled: return
	for pair in [[60,63,1,"K"],[60,56,1,"Q"],[4,7,-1,"k"],[4,0,-1,"q"]]:
		if position.board[pair[0]] == pair[2] * Rules.KING and position.board[pair[1]] == pair[2] * Rules.ROOK:
			position.rights += pair[3]

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
	# This editor supports standard armies with material removed/repositioned,
	# not arbitrary extra armies. Keep the native fixed piece/move buffers safe.
	for side in [1,-1]:
		var counts = [0,0,0,0,0,0,0]
		var bishop_colors = [0,0]
		for square in 64:
			var piece: int = position.board[square]
			if piece * side > 0:
				counts[abs(piece)] += 1
				if abs(piece) == Rules.BISHOP: bishop_colors[(square / 8 + square % 8) % 2] += 1
		var name = "White" if side == 1 else "Black"
		for piece in range(1,7):
			if counts[piece] > [0,8,2,2,2,1,1][piece]: return name + " exceeds the setup inventory: 8 pawns, 2 knights/bishops/rooks, 1 queen and king."
		var promotions = maxi(0,bishop_colors[0]-1) + maxi(0,bishop_colors[1]-1)
		if promotions > 8-counts[Rules.PAWN]: return name + " needs a missing pawn to account for a promoted same-color bishop."
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
