extends SceneTree
## Process-kill QA driver (not shipped). Plays the real App against the real file backend in
## user://qa_kill and prints a marker after each committed step, then idles so the shell script
## can SIGKILL the process. `--verify` boots once and prints the restored state as JSON.
##   godot --headless --path . -s res://tools/qa/kill_driver.gd -- --steps=3
##   godot --headless --path . -s res://tools/qa/kill_driver.gd -- --stress
##   godot --headless --path . -s res://tools/qa/kill_driver.gd -- --verify

const ROOT := "user://qa_kill"

func _initialize() -> void:
	Log.min_level = Log.Level.WARN
	_main.call_deferred()

func _arg(name: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _main() -> void:
	var h := UiHarness.new(Vector2(360, 640), 1.0, [0, 0, 0, 0], FileSaveBackend.new(ROOT))
	await h.boot()
	if _arg("verify") != "":
		var raw := SaveRepository.new(FileSaveBackend.new(ROOT)).load()
		print("VERIFY ", JSON.stringify({"load_status": raw["status"], "boot_status": h.app.boot_result.get("status"),
			"route": h.route(), "evidence": h.run("C01").get("evidence", []), "questions": h.run("C01").get("questions", {}),
			"hint_level": h.run("C01").get("hint_level", 0), "completed": h.state().get("campaign", {}).get("completed", {}),
			"xp": h.state().get("campaign", {}).get("xp", -1), "interaction_index": h.state().get("interaction_index", -1)}))
		quit(0)
		return
	if _arg("stress") != "":
		# Continuous committed writes (settings toggles + hints) until killed.
		await h.press("UI_PRIMARY", h.base())
		var n := 0
		while true:
			h.ctx().perform(CZ.SET_SETTING, {"key": "reduced_motion", "value": n % 2 == 0})
			n += 1
			if n % 50 == 0:
				print("STRESS ", n)
			await h.frames(1)
		return
	var steps := int(_arg("steps", "0"))
	var plan := [
		func(): await h.press("UI_PRIMARY", h.base()),                     # 1 START (intro -> scene)
		func(): await h.tap_object("C01", "C01_WINDOW"),                    # 2 RAIN (killed with panel open)
		func(): await h.close(); await h.tap_object("C01", "C01_FLOOR"),    # 3 DRY_FLOOR
		func(): await h.close(); await h.press("UI_HINT", h.base()),        # 4 hint level 1
		func():                                                              # 5 Q1 correct
			await h.close()
			await h.press("UI_EVIDENCE", h.base())
			await h.press("UI_PRIMARY")
			(h.top() as StageModal).choose_answer("C01_Q1_A0")
			(h.top() as StageModal).press_submit()
			await h.settle(),
		func():                                                              # 6 ADMISSION
			(h.top() as StageModal).press_submit()
			await h.settle()
			await h.tap_object("C01", "C01_MANAGER"),
		func():                                                              # 7 SOLVED
			await h.close()
			await h.press("UI_EVIDENCE", h.base())
			await h.press("UI_PRIMARY")
			(h.top() as StageModal).choose_answer("C01_Q2_A1")
			(h.top() as StageModal).press_submit()
			await h.settle(),
	]
	for i in mini(steps, plan.size()):
		await plan[i].call()
		print("STEP %d route=%s" % [i + 1, h.route()])
	print("READY_FOR_KILL")
	while true:
		await h.frames(10)
