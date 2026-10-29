extends SceneTree
const Rules = preload("res://rules.gd")
var ui
var checks = 0
var failures = 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + text)
	else: print("PASS: " + text)
func move_for(game, uci: String) -> Dictionary:
	for m in game.legal_moves():
		if Rules.uci_name(m) == uci: return m
	return {}
func notation(fen: String, uci: String, expected: String) -> void:
	var game = Rules.new()
	game.load_fen(fen)
	var key = game.position_key()
	check(game.san(move_for(game, uci)) == expected, "SAN " + uci + " = " + expected)
	check(game.position_key() == key and game.move_log.is_empty(), "SAN leaves position/history unchanged")
func mouse(point: Vector2, down: bool, button = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.pressed = down
	event.button_index = button
	root.push_input(event)
func point(square: String) -> Vector2:
	return ui.square_rect(Rules.square(square)).get_center()
func motion(target: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.position = target
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)
func drag(a: String, b: String) -> void:
	mouse(point(a), true)
	motion(point(b))
	mouse(point(b), false)
func key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
func fixture(fen: String) -> void:
	ui.restart()
	ui.game.load_fen(fen)
	ui.refresh()
func capture(name: String) -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--screenshots": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[1])
	root.get_texture().get_image().save_png(args[1].path_join(name + ".png"))

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	notation("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "e1g1", "O-O")
	notation("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1", "e8c8", "O-O-O")
	notation("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "e5d6", "exd6")
	notation("4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1", "b1d2", "Nbd2")
	notation("4k3/8/8/8/8/R7/8/R3K3 w - - 0 1", "a1a2", "R1a2")
	notation("4k3/8/8/8/8/1N6/8/1N2KN2 w - - 0 1", "b1d2", "Nb1d2")
	# Pinned alternate knight cannot cause SAN ambiguity.
	notation("k4r2/8/8/8/8/5N2/8/1N3K2 w - - 0 1", "b1d2", "Nd2")
	for pair in [["q", "a8=Q+"], ["r", "a8=R+"], ["b", "a8=B"], ["n", "a8=N"]]:
		notation("4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7a8" + pair[0], pair[1])
	notation("1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7b8q", "axb8=Q+")
	ui = load("res://main.tscn").instantiate()
	root.size = Vector2i(1180,900)
	root.add_child(ui)
	await process_frame
	ui.set_mode(0)
	mouse(point("e2"), true); motion(point("e3"))
	await capture("drag")
	mouse(point("e2"), false)
	drag("e2", "e4")
	check(ui.game.move_log == ["e2e4"] and ui.records[0].san == "e4" and not ui.dragging, "Drag commits exactly one move and SAN entry")
	drag("e7", "e4")
	check(ui.records.size() == 1 and ui.game.turn == -1, "Illegal drop does not move or record")
	mouse(point("e7"), true); motion(Vector2(5,5)); mouse(Vector2(5,5), false)
	check(ui.drag_from == -1 and ui.records.size() == 1, "Off-board drop clears drag without moving")
	mouse(point("e7"), true); motion(point("e5")); key(KEY_ESCAPE); mouse(point("e5"), false)
	check(ui.drag_from == -1 and ui.records.size() == 1, "Escape cancels a dragged move")
	mouse(point("e7"), true); motion(point("e5")); mouse(point("e5"), true, MOUSE_BUTTON_RIGHT); mouse(point("e5"), false)
	check(ui.records.size() == 1 and not ui.dragging, "Right click cancels drag")
	mouse(point("e7"), true); motion(point("e5")); ui.layout_board(); mouse(point("e5"), false)
	check(ui.records.size() == 1 and not ui.dragging, "Resize cancels drag")
	mouse(point("e7"), true); motion(ui.sidebar.position + Vector2(10,10)); mouse(ui.sidebar.position + Vector2(10,10), false)
	check(ui.records.size() == 1 and ui.drag_from == -1, "Sidebar release cancels drag")
	drag("d7", "d5"); drag("e4", "d5")
	check(ui.records[2].san == "exd5" and ui.records[2].captured == -1 and ui.game.material_balance() == 1, "Capture ledger and material balance use actual captured piece")
	await capture("capture")
	var live_key = ui.game.position_key()
	ui.browse_history(1)
	check(ui.displayed_game().board[Rules.square("d7")] == -1 and ui.displayed_game().turn == -1 and ui.material_label.text == "Material · Even", "Historical board, turn and material match selected ply")
	await capture("history")
	check(ui.captures_label.text == "White captured: —\nBlack captured: —" and ui.status.text.begins_with("Review"), "Historical captures and review status")
	drag("d7", "d5")
	ui.finish_move(move_for(ui.game, "d8d5"))
	check(ui.game.position_key() == live_key and ui.records.size() == 3, "History blocks both drag and direct move execution")
	mouse(point("e4"), true, MOUSE_BUTTON_RIGHT)
	check(ui.inspected == Rules.square("e4") and not ui.preview.is_empty(), "Right-click history inspection uses displayed snapshot")
	ui.return_to_live()
	check(ui.game.position_key() == live_key and ui.history_index == -1 and ui.material_label.text == "Material · White +1", "Return to live restores current position unchanged")
	ui.move_list.grab_focus()
	key(KEY_LEFT)
	check(ui.history_index == 2, "History shortcut works while move list has focus")
	key(KEY_HOME)
	check(ui.displayed_game().board[Rules.square("e2")] == 1 and ui.current_ply() == 0, "Starting position is browsable")
	ui.restart()
	check(ui.records.is_empty() and ui.positions.size() == 1 and ui.history_index == -1 and ui.move_list.item_count == 1, "Restart clears chronicle and review")
	fixture("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	drag("e5", "d6")
	check(ui.records[0].captured == -1 and ui.game.board[Rules.square("d5")] == 0 and ui.game.material_balance() == 1, "En passant ledger counts removed pawn behind destination")
	fixture("1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	drag("a7", "b8")
	await capture("promotion")
	check(ui.promotion.visible and ui.records.is_empty() and not ui.dragging, "Dragged promotion waits for choice without history entry")
	ui.promotion.canceled.emit(); ui.promotion.hide()
	check(ui.records.is_empty() and ui.game.board[8] == 1, "Canceled promotion leaves position and ledger untouched")
	drag("a7", "b8"); ui.promote("5")
	check(ui.records[0].san == "axb8=Q+" and ui.records[0].captured == -4 and ui.game.material_balance() == 9, "Promotion changes material but does not count promoted pawn as captured")
	ui.browse_history(0)
	check(ui.displayed_game().material_balance() == -4, "Pre-promotion material preserved in history")
	fixture("1r6/P3k3/8/8/8/8/8/4K3 w - - 0 1")
	ui.finish_move(move_for(ui.game, "a7a8q"))
	ui.finish_move(move_for(ui.game, "b8a8"))
	check(ui.records[-1].san == "Rxa8" and ui.records[-1].captured == 5 and ui.game.material_balance() == -5, "Captured promoted queen counts as queen; Black material lead")
	check(ui.captures_label.text == "White captured: —\nBlack captured: ♛ ", "Black capture display records promoted piece, no imaginary pawn")
	ui.set_mode(0)
	for uci in ["f2f3", "e7e5", "g2g4", "d8h4"]: ui.finish_move(move_for(ui.game, uci))
	check(ui.records[-1].san == "Qh4#" and ui.game.result.contains("checkmate"), "Terminal move records SAN mate")
	ui.browse_history(4)
	check(ui.displayed_game().result == ui.game.result and ui.status.text.contains("checkmate"), "Terminal history preserves result")
	drag("e2", "e4")
	check(ui.records.size() == 4, "No moves in terminal history")
	ui.return_to_live(); drag("e2", "e4")
	check(ui.records.size() == 4, "No moves after live game ends")
	ui.restart(); ui.agreement.confirmed.emit(); ui.refresh()
	check(ui.positions[-1].result == "Draw — agreement", "Draw result preserved without adding a move")
	ui.set_mode(1); ui.set_difficulty(0); ui.set_side(-1)
	# Directly test rotated coordinates with a black-to-move fixture before the next frame.
	fixture("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
	drag("e7", "e5")
	check(ui.flipped() and ui.game.move_log == ["e7e5"], "Rotated board drag maps to correct engine squares")
	ui.set_side(1); ui.set_difficulty(2); drag("e2", "e4")
	var start_deadline = Time.get_ticks_msec() + 1000
	while not ui.search_active and Time.get_ticks_msec() < start_deadline: await process_frame
	check(ui.search_active, "AI starts after dragged human move")
	drag("e7", "e5")
	check(ui.records.size() == 1 and ui.drag_from == -1, "Human drag blocked during AI turn")
	ui.browse_history(0)
	var deadline = Time.get_ticks_msec() + 4000
	while ui.search_active and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.search_active and ui.records.size() == 1 and ui.game.turn == -1, "Browsing cancels pending AI result without changing live state")
	ui.return_to_live(); ui.set_difficulty(0)
	deadline = Time.get_ticks_msec() + 6000
	while ui.game.turn != 1 and Time.get_ticks_msec() < deadline: await process_frame
	check(ui.records.size() == 2 and ui.game.turn == 1, "Return to live resumes AI exactly once")
	ui.set_mode(0); mouse(point("e2"), true); motion(point("e4")); ui.set_side(-1)
	check(not ui.dragging and ui.records.is_empty(), "Side change clears drag and history")
	mouse(point("e2"), true); motion(point("e4")); ui.set_mode(0)
	check(not ui.dragging and ui.records.is_empty(), "Mode change clears drag and history")
	mouse(point("e2"), true); motion(point("e4")); ui.set_difficulty(1)
	check(not ui.dragging and ui.records.is_empty(), "Difficulty change cancels drag")
	mouse(point("e2"), true); motion(point("e4")); ui.restart(); mouse(point("e4"), false)
	check(ui.records.is_empty() and not ui.dragging and ui.game.turn == 1, "Restart during drag cancels release")
	root.size = Vector2i(600,900)
	await process_frame
	ui.layout_board()
	await capture("narrow")
	check(ui.sidebar.position.y > ui.ORIGIN.y + ui.CELL * 8 and ui.sidebar.size.x <= 600, "Narrow layout keeps history below board")
	print("UX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
