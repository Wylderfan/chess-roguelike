extends SceneTree
const Setup = preload("res://setup.gd")
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
func validation(fen: String, error: String) -> void:
	var setup = Setup.new()
	setup.position.load_fen(fen)
	var message = setup.validation_error()
	check(message.contains(error) if error != "" else message == "", "Setup validation: " + (error if error != "" else "playable position allowed"))
func move_for(game, uci: String) -> Dictionary:
	for m in game.legal_moves():
		if Rules.uci_name(m) == uci: return m
	return {}
func mouse(square: String, pressed: bool, button = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	event.position = ui.square_rect(Rules.square(square)).get_center()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event)
func click(square: String, button = MOUSE_BUTTON_LEFT) -> void:
	mouse(square,true,button); mouse(square,false,button)
func drag(a: String, b: String) -> void:
	mouse(a,true)
	var event = InputEventMouseMotion.new()
	event.position = ui.square_rect(Rules.square(b)).get_center()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)
	mouse(b,false)
func wait_search() -> void:
	var until = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < until:
		if not ui.search_active and (ui.editing or ui.mode == 0 or ui.game.turn == ui.human_side or ui.engine_fault != "" or ui.game.result != ""): return
		await process_frame
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
	var draft = Setup.new()
	check(draft.validation_error() == "" and draft.fen() == Rules.new().initial_fen, "Standard draft roundtrips to exact FEN")
	validation("4k3/8/8/8/8/8/8/R7 w - - 0 1", "White needs exactly one king")
	validation("4k3/8/8/8/8/8/8/R2KK3 w - - 0 1", "White needs exactly one king")
	validation("8/8/8/8/8/8/4k3/R3K3 w - - 0 1", "adjacent")
	validation("P3k3/8/8/8/8/8/8/R3K3 w - - 0 1", "ranks 1 or 8")
	validation("4k3/8/8/8/8/8/8/R3K2p w - - 0 1", "ranks 1 or 8")
	validation("4k2R/8/8/8/8/8/8/r3K3 w - - 0 1", "Both kings")
	validation("4k3/8/8/8/8/8/8/K3R3 w - - 0 1", "side not to move")
	validation("k3r3/8/8/8/8/8/8/4K3 w - - 0 1", "")
	validation("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1", "checkmate")
	validation("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1", "stalemate")
	validation("4k3/8/8/8/8/8/8/4K3 w - - 0 1", "insufficient")
	validation("4k3/8/8/8/8/8/PPPPPPPP/P3K3 w - - 0 1", "ranks 1 or 8")
	validation("4k3/8/8/8/8/P7/PPPPPPPP/4K3 w - - 0 1", "")
	validation("4k3/8/8/8/8/8/8/QQ2K3 w - - 0 1", "")
	validation("4k3/8/8/8/8/8/8/NNN1K3 w - - 0 1", "")
	validation("4k3/8/8/8/8/8/PPPPPPPP/2B1K1B1 w - - 0 1", "")
	for human in [1,-1]:
		for pair in [[Rules.PAWN,1],[Rules.KNIGHT,3],[Rules.ROOK,5],[Rules.QUEEN,9]]:
			draft.odds(pair[0],human)
			check(draft.validation_error() == "" and draft.position.material_balance() == human*pair[1], "Odds inventory and material: human %d removed %d" % [human,pair[0]])
			check(draft.position.rights == (("KQk" if human == 1 else "Kkq") if pair[0] == Rules.ROOK else "KQkq") and draft.position.ep == -1, "Odds preserve untouched castling pairs and clear EP")
	draft.position.load_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	draft.edit(36,0)
	check(draft.position.ep == -1 and draft.fen().split(" ")[3] == "-", "Edited setup cannot preserve stale en-passant rights")
	draft.reset_standard(); draft.edit(3,0); draft.allow_home_castling(true)
	check(draft.position.rights == "KQkq", "Explicit castling uses home kings and rooks")
	draft.edit(0,0)
	check(draft.position.rights == "KQk", "Rook removal clears only its castling right")
	draft.allow_home_castling(true)
	check(draft.position.rights == "KQk", "Missing rook cannot receive castling right")
	draft.relocate(4,12); draft.allow_home_castling(true)
	check(draft.position.rights == "KQ", "Moved king cannot receive castling rights")
	draft.reset_standard()
	var before = draft.create_game()
	for side in ["white","black"]:
		for ability in Setup.PLANNED_ABILITIES: draft.set_planned(side,ability,true)
	var after = draft.create_game()
	check(draft.planned.white.size() == 3 and draft.planned.black.size() == 3, "Independent per-side ability intentions recorded")
	check(before.position_key() == after.position_key() and before.legal_moves() == after.legal_moves() and after.ability_state.is_empty(), "Planned abilities do not alter keys, moves or runtime ability state")
	draft.set_planned("white", "Pawn Dash", false)
	check(not "Pawn Dash" in draft.planned.white and "Pawn Dash" in draft.planned.black, "Per-side checkbox removal is independent")
	ui = load("res://main.tscn").instantiate()
	root.size = Vector2i(1180,900)
	root.add_child(ui)
	await process_frame
	ui.set_mode(0)
	ui.finish_move(move_for(ui.game,"e2e4"))
	var original_key = ui.game.position_key()
	var original_fen = ui.game.initial_fen
	var original_history = ui.game.history.duplicate()
	ui.open_setup()
	check(ui.editing and ui.setup.position.board[52] == 1 and ui.game.position_key() == original_key, "Editor opens fresh draft without altering live game")
	ui.choose_setup_tool(0); click("d8")
	check(ui.setup.position.board[3] == 0 and ui.setup.position.rights == "KQkq" and ui.game.position_key() == original_key, "Unrelated palette erase changes draft only and keeps castling rights")
	ui.choose_setup_tool(-5); click("d8")
	check(ui.setup.position.board[3] == -5, "Palette restores standard piece")
	ui.choose_setup_tool(99); drag("e2","e4")
	check(ui.setup.position.board[36] == 1 and ui.setup.position.board[52] == 0 and not ui.dragging, "Editor drag repositions piece without playing a move")
	click("e7"); click("e5")
	check(ui.setup.position.board[28] == -1 and ui.setup.position.board[12] == 0, "Editor click-to-reposition supports opposing pieces")
	click("e1",MOUSE_BUTTON_RIGHT)
	check(ui.setup_status.text.contains("White needs exactly one king") and not ui.start_setup() and ui.editing, "Invalid setup gives visible error and blocks Start")
	await capture("invalid-setup")
	ui.cancel_setup()
	check(ui.game.position_key() == original_key and ui.game.initial_fen == original_fen and ui.game.history == original_history and ui.records.size() == 1, "Cancel restores exact live position, history and chronicle")
	ui.open_setup(); ui.apply_setup_odds(Rules.QUEEN)
	ui.setup_ability_checks["whitePawn Dash"].button_pressed = true
	ui.setup_ability_checks["blackQueen Exchange"].button_pressed = true
	check(ui.setup.planned.white == ["Pawn Dash"] and ui.setup.planned.black == ["Queen Exchange"], "Actual checkbox signals store independent configuration")
	await capture("queen-odds")
	ui.sidebar.scroll_vertical = 900
	await capture("planned-abilities")
	check(ui.start_setup(), "Valid odds draft starts game")
	check(ui.records.is_empty() and ui.game.move_log.is_empty() and ui.positions.size() == 1 and ui.game.history.size() == 1, "Custom start creates fresh history and empty chronicle")
	check(ui.game.material_balance() == 9 and ui.captures_label.text == "White captured: —\nBlack captured: —", "Queen odds are +9 without imaginary capture")
	check(ui.planned_abilities.white == ["Pawn Dash"] and ui.game.ability_state.is_empty() and ui.game.uci_position().contains(ui.game.initial_fen), "Setup intent separate from empty native state and fresh FEN transport")
	# Normal move/chronicle/history continue from custom board.
	drag("e2","e4")
	check(ui.records[0].san == "e4" and ui.game.move_log == ["e2e4"], "Drag and SAN work after custom start")
	ui.browse_history(0)
	check(ui.displayed_game().material_balance() == 9 and ui.displayed_game().board[52] == 1, "History begins at custom odds board")
	ui.open_setup(); ui.cancel_setup()
	check(ui.history_index == 0 and ui.game.move_log == ["e2e4"], "Cancel setup restores history browsing state")
	ui.return_to_live()
	ui.open_setup(); ui.setup.position.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	ui.refresh_setup(); check(ui.start_setup(), "Valid promotion-ready custom board starts")
	drag("a7","a8")
	check(ui.promotion.visible and ui.records.is_empty(), "Custom-start dragged promotion waits for choice")
	ui.promote("4")
	check(ui.records[0].san == "a8=R+", "Custom-start promotion SAN preserved")
	ui.open_setup(); ui.setup.position.load_fen("k3r3/8/8/8/8/8/8/4K3 w - - 0 1"); ui.refresh_setup()
	check(ui.start_setup() and ui.game.in_check(1) and ui.status.text.contains("Check"), "Legal side-to-move check accepted and displayed")
	# Eight actual native replies: every preset and both human colours.
	for human in [1,-1]:
		for piece in [Rules.PAWN,Rules.KNIGHT,Rules.ROOK,Rules.QUEEN]:
			ui.open_setup(); ui.setup_mode = 1; ui.setup_side = human; ui.setup_level = 0
			ui.apply_setup_odds(piece)
			ui.setup.position.turn = -human
			var expected_fen = ui.setup.fen()
			check(ui.start_setup(), "Native odds start: human %d removed %d" % [human,piece])
			check(ui.game.material_balance() == human * {1:1,2:3,4:5,5:9}[piece] and ui.game.rights == (("KQk" if human == 1 else "Kkq") if piece == Rules.ROOK else "KQkq"), "Native odds setup has intended handicap and only eligible castling rights")
			await wait_search()
			check(ui.engine_fault == "" and ui.game.move_log.size() == 1 and ui.game.turn == human and not ui.last_search.move.is_empty(), "Native legal reply from asymmetric initial FEN")
			check(ui.game.initial_fen == expected_fen and ui.records[0].side == -human and ui.records[0].number == 1 and ui.game.ability_state.is_empty(), "Arbitrary-start FEN, SAN side/number and inactive abilities preserved")
			if human == 1: check(ui.move_list.get_item_text(1).begins_with("1…"), "Black-start chronicle uses 1… notation")
			ui.finish_move(ui.game.legal_moves()[0])
			await wait_search()
			check(ui.engine_fault == "" and ui.game.move_log.size() == 3 and ui.game.turn == human, "Second native odds reply preserves full custom-start move history")
	ui.open_setup(); ui.setup_mode=1; ui.setup_side=-1; ui.setup_level=2; ui.apply_setup_odds(Rules.QUEEN); ui.start_setup()
	var deadline = Time.get_ticks_msec()+1000
	while not ui.search_active and Time.get_ticks_msec()<deadline: await process_frame
	check(ui.search_active, "Native search active before setup interruption")
	var interrupted_key = ui.game.position_key()
	ui.open_setup()
	await wait_search()
	check(not ui.search_active and ui.game.position_key() == interrupted_key and ui.records.is_empty(), "Opening setup cancels live search and rejects stale result")
	ui.cancel_setup(); ui.set_difficulty(0)
	await wait_search()
	check(ui.records.size()==1 and ui.game.turn==-1, "Cancel setup resumes exactly one native reply")
	# Starting a new draft during search also invalidates old generation.
	ui.restart(); ui.set_difficulty(2)
	deadline=Time.get_ticks_msec()+1000
	while not ui.search_active and Time.get_ticks_msec()<deadline: await process_frame
	ui.open_setup(); ui.setup_mode=0; ui.apply_setup_odds(Rules.ROOK)
	check(ui.start_setup(), "Apply new local draft during native search")
	await wait_search()
	check(ui.records.is_empty() and ui.game.material_balance()==-5 and ui.mode==0, "No stale native move after replacing active game")
	ui.open_setup(); ui.setup_mode=1; ui.setup_side=-1; ui.apply_setup_odds(Rules.KNIGHT); ui.choose_setup_tool(0)
	click("d1")
	check(ui.flipped() and ui.setup.position.board[59]==0, "Rotated editor input maps to actual board square")
	ui.apply_setup_odds(0)
	check(ui.setup.position.rights=="KQkq" and ui.setup.position.material_balance()==0, "Reset standard restores material and known starting rights")
	root.size = Vector2i(600,900)
	await process_frame
	ui.layout_board()
	check(ui.sidebar.position.y > ui.ORIGIN.y+ui.CELL*8, "Setup has scrollable stacked narrow layout")
	await capture("narrow-setup")
	ui.cancel_setup(); ui.set_mode(0)
	print("SETUP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
