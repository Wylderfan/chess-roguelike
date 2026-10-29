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
func click_square(square: String) -> void:
	var s = ui.Rules.square(square)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = ui.ORIGIN + Vector2(s % 8, s / 8) * ui.CELL + Vector2.ONE * ui.CELL / 2
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	root.size = Vector2i(1000,800)
	root.content_scale_size = Vector2i(1000,800)
	await process_frame
	ui.set_mode(0)
	check(ui.status.text == "White to move", "Scene starts with White to move")
	click_square("e2")
	check(ui.selected == ui.Rules.square("e2"), "Mouse event selects white pawn")
	click_square("e5")
	check(ui.game.turn == 1 and ui.game.board[ui.Rules.square("e2")] == 1, "Illegal destination leaves position intact")
	click_square("e2"); click_square("e4")
	check(ui.game.turn == -1 and ui.game.board[ui.Rules.square("e4")] == 1, "Mouse events play e2-e4 and change turn")
	ui.restart()
	check(ui.game.turn == 1 and ui.game.board[ui.Rules.square("e2")] == 1 and ui.last_move.is_empty(), "Restart resets board, turn and highlights")
	ui.game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	ui.refresh()
	click_square("a7"); click_square("a8")
	check(ui.promotion.visible and ui.game.board[8] == 1, "Promotion waits for choice")
	ui.promotion.custom_action.emit("2")
	check(ui.game.board[0] == 2 and not ui.promotion.visible, "Promotion dialog choice applies knight")
	ui.restart()
	for pair in [["f2","f3"],["e7","e5"],["g2","g4"],["d8","h4"]]:
		click_square(pair[0]); click_square(pair[1])
	check(ui.status.text == "Black wins — checkmate", "Mouse sequence displays checkmate")
	ui.restart()
	ui.agreement.confirmed.emit()
	check(ui.status.text == "Draw — agreement" and ui.legal.is_empty(), "Draw agreement disables moves")
	await process_frame
	print("UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
