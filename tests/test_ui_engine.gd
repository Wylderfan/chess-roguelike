extends SceneTree
var failures = 0
var checks = 0
var ui
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else: print("PASS: " + label)
func click_square(square: String, button = MOUSE_BUTTON_LEFT) -> void:
	var s = ui.Rules.square(square)
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = ui.square_rect(s).get_center()
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func settle(timeout_ms = 4500) -> Dictionary:
	var start = Time.get_ticks_msec()
	var frames = 0
	var last = start
	var largest_gap = 0
	while (ui.search_active or (ui.mode == 1 and ui.game.turn != ui.human_side and ui.game.result == "")) and Time.get_ticks_msec() - start < timeout_ms:
		await process_frame
		frames += 1
		var now = Time.get_ticks_msec()
		largest_gap = maxi(largest_gap, now - last)
		last = now
	return {"frames": frames, "elapsed_ms": Time.get_ticks_msec() - start, "max_frame_gap_ms": largest_gap}
func start_black_engine_turn() -> void:
	ui.set_mode(1)
	ui.set_side(1)
	click_square("e2"); click_square("e4")
	await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.size = Vector2i(1180,900)
	root.content_scale_size = Vector2i(1180,900)
	root.add_child(ui)
	await process_frame
	ui.set_mode(0)
	var initial = ui.game.position_key()
	click_square("e2", MOUSE_BUTTON_RIGHT)
	check(ui.inspected == ui.Rules.square("e2") and ui.selected == -1 and not ui.preview.hypothetical, "Right-click own piece inspects, not selects")
	click_square("e4")
	check(ui.game.position_key() == initial, "Left-click inspected destination cannot execute preview")
	click_square("e7", MOUSE_BUTTON_RIGHT)
	check(ui.inspected == ui.Rules.square("e7") and ui.preview.hypothetical and ui.detail.text.contains("if this side moved now"), "Right-click opposing piece labels off-turn preview")
	check(ui.game.position_key() == initial, "Right-click both sides leaves game unchanged")
	ui.set_difficulty(2)
	await start_black_engine_turn()
	check(ui.search_active, "AI search starts on worker thread")
	click_square("e7", MOUSE_BUTTON_RIGHT)
	check(ui.inspected == ui.Rules.square("e7"), "Can inspect engine army during search")
	click_square("e7"); click_square("e5")
	check(ui.game.turn == -1 and ui.game.board[ui.Rules.square("e7")] == -1, "Human cannot play the engine's turn")
	var responsiveness = await settle()
	print("RESPONSIVENESS " + str(responsiveness))
	check(ui.game.turn == 1 and not ui.last_search.is_empty(), "AI returns and applies a legal reply")
	check(responsiveness.frames > 10 and responsiveness.max_frame_gap_ms < 250, "Frames continue while AI searches")
	await start_black_engine_turn()
	var before = Time.get_ticks_msec()
	ui.restart()
	await settle()
	check(ui.game.turn == 1 and ui.last_move.is_empty() and Time.get_ticks_msec() - before < 400, "Restart cancels promptly and rejects stale move")
	await start_black_engine_turn()
	ui.set_mode(0)
	await settle()
	check(ui.mode == 0 and ui.game.turn == 1 and ui.last_move.is_empty(), "Mode change rejects stale search")
	await start_black_engine_turn()
	ui.set_side(-1)
	check(ui.flipped(), "Black human view rotates board")
	# Reconfigure again before the engine's new opening move completes.
	ui.set_side(1)
	await settle()
	check(ui.game.turn == 1 and ui.last_move.is_empty(), "Side change rejects old result even at identical initial position")
	await start_black_engine_turn()
	var old_generation = ui.search_generation
	ui.set_difficulty(0)
	await settle()
	check(ui.generation > old_generation and ui.game.turn == 1 and ui.last_search.elapsed_ms <= 1000 and ui.last_search.depth > 0, "Difficulty change cancels and searches with new limits")
	await start_black_engine_turn()
	ui.game.result = "Draw — test terminal event"
	ui.invalidate_search()
	ui.refresh()
	await settle()
	check(ui.game.turn == -1 and ui.game.result == "Draw — test terminal event", "Terminal draw during search rejects pending move")
	ui.set_mode(1)
	ui.set_side(1)
	ui.game.load_fen("7k/5K2/6B1/8/8/8/p7/8 b - - 0 1")
	ui.refresh()
	await settle()
	check(ui.game.board[56] == -5 and not ui.promotion.visible, "AI promotion applies directly without human dialog")
	ui.restart()
	ui.game.load_fen("7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
	ui.human_side = -1
	ui.refresh()
	await settle()
	check(ui.game.result == "White wins — checkmate" and ui.status.text.contains("checkmate"), "AI checkmate stops further searches")
	ui.set_mode(0)
	ui.game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	ui.refresh()
	click_square("a7"); click_square("a8")
	check(ui.promotion.visible, "Human promotion dialog still opens")
	ui.set_mode(1)
	check(not ui.promotion.visible and ui.pending.is_empty() and ui.game.board[8] == -1, "Mode reset clears pending human promotion")
	ui.set_mode(0)
	ui.agreement.confirmed.emit()
	click_square("e7", MOUSE_BUTTON_RIGHT)
	check(ui.inspected == ui.Rules.square("e7") and ui.detail.text.contains("game has ended"), "Ended game permits labeled study without moves")
	root.size = Vector2i(660,900)
	root.content_scale_size = Vector2i(660,900)
	await process_frame
	ui.layout_board()
	check(ui.ORIGIN.x >= 0 and ui.sidebar.position.y > ui.ORIGIN.y + ui.CELL * 8 and ui.sidebar.size.y > 0, "Narrow layout stacks board and scrollable controls")
	print("UI ENGINE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
