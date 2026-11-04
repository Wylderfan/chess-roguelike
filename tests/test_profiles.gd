extends SceneTree
var ui
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	var until = Time.get_ticks_msec() + 7000
	while (ui.search_active or (ui.game.turn != ui.human_side and ui.engine_fault == "")) and Time.get_ticks_msec() < until: await process_frame
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.size = Vector2i(1180, 900)
	root.add_child(ui)
	await process_frame
	check(ui.rules_profile == "standard", "Standard profile defaults on")
	ui.set_profile(1)
	check(ui.rules_profile == "conservative" and ui.profile_choice.selected == 1, "Conservative selection is explicit and independent of planned abilities")
	ui.set_difficulty(0)
	ui.set_side(-1)
	await settle()
	check(ui.engine_fault == "" and ui.game.move_log.size() == 1 and ui.game.turn == -1, "Conservative engine plays legal White move through verified bridge")
	check(ui.thinker.rules_profile == "conservative" and ui.game.ability_state.is_empty(), "Chosen profile reaches worker without activating ability state")
	ui.set_side(1)
	ui.finish_move({"from":52,"to":36,"promotion":0})
	await settle()
	check(ui.engine_fault == "" and ui.game.move_log.size() == 2 and ui.game.turn == 1, "Conservative engine plays Black from normal move history")
	ui.set_difficulty(2)
	ui.set_side(-1)
	var until = Time.get_ticks_msec() + 3000
	while not ui.search_active and Time.get_ticks_msec() < until: await process_frame
	var old_generation = ui.generation
	ui.set_profile(0)
	check(ui.generation > old_generation, "Profile change invalidates pending search")
	ui.set_difficulty(0)
	await settle()
	check(ui.engine_fault == "" and ui.game.move_log.size() == 1 and ui.thinker.rules_profile == "standard", "No stale or duplicate move after profile change")
	ui.set_profile(1)
	ui.restart()
	ui.set_mode(0)
	await process_frame
	check(ui.game.move_log.is_empty() and ui.human_can_play(), "Restart/local switch cancels profile search")
	var bad = ui.EngineAI.new()
	bad.rules_profile = "unsupported"
	check(bad.search(ui.game.copy_position(true), 10).error != "", "Unknown profile fails closed in bridge")
	print("PROFILES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
