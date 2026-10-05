class_name App
extends Control
## Composition root (SCN_BOOT). Builds the services once, validates content (fail fast), restores
## the save through BootService and hands rendering to AppShell. It also owns the three
## process-level concerns no screen should: active-time accounting, Android lifecycle and the
## system Back request.

signal booted(result: Dictionary)

var ctx: AppContext
var shell: AppShell
var debug_overlay: DebugOverlay
var boot_result: Dictionary = {}
## Tests inject a backend (memory) or a save root; production uses user://save.
var backend_override: SaveBackend = null
var platform_override := {}
var analytics_dir_override := ""

var _active_accum_ms := 0
var _last_tick_ms := 0
var _foreground := true
var _content_errors: Array = []

func _ready() -> void:
	name = "App"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	start()

func start() -> void:
	var t0 := Time.get_ticks_msec()
	var db := ContentDB.load_default()
	_content_errors = db.load_errors.duplicate()
	if _content_errors.is_empty():
		_content_errors = ContentValidator.validate(db)
	if _content_errors.is_empty():
		_content_errors = Solvability.check(db)
	_build_context(db)
	# Dev builds log everything; playtest/release keep WARN and above.
	Log.configure(ctx.platform.is_dev)
	_apply_metrics()
	shell = AppShell.new().setup(ctx)
	add_child(shell)
	if not _content_errors.is_empty():
		# Content is a release blocker; never start a case from a broken manifest.
		for e in _content_errors:
			Log.e(Log.CONTENT, "content invalid", {"error": str(e)})
		shell.sync()
		_boot_screen_error("content: %d error(s)" % _content_errors.size())
		return
	shell.sync()
	_boot(t0)
	# Debug overlay: dev builds only (never playtest or release).
	if ctx.platform.is_dev:
		debug_overlay = DebugOverlay.new().setup(ctx, self)
		shell.debug_layer.add_child(debug_overlay)

func _build_context(db: ContentDB) -> void:
	ctx = AppContext.new()
	ctx.db = db
	ctx.platform = PlatformService.new()
	ctx.platform.override = platform_override
	var backend: SaveBackend = backend_override if backend_override else FileSaveBackend.new()
	var repo := SaveRepository.new(backend)
	ctx.store = Store.new(db, repo)
	ctx.router = Router.new()
	ctx.store.route_provider = func() -> String: return ctx.router.current_id()
	ctx.assets = AssetRegistry.new(db)
	UiStyle.load_fonts(ctx.assets)
	ctx.audio = AudioService.new()
	ctx.audio.name = "Audio"
	add_child(ctx.audio)
	ctx.audio.setup(db, ctx.assets)
	ctx.audio.enabled_provider = func() -> bool: return bool(ctx.state().get("settings", {}).get("sound", true))
	ctx.haptics = HapticsService.new(ctx.platform)
	ctx.haptics.enabled_provider = func() -> bool: return bool(ctx.state().get("settings", {}).get("haptic", true))
	ctx.analytics = AnalyticsService.new(ctx.platform.build_id(), db.content_version)
	if analytics_dir_override != "":
		ctx.analytics.dir = analytics_dir_override
	ctx.analytics.state_provider = func() -> Dictionary: return ctx.state()
	ctx.analytics.route_provider = func() -> String: return ctx.router.current_id()
	ctx.analytics.active_ms_provider = func(case_id) -> int: return active_ms(str(case_id))
	ctx.store.committed.connect(_on_committed)
	ctx.store.save_failed.connect(ctx.analytics.on_save_failed)
	ctx.router.changed.connect(_on_route_changed)
	ctx.settings_changed.connect(func(): ctx.audio.refresh_settings())

func _apply_metrics() -> void:
	ctx.metrics = LayoutMetrics.compute(get_viewport_rect().size, ctx.platform)
	theme = UiStyle.build_theme(ctx.metrics)

## Re-reads safe area / density / font scale (window resize, resume after a font change).
func refresh_metrics() -> void:
	var old := ctx.metrics
	_apply_metrics()
	var m := ctx.metrics
	if old == null or old.size != m.size or old.safe != m.safe or old.unit != m.unit or old.font_scale != m.font_scale:
		ctx.metrics_changed.emit()
		shell.relayout()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if ctx and shell:
				refresh_metrics()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if back():
				return
			_quit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			on_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			on_foreground()

## Android Back entry (also used by UI tests). Returns false when the app should close.
func back() -> bool:
	return shell != null and shell.handle_back()

func _quit() -> void:
	flush_active_time()
	get_tree().quit()

# --- boot ---------------------------------------------------------------------------------

func _boot(t0: int) -> void:
	var r := BootService.boot(ctx.db, ctx.store.repo)
	boot_result = r
	match r["status"]:
		BootService.FRESH, BootService.OK:
			_finish_boot(r, t0)
		BootService.RECOVERY:
			if not r["state"].is_empty():
				ctx.store.set_committed_state(r["state"])
			var modal := Router.recovery(r["recovery"])
			ctx.router.push(modal)
			var node := shell._modals.back()["node"] as RecoveryModal
			node.resolved.connect(func(kind): _resolve_recovery(kind, t0))
		_:
			_boot_screen_error(str(r["recovery"].get("detail", "")))
	booted.emit(r)

func _resolve_recovery(kind: String, t0: int) -> void:
	var cases: Array = boot_result.get("recovery", {}).get("cases", [])
	var r := BootService.apply_recovery(ctx.db, ctx.store.repo, kind, boot_result.get("state", {}), cases)
	ctx.router.pop_to_base()
	if r["status"] != BootService.OK:
		_boot_screen_error(str(r["recovery"].get("detail", "")))
		return
	boot_result = r
	_finish_boot(r, t0)

func _finish_boot(r: Dictionary, t0: int) -> void:
	ctx.store.set_committed_state(r["state"])
	_last_tick_ms = Time.get_ticks_msec()
	var route := str(r["route"])
	if route.ends_with("_INTRO"):
		ctx.router.set_base(Router.intro(route.trim_suffix("_INTRO"), "first_launch"))
	else:
		ctx.router.set_base(Router.board())
	ctx.analytics.track("APP_STARTED", {"fresh_install": r["fresh_install"], "save_recovered": r["save_recovered"]})
	Log.i(Log.BOOT, "boot finished", {"route": ctx.router.current_id(), "ms": Time.get_ticks_msec() - t0})

func _boot_screen_error(detail: String) -> void:
	if shell.base_node is BootScreen:
		var bs := shell.base_node as BootScreen
		bs.show_error(detail)
		if not bs.retry_requested.is_connected(_retry_boot):
			bs.retry_requested.connect(_retry_boot)

func _retry_boot() -> void:
	for c in get_children():
		c.queue_free()
	ctx = null
	shell = null
	debug_overlay = null
	await get_tree().process_frame
	start()

# --- feedback and analytics bridge --------------------------------------------------------

## Committed results only: sounds, haptics and analytics describe what the save already holds.
func _on_committed(_action: Dictionary, res: Dictionary) -> void:
	var fb: Dictionary = res.get("feedback", {})
	for s in fb.get("sfx", []):
		ctx.audio.play(str(s))
	var level := str(fb.get("haptic", CZ.HAPTIC_NONE))
	if level == CZ.HAPTIC_NONE:
		for s in fb.get("sfx", []):
			var se = ctx.db.sound_events.get(str(s))
			if se != null and str(se.get("haptic", "NONE")) != "NONE":
				level = str(se["haptic"])
	ctx.haptics.play(level)
	ctx.analytics.on_committed(_action, res)

## Route-entry analytics (EVIDENCE_OPENED, DEDUCTION_OPENED, REWARD_VIEWED).
func _on_route_changed(prev: Dictionary, cur: Dictionary) -> void:
	_tick_active()
	if prev == cur:
		return
	Log.d(Log.NAV, "route", {"from": str(prev.get("id", "")), "to": str(cur.get("id", ""))})
	var cid := str(cur.get("case_id", ""))
	match cur["kind"]:
		Router.EVIDENCE:
			var def := ctx.db.case_def(cid)
			ctx.analytics.track("EVIDENCE_OPENED", {"case_id": cid, "required_found": Selectors.required_found(def, ctx.run(cid)),
				"required_total": Selectors.required_total(def)})
		Router.STAGE:
			var st = ctx.db.case_def(cid).stage(str(cur["stage_id"]))
			ctx.analytics.track("DEDUCTION_OPENED", {"case_id": cid, "stage_id": st["id"],
				"prerequisite_ids": st.get("required_evidence", [])})
		Router.REWARD:
			ctx.analytics.track("REWARD_VIEWED", {"case_id": cid, "xp_delta": int(cur.get("info", {}).get("xp_delta", 0)),
				"campaign_xp": int(ctx.state().get("campaign", {}).get("xp", 0))})

# --- active time (spec Part 10/11: excludes background and pause) -------------------------

func _process(_dt: float) -> void:
	_tick_active()
	if _active_accum_ms >= CZ.ACTIVE_TIME_CHECKPOINT_MS:
		flush_active_time()

func _active_case() -> String:
	if ctx == null or not _foreground or not ctx.router.is_active_time_route():
		return ""
	var cid := str(ctx.router.base.get("case_id", ""))
	var run := ctx.run(cid)
	if run.is_empty() or not run.get("started", false) or run.get("solved", false):
		return ""
	return cid

var _accum_case := ""

func _tick_active() -> void:
	var now := Time.get_ticks_msec()
	var cid := _active_case()
	if _last_tick_ms > 0 and cid != "":
		if _accum_case != "" and _accum_case != cid:
			flush_active_time()
		_accum_case = cid
		_active_accum_ms += now - _last_tick_ms
	_last_tick_ms = now

## Unflushed active time is included so analytics see a monotonic value.
func active_ms(case_id: String) -> int:
	var base := int(ctx.run(case_id).get("active_ms", 0)) if ctx else 0
	return base + (_active_accum_ms if case_id == _accum_case else 0)

func flush_active_time() -> void:
	if ctx == null or _accum_case == "" or _active_accum_ms <= 0 or ctx.store.has_pending():
		return
	var add := _active_accum_ms
	var cid := _accum_case
	_active_accum_ms = 0
	ctx.perform(CZ.CHECKPOINT_ACTIVE_TIME, {"case_id": cid, "add_ms": add})

func on_background() -> void:
	if not _foreground:
		return
	_tick_active()
	_foreground = false
	flush_active_time()
	if ctx:
		ctx.audio.on_background()

func on_foreground() -> void:
	if _foreground:
		return
	_foreground = true
	_last_tick_ms = Time.get_ticks_msec()
	if ctx:
		ctx.audio.on_foreground()
		refresh_metrics()
