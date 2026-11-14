extends SceneTree
var ui
var checks = 0
var failures = 0
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
	else: print("PASS: " + message)
func frames(count = 3):
	for i in count: await process_frame
func move(uci: String):
	for m in ui.game.legal_moves():
		if ui.Rules.uci_name(m) == uci: ui.finish_move(m); return
	check(false, "legal fixture move " + uci)
func _initialize(): call_deferred("run")
func run():
	ui = load("res://main.tscn").instantiate()
	ui.preferences_path = "user://test-menu-preferences.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.preferences_path))
	root.add_child(ui); await frames()
	check(ui.screen == "menu" and ui.menu_panel.visible and not ui.sidebar.visible and not ui.has_match, "Boot opens main menu without a live match")
	check(ui.difficulty == 1 and ui.BUDGETS == [300,1100,2600] and ui.rules_profile == "standard", "Default difficulty and profile unchanged")
	ui.game.turn = -1; await frames(8)
	check(not ui.search_active and not ui.human_can_play(), "Menu cannot launch native search or accept board moves")
	ui.show_settings(); ui.coordinates_check.button_pressed = false
	check(ui.screen == "settings" and not ui.show_coordinates and not ui.menu_panel.visible, "Settings coordinate toggle is functional")
	var second = load("res://main.tscn").instantiate(); second.preferences_path = ui.preferences_path
	root.add_child(second); await frames()
	check(not second.show_coordinates and not second.coordinates_check.button_pressed, "Coordinate preference reloads in a fresh scene")
	second.queue_free(); await frames()
	ui.coordinates_check.button_pressed = true; ui.show_main_menu()
	ui.open_setup(); check(ui.editing and ui.screen == "setup" and ui.setup_level == 1, "Create Sandbox Game opens full setup with default difficulty")
	ui.cancel_setup(); check(ui.screen == "menu" and not ui.has_match, "Cancel first sandbox returns to menu")
	ui.open_setup(); ui.setup_mode = 0
	check(ui.start_setup() and ui.screen == "game" and ui.has_match, "Start enters a real sandbox match")
	check(not ui.mode_choice.is_visible_in_tree() and not ui.side_choice.is_visible_in_tree() and not ui.level_choice.is_visible_in_tree() and not ui.profile_choice.is_visible_in_tree(), "Live sidebar contains no per-match editing controls")
	for uci in ["e2e4","f7f6","d1h5","g7g6"]: move(uci)
	check(ui.records[2].san.contains("+") and ui.positions[3].in_check(-1), "Regression fixture includes Qh5+ then a check evasion")
	for dimensions in [Vector2i(1100,812),Vector2i(1180,812),Vector2i(1000,800),Vector2i(700,820),Vector2i(600,760)]:
		root.size = dimensions; root.content_scale_size = dimensions; ui.layout_board()
		ui.browse_history(2); await frames()
		var previous = ui.previous_button.get_global_rect()
		var next = ui.next_button.get_global_rect()
		var live = ui.live_button.get_global_rect()
		for repetition in 4:
			ui.next_button.pressed.emit(); await frames()
			check(ui.current_ply() == 3 and ui.check_status.text == "Check", "Next reaches checking position " + str(dimensions))
			check(previous == ui.previous_button.get_global_rect() and next == ui.next_button.get_global_rect() and live == ui.live_button.get_global_rect(), "All history button rects fixed on check " + str(dimensions))
			ui.previous_button.pressed.emit(); await frames()
			check(ui.current_ply() == 2 and ui.check_status.text == "" and previous == ui.previous_button.get_global_rect(), "Previous clears check without moving controls " + str(dimensions))
		print("FIXED HISTORY ", dimensions, " previous=",previous," next=",next," live=",live)
	ui.return_to_live(); var before = ui.game.position_key(); var records = ui.records.size()
	ui.open_setup(); ui.setup.edit(52,0); ui.cancel_setup()
	check(ui.screen == "game" and ui.game.position_key() == before and ui.records.size() == records, "New Game draft cancel preserves current position/history")
	ui.open_setup(); ui.request_start_setup(); await frames()
	check(ui.transition_action == "start" and ui.game.position_key() == before, "Starting replacement asks before discarding live match")
	ui.transition_dialog.hide(); ui.transition_dialog.canceled.emit(); ui.cancel_setup()
	ui.request_return_to_menu(); await frames()
	check(ui.transition_action == "menu" and ui.transition_dialog.visible, "Quit to Menu protects unfinished match")
	ui.transition_dialog.hide(); ui.transition_dialog.canceled.emit()
	check(ui.screen == "game" and ui.game.position_key() == before, "Cancel return-to-menu keeps match")
	ui.request_return_to_menu(); ui.confirm_transition()
	check(ui.screen == "menu" and not ui.has_match and not ui.search_active and ui.records.is_empty(), "Confirmed return discards match and stops search")
	ui.open_setup(); ui.setup_mode=1; ui.setup_side=1; ui.setup_level=0
	ui.choose_setup_tool(98); ui.setup_square(52); ui.upgrade_retreat.button_pressed=true
	ui.upgrade_rarity.select(2); ui.upgrade_rarity.item_selected.emit(2)
	check(ui.setup.position.pawn_can_retreat(52) and ui.upgrade_slots.text.contains("1 / 2"), "Sandbox retains Workshop and reserved second slot")
	check(ui.start_setup(), "Start upgraded engine sandbox")
	move("e2e4")
	var until = Time.get_ticks_msec()+10000
	while not ui.search_active and Time.get_ticks_msec()<until: await process_frame
	check(ui.search_active, "Native engine starts during match")
	ui.request_return_to_menu(); await frames(10)
	check(ui.game.move_log.size()==1, "Pending exit confirmation cancels search and rejects stale reply")
	ui.transition_dialog.hide(); ui.transition_dialog.canceled.emit()
	until = Time.get_ticks_msec()+10000
	while ui.game.move_log.size()<2 and ui.engine_fault=="" and Time.get_ticks_msec()<until: await process_frame
	check(ui.engine_fault=="" and ui.game.move_log.size()==2, "Cancel exit resumes exactly one legal engine reply")
	ui.open_setup(); ui.cancel_setup()
	ui.request_return_to_menu(); ui.confirm_transition(); await frames(15)
	check(ui.screen=="menu" and not ui.search_active and ui.game.move_log.is_empty(), "No native reply can cross confirmed menu transition")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.preferences_path))
	print("MENU AND CHECK HISTORY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
