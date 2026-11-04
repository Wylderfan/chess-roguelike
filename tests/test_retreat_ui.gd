extends SceneTree
var checks = 0
var failures = 0
var ui
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + msg)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui.set_mode(0); ui.open_setup()
	ui.setup_retreat_checks.white.button_pressed = true
	check(ui.setup.retreat_value() == "white", "Live checkbox configures draft")
	check(ui.start_setup() and ui.game.retreat_setting() == "white", "Start enables only White")
	ui.finish_move({"from":52,"to":36,"promotion":0})
	ui.finish_move({"from":12,"to":28,"promotion":0})
	ui.finish_move({"from":36,"to":44,"promotion":0})
	check(ui.game.move_log == ["e2e4","e7e5","e4e3"], "Actual UI executes retreat")
	check(ui.game.board[44] == 1 and ui.engine_fault == "", "Board updated without engine fault")
	ui.open_setup(); ui.setup_retreat_checks.black.button_pressed = true; ui.cancel_setup()
	check(ui.game.retreat_setting() == "white" and ui.game.move_log.size() == 3, "Cancel leaves live rule and game unchanged")
	ui.restart()
	check(ui.game.ability_state.is_empty() and ui.game.move_log.is_empty(), "Restart clears ability")
	ui.open_setup(); ui.setup_retreat_checks.black.button_pressed = true
	ui.setup.position.load_fen("7k/8/8/4p3/4P3/8/8/K7 b - - 0 1")
	ui.setup.sync_retreat(); ui.setup_mode = 1; ui.setup_side = 1; ui.setup_level = 0
	check(ui.start_setup(), "Start Black ability engine test")
	var deadline = Time.get_ticks_msec() + 12000
	while ui.game.move_log.is_empty() and ui.engine_fault == "" and Time.get_ticks_msec() < deadline: await process_frame
	check(ui.engine_fault == "" and ui.game.move_log.size() == 1, "Engine plays with Black ability: " + ui.engine_fault)
	ui.set_mode(0)
	print("RETREAT UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
