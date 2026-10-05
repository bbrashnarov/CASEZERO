class_name Router
extends RefCounted
## Central navigation over the Screen IDs of the spec. A route is
##   {"id": ScreenID, "kind": KIND, "case_id": String, ...params}
## The base route is a full screen (boot, board, settings, end, intro, scene, solved, reward);
## modal routes (inspect, evidence, detail card, hint, pause, confirm, stage, picker, write
## error, recovery) stack on top. Buttons never switch screens themselves: they call the
## navigation helpers below or an action flow.
##
## Route state is runtime-only (spec Part 10: route persisted NO).

signal changed(previous: Dictionary, current: Dictionary)

const BOOT := "BOOT"
const BOARD := "BOARD"
const SETTINGS := "SETTINGS"
const END := "END"
const INTRO := "INTRO"
const SCENE := "SCENE"
const SOLVED := "SOLVED"
const REWARD := "REWARD"
const INSPECT := "INSPECT"
const EVIDENCE := "EVIDENCE"
const DETAIL_CARD := "DETAIL_CARD"
const HINT := "HINT"
const PAUSE := "PAUSE"
const CONFIRM_RESET := "CONFIRM_RESET"
const STAGE := "STAGE"
const PICKER := "PICKER"
const WRITE_ERROR := "WRITE_ERROR"
const RECOVERY := "RECOVERY"

const BASE_KINDS := [BOOT, BOARD, SETTINGS, END, INTRO, SCENE, SOLVED, REWARD]
## Modal kinds during which the run's active timer keeps counting (spec Part 11 Active time:
## investigation, reading, evidence and hints count; pause does not).
const ACTIVE_KINDS := [SCENE, INSPECT, EVIDENCE, DETAIL_CARD, HINT, STAGE, PICKER]

var base: Dictionary = {"id": "G_BOOT", "kind": BOOT, "case_id": ""}
var stack: Array = []

# --- route constructors -----------------------------------------------------------------

static func g(id: String, kind: String) -> Dictionary:
	return {"id": id, "kind": kind, "case_id": ""}

static func boot() -> Dictionary: return g("G_BOOT", BOOT)
static func board() -> Dictionary: return g("G_BOARD", BOARD)
static func settings() -> Dictionary: return g("G_SETTINGS", SETTINGS)
static func end_screen() -> Dictionary: return g("G_END", END)
static func picker(case_id: String, object_ids: Array) -> Dictionary:
	return {"id": "G_PICKER", "kind": PICKER, "case_id": case_id, "object_ids": object_ids}
static func write_error() -> Dictionary: return g("G_WRITE_ERROR", WRITE_ERROR)
static func recovery(info: Dictionary) -> Dictionary:
	var r := g("G_BOOT", RECOVERY)
	r["info"] = info
	return r

static func case_route(case_id: String, kind: String, suffix: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"id": "%s_%s" % [case_id, suffix], "kind": kind, "case_id": case_id}
	r.merge(extra)
	return r

static func intro(case_id: String, entry_source := "board") -> Dictionary:
	return case_route(case_id, INTRO, "INTRO", {"entry_source": entry_source})
static func scene(case_id: String) -> Dictionary: return case_route(case_id, SCENE, "SCENE")
static func evidence(case_id: String) -> Dictionary: return case_route(case_id, EVIDENCE, "EVIDENCE")
static func hint(case_id: String) -> Dictionary: return case_route(case_id, HINT, "HINT")
static func pause(case_id: String) -> Dictionary: return case_route(case_id, PAUSE, "PAUSE")
static func confirm_reset(case_id: String, return_to: String) -> Dictionary:
	return case_route(case_id, CONFIRM_RESET, "CONFIRM_RESET", {"return_to": return_to})
static func detail_card(case_id: String, evidence_id: String) -> Dictionary:
	return case_route(case_id, DETAIL_CARD, "DETAIL_CARD", {"evidence_id": evidence_id})
static func solved(case_id: String, info: Dictionary) -> Dictionary:
	return case_route(case_id, SOLVED, "SOLVED", {"info": info})
static func reward(case_id: String, info: Dictionary) -> Dictionary:
	return case_route(case_id, REWARD, "REWARD", {"info": info})

static func inspect(def: CaseDef, object_id: String, info: Dictionary) -> Dictionary:
	var obj: Dictionary = def.object(object_id)
	return {"id": obj["inspect_screen"], "kind": INSPECT, "case_id": def.id, "object_id": object_id, "info": info}

static func stage(def: CaseDef, stage_id: String) -> Dictionary:
	var s: Dictionary = def.stage(stage_id)
	return {"id": s["screen"], "kind": STAGE, "case_id": def.id, "stage_id": stage_id}

# --- state -------------------------------------------------------------------------------

func current() -> Dictionary:
	return stack.back() if not stack.is_empty() else base

func current_id() -> String:
	return str(current()["id"])

func has_modal() -> bool:
	return not stack.is_empty()

func has_kind(kind: String) -> bool:
	if base["kind"] == kind:
		return true
	for r in stack:
		if r["kind"] == kind:
			return true
	return false

func set_base(route: Dictionary) -> void:
	var prev := current()
	base = route
	stack.clear()
	Log.d(Log.NAV, "base", {"id": route["id"]})
	changed.emit(prev, current())

func push(route: Dictionary) -> void:
	var prev := current()
	stack.append(route)
	Log.d(Log.NAV, "push", {"id": route["id"]})
	changed.emit(prev, current())

func pop() -> void:
	if stack.is_empty():
		return
	var prev := current()
	stack.pop_back()
	Log.d(Log.NAV, "pop", {"to": current()["id"]})
	changed.emit(prev, current())

func replace_top(route: Dictionary) -> void:
	if stack.is_empty():
		set_base(route)
		return
	var prev := current()
	stack[stack.size() - 1] = route
	changed.emit(prev, current())

func pop_to_base() -> void:
	if stack.is_empty():
		return
	var prev := current()
	stack.clear()
	changed.emit(prev, current())

## The run timer counts only while the player is inside an active case screen.
func is_active_time_route() -> bool:
	var c := current()
	return base["kind"] == SCENE and ACTIVE_KINDS.has(c["kind"])
