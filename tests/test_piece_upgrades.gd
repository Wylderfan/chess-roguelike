extends SceneTree
const Rules = preload("res://rules.gd")
const Setup = preload("res://setup.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
	else: print("PASS: " + label)
func position(fen: String):
	var g = Rules.new()
	g.load_fen(fen)
	return g
func names(g) -> Array:
	var moves: Array = []
	for m in g.legal_moves(): moves.append(Rules.uci_name(m))
	return moves
func play(g, uci: String) -> bool:
	for m in g.legal_moves():
		if Rules.uci_name(m) == uci: return g.play(m)
	return false
func equip(g, square: String) -> bool:
	return g.set_piece_ability(Rules.square(square), Rules.PAWN_RETREAT, true)
func data(g, square: String) -> Dictionary:
	return g.get_piece_data(Rules.square(square))
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var g = Rules.new()
	check(g.piece_data.size() == 32 and g.piece_data_error() == "", "Every original piece has unique metadata")
	check(Rules.ability_capacity("common") == 1 and Rules.ability_capacity("rare") == 2 and Rules.ability_capacity("legendary") == 2, "Default one slot; rare and legendary have two")
	check(data(g,"e2").rarity == "common" and data(g,"e2").abilities.is_empty(), "New pieces are common and unupgraded")
	check(not g.set_piece_rarity(52,"mythic") and not g.set_piece_ability(60,Rules.PAWN_RETREAT,true) and not g.set_piece_ability(52,"pawn_dash",true), "Unknown rarity, ineligible piece and unavailable ability rejected")
	check(not g.set_piece_ability(36,Rules.PAWN_RETREAT,true) and not g.set_piece_rarity(36,"rare"), "Empty square cannot receive upgrades")
	check(equip(g,"e2") and equip(g,"e2") and data(g,"e2").abilities == [Rules.PAWN_RETREAT], "Equipping existing ability is idempotent, never duplicate")
	check(g.ability_state == {"pawn_retreat":["e2"]} and g.initial_retreat_squares == ["e2"] and g.supported_abilities(), "Current and initial marker state are canonical")
	check(g.set_piece_rarity(52,"legendary") and data(g,"e2").abilities == [Rules.PAWN_RETREAT], "Rarity change keeps equipped ability without inventing a second one")
	check(g.set_piece_rarity(52,"common") and g.set_piece_ability(52,Rules.PAWN_RETREAT,false) and g.ability_state.is_empty(), "Downgrade and ability removal keep legal empty state")
	g = position("7k/8/3pp3/8/3PP3/8/8/K7 w - - 0 1")
	equip(g,"e4"); equip(g,"d6")
	check("e4e3" in names(g) and not "d4d3" in names(g), "Same-side ordinary pawn cannot borrow equipped pawn's retreat")
	check(g.retreat_squares() == ["d6","e4"] and g.retreat_setting() == "both", "Markers sorted by square; legacy summary reports affected sides")
	var black = g.copy_position(); black.turn = -1
	check("d6d7" in names(black) and not "e6e7" in names(black), "Black's mixed pawn upgrades are independent too")
	var e4 = data(g,"e4"); var initial = g.initial_piece_data.duplicate(true)
	check(play(g,"e4e3") and data(g,"e3") == e4 and not g.piece_data.has(Rules.square("e4")), "Retreat carries complete identity, rarity and abilities")
	check(g.initial_retreat_squares == ["d6","e4"] and g.initial_piece_data == initial and g.retreat_squares() == ["d6","e3"], "Move updates current markers without changing replay origin")
	check(not g.set_piece_ability(Rules.square("e3"),Rules.PAWN_RETREAT,false) and not g.set_piece_rarity(Rules.square("e3"),"rare") and not g.configure_piece_data(g.piece_data), "Composition APIs cannot alter a game after its first move")
	var snapshot = g.copy_position(true)
	check(snapshot.piece_data == g.piece_data and snapshot.initial_piece_data == initial and snapshot.history == g.history, "History copy keeps current and initial metadata and repetition")
	snapshot.piece_data[Rules.square("e3")].abilities.clear(); snapshot.initial_piece_data[Rules.square("e4")].abilities.clear()
	check(data(g,"e3").abilities == [Rules.PAWN_RETREAT] and g.initial_piece_data[Rules.square("e4")].abilities == [Rules.PAWN_RETREAT], "Copied current and initial nested ability arrays are isolated")
	var public_data = data(g,"e3"); public_data.abilities.clear()
	check(g.pawn_can_retreat(Rules.square("e3")), "Inspection getter cannot mutate the position")

	var setup = Setup.new()
	setup.set_piece_ability(52,Rules.PAWN_RETREAT,true); setup.set_piece_rarity(52,"rare")
	var moving = data(setup.position,"e2")
	setup.relocate(52,36)
	check(data(setup.position,"e4") == moving and not setup.position.piece_data.has(52), "Editor relocation preserves upgraded piece")
	setup.set_piece_ability(51,Rules.PAWN_RETREAT,true)
	var overwritten_id = data(setup.position,"d2").id
	setup.relocate(36,51)
	check(data(setup.position,"d2") == moving and data(setup.position,"d2").id != overwritten_id and setup.position.retreat_squares() == ["d2"], "Overwrite removes destination identity and transfers source upgrade")
	setup.edit(52,Rules.PAWN)
	check(data(setup.position,"e2").id != moving.id and not setup.position.pawn_can_retreat(52), "New palette pawn has new identity and no inherited side upgrade")
	var new_id = data(setup.position,"e2").id
	setup.edit(52,Rules.PAWN)
	check(data(setup.position,"e2").id != new_id, "Replacing identical type still creates a new piece")
	var untouched = setup.position.piece_data.duplicate(true)
	setup.relocate(36,52)
	check(setup.position.piece_data == untouched, "Moving an empty source does not erase the destination")
	setup.edit(51,0)
	check(not setup.position.piece_data.has(51) and setup.position.retreat_squares().is_empty(), "Erase removes identity and equipped ability")
	setup.set_retreat("white",true); setup.edit(36,Rules.PAWN)
	check(not setup.position.pawn_can_retreat(36) and setup.position.pawn_can_retreat(52), "Legacy convenience applies only to currently placed pawn instances")
	setup.set_piece_rarity(52,"legendary")
	g = setup.create_game()
	check(g != null and g.piece_data == setup.position.piece_data and g.initial_retreat_squares == setup.position.retreat_squares() and g.initial_piece_data == g.piece_data, "Start transfers exact composed metadata and replay start")
	check(g.move_log.is_empty() and g.history == {g.position_key():1}, "Composed start has fresh correct repetition history")
	setup.set_piece_ability(52,Rules.PAWN_RETREAT,false)
	check(g.pawn_can_retreat(52), "Live game does not share mutable metadata with editor draft")
	var restored = Setup.new(); restored.position.load_fen(g.initial_fen)
	check(restored.position.configure_piece_data(g.initial_piece_data) and restored.position.piece_data == g.initial_piece_data, "Original prepared army can be reopened without side-wide reconstruction")

	var old_ids: Array = []
	for metadata in setup.position.piece_data.values(): old_ids.append(metadata.id)
	setup.reset_standard()
	check(setup.position.ability_state.is_empty() and setup.position.piece_data.values().all(func(d): return d.rarity == "common" and not d.id in old_ids), "Reset replaces army with new common identities and clears upgrades")
	setup.set_piece_ability(52,Rules.PAWN_RETREAT,true); setup.set_piece_rarity(52,"legendary")
	setup.odds(Rules.QUEEN,1)
	check(setup.position.ability_state.is_empty() and data(setup.position,"e2").rarity == "common", "Material preset creates a clean replacement army without stale upgrades")

	g = position("7k/8/8/3p4/4P3/8/8/K7 w - - 0 1")
	equip(g,"e4"); equip(g,"d5"); g.set_piece_rarity(Rules.square("e4"),"rare")
	moving = data(g,"e4"); overwritten_id = data(g,"d5").id
	check(play(g,"e4d5") and data(g,"d5") == moving and g.retreat_squares() == ["d5"], "Pawn capture carries attacker's upgrade and removes captured upgrade")
	check(not g.piece_data.values().any(func(d): return d.id == overwritten_id), "Captured piece identity is absent")
	g = position("7k/8/8/8/r3P3/8/8/1K6 b - - 0 1"); equip(g,"e4")
	var rook_id = data(g,"a4").id
	check(play(g,"a4e4") and data(g,"e4").id == rook_id and g.ability_state.is_empty() and g.initial_retreat_squares == ["e4"], "Ordinary capture removes last effective marker but retains replay configuration")
	g = position("7k/8/8/3pP3/8/8/8/K7 w - d6 0 1"); equip(g,"e5"); equip(g,"d5")
	moving = data(g,"e5")
	check(play(g,"e5d6") and data(g,"d6") == moving and not g.piece_data.has(Rules.square("d5")) and g.retreat_squares() == ["d6"], "En passant removes captured metadata behind destination and carries capturer")
	g = position("7k/4P3/8/4p3/8/8/8/K7 w - e6 0 1"); equip(g,"e7"); equip(g,"e5")
	var survivor = data(g,"e5")
	check(play(g,"e7e6") and data(g,"e5") == survivor and g.retreat_squares() == ["e5","e6"], "Retreat onto EP target does not erase behind-target pawn metadata")
	for fixture in [["7k/P7/8/8/8/8/8/K7 w - - 0 1","a7","a8"],["7k/8/8/8/8/8/p7/7K b - - 0 1","a2","a1"]]:
		for promotion in ["q","r","b","n"]:
			g = position(fixture[0]); equip(g,fixture[1]); g.set_piece_rarity(Rules.square(fixture[1]),"legendary")
			moving = data(g,fixture[1])
			check(play(g,fixture[1]+fixture[2]+promotion) and data(g,fixture[2]).id == moving.id and data(g,fixture[2]).rarity == "legendary" and data(g,fixture[2]).abilities.is_empty() and g.ability_state.is_empty() and g.initial_retreat_squares == [fixture[1]], "Promotion retains identity/rarity and drops pawn-only ability: " + fixture[1]+fixture[2]+promotion)
	for fixture in [["w","e1g1","h1","f1"],["w","e1c1","a1","d1"],["b","e8g8","h8","f8"],["b","e8c8","a8","d8"]]:
		g = position("r3k2r/8/8/8/8/8/8/R3K2R " + fixture[0] + " KQkq - 0 1")
		g.set_piece_rarity(Rules.square(fixture[2]),"rare")
		moving = data(g,fixture[2]); var king = data(g,fixture[1].substr(0,2))
		check(play(g,fixture[1]) and data(g,fixture[3]) == moving and data(g,fixture[1].substr(2,2)) == king and not g.piece_data.has(Rules.square(fixture[2])), "Castling carries both king and rook identities: " + fixture[1])

	g = position("7k/8/8/4p3/4P3/8/8/K7 w - - 0 1"); g.configure_retreat("both")
	var first_key = g.position_key()
	for cycle in 2:
		for uci in ["e4e3","e5e6","e3e4","e6e5"]: check(play(g,uci), "Repeatable equipped-pawn move: " + uci)
	check(g.position_key() == first_key and g.claim_reason() == "threefold repetition", "Rule-effective marker cycles count toward threefold repetition")
	g = position("7k/8/8/8/3PP3/8/8/K7 w - - 0 1"); equip(g,"e4")
	var key = g.position_key(); var altered = g.copy_position()
	altered.piece_data[Rules.square("e4")].id = "renamed_visual_id"; altered.piece_data[Rules.square("e4")].rarity = "rare"
	check(altered.position_key() == key and altered.legal_moves() == g.legal_moves(), "Visual-only identity/rarity never split equivalent positions")
	altered.set_piece_ability(Rules.square("e4"),Rules.PAWN_RETREAT,false); equip(altered,"d4")
	check(altered.position_key() != key and altered.legal_moves() != g.legal_moves(), "Same board with different equipped pawn has different legality and key")
	g.configure_retreat("none")
	check(g.position_key() == position(g.initial_fen).position_key(), "Unequipped metadata preserves orthodox position key")

	g = Rules.new(); var good = g.piece_data.duplicate(true)
	var bad = good.duplicate(true); bad[52].abilities = ["pawn_retreat","pawn_retreat"]
	check(not g.configure_piece_data(bad) and g.piece_data == good, "Over-capacity state rejected atomically")
	bad[52].rarity = "rare"
	check(not g.configure_piece_data(bad), "Duplicate ability rejected even with second slot")
	bad = good.duplicate(true); bad[60].abilities = ["pawn_retreat"]
	check(not g.configure_piece_data(bad), "Imported pawn ability on king rejected")
	bad = good.duplicate(true); bad[52].abilities = ["unimplemented"]
	check(not g.configure_piece_data(bad), "Unimplemented imported ability rejected")
	bad = good.duplicate(true); bad[52].id = bad[51].id
	check(not g.configure_piece_data(bad), "Duplicate piece identity rejected")
	bad = good.duplicate(true); bad[36] = {"id":"ghost","rarity":"common","abilities":[]}
	check(not g.configure_piece_data(bad), "Upgrade on empty square rejected")
	bad = good.duplicate(true); bad.erase(52)
	check(not g.configure_piece_data(bad), "Missing occupied-square metadata rejected")
	g.ability_state = {"pawn_retreat":["e2"]}
	check(not g.supported_abilities(), "Effective-state mismatch fails closed")
	g.ability_state = {"white_used":1}
	check(not g.supported_abilities(), "Unknown ability-state schema fails closed")
	g = Rules.new(); equip(g,"e2"); g.initial_retreat_squares = ["d2"]
	check(not g.supported_abilities(), "Corrupt initial replay markers fail closed")
	setup = Setup.new(); setup.position.piece_data[52].abilities = ["pawn_retreat","pawn_retreat"]
	check(setup.validation_error().contains("more abilities"), "Editor validates capacity before starting")
	setup.position.piece_data[52].rarity = "rare"
	check(setup.validation_error().contains("same ability twice"), "Editor validates duplicate ability separately from capacity")
	g = Rules.new(); equip(g,"e2"); g.load_fen(g.initial_fen)
	check(g.ability_state.is_empty() and g.initial_retreat_squares.is_empty() and g.piece_data_error() == "", "FEN import starts clean, with no stale upgrades")
	print("PIECE UPGRADES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
