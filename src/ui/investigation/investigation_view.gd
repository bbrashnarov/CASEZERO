class_name InvestigationView
extends Control
## Reusable investigation renderer for every case scene (SCN_C01_ROOM, SCN_C02_DESK, ...).
## Draws the flattened background and the case objects from content at canonical coordinates
## through the uniform scene transform, and resolves taps with canonical hitboxes:
##   * hitbox expanded symmetrically to the 48 dp physical minimum, clamped to the viewport
##   * overlap resolution: priority desc, z-index desc, Object ID asc
##   * expanded hitboxes overlapping > 25% of the smaller area -> G_PICKER, never a guess
## Rendering is never the source of truth: everything drawn is derived from GameState.

signal object_tapped(object_id: String)
signal picker_needed(object_ids: Array)

const GREY_BG := Color("#2B3A44")
const GREY_OBJ := Color("#3E5563")
const GREY_DECOR := Color("#34444F")

var ctx: AppContext
var def: CaseDef
var scale_s := 1.0
var debug_hitboxes := false
var interactive := true
var gesture := TapGesture.new()
var _pressed_id := ""
var _pulses := {}          # object_id -> {start_ms, duration_ms, count}
var _connect_flash := {}   # object_id -> start_ms (AN_CONNECT crossfade)

func setup(context: AppContext, case_def: CaseDef) -> InvestigationView:
	ctx = context
	def = case_def
	name = def.scene_id()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	gesture.unit = ctx.metrics.unit
	gesture.pressed.connect(_on_press)
	gesture.released.connect(func(): _pressed_id = ""; queue_redraw())
	gesture.tapped.connect(_on_tap)
	return self

func set_viewport_rect(r: Rect2, s: float) -> void:
	position = r.position
	size = r.size
	scale_s = s
	queue_redraw()

# --- coordinate transform ----------------------------------------------------------------

func canvas_to_local(p: Vector2) -> Vector2:
	return LayoutMetrics.canvas_to_screen(p, Vector2.ZERO, scale_s)

func local_to_canvas(p: Vector2) -> Vector2:
	return LayoutMetrics.screen_to_canvas(p, Vector2.ZERO, scale_s)

func canvas_rect_to_local(r: Rect2) -> Rect2:
	return Rect2(canvas_to_local(r.position), r.size * scale_s)

static func _r(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))

# --- hit testing ------------------------------------------------------------------------

## Hitbox in canonical units after the 48 dp minimum expansion.
func expanded_hitbox(obj: Dictionary) -> Rect2:
	var hb := _r(obj["hitbox"])
	var min_canon := ctx.metrics.touch_min() / maxf(scale_s, 0.0001)
	var grow_x := maxf(0.0, (min_canon - hb.size.x) * 0.5)
	var grow_y := maxf(0.0, (min_canon - hb.size.y) * 0.5)
	var e := hb.grow_individual(grow_x, grow_y, grow_x, grow_y)
	return e.intersection(CZ.SCENE_RECT)

static func overlap_ratio(a: Rect2, b: Rect2) -> float:
	var inter := a.intersection(b)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0:
		return 0.0
	var smaller := minf(a.get_area(), b.get_area())
	return inter.get_area() / smaller if smaller > 0.0 else 0.0

## Returns {"kind": "none"|"object"|"picker", "ids": [...]} for a canonical point.
func resolve_tap(canvas_point: Vector2) -> Dictionary:
	var hits := []
	for o in def.clickable_objects():
		if expanded_hitbox(o).has_point(canvas_point):
			hits.append(o)
	if hits.is_empty():
		return {"kind": "none", "ids": []}
	hits.sort_custom(func(a, b):
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		if int(a["z"]) != int(b["z"]):
			return int(a["z"]) > int(b["z"])
		return str(a["id"]) < str(b["id"]))
	if hits.size() > 1:
		var ambiguous := false
		for i in hits.size():
			for j in range(i + 1, hits.size()):
				if overlap_ratio(expanded_hitbox(hits[i]), expanded_hitbox(hits[j])) > CZ.PICKER_OVERLAP_RATIO:
					ambiguous = true
		if ambiguous:
			return {"kind": "picker", "ids": hits.map(func(o): return o["id"])}
	return {"kind": "object", "ids": [hits[0]["id"]]}

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if gesture.feed(event):
		accept_event()

func _on_press(pos: Vector2) -> void:
	var r := resolve_tap(local_to_canvas(pos))
	_pressed_id = r["ids"][0] if r["kind"] == "object" else ""
	queue_redraw()

func _on_tap(pos: Vector2) -> void:
	_pressed_id = ""
	queue_redraw()
	if ctx.input_locked():
		return
	var r := resolve_tap(local_to_canvas(pos))
	match r["kind"]:
		"object":
			object_tapped.emit(r["ids"][0])
		"picker":
			picker_needed.emit(r["ids"])
		_:
			pass   # empty scene / decoration: no sound, ripple, event or penalty (spec failure contract)

## Test/automation entry: tap at a canonical canvas point through the same resolution path.
func tap_canvas(p: Vector2) -> void:
	_on_tap(canvas_to_local(p))

# --- feedback animations -----------------------------------------------------------------

func pulse(object_id: String, count := CZ.AN_HINT_PULSE_COUNT, duration_ms := CZ.AN_HINT_PULSE_MS) -> void:
	_pulses[object_id] = {"start": Time.get_ticks_msec(), "duration": duration_ms, "count": count}
	set_process(true)

func stop_pulse(object_id: String) -> void:
	_pulses.erase(object_id)
	queue_redraw()

func flash_connect(object_id: String) -> void:
	if ctx.reduced_motion():
		queue_redraw()
		return
	_connect_flash[object_id] = Time.get_ticks_msec()
	set_process(true)

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	for k in _pulses.keys():
		var p: Dictionary = _pulses[k]
		if now - int(p["start"]) > int(p["duration"]) * int(p["count"]):
			_pulses.erase(k)
	for k in _connect_flash.keys():
		if now - int(_connect_flash[k]) > CZ.AN_CONNECT_MS:
			_connect_flash.erase(k)
	if _pulses.is_empty() and _connect_flash.is_empty():
		set_process(false)
	queue_redraw()

# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if def == null:
		return
	var font := UiStyle.regular
	var fs := maxi(10, int(28.0 * scale_s))
	var bg := def.background()
	var bg_local := Rect2(Vector2.ZERO, size)
	var bg_tex := ctx.assets.texture(str(bg.get("asset_id", "")))
	if bg_tex:
		draw_texture_rect(bg_tex, bg_local, false)
	else:
		draw_rect(bg_local, GREY_BG)
		draw_string(font, Vector2(8, fs + 4), "%s · GREYBOX" % bg.get("asset_id", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.35))
	var run := ctx.run(def.id)
	var campaign: Dictionary = ctx.state()["campaign"]
	var objs := def.objects.duplicate()
	objs.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	for o in objs:
		var r := canvas_rect_to_local(_r(o["rect"]))
		var variant := ""
		if o.has("variant_field") and not run.is_empty():
			variant = str(run.get(o["variant_field"], ""))
		var tex := ctx.assets.texture(str(o["asset_id"]), variant)
		var clickable: bool = o.get("clickable", false)
		if tex:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, GREY_OBJ if clickable else GREY_DECOR)
			draw_rect(r, Color(1, 1, 1, 0.5) if clickable else Color(1, 1, 1, 0.2), false, maxf(1.0, 2.0 * scale_s))
			var label := str(o.get("name", o["id"]))
			draw_string(font, r.position + Vector2(6, fs + 4), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, fs, Color(1, 1, 1, 0.9))
			draw_string(font, r.position + Vector2(6, fs * 2 + 8), str(o["id"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, int(fs * 0.8), Color(1, 1, 1, 0.55))
			if variant != "":
				draw_string(font, r.position + Vector2(6, fs * 3 + 12), variant, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, int(fs * 0.8), UiStyle.ACCENT)
		if clickable and not run.is_empty():
			var profile := Profiles.get_profile(o["profile"])
			if profile is PManager and not Selectors.gate_open(o, run, campaign):
				_draw_lock(r.get_center(), maxf(16.0, 56.0 * scale_s))
			if run["objects"].get(o["id"], {}).get("inspection") == CZ.SEEN:
				draw_circle(r.position + Vector2(r.size.x - 14 * scale_s - 6, 14 * scale_s + 6), maxf(4.0, 10 * scale_s), UiStyle.SUCCESS)
		if o["id"] == _pressed_id:
			draw_rect(r, Color(0, 0, 0, 0.08))
			draw_rect(r, UiStyle.ACCENT, false, maxf(2.0, 4.0 * scale_s))
		if _pulses.has(o["id"]):
			var p: Dictionary = _pulses[o["id"]]
			var t := float(Time.get_ticks_msec() - int(p["start"])) / float(p["duration"])
			var phase := fmod(t, 1.0)
			# Reduced motion keeps the informational highlight but drops the breathing animation.
			var alpha := 0.55 if ctx.reduced_motion() else 0.25 + 0.30 * sin(phase * PI)
			draw_rect(r.grow(6 * scale_s), Color(UiStyle.ACCENT, alpha), false, maxf(3.0, 8.0 * scale_s))
		if _connect_flash.has(o["id"]):
			var k := float(Time.get_ticks_msec() - int(_connect_flash[o["id"]])) / CZ.AN_CONNECT_MS
			draw_rect(r, Color(UiStyle.SUCCESS, 0.35 * (1.0 - k)))
	if debug_hitboxes:
		for o in def.clickable_objects():
			draw_rect(canvas_rect_to_local(_r(o["hitbox"])), Color(0, 1, 0, 0.9), false, 2.0)
			draw_rect(canvas_rect_to_local(expanded_hitbox(o)), Color(1, 1, 0, 0.7), false, 1.0)
			var hp := canvas_rect_to_local(_r(o["hitbox"])).position
			draw_string(font, hp + Vector2(2, -4), "%s p%s z%s" % [o["id"], o["priority"], o["z"]], HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, fs - 4), Color(0, 1, 0))

func _draw_lock(c: Vector2, s: float) -> void:
	var body := Rect2(c.x - s * 0.5, c.y - s * 0.1, s, s * 0.7)
	draw_rect(body.grow(3), Color(0, 0, 0, 0.45))
	draw_rect(body, UiStyle.ACCENT)
	draw_arc(Vector2(c.x, c.y - s * 0.1), s * 0.3, PI, TAU, 16, UiStyle.ACCENT, maxf(2.0, s * 0.12))
