extends Control
const Rules = preload("res://rules.gd")
const Setup = preload("res://setup.gd")
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
# Live rules never become a historical position. Browsing pauses/cancels AI.
var positions: Array = []
var records: Array = []
var history_index = -1 # -1 = live
var move_list: ItemList
var history_label: Label
var live_button: Button
var previous_button: Button
var next_button: Button
var material_label: Label
var captures_label: Label
var drag_from = -1
var dragging = false
var drag_start = Vector2.ZERO
var drag_position = Vector2.ZERO
var editing = false
var setup = Setup.new()
var setup_panel: VBoxContainer
var play_widgets: Array = []
var setup_status: Label
var setup_summary: Label
var setup_tool_label: Label
var setup_mode_choice: OptionButton
var setup_side_label: Label
var setup_side_choice: OptionButton
var setup_turn_choice: OptionButton
var setup_level_choice: OptionButton
var setup_castling_checks: Dictionary = {}
var setup_ability_checks: Dictionary = {}
var setup_mode = 1
var setup_side = 1
var setup_level = 1
var setup_tool = 99 # 99=relocate, 0=erase, signed piece=place
var planned_abilities = {"white": [], "black": []}
var planned_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_theme()
	sidebar = ScrollContainer.new()
	sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sidebar)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	sidebar.add_child(panel)
	var eyebrow = label("THE GREAT HALL", 14)
	eyebrow.modulate = Color("c9ad72")
	status = label("", 27)
	status.add_theme_font_override("font", TITLE_FONT)
	make_button("New game / Setup", open_setup)
	detail = label("", 15)
	detail.custom_minimum_size.y = 92
	material_label = label("", 17)
	captures_label = label("", 14)
	label("CHRONICLE", 13).modulate = Color("c9ad72")
	history_label = label("", 13)
	move_list = ItemList.new()
	move_list.custom_minimum_size.y = 126
	move_list.add_theme_font_size_override("font_size", 16)
	move_list.item_selected.connect(func(index): browse_history(index))
	panel.add_child(move_list)
	var navigation = HBoxContainer.new()
	panel.add_child(navigation)
	previous_button = Button.new()
	previous_button.text = "‹ Previous"
	previous_button.pressed.connect(func(): browse_history(current_ply() - 1))
	navigation.add_child(previous_button)
	next_button = Button.new()
	next_button.text = "Next ›"
	next_button.pressed.connect(func(): browse_history(current_ply() + 1))
	navigation.add_child(next_button)
	live_button = Button.new()
	live_button.text = "Return to live"
	live_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_button.pressed.connect(return_to_live)
	navigation.add_child(live_button)
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
	planned_label = label("", 13)
	planned_label.modulate = Color("c9ad72")
	engine_status = label("", 13)
	engine_status.modulate = Color("bdb09a")
	engine_status.custom_minimum_size.y = 36
	claim = make_button("Claim draw", func():
		if human_can_play() and game.claim_draw():
			invalidate_search()
			refresh())
	agreement_button = make_button("Agree to a draw", func():
		if history_index == -1 and game.result == "" and mode == 0: agreement.popup_centered())
	label("DRAG or CLICK  ·  move\nRIGHT CLICK  ·  inspect either army\n← / →  ·  history     END  ·  live\nESC  ·  cancel drag / clear highlights", 13).modulate = Color("bdb09a")
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
	build_setup_panel()
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
	# Fixed metrics in every state: native theme checked/unchecked icons and inherited
	# Button styles may otherwise have different widths/margins, shifting the text.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("3d3930") if state == "normal" else Color("514835")
		box.border_color = Color("e0bf77") if state == "focus" else Color("83704b")
		box.set_border_width_all(1)
		box.set_corner_radius_all(4)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		t.set_stylebox(state, "CheckBox", box)
	for checked in [false,true]:
		var icon = checkbox_icon(checked)
		for suffix in ["", "_disabled"]:
			t.set_icon(("checked" if checked else "unchecked") + suffix, "CheckBox", icon)
	t.set_constant("h_separation", "CheckBox", 8)
	t.set_constant("check_v_offset", "CheckBox", 0)
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
	cancel_drag()
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
	return not editing and history_index == -1 and game.result == "" and (mode == 0 or game.turn == human_side)

func set_mode(value: int) -> void:
	mode = value
	mode_choice.select(0 if mode == 1 else 1)
	restart()

func set_side(value: int) -> void:
	human_side = value
	side_choice.select(0 if value == 1 else 1)
	restart()

func set_difficulty(value: int) -> void:
	cancel_drag()
	difficulty = value
	level_choice.select(value)
	invalidate_search()
	refresh()

func invalidate_search() -> void:
	generation += 1
	if search_active: thinker.cancel()

func restart() -> void:
	if editing: show_setup(false)
	planned_abilities = {"white": [], "black": []}
	cancel_drag()
	invalidate_search()
	positions.clear()
	records.clear()
	history_index = -1
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
		if not editing and history_index == -1 and search_generation == generation and search_key == game.position_key() and game.result == "" and mode == 1 and game.turn != human_side:
			last_search = answer
			if answer.get("error", "") != "":
				engine_fault = answer.error
				refresh()
			elif answer.claim and game.claim_draw(): refresh()
			elif not answer.move.is_empty(): finish_move(answer.move)
			else: refresh()
	if not editing and history_index == -1 and not search_active and engine_fault == "" and mode == 1 and game.result == "" and game.turn != human_side:
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
	if editing:
		refresh_setup()
		return
	ensure_history()
	var shown = displayed_game()
	legal = shown.legal_moves() if shown.result == "" else []
	var side = "White" if shown.turn == 1 else "Black"
	status.text = shown.result if shown.result != "" else side + " to move" + (" · Check" if shown.in_check(shown.turn) else "")
	detail.text = "Move %d\n" % shown.fullmove
	if inspected != -1 and shown.board[inspected] != 0:
		preview = shown.inspect_piece(inspected)
		var piece_side = "White" if shown.board[inspected] > 0 else "Black"
		detail.text += "INSPECT · %s %s · %s\n" % [piece_side, PIECE_NAMES[abs(shown.board[inspected])], Rules.name_of(inspected)]
		detail.text += "Blue dots/rings: king-safe destinations " + ("if this side moved now; no en passant.\n" if preview.hypothetical else "this turn.\n")
		detail.text += "Amber diamonds: attacks/protection, not legal moves. Pins still attack; pawns attack diagonally."
		if shown.result != "": detail.text += "\nPosition study only; the game has ended."
	elif shown.result != "": detail.text += "The game is complete. Begin a new game to play again."
	elif selected != -1: detail.text += "Selected: " + Rules.name_of(selected) + "\nGreen dots/rings mark legal moves.\nRight-click any piece to study it."
	elif mode == 1 and shown.turn != human_side: detail.text += "The engine is considering its move.\nYou can right-click either army to inspect it while you wait."
	else: detail.text += "Choose a piece from your army.\nRight-click either army to inspect moves and attacks without moving."
	var reason = shown.claim_reason()
	claim.disabled = reason == "" or not human_can_play()
	claim.tooltip_text = "Claim a current threefold repetition or 50-move draw." if reason == "" else reason
	agreement_button.visible = mode == 0
	side_choice.visible = mode == 1
	level_choice.visible = mode == 1
	if engine_fault != "": engine_status.text = engine_fault + "\nChoose Local or New game to retry."
	elif mode == 0: engine_status.text = "Both armies are controlled locally."
	elif search_active: engine_status.text = "Thinking…  ·  %s budget\nInspection and controls remain available." % ("%.1f s" % (BUDGETS[difficulty] / 1000.0))
	elif not last_search.is_empty(): engine_status.text = "Last search: depth %d · %d nodes · %d ms\nSebastian Lague V2 · no verified Elo" % [last_search.depth, last_search.nodes, last_search.elapsed_ms]
	else: engine_status.text = "Sebastian Lague V2 · no verified Elo\nMode or side changes start a standard game."
	if history_index != -1:
		status.text = "Review · " + status.text
		detail.text = "Read-only history. The live game is paused.\nReturn to live to continue.\nRight-click to inspect this position.\n" + (detail.text if inspected != -1 else "")
		agreement_button.disabled = true
	else: agreement_button.disabled = false
	planned_label.text = "Planned abilities recorded · no gameplay effect" if not planned_abilities.white.is_empty() or not planned_abilities.black.is_empty() else ""
	planned_label.visible = planned_label.text != ""
	refresh_chronicle()
	queue_redraw()

func square_at(point: Vector2) -> int:
	var p = get_global_transform_with_canvas().affine_inverse() * point - ORIGIN
	if p.x < 0 or p.y < 0 or p.x >= CELL * 8 or p.y >= CELL * 8: return -1
	var square = int(p.y / CELL) * 8 + int(p.x / CELL)
	return 63 - square if flipped() else square

func cancel_drag() -> void:
	drag_from = -1
	dragging = false
	queue_redraw()

# Release is handled before GUI dispatch, even over the sidebar or off-board.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and drag_from != -1:
		drag_position = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.position.distance_to(drag_start) >= 6:
			dragging = true
			selected = drag_from
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drag_from != -1:
		var source = drag_from
		var was_dragging = dragging
		cancel_drag()
		if was_dragging:
			var target = square_at(event.position)
			selected = source
			if target != -1 and target != source:
				if editing: setup_square(target)
				else: select_square(target)
			else:
				selected = -1
				refresh()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		selected = -1
		inspected = -1
		refresh()

	if event is InputEventKey and event.pressed and not editing and not promotion.visible and not agreement.visible and not (get_viewport().gui_get_focus_owner() is OptionButton):
		if event.keycode == KEY_LEFT: browse_history(current_ply() - 1)
		elif event.keycode == KEY_RIGHT: browse_history(current_ply() + 1)
		elif event.keycode == KEY_HOME: browse_history(0)
		elif event.keycode == KEY_END: return_to_live()
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]: get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: cancel_drag()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var square = square_at(event.position)
		if editing:
			if square == -1: return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_drag()
				setup.edit(square, 0)
				selected = -1
				refresh_setup()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				setup_square(square)
				if setup_tool == 99 and selected == square and setup.position.board[square] != 0:
					drag_from = square
					drag_start = event.position
					drag_position = get_global_transform_with_canvas().affine_inverse() * event.position
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_drag()
			if square != -1: inspect_square(square)
		elif event.button_index == MOUSE_BUTTON_LEFT and square != -1:
			select_square(square)
			if human_can_play() and not promotion.visible and not agreement.visible and game.board[square] * game.turn > 0:
				drag_from = square
				drag_start = event.position
				drag_position = get_global_transform_with_canvas().affine_inverse() * event.position

func inspect_square(s: int) -> void:
	if editing or promotion.visible or agreement.visible: return
	selected = -1
	inspected = s if displayed_game().board[s] != 0 and inspected != s else -1
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
	if editing: return
	if history_index != -1: return
	ensure_history()
	var san = game.san(m)
	var victim = game.captured_piece(m)
	var side = game.turn
	var number = game.fullmove
	if game.play(m):
		records.append({"san": san, "captured": victim, "side": side, "number": number, "move": m.duplicate()})
		positions.append(snapshot(game))
		cancel_drag()
		last_move = m
		selected = -1
		inspected = -1
	refresh()

func flipped() -> bool:
	if editing: return setup_mode == 1 and setup_side == -1
	return mode == 1 and human_side == -1

func square_rect(s: int) -> Rect2:
	var view = 63 - s if flipped() else s
	return Rect2(ORIGIN + Vector2(view % 8, view / 8) * CELL, Vector2.ONE * CELL)

func marker(center: Vector2, capture: bool, color: Color) -> void:
	if capture: draw_arc(center, CELL * 0.42, 0, TAU, 40, color, maxf(2, CELL * 0.04), true)
	else: draw_circle(center, CELL * 0.10, color, true, -1, true)

func _draw() -> void:
	var shown = displayed_game()
	var highlighted = {} if editing else (last_move if history_index == -1 else (records[history_index - 1].move if history_index > 0 else {}))
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
		if not highlighted.is_empty() and s in [highlighted.from, highlighted.to]: draw_rect(rect, Color(0.89,0.67,0.20,0.36))
		if abs(shown.board[s]) == Rules.KING and shown.in_check(sign(shown.board[s])): draw_rect(rect, Color(0.78,0.19,0.17,0.58))
		if s == selected: draw_rect(rect.grow(-3), Color("39765b"), false, 4)
		if s == inspected:
			draw_rect(rect, Color(0.18,0.55,0.75,0.25))
			draw_rect(rect.grow(-3), Color("377da6"), false, 4)
		var piece: int = shown.board[s]
		if piece != 0 and not (dragging and s == drag_from):
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
	if editing: legend = "SETUP  ·  click to place / move   ·   RIGHT CLICK  erase"
	draw_string(font, Vector2(ORIGIN.x, ORIGIN.y + CELL * 8 + 53), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c2b59a"))

	if dragging and drag_from != -1:
		var piece: int = shown.board[drag_from]
		var symbol: String = SYMBOLS[abs(piece)]
		var fs = int(CELL * 0.85)
		var width = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos = drag_position + Vector2(-width / 2, CELL * 0.28)
		draw_string_outline(font, pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color("59432d") if piece > 0 else Color("d9c59b"))
		draw_string(font, pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff1d3") if piece > 0 else Color("25332d"))

func snapshot(source: ChessRules) -> ChessRules:
	var copy = source.copy_position(true)
	copy.result = source.result
	return copy

func ensure_history() -> void:
	# Also supports loading test/study FENs before the first recorded move.
	if positions.is_empty() or (records.is_empty() and positions[0].position_key() != game.position_key()):
		positions = [snapshot(game)]
	if positions[-1].position_key() == game.position_key(): positions[-1].result = game.result

func displayed_game() -> ChessRules:
	if editing: return setup.position
	return positions[history_index] if history_index >= 0 and history_index < positions.size() else game

func current_ply() -> int:
	return records.size() if history_index == -1 else history_index

func browse_history(ply: int) -> void:
	if editing: return
	if promotion.visible or agreement.visible: return
	ensure_history()
	if records.is_empty(): return
	cancel_drag()
	invalidate_search()
	history_index = clampi(ply, 0, records.size())
	selected = -1
	inspected = -1
	refresh()

func return_to_live() -> void:
	if editing: return
	cancel_drag()
	history_index = -1
	selected = -1
	inspected = -1
	refresh()

func refresh_chronicle() -> void:
	var ply = current_ply()
	history_label.text = "LIVE · %d half-moves" % records.size() if history_index == -1 else "REVIEW · %d / %d · game paused" % [ply, records.size()]
	live_button.disabled = history_index == -1
	previous_button.disabled = ply == 0
	next_button.disabled = ply == records.size()
	# Rebuild only on moves; inspection should not reset scroll position.
	if move_list.item_count != records.size() + 1:
		move_list.clear()
		move_list.add_item("Starting position")
		for record in records:
			move_list.add_item("%d%s  %s" % [record.number, "." if record.side == 1 else "…", record.san])
	var was_selected = move_list.is_selected(ply)
	move_list.select(ply)
	if not was_selected: move_list.ensure_current_is_visible()
	var balance = displayed_game().material_balance()
	material_label.text = "Material · Even" if balance == 0 else "Material · %s +%d" % ["White" if balance > 0 else "Black", abs(balance)]
	material_label.tooltip_text = "Pieces currently on this board: pawn 1, knight/bishop 3, rook 5, queen 9. Not an engine evaluation."
	var white = ""
	var black = ""
	for i in ply:
		var victim: int = records[i].captured
		if victim < 0: white += SYMBOLS[abs(victim)] + " "
		elif victim > 0: black += SYMBOLS[abs(victim)] + " "
	captures_label.text = "White captured: " + (white if white != "" else "—") + "\nBlack captured: " + (black if black != "" else "—")

# Setup is an isolated draft. Only Start replaces the live game.
func build_setup_panel() -> void:
	play_widgets = panel.get_children()
	setup_panel = VBoxContainer.new()
	setup_panel.add_theme_constant_override("separation", 8)
	panel.add_child(setup_panel)
	var live_panel = panel
	panel = setup_panel
	label("PREPARE THE ARMIES", 23).add_theme_font_override("font", TITLE_FONT)
	label("New game draft · current game paused.\nStart replaces it; Cancel returns unchanged.\nUp to 32 pieces per side, including one king.", 14)
	make_button("Start this position", start_setup)
	make_button("Cancel · return to game", cancel_setup)
	setup_status = label("", 15)
	setup_summary = label("", 14)
	setup_mode_choice = choice(["Challenge the engine", "Local · two players"])
	setup_mode_choice.item_selected.connect(func(index): setup_mode = 1 if index == 0 else 0; cancel_drag(); selected = -1; refresh_setup())
	setup_side_label = label("Your side", 13)
	setup_side_choice = choice(["White", "Black"])
	setup_side_choice.item_selected.connect(func(index): setup_side = 1 if index == 0 else -1; cancel_drag(); selected = -1; refresh_setup())
	setup_level_choice = choice(["Quick · 0.3 s", "Balanced · 1.1 s", "Deep · 2.6 s"])
	setup_level_choice.item_selected.connect(func(index): setup_level = index)
	setup_turn_choice = choice(["White to move", "Black to move"])
	setup_turn_choice.item_selected.connect(func(index): setup.position.turn = 1 if index == 0 else -1; refresh_setup())
	label("REMOVE MATERIAL · resets the board", 13).modulate = Color("c9ad72")
	var presets = choice(["Choose a preset…", "Remove opponent pawn · f-file", "Remove opponent knight · b-file", "Remove opponent rook · a-file", "Remove opponent queen"])
	presets.item_selected.connect(func(index):
		if index > 0: apply_setup_odds([0,Rules.PAWN,Rules.KNIGHT,Rules.ROOK,Rules.QUEEN][index])
		presets.select(0))
	make_button("Reset standard board", func(): apply_setup_odds(0))
	label("ADD MATERIAL · choose a piece below, then click an empty square. Move and Erase also remain available.", 13)
	setup_tool_label = label("", 14)
	var group = ButtonGroup.new()
	var tools_row = HBoxContainer.new()
	panel.add_child(tools_row)
	for pair in [[99,"Move pieces"],[0,"Erase"]]:
		var button = Button.new()
		button.text = pair[1]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = pair[0] == 99
		button.pressed.connect(choose_setup_tool.bind(pair[0]))
		tools_row.add_child(button)
	for side in [1,-1]:
		label("Place White" if side == 1 else "Place Black", 13)
		var row = HBoxContainer.new()
		panel.add_child(row)
		for piece in range(1,7):
			var button = Button.new()
			button.text = SYMBOLS[piece]
			button.add_theme_font_size_override("font_size", 25)
			button.add_theme_color_override("font_color", Color("fff1d3") if side == 1 else Color("c5cbb3"))
			button.tooltip_text = ("White " if side == 1 else "Black ") + PIECE_NAMES[piece]
			button.toggle_mode = true
			button.button_group = group
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(choose_setup_tool.bind(side * piece))
			row.add_child(button)
	label("CASTLING RIGHTS · composed starting position", 13)
	var castling_grid = GridContainer.new()
	castling_grid.columns = 2
	panel.add_child(castling_grid)
	for pair in [["K","White O-O"],["Q","White O-O-O"],["k","Black O-O"],["q","Black O-O-O"]]:
		var box = CheckBox.new()
		box.text = pair[1]
		box.add_theme_font_size_override("font_size", 13)
		box.toggled.connect(func(enabled): setup.set_castling(pair[0],enabled); refresh_setup())
		castling_grid.add_child(box)
		setup_castling_checks[pair[0]] = box
	label("Unrelated edits keep rights. Moving, replacing or removing a home king/rook clears its rights; restoring a piece does not restore rights. Opt in explicitly for a composed start. En passant always starts empty.", 13)
	label("PLANNED ABILITIES · NO GAMEPLAY EFFECT", 13).modulate = Color("c9ad72")
	label("These checkboxes record ideas only. Both armies still use normal chess rules; the engine receives no active abilities.", 13)
	for side in ["white","black"]:
		label(side.capitalize() + " · planned", 15)
		for ability in Setup.PLANNED_ABILITIES:
			var box = CheckBox.new()
			box.text = ability + " (planned)"
			box.toggled.connect(func(enabled): setup.set_planned(side, ability, enabled))
			panel.add_child(box)
			setup_ability_checks[side + ability] = box
	panel = live_panel
	setup_panel.hide()

func show_setup(enabled: bool) -> void:
	editing = enabled
	for widget in play_widgets: widget.visible = not enabled
	setup_panel.visible = enabled
	sidebar.scroll_vertical = 0

func open_setup() -> void:
	cancel_drag()
	invalidate_search()
	pending.clear()
	promotion.hide()
	agreement.hide()
	selected = -1
	inspected = -1
	preview = {}
	legal = []
	setup = Setup.new()
	setup.planned = planned_abilities.duplicate(true)
	setup_mode = mode
	setup_side = human_side
	setup_level = difficulty
	setup_mode_choice.select(0 if mode == 1 else 1)
	setup_side_choice.select(0 if human_side == 1 else 1)
	setup_level_choice.select(difficulty)
	for side in ["white","black"]:
		for ability in Setup.PLANNED_ABILITIES:
			setup_ability_checks[side + ability].set_pressed_no_signal(ability in setup.planned[side])
	show_setup(true)
	refresh_setup()

func cancel_setup() -> void:
	cancel_drag()
	selected = -1
	show_setup(false)
	refresh()

func choose_setup_tool(piece: int) -> void:
	cancel_drag()
	selected = -1
	setup_tool = piece
	refresh_setup()

func setup_square(square: int) -> void:
	if not editing: return
	if setup_tool == 99:
		if selected != -1 and selected != square:
			setup.relocate(selected, square)
			selected = -1
		else: selected = square if setup.position.board[square] != 0 and selected != square else -1
	else:
		setup.edit(square, setup_tool)
		selected = -1
	refresh_setup()

func apply_setup_odds(piece: int) -> void:
	cancel_drag()
	selected = -1
	setup.odds(piece, setup_side)
	refresh_setup()

func refresh_setup() -> void:
	if not editing: return
	var error = setup.validation_error()
	setup_status.text = "Ready · normal chess" if error == "" else error
	setup_status.modulate = Color("b8d7a8") if error == "" else Color("f2b7a1")
	var balance = setup.position.material_balance()
	setup_summary.text = ("Material · Even" if balance == 0 else "Material · %s +%d" % ["White" if balance > 0 else "Black", abs(balance)])
	setup_summary.text += "\nOpponent for presets: " + ("Black" if setup_side == 1 else "White")
	setup_summary.text += " · castling: " + (setup.position.rights if setup.position.rights != "" else "off")
	setup_tool_label.text = "Tool: " + ("Move · drag, or click source then destination" if setup_tool == 99 else ("Erase" if setup_tool == 0 else "Place " + ("White " if setup_tool > 0 else "Black ") + PIECE_NAMES[abs(setup_tool)]))
	setup_turn_choice.select(0 if setup.position.turn == 1 else 1)
	for right in setup_castling_checks:
		setup_castling_checks[right].disabled = not setup.eligible_castling(right)
		setup_castling_checks[right].set_pressed_no_signal(right in setup.position.rights)
	setup_side_label.text = "Your side" if setup_mode == 1 else "Preset beneficiary"
	setup_level_choice.visible = setup_mode == 1
	queue_redraw()

func start_setup() -> bool:
	if not editing: return false
	if setup.validation_error() != "":
		refresh_setup()
		sidebar.scroll_vertical = 0
		return false
	var candidate = setup.create_game()
	var intent = setup.planned.duplicate(true)
	show_setup(false)
	mode = setup_mode
	human_side = setup_side
	difficulty = setup_level
	mode_choice.select(0 if mode == 1 else 1)
	side_choice.select(0 if human_side == 1 else 1)
	level_choice.select(difficulty)
	restart()
	game = candidate
	positions.clear()
	planned_abilities = intent
	refresh()
	return true

func checkbox_icon(checked: bool) -> ImageTexture:
	var pixels = Image.create(22,22,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in range(2,20):
		for x in range(2,20):
			pixels.set_pixel(x,y,Color("d9bd7e") if x in [2,3,18,19] or y in [2,3,18,19] else Color("202622"))
	if checked:
		for i in range(5,17):
			var y = (i+5) if i < 10 else (24-i)
			for dy in range(-1,2): pixels.set_pixel(i,y+dy,Color("eee1c7"))
	return ImageTexture.create_from_image(pixels)
