class_name Migrations
extends RefCounted
## Explicit, versioned save migrations. schema_version 1 is the only version so far, so the
## registry is empty; the contract is what matters:
##   * version == current          -> unchanged
##   * version <  current          -> apply each registered step in order; a missing step fails
##   * version >  current          -> UNSUPPORTED (newer build wrote it); never overwrite it
## There is no silent migration (spec Part 10 Restore).

const CURRENT := CZ.SCHEMA_VERSION

## from_version -> Callable(state: Dictionary) -> Dictionary (returns state at from_version + 1)
static var steps := {}

static func migrate(state: Dictionary) -> Dictionary:
	var v := int(state.get("schema_version", -1))
	if v == CURRENT:
		return {"status": "OK", "state": state, "applied": []}
	if v > CURRENT:
		return {"status": "UNSUPPORTED", "state": state, "applied": []}
	if v < 1:
		return {"status": "INVALID", "state": state, "applied": []}
	var applied := []
	var s := state
	while v < CURRENT:
		if not steps.has(v):
			return {"status": "INVALID", "state": state, "applied": applied}
		s = steps[v].call(s.duplicate(true))
		v += 1
		s["schema_version"] = v
		applied.append(v)
	return {"status": "OK", "state": s, "applied": applied}
