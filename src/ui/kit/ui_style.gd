class_name UiStyle
extends RefCounted
## Palette and typography from spec Part 3, plus the generated Theme.

const BG := Color("#202E38")
const PANEL := Color("#F3EBDD")
const TEXT := Color("#162733")
const SUBDUED := Color("#52616B")
const ACCENT := Color("#B27A35")
const SELECTED := Color("#285D70")
const SUCCESS := Color("#23664F")
const ERROR := Color("#963F3F")
const SCRIM := Color(0.05, 0.08, 0.1, 0.72)
const DISABLED_FILL := Color("#C9C3B8")

const TITLE_SP := 26
const BODY_SP := 18
const SECONDARY_SP := 16
const TIMESTAMP_SP := 20

static var regular: Font
static var semibold: Font

static func load_fonts(assets: AssetRegistry) -> void:
	regular = assets.font("F_UI_REGULAR")
	semibold = assets.font("F_UI_SEMIBOLD")
	if regular == null:
		regular = ThemeDB.fallback_font
	if semibold == null:
		semibold = regular

static func build_theme(m: LayoutMetrics) -> Theme:
	var th := Theme.new()
	th.default_font = regular
	th.default_font_size = m.sp(BODY_SP)
	th.set_color("font_color", "Label", TEXT)
	var sb := StyleBoxEmpty.new()
	th.set_stylebox("panel", "ScrollContainer", sb)
	th.set_constant("separation", "VBoxContainer", int(m.dp(8)))
	th.set_constant("separation", "HBoxContainer", int(m.dp(8)))
	return th

static func panel_box(m: LayoutMetrics, fill := PANEL, border := Color.TRANSPARENT, radius_dp := 8.0, border_dp := 0.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	var r := int(m.dp(radius_dp))
	b.corner_radius_top_left = r
	b.corner_radius_top_right = r
	b.corner_radius_bottom_left = r
	b.corner_radius_bottom_right = r
	var bw := int(maxf(1.0, m.dp(border_dp))) if border_dp > 0.0 else 0
	b.border_width_left = bw
	b.border_width_right = bw
	b.border_width_top = bw
	b.border_width_bottom = bw
	b.border_color = border
	var pad := m.dp(12)
	b.content_margin_left = pad
	b.content_margin_right = pad
	b.content_margin_top = m.dp(8)
	b.content_margin_bottom = m.dp(8)
	return b

## Height an autowrapped label needs at `width` (layout is computed synchronously, before the
## containers' deferred sort, so it cannot rely on the label's own minimum size).
static func text_height(l: Label, width: float) -> float:
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	if l.text == "" or not l.visible:
		return 0.0
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return font.get_height(fs)
	var sz := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, width), fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	return sz.y

static func label(m: LayoutMetrics, text: String, size_sp := BODY_SP, color := TEXT, bold := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", m.sp(size_sp))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", semibold)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
