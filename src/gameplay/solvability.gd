class_name Solvability
extends RefCounted
## Content check that needs the real reducer: plays every case greedily with the canonical
## answers and fails when the success predicate can never be reached (impossible predicate,
## cyclic prerequisites, required clue locked behind itself, CTA that never enables...).

static func check(db: ContentDB) -> Array:
	var errors := []
	for cid in db.case_order:
		if db.has_case(cid):
			var e := solve_case(db, cid)
			if e != "":
				errors.append("%s: %s" % [cid, e])
	return errors

## Returns "" when solvable, otherwise a description of where progress stopped.
static func solve_case(db: ContentDB, cid: String) -> String:
	var state := GameState.new_state(db.content_version, db.case_order)
	# Pretend every other case is complete so unlock rules do not block this one.
	for other in db.case_order:
		if other != cid:
			state["campaign"]["completed"][other] = true
			state["campaign"]["reward_granted"][other] = true
			state["campaign"]["xp"] += CZ.XP_FIRST_SOLVE
	var def := db.case_def(cid)
	var n := [0]
	var ctx_uuid := func() -> String:
		n[0] += 1
		return "solver-%d" % n[0]
	var step := func(s: Dictionary, action: Dictionary, route: String) -> Dictionary:
		return Reducer.reduce(s, action, db, {"route": route, "new_uuid": ctx_uuid})
	var r: Dictionary = step.call(state, {"type": CZ.START_CASE, "case_id": cid}, "")
	if r["status"] != CZ.OK:
		return "START_CASE refused: %s" % r["code"]
	state = r["state"]
	for _i in 64:
		if state["runs"][cid]["solved"]:
			return ""
		var progressed := false
		for o in def.clickable_objects():
			r = step.call(state, {"type": CZ.INSPECT_OBJECT, "case_id": cid, "object_id": o["id"]}, def.screen("SCENE"))
			if r["status"] == CZ.OK and r["persist"]:
				state = r["state"]
				progressed = true
			if not Profiles.get_profile(o["profile"]).cta(o).is_empty():
				r = step.call(state, {"type": CZ.CONNECT_CHARGER, "case_id": cid, "object_id": o["id"]}, o["inspect_screen"])
				if r["status"] == CZ.OK:
					state = r["state"]
					progressed = true
		var cta := Selectors.deduction_cta(def, state["runs"][cid], state["campaign"])
		if cta["kind"] == "open":
			var s: Dictionary = cta["stage"]
			var submit := {"type": CZ.SUBMIT_STAGE, "case_id": cid, "stage_id": s["id"]}
			match s["type"]:
				CZ.STAGE_SINGLE_ANSWER:
					submit["answer_id"] = s["correct"]
				CZ.STAGE_EVIDENCE_SET:
					submit["evidence_ids"] = s["correct_set"]
				CZ.STAGE_TIMELINE:
					for i in s["correct_order"].size():
						r = step.call(state, {"type": CZ.PLACE_TIMELINE_TOKEN, "case_id": cid, "stage_id": s["id"],
							"token_id": s["correct_order"][i], "slot": i}, s["screen"])
						if r["status"] == CZ.OK:
							state = r["state"]
			r = step.call(state, submit, s["screen"])
			if r["status"] == CZ.OK and r["code"] in [CZ.CORRECT, CZ.SOLVED]:
				state = r["state"]
				progressed = true
			else:
				return "canonical answer for %s rejected (%s/%s)" % [s["id"], r["status"], r["code"]]
		if not progressed:
			return "no progress possible; deduction state=%s" % cta["kind"]
	return "did not converge"
