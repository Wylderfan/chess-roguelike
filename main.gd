extends Control
const Rules = preload("res://rules.gd")
const EngineAI = preload("res://engine.gd")
const PIECE_FONT = preload("res://assets/pieces.ttf")
const TITLE_FONT = preload("res://assets/title.ttf")
const SYMBOLS = ["", "♟", "♞", "♝", "♜", "♛", "♚"]
const PIECE_NAMES = ["", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
const BUDGETS = [300, 1100, 2600]
const DEPTHS = [64, 64, 64] # UCI difficulty is a real movetime budget, not a skill rating.
var ORIGIN = Vector2(48, 126)
var CELL = 76.0
var game = Rules.new()
var selected = -1
var inspected = -1
var preview: Dictionary = {}
var legal: Array = []
var last_move: Dictionary = {}
var pending: Array = []
var status: Label
var detail: Label
var engine_status: Label
var claim: Button
var agreement_button: Button
var promotion: ConfirmationDialog
var agreement: ConfirmationDialog
var sidebar: ScrollContainer
var panel: VBoxContainer
var mode_choice: OptionButton
var side_choice: OptionButton
var level_choice: OptionButton
var mode = 1 # 0 = local, 1 = engine
var human_side = 1
var difficulty = 1
var generation = 0
var worker: Thread
var thinker: ChessEngine
var search_generation = -1
var search_key = ""
var search_active = false
var last_search: Dictionary = {}
var engine_fault = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_theme()
	sidebar = ScrollContainer.new()
	sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sidebar)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	sidebar.add_child(panel)
	var eyebrow = label("THE GREAT HALL", 14)
	eyebrow.modulate = Color("c9ad72")
	status = label("", 27)
	status.add_theme_font_override("font", TITLE_FONT)
	detail = label("", 15)
	detail.custom_minimum_size.y = 130
	var separator = HSeparator.new()
	panel.add_child(separator)
	label("YOUR GAME", 13).modulate = Color("c9ad72")
	mode_choice = choice(["Challenge the engine", "Local · two players"])
	mode_choice.item_selected.connect(func(index): set_mode(1 if index == 0 else 0))
	side_choice = choice(["Play as White", "Play as Black"])
	side_choice.item_selected.connect(func(index): set_side(1 if index == 0 else -1))
	level_choice = choice(["Quick · 0.3 s", "Balanced · 1.1 s", "Deep · 2.6 s"])
	level_choice.select(difficulty)
	level_choice.item_selected.connect(set_difficulty)
	engine_status = label("", 13)
	engine_status.modulate = Color("bdb09a")
	engine_status.custom_minimum_size.y = 36
	make_button("New game", restart)
	claim = make_button("Claim draw", func():
		if human_can_play() and game.claim_draw():
			invalidate_search()
			refresh())
	agreement_button = make_button("Agree to a draw", func():
		if game.result == "" and mode == 0: agreement.popup_centered())
	label("LEFT CLICK  ·  select & move\nRIGHT CLICK  ·  inspect either army\nESC  ·  clear highlights", 13).modulate = Color("bdb09a")
	promotion = ConfirmationDialog.new()
	promotion.title = "Crown your pawn"
	promotion.dialog_text = "Choose a piece to complete the move."
	promotion.get_ok_button().hide()
	promotion.get_cancel_button().text = "Cancel move"
	for pair in [[5,"Queen"],[4,"Rook"],[3,"Bishop"],[2,"Knight"]]: promotion.add_button(pair[1], false, str(pair[0]))
	promotion.custom_action.connect(promote)
	promotion.canceled.connect(func(): pending.clear())
	add_child(promotion)
	agreement = ConfirmationDialog.new()
	agreement.title = "Draw by agreement"
	agreement.dialog_text = "Both local players must agree. End this game as a draw?"
	agreement.confirmed.connect(func():
		game.result = "Draw — agreement"
		invalidate_search()
		refresh())
	add_child(agreement)
	resized.connect(layout_board)
	layout_board()
	refresh()

func build_theme() -> void:
	var t = Theme.new()
	t.default_font = PIECE_FONT
	t.default_font_size = 15
	t.set_color("font_color", "Label", Color("eee1c7"))
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box = StyleBoxFlat.new()
			box.bg_color = Color("3d3930") if state == "normal" else Color("514835")
			if state == "disabled": box.bg_color = Color("292923")
			box.border_color = Color("83704b") if state != "focus" else Color("e0bf77")
			box.set_border_width_all(1 if state != "focus" else 2)
			box.set_corner_radius_all(4)
			box.content_margin_left = 12
			box.content_margin_right = 12
			box.content_margin_top = 10
			box.content_margin_bottom = 10
			t.set_stylebox(state, type, box)
		t.set_color("font_color", type, Color("eee1c7"))
		t.set_color("font_disabled_color", type, Color("8f897c"))
	theme = t

func label(text: String, font_size: int) -> Label:
	var item = Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	panel.add_child(item)
	return item

func choice(items: Array) -> OptionButton:
	var item = OptionButton.new()
	for text in items: item.add_item(text)
	item.custom_minimum_size.y = 42
	panel.add_child(item)
	return item

func make_button(text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	panel.add_child(button)
	return button

func layout_board() -> void:
	if sidebar == null: return
	var board_size: float
	if size.x >= 940:
		board_size = minf(size.y - 220, size.x - 440)
		ORIGIN = Vector2(46, 136)
		sidebar.position = Vector2(board_size + 94, 126)
		sidebar.size = Vector2(size.x - sidebar.position.x - 34, size.y - 150)
	else:
		board_size = minf(size.x - 88, size.y * 0.48)
		ORIGIN = Vector2((size.x - board_size) / 2, 112)
		sidebar.position = Vector2(40, ORIGIN.y + board_size + 68)
		sidebar.size = Vector2(size.x - 80, maxf(100, size.y - sidebar.position.y - 18))
	CELL = maxf(20, board_size / 8)
	queue_redraw()

func human_can_play() -> bool:
	return game.result == "" and (mode == 0 or game.turn == human_side)

func set_mode(value: int) -> void:
	mode = value
	mode_choice.select(0 if mode == 1 else 1)
	restart()

func set_side(value: int) -> void:
	human_side = value
	side_choice.select(0 if value == 1 else 1)
	restart()

func set_difficulty(value: int) -> void:
	difficulty = value
	level_choice.select(value)
	invalidate_search()
	refresh()

func invalidate_search() -> void:
	generation += 1
	if search_active: thinker.cancel()

func restart() -> void:
	invalidate_search()
	game = Rules.new()
	selected = -1
	inspected = -1
	preview = {}
	last_move = {}
	last_search = {}
	engine_fault = ""
	pending.clear()
	promotion.hide()
	agreement.hide()
	refresh()

func _process(_delta: float) -> void:
	if search_active and not worker.is_alive():
		var answer: Dictionary = worker.wait_to_finish()
		search_active = false
		# Reject stale results even if a restart recreated the same board.
		if search_generation == generation and search_key == game.position_key() and game.result == "" and mode == 1 and game.turn != human_side:
			last_search = answer
			if answer.get("error", "") != "":
				engine_fault = answer.error
				refresh()
			elif answer.claim and game.claim_draw(): refresh()
			elif not answer.move.is_empty(): finish_move(answer.move)
			else: refresh()
	if not search_active and engine_fault == "" and mode == 1 and game.result == "" and game.turn != human_side:
		thinker = EngineAI.new()
		worker = Thread.new()
		search_generation = generation
		search_key = game.position_key()
		var snapshot = game.copy_position(true)
		var error = worker.start(thinker.search.bind(snapshot, BUDGETS[difficulty], DEPTHS[difficulty]))
		search_active = error == OK
		if not search_active:
			mode = 0
			mode_choice.select(1)
			engine_status.text = "Engine unavailable; local play enabled."
		else: refresh()

func _exit_tree() -> void:
	if search_active:
		thinker.cancel()
		worker.wait_to_finish()
		search_active = false

func refresh() -> void:
	legal = game.legal_moves() if game.result == "" else []
	var side = "White" if game.turn == 1 else "Black"
	status.text = game.result if game.result != "" else side + " to move" + (" · Check" if game.in_check(game.turn) else "")
	detail.text = "Move %d\n" % game.fullmove
	if inspected != -1 and game.board[inspected] != 0:
		preview = game.inspect_piece(inspected)
		var piece_side = "White" if game.board[inspected] > 0 else "Black"
		detail.text += "INSPECT · %s %s · %s\n" % [piece_side, PIECE_NAMES[abs(game.board[inspected])], Rules.name_of(inspected)]
		detail.text += "Blue dots/rings: king-safe destinations " + ("if this side moved now; no en passant.\n" if preview.hypothetical else "this turn.\n")
		detail.text += "Amber diamonds: attacks/protection, not legal moves. Pins still attack; pawns attack diagonally."
		if game.result != "": detail.text += "\nPosition study only; the game has ended."
	elif game.result != "": detail.text += "The game is complete. Begin a new game to play again."
	elif selected != -1: detail.text += "Selected: " + Rules.name_of(selected) + "\nGreen dots/rings mark legal moves.\nRight-click any piece to study it."
	elif mode == 1 and game.turn != human_side: detail.text += "The engine is considering its move.\nYou can right-click either army to inspect it while you wait."
	else: detail.text += "Choose a piece from your army.\nRight-click either army to inspect moves and attacks without moving."
	var reason = game.claim_reason()
	claim.disabled = reason == "" or not human_can_play()
	claim.tooltip_text = "Claim a current threefold repetition or 50-move draw." if reason == "" else reason
	agreement_button.visible = mode == 0
	side_choice.visible = mode == 1
	level_choice.visible = mode == 1
	if engine_fault != "": engine_status.text = engine_fault + "\nChoose Local or New game to retry."
	elif mode == 0: engine_status.text = "Both armies are controlled locally."
	elif search_active: engine_status.text = "Thinking…  ·  %s budget\nInspection and controls remain available." % ("%.1f s" % (BUDGETS[difficulty] / 1000.0))
	elif not last_search.is_empty(): engine_status.text = "Last search: depth %d · %d nodes · %d ms\nSebastian Lague V2 · no verified Elo" % [last_search.depth, last_search.nodes, last_search.elapsed_ms]
	else: engine_status.text = "Sebastian Lague V2 · no verified Elo\nMode or side changes start a new game."
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		selected = -1
		inspected = -1
		refresh()
	if event is InputEventMouseButton and event.pressed:
		var p = get_global_transform_with_canvas().affine_inverse() * event.position - ORIGIN
		if p.x >= 0 and p.y >= 0 and p.x < CELL * 8 and p.y < CELL * 8:
			var s = int(p.y / CELL) * 8 + int(p.x / CELL)
			if flipped(): s = 63 - s
			if event.button_index == MOUSE_BUTTON_RIGHT: inspect_square(s)
			elif event.button_index == MOUSE_BUTTON_LEFT: select_square(s)

func inspect_square(s: int) -> void:
	if promotion.visible or agreement.visible: return
	selected = -1
	inspected = s if game.board[s] != 0 and inspected != s else -1
	refresh()

func select_square(s: int) -> void:
	if not human_can_play() or promotion.visible or agreement.visible: return
	# Inspection never becomes an actionable selection. A left click starts fresh.
	inspected = -1
	var candidates: Array = []
	for m in legal:
		if m.from == selected and m.to == s: candidates.append(m)
	if not candidates.is_empty():
		if candidates.size() > 1:
			pending = candidates
			promotion.popup_centered()
		else: finish_move(candidates[0])
		return
	selected = s if game.board[s] * game.turn > 0 and s != selected else -1
	refresh()

func promote(action: String) -> void:
	for m in pending:
		if m.promotion == int(action):
			finish_move(m)
			break
	pending.clear()
	promotion.hide()

func finish_move(m: Dictionary) -> void:
	if game.play(m):
		last_move = m
		selected = -1
		inspected = -1
	refresh()

func flipped() -> bool:
	return mode == 1 and human_side == -1

func square_rect(s: int) -> Rect2:
	var view = 63 - s if flipped() else s
	return Rect2(ORIGIN + Vector2(view % 8, view / 8) * CELL, Vector2.ONE * CELL)

func marker(center: Vector2, capture: bool, color: Color) -> void:
	if capture: draw_arc(center, CELL * 0.42, 0, TAU, 40, color, maxf(2, CELL * 0.04), true)
	else: draw_circle(center, CELL * 0.10, color, true, -1, true)

func _draw() -> void:
	var font = PIECE_FONT
	var brass = Color("b99a61")
	draw_rect(Rect2(Vector2.ZERO, size), Color("202622"))
	# Restrained brass border and title, all original procedural drawing.
	draw_line(Vector2(32, 20), Vector2(size.x - 32, 20), brass, 1)
	draw_string(TITLE_FONT, Vector2(42, 67), "Knight Chess", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("f0dfbc"))
	draw_string(font, Vector2(44, 91), "A BOARD. TWO ARMIES. YOUR NEXT MOVE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, brass)
	var board_rect = Rect2(ORIGIN, Vector2.ONE * CELL * 8)
	draw_rect(board_rect.grow(17), Color("131b18"))
	draw_rect(board_rect.grow(12), Color("59432d"))
	draw_rect(board_rect.grow(13), brass, false, 1)
	draw_rect(board_rect.grow(3), Color("322b22"))
	for s in 64:
		var rect = square_rect(s)
		var light = (s % 8 + s / 8) % 2 == 0
		draw_rect(rect, Color("decba5") if light else Color("78806a"))
		if not last_move.is_empty() and s in [last_move.from, last_move.to]: draw_rect(rect, Color(0.89,0.67,0.20,0.36))
		if abs(game.board[s]) == Rules.KING and game.in_check(sign(game.board[s])): draw_rect(rect, Color(0.78,0.19,0.17,0.58))
		if s == selected: draw_rect(rect.grow(-3), Color("39765b"), false, 4)
		if s == inspected:
			draw_rect(rect, Color(0.18,0.55,0.75,0.25))
			draw_rect(rect.grow(-3), Color("377da6"), false, 4)
		var piece: int = game.board[s]
		if piece != 0:
			var symbol: String = SYMBOLS[abs(piece)]
			var fs = int(CELL * 0.77)
			var width = PIECE_FONT.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos = rect.position + Vector2((CELL - width)/2, CELL * 0.78)
			var ink = Color("fff1d3") if piece > 0 else Color("25332d")
			var edge = Color("59432d") if piece > 0 else Color("d9c59b")
			draw_string_outline(PIECE_FONT, pos + Vector2(1,2), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.12,0.12,0.09,0.35))
			draw_string_outline(PIECE_FONT, pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, edge)
			draw_string(PIECE_FONT, pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		for m in legal:
			if m.from == selected and m.to == s: marker(rect.get_center(), piece != 0, Color("276247"))
		if inspected != -1 and not preview.is_empty():
			for m in preview.moves:
				if m.to == s: marker(rect.get_center(), piece != 0, Color("206c9a"))
			if s in preview.attacks:
				var c = rect.position + Vector2(CELL * 0.83, CELL * 0.17)
				var r = CELL * 0.065
				draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r),c+Vector2(r,0),c+Vector2(0,r),c+Vector2(-r,0)]), Color("8c4e13"))
	for i in 8:
		var file = 7 - i if flipped() else i
		var rank = i + 1 if flipped() else 8 - i
		draw_string(font, Vector2(ORIGIN.x + i * CELL + CELL * 0.44, ORIGIN.y + CELL * 8 + 30), "abcdefgh"[file], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, brass)
		draw_string(font, Vector2(ORIGIN.x - 31, ORIGIN.y + i * CELL + CELL * 0.57), str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, brass)
	var legend = "BLUE  inspect   ·   AMBER ◆ attacks / protection" if inspected != -1 else "GREEN  legal moves   ·   GOLD  last move   ·   RED  check"
	draw_string(font, Vector2(ORIGIN.x, ORIGIN.y + CELL * 8 + 53), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c2b59a"))
