class_name CaseDef
extends RefCounted
## Read-only typed view over one case JSON (content/cases/<id>.json).
## All gameplay code reads case data through this class; nothing here is mutable at runtime.

var data: Dictionary
var id: String
var objects: Array = []
var evidence: Array = []
var stages: Array = []
var _obj_by_id := {}
var _obj_by_screen := {}
var _ev_by_id := {}
var _stage_by_id := {}
var _stage_by_screen := {}

func _init(d: Dictionary) -> void:
	data = d
	id = str(d.get("case_id", ""))
	objects = d.get("objects", [])
	evidence = d.get("evidence", [])
	stages = d.get("stages", [])
	for o in objects:
		_obj_by_id[o["id"]] = o
		if o.get("inspect_screen") != null:
			_obj_by_screen[o["inspect_screen"]] = o
	for e in evidence:
		_ev_by_id[e["id"]] = e
	for s in stages:
		_stage_by_id[s["id"]] = s
		_stage_by_screen[s["screen"]] = s

func title() -> String: return str(data.get("title", id))
func objective() -> String: return str(data.get("objective", ""))
func opening_text() -> String: return str(data.get("opening_text", ""))
func solved_text() -> String: return str(data.get("solved_text", ""))
func scene_id() -> String: return str(data.get("scene_id", ""))
func next_case() -> Variant: return data.get("next_case")
func unlock() -> Variant: return data.get("unlock", false)
func success() -> Variant: return data.get("success", false)
func run_fields() -> Dictionary: return data.get("run_fields", {})
func invariants() -> Array: return data.get("invariants", [])
func hint_texts() -> Array: return data.get("hints", {}).get("texts", [])
func hint_targets() -> Array: return data.get("hints", {}).get("targets", [])
func background() -> Dictionary: return data.get("background", {})

func object(object_id: String) -> Variant: return _obj_by_id.get(object_id)
func object_for_screen(screen_id: String) -> Variant: return _obj_by_screen.get(screen_id)
func evidence_def(evidence_id: String) -> Variant: return _ev_by_id.get(evidence_id)
func stage(stage_id: String) -> Variant: return _stage_by_id.get(stage_id)
func stage_for_screen(screen_id: String) -> Variant: return _stage_by_screen.get(screen_id)

func clickable_objects() -> Array:
	return objects.filter(func(o): return o.get("clickable", false))

func evidence_ids() -> Array:
	return evidence.map(func(e): return e["id"])

func required_evidence_ids() -> Array:
	return evidence.filter(func(e): return e.get("required", false)).map(func(e): return e["id"])

## Question IDs are the stages whose result writes runs[case].questions[...].
func question_ids() -> Array:
	var out := []
	for s in stages:
		var r: Dictionary = s.get("result", {})
		if r.has("question"):
			out.append(r["question"])
	return out

func evidence_index(evidence_id: String) -> int:
	for i in evidence.size():
		if evidence[i]["id"] == evidence_id:
			return i
	return -1

## Screen IDs derived from the case prefix (spec Part 5–7 screen registers).
func screen(suffix: String) -> String:
	return "%s_%s" % [id, suffix]
