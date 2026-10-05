extends SceneTree
## QA helper (not shipped): renders key routes to PNG through the real UI on given device sizes.
##   xvfb-run -s "-screen 0 1280x2400x24" godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd -- --out=build/screens
## Needs a rendering context (not --headless).

var out_dir := "res://build/screens"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _shot(h: UiHarness, label: String) -> void:
	await h.frames(3)
	await RenderingServer.frame_post_draw
	var img := h.vp.get_texture().get_image()
	img.save_png(out_dir.path_join(label + ".png"))
	print("saved ", label)

func _run() -> void:
	for spec in [[Vector2(360, 640), 1.0], [Vector2(412, 915), 1.0], [Vector2(360, 640), 2.0], [Vector2(800, 1280), 1.0]]:
		var d: Vector2 = spec[0]
		var fs: float = spec[1]
		var tag := "%dx%d_fs%.1f" % [d.x, d.y, fs]
		var h := UiHarness.new(d, fs)
		await h.boot()
		h.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await _shot(h, tag + "_01_intro")
		await h.press("UI_PRIMARY", h.base())
		await _shot(h, tag + "_02_scene")
		await h.tap_object("C01", "C01_WINDOW")
		await h.wait(300)
		await _shot(h, tag + "_03_inspect")
		await h.close()
		await h.tap_object("C01", "C01_FLOOR")
		await h.close()
		await h.press("UI_EVIDENCE", h.base())
		await _shot(h, tag + "_04_evidence")
		await h.press("UI_PRIMARY")
		await _shot(h, tag + "_05_q1")
		await h.close()
		await h.close()
		await h.press("UI_HINT", h.base())
		await _shot(h, tag + "_06_hint")
		await h.close()
		h.app.back()
		await h.settle()
		await _shot(h, tag + "_07_pause")
		await h.press("UI_PAUSE_BOARD")
		await _shot(h, tag + "_08_board")
		await h.cleanup()
	for spec in [[Vector2(360, 640), 1.0], [Vector2(360, 640), 2.0], [Vector2(412, 915), 1.0]]:
		var d: Vector2 = spec[0]
		var fs: float = spec[1]
		var tag := "%dx%d_fs%.1f" % [d.x, d.y, fs]
		var fx := Fx.new()
		fx.solve_c01()
		var h := UiHarness.new(d, fs, [0, 0, 0, 0], fx.backend)
		await h.boot()
		h.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await h.press("UI_BOARD_C02", h.base())
		await h.press("UI_PRIMARY", h.base())
		await _shot(h, tag + "_20_c02_scene")
		await h.tap_object("C02", "C02_CHARGER")
		await h.press("UI_PRIMARY")
		await _shot(h, tag + "_21_c02_charger_connected")
		await h.close()
		for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
			await h.tap_object("C02", o)
			await h.close()
		await h.press("UI_EVIDENCE", h.base())
		await h.press("UI_PRIMARY")
		(h.top() as StageModal).toggle("EV_C02_BATTERY")
		(h.top() as StageModal).toggle("EV_C02_NETWORK")
		await _shot(h, tag + "_22_c02_connect")
		await h.cleanup()
		var fx3 := Fx.new()
		fx3.solve_c01()
		fx3.solve_c02()
		fx3.start("C03")
		for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
			fx3.inspect("C03", o)
		fx3.route = ""
		h = UiHarness.new(d, fs, [0, 0, 0, 0], fx3.backend)
		await h.boot()
		h.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await h.press("UI_BOARD_C03", h.base())
		await _shot(h, tag + "_30_c03_scene")
		await h.press("UI_EVIDENCE", h.base())
		await h.press("UI_PRIMARY")
		(h.top() as StageModal).pick_token("TL_DEPART")
		(h.top() as StageModal).pick_slot(0)
		(h.top() as StageModal).pick_token("TL_PHOTO")
		await h.settle()
		await _shot(h, tag + "_31_c03_timeline")
		await h.cleanup()
	quit(0)
