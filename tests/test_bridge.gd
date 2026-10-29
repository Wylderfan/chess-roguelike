extends SceneTree
const Rules = preload("res://rules.gd")
const EngineAI = preload("res://engine.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else: print("PASS: " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixtures = [
		"r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
		"4kr2/8/8/8/8/8/8/4K2R w K - 0 1",
		"4k1r1/8/8/8/8/8/8/4K2R w K - 0 1",
		"4r1k1/8/8/8/8/8/8/4K2R w K - 0 1",
		"4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1",
		"k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1",
		"4k3/8/8/r4pPK/8/8/8/8 w - f6 0 1",
		"4k3/P7/8/8/8/8/8/4K3 w - - 0 1",
		"4k3/8/8/8/8/8/p7/4K3 b - - 0 1",
		"4r1k1/8/8/8/8/8/4N3/4K3 w - - 0 1",
		"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
		"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"]
	for fen in fixtures:
		var g = Rules.new()
		g.load_fen(fen)
		var result = EngineAI.new().search(g.copy_position(true), 10)
		check(result.error == "" and not result.move.is_empty(), "Exact both-side legal/threat agreement: " + fen + " " + result.error)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7303
	var game = Rules.new()
	for ply in 40:
		var legal = game.legal_moves()
		if game.result != "": break
		game.play(legal[rng.randi_range(0,legal.size()-1)])
		if game.result != "": break
		var result = EngineAI.new().search(game.copy_position(true), 5)
		check(result.error == "" and not result.move.is_empty(), "Random-history position agreement ply %d: %s" % [ply+1,result.error])
	game = Rules.new()
	game.ability_state = {"white_used": 1}
	var copy = game.copy_position(true)
	check(copy.ability_state == game.ability_state and copy.position_key() == game.position_key(), "Ability placeholder copies and changes identity")
	check(EngineAI.new().search(copy, 10).error != "", "Unimplemented abilities fail closed")
	game = Rules.new()
	var worker = EngineAI.new()
	var thread = Thread.new()
	thread.start(worker.search.bind(game.copy_position(true), 2600))
	var deadline = Time.get_ticks_msec() + 3000
	while worker.process_id <= 0 and thread.is_alive() and Time.get_ticks_msec() < deadline: await process_frame
	if worker.process_id > 0:
		if OS.get_name() == "Windows": OS.execute("taskkill", ["/PID", str(worker.process_id), "/F"])
		else: OS.execute("/bin/kill", ["-9", str(worker.process_id)])
	while thread.is_alive() and Time.get_ticks_msec() < deadline: await process_frame
	worker.cancel()
	var result = thread.wait_to_finish()
	check(result.error != "" or result.canceled, "Process failure terminates search without illegal move")
	check(result.move.is_empty(), "Failed process cannot produce playable result")
	print("BRIDGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
