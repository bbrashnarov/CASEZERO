class_name ContentDB
extends RefCounted
## Loads the content manifest, case definitions and UI text. Pure data; no runtime state.

const MANIFEST_PATH := "res://content/manifest.json"
const UI_TEXT_PATH := "res://content/ui_text.json"

var manifest: Dictionary = {}
var content_version := ""
var case_order: Array = []
var cases := {}            # CaseID -> CaseDef
var assets := {}           # AssetID -> manifest entry
var sound_events := {}     # Sound Event ID -> {asset, haptic, bus, loop}
var text := {}             # merged spec + engineering UI text
var load_errors: Array = []

static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_from(MANIFEST_PATH, UI_TEXT_PATH)
	return db

## Builds a ContentDB from already-parsed dictionaries (tests and tools).
static func from_data(manifest_data: Dictionary, case_data: Array, ui_text_data: Dictionary) -> ContentDB:
	var db := ContentDB.new()
	db._apply(manifest_data, case_data, ui_text_data)
	return db

func load_from(manifest_path: String, ui_text_path: String) -> bool:
	load_errors.clear()
	var m = _read_json(manifest_path)
	if m == null:
		return false
	var case_data := []
	for cid in m.get("cases", []):
		var path: String = m.get("case_files", {}).get(cid, "")
		var c = _read_json(path)
		if c == null:
			return false
		case_data.append(c)
	var t = _read_json(ui_text_path)
	if t == null:
		return false
	_apply(m, case_data, t)
	return load_errors.is_empty()

func _apply(m: Dictionary, case_data: Array, t: Dictionary) -> void:
	manifest = m
	content_version = str(m.get("content_version", ""))
	case_order = m.get("cases", [])
	for a in m.get("assets", []):
		assets[a["id"]] = a
	sound_events = m.get("sound_events", {})
	for c in case_data:
		var def := CaseDef.new(c)
		cases[def.id] = def
	text = {}
	text.merge(t.get("spec", {}))
	text.merge(t.get("engineering", {}))

func case_def(case_id: String) -> CaseDef:
	return cases.get(case_id)

func has_case(case_id: String) -> bool:
	return cases.has(case_id)

func t(key: String) -> String:
	if not text.has(key):
		Log.e(Log.CONTENT, "missing ui text key", {"key": key})
		return "<%s>" % key
	return str(text[key])

func greybox_allowed() -> bool:
	return bool(manifest.get("art_pack", {}).get("greybox_allowed", false))

func _read_json(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		load_errors.append("missing content file: %s" % path)
		return null
	var txt := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(txt) != OK:
		load_errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if not (json.data is Dictionary):
		load_errors.append("%s: root must be an object" % path)
		return null
	return json.data
