class_name CzButton
extends PanelContainer
## CMP_BUTTON / CMP_DEDUCTION_CARD / CMP_EVIDENCE_CARD base: states NORMAL, PRESSED, DISABLED,
## SELECTED, SUCCESS, ERROR. Activation goes through TapGesture (same contract as scene taps).
## A disabled button shows its reason text and emits nothing.

signal activated()

const NORMAL := "NORMAL"
const PRESSED := "PRESSED"
const DISABLED := "DISABLED"
const SELECTED := "SELECTED"
const SUCCESS := "SUCCESS"
const ERROR := "ERROR"

var ui_id := ""                 ## spec UI ID, e.g. UI_PRIMARY (prefixed by screen in the tree)
var ctx: AppContext
var state := NORMAL
var disabled := false
var selected := false
var label_node: Label
var sub_label: Label
var gesture := TapGesture.new()
var _box: VBoxContainer
var _pressed := false
var silent := false             ## no UI tap sound (e.g. toggles that play their own feedback)

func setup(context: AppContext, id: String, text: String, sub := "") -> CzButton:
	ctx = context
	ui_id = id
	name = id
	var m := ctx.metrics
	custom_minimum_size = Vector2(m.touch_min(), m.touch_min())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	label_node = UiStyle.label(m, text, UiStyle.BODY_SP, UiStyle.TEXT, true)
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label_node)
	sub_label = UiStyle.label(m, sub, UiStyle.SECONDARY_SP, UiStyle.SUBDUED)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.visible = sub != ""
	_box.add_child(sub_label)
	gesture.unit = m.unit
	gesture.pressed.connect(func(_p): _set_pressed(true))
	gesture.released.connect(func(): _set_pressed(false))
	gesture.tapped.connect(_on_tap)
	if "accessibility_name" in self:
		set("accessibility_name", text)
	_refresh()
	return self

func set_text(text: String) -> void:
	label_node.text = text
	if "accessibility_name" in self:
		set("accessibility_name", text)

func set_sub(text: String) -> void:
	sub_label.text = text
	sub_label.visible = text != ""

func align_left() -> void:
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func set_disabled(v: bool, reason := "") -> void:
	disabled = v
	if v and reason != "":
		set_sub(reason)
	elif not v and sub_label.text == reason and reason != "":
		set_sub("")
	_refresh()

func set_selected(v: bool) -> void:
	selected = v
	_refresh()

func set_result(s: String) -> void:
	state = s
	_refresh()

func _gui_input(event: InputEvent) -> void:
	if gesture.feed(event):
		accept_event()

func _set_pressed(v: bool) -> void:
	_pressed = v and not disabled
	_refresh()

func _on_tap(_pos: Vector2) -> void:
	if disabled or ctx.input_locked():
		return
	if not silent:
		ctx.ui_tap()
	activated.emit()

## Programmatic activation used by UI tests and accessibility actions; same guards as a tap.
func activate() -> void:
	_on_tap(Vector2.ZERO)

## Height needed at `width` (content margins + wrapped text), never below the 48 dp minimum.
func preferred_height(width: float) -> float:
	var m := ctx.metrics
	var inner := width - m.dp(24)
	var h := UiStyle.text_height(label_node, inner) + m.dp(16)
	if sub_label.visible:
		h += UiStyle.text_height(sub_label, inner) + _box.get_theme_constant("separation")
	return maxf(maxf(m.touch_min(), custom_minimum_size.y), ceil(h))

func _refresh() -> void:
	if ctx == null:
		return
	var m := ctx.metrics
	var fill := UiStyle.PANEL
	var border := UiStyle.SUBDUED
	var bw := 1.0
	var text_col := UiStyle.TEXT
	if disabled:
		fill = UiStyle.DISABLED_FILL
		text_col = UiStyle.SUBDUED
	elif state == SUCCESS:
		border = UiStyle.SUCCESS
		bw = 3.0
	elif state == ERROR:
		border = UiStyle.ERROR
		bw = 3.0
	elif selected:
		border = UiStyle.SELECTED
		bw = 3.0
	if _pressed:
		fill = fill.darkened(0.08)
	add_theme_stylebox_override("panel", UiStyle.panel_box(m, fill, border, 8.0, bw))
	label_node.add_theme_color_override("font_color", text_col)
