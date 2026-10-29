extends SceneTree
const Rules = preload("res://rules.gd")
const Native = preload("res://engine.gd")
const Baseline = preload("res://tests/baseline/engine_v02.gd")
func _initialize() -> void:
	var wins = 0
	var losses = 0
	var draws = 0
	var capped = 0
	var openings = [["e2e4","e7e5"], ["d2d4","d7d5"]]
	for opening in openings:
		for native_side in [1,-1]:
			var g = Rules.new()
			for text in opening:
				for m in g.legal_moves():
					if Rules.uci_name(m) == text:
						g.play(m)
						break
			var moves: Array = opening.duplicate()
			for ply in 100:
				if g.result != "": break
				var engine = Native.new() if g.turn == native_side else Baseline.new()
				var answer = engine.search(g.copy_position(true), 150, 6)
				if answer.get("error", "") != "":
					printerr("COMPARISON ERROR " + answer.error)
					quit(1)
					return
				if answer.claim and g.claim_draw(): break
				if not g.play(answer.move):
					printerr("COMPARISON ERROR illegal move")
					quit(1)
					return
				moves.append(Rules.uci_name(answer.move))
			var winner = 1 if g.result.begins_with("White wins") else (-1 if g.result.begins_with("Black wins") else 0)
			if winner == native_side: wins += 1
			elif winner != 0: losses += 1
			elif g.result != "": draws += 1
			else: capped += 1
			print("GAME native_side=%d opening=%s result=%s plies=%d moves=%s" % [native_side,str(opening),g.result if g.result != "" else "100-ply cap, not adjudicated",moves.size()," ".join(moves)])
	print("COMPARISON native wins=%d losses=%d draws=%d capped=%d; 150ms search budget each, four games only, no Elo inference" % [wins,losses,draws,capped])
	quit()
