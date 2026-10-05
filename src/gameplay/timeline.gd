class_name Timeline
extends RefCounted
## Reusable timeline placement (spec C03_TIMELINE). Correctness comes from token IDs in slot
## order, never from sprite positions. Placement: the selected token leaves its old slot, the
## slot's previous occupant returns to the unplaced pool (no swap), no token appears twice.

static func place(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var g := Reducer.guard_run(state, db, cid)
	if g != "":
		return Reducer.result(CZ.REJECTED, g, state)
	var def := db.case_def(cid)
	var stage = def.stage(str(action.get("stage_id", "")))
	if stage == null or stage["type"] != CZ.STAGE_TIMELINE:
		return Reducer.result(CZ.REJECTED, CZ.UNKNOWN_STAGE, state)
	if ctx.get("route") != stage["screen"]:
		return Reducer.result(CZ.REJECTED, CZ.ROUTE_INVALID, state)
	var run: Dictionary = state["runs"][cid]
	if run["solved"]:
		return Reducer.result(CZ.NOOP, CZ.ALREADY_SOLVED, state)
	if Stages.is_passed(stage, run):
		return Reducer.result(CZ.NOOP, CZ.STAGE_ALREADY_PASSED, state)
	if not Predicate.eval(stage.get("unlock"), run, state["campaign"]):
		return Reducer.result(CZ.REJECTED, CZ.PRECONDITION_MISSING, state)
	var token := str(action.get("token_id", ""))
	var token_ids: Array = stage["tokens"].map(func(t): return t["id"])
	var slot_v = action.get("slot")
	if not token_ids.has(token) or typeof(slot_v) not in [TYPE_INT, TYPE_FLOAT]:
		return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
	var slot := int(slot_v)
	var field: String = stage["slots_field"]
	var slots: Array = run[field]
	if slot < 0 or slot >= slots.size():
		return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
	var from := slots.find(token)
	if from == slot:
		return Reducer.result(CZ.NOOP, CZ.ALREADY_DONE, state)
	var next := GameState.clone(state)
	var nslots: Array = next["runs"][cid][field]
	var displaced = nslots[slot]
	if from >= 0:
		nslots[from] = null
	nslots[slot] = token
	Reducer.bump_interaction(next)
	var res := Reducer.result(CZ.OK, CZ.OK, next, true)
	Reducer.event(res, "TIMELINE_CHANGED", {"case_id": cid, "run_id": run["run_id"], "token_id": token,
		"from_slot": from if from >= 0 else null, "to_slot": slot, "displaced_token": displaced})
	res["data"] = {"slots": nslots.duplicate()}
	return res
