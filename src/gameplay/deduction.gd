class_name Deduction
extends RefCounted
## SUBMIT_STAGE for every deduction form: single answer, evidence set, timeline order.
## Validation uses IDs, prerequisites and domain state only — never what the UI highlights.

static func submit(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var g := Reducer.guard_run(state, db, cid)
	if g != "":
		return Reducer.result(CZ.REJECTED, g, state)
	var def := db.case_def(cid)
	var stage = def.stage(str(action.get("stage_id", "")))
	if stage == null:
		return Reducer.result(CZ.REJECTED, CZ.UNKNOWN_STAGE, state)
	if ctx.get("route") != stage["screen"]:
		return Reducer.result(CZ.REJECTED, CZ.ROUTE_INVALID, state)
	var run: Dictionary = state["runs"][cid]
	var campaign: Dictionary = state["campaign"]
	if run["solved"]:
		# Repeated submit after solve: no-op, route to SOLVED, no duplicate event or reward.
		var done := Reducer.result(CZ.NOOP, CZ.ALREADY_SOLVED, state)
		done["data"] = {"route": "SOLVED"}
		return done
	if Stages.is_passed(stage, run):
		return Reducer.result(CZ.NOOP, CZ.STAGE_ALREADY_PASSED, state)
	if not Predicate.eval(stage.get("unlock"), run, campaign):
		return Reducer.result(CZ.REJECTED, CZ.PRECONDITION_MISSING, state)

	var answer_id = null
	var selected: Array = []
	var tokens: Array = []
	var correct := false
	var reason := ""
	match stage["type"]:
		CZ.STAGE_SINGLE_ANSWER:
			answer_id = action.get("answer_id")
			var ids: Array = stage["answers"].map(func(a): return a["id"])
			if answer_id == null or not ids.has(answer_id):
				return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
			correct = answer_id == stage["correct"]
			reason = "WRONG_ANSWER"
		CZ.STAGE_EVIDENCE_SET:
			var raw = action.get("evidence_ids", [])
			if not (raw is Array):
				return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
			var uniq := {}
			for e in raw:
				uniq[e] = true
			selected = uniq.keys()
			if selected.size() != raw.size() or selected.size() != int(stage["select_count"]):
				return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
			for e in selected:
				if not run["evidence"].has(e):
					return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
			correct = true
			for e in stage["correct_set"]:
				if not uniq.has(e):
					correct = false
			reason = "WRONG_SET"
		CZ.STAGE_TIMELINE:
			tokens = run[stage["slots_field"]].duplicate()
			var placed := {}
			for t in tokens:
				if t == null or placed.has(t):
					return Reducer.result(CZ.REJECTED, CZ.INVALID_SELECTION, state)
				placed[t] = true
			correct = tokens == stage["correct_order"]
			reason = "WRONG_ORDER"
		_:
			return Reducer.result(CZ.REJECTED, CZ.INVALID_PAYLOAD, state)

	var next := GameState.clone(state)
	var nrun: Dictionary = next["runs"][cid]
	Reducer.bump_interaction(next)
	var submitted := {"case_id": cid, "run_id": run["run_id"], "stage_id": stage["id"], "answer_id": answer_id,
		"selected_evidence_ids": _registry_sorted(def, selected), "timeline_token_ids": tokens}
	if not correct:
		nrun["attempts"] = int(nrun["attempts"]) + 1
		var bad := Reducer.result(CZ.OK, CZ.WRONG, next, true)
		Reducer.event(bad, "DEDUCTION_SUBMITTED", submitted)
		Reducer.event(bad, "DEDUCTION_FAILED", {"case_id": cid, "run_id": run["run_id"], "stage_id": stage["id"],
			"reason": reason, "attempts_after": nrun["attempts"]})
		bad["feedback"]["sfx"].append("SFX_WRONG_DEDUCTION")
		bad["data"] = {"feedback": str(stage.get("incorrect_feedback", ""))}
		return bad

	Stages.set_passed(stage, nrun)
	if stage.get("final", false):
		var solve := Resolution.atomic_solve(next, def)
		if not solve["ok"]:
			# Content promised this stage completes the case; refusing keeps state consistent.
			Log.e(Log.GAMEPLAY, "final stage passed but success predicate false", {"case": cid, "stage": stage["id"]})
			return Reducer.result(CZ.REJECTED, CZ.INVARIANT_VIOLATION, state)
		var ok := Reducer.result(CZ.OK, CZ.SOLVED, next, true)
		Reducer.event(ok, "DEDUCTION_SUBMITTED", submitted)
		Reducer.event(ok, "CASE_SOLVED", {"case_id": cid, "run_id": run["run_id"], "attempts_total": nrun["attempts"],
			"hint_level": nrun["hint_level"], "active_ms": nrun["active_ms"],
			"required_count": Selectors.required_found(def, nrun), "replay": solve["replay"], "xp_delta": solve["xp_delta"]})
		ok["feedback"]["sfx"].append("SFX_CASE_SOLVED")
		ok["feedback"]["haptic"] = CZ.HAPTIC_MEDIUM
		ok["data"] = {"route": "SOLVED", "xp_delta": solve["xp_delta"], "replay": solve["replay"],
			"feedback": str(stage.get("correct_feedback", ""))}
		return ok
	var res := Reducer.result(CZ.OK, CZ.CORRECT, next, true)
	Reducer.event(res, "DEDUCTION_SUBMITTED", submitted)
	Reducer.event(res, "DEDUCTION_SUCCEEDED", {"case_id": cid, "run_id": run["run_id"], "stage_id": stage["id"]})
	res["feedback"]["sfx"].append("SFX_DEDUCTION_CORRECT")
	var after := Selectors.deduction_cta(def, nrun, next["campaign"])
	res["data"] = {"feedback": str(stage.get("correct_feedback", "")), "success_cta": stage.get("success_cta"),
		"next_screen": after["stage"]["screen"] if after["kind"] == "open" else null}
	return res

static func _registry_sorted(def: CaseDef, ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return def.evidence_index(a) < def.evidence_index(b))
	return out
