extends SceneTree
## Independent QA fuzz of the real Reducer/Store/SaveRepository (not the developer's tests).
## Run from a COPY of the project (so nothing is written into the repo):
##   cp QA/tools/godot/qa_fuzz.gd <copy>/tests/qa_fuzz.gd
##   godot --headless --path <copy> -s res://tests/qa_fuzz.gd -- --seeds=200 --steps=400
## Oracle (written from the spec, independent of GameState.check):
##   O1 xp == 100 * (#cases ever first-solved) and never decreases; xp<=300, steps of exactly 100
##   O2 completed[c] never reverts; reward_granted[c] => completed[c]
##   O3 run c02/c03 exists only if previous case completed (unlock invariant)
##   O4 evidence ids unique; C02: IDENTITY => charger CONNECTED & power RESTORED; BATTERY present with IDENTITY
##   O5 solved => all case success conditions (checked by recomputing from evidence/questions)
##   O6 after kill+restart the restored state deep-equals the last committed state
##   O7 a failed write never changes committed state; Retry commits the same state once
##   O8 attempts never decrease within a run; hint_level in 0..3 and monotone within a run
##   O9 duplicate action id never changes state

var fails: Array = []
var stats := {"actions": 0, "ok": 0, "noop": 0, "rejected": 0, "dup": 0, "write_failed": 0, "kills": 0, "solves": [0, 0, 0], "replays": 0}

func _initialize() -> void:
	Log.quiet = true
	Log.min_level = Log.Level.WARN
	var seeds := 100
	var steps := 300
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.substr(8))
		if a.begins_with("--steps="): steps = int(a.substr(8))
	for s in seeds:
		_run_seed(s, steps)
	print("QA_FUZZ stats ", JSON.stringify(stats))
	print("QA_FUZZ seeds=%d steps=%d failures=%d" % [seeds, steps, fails.size()])
	for f in fails.slice(0, 25):
		print("FAIL ", f)
	quit(1 if fails.size() > 0 else 0)

func _f(seed: int, step: int, msg: String) -> void:
	fails.append("seed=%d step=%d %s" % [seed, step, msg])

const OBJ := {
	"C01": ["C01_WINDOW", "C01_FLOOR", "C01_SHOES", "C01_CUP", "C01_CLOCK", "C01_MANAGER", "C01_BODY", "C01_BACKGROUND", "NOPE"],
	"C02": ["C02_PHONE", "C02_CHARGER", "C02_RECORD", "C02_WATCH", "C02_CLOCK", "C02_BACKGROUND", "NOPE"],
	"C03": ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM", "C03_BACKGROUND", "NOPE"],
}
const STAGES := {
	"C01": ["C01_Q1", "C01_Q2", "BAD"], "C02": ["C02_CONNECT", "C02_Q1", "BAD"],
	"C03": ["C03_TIMELINE", "C03_LINK", "C03_Q1", "BAD"],
}
const EVS := {
	"C01": ["EV_C01_RAIN", "EV_C01_DRY_FLOOR", "EV_C01_ADMISSION"],
	"C02": ["EV_C02_BATTERY", "EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"],
	"C03": ["EV_C03_TICKET", "EV_C03_CLOCK_SYNC", "EV_C03_DEPARTURE", "EV_C03_PHOTO", "EV_C03_PLATFORM"],
}
const TOKENS := ["TL_DEPART", "TL_CLAIM", "TL_PHOTO", "TL_X"]
const CORRECT := {  # good moves, drawn with higher probability so the fuzz reaches deep states
	"C01_Q1": "C01_Q1_A0", "C01_Q2": "C01_Q2_A1", "C02_Q1": "C02_Q1_A2", "C03_Q1": "C03_Q1_A0",
}

func _run_seed(seed: int, steps: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fx := Fx.new()
	var ever_solved := {"C01": false, "C02": false, "C03": false}
	var prev_xp := 0
	var prev_attempts := {}
	var prev_hint := {}
	var prev_run_id := {}
	var cursor := {}
	for step in steps:
		var cid: String = ["C01", "C02", "C03"][rng.randi_range(0, 2)]
		if rng.randf() < 0.55:  # bias to the earliest unsolved case
			for c in ["C01", "C02", "C03"]:
				if not fx.state()["campaign"]["completed"][c]:
					cid = c
					break
		var before: Dictionary = fx.state().duplicate(true)
		var roll := rng.randf()
		var res: Dictionary = {}
		if rng.randf() < 0.55:
			var cs: String = cid
			res = _canon(fx, cs, int(cursor.get(cs, 0)))
			cursor[cs] = int(cursor.get(cs, 0)) + 1
			stats["actions"] += 1
			_check(fx, seed, step, ever_solved, prev_xp, prev_attempts, prev_hint, prev_run_id)
			prev_xp = int(fx.state()["campaign"]["xp"])
			for c in fx.state()["runs"]:
				prev_attempts[c] = int(fx.state()["runs"][c]["attempts"])
				prev_hint[c] = int(fx.state()["runs"][c]["hint_level"])
				prev_run_id[c] = fx.state()["runs"][c]["run_id"]
			continue
		var committed_before_ids: int = fx.store.state.get("committed_action_ids", []).size()
		if roll < 0.04:
			# process kill: everything in memory dropped
			fx = fx.kill_and_restart()
			stats["kills"] += 1
			if not TestCase.deep_eq(fx.state()["campaign"], before["campaign"]) or not TestCase.deep_eq(fx.state()["runs"], before["runs"]):
				_f(seed, step, "O6 restored state differs from last committed state after kill")
			continue
		elif roll < 0.10:
			fx.route = "%s_INTRO" % cid
			res = fx.act(CZ.START_CASE, {"case_id": cid, "entry_source": "board"})
		elif roll < 0.38:
			var objs: Array = OBJ[cid]
			res = fx.inspect(cid, objs[rng.randi_range(0, objs.size() - 1)])
		elif roll < 0.46:
			var o: String = "C02_CHARGER" if cid == "C02" else OBJ[cid][0]
			res = fx.connect_charger(cid, o) if cid == "C02" else fx.act(CZ.CONNECT_CHARGER, {"case_id": cid, "object_id": o})
		elif roll < 0.56:
			var st: String = STAGES[cid][rng.randi_range(0, STAGES[cid].size() - 1)]
			var ans: Variant = CORRECT.get(st, "%s_A%d" % [st, rng.randi_range(0, 3)]) if rng.randf() < 0.5 else "%s_A%d" % [st, rng.randi_range(0, 3)]
			fx.route = "%s_X" % cid if rng.randf() < 0.1 else (fx.db.case_def(cid).stage(st)["screen"] if fx.db.case_def(cid).stage(st) != null else "%s_SCENE" % cid)
			res = fx.act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": st, "answer_id": ans})
		elif roll < 0.66:
			var st2: String = STAGES[cid][rng.randi_range(0, STAGES[cid].size() - 1)]
			var evs: Array = EVS[cid].duplicate()
			evs.shuffle()
			var n := rng.randi_range(0, 5)
			if cid == "C02" and rng.randf() < 0.4: evs = ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]
			if cid == "C03" and rng.randf() < 0.4: evs = ["EV_C03_PHOTO", "EV_C03_CLOCK_SYNC", "EV_C03_PLATFORM"]
			if cid == "C02" and rng.randf() < 0.1: evs = ["EV_C02_IDENTITY", "EV_C02_IDENTITY", "EV_C02_NETWORK"]  # duplicate selection
			var sd = fx.db.case_def(cid).stage(st2)
			fx.route = sd["screen"] if sd != null else "%s_SCENE" % cid
			res = fx.act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": st2, "evidence_ids": evs.slice(0, n) if rng.randf() < 0.7 else evs.slice(0, 3)})
		elif roll < 0.78:
			var t: String = TOKENS[rng.randi_range(0, TOKENS.size() - 1)]
			if rng.randf() < 0.5:
				var order := ["TL_DEPART", "TL_CLAIM", "TL_PHOTO"]
				var i := rng.randi_range(0, 2)
				res = _place(fx, cid, order[i], i)
			else:
				res = _place(fx, cid, t, rng.randi_range(-1, 3))
		elif roll < 0.82:
			res = _submit_tl(fx, cid)
		elif roll < 0.88:
			res = fx.hint(cid, ["open", "next", "bogus"][rng.randi_range(0, 2)])
		elif roll < 0.92:
			if fx.state()["campaign"]["completed"][cid]: stats["replays"] += 1
			res = fx.reset(cid)
		elif roll < 0.95:
			res = fx.act(CZ.SET_SETTING, {"key": ["sound", "haptic", "reduced_motion", "x"][rng.randi_range(0, 3)], "value": rng.randf() < 0.5})
		elif roll < 0.98:
			# duplicate action id must never change state (O9)
			var a := fx.store.make_action(CZ.INSPECT_OBJECT, {"case_id": cid, "object_id": OBJ[cid][0]})
			fx.scene(cid)
			fx.store.dispatch(a)
			var snap: Dictionary = fx.state().duplicate(true)
			var r2 := fx.store.dispatch(a)
			if not TestCase.deep_eq(fx.state(), snap) or r2["status"] != CZ.DUPLICATE and r2["status"] != CZ.OK:
				_f(seed, step, "O9 duplicate action id changed state/status=%s" % r2["status"])
			continue
		else:
			# write failure: state must not change; retry must commit exactly the proposed state once
			fx.backend.fail_writes = 1
			var o2: String = OBJ[cid][rng.randi_range(0, 3)]
			var pre: Dictionary = fx.state().duplicate(true)
			res = fx.inspect(cid, o2)
			if res["status"] == CZ.WRITE_FAILED:
				stats["write_failed"] += 1
				if not TestCase.deep_eq(fx.state(), pre):
					_f(seed, step, "O7 committed state changed by failed write")
				if rng.randf() < 0.5:
					var rr := fx.store.retry_pending()
					if rr["status"] != CZ.OK: _f(seed, step, "O7 retry failed with status %s" % rr["status"])
				else:
					fx.store.revert_pending()
					if not TestCase.deep_eq(fx.state(), pre): _f(seed, step, "O7 revert changed state")
			fx.backend.fail_writes = 0
		stats["actions"] += 1
		match res.get("status", ""):
			CZ.OK: stats["ok"] += 1
			CZ.NOOP: stats["noop"] += 1
			CZ.REJECTED: stats["rejected"] += 1
			CZ.DUPLICATE: stats["dup"] += 1
		_check(fx, seed, step, ever_solved, prev_xp, prev_attempts, prev_hint, prev_run_id)
		prev_xp = int(fx.state()["campaign"]["xp"])
		for c in fx.state()["runs"]:
			prev_attempts[c] = int(fx.state()["runs"][c]["attempts"])
			prev_hint[c] = int(fx.state()["runs"][c]["hint_level"])
			prev_run_id[c] = fx.state()["runs"][c]["run_id"]
	# Replay phase: solve everything once, then reset+re-solve each case twice, with random kills in between.
	for c in ["C01", "C02", "C03"]:
		for i in 14:
			_canon(fx, c, i)
	var xp_full := int(fx.state()["campaign"]["xp"])
	if xp_full != 300: _f(seed, steps, "O1 after full campaign xp=%d (expected 300)" % xp_full)
	for round in 2:
		for c in ["C01", "C02", "C03"]:
			fx.reset(c)
			for i in 14:
				_canon(fx, c, i)
				if rng.randf() < 0.08:
					fx = fx.kill_and_restart()
			if not fx.state()["runs"][c]["solved"]: _f(seed, steps, "replay of %s did not reach solved" % c)
			if int(fx.state()["campaign"]["xp"]) != 300: _f(seed, steps, "O1 replay %s changed xp to %d" % [c, fx.state()["campaign"]["xp"]])
			if not fx.state()["campaign"]["completed"][c]: _f(seed, steps, "O2 replay lost completion %s" % c)
			stats["replays"] += 1
	for i in 3:
		if fx.state()["campaign"]["completed"]["C0%d" % (i + 1)]:
			stats["solves"][i] += 1

func _check(fx: Fx, seed: int, step: int, ever: Dictionary, prev_xp: int, prev_att: Dictionary, prev_hint: Dictionary, prev_run: Dictionary) -> void:
	var s: Dictionary = fx.state()
	var camp: Dictionary = s["campaign"]
	var granted := 0
	for c in ["C01", "C02", "C03"]:
		if camp["reward_granted"][c]:
			granted += 1
			if not camp["completed"][c]: _f(seed, step, "O2 reward_granted without completed %s" % c)
		if ever[c] and not camp["completed"][c]: _f(seed, step, "O2 completed reverted for %s" % c)
		if camp["completed"][c]: ever[c] = true
	if int(camp["xp"]) != 100 * granted: _f(seed, step, "O1 xp=%d granted=%d" % [camp["xp"], granted])
	if int(camp["xp"]) < prev_xp: _f(seed, step, "O1 xp decreased %d->%d" % [prev_xp, camp["xp"]])
	if int(camp["xp"]) - prev_xp not in [0, 100]: _f(seed, step, "O1 xp jumped by %d" % (int(camp["xp"]) - prev_xp))
	if s["runs"].has("C02") and not s["runs"]["C02"].is_empty() and not camp["completed"]["C01"]:
		_f(seed, step, "O3 C02 run exists but C01 not completed")
	if s["runs"].has("C03") and not s["runs"]["C03"].is_empty() and not camp["completed"]["C02"]:
		_f(seed, step, "O3 C03 run exists but C02 not completed")
	for c in s["runs"]:
		var run: Dictionary = s["runs"][c]
		if run.is_empty(): continue
		var seen := {}
		for e in run["evidence"]:
			if seen.has(e): _f(seed, step, "O4 duplicate evidence %s in %s" % [e, c])
			seen[e] = true
		if c == "C02":
			if seen.has("EV_C02_IDENTITY") and (run.get("charger") != "CONNECTED" or run.get("phone_power") != "RESTORED"):
				_f(seed, step, "O4 IDENTITY without CONNECTED/RESTORED")
			if seen.has("EV_C02_IDENTITY") and not seen.has("EV_C02_BATTERY"):
				_f(seed, step, "O4 IDENTITY without BATTERY")
			if (run.get("charger") == "CONNECTED") != (run.get("phone_power") == "RESTORED"):
				_f(seed, step, "O4 charger/phone_power inconsistent")
		if run["solved"]:
			var q: Dictionary = run["questions"]
			var need: Array = {"C01": ["EV_C01_RAIN", "EV_C01_DRY_FLOOR", "EV_C01_ADMISSION"], "C02": ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"], "C03": EVS["C03"]}[c]
			for e in need:
				if not seen.has(e): _f(seed, step, "O5 %s solved without %s" % [c, e])
			for qq in q:
				if not q[qq]: _f(seed, step, "O5 %s solved with %s=false" % [c, qq])
			if c == "C02" and not run["link_ok"]: _f(seed, step, "O5 C02 solved without link_ok")
			if c == "C03" and not (run["link_ok"] and run["timeline_ok"]): _f(seed, step, "O5 C03 solved without link/timeline")
			if not camp["completed"][c]: _f(seed, step, "O5 solved but campaign.completed false %s" % c)
		if int(run["hint_level"]) < 0 or int(run["hint_level"]) > 3: _f(seed, step, "O8 hint_level out of range")
		if prev_run.get(c) == run["run_id"]:
			if int(run["attempts"]) < int(prev_att.get(c, 0)): _f(seed, step, "O8 attempts decreased in %s" % c)
			if int(run["hint_level"]) < int(prev_hint.get(c, 0)): _f(seed, step, "O8 hint_level decreased in %s" % c)
		if c == "C03":
			var tl: Array = run["timeline"]
			var vals := tl.filter(func(x): return x != null)
			if vals.size() != len(Dictionary(vals.reduce(func(a, x): a[x] = 1; return a, {}))): _f(seed, step, "O4 duplicate token in timeline")
			if tl.size() != 3: _f(seed, step, "O4 timeline size %d" % tl.size())


func _place(fx: Fx, cid: String, token: String, slot: int) -> Dictionary:
	fx.route = "%s_TIMELINE" % cid
	return fx.act(CZ.PLACE_TIMELINE_TOKEN, {"case_id": cid, "stage_id": "%s_TIMELINE" % cid, "token_id": token, "slot": slot})

func _submit_tl(fx: Fx, cid: String) -> Dictionary:
	fx.route = "%s_TIMELINE" % cid
	return fx.act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": "%s_TIMELINE" % cid})

## Canonical happy-path steps (spec Part 5-7), executed in order with wrap-around so the fuzz also covers replay.
func _canon(fx: Fx, cid: String, i: int) -> Dictionary:
	var steps: Array
	match cid:
		"C01":
			steps = [func(): return fx.start("C01"), func(): return fx.inspect("C01", "C01_WINDOW"), func(): return fx.inspect("C01", "C01_FLOOR"),
				func(): return fx.answer("C01", "C01_Q1", "C01_Q1_A0"), func(): return fx.inspect("C01", "C01_MANAGER"), func(): return fx.answer("C01", "C01_Q2", "C01_Q2_A1")]
		"C02":
			steps = [func(): return fx.start("C02"), func(): return fx.inspect("C02", "C02_PHONE"), func(): return fx.inspect("C02", "C02_CHARGER"),
				func(): return fx.connect_charger("C02", "C02_CHARGER"), func(): return fx.inspect("C02", "C02_PHONE"), func(): return fx.inspect("C02", "C02_RECORD"),
				func(): return fx.inspect("C02", "C02_WATCH"), func(): return fx.select_set("C02", "C02_CONNECT", ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]),
				func(): return fx.answer("C02", "C02_Q1", "C02_Q1_A2")]
		_:
			steps = [func(): return fx.start("C03"), func(): return fx.inspect("C03", "C03_TICKET"), func(): return fx.inspect("C03", "C03_CLOCK"),
				func(): return fx.inspect("C03", "C03_TIMETABLE"), func(): return fx.inspect("C03", "C03_PHOTO"), func(): return fx.inspect("C03", "C03_PLATFORM"),
				func(): return fx.place("C03", "C03_TIMELINE", "TL_DEPART", 0), func(): return fx.place("C03", "C03_TIMELINE", "TL_CLAIM", 1),
				func(): return fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 2), func(): return fx.submit_timeline("C03", "C03_TIMELINE"),
				func(): return fx.select_set("C03", "C03_LINK", ["EV_C03_PHOTO", "EV_C03_CLOCK_SYNC", "EV_C03_PLATFORM"]), func(): return fx.answer("C03", "C03_Q1", "C03_Q1_A0")]
	return steps[i % steps.size()].call()
