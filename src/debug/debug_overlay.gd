class_name DebugOverlay
extends Control
## Dev/playtest-only overlay (never instantiated in release: App checks PlatformService flags).
## Shows route, run state, recent sounds/haptics and save health; dev builds additionally get
## QA toggles (hitbox outlines, simulated write failure, font scale / insets override).
## It reads state and calls the same public intents as the UI; it never writes GameState itself.

var ctx: AppContext
var app: App
var _toggle: Button
var _panel: PanelContainer
var _info: Label
var _hitboxes := false

func setup(context: AppContext, owner_app: App) -> DebugOverlay:
	ctx = context
	app = owner_app
	name = "DebugOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ctx.metrics
	_toggle = Button.new()
	_toggle.name = "DebugToggle"
	_toggle.text = "DBG"
	_toggle.flat = false
	_toggle.add_theme_font_size_override("font_size", int(m.dp(10)))
	_toggle.modulate.a = 0.45
	_toggle.size = Vector2(m.dp(40), m.dp(24))
	_toggle.position = Vector2(m.safe.end.x - m.dp(44), m.safe.position.y + m.dp(2))
	_toggle.pressed.connect(func(): _panel.visible = not _panel.visible; _update())
	add_child(_toggle)
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UiStyle.panel_box(m, Color(0, 0, 0, 0.82), Color.TRANSPARENT, 6.0))
	_panel.position = Vector2(m.safe.position.x + m.dp(4), m.safe.position.y + m.dp(28))
	_panel.custom_minimum_size = Vector2(m.safe.size.x - m.dp(8), 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	_panel.add_child(col)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", int(m.dp(10)))
	_info.add_theme_color_override("font_color", Color(0.75, 1, 0.75))
	col.add_child(_info)
	var row := HFlowContainer.new()
	col.add_child(row)
	_add_btn(row, "Hitboxes", func(): _hitboxes = not _hitboxes; _apply_hitboxes())
	if ctx.platform.is_dev:
		_add_btn(row, "Fail next write", func(): ctx.store.repo.debug_fail_next = 1)
		_add_btn(row, "Font 1.0/1.5/2.0", _cycle_font)
		_add_btn(row, "Insets", _toggle_insets)
		_add_btn(row, "Log state", func(): Log.i(Log.STATE, "state", {"state": JSON.stringify(ctx.state())}))
	_add_btn(row, "Export log", func(): var r := ctx.analytics.export_log(); ctx.toast(ctx.t("export_log") + (" ✓" if r["ok"] else " ✕"), 1500))
	ctx.router.changed.connect(func(_a, _b): _apply_hitboxes(); _update())
	ctx.store.committed.connect(func(_a, _r): _update())
	return self

func _add_btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", int(ctx.metrics.dp(11)))
	b.custom_minimum_size = Vector2(0, ctx.metrics.dp(32))
	b.pressed.connect(cb)
	parent.add_child(b)

func _apply_hitboxes() -> void:
	if app.shell.base_node is CaseScreen:
		var cs := app.shell.base_node as CaseScreen
		if cs.view:
			cs.view.debug_hitboxes = _hitboxes
			cs.view.queue_redraw()

func _cycle_font() -> void:
	var cur := float(app.platform_override.get("font_scale", 1.0))
	var nxt := 1.5 if cur < 1.5 else (2.0 if cur < 2.0 else 1.0)
	app.platform_override["font_scale"] = nxt
	ctx.platform.override = app.platform_override
	app.refresh_metrics()

func _toggle_insets() -> void:
	if app.platform_override.has("insets_dp"):
		app.platform_override.erase("insets_dp")
	else:
		app.platform_override["insets_dp"] = [0, 32, 0, 24]   # status bar + gesture nav emulation
	ctx.platform.override = app.platform_override
	app.refresh_metrics()

func _process(_dt: float) -> void:
	if _panel and _panel.visible and Engine.get_process_frames() % 15 == 0:
		_update()

func _update() -> void:
	if _info == null or not _panel.visible:
		return
	var s := ctx.state()
	var lines := [
		"build %s | content %s | fps %d" % [ctx.platform.build_id(), ctx.db.content_version, Engine.get_frames_per_second()],
		"route %s | stack %d | locked %s" % [ctx.router.current_id(), ctx.router.stack.size(), ctx.input_locked()],
		"xp %s | completed %s" % [s.get("campaign", {}).get("xp"), JSON.stringify(s.get("campaign", {}).get("completed", {}))],
		"writes ok %d | last ok %s | pending %s" % [ctx.write_count, ctx.last_write_ok, ctx.store.has_pending()],
		"metrics unit %.2f font %.2f safe %s" % [ctx.metrics.unit, ctx.metrics.font_scale, str(ctx.metrics.safe)],
		"sfx %s | haptics %s" % [str(ctx.audio.played.slice(-4)), str(ctx.haptics.played.slice(-3))],
	]
	var cid := str(ctx.router.base.get("case_id", ""))
	var run := ctx.run(cid)
	if not run.is_empty():
		lines.append("%s run %s | ev %s | q %s | hint %s | att %s | active %dms" % [cid, str(run["run_id"]).substr(0, 8),
			str(run["evidence"]), JSON.stringify(run.get("questions", {})), run["hint_level"], run.get("attempts", 0), app.active_ms(cid)])
	_info.text = "\n".join(lines)
