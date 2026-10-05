class_name ModalBase
extends Control
## Reusable modal surface (spec wireframe: surface, UI_CLOSE, scrollable body, fixed footer CTA).
## The footer sits outside the scroll area, so the primary CTA never leaves the viewport even at
## font scale 2.0. Scene objects stay visible behind the scrim but receive no input.

signal close_requested()

var ctx: AppContext
var route: Dictionary
var closable := true
var tall := false
var surface: PanelContainer
var title_label: Label
var close_button: CzButton
var scroll: ScrollContainer
var body: VBoxContainer
var footer: VBoxContainer
var _scrim: ColorRect
var _scrim_gesture := TapGesture.new()
var _layout_queued := false

func init_modal(context: AppContext, r: Dictionary) -> void:
	ctx = context
	route = r
	name = str(r["id"]).replace("(", "_").replace(")", "")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## Subclasses call build() from their own setup after setting title/flags.
func build(title: String) -> void:
	var m := ctx.metrics
	_scrim = ColorRect.new()
	_scrim.color = UiStyle.SCRIM
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim_gesture.unit = m.unit
	_scrim_gesture.tapped.connect(func(_p): _on_backdrop())
	_scrim.gui_input.connect(func(e): _scrim_gesture.feed(e))
	add_child(_scrim)
	surface = PanelContainer.new()
	surface.name = "Surface"
	surface.add_theme_stylebox_override("panel", UiStyle.panel_box(m, UiStyle.PANEL, Color.TRANSPARENT, 12.0))
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(surface)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(m.dp(8)))
	surface.add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	title_label = UiStyle.label(m, title, UiStyle.TITLE_SP, UiStyle.TEXT, true)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_label)
	close_button = CzButton.new().setup(ctx, "UI_CLOSE", "✕")
	close_button.custom_minimum_size = Vector2(m.touch_min(), m.touch_min())
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if "accessibility_name" in close_button:
		close_button.set("accessibility_name", ctx.t("close"))
	close_button.activated.connect(func(): request_close())
	close_button.visible = closable
	header.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.name = "Body"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(m.dp(12)))
	scroll.add_child(body)
	footer = VBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", int(m.dp(8)))
	col.add_child(footer)
	body.minimum_size_changed.connect(_queue_layout)
	footer.minimum_size_changed.connect(_queue_layout)
	layout()
	_animate_in()

func layout() -> void:
	if surface == null:
		return
	var r := ctx.metrics.modal_rect(tall)
	if not tall:
		# Grow with the content (detail text, CTA) up to the safe height; the body scrolls beyond.
		var col := surface.get_child(0) as VBoxContainer
		var sep := col.get_theme_constant("separation")
		var need: float = surface.get_theme_stylebox("panel").get_minimum_size().y \
			+ col.get_child(0).get_combined_minimum_size().y + body.get_combined_minimum_size().y \
			+ footer.get_combined_minimum_size().y + sep * 2 + ctx.metrics.dp(12)
		var max_r := ctx.metrics.modal_rect(true)
		if need > r.size.y:
			var hh := minf(need, max_r.size.y)
			r = Rect2(r.position.x, max_r.position.y + (max_r.size.y - hh) * 0.5, r.size.x, hh)
	surface.position = r.position
	surface.size = r.size
	surface.custom_minimum_size = r.size

func _queue_layout() -> void:
	if not _layout_queued:
		_layout_queued = true
		(func(): _layout_queued = false; layout()).call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()

func _animate_in() -> void:
	var ms := ctx.anim_ms(CZ.AN_MODAL_IN_MS)
	# Underlying scene is blocked immediately; the modal itself accepts input once visible.
	ctx.lock_input_for(ms)
	if ms <= 0:
		return
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, ms / 1000.0).set_ease(Tween.EASE_OUT)

func _on_backdrop() -> void:
	if closable and not ctx.input_locked():
		request_close()

func request_close() -> void:
	if not closable:
		return
	close_requested.emit()

## Called when the route stack updates while this modal stays on top (state may have changed).
func refresh() -> void:
	pass

func primary_button(text: String) -> CzButton:
	var b := CzButton.new().setup(ctx, "UI_PRIMARY", text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(b)
	return b

func add_text(text: String, size_sp := UiStyle.BODY_SP, color := UiStyle.TEXT, bold := false) -> Label:
	var l := UiStyle.label(ctx.metrics, text, size_sp, color, bold)
	body.add_child(l)
	return l
