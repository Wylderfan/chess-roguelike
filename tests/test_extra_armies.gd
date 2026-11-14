extends SceneTree
const Rules=preload("res://rules.gd")
const Setup=preload("res://setup.gd")
const EngineAI=preload("res://engine.gd")
var ui
var checks=0
var failures=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+text)
	else:print("PASS: "+text)
func move_for(g,uci:String)->Dictionary:
	for m in g.legal_moves():
		if Rules.uci_name(m)==uci:return m
	return {}
func click(point:Vector2)->void:
	var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e)
	e=e.duplicate();e.pressed=false;root.push_input(e)
func wait_search()->void:
	var end=Time.get_ticks_msec()+7000
	while Time.get_ticks_msec()<end:
		if not ui.search_active and (ui.game.turn==ui.human_side or ui.game.result!="" or ui.engine_fault!=""):return
		await process_frame
func reveal(control:Control)->void:
	# Container ranges settle on deferred layout, especially in headless runs.
	for i in 10:
		await process_frame
		ui.sidebar.ensure_control_visible(control)
		await process_frame
		if ui.sidebar.get_global_rect().encloses(control.get_global_rect()):return

func count_nodes(g,depth:int)->int:
	if depth==0:return 1
	var total=0
	for m in g.legal_moves():
		var next=g.copy_position();next.apply_unchecked(m);total+=count_nodes(next,depth-1)
	return total

func capture(name:String)->void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(args[1]);root.get_texture().get_image().save_png(args[1].path_join(name+".png"))
func _initialize()->void:call_deferred("run")
func run()->void:
	ui=load("res://main.tscn").instantiate();root.size=Vector2i(1180,900);root.add_child(ui);await process_frame;ui.set_mode(0)
	ui.open_setup()
	check(ui.setup_side_choice.get_item_text(0)=="White" and ui.setup_side_choice.get_item_text(1)=="Black","Side options are just White and Black")
	# Actual preparation -> play -> castling -> history on all four wings.
	for fixture in [[1,[61,62],"e1g1",62,61,"kq"],[1,[57,58,59],"e1c1",58,59,"kq"],[-1,[5,6],"e8g8",6,5,"KQ"],[-1,[1,2,3],"e8c8",2,3,"KQ"]]:
		ui.open_setup();ui.setup_mode=0;ui.setup.position.turn=fixture[0]
		for square in fixture[1]:ui.setup.edit(square,0)
		ui.refresh_setup()
		check(ui.setup.position.rights=="KQkq","Unrelated setup removals preserve all original castling rights")
		check(ui.start_setup(),"Cleared-wing composed position starts")
		var m=move_for(ui.game,fixture[2]);check(not m.is_empty(),"Castling generated for "+fixture[2])
		ui.finish_move(m)
		check(ui.game.board[fixture[3]]==fixture[0]*6 and ui.game.board[fixture[4]]==fixture[0]*4 and ui.game.rights==fixture[5],"King and rook move; own castling rights consumed")
		ui.browse_history(0)
		check(ui.displayed_game().rights=="KQkq" and ui.records[0].san.begins_with("O-O"),"Castling SAN and custom-start history preserved")
		ui.return_to_live()
	var s=Setup.new();s.edit(63,4)
	check(s.position.rights=="Qkq","Replacing even identical home rook clears its right")
	s.set_castling("K",true);check(s.position.rights=="KQkq","Explicit composed-start right can be restored for valid pair")
	s.relocate(63,55);s.relocate(55,63)
	check(not "K" in s.position.rights,"Returning a moved rook never infers castling history")
	s.edit(60,6);check(s.position.rights=="kq","Replacing king clears both own rights only")
	s.edit(0,0);s.set_castling("q",true);check(not "q" in s.position.rights,"Absent rook cannot gain castling right")
	ui.open_setup();ui.setup.edit(63,0);ui.refresh_setup()
	check(ui.setup_castling_checks.K.disabled and not ui.setup_castling_checks.Q.disabled,"Castling controls disable only unavailable pairs")
	ui.apply_setup_odds(0);ui.choose_setup_tool(5);click(ui.square_rect(44).get_center())
	check(ui.setup.position.board[44]==5 and ui.setup.validation_error()=="" and ui.setup.position.material_balance()==9,"Palette adds a genuine second queen without removing another piece")
	await capture("extra-queen-setup")
	check(ui.start_setup() and ui.captures_label.text=="White captured: —\nBlack captured: —" and ui.game.material_balance()==9,"Extra starting material is not a capture")
	ui.open_setup();ui.sidebar.scroll_vertical=9999;await process_frame;await process_frame
	var box:CheckBox=ui.setup_ability_checks["blackQueen Exchange"]
	await reveal(box)
	var bounds=box.get_global_rect();var minimum=box.get_combined_minimum_size()
	await capture("checkbox-off")
	click(bounds.get_center());await process_frame
	check(box.button_pressed and box.get_global_rect()==bounds and box.get_combined_minimum_size()==minimum,"Mouse checked state leaves checkbox text/control geometry fixed")
	check(box.get_theme_icon("checked").get_size()==Vector2(22,22) and box.get_theme_icon("unchecked").get_size()==Vector2(22,22),"Checked and unchecked indicators have identical dimensions")
	await capture("checkbox-on-hover")
	box.grab_focus();var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key);key=key.duplicate();key.pressed=false;root.push_input(key);await process_frame
	check(not box.button_pressed and box.get_global_rect()==bounds,"Keyboard toggling and focus preserve geometry")
	await capture("checkbox-keyboard")
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style=box.get_theme_stylebox(state)
		check(style.content_margin_left==12 and style.content_margin_right==12 and style.content_margin_top==10 and style.content_margin_bottom==10,"Stable checkbox padding: "+state)
	root.size=Vector2i(600,900);await process_frame;ui.layout_board();ui.sidebar.scroll_vertical=9999;await process_frame
	await reveal(box)
	bounds=box.get_global_rect();click(bounds.get_center());await process_frame
	check(box.button_pressed and box.get_global_rect()==bounds and bounds.end.x<=600,"Narrow checked layout stays aligned and within viewport")
	await capture("checkbox-narrow")
	for side in ["white","black"]:
		for ability in Setup.PLANNED_ABILITIES:ui.setup.set_planned(side,ability,true)
	var inactive=ui.setup.create_game()
	check(inactive.ability_state.is_empty() and inactive.position_key()==Rules.new().position_key(),"All planned checkboxes selected still leave orthodox identity and inactive state")
	check(count_nodes(inactive,2)==400,"Planned checkboxes selected still pass initial depth-2 perft")
	ui.cancel_setup();root.size=Vector2i(1180,900);await process_frame
	var corpus=JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/positions.json"))
	for f in corpus.positions:
		if (f.name.begins_with("max-") and not "-walk-" in f.name) or f.name in ["221-legal-moves","129-captures","nine-isolated-pawns","ten-queens-after-promotion"]:
			var draft=Setup.new();draft.position.load_fen(f.fen)
			check(draft.validation_error()=="","Supported boundary setup accepted: "+f.name)
			var g=draft.create_game();var key_before=g.position_key()
			var answer=EngineAI.new().search(g.copy_position(true),30)
			check(answer.error=="" and not answer.move.is_empty() and g.position_key()==key_before,"Native search and both-side threat/legal parity: "+f.name)
	# Over-cap rejection is independent of per-type mix; promotions leave count unchanged.
	var too_many=Setup.new();too_many.position.board.fill(0);too_many.position.board[63]=6;too_many.position.board[0]=-6
	for square in range(8,40):too_many.position.board[square]=2
	check(too_many.validation_error().contains("32 pieces"),"33-piece side is rejected before native loading")
	for human in [1,-1]:
		ui.open_setup();ui.setup_mode=1;ui.setup_side=human;ui.setup_level=0
		ui.setup.edit(44 if human==1 else 20,human*5);ui.setup.position.turn=-human
		check(ui.start_setup(),"Extra-queen game starts for human side "+str(human))
		await wait_search();check(ui.engine_fault=="" and ui.records.size()==1,"Engine plays legally against extra queen")
		ui.finish_move(ui.game.legal_moves()[0]);await wait_search()
		check(ui.engine_fault=="" and ui.records.size()==3 and ui.game.ability_state.is_empty(),"Second engine reply retains extra-army history and inactive ability state")
	ui.set_mode(0)
	print("EXTRA ARMIES: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
