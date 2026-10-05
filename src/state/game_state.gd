class_name GameState
extends RefCounted
## Canonical GameState schema (spec Part 10) as plain Dictionaries, so the persisted JSON is
## exactly the authoritative structure. This class only builds, normalises and validates state;
## it never decides gameplay outcomes (that is the reducer's job).
##
## Persisted extras beyond the Part 10 example, both listed as "persisted YES" in its
## Additional variable table or required by the transaction contract:
##   interaction_index       event ordering
##   committed_action_ids    bounded journal for action idempotency across process kills

static func new_state(content_version: String, case_ids: Array) -> Dictionary:
	var completed := {}
	var granted := {}
	for c in case_ids:
		completed[c] = false
		granted[c] = false
	return {
		"schema_version": CZ.SCHEMA_VERSION,
		"content_version": content_version,
		"campaign": {"xp": 0, "completed": completed, "reward_granted": granted},
		"settings": {"sound": true, "haptic": true, "reduced_motion": false},
		"last_case": case_ids[0] if case_ids.size() > 0 else "",
		"runs": {},
		"interaction_index": 0,
		"committed_action_ids": [],
	}

## Fresh run with every field of the case state table (spec: runs populated lazily on first START).
static func new_run(def: CaseDef, run_id: String) -> Dictionary:
	var objects := {}
	for o in def.clickable_objects():
		objects[o["id"]] = {"inspection": CZ.UNSEEN}
	var questions := {}
	for q in def.question_ids():
		questions[q] = false
	var run := {
		"run_id": run_id,
		"started": false,
		"evidence": [],
		"objects": objects,
		"questions": questions,
		"hint_level": 0,
		"attempts": 0,
		"solved": false,
		"active_ms": 0,
	}
	var fields := def.run_fields()
	for f in fields:
		run[f] = initial_field_value(fields[f])
	return run

static func initial_field_value(spec: Dictionary) -> Variant:
	match spec.get("type"):
		"token_slots":
			var arr := []
			for i in int(spec.get("size", 0)):
				arr.append(null)
			return arr
		"bool":
			return bool(spec.get("initial", false))
		_:
			return spec.get("initial")

static func clone(state: Dictionary) -> Dictionary:
	return state.duplicate(true)

## Adds evidence keeping set semantics and registry order (spec: evidence is Set<EvidenceID>).
## Returns true when the ID was newly added.
static func add_evidence(run: Dictionary, def: CaseDef, evidence_id: String) -> bool:
	var ev: Array = run["evidence"]
	if ev.has(evidence_id):
		return false
	ev.append(evidence_id)
	ev.sort_custom(func(a, b): return def.evidence_index(a) < def.evidence_index(b))
	return true

## JSON has no integer type; Godot parses every number as float. Restore integer fields after
## load so equality checks and arithmetic stay exact.
static func normalize(state: Dictionary) -> Dictionary:
	if state.has("schema_version"):
		state["schema_version"] = int(state["schema_version"])
	if state.has("interaction_index"):
		state["interaction_index"] = int(state["interaction_index"])
	if state.has("campaign") and state["campaign"] is Dictionary and state["campaign"].has("xp"):
		state["campaign"]["xp"] = int(state["campaign"]["xp"])
	if state.has("runs") and state["runs"] is Dictionary:
		for c in state["runs"]:
			var run = state["runs"][c]
			if run is Dictionary:
				for k in ["hint_level", "attempts", "active_ms"]:
					if run.has(k):
						run[k] = int(run[k])
	return state

# ---------------------------------------------------------------------------------------
# Invariants. Called after every reducer step (proposed state) and on restore.
# Returns {"campaign": [errors], "runs": {case_id: [errors]}} so restore can reset only the
# affected run (spec Part 10 Restore) instead of wiping campaign progress.
# ---------------------------------------------------------------------------------------
static func check(state: Dictionary, db: ContentDB) -> Dictionary:
	var out := {"campaign": [], "runs": {}}
	var camp_errs: Array = out["campaign"]
	for k in ["schema_version", "content_version", "campaign", "settings", "last_case", "runs"]:
		if not state.has(k):
			camp_errs.append("missing key %s" % k)
	if not camp_errs.is_empty():
		return out
	var campaign = state["campaign"]
	if not (campaign is Dictionary) or not campaign.has("completed") or not campaign.has("reward_granted") or not campaign.has("xp"):
		camp_errs.append("campaign malformed")
		return out
	var granted_count := 0
	for c in campaign["reward_granted"]:
		if not db.has_case(c):
			camp_errs.append("reward_granted has unknown case %s" % c)
		if campaign["reward_granted"][c] == true:
			granted_count += 1
			if campaign["completed"].get(c) != true:
				camp_errs.append("reward_granted %s without completed" % c)
	for c in campaign["completed"]:
		if not db.has_case(c):
			camp_errs.append("completed has unknown case %s" % c)
	for c in db.case_order:
		if not campaign["completed"].has(c) or not campaign["reward_granted"].has(c):
			camp_errs.append("campaign missing case %s" % c)
	# Spec Part 10: xp = 100 * count(reward_granted == true) for this slice.
	if int(campaign["xp"]) != CZ.XP_FIRST_SOLVE * granted_count:
		camp_errs.append("xp %d != 100 * %d rewards" % [int(campaign["xp"]), granted_count])
	var settings = state["settings"]
	if not (settings is Dictionary):
		camp_errs.append("settings malformed")
	else:
		for k in ["sound", "haptic", "reduced_motion"]:
			if typeof(settings.get(k)) != TYPE_BOOL:
				camp_errs.append("setting %s must be bool" % k)
	if not db.has_case(str(state["last_case"])):
		camp_errs.append("last_case unknown")
	if not (state["runs"] is Dictionary):
		camp_errs.append("runs malformed")
		return out
	for c in state["runs"]:
		if not db.has_case(c):
			camp_errs.append("run for unknown case %s" % c)
			continue
		var errs := check_run(state["runs"][c], db.case_def(c), campaign)
		if not errs.is_empty():
			out["runs"][c] = errs
	return out

static func is_valid(report: Dictionary) -> bool:
	return report["campaign"].is_empty() and report["runs"].is_empty()

static func check_run(run: Variant, def: CaseDef, campaign: Dictionary) -> Array:
	var errs := []
	if not (run is Dictionary):
		return ["run is not an object"]
	for k in ["run_id", "started", "evidence", "objects", "questions", "hint_level", "attempts", "solved", "active_ms"]:
		if not run.has(k):
			errs.append("missing %s" % k)
	if not errs.is_empty():
		return errs
	var known_ev := def.evidence_ids()
	var seen := {}
	for e in run["evidence"]:
		if not known_ev.has(e):
			errs.append("unknown evidence %s" % e)
		if seen.has(e):
			errs.append("duplicate evidence %s" % e)
		seen[e] = true
	var clickable := def.clickable_objects().map(func(o): return o["id"])
	for oid in run["objects"]:
		if not clickable.has(oid):
			errs.append("unknown object %s" % oid)
		elif not [CZ.UNSEEN, CZ.SEEN].has(run["objects"][oid].get("inspection")):
			errs.append("invalid inspection state for %s" % oid)
	for oid in clickable:
		if not run["objects"].has(oid):
			errs.append("missing object %s" % oid)
	var qids := def.question_ids()
	for q in run["questions"]:
		if not qids.has(q):
			errs.append("unknown question %s" % q)
	for q in qids:
		if not run["questions"].has(q):
			errs.append("missing question %s" % q)
	if int(run["hint_level"]) < 0 or int(run["hint_level"]) > CZ.HINT_MAX_LEVEL:
		errs.append("hint_level out of range")
	if int(run["attempts"]) < 0:
		errs.append("attempts negative")
	var fields := def.run_fields()
	for f in fields:
		var spec: Dictionary = fields[f]
		if not run.has(f):
			errs.append("missing run_field %s" % f)
			continue
		match spec.get("type"):
			"enum":
				if not spec.get("values", []).has(run[f]):
					errs.append("run_field %s invalid value" % f)
			"bool":
				if typeof(run[f]) != TYPE_BOOL:
					errs.append("run_field %s must be bool" % f)
			"token_slots":
				var slots = run[f]
				if not (slots is Array) or slots.size() != int(spec.get("size", 0)):
					errs.append("run_field %s wrong size" % f)
				else:
					var placed := {}
					for t in slots:
						if t != null:
							if placed.has(t):
								errs.append("duplicate token %s in %s" % [t, f])
							placed[t] = true
	if not errs.is_empty():
		return errs
	for inv in def.invariants():
		if not Predicate.eval(inv, run, campaign):
			errs.append("case invariant failed: %s" % JSON.stringify(inv))
	# A passed stage implies its prerequisites held when it was passed; evidence is never removed
	# within a run, so it must still hold.
	for s in def.stages:
		if Stages.is_passed(s, run) and not Predicate.eval(s.get("unlock"), run, campaign):
			errs.append("stage %s passed without prerequisites" % s["id"])
	if run["solved"] == true:
		if not Predicate.eval(def.success(), run, campaign):
			errs.append("solved without success predicate")
		if campaign.get("completed", {}).get(def.id) != true:
			errs.append("solved run but campaign not completed")
	if run["started"] != true and (not run["evidence"].is_empty() or run["solved"] == true):
		errs.append("progress in a run that was never started")
	return errs
