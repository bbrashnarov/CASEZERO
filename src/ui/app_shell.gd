class_name AppShell
extends Control
## Reusable UI shell: renders the Router state (base screen + modal stack) and owns the
## cross-screen UI behaviour: modal close animation, Android Back contract, toasts, ambience.
## It renders state; it never decides gameplay.

var ctx: AppContext
var screen_layer: Control
var modal_layer: Control
var toast_layer: Control
var debug_layer: Control
var base_node: Control
var _base_route: Dictionary = {}
var _modals: Array = []        # [{route, node}]
var _toast_seq := 0
var _closing := false

func setup(context: AppContext) -> AppShell:
	ctx = context
	name = "AppShell"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in ["ScreenLayer", "ModalLayer", "ToastLayer", "DebugLayer"]:
		var c := Control.new()
		c.name = n
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	screen_layer = $ScreenLayer
	modal_layer = $ModalLayer
	toast_layer = $ToastLayer
	debug_layer = $DebugLayer
	ctx.router.changed.connect(func(_p, _c): sync())
	ctx.store.committed.connect(func(_a, _r): refresh_all())
	ctx.toast_requested.connect(show_toast)
	ctx.pulse_requested.connect(_on_pulse)
	return self

# --- router sync ------------------------------------------------------------------------

func sync() -> void:
	var router := ctx.router
	if base_node == null or not is_instance_valid(base_node) or _base_route != router.base:
		_replace_base(router.base)
	# Remove modals that are no longer on the stack (from the top down).
	var keep := 0
	while keep < _modals.size() and keep < router.stack.size() and _modals[keep]["route"] == router.stack[keep]:
		keep += 1
	var popped_kinds := []
	while _modals.size() > keep:
		var m: Dictionary = _modals.pop_back()
		popped_kinds.append(m["route"]["kind"])
		if is_instance_valid(m["node"]):
			m["node"].queue_free()
	for i in range(keep, router.stack.size()):
		var node := _make_modal(router.stack[i])
		if node:
			modal_layer.add_child(node)
			_modals.append({"route": router.stack[i], "node": node})
			_on_modal_opened(router.stack[i], node)
	if popped_kinds.has(Router.HINT) and base_node is CaseScreen and not router.has_modal():
		var def := ctx.db.case_def(router.base["case_id"])
		(base_node as CaseScreen).pulse_target(Selectors.hint_target(def, ctx.run(def.id), ctx.state()["campaign"]))
	_update_ambience()
	refresh_all()

func _replace_base(route: Dictionary) -> void:
	var prev_case := str(_base_route.get("case_id", ""))
	if base_node and is_instance_valid(base_node):
		base_node.queue_free()
	_base_route = route
	base_node = _make_screen(route)
	screen_layer.add_child(base_node)
	if prev_case != "" and prev_case != str(route.get("case_id", "")):
		ctx.assets.release_case(prev_case)
	if route["kind"] == Router.SCENE and base_node is CaseScreen:
		(base_node as CaseScreen).on_scene_entered()

func _make_screen(r: Dictionary) -> Control:
	match r["kind"]:
		Router.BOARD:
			return BoardScreen.new().setup(ctx, r)
		Router.SETTINGS:
			return SettingsScreen.new().setup(ctx, r)
		Router.INTRO, Router.SCENE:
			return CaseScreen.new().setup(ctx, r)
		Router.SOLVED:
			return SolvedScreen.new().setup(ctx, r)
		Router.REWARD:
			return RewardScreen.new().setup(ctx, r)
		Router.END:
			return EndScreen.new().setup(ctx, r)
	return BootScreen.new().setup(ctx, r)

func _make_modal(r: Dictionary) -> Control:
	var node: ModalBase
	match r["kind"]:
		Router.INSPECT:
			node = InspectModal.new().setup(ctx, r)
		Router.EVIDENCE:
			node = EvidenceModal.new().setup(ctx, r)
		Router.DETAIL_CARD:
			node = DetailCardModal.new().setup(ctx, r)
		Router.HINT:
			node = HintModal.new().setup(ctx, r)
		Router.STAGE:
			node = StageModal.new().setup(ctx, r)
		Router.PAUSE:
			var p := PauseModal.new().setup(ctx, r)
			p.board_requested.connect(func(): CaseFlow.exit_to_board(ctx, str(r["case_id"])))
			node = p
		Router.CONFIRM_RESET:
			node = ConfirmResetModal.new().setup(ctx, r)
		Router.PICKER:
			var pk := PickerModal.new().setup(ctx, r)
			pk.picked.connect(func(oid):
				ctx.router.pop()
				if base_node is CaseScreen:
					(base_node as CaseScreen).inspect_object(oid))
			node = pk
		Router.WRITE_ERROR:
			node = WriteErrorModal.new().setup(ctx, r)
		Router.RECOVERY:
			node = RecoveryModal.new().setup(ctx, r)
	if node:
		node.close_requested.connect(close_top)
	return node

func _on_modal_opened(r: Dictionary, _node: Control) -> void:
	if r["kind"] == Router.INSPECT:
		var t := str(r.get("info", {}).get("toast", ""))
		if t != "":
			# Evidence toast from t=180 ms for 700 ms; cancelled if the panel closes first.
			var seq := _toast_seq + 1
			_toast_seq = seq
			var delay := CZ.CLUE_TOAST_DELAY_MS / 1000.0
			get_tree().create_timer(delay).timeout.connect(func():
				if _toast_seq == seq and ctx.router.current() == r:
					show_toast(t, CZ.AN_CLUE_TOAST_MS, "clue", r))

func refresh_all() -> void:
	if base_node and is_instance_valid(base_node) and base_node.has_method("refresh"):
		base_node.refresh()
	for m in _modals:
		if is_instance_valid(m["node"]):
			m["node"].refresh()

## Closes the top modal with the 120 ms fade; no click-through until it completes.
func close_top() -> void:
	if _closing or not ctx.router.has_modal():
		return
	var top: Dictionary = _modals.back() if not _modals.is_empty() else {}
	var ms := ctx.anim_ms(CZ.AN_MODAL_OUT_MS)
	_toast_seq += 1
	_cancel_route_toasts()
	if ms <= 0 or top.is_empty() or not is_instance_valid(top["node"]):
		ctx.router.pop()
		return
	_closing = true
	ctx.lock_input_for(ms)
	var tw := create_tween()
	tw.tween_property(top["node"], "modulate:a", 0.0, ms / 1000.0)
	tw.tween_callback(func():
		_closing = false
		if ctx.router.has_modal() and ctx.router.current() == top["route"]:
			ctx.router.pop())

# --- Android Back contract (spec Part 4) ------------------------------------------------

## Returns false when the system should handle Back (BOARD/BOOT -> leave the app).
func handle_back() -> bool:
	if ctx.input_locked() and not ctx.router.current()["kind"] in [Router.WRITE_ERROR]:
		return true
	var r := ctx.router
	var top := r.current()
	match top["kind"]:
		Router.INSPECT, Router.EVIDENCE, Router.DETAIL_CARD, Router.HINT, Router.STAGE, Router.PICKER:
			close_top()        # previous route; Back never submits a deduction or loses findings
		Router.PAUSE:
			r.pop()            # resume
		Router.CONFIRM_RESET:
			r.pop()            # same as "Не"
		Router.WRITE_ERROR:
			ctx.revert_write() # never lands on an uncommitted success screen
		Router.RECOVERY:
			pass
		Router.SCENE:
			r.push(Router.pause(str(top["case_id"])))
		Router.INTRO, Router.SOLVED, Router.REWARD, Router.SETTINGS, Router.END:
			r.set_base(Router.board())   # reward was already committed with the solve
		_:
			return false
	return true

# --- toasts --------------------------------------------------------------------------------

func show_toast(text: String, duration_ms: int, kind := "info", for_route: Dictionary = {}) -> void:
	var m := ctx.metrics
	var p := PanelContainer.new()
	p.name = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UiStyle.TEXT
	if kind == "clue":
		fill = UiStyle.SUCCESS
	elif kind == "error":
		fill = UiStyle.ERROR
	p.add_theme_stylebox_override("panel", UiStyle.panel_box(m, fill, Color.TRANSPARENT, 10.0))
	var l := UiStyle.label(m, text, UiStyle.BODY_SP, UiStyle.PANEL, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	var w := minf(m.column.size.x - 2 * m.margin(), m.dp(280))
	var h := UiStyle.text_height(l, w - m.dp(24)) + m.dp(16)
	l.custom_minimum_size = Vector2(w - m.dp(24), 0)
	p.custom_minimum_size = Vector2(w, h)
	toast_layer.add_child(p)
	p.size = Vector2(w, h)
	p.position = Vector2(m.column.position.x + (m.column.size.x - w) * 0.5, m.safe.end.y - m.margin() - m.touch_min() * 2.5 - h)
	p.set_meta("route", for_route)
	if kind == "clue" and not ctx.reduced_motion():
		p.pivot_offset = Vector2(w, h) * 0.5
		p.scale = Vector2(0.96, 0.96)
		create_tween().tween_property(p, "scale", Vector2.ONE, CZ.AN_CLUE_SNAP_MS / 1000.0)
	# A tween bound to the toast dies with it (cancelled toasts leave no dangling callback).
	var tw := p.create_tween()
	tw.tween_interval(duration_ms / 1000.0)
	tw.tween_callback(p.queue_free)

func _cancel_route_toasts() -> void:
	for c in toast_layer.get_children():
		if not (c.get_meta("route", {}) as Dictionary).is_empty():
			c.queue_free()

func toasts() -> Array:
	return toast_layer.get_children().filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return (c.get_child(0) as Label).text)

func _on_pulse(target: String) -> void:
	if base_node is CaseScreen:
		(base_node as CaseScreen).pulse_target(target)

func _update_ambience() -> void:
	var base := ctx.router.base
	var top := ctx.router.current()
	if base["kind"] == Router.SCENE and top["kind"] != Router.PAUSE:
		var def := ctx.db.case_def(base["case_id"])
		var amb = def.data.get("ambience")
		if amb != null:
			ctx.audio.start_ambience(str(amb))
			return
	ctx.audio.stop_ambience()

func relayout() -> void:
	# Metrics changed (rotation is locked, but window/insets/font scale can change): rebuild.
	_base_route = {}
	for m in _modals:
		if is_instance_valid(m["node"]):
			m["node"].queue_free()
	_modals.clear()
	sync()
