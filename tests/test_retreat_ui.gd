extends SceneTree
var checks = 0
var failures = 0
var ui
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + msg)
func _initialize() -> void: call_deferred("run")
func equip(square: int) -> void:
	ui.choose_setup_tool(98);ui.setup_square(square);ui.upgrade_retreat.button_pressed=true
func run() -> void:
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	await process_frame
	ui.set_mode(0);ui.open_setup();equip(52)
	check(ui.setup.position.retreat_squares()==["e2"],"Checkbox equips only selected pawn")
	check(not ui.setup.position.pawn_can_retreat(51),"Neighboring pawn remains ordinary")
	var identity=ui.setup.position.get_piece_data(52).id
	ui.choose_setup_tool(99);ui.setup_square(52);ui.setup_square(44)
	check(ui.setup.position.get_piece_data(44).id==identity and ui.setup.position.pawn_can_retreat(44),"Editor move preserves identity and upgrade")
	ui.choose_setup_tool(98);ui.setup_square(44)
	ui.upgrade_rarity.select(1);ui.upgrade_rarity.item_selected.emit(1)
	check(ui.setup.position.get_piece_data(44).rarity=="rare" and ui.upgrade_slots.text.contains("1 / 2"),"Rare opens second empty slot without fake ability")
	ui.choose_setup_tool(101);ui.setup_square(35)
	check(ui.setup.position.pawn_can_retreat(35),"Direct upgraded pawn placement")
	ui.choose_setup_tool(0);ui.setup_square(35)
	check(not ui.setup.position.pawn_can_retreat(35),"Erase removes upgrade")
	ui.choose_setup_tool(98);ui.setup_square(57)
	check(ui.upgrade_retreat.disabled,"Knight cannot equip pawn ability")
	check(ui.start_setup() and ui.game.retreat_squares()==["e3"],"Start transfers selective state")
	ui.finish_move({"from":44,"to":52,"promotion":0})
	check(ui.game.move_log==["e3e2"] and ui.game.pawn_can_retreat(52),"Live retreat carries its upgrade")
	ui.browse_history(0)
	check(ui.displayed_game().pawn_can_retreat(44) and not ui.displayed_game().pawn_can_retreat(52),"History restores original upgrade square")
	ui.return_to_live();ui.open_setup()
	check(ui.setup.position.pawn_can_retreat(44) and ui.setup.position.get_piece_data(44).rarity=="rare","Reopen edits original upgraded army, not midgame")
	ui.setup.edit(44,0);ui.cancel_setup()
	check(ui.game.pawn_can_retreat(52) and ui.game.move_log.size()==1,"Cancel leaves live piece identity untouched")
	ui.restart()
	check(ui.game.ability_state.is_empty() and ui.game.move_log.is_empty(),"Restart clears upgrades")
	ui.open_setup();ui.setup.position.load_fen("7k/8/8/4pp2/4PP2/8/8/K7 b - - 0 1")
	equip(28)
	ui.setup_mode=1;ui.setup_side=1;ui.setup_level=0
	check(ui.start_setup(),"Start selective Black ability engine position")
	var deadline=Time.get_ticks_msec()+12000
	while ui.game.move_log.is_empty() and ui.engine_fault=="" and Time.get_ticks_msec()<deadline:await process_frame
	check(ui.engine_fault=="" and ui.game.move_log.size()==1,"Engine plays selective Black ability: "+ui.engine_fault)
	ui.set_mode(0)
	print("RETREAT UI: %d checks, %d failures" %[checks,failures])
	quit(1 if failures else 0)
