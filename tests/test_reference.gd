extends SceneTree
const Rules=preload("res://rules.gd")
var failures=0
var checks=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+message)
func names(g) -> Array:
	var out=[]
	for m in g.legal_moves():out.append(Rules.uci_name(m))
	out.sort()
	return out
func perft(g,depth:int) -> int:
	if depth==0:return 1
	var nodes=0
	for m in g.legal_moves():
		var next=g.copy_position();next.apply_unchecked(m)
		nodes+=perft(next,depth-1)
	return nodes
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/positions.json"))
	var count=0
	for fixture in data.positions:
		var g=Rules.new();g.load_fen(fixture.fen)
		var actual=names(g)
		check(actual==fixture.legal,fixture.name+" legal: "+str(actual)+" expected "+str(fixture.legal))
		var other=g.copy_position();other.turn=-other.turn;other.ep=-1
		check(names(other)==fixture.other,fixture.name+" off-turn legal")
		var threats={}
		for square in 64:
			if g.board[square]==0:continue
			var targets=[]
			for target in 64:
				if g.piece_attacks(square,target):targets.append(Rules.name_of(target))
			targets.sort();threats[Rules.name_of(square)]=targets
		check(threats==fixture.threats,fixture.name+" threats/protection")
		for depth in fixture.divide:
			var counts={}
			for m in g.legal_moves():
				var next=g.copy_position();next.apply_unchecked(m)
				counts[Rules.uci_name(m)]=perft(next,int(depth)-1)
			var expected={}
			for move in fixture.divide[depth]: expected[move]=int(fixture.divide[depth][move])
			check(counts==expected,fixture.name+" depth "+depth+" divide actual="+str(counts)+" expected="+str(fixture.divide[depth]))
			print("PERFT ",fixture.name," depth ",depth," = ",counts.values().reduce(func(a,b):return a+b,0))
		count+=1
		if count%100==0:print("Reference positions compared: ",count)
	print("GODOT REFERENCE: %d positions, %d checks, %d failures" % [count,checks,failures])
	quit(1 if failures else 0)
