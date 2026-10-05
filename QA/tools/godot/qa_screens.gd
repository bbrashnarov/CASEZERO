extends SceneTree
## QA screenshots for spec findings CZ-QA-003/004/005 on the REAL UI (desktop render, 1080px canvas == 360dp).
##   cp QA/tools/godot/qa_screens.gd <copy>/tools/qa_screens.gd
##   xvfb-run -a -s "-screen 0 1280x2400x24" godot --path <copy> --rendering-driver opengl3 -s res://tools/qa_screens.gd -- --out=/abs/dir
var out_dir := "/tmp/qa_screens"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _shot(h: UiHarness, label: String) -> void:
	await h.frames(3)
	await RenderingServer.frame_post_draw
	h.vp.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("saved ", label)

func _c03_ready(d: Vector2, fs: float) -> UiHarness:
	var fx := Fx.new()
	fx.solve_c01()
	fx.solve_c02()
	fx.start("C03")
	for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
		fx.inspect("C03", o)
	fx.route = ""
	var h := UiHarness.new(d, fs, [0, 0, 0, 0], fx.backend)
	await h.boot()
	h.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await h.press("UI_BOARD_C03", h.base())
	return h

func _run() -> void:
	for spec in [[Vector2(360, 640), 1.0], [Vector2(360, 640), 1.3], [Vector2(360, 640), 2.0], [Vector2(412, 915), 1.0]]:
		var d: Vector2 = spec[0]
		var fs: float = spec[1]
		var tag := "%dx%d_fs%.1f" % [d.x, d.y, fs]
		var h := await _c03_ready(d, fs)
		await h.press("UI_EVIDENCE", h.base())
		await _shot(h, tag + "_A_c03_evidence_5cards")
		await h.press("UI_PRIMARY")
		var m := h.top() as StageModal
		# deliberately WRONG order -> inline error (CZ-QA-003: error rect vs slots)
		m.pick_token("TL_PHOTO"); m.pick_slot(0)
		m.pick_token("TL_CLAIM"); m.pick_slot(1)
		m.pick_token("TL_DEPART"); m.pick_slot(2)
		await h.settle()
		await h.press("UI_PRIMARY")
		await h.settle()
		await _shot(h, tag + "_B_c03_timeline_wrong")
		await h.cleanup()
	# C01 deduction answers at 1.0 / 2.0 (CZ-QA-005)
	for fs in [1.0, 2.0]:
		var fx := Fx.new()
		fx.start("C01")
		fx.inspect("C01", "C01_WINDOW"); fx.inspect("C01", "C01_FLOOR")
		fx.answer("C01", "C01_Q1", "C01_Q1_A0"); fx.inspect("C01", "C01_MANAGER")
		fx.route = ""
		var h := UiHarness.new(Vector2(360, 640), fs, [0, 0, 0, 0], fx.backend)
		await h.boot()
		h.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await h.press("UI_BOARD_C01", h.base())
		await h.press("UI_EVIDENCE", h.base())
		await h.press("UI_PRIMARY")
		await _shot(h, "360x640_fs%.1f_C_c01_q2_answers" % fs)
		await h.cleanup()
	quit(0)
