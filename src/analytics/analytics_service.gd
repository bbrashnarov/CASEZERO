class_name AnalyticsService
extends RefCounted
## Local-first analytics (spec Part 11). Events are appended as JSON lines to a local log with a
## 5 MiB budget (FIFO drop of the oldest events, never touching save data). Nothing is sent
## anywhere; playtest builds export the log explicitly. A failure here is logged and ignored:
## save and analytics are separate reliability domains, and listeners never write GameState.

const DIR := "user://analytics"
const FILE := "events.jsonl"
## Properties that may carry personal data or free text are never recorded.
const FORBIDDEN_KEYS := ["name", "user", "account", "email", "phone", "path", "device_id", "text"]

var build_id := ""
var content_version := ""
var session_id := Uuid.v4()
var budget_bytes := CZ.ANALYTICS_BUDGET_BYTES
var state_provider: Callable = func() -> Dictionary: return {}
var route_provider: Callable = func() -> String: return ""
var active_ms_provider: Callable = func(_case_id) -> int: return 0
var clock: Callable = func() -> String: return Time.get_datetime_string_from_system(true) + "Z"
var enabled := true
var recent: Array = []        ## in-memory tail for tests/debug
var dir := DIR
var write_failures := 0

func _init(build: String, cv: String) -> void:
	build_id = build
	content_version = cv

func track(event_name: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	var state: Dictionary = state_provider.call()
	var case_id = props.get("case_id")
	var run_id = props.get("run_id")
	if case_id != null and run_id == null and state.get("runs", {}).has(case_id):
		run_id = state["runs"][case_id].get("run_id")
	var ev := {
		"event_id": Uuid.v4(),
		"event_name": event_name,
		"schema_version": 1,
		"build_id": build_id,
		"content_version": content_version,
		"session_id": session_id,
		"run_id": run_id,
		"case_id": case_id,
		"timestamp_utc": clock.call(),
		"elapsed_active_ms": active_ms_provider.call(case_id) if case_id != null else 0,
		"interaction_index": int(state.get("interaction_index", 0)),
		"route": route_provider.call(),
	}
	for k in props:
		if k in ["case_id", "run_id"] or FORBIDDEN_KEYS.has(k):
			continue
		ev[k] = props[k]
	recent.append(ev)
	if recent.size() > 200:
		recent.pop_front()
	_append(ev)

## Store listener: committed results carry the events that describe committed state.
func on_committed(_action: Dictionary, result: Dictionary) -> void:
	for e in result.get("events", []):
		track(e["name"], e["props"])

func on_save_failed(action_type: String, error_category: String) -> void:
	track("SAVE_FAILED", {"action_type": action_type, "error_category": error_category})

func _append(ev: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(FILE)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		write_failures += 1
		Log.w(Log.ANALYTICS, "event log unavailable", {"err": FileAccess.get_open_error()})
		return
	f.seek_end()
	f.store_line(JSON.stringify(ev))
	var size := f.get_length()
	f.close()
	if size > budget_bytes:
		_trim(path)

## FIFO: keep the newest events that fit in 80% of the budget.
func _trim(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var keep: Array = []
	var total := 0
	var target := int(budget_bytes * 0.8)
	for i in range(lines.size() - 1, -1, -1):
		total += lines[i].to_utf8_buffer().size() + 1
		if total > target:
			break
		keep.push_front(lines[i])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		write_failures += 1
		return
	f.store_string("\n".join(keep) + ("\n" if not keep.is_empty() else ""))
	f.close()
	Log.i(Log.ANALYTICS, "analytics budget reached, dropped oldest", {"kept": keep.size(), "dropped": lines.size() - keep.size()})

func read_all() -> Array:
	var path := dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		return []
	var out := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var j := JSON.new()
		if j.parse(line) == OK:
			out.append(j.data)
	return out

## Playtest export: one JSON document with build info and all locally stored events.
## Returns {"ok", "path", "json"}.
func export_log() -> Dictionary:
	var doc := {"export_format": "casezero-playtest-log-1", "build_id": build_id, "content_version": content_version,
		"exported_utc": clock.call(), "events": read_all()}
	var json := JSON.stringify(doc, " ")
	var out_dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var path := out_dir.path_join("playtest_log_%s.json" % stamp)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "path": "", "json": json}
	f.store_string(json)
	f.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path), "json": json}
