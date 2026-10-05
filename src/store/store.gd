class_name Store
extends RefCounted
## The single entry point for state change (spec Part 10 transaction contract):
##
##   1 action_id already committed?  -> return prior result, execute nothing
##   2-6 Reducer: route / object / input / prerequisite validation, apply on a deep copy
##   7-8 recompute derived (selectors are pure) + validate invariants on the proposed state
##   9  persist the proposed snapshot atomically (journal includes action_id)
##   10 replace live state only after the write succeeded
##   11-12 emit `committed` -> UI feedback, audio, haptics, analytics (listeners never write state)
##
## On a write failure the live state stays at the last committed snapshot, the proposed state is
## kept as `pending` for Retry (same action_id, same proposed state) or Revert, and the UI shows
## G_WRITE_ERROR instead of a success it could not save.

signal committed(action: Dictionary, result: Dictionary)
signal rejected(action: Dictionary, result: Dictionary)
signal write_failed(action: Dictionary, result: Dictionary)
signal save_failed(action_type: String, error_category: String)

const RESULT_CACHE := 256

var db: ContentDB
var repo: SaveRepository
var route_provider: Callable = func() -> String: return ""
var uuid_provider: Callable = func() -> String: return Uuid.v4()

## Last committed state. Read-only for everyone except this class.
var state: Dictionary = {}
var pending: Dictionary = {}   # {"action", "result"} awaiting Retry/Revert

var _results := {}
var _result_order: Array = []
var _dispatching := false

func _init(content: ContentDB, repository: SaveRepository) -> void:
	db = content
	repo = repository

func set_committed_state(s: Dictionary) -> void:
	state = s

func make_action(type: String, payload: Dictionary = {}) -> Dictionary:
	var a := payload.duplicate()
	a["type"] = type
	a["id"] = uuid_provider.call()
	return a

func has_pending() -> bool:
	return not pending.is_empty()

func dispatch(action: Dictionary) -> Dictionary:
	if _dispatching:
		return _simple(CZ.REJECTED, CZ.BUSY)
	if not action.has("id") or str(action["id"]) == "":
		action["id"] = uuid_provider.call()
	var aid := str(action["id"])
	# 1. Idempotency: an action that already committed returns its prior result and does nothing.
	if _results.has(aid):
		return _duplicate_of(_results[aid])
	if state.get("committed_action_ids", []).has(aid):
		return _simple(CZ.DUPLICATE, CZ.ALREADY_DONE)
	# While G_WRITE_ERROR is open nothing else may commit on top of the unsaved proposal.
	if has_pending() and action.get("type") != CZ.CHECKPOINT_ACTIVE_TIME:
		return _simple(CZ.REJECTED, CZ.BUSY)
	_dispatching = true
	var ctx := {"route": action.get("route", route_provider.call()), "new_uuid": uuid_provider}
	var res := Reducer.reduce(state, action, db, ctx)
	if res["status"] == CZ.OK and res["persist"]:
		var next: Dictionary = res["state"]
		var journal: Array = next.get("committed_action_ids", [])
		journal.append(aid)
		while journal.size() > CZ.COMMITTED_ACTION_JOURNAL:
			journal.pop_front()
		next["committed_action_ids"] = journal
		var report := GameState.check(next, db)
		if not GameState.is_valid(report):
			_dispatching = false
			Log.e(Log.STATE, "invariant violation, action refused", {"action": action.get("type"), "report": report})
			var bad := _simple(CZ.REJECTED, CZ.INVARIANT_VIOLATION)
			rejected.emit(action, bad)
			return bad
		var w := repo.commit(next)
		if not w["ok"]:
			_dispatching = false
			res["status"] = CZ.WRITE_FAILED
			res["error_category"] = w["error_category"]
			save_failed.emit(str(action.get("type")), str(w["error_category"]))
			if action.get("type") == CZ.CHECKPOINT_ACTIVE_TIME:
				# Metrics checkpoint: keep playing; the timer re-sends the accumulated time.
				return res
			pending = {"action": action, "result": res}
			Log.e(Log.SAVE, "commit blocked by write failure", {"action": action.get("type")})
			write_failed.emit(action, res)
			return res
		state = next
	_dispatching = false
	_remember(aid, res)
	if res["status"] == CZ.REJECTED:
		Log.d(Log.GAMEPLAY, "action rejected", {"type": action.get("type"), "code": res["code"]})
		rejected.emit(action, res)
	else:
		Log.d(Log.GAMEPLAY, "action %s" % res["status"], {"type": action.get("type"), "code": res["code"]})
		committed.emit(action, res)
	return res

## G_WRITE_ERROR Retry: re-commit the same proposed state under the same action_id.
func retry_pending() -> Dictionary:
	if not has_pending():
		return _simple(CZ.NOOP, CZ.ALREADY_DONE)
	var action: Dictionary = pending["action"]
	var res: Dictionary = pending["result"]
	var w := repo.commit(res["state"])
	if not w["ok"]:
		save_failed.emit(str(action.get("type")), str(w["error_category"]))
		return res
	res["status"] = CZ.OK
	res.erase("error_category")
	state = res["state"]
	pending = {}
	_remember(str(action["id"]), res)
	committed.emit(action, res)
	return res

## G_WRITE_ERROR Revert: drop the unsaved proposal; the live state already is the last committed
## snapshot. Returns false when no committed snapshot exists (spec: "Няма запис. Започни отначало").
func revert_pending() -> bool:
	pending = {}
	return not state.is_empty()

func _remember(aid: String, res: Dictionary) -> void:
	_results[aid] = res
	_result_order.append(aid)
	while _result_order.size() > RESULT_CACHE:
		_results.erase(_result_order.pop_front())

func _duplicate_of(prior: Dictionary) -> Dictionary:
	var d := prior.duplicate()
	d["status"] = CZ.DUPLICATE
	d["prior_status"] = prior["status"]
	d["events"] = []
	d["feedback"] = {"sfx": [], "haptic": CZ.HAPTIC_NONE, "toast": ""}
	return d

func _simple(status: String, code: String) -> Dictionary:
	var r := Reducer.result(status, code, state)
	return r
