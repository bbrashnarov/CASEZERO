class_name LayoutMetrics
extends RefCounted
## Responsive contract (spec Part 3): U = safe rect after insets; HUD anchored to U with a 16 dp
## margin; the scene viewport is fitted between header and footer with a single uniform scale
##   s = min(availW / 1080, availH / 1332), centred, and input uses the inverse transform.
## Tablets: HUD and scene limited to 600 dp width, centred.

const SCENE_W := 1080.0
const SCENE_H := 1332.0
const SCENE_TOP := 264.0
const MAX_COLUMN_DP := 600.0
const MARGIN_DP := 16.0

var size := Vector2(1080, 1920)
var safe := Rect2(0, 0, 1080, 1920)
var unit := 3.0          ## logical units per dp
var font_scale := 1.0
var column := Rect2()    ## safe rect limited to MAX_COLUMN_DP, centred

static func compute(shell_size: Vector2, platform: PlatformService) -> LayoutMetrics:
	var m := LayoutMetrics.new()
	m.size = shell_size
	m.unit = platform.units_per_dp(shell_size)
	m.safe = platform.safe_rect(shell_size)
	m.font_scale = platform.font_scale()
	var w := minf(m.safe.size.x, MAX_COLUMN_DP * m.unit)
	m.column = Rect2(m.safe.position.x + (m.safe.size.x - w) * 0.5, m.safe.position.y, w, m.safe.size.y)
	return m

func dp(v: float) -> float:
	return v * unit

## Text size: sp honours the system font scale; never shrunk to fit (spec Part 3 Typography).
func sp(v: float) -> int:
	return int(round(v * unit * font_scale))

func margin() -> float:
	return dp(MARGIN_DP)

func touch_min() -> float:
	return dp(CZ.MIN_TOUCH_DP)

## Scene viewport for the area between header bottom and footer top.
func scene_rect(top: float, bottom: float) -> Dictionary:
	var avail := Rect2(column.position.x, top, column.size.x, maxf(1.0, bottom - top))
	var s := minf(avail.size.x / SCENE_W, avail.size.y / SCENE_H)
	var w := SCENE_W * s
	var h := SCENE_H * s
	var origin := Vector2(avail.position.x + (avail.size.x - w) * 0.5, avail.position.y + (avail.size.y - h) * 0.5)
	return {"rect": Rect2(origin, Vector2(w, h)), "scale": s}

## Canonical canvas point -> screen point inside a scene viewport (spec formula).
static func canvas_to_screen(p: Vector2, scene_origin: Vector2, s: float) -> Vector2:
	return Vector2(scene_origin.x + p.x * s, scene_origin.y + (p.y - SCENE_TOP) * s)

static func screen_to_canvas(p: Vector2, scene_origin: Vector2, s: float) -> Vector2:
	return Vector2((p.x - scene_origin.x) / s, (p.y - scene_origin.y) / s + SCENE_TOP)

## Modal surface: spec baseline [48,312,984,1248] inside the 1080×1920 safe frame; on other
## screens it keeps 16 dp side margins and grows to the safe height when text needs room.
func modal_rect(tall := false) -> Rect2:
	var m := margin()
	var x := column.position.x + m
	var w := column.size.x - 2.0 * m
	var max_h := safe.size.y - 2.0 * m
	var base_h := dp(416.0)
	var h := max_h if (tall or font_scale > 1.25 or base_h > max_h) else base_h
	var y := safe.position.y + (safe.size.y - h) * 0.5
	return Rect2(x, y, w, h)
