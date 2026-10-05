class_name Fx
extends RefCounted
## Test fixture: real content, real reducer/store, in-memory storage with fault injection and
## deterministic UUIDs. `kill_and_restart()` models a process kill: everything in memory is
## dropped and a new Store boots from whatever the storage backend holds.

var db: ContentDB
var backend: MemorySaveBackend
var repo: SaveRepository
var store: Store
var route := ""
var events: Array = []          # analytics events emitted after commit, in order
var boot_result: Dictionary = {}
var _n := 0

func _init(shared_backend: MemorySaveBackend = null) -> void:
	db = ContentDB.load_default()
	backend = shared_backend if shared_backend != null else MemorySaveBackend.new()
	_boot()

func _boot() -> void:
	repo = SaveRepository.new(backend)
	store = Store.new(db, repo)
	store.uuid_provider = _uuid
	store.route_provider = func() -> String: return route
	store.committed.connect(func(_a, r): events.append_array(r["events"]))
	boot_result = BootService.boot(db, repo)
	store.set_committed_state(boot_result["state"])

func _uuid() -> String:
	_n += 1
	return "00000000-0000-4000-8000-%012d" % _n

func kill_and_restart() -> Fx:
	var f := Fx.new(backend)
	f._n = _n + 1000
	return f

func state() -> Dictionary:
	return store.state

func run(cid: String) -> Dictionary:
	return store.state["runs"].get(cid, {})

func act(type: String, payload: Dictionary) -> Dictionary:
	var a := store.make_action(type, payload)
	return store.dispatch(a)

func scene(cid: String) -> void:
	route = "%s_SCENE" % cid

func start(cid: String) -> Dictionary:
	route = "%s_INTRO" % cid
	var r := act(CZ.START_CASE, {"case_id": cid, "entry_source": "board"})
	scene(cid)
	return r

func inspect(cid: String, oid: String) -> Dictionary:
	scene(cid)
	return act(CZ.INSPECT_OBJECT, {"case_id": cid, "object_id": oid})

func connect_charger(cid: String, oid: String) -> Dictionary:
	route = db.case_def(cid).object(oid)["inspect_screen"]
	return act(CZ.CONNECT_CHARGER, {"case_id": cid, "object_id": oid})

func stage_route(cid: String, stage_id: String) -> void:
	route = db.case_def(cid).stage(stage_id)["screen"]

func answer(cid: String, stage_id: String, answer_id: Variant) -> Dictionary:
	stage_route(cid, stage_id)
	return act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": stage_id, "answer_id": answer_id})

func select_set(cid: String, stage_id: String, ids: Array) -> Dictionary:
	stage_route(cid, stage_id)
	return act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": stage_id, "evidence_ids": ids})

func place(cid: String, stage_id: String, token: String, slot: int) -> Dictionary:
	stage_route(cid, stage_id)
	return act(CZ.PLACE_TIMELINE_TOKEN, {"case_id": cid, "stage_id": stage_id, "token_id": token, "slot": slot})

func submit_timeline(cid: String, stage_id: String) -> Dictionary:
	stage_route(cid, stage_id)
	return act(CZ.SUBMIT_STAGE, {"case_id": cid, "stage_id": stage_id})

func hint(cid: String, mode: String) -> Dictionary:
	route = "%s_SCENE" % cid if mode == Hints.MODE_OPEN else "%s_HINT" % cid
	return act(CZ.REQUEST_HINT, {"case_id": cid, "mode": mode})

func reset(cid: String) -> Dictionary:
	route = "%s_CONFIRM_RESET" % cid
	return act(CZ.RESET_RUN, {"case_id": cid})

## Canonical C01 happy path up to (and including) the final solve.
func solve_c01() -> Dictionary:
	if run("C01").is_empty() or not run("C01")["started"]:
		start("C01")
	inspect("C01", "C01_WINDOW")
	inspect("C01", "C01_FLOOR")
	answer("C01", "C01_Q1", "C01_Q1_A0")
	inspect("C01", "C01_MANAGER")
	return answer("C01", "C01_Q2", "C01_Q2_A1")

func names() -> Array:
	return events.map(func(e): return e["name"])
