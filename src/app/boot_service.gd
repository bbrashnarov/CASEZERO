class_name BootService
extends RefCounted
## Boot flow without UI (spec Part 4 G_BOOT + Part 10 Restore):
##   load save -> validate envelope -> migrate schema -> validate content version and invariants
##   -> recover if required -> route.
## Content validation happens before this (Bootstrap) so a broken manifest fails fast.

const OK := "OK"
const FRESH := "FRESH"
const RECOVERY := "RECOVERY"
const FATAL := "FATAL"

const RECOVER_RUNS := "runs"            # only some runs are invalid: offer reset of those runs
const RECOVER_ALL := "corrupt_all"      # campaign unreadable: offer a full restart
const RECOVER_UNSUPPORTED := "unsupported"  # save from a newer schema: never overwrite silently

## Returns {"status", "state", "route", "fresh_install", "save_recovered", "recovery": {kind, cases, detail}}.
static func boot(db: ContentDB, repo: SaveRepository) -> Dictionary:
	var out := {"status": OK, "state": {}, "route": "G_BOARD", "fresh_install": false,
		"save_recovered": false, "recovery": {}}
	var loaded := repo.load()
	Log.i(Log.BOOT, "save load", {"status": loaded["status"], "error": loaded["error"]})
	match loaded["status"]:
		SaveRepository.FRESH:
			var s := GameState.new_state(db.content_version, db.case_order)
			var w := repo.commit(s)
			if not w["ok"]:
				out["status"] = FATAL
				out["recovery"] = {"kind": "write", "cases": [], "detail": w["error_category"]}
				return out
			out["status"] = FRESH
			out["state"] = s
			out["fresh_install"] = true
			# Spec Part 4: first session -> C01_INTRO; later sessions -> G_BOARD.
			out["route"] = "%s_INTRO" % db.case_order[0]
			return out
		SaveRepository.CORRUPT:
			out["status"] = RECOVERY
			out["recovery"] = {"kind": RECOVER_ALL, "cases": [], "detail": loaded["error"]}
			return out
		SaveRepository.RECOVERED_FROM_BACKUP:
			out["save_recovered"] = true
	var mig := Migrations.migrate(loaded["state"])
	if mig["status"] == "UNSUPPORTED":
		out["status"] = RECOVERY
		out["recovery"] = {"kind": RECOVER_UNSUPPORTED, "cases": [], "detail": "schema_version %s" % str(loaded["state"].get("schema_version"))}
		return out
	if mig["status"] != "OK":
		out["status"] = RECOVERY
		out["recovery"] = {"kind": RECOVER_ALL, "cases": [], "detail": "schema invalid"}
		return out
	var state: Dictionary = mig["state"]
	if not state.has("interaction_index"):
		state["interaction_index"] = 0
	if not state.has("committed_action_ids"):
		state["committed_action_ids"] = []
	var content_changed := str(state.get("content_version", "")) != db.content_version
	# Content extension rule: a case added after the save was written (e.g. C04) starts as
	# not completed / not rewarded. Existing progress is never altered by this step.
	if state.get("campaign") is Dictionary and state["campaign"].get("completed") is Dictionary \
			and state["campaign"].get("reward_granted") is Dictionary:
		for c in db.case_order:
			if not state["campaign"]["completed"].has(c):
				state["campaign"]["completed"][c] = false
				state["campaign"]["reward_granted"][c] = false
				content_changed = true
	if content_changed:
		# Explicit content-version policy: runs are re-validated against the current content;
		# anything that no longer matches is offered for reset below, never silently rewritten.
		Log.w(Log.BOOT, "content_version differs", {"save": state.get("content_version"), "content": db.content_version})
	var report := GameState.check(state, db)
	if not report["campaign"].is_empty():
		repo.preserve_current("invalid")
		out["status"] = RECOVERY
		out["recovery"] = {"kind": RECOVER_ALL, "cases": [], "detail": str(report["campaign"])}
		return out
	if not report["runs"].is_empty():
		repo.preserve_current("invalid_run")
		out["state"] = state
		out["status"] = RECOVERY
		out["recovery"] = {"kind": RECOVER_RUNS, "cases": report["runs"].keys(), "detail": str(report["runs"])}
		return out
	if content_changed or mig["applied"].size() > 0 or out["save_recovered"]:
		state["content_version"] = db.content_version
		var w2 := repo.commit(state)
		if not w2["ok"]:
			Log.w(Log.BOOT, "could not rewrite migrated save; continuing from memory", {})
	out["state"] = state
	return out

## Applies the player's recovery choice and persists it. Returns the boot-shaped result.
static func apply_recovery(db: ContentDB, repo: SaveRepository, kind: String, state: Dictionary, cases: Array) -> Dictionary:
	var s: Dictionary
	if kind == RECOVER_RUNS:
		s = state.duplicate(true)
		for c in cases:
			s["runs"].erase(c)    # lazily recreated on next START; campaign stays intact
		if not db.has_case(str(s["last_case"])):
			s["last_case"] = db.case_order[0]
		s["content_version"] = db.content_version
		var report := GameState.check(s, db)
		if not GameState.is_valid(report):
			s = GameState.new_state(db.content_version, db.case_order)
	else:
		s = GameState.new_state(db.content_version, db.case_order)
	var w := repo.commit(s)
	if not w["ok"]:
		return {"status": FATAL, "state": {}, "route": "G_BOOT", "fresh_install": false, "save_recovered": true,
			"recovery": {"kind": "write", "cases": [], "detail": w["error_category"]}}
	return {"status": OK, "state": s, "route": "G_BOARD", "fresh_install": false, "save_recovered": true, "recovery": {}}
