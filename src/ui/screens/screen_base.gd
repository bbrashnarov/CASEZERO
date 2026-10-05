class_name ScreenBase
extends Control
## Full-screen route with a centred column (header + scroll body + fixed footer), anchored to the
## safe rect. Used by BOARD, SETTINGS, SOLVED, REWARD, END and BOOT.

var ctx: AppContext
var route: Dictionary
var title_label: Label
var top_bar: HBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var footer: VBoxContainer
var _col: VBoxContainer

func init_screen(context: AppContext, r: Dictionary, title: String) -> void:
	ctx = context
	route = r
	name = str(r["id"])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ctx.metrics
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", int(m.dp(12)))
	add_child(_col)
	top_bar = HBoxContainer.new()
	_col.add_child(top_bar)
	title_label = UiStyle.label(m, title, UiStyle.TITLE_SP, UiStyle.PANEL, true)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(title_label)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(m.dp(12)))
	scroll.add_child(body)
	footer = VBoxContainer.new()
	_col.add_child(footer)
	layout()

func layout() -> void:
	if _col == null:
		return
	var m := ctx.metrics
	var mg := m.margin()
	_col.position = Vector2(m.column.position.x + mg, m.safe.position.y + mg)
	_col.size = Vector2(m.column.size.x - 2 * mg, m.safe.size.y - 2 * mg)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()

func refresh() -> void:
	pass

func add_text(text: String, size_sp := UiStyle.BODY_SP, color := UiStyle.PANEL, bold := false) -> Label:
	var l := UiStyle.label(ctx.metrics, text, size_sp, color, bold)
	body.add_child(l)
	return l

func primary_button(text: String, id := "UI_PRIMARY") -> CzButton:
	var b := CzButton.new().setup(ctx, id, text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(b)
	return b
