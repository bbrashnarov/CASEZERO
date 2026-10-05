extends TestCase
## Input contract through real pointer events, and the responsive layout contract on the
## reference device classes (spec Part 3): 360×640, 360×800, 412×915 dp phones, a 800×1280 dp
## tablet, font scale 1.0 and 2.0, and system-bar insets.

const DEVICES := [Vector2(360, 640), Vector2(360, 800), Vector2(412, 915), Vector2(800, 1280)]

var h: UiHarness

func after_each() -> void:
	if h:
		await h.cleanup()

func _scene(device: Vector2, fs := 1.0, insets := [0, 0, 0, 0]) -> void:
	h = UiHarness.new(device, fs, insets)
	await h.boot()
	await h.press("UI_PRIMARY", h.base())
	await h.frames(2)

func test_pointer_tap_opens_object() -> void:
	await _scene(Vector2(360, 640))
	await h.pointer_tap(h.object_screen_center("C01", "C01_WINDOW"))
	assert_eq(h.route(), "C01_INSPECT_WINDOW")

func test_drag_over_12dp_is_not_a_tap() -> void:
	await _scene(Vector2(360, 640))
	await h.pointer_tap(h.object_screen_center("C01", "C01_WINDOW"), 60, Vector2(13 * h.unit(), 0))
	assert_eq(h.route(), "C01_SCENE")
	assert_eq(h.run("C01")["evidence"], [])

func test_small_move_within_12dp_is_a_tap() -> void:
	await _scene(Vector2(360, 640))
	await h.pointer_tap(h.object_screen_center("C01", "C01_WINDOW"), 60, Vector2(10 * h.unit(), 0))
	assert_eq(h.route(), "C01_INSPECT_WINDOW")

func test_hold_over_500ms_is_not_a_tap() -> void:
	await _scene(Vector2(360, 640))
	await h.pointer_tap(h.object_screen_center("C01", "C01_WINDOW"), 620)
	assert_eq(h.route(), "C01_SCENE")

func test_scene_input_blocked_under_modal() -> void:
	await _scene(Vector2(360, 640))
	await h.tap_object("C01", "C01_WINDOW")
	# A tap where the floor is, while the inspect panel is open, must not reach the scene.
	await h.pointer_tap(h.object_screen_center("C01", "C01_FLOOR"))
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])

func _check_layout(label: String) -> void:
	var m := h.ctx().metrics
	var cs := h.base() as CaseScreen
	var v := cs.view
	var vr := Rect2(v.position, v.size)
	var safe := m.safe
	assert_true(safe.grow(1).encloses(vr), "%s: scene inside safe area %s vs %s" % [label, vr, safe])
	assert_true(m.column.size.x <= LayoutMetrics.MAX_COLUMN_DP * m.unit + 1, label + ": column ≤ 600 dp")
	# Uniform scale: aspect of the viewport equals the canonical 1080×1332.
	assert_true(absf(vr.size.x / vr.size.y - 1080.0 / 1332.0) < 0.01, label + ": uniform scale")
	var header_bottom := cs.header.position.y + cs.header.size.y
	assert_true(header_bottom <= vr.position.y + 1, "%s: header above scene (%f > %f)" % [label, header_bottom, vr.position.y])
	assert_true(cs.footer.position.y >= vr.end.y - 1, label + ": footer below scene")
	assert_true(cs.footer.position.y + cs.footer.size.y <= safe.end.y + 1, label + ": footer inside safe area")
	for b in [cs.hint_button, cs.evidence_button]:
		assert_true(b.size.y >= m.touch_min() - 0.5 and b.size.x >= m.touch_min() - 0.5, label + ": HUD button ≥ 48 dp")
	# Every clickable object is reachable with ≥ 48 dp after expansion.
	for o in h.ctx().db.case_def("C01").clickable_objects():
		var e := v.expanded_hitbox(o)
		var phys := e.size * v.scale_s / m.unit
		assert_true(phys.x >= 47.5 or e.size.x >= CZ.SCENE_RECT.size.x - 1, "%s: %s width %.1f dp" % [label, o["id"], phys.x])
		assert_true(phys.y >= 47.5, "%s: %s height %.1f dp" % [label, o["id"], phys.y])
	# Inverse transform: the screen centre of each hitbox resolves to that object.
	for o in h.ctx().db.case_def("C01").clickable_objects():
		var hb: Array = o["hitbox"]
		var c := Vector2(hb[0] + hb[2] * 0.5, hb[1] + hb[3] * 0.5)
		var back := v.local_to_canvas(v.canvas_to_local(c))
		assert_true(back.distance_to(c) < 0.01, label + ": inverse transform")
		var r := v.resolve_tap(c)
		assert_true(r["kind"] == "object" and r["ids"][0] == o["id"], "%s: centre of %s resolves to %s" % [label, o["id"], str(r)])

func _check_modal_cta(label: String) -> void:
	var m := h.ctx().metrics
	await h.tap_object("C01", "C01_WINDOW")
	var modal := h.top() as ModalBase
	await h.frames(2)
	var surf := Rect2(modal.surface.global_position, modal.surface.size)
	var cta_rect := Rect2(modal.footer.global_position, modal.footer.size)
	assert_true(m.safe.grow(1).encloses(surf), "%s: modal inside safe area %s / %s" % [label, surf, m.safe])
	var close_rect := Rect2(modal.close_button.global_position, modal.close_button.size)
	assert_true(close_rect.size.x >= m.touch_min() - 0.5, label + ": close ≥ 48 dp")
	assert_true(m.safe.grow(1).encloses(close_rect), label + ": close visible")
	assert_true(surf.grow(1).encloses(cta_rect), label + ": footer inside surface")
	await h.close()

func test_layout_reference_devices_font_1() -> void:
	for d in DEVICES:
		await _scene(d)
		_check_layout("%dx%d fs1.0" % [d.x, d.y])
		await _check_modal_cta("%dx%d fs1.0" % [d.x, d.y])
		await h.cleanup()
	h = null

func test_layout_reference_devices_font_2() -> void:
	for d in DEVICES:
		await _scene(d, 2.0)
		_check_layout("%dx%d fs2.0" % [d.x, d.y])
		await _check_modal_cta("%dx%d fs2.0" % [d.x, d.y])
		await h.cleanup()
	h = null

func test_layout_with_system_insets() -> void:
	await _scene(Vector2(360, 800), 1.0, [0, 32, 0, 48])
	_check_layout("360x800 insets")
	await _check_modal_cta("360x800 insets")

func test_stage_modal_cta_visible_at_font_2_small_phone() -> void:
	await _scene(Vector2(360, 640), 2.0)
	for oid in ["C01_WINDOW", "C01_FLOOR"]:
		await h.tap_object("C01", oid)
		await h.close()
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	await h.frames(2)
	var m := h.ctx().metrics
	var sub := Rect2(st._submit.global_position, st._submit.size)
	assert_true(m.safe.grow(1).encloses(sub), "submit visible without scrolling: %s in %s" % [sub, m.safe])
	assert_true(st.scroll.get_v_scroll_bar() != null, "body scrolls")
	# Long answers wrap; nothing scrolls horizontally.
	assert_eq(st.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)

func test_intro_cta_visible_all_devices_font_2() -> void:
	for d in DEVICES:
		h = UiHarness.new(d, 2.0)
		await h.boot()
		await h.frames(3)
		var cs := h.base() as CaseScreen
		var m := h.ctx().metrics
		var b := h.button("UI_PRIMARY", cs)
		var r := Rect2(b.global_position, b.size)
		assert_true(m.safe.grow(1).encloses(r), "%s: intro CTA visible %s in %s" % [d, r, m.safe])
		assert_true(r.size.y >= m.touch_min() - 0.5, "%s: intro CTA ≥ 48 dp" % d)
		var card := Rect2(cs.intro_card.global_position, cs.intro_card.size)
		assert_true(m.safe.grow(1).encloses(card), "%s: intro card inside safe area %s" % [d, card])
		await h.cleanup()
	h = null
