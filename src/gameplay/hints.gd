class_name Hints
extends RefCounted
## Hint escalation (spec Part 4 Hint panel): first open sets level 1, the CTA raises it up to 3,
## at 3 the CTA repeats. Level never rises with time. Hints are free and never touch XP.

const MODE_OPEN := "open"
const MODE_NEXT := "next"

static func request(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var g := Reducer.guard_run(state, db, cid)
	if g != "":
		return Reducer.result(CZ.REJECTED, g, state)
	var def := db.case_def(cid)
	var mode := str(action.get("mode", MODE_OPEN))
	var expected_route := def.screen("SCENE") if mode == MODE_OPEN else def.screen("HINT")
	if ctx.get("route") != expected_route:
		return Reducer.result(CZ.REJECTED, CZ.ROUTE_INVALID, state)
	var run: Dictionary = state["runs"][cid]
	var before := int(run["hint_level"])
	var after := before
	var is_repeat := false
	if mode == MODE_OPEN:
		if before == 0:
			after = 1
	elif mode == MODE_NEXT:
		if before < CZ.HINT_MAX_LEVEL:
			after = before + 1
		else:
			is_repeat = true
	else:
		return Reducer.result(CZ.REJECTED, CZ.INVALID_PAYLOAD, state)
	var target := Selectors.hint_target(def, run, state["campaign"])
	var res: Dictionary
	if after != before:
		var next := GameState.clone(state)
		next["runs"][cid]["hint_level"] = after
		Reducer.bump_interaction(next)
		res = Reducer.result(CZ.OK, CZ.OK, next, true)
	elif is_repeat:
		res = Reducer.result(CZ.OK, CZ.OK, state, false)
	else:
		res = Reducer.result(CZ.NOOP, CZ.ALREADY_DONE, state)
	if after != before or is_repeat:
		Reducer.event(res, "HINT_REQUESTED", {"case_id": cid, "run_id": run["run_id"], "level_before": before,
			"level_after": after, "target_id": target, "is_repeat": is_repeat})
	res["data"] = {"level": after, "text": Selectors.hint_text(def, after), "target": target}
	return res
