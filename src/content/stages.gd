class_name Stages
extends RefCounted
## Stage result helpers shared by state validation and gameplay.

## True when the stage's result flag is set in the run (question bool or run_field bool).
static func is_passed(stage: Dictionary, run: Dictionary) -> bool:
	var res: Dictionary = stage.get("result", {})
	if res.has("question"):
		return bool(run.get("questions", {}).get(res["question"], false))
	if res.has("field"):
		return run.get(res["field"]) == true
	return false

static func set_passed(stage: Dictionary, run: Dictionary) -> void:
	var res: Dictionary = stage.get("result", {})
	if res.has("question"):
		run["questions"][res["question"]] = true
	elif res.has("field"):
		run[res["field"]] = true
