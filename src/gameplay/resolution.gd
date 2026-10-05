class_name Resolution
extends RefCounted
## Case resolution (spec Part 10 atomicSolve). Mutates the PROPOSED state only; the Store
## persists solved + completed + reward_granted + xp in one snapshot write, so a process kill
## can never leave "solved" without the reward bookkeeping or vice versa.

## Returns {"ok": bool, "noop": bool, "xp_delta": int, "replay": bool}.
static func atomic_solve(next: Dictionary, def: CaseDef) -> Dictionary:
	var cid := def.id
	var run: Dictionary = next["runs"][cid]
	var campaign: Dictionary = next["campaign"]
	if not Predicate.eval(def.success(), run, campaign):
		return {"ok": false, "noop": false, "xp_delta": 0, "replay": false}
	if run["solved"]:
		return {"ok": true, "noop": true, "xp_delta": 0, "replay": true}
	var was_completed := bool(campaign["completed"].get(cid, false))
	run["solved"] = true
	campaign["completed"][cid] = true
	var xp_delta := 0
	# Reward idempotency key is the campaign case ID, not the run: replays and resets never pay twice.
	if not campaign["reward_granted"].get(cid, false):
		campaign["reward_granted"][cid] = true
		campaign["xp"] = int(campaign["xp"]) + CZ.XP_FIRST_SOLVE
		xp_delta = CZ.XP_FIRST_SOLVE
	return {"ok": true, "noop": false, "xp_delta": xp_delta, "replay": was_completed}
