class_name CaseScreen
extends Control
## <CASE>_INTRO and <CASE>_SCENE: header (title + objective), the reusable InvestigationView and
## the footer HUD (UI_HINT, UI_EVIDENCE). The intro card sits over the visible scene.
## All intents go through AppContext.perform (state) or the Router (navigation).

var ctx: AppContext
var route: Dictionary
var def: CaseDef
var view: InvestigationView
var header: ScrollContainer
var header_box: VBoxContainer
var _title: Label
var _objective: Label
var footer: HBoxContainer
var hint_button: CzButton
var evidence_button: CzButton
var intro_card: PanelContainer
var _intro_scroll: ScrollContainer
var _intro_text: Label
var _intro_cta: CzButton
var asset_error: Control
var _intro_pulse_until := 0
var _evidence_pulse_until := 0

func setup(context: AppContext, r: Dictionary) -> CaseScreen:
	ctx = context
	route = r
	def = ctx.db.case_def(r["case_id"])
	name = def.scene_id()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ctx.metrics
	var failures := ctx.assets.case_failures(def)
	if not failures.is_empty():
		_build_asset_error(failures)
		return self
	view = InvestigationView.new().setup(ctx, def)
	add_child(view)
	view.object_tapped.connect(inspect_object)
	view.picker_needed.connect(func(ids): ctx.router.push(Router.picker(def.id, ids)))
	# Header: title + objective. At large font scales it is capped and scrolls instead of
	# shrinking text (spec Typography), so the scene keeps a usable share of the screen.
	header = ScrollContainer.new()
	header.name = "Header"
	header.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	header_box = VBoxContainer.new()
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_constant_override("separation", int(m.dp(4)))
	header.add_child(header_box)
	_title = UiStyle.label(m, def.title(), UiStyle.TITLE_SP, UiStyle.PANEL, true)
	_title.name = "Title"
	_objective = UiStyle.label(m, def.objective(), UiStyle.BODY_SP, UiStyle.PANEL)
	_objective.name = "Objective"
	header_box.add_child(_title)
	header_box.add_child(_objective)
	add_child(header)
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(m.dp(24)))
	hint_button = CzButton.new().setup(ctx, "UI_HINT", "? " + ctx.t("hint_button"))
	evidence_button = CzButton.new().setup(ctx, "UI_EVIDENCE", "")
	for b in [hint_button, evidence_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(b)
	hint_button.activated.connect(open_hint)
	evidence_button.activated.connect(open_evidence)
	add_child(footer)
	if r["kind"] == Router.INTRO:
		_build_intro()
	refresh()
	layout()
	return self

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()

const HEADER_MAX_SHARE := 0.28

func layout() -> void:
	if view == null:
		return
	var m := ctx.metrics
	var col := m.column
	var mg := m.margin()
	var w := col.size.x - 2 * mg
	var content_h := UiStyle.text_height(_title, w) + UiStyle.text_height(_objective, w) + m.dp(4)
	var hh := minf(ceil(content_h), maxf(m.touch_min(), m.safe.size.y * HEADER_MAX_SHARE))
	header.position = Vector2(col.position.x + mg, m.safe.position.y + mg)
	header.size = Vector2(w, hh)
	var header_bottom := header.position.y + hh + mg * 0.5
	var bw := (w - footer.get_theme_constant("separation")) * 0.5
	var fh := maxf(hint_button.preferred_height(bw), evidence_button.preferred_height(bw))
	footer.size = Vector2(w, fh)
	footer.position = Vector2(col.position.x + mg, m.safe.end.y - mg - fh)
	var sr := m.scene_rect(header_bottom, footer.position.y - mg * 0.5)
	view.set_viewport_rect(sr["rect"], sr["scale"])
	if intro_card:
		_layout_intro(w)

## Intro card at the bottom over the visible scene: the opening text scrolls when needed, the CTA
## always stays on screen (spec: footer outside scroll at large font).
func _layout_intro(w: float) -> void:
	var m := ctx.metrics
	var mg := m.margin()
	var inner := w - m.dp(24)
	var sep := m.dp(12)
	var pad := m.dp(16)
	var cta_h := _intro_cta.preferred_height(inner)
	var max_h := m.safe.size.y - 2 * mg
	var text_cap := minf(m.dp(240) * m.font_scale, m.safe.size.y * 0.45)
	var text_h := minf(ceil(UiStyle.text_height(_intro_text, inner)), minf(text_cap, max_h - cta_h - sep - pad))
	_intro_scroll.custom_minimum_size = Vector2(0, text_h)
	_intro_cta.custom_minimum_size.y = cta_h
	var h := text_h + sep + cta_h + pad
	intro_card.custom_minimum_size = Vector2(w, h)
	intro_card.size = Vector2(w, h)
	intro_card.position = Vector2(m.column.position.x + mg, m.safe.end.y - mg - h)

func _build_intro() -> void:
	var m := ctx.metrics
	footer.visible = false
	view.interactive = false
	intro_card = PanelContainer.new()
	intro_card.name = "IntroCard"
	intro_card.add_theme_stylebox_override("panel", UiStyle.panel_box(m, UiStyle.PANEL, Color.TRANSPARENT, 12.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(m.dp(12)))
	intro_card.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_intro_scroll = scroll
	var txt := UiStyle.label(m, def.opening_text())
	_intro_text = txt
	txt.name = "OpeningText"
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(txt)
	col.add_child(scroll)
	var start := CzButton.new().setup(ctx, "UI_PRIMARY", ctx.t("intro_cta"))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.activated.connect(start_case)
	_intro_cta = start
	col.add_child(start)
	add_child(intro_card)

func _build_asset_error(failures: Array) -> void:
	# Critical asset failure: fail visibly with Asset ID / Case ID / expected type instead of
	# rendering invisible clickable clues.
	var m := ctx.metrics
	var box := VBoxContainer.new()
	box.position = m.safe.position + Vector2(m.margin(), m.margin())
	box.size = m.safe.size - Vector2(2, 2) * m.margin()
	box.add_child(UiStyle.label(m, ctx.t("asset_error"), UiStyle.TITLE_SP, UiStyle.ERROR, true))
	for f in failures:
		box.add_child(UiStyle.label(m, "Asset ID: %s\nCase ID: %s\nExpected type: %s %s" % [f["asset_id"], f["case_id"], f["expected_type"], f.get("variant", "")], UiStyle.SECONDARY_SP, UiStyle.PANEL))
	var back := CzButton.new().setup(ctx, "UI_PRIMARY", ctx.t("end_cta"))
	back.activated.connect(func(): ctx.router.set_base(Router.board()))
	box.add_child(back)
	asset_error = box
	add_child(box)
	Log.e(Log.ASSET, "critical assets missing; case not started", {"case": def.id, "count": failures.size()})

func refresh() -> void:
	if view == null:
		return
	var run := ctx.run(def.id)
	evidence_button.set_text(ctx.t("evidence_button") % [Selectors.required_found(def, run), Selectors.required_total(def)])
	view.queue_redraw()

# --- intents --------------------------------------------------------------------------------

func start_case() -> void:
	var source := str(route.get("entry_source", "board"))
	ctx.perform(CZ.START_CASE, {"case_id": def.id, "entry_source": source}, func(res):
		if res["status"] in [CZ.OK, CZ.NOOP]:
			ctx.router.set_base(Router.scene(def.id)))

## Called by the shell when this screen becomes the SCENE (first interactive frame).
func on_scene_entered() -> void:
	var p = def.data.get("intro_pulse")
	var run := ctx.run(def.id)
	# The intro pulse belongs to the first look at a fresh run only.
	if p != null and view and run.get("evidence", []).is_empty() and _all_unseen(run):
		var dur := int(p.get("duration_ms", 5000))
		view.pulse(str(p["object_id"]), int(ceil(float(dur) / CZ.AN_HINT_PULSE_MS)), CZ.AN_HINT_PULSE_MS)
		_intro_pulse_until = Time.get_ticks_msec() + dur

func _all_unseen(run: Dictionary) -> bool:
	for oid in run.get("objects", {}):
		if run["objects"][oid]["inspection"] != CZ.UNSEEN:
			return false
	return true

func inspect_object(object_id: String) -> void:
	if ctx.input_locked() or ctx.router.has_modal():
		return
	ctx.ui_tap()
	# The first accepted scene tap stops the intro pulse; it never blocks exploration.
	var p = def.data.get("intro_pulse")
	if p != null:
		view.stop_pulse(str(p["object_id"]))
	ctx.perform(CZ.INSPECT_OBJECT, {"case_id": def.id, "object_id": object_id}, _on_inspected.bind(object_id))

func _on_inspected(res: Dictionary, object_id: String) -> void:
	match res["status"]:
		CZ.NOOP:
			if res["code"] == CZ.GATE_LOCKED:
				ctx.toast(str(res["data"]["locked_text"]), CZ.LOCKED_FEEDBACK_MS, "locked")
		CZ.OK:
			var info: Dictionary = res["data"].duplicate()
			info["toast"] = res["feedback"]["toast"]
			ctx.router.push(Router.inspect(def, object_id, info))

func open_hint() -> void:
	if ctx.router.has_modal():
		return
	ctx.perform(CZ.REQUEST_HINT, {"case_id": def.id, "mode": Hints.MODE_OPEN}, func(res):
		if res["status"] in [CZ.OK, CZ.NOOP]:
			ctx.router.push(Router.hint(def.id)))

func open_evidence() -> void:
	if ctx.router.has_modal():
		return
	ctx.router.push(Router.evidence(def.id))

## Hint target pulse after the hint panel closes (the panel covers the scene while open).
func pulse_target(target: String) -> void:
	if view == null:
		return
	if target == Selectors.UI_EVIDENCE:
		_pulse_button(evidence_button)
	elif target.begins_with("CONNECT:"):
		view.flash_connect(target.substr(8))
	else:
		view.pulse(target)

func _pulse_button(b: CzButton) -> void:
	if ctx.reduced_motion():
		b.set_selected(true)
		var hold := b.create_tween()
		hold.tween_interval(CZ.AN_HINT_PULSE_MS * CZ.AN_HINT_PULSE_COUNT / 1000.0)
		hold.tween_callback(b.set_selected.bind(false))
		return
	var tw := create_tween()
	for i in CZ.AN_HINT_PULSE_COUNT:
		tw.tween_callback(func(): b.set_selected(true))
		tw.tween_interval(CZ.AN_HINT_PULSE_MS / 2000.0)
		tw.tween_callback(func(): b.set_selected(false))
		tw.tween_interval(CZ.AN_HINT_PULSE_MS / 2000.0)
