class_name AppContext
extends RefCounted
## Composition wiring shared by UI components. Holds service references and the two
## cross-cutting UI rules: action continuation across G_WRITE_ERROR, and input locking.
## It owns no gameplay rules.

signal toast_requested(text: String, duration_ms: int, kind: String)
signal pulse_requested(target_id: String)
signal settings_changed()
signal metrics_changed()

var db: ContentDB
var store: Store
var router: Router
var platform: PlatformService
var assets: AssetRegistry
var audio: AudioService
var haptics: HapticsService
var analytics: AnalyticsService
var metrics: LayoutMetrics
var last_write_ok := true
var write_count := 0

var _continuation: Callable
var _locked_until_ms := 0
var _lock_holds := 0

func t(key: String) -> String:
	return db.t(key)

func state() -> Dictionary:
	return store.state

func run(case_id: String) -> Dictionary:
	return Selectors.run_of(store.state, case_id)

## Dispatches a semantic action. `on_done` runs only for a committed/accepted outcome; when the
## write fails it is parked until G_WRITE_ERROR Retry succeeds, so no screen ever shows a
## success the save did not confirm.
func perform(type: String, payload: Dictionary, on_done: Callable = Callable()) -> Dictionary:
	var action := store.make_action(type, payload)
	var res := store.dispatch(action)
	if res["status"] == CZ.WRITE_FAILED:
		last_write_ok = false
		if type != CZ.CHECKPOINT_ACTIVE_TIME:
			_continuation = on_done
			router.push(Router.write_error())
		return res
	if res.get("persist", false) and res["status"] == CZ.OK:
		last_write_ok = true
		write_count += 1
	if on_done.is_valid():
		on_done.call(res)
	return res

func retry_write() -> bool:
	var res := store.retry_pending()
	if res["status"] != CZ.OK:
		return false
	last_write_ok = true
	write_count += 1
	_close_write_error()
	var cont := _continuation
	_continuation = Callable()
	if cont.is_valid():
		cont.call(res)
	return true

## Revert -> last committed SCENE/BOARD (spec G_WRITE_ERROR).
func revert_write() -> void:
	store.revert_pending()
	_continuation = Callable()
	_close_write_error()
	var base := router.base
	var cid := str(base.get("case_id", ""))
	if cid != "" and run(cid).get("started", false) and not run(cid).get("solved", false):
		router.set_base(Router.scene(cid))
	elif base["kind"] in [Router.BOARD, Router.SETTINGS, Router.END]:
		router.pop_to_base()
	else:
		router.set_base(Router.board())

func _close_write_error() -> void:
	if router.current()["kind"] == Router.WRITE_ERROR:
		router.pop()

# --- input locking (modal transitions, atomic writes, solve) ---------------------------

func lock_input_for(ms: int) -> void:
	_locked_until_ms = maxi(_locked_until_ms, Time.get_ticks_msec() + ms)

func hold_input() -> void:
	_lock_holds += 1

func release_input() -> void:
	_lock_holds = maxi(0, _lock_holds - 1)

func input_locked() -> bool:
	return _lock_holds > 0 or Time.get_ticks_msec() < _locked_until_ms

func ui_tap() -> void:
	audio.play("SFX_UI_TAP")

func reduced_motion() -> bool:
	return bool(store.state.get("settings", {}).get("reduced_motion", false))

## Decorative animation length; informational state changes happen immediately regardless.
func anim_ms(ms: int) -> int:
	return 0 if reduced_motion() else ms

func toast(text: String, duration_ms: int, kind := "info") -> void:
	toast_requested.emit(text, duration_ms, kind)
