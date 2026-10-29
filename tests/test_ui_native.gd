extends SceneTree
var ui
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else: print("PASS: " + label)
func wait_for_turn(timeout = 6000) -> void:
	var deadline = Time.get_ticks_msec() + timeout
	while (ui.search_active or (ui.mode == 1 and ui.game.turn != ui.human_side and ui.game.result == "" and ui.engine_fault == "")) and Time.get_ticks_msec() < deadline:
		await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.size = Vector2i(1180,900)
	root.add_child(ui)
	await process_frame
	ui.set_difficulty(0)
	ui.set_side(-1)
	await wait_for_turn()
	check(ui.flipped() and ui.game.turn == -1 and ui.game.move_log.size() == 1, "Black-side start: engine plays White, board stays rotated")
	check(ui.engine_fault == "" and not ui.last_search.move.is_empty(), "Compiled engine reply verified and recorded")
	ui.set_side(1)
	ui.set_difficulty(2)
	ui.finish_move({"from":52,"to":36,"promotion":0})
	var deadline = Time.get_ticks_msec() + 3000
	while (not ui.search_active or ui.thinker.process_id <= 0) and Time.get_ticks_msec() < deadline: await process_frame
	var before = ui.game.position_key()
	ui.inspect_square(12)
	check(ui.inspected == 12, "Preview remains available while native process runs")
	var pid = ui.thinker.process_id
	if OS.get_name() == "Windows": OS.execute("taskkill", ["/PID",str(pid),"/F"])
	else: OS.execute("/bin/kill", ["-9",str(pid)])
	await wait_for_turn()
	check(ui.engine_fault != "" and ui.engine_status.text.contains("Choose Local"), "Native process failure is displayed with recovery controls")
	check(ui.game.position_key() == before and not ui.search_active, "Failure leaves position intact and does not spin/retry")
	ui.set_mode(0)
	check(ui.engine_fault == "" and ui.human_can_play(), "Local mode recovers from native failure")
	ui.set_mode(1)
	ui.set_difficulty(0)
	ui.set_side(-1)
	await wait_for_turn()
	check(ui.engine_fault == "" and ui.game.turn == -1, "New game successfully restarts compiled engine after failure")
	print("UI NATIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
