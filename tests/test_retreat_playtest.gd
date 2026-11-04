extends SceneTree
const Rules=preload("res://rules.gd")
const Bridge=preload("res://engine.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var plies=0
	var retreats=0
	var failures=0
	for ability in ["white", "both"]:
		var g=Rules.new();g.configure_retreat(ability)
		# Seed a legal retreat before continuing full engine play.
		for move in ["e2e4", "e7e5", "e4e3"]:
			for m in g.legal_moves():
				if Rules.uci_name(m)==move: g.play(m);break
		for ply in 32:
			if g.result!="":break
			var answer=Bridge.new().search(g,100)
			if answer.error!="" or answer.move.is_empty():
				printerr("FAIL playtest ",ability," ",ply," ",answer.error);failures+=1;break
			var m=answer.move
			if abs(g.board[m.from])==Rules.PAWN and (m.to-m.from)*g.turn==8:retreats+=1
			print("PLAY ",ability," ",g.uci_name(m)," depth=",answer.depth," nodes=",answer.nodes," ms=",answer.elapsed_ms)
			if not g.play(m):failures+=1;break
			plies+=1
	print("RETREAT PLAYTEST: %d engine plies, %d engine-selected retreats, %d failures" %[plies,retreats,failures])
	quit(1 if failures else 0)
