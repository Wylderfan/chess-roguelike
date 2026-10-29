class_name ChessEngine
extends RefCounted
# UCI bridge only: all search is compiled Sebastian Lague C# core.
# A fresh process owns each request; no result or timer crosses requests.
const Rules = preload("res://rules.gd")
const MATE = 100000
var mutex = Mutex.new()
var canceled = false
var pipe: FileAccess
var errors: FileAccess
var process_id = -1
var buffer = ""
var lines: Array = []
var fault = ""
var stderr_text = ""
var rules_profile = "standard"

func cancel() -> void:
	mutex.lock()
	canceled = true
	mutex.unlock()

func is_canceled() -> bool:
	mutex.lock()
	var value = canceled
	mutex.unlock()
	return value

static func executable_path() -> String:
	var platform = OS.get_name()
	var arch = Engine.get_architecture_name()
	var rid = ""
	if platform == "Windows": rid = "win-arm64" if arch == "arm64" else "win-x64"
	elif platform == "Linux": rid = "linux-x64" if arch == "x86_64" else "linux-arm64"
	elif platform == "macOS": rid = "osx-arm64" if arch == "arm64" else "osx-x64"
	return ProjectSettings.globalize_path("res://native/bin/" + rid + "/KnightEngine" + (".exe" if platform == "Windows" else ""))

func send(text: String) -> void:
	pipe.store_buffer((text + "\n").to_utf8_buffer())
	if pipe.get_error() != OK: fault = "Engine input pipe failed."

func next_line(until: int) -> String:
	while Time.get_ticks_msec() < until and not is_canceled() and fault == "":
		if not lines.is_empty(): return lines.pop_front()
		var chunk = pipe.get_buffer(4096)
		if not chunk.is_empty():
			buffer += chunk.get_string_from_utf8()
			while buffer.contains("\n"):
				var end = buffer.find("\n")
				lines.append(buffer.substr(0, end).strip_edges())
				buffer = buffer.substr(end + 1)
			continue
		var err = errors.get_buffer(4096)
		if not err.is_empty(): stderr_text = (stderr_text + err.get_string_from_utf8()).left(2000)
		if not OS.is_process_running(process_id):
			fault = "Engine exited unexpectedly. " + stderr_text.left(300)
			break
		OS.delay_msec(2)
	return ""

func close_process() -> void:
	if process_id <= 0: return
	if OS.is_process_running(process_id):
		send("stop")
		send("quit")
		var deadline = Time.get_ticks_msec() + 150
		while OS.is_process_running(process_id) and Time.get_ticks_msec() < deadline: OS.delay_msec(2)
		if OS.is_process_running(process_id): OS.kill(process_id)
	pipe.close()
	errors.close()
	process_id = -1

func verify_snapshot(g: ChessRules, data: Dictionary) -> String:
	if data.get("profile", "") != rules_profile: return "Engine rules profile mismatch."
	if data.get("schema", -1) != 0 or not data.get("abilities_empty", false) or not g.ability_state.is_empty(): return "Unsupported ability schema; normal chess only."
	var ours: Array = []
	for m in g.legal_moves(): ours.append(Rules.uci_name(m))
	ours.sort()
	if ours != data.get("legal", []): return "Rules disagree on legal moves; engine play stopped."
	var theirs: Array = []
	for s in 64:
		if g.board[s] == 0: continue
		var preview = g.inspect_piece(s)
		if preview.hypothetical:
			for m in preview.moves: theirs.append(Rules.uci_name(m))
		var attacks: Array = []
		for target in preview.attacks: attacks.append(Rules.name_of(target))
		attacks.sort()
		if attacks != data.get("threats", {}).get(Rules.name_of(s), []): return "Rules disagree on threat masks; engine play stopped."
	theirs.sort()
	if theirs != data.get("other_legal", []): return "Rules disagree on opposing-piece preview; engine play stopped."
	return ""

func search(position: ChessRules, milliseconds: int, _max_depth: int = 64) -> Dictionary:
	var start = Time.get_ticks_msec()
	var output = {"move": {}, "depth": 0, "nodes": 0, "score": 0, "elapsed_ms": 0, "claim": false, "error": "", "canceled": false}
	if is_canceled():
		output.canceled = true
		return output
	if rules_profile not in ["standard", "conservative"]:
		output.error = "Unsupported rules profile."
		return output
	if position.result != "" or position.legal_moves().is_empty(): return output
	if not position.ability_state.is_empty():
		output.error = "Abilities are not enabled in v0.3."
		return output
	var path = executable_path()
	if not FileAccess.file_exists(path):
		output.error = "Engine binary is missing for this platform. See native/INTEGRATION.md."
		return output
	var process = OS.execute_with_pipe(path, [], false)
	if process.is_empty():
		output.error = "Cannot start the engine. Check executable permissions and native/INTEGRATION.md."
		return output
	pipe = process.stdio
	errors = process.stderr
	process_id = process.pid
	send("uci")
	var ready = false
	var deadline = start + 5000
	while not ready and fault == "" and not is_canceled() and Time.get_ticks_msec() < deadline:
		ready = next_line(deadline) == "uciok"
	if not ready and not is_canceled(): fault = "Engine startup failed. " + fault
	if fault == "" and not is_canceled():
		send("setoption name RulesProfile value " + rules_profile)
		send("ucinewgame")
		send(position.uci_position())
		send("knight snapshot")
		var verified = false
		while not verified and fault == "" and not is_canceled() and Time.get_ticks_msec() < deadline:
			var line = next_line(deadline)
			if line.begins_with("info string error"): fault = line
			if line.begins_with("knight "):
				var data = JSON.parse_string(line.substr(7))
				if data is Dictionary:
					fault = verify_snapshot(position, data)
					verified = fault == ""
				else: fault = "Malformed engine snapshot."
		if not verified and fault == "" and not is_canceled(): fault = "Engine rules handshake timed out."
	if fault == "" and not is_canceled():
		send("go movetime " + str(milliseconds))
		deadline = Time.get_ticks_msec() + milliseconds + 5000
		var finished = false
		while not finished and fault == "" and not is_canceled() and Time.get_ticks_msec() < deadline:
			var line = next_line(deadline)
			if line.begins_with("info string error"): fault = line
			elif line.begins_with("info "):
				var parts = line.split(" ")
				for field in ["depth", "nodes"]:
					var i = parts.find(field)
					if i >= 0 and i + 1 < parts.size(): output[field] = int(parts[i + 1])
				var cp = parts.find("cp")
				if cp >= 0 and cp + 1 < parts.size(): output.score = int(parts[cp + 1])
			elif line.begins_with("bestmove "):
				finished = true
				var uci = line.split(" ")[1]
				for m in position.legal_moves():
					if Rules.uci_name(m) == uci: output.move = m
				if output.move.is_empty(): fault = "Engine returned no valid move in a playable position."
		if not finished and fault == "" and not is_canceled(): fault = "Engine search timed out."
	output.canceled = is_canceled()
	output.error = fault if not output.canceled else ""
	output.claim = position.claim_reason() != "" and output.score <= 0 and not output.move.is_empty()
	close_process()
	output.elapsed_ms = Time.get_ticks_msec() - start
	return output
