class_name Reducer
extends RefCounted
## Pure domain transition function (spec Part 10 Reducer / transaction contract).
##
##   reduce(state, action, db, ctx) -> result
##
## `state` is the last committed state and is never mutated: every accepted change is applied to
## a deep copy. `ctx` injects everything non-deterministic: {"route": String, "new_uuid": Callable}.
## The result describes the outcome; the Store decides about persistence and commit.
##
## result = {
##   status:   CZ.OK | CZ.NOOP | CZ.REJECTED
##   code:     CZ result code
##   state:    proposed next state (OK) or the unchanged input
##   persist:  true when the proposed state differs and must be written before commit
##   events:   [{name, props}] analytics describing the committed outcome (emitted after commit)
##   feedback: {sfx: [Sound Event ID], haptic: level, toast: String}
##   data:     action-specific information for the UI (detail text, feedback copy, next route)
## }

static func reduce(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	match action.get("type"):
		CZ.START_CASE:
			return _start_case(state, action, db, ctx)
		CZ.INSPECT_OBJECT:
			return _inspect(state, action, db, ctx)
		CZ.CONNECT_CHARGER:
			return _connect(state, action, db, ctx)
		CZ.PLACE_TIMELINE_TOKEN:
			return Timeline.place(state, action, db, ctx)
		CZ.SUBMIT_STAGE:
			return Deduction.submit(state, action, db, ctx)
		CZ.REQUEST_HINT:
			return Hints.request(state, action, db, ctx)
		CZ.RESET_RUN:
			return _reset_run(state, action, db, ctx)
		CZ.SET_SETTING:
			return _set_setting(state, action)
		CZ.NAVIGATE:
			return _navigate(state, action, db)
		CZ.CHECKPOINT_ACTIVE_TIME:
			return _checkpoint(state, action)
	return result(CZ.REJECTED, CZ.INVALID_PAYLOAD, state)

# --- result helpers ------------------------------------------------------------------

static func result(status: String, code: String, next: Dictionary, persist := false) -> Dictionary:
	return {"status": status, "code": code, "state": next, "persist": persist,
		"events": [], "feedback": {"sfx": [], "haptic": CZ.HAPTIC_NONE, "toast": ""}, "data": {}}

static func event(res: Dictionary, name: String, props: Dictionary) -> void:
	res["events"].append({"name": name, "props": props})

## Common guard: case exists and has a started run. Returns "" when OK, else a result code.
static func guard_run(state: Dictionary, db: ContentDB, case_id: String) -> String:
	if not db.has_case(case_id):
		return CZ.UNKNOWN_CASE
	var run: Dictionary = state["runs"].get(case_id, {})
	if run.is_empty() or not run.get("started", false):
		return CZ.NOT_STARTED
	return ""

## Every committed interaction advances the persisted ordering index.
static func bump_interaction(next: Dictionary) -> void:
	next["interaction_index"] = int(next.get("interaction_index", 0)) + 1

# --- START_CASE ----------------------------------------------------------------------

static func _start_case(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	if not db.has_case(cid):
		return result(CZ.REJECTED, CZ.UNKNOWN_CASE, state)
	if not Selectors.case_unlocked(db, state, cid):
		return result(CZ.REJECTED, CZ.CASE_LOCKED, state)
	var existing: Dictionary = state["runs"].get(cid, {})
	if not existing.is_empty() and existing.get("started", false):
		return result(CZ.NOOP, CZ.ALREADY_STARTED, state)
	var next := GameState.clone(state)
	var def := db.case_def(cid)
	var run: Dictionary = next["runs"].get(cid, {})
	if run.is_empty():
		run = GameState.new_run(def, ctx["new_uuid"].call())
		next["runs"][cid] = run
	# Spec Part 10: started=true in the same START transaction.
	run["started"] = true
	next["last_case"] = cid
	bump_interaction(next)
	var res := result(CZ.OK, CZ.OK, next, true)
	var replay := bool(state["campaign"]["completed"].get(cid, false))
	event(res, "CASE_STARTED", {"case_id": cid, "run_id": run["run_id"],
		"entry_source": str(action.get("entry_source", "board")), "replay": replay})
	return res

# --- INSPECT_OBJECT ------------------------------------------------------------------

static func _inspect(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var g := guard_run(state, db, cid)
	if g != "":
		return result(CZ.REJECTED, g, state)
	var def := db.case_def(cid)
	# Interaction prerequisite: "screen=SCENE AND no modal" — the Store passes the live route.
	if ctx.get("route") != def.screen("SCENE"):
		return result(CZ.REJECTED, CZ.ROUTE_INVALID, state)
	var oid := str(action.get("object_id", ""))
	var obj = def.object(oid)
	if obj == null:
		return result(CZ.REJECTED, CZ.UNKNOWN_OBJECT, state)
	if not obj.get("clickable", false):
		# Decorations never intercept input (spec Part 2): no event, no feedback.
		return result(CZ.REJECTED, CZ.NOT_INTERACTIVE, state)
	var run: Dictionary = state["runs"][cid]
	var profile := Profiles.get_profile(obj["profile"])
	var inspection: String = run["objects"][oid]["inspection"]
	var gate := Selectors.gate_open(obj, run, state["campaign"])
	var tapped := {"case_id": cid, "run_id": run["run_id"], "object_id": oid, "inspection_state": inspection,
		"physical_state": profile.art_variant(obj, run) if obj.has("variant_field") else str(obj.get("physical_state", "STATIC")),
		"gate_passed": gate}
	if not gate:
		var locked := result(CZ.NOOP, CZ.GATE_LOCKED, state)
		event(locked, "OBJECT_TAPPED", tapped)
		locked["data"] = {"locked_text": str(obj.get("locked_text", ""))}
		return locked
	var resolved := profile.resolve(obj, run)
	var next := GameState.clone(state)
	var nrun: Dictionary = next["runs"][cid]
	var first := inspection == CZ.UNSEEN
	nrun["objects"][oid]["inspection"] = CZ.SEEN
	var added := []
	for eid in resolved["evidence"]:
		if GameState.add_evidence(nrun, def, eid):
			added.append(eid)
	var changed := first or not added.is_empty()
	if changed:
		bump_interaction(next)
	var res := result(CZ.OK, CZ.OK, next if changed else state, changed)
	event(res, "OBJECT_TAPPED", tapped)
	event(res, "OBJECT_INSPECTED", {"case_id": cid, "run_id": run["run_id"], "object_id": oid,
		"first_inspection": first, "detail_variant": resolved["variant"]})
	for eid in added:
		var key := "%s:%s" % [run["run_id"], eid]  # Part 10 idempotency key = run_id + evidence_id
		event(res, "CLUE_DISCOVERED", {"case_id": cid, "run_id": run["run_id"], "evidence_id": eid,
			"source_object_id": oid, "discovery_key": key})
		event(res, "EVIDENCE_ADDED", {"case_id": cid, "run_id": run["run_id"], "evidence_id": eid,
			"required_count_after": Selectors.required_found(def, nrun), "discovery_key": key})
	if not added.is_empty():
		# One clue sound and one LIGHT haptic per transaction, however many IDs it adds.
		res["feedback"]["sfx"].append("SFX_CLUE_FOUND")
		res["feedback"]["haptic"] = CZ.HAPTIC_LIGHT
		res["feedback"]["toast"] = db.t("toast_clue_single") if added.size() == 1 else db.t("toast_clue_multi") % added.size()
	res["data"] = {"object_id": oid, "detail_text": resolved["detail_text"], "variant": resolved["variant"],
		"first_inspection": first, "new_evidence": added, "repeat": not first and added.is_empty()}
	return res

# --- CONNECT_CHARGER -----------------------------------------------------------------

static func _connect(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var g := guard_run(state, db, cid)
	if g != "":
		return result(CZ.REJECTED, g, state)
	var def := db.case_def(cid)
	var oid := str(action.get("object_id", ""))
	var obj = def.object(oid)
	if obj == null:
		return result(CZ.REJECTED, CZ.UNKNOWN_OBJECT, state)
	var profile := Profiles.get_profile(obj["profile"])
	var cta := profile.cta(obj)
	if cta.is_empty() or cta.get("action") != CZ.CONNECT_CHARGER:
		return result(CZ.REJECTED, CZ.INVALID_PAYLOAD, state)
	# Spec Part 12 §H: CONNECT_CHARGER requires the C02_INSPECT_CHARGER route.
	if ctx.get("route") != obj.get("inspect_screen"):
		return result(CZ.REJECTED, CZ.ROUTE_INVALID, state)
	var run: Dictionary = state["runs"][cid]
	if not Predicate.eval(cta.get("enabled_when"), run, state["campaign"]):
		return result(CZ.NOOP, CZ.ALREADY_DONE, state)
	var next := GameState.clone(state)
	var nrun: Dictionary = next["runs"][cid]
	var prior := {}
	for f in cta.get("effects", {}):
		prior[f] = nrun[f]
		nrun[f] = cta["effects"][f]
	bump_interaction(next)
	var res := result(CZ.OK, CZ.OK, next, true)
	var ev_props := {"case_id": cid, "run_id": run["run_id"], "object_id": oid}
	for f in cta.get("event_prior_fields", {}):
		ev_props[cta["event_prior_fields"][f]] = prior.get(f)
	event(res, str(cta.get("event", "CHARGER_CONNECTED")), ev_props)
	if cta.get("sound") != null:
		res["feedback"]["sfx"].append(str(cta["sound"]))
	return res

# --- RESET_RUN -----------------------------------------------------------------------

static func _reset_run(state: Dictionary, action: Dictionary, db: ContentDB, ctx: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	if not db.has_case(cid):
		return result(CZ.REJECTED, CZ.UNKNOWN_CASE, state)
	if not Selectors.case_unlocked(db, state, cid):
		return result(CZ.REJECTED, CZ.CASE_LOCKED, state)
	var next := GameState.clone(state)
	var old: Dictionary = state["runs"].get(cid, {})
	# Restart clears only the run; campaign.completed / reward_granted / xp are untouched.
	var run := GameState.new_run(db.case_def(cid), ctx["new_uuid"].call())
	next["runs"][cid] = run
	next["last_case"] = cid
	bump_interaction(next)
	var res := result(CZ.OK, CZ.OK, next, true)
	event(res, "CASE_RESTARTED", {"case_id": cid, "run_id": run["run_id"], "old_run_id": old.get("run_id"),
		"new_run_id": run["run_id"], "was_solved": bool(old.get("solved", false))})
	return res

# --- SET_SETTING ---------------------------------------------------------------------

static func _set_setting(state: Dictionary, action: Dictionary) -> Dictionary:
	var key := str(action.get("key", ""))
	if not state["settings"].has(key) or typeof(action.get("value")) != TYPE_BOOL:
		return result(CZ.REJECTED, CZ.INVALID_PAYLOAD, state)
	if state["settings"][key] == action["value"]:
		return result(CZ.NOOP, CZ.ALREADY_DONE, state)
	var next := GameState.clone(state)
	next["settings"][key] = action["value"]
	bump_interaction(next)
	return result(CZ.OK, CZ.OK, next, true)

# --- NAVIGATE --------------------------------------------------------------------------
## Navigation itself is runtime-only (route is not persisted). The only persisted effect is
## last_case on accepted case selection (Part 10), used by the Board "Продължи" badge.

static func _navigate(state: Dictionary, action: Dictionary, db: ContentDB) -> Dictionary:
	var cid = action.get("case_id")
	if cid == null or not db.has_case(str(cid)) or state["last_case"] == cid:
		return result(CZ.NOOP, CZ.ALREADY_DONE, state)
	var next := GameState.clone(state)
	next["last_case"] = cid
	return result(CZ.OK, CZ.OK, next, true)

# --- CHECKPOINT_ACTIVE_TIME -------------------------------------------------------------

static func _checkpoint(state: Dictionary, action: Dictionary) -> Dictionary:
	var cid := str(action.get("case_id", ""))
	var add := int(action.get("add_ms", 0))
	var run: Dictionary = state["runs"].get(cid, {})
	if run.is_empty() or add <= 0:
		return result(CZ.NOOP, CZ.ALREADY_DONE, state)
	var next := GameState.clone(state)
	next["runs"][cid]["active_ms"] = int(run["active_ms"]) + add
	return result(CZ.OK, CZ.OK, next, true)
