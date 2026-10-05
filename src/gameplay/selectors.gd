class_name Selectors
extends RefCounted
## Derived state (spec Part 10): computed on demand from GameState + content, never stored.

const UI_EVIDENCE := "UI_EVIDENCE"

static func run_of(state: Dictionary, case_id: String) -> Dictionary:
	return state.get("runs", {}).get(case_id, {})

## case_unlocked = C01 OR previous campaign.completed (expressed in content as `unlock`).
static func case_unlocked(db: ContentDB, state: Dictionary, case_id: String) -> bool:
	var def := db.case_def(case_id)
	if def == null:
		return false
	return Predicate.eval(def.unlock(), {}, state["campaign"])

static func gate_open(obj: Dictionary, run: Dictionary, campaign: Dictionary) -> bool:
	if not obj.get("clickable", false):
		return false
	return Predicate.eval(obj.get("gate"), run, campaign)

## evidence_counter = count(required ∩ evidence)
static func required_found(def: CaseDef, run: Dictionary) -> int:
	var ev: Array = run.get("evidence", [])
	var n := 0
	for id in def.required_evidence_ids():
		if ev.has(id):
			n += 1
	return n

static func required_total(def: CaseDef) -> int:
	return def.required_evidence_ids().size()

## Deduction CTA route selection (spec Part 5–7 "Route selection при натискане на deduction CTA").
## Returns {"kind": "solved"|"open"|"waiting"|"blocked", "stage": Dictionary|null, "index": int}.
##   open     first unpassed stage with prerequisites met  -> CTA enabled, opens stage screen
##   waiting  first unpassed stage defines waiting_cta whose `when` holds (C01 "Провери показанията")
##   blocked  prerequisites missing                         -> CTA disabled "Нужни са още улики"
static func deduction_cta(def: CaseDef, run: Dictionary, campaign: Dictionary) -> Dictionary:
	if run.get("solved", false):
		return {"kind": "solved", "stage": null, "index": def.stages.size()}
	for i in def.stages.size():
		var s: Dictionary = def.stages[i]
		if Stages.is_passed(s, run):
			continue
		if Predicate.eval(s.get("unlock"), run, campaign):
			return {"kind": "open", "stage": s, "index": i}
		var w = s.get("waiting_cta")
		if w != null and Predicate.eval(w.get("when"), run, campaign):
			return {"kind": "waiting", "stage": s, "index": i}
		return {"kind": "blocked", "stage": s, "index": i}
	# All stages passed but not solved can only happen with inconsistent content; the
	# validator's solvability check rejects such content.
	return {"kind": "blocked", "stage": null, "index": def.stages.size()}

static func stage_unlocked(stage: Dictionary, run: Dictionary, campaign: Dictionary) -> bool:
	return Predicate.eval(stage.get("unlock"), run, campaign)

## Hint target (spec Part 4 Hint panel + per-case target order): first mandatory source in case
## order that is available and not yet satisfied; otherwise the deduction control (UI_EVIDENCE).
static func hint_target(def: CaseDef, run: Dictionary, campaign: Dictionary) -> String:
	for t in def.hint_targets():
		if t.has("available") and not Predicate.eval(t["available"], run, campaign):
			continue
		if not Predicate.eval(t.get("satisfied"), run, campaign):
			return str(t["object_id"])
	return UI_EVIDENCE

static func hint_text(def: CaseDef, level: int) -> String:
	var texts := def.hint_texts()
	if level < 1 or level > texts.size():
		return ""
	return str(texts[level - 1]["text"])

## Board card status (spec Part 4 G_BOARD): locked / new / in_progress / solved.
static func board_status(db: ContentDB, state: Dictionary, case_id: String) -> String:
	if not case_unlocked(db, state, case_id):
		return "locked"
	var run := run_of(state, case_id)
	if not run.is_empty() and run.get("solved", false):
		return "solved"
	if not run.is_empty() and run.get("started", false):
		return "in_progress"
	if state["campaign"]["completed"].get(case_id, false):
		return "solved"
	return "new"

## Short stage descriptor used by analytics (CASE_RESUMED.stage, CASE_EXITED.stage).
static func stage_label(def: CaseDef, run: Dictionary, campaign: Dictionary) -> String:
	var cta := deduction_cta(def, run, campaign)
	match cta["kind"]:
		"solved":
			return "SOLVED"
		"open", "waiting":
			return str(cta["stage"]["id"])
		_:
			return "INVESTIGATION"
