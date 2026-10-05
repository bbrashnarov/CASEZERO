extends SceneTree
## Probe: after a WRONG submission, is the inline error (node "Feedback") inside the visible area of the modal's ScrollContainer?
##   cp QA/tools/godot/qa_feedback_probe.gd <copy>/tools/ ; xvfb-run -a godot --path <copy> --rendering-driver opengl3 -s res://tools/qa_feedback_probe.gd
func _initialize() -> void:
	_run.call_deferred()

func _scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer: return n
	for c in n.get_children():
		var r := _scroll(c)
		if r != null: return r
	return null

func _report(h: UiHarness, label: String) -> void:
	await h.settle()
	await h.frames(3)
	var m := h.top()
	var fb := h.find(m, "Feedback") as Control
	var sc := _scroll(m)
	if fb == null or sc == null:
		print("PROBE %s: no feedback/scroll node" % label); return
	var fr := fb.get_global_rect()
	var sr := sc.get_global_rect()
	var inside := fb.visible and sr.encloses(fr)
	var partly := fb.visible and sr.intersects(fr)
	print("PROBE %-34s feedback.visible=%s text='%s' inside_visible_scroll_area=%s partly=%s  scroll_v=%d  fb_y=%.0f..%.0f scroll_y=%.0f..%.0f" % [label, fb.visible, (fb as Label).text.left(40), inside, partly, sc.scroll_vertical, fr.position.y, fr.end.y, sr.position.y, sr.end.y])

func _run() -> void:
	for spec in [[Vector2(360, 640), 1.0], [Vector2(360, 800), 1.0], [Vector2(412, 915), 1.0], [Vector2(360, 640), 1.3], [Vector2(360, 640), 2.0]]:
		var d: Vector2 = spec[0]; var fs: float = spec[1]
		var tag := "%dx%d fs%.1f" % [d.x, d.y, fs]
		# C01 Q1 wrong answer
		var fx := Fx.new()
		fx.start("C01"); fx.inspect("C01", "C01_WINDOW"); fx.inspect("C01", "C01_FLOOR"); fx.route = ""
		var h := UiHarness.new(d, fs, [0, 0, 0, 0], fx.backend)
		await h.boot()
		await h.press("UI_BOARD_C01", h.base())
		await h.press("UI_EVIDENCE", h.base()); await h.press("UI_PRIMARY")
		(h.top() as StageModal).choose_answer("C01_Q1_A1"); (h.top() as StageModal).press_submit()
		await _report(h, tag + " C01 Q1 wrong")
		await h.cleanup()
		# C03 timeline wrong
		var fx3 := Fx.new()
		fx3.solve_c01(); fx3.solve_c02(); fx3.start("C03")
		for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]: fx3.inspect("C03", o)
		fx3.route = ""
		h = UiHarness.new(d, fs, [0, 0, 0, 0], fx3.backend)
		await h.boot()
		await h.press("UI_BOARD_C03", h.base())
		await h.press("UI_EVIDENCE", h.base()); await h.press("UI_PRIMARY")
		var m := h.top() as StageModal
		m.pick_token("TL_PHOTO"); m.pick_slot(0); m.pick_token("TL_CLAIM"); m.pick_slot(1); m.pick_token("TL_DEPART"); m.pick_slot(2)
		m.press_submit()
		await _report(h, tag + " C03 timeline wrong")
		await h.cleanup()
		# C03 link wrong (needs timeline_ok): set via fx
		var fx4 := Fx.new()
		fx4.solve_c01(); fx4.solve_c02(); fx4.start("C03")
		for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]: fx4.inspect("C03", o)
		fx4.place("C03", "C03_TIMELINE", "TL_DEPART", 0); fx4.place("C03", "C03_TIMELINE", "TL_CLAIM", 1); fx4.place("C03", "C03_TIMELINE", "TL_PHOTO", 2); fx4.submit_timeline("C03", "C03_TIMELINE")
		fx4.route = ""
		h = UiHarness.new(d, fs, [0, 0, 0, 0], fx4.backend)
		await h.boot()
		await h.press("UI_BOARD_C03", h.base())
		await h.press("UI_EVIDENCE", h.base()); await h.press("UI_PRIMARY")
		m = h.top() as StageModal
		m.toggle("EV_C03_TICKET"); m.toggle("EV_C03_PHOTO"); m.toggle("EV_C03_CLOCK_SYNC"); m.press_submit()
		await _report(h, tag + " C03 link wrong")
		await h.cleanup()
	quit(0)
