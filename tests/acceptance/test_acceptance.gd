extends TestCase
## Spec Part 12 "Implementation acceptance scenarios" AT01–AT20, executed through the real App
## (UI shell + store + save). Each test name carries its AT ID; TEST_REPORT.md maps them 1:1.

var h: UiHarness

func after_each() -> void:
	if h:
		await h.cleanup()

func _boot(solved: Array = [], device := Vector2(360, 640), fs := 1.0) -> void:
	var fx := Fx.new()
	if solved.has("C01"):
		fx.solve_c01()
	if solved.has("C02"):
		fx.solve_c02()
	h = UiHarness.new(device, fs, [0, 0, 0, 0], fx.backend)
	await h.boot()

func _enter(cid: String) -> void:
	await h.press("UI_BOARD_" + cid, h.base())
	if h.base_id() == cid + "_INTRO":
		await h.press("UI_PRIMARY", h.base())

func _look(cid: String, oid: String) -> void:
	await h.tap_object(cid, oid)
	await h.close()

func _open_deduction() -> StageModal:
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	return h.top() as StageModal

func _cta_kind(cid: String) -> String:
	return Selectors.deduction_cta(h.ctx().db.case_def(cid), h.run(cid), h.state()["campaign"])["kind"]

func test_at01_c01_floor_before_window() -> void:
	await _boot()
	await _enter("C01")
	await _look("C01", "C01_FLOOR")
	await h.press("UI_EVIDENCE", h.base())
	assert_true(h.button("UI_PRIMARY").disabled, "Q1 locked with FLOOR only")
	assert_true(h.button("UI_PRIMARY").sub_label.text.contains("Нужни са още улики"))
	await h.close()
	await _look("C01", "C01_WINDOW")
	await h.press("UI_EVIDENCE", h.base())
	assert_false(h.button("UI_PRIMARY").disabled, "Q1 enabled after WINDOW")

func test_at02_c01_manager_before_q1() -> void:
	await _boot()
	await _enter("C01")
	await h.tap_object("C01", "C01_MANAGER")
	assert_eq(h.route(), "C01_SCENE")
	assert_true(h.app.shell.toasts().has("Първо сравни прозореца и пода."), "locked toast")
	assert_false(h.run("C01")["evidence"].has("EV_C01_ADMISSION"))

func test_at03_c01_q1_correct_then_kill() -> void:
	await _boot()
	await _enter("C01")
	await _look("C01", "C01_WINDOW")
	await _look("C01", "C01_FLOOR")
	var st := await _open_deduction()
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	await h.kill_and_restart()
	assert_false(h.run("C01")["solved"], "no premature solve")
	await _enter("C01")
	await h.tap_object("C01", "C01_MANAGER")
	assert_eq(h.route(), "C01_INSPECT_MANAGER", "MANAGER unlocked after resume")

func test_at04_c02_phone_empty_charger_phone() -> void:
	await _boot(["C01"])
	await _enter("C02")
	await _look("C02", "C02_PHONE")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	await h.tap_object("C02", "C02_PHONE")
	var ev: Array = h.run("C02")["evidence"]
	assert_eq(ev.count("EV_C02_BATTERY"), 1, "BATTERY once")
	assert_true(ev.has("EV_C02_IDENTITY"), "IDENTITY on second inspect")
	var clue_events := h.analytics_names().filter(func(n): return n == "CLUE_DISCOVERED")
	assert_eq(clue_events.size(), 2)

func test_at05_c02_charger_first() -> void:
	await _boot(["C01"])
	await _enter("C02")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	await h.tap_object("C02", "C02_PHONE")
	assert_eq(h.run("C02")["evidence"], ["EV_C02_BATTERY", "EV_C02_IDENTITY"])
	await h.wait(CZ.CLUE_TOAST_DELAY_MS + 60)
	assert_true(h.app.shell.toasts().has("2 наблюдения добавени"))
	await h.close()
	await _look("C02", "C02_RECORD")
	await _look("C02", "C02_WATCH")
	var st := await _open_deduction()
	for e in ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	st = h.top() as StageModal
	st.choose_answer("C02_Q1_A2")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C02_SOLVED", "same solve reachable")

func test_at06_c02_wrong_set() -> void:
	await _boot(["C01"])
	await _enter("C02")
	await _look("C02", "C02_PHONE")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		await _look("C02", o)
	var before: Array = h.run("C02")["evidence"].duplicate()
	var st := await _open_deduction()
	for e in ["EV_C02_BATTERY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	assert_false(h.run("C02")["link_ok"], "wrong set")
	assert_eq(h.run("C02")["evidence"], before, "no evidence lost")
	assert_eq(st._feedback.text, "Батерията при огледа не определя какво е станало в 23:30.")

func test_at07_c02_wrong_final_answer() -> void:
	await _boot(["C01"])
	await _enter("C02")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		await _look("C02", o)
	var st := await _open_deduction()
	for e in ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	st = h.top() as StageModal
	st.choose_answer("C02_Q1_A1")
	st.press_submit()
	await h.settle()
	assert_eq(int(h.run("C02")["attempts"]), 1)
	assert_false(h.run("C02")["solved"])
	assert_eq(h.route(), "C02_DEDUCTION_Q1", "answer stays editable")
	assert_eq(st._answer_buttons["C02_Q1_A1"].state, CzButton.ERROR)
	st.choose_answer("C02_Q1_A2")
	assert_eq(st._answer_buttons["C02_Q1_A1"].state, CzButton.NORMAL, "error clears on new selection")

func test_at08_c03_arbitrary_order() -> void:
	await _boot(["C01", "C02"])
	await _enter("C03")
	for o in ["C03_PLATFORM", "C03_CLOCK", "C03_PHOTO", "C03_TIMETABLE"]:
		await _look("C03", o)
		assert_eq(_cta_kind("C03"), "blocked")
	await _look("C03", "C03_TICKET")
	var st := await _open_deduction()
	assert_eq(h.route(), "C03_TIMELINE", "5/5 unlocks timeline")
	assert_true(st != null)

func _c03_to_timeline() -> StageModal:
	await _boot(["C01", "C02"])
	await _enter("C03")
	for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
		await _look("C03", o)
	return await _open_deduction()

func test_at09_c03_occupied_slot() -> void:
	var st := await _c03_to_timeline()
	st.pick_token("TL_PHOTO"); st.pick_slot(1)
	st.pick_token("TL_CLAIM"); st.pick_slot(1)
	var tl: Array = h.run("C03")["timeline"]
	assert_eq(tl, [null, "TL_CLAIM", null], "old occupant unplaced")
	assert_eq(st._token_buttons["TL_PHOTO"].sub_label.text, "", "PHOTO back in pool (no slot badge)")
	assert_eq(st._token_buttons["TL_CLAIM"].sub_label.text, "→ 2")

func test_at10_c03_wrong_order() -> void:
	var st := await _c03_to_timeline()
	st.pick_token("TL_CLAIM"); st.pick_slot(0)
	st.pick_token("TL_DEPART"); st.pick_slot(1)
	st.pick_token("TL_PHOTO"); st.pick_slot(2)
	st.press_submit()
	await h.settle()
	assert_false(h.run("C03")["timeline_ok"])
	assert_eq(h.run("C03")["timeline"], ["TL_CLAIM", "TL_DEPART", "TL_PHOTO"], "array retained")
	assert_true(st._feedback.visible, "inline error")
	assert_eq(st._feedback.text, "Подреди по показаните часове. Началото на алибито е твърдение, не доказан факт.")

func test_at11_c03_correct_timeline_then_back() -> void:
	var st := await _c03_to_timeline()
	st.pick_token("TL_DEPART"); st.pick_slot(0)
	st.pick_token("TL_CLAIM"); st.pick_slot(1)
	st.pick_token("TL_PHOTO"); st.pick_slot(2)
	st.press_submit()
	await h.settle()
	await h.back()
	assert_eq(h.route(), "C03_EVIDENCE")
	assert_true(h.run("C03")["timeline_ok"], "timeline stays valid")
	await h.press("UI_EVIDENCE_CARD_EV_C03_PHOTO")
	assert_eq(h.route(), "C03_DETAIL_CARD", "evidence review available")

func test_at12_solve_then_kill_before_reward() -> void:
	await _boot()
	await _enter("C01")
	await _look("C01", "C01_WINDOW")
	await _look("C01", "C01_FLOOR")
	var st := await _open_deduction()
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	st.press_submit()
	await h.settle()
	await _look("C01", "C01_MANAGER")
	st = await _open_deduction()
	st.choose_answer("C01_Q2_A1")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C01_SOLVED")
	await h.kill_and_restart()
	assert_true(h.state()["campaign"]["completed"]["C01"])
	assert_true(h.state()["campaign"]["reward_granted"]["C01"])
	assert_eq(int(h.state()["campaign"]["xp"]), 100)
	await h.kill_and_restart()
	assert_eq(int(h.state()["campaign"]["xp"]), 100, "XP not doubled")

func test_at13_replay_all_three_keeps_300() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	fx.solve_c02()
	fx.solve_c03()
	h = UiHarness.new(Vector2(360, 640), 1.0, [0, 0, 0, 0], fx.backend)
	await h.boot()
	assert_eq(int(h.state()["campaign"]["xp"]), 300)
	for c in ["C01", "C02", "C03"]:
		await h.press("UI_BOARD_" + c, h.base())
		assert_eq(h.route(), c + "_CONFIRM_RESET")
		await h.press("UI_CONFIRM_YES")
		assert_eq(h.base_id(), c + "_INTRO")
		await h.back()
	await h.free_app()
	var fx2 := fx.kill_and_restart()   # deterministic ids continue past the journal
	for r in [fx2.solve_c01(), fx2.solve_c02(), fx2.solve_c03()]:
		assert_eq(r["code"], CZ.SOLVED, str(r["code"]) + " " + str(r.get("status")))
		assert_eq(int(r.get("data", {}).get("xp_delta", -1)), 0)
	h = UiHarness.new(Vector2(360, 640), 1.0, [0, 0, 0, 0], fx.backend)
	await h.boot()
	assert_eq(int(h.state()["campaign"]["xp"]), 300, "campaign XP stays 300")

func test_at14_double_tap_and_duplicate_dispatch() -> void:
	await _boot()
	await _enter("C01")
	var v := h.case_view()
	var hb: Array = h.ctx().db.case_def("C01").object("C01_WINDOW")["hitbox"]
	var c := Vector2(hb[0] + hb[2] * 0.5, hb[1] + hb[3] * 0.5)
	v.tap_canvas(c)
	v.tap_canvas(c)   # second tap lands while the modal opens: scene input locked
	await h.settle()
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])
	assert_eq(h.ctx().haptics.played.count("LIGHT"), 1, "one haptic")
	assert_eq(h.ctx().router.stack.size(), 1, "one panel")
	var a := h.ctx().store.make_action(CZ.SET_SETTING, {"key": "reduced_motion", "value": true})
	var r1 := h.ctx().store.dispatch(a)
	var idx := int(h.state()["interaction_index"])
	var r2 := h.ctx().store.dispatch(a)
	assert_eq(r1["status"], CZ.OK)
	assert_eq(r2["status"], CZ.DUPLICATE, "same action_id executes once")
	assert_eq(int(h.state()["interaction_index"]), idx, "deterministic state")

func test_at15_background_during_animation() -> void:
	await _boot()
	await _enter("C01")
	h.case_view().tap_canvas(Vector2(816, 576))   # C01_WINDOW centre; do not wait for the animation
	h.app.on_background()
	await h.kill_and_restart()                     # activity recreated / process killed mid-animation
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"], "finding committed before the animation")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "portrait locked")
	await _enter("C01")
	assert_eq(h.route(), "C01_SCENE")

func test_at16_font_2_small_phone() -> void:
	await _boot([], Vector2(360, 640), 2.0)
	await _enter("C01")
	await _look("C01", "C01_WINDOW")
	await _look("C01", "C01_FLOOR")
	var st := await _open_deduction()
	await h.frames(3)
	var m := h.ctx().metrics
	var sub := Rect2(st._submit.global_position, st._submit.size)
	assert_true(m.safe.grow(1).encloses(sub), "CTA on screen")
	var scroll_rect := Rect2(st.scroll.global_position, st.scroll.size)
	assert_false(sub.intersects(scroll_rect), "CTA does not cover text (footer outside scroll)")
	# Every answer is reachable by scrolling and wraps (no horizontal scroll).
	for k in st._answer_buttons:
		var b: CzButton = st._answer_buttons[k]
		st.scroll.ensure_control_visible(b)
		await h.frames(2)
		var br := Rect2(b.global_position, b.size)
		assert_true(scroll_rect.grow(2).intersects(br), k + " reachable by scroll")
		assert_true(b.label_node.autowrap_mode != TextServer.AUTOWRAP_OFF, k + " wraps")
		assert_eq(b.label_node.get_theme_font_size("font_size"), m.sp(UiStyle.BODY_SP), "font not reduced")
	assert_eq(st.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)

func test_at17_save_fails_on_solve() -> void:
	await _boot()
	await _enter("C01")
	await _look("C01", "C01_WINDOW")
	await _look("C01", "C01_FLOOR")
	var st := await _open_deduction()
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	st.press_submit()
	await h.settle()
	await _look("C01", "C01_MANAGER")
	st = await _open_deduction()
	st.choose_answer("C01_Q2_A1")
	h.ctx().store.repo.debug_fail_next = 1
	st.press_submit()
	await h.settle()
	assert_eq(h.route(), "G_WRITE_ERROR")
	assert_false(h.state()["campaign"]["completed"]["C01"], "no false committed success")
	assert_eq(int(h.state()["campaign"]["xp"]), 0)
	assert_true(h.base_id() != "C01_SOLVED")
	await h.press("UI_PRIMARY")   # retry once
	assert_eq(h.base_id(), "C01_SOLVED")
	assert_eq(int(h.state()["campaign"]["xp"]), 100)
	await h.kill_and_restart()
	assert_eq(int(h.state()["campaign"]["xp"]), 100)

func test_at18_tap_decoration() -> void:
	await _boot()
	await _enter("C01")
	var before := h.ctx().analytics.recent.size()
	var body: Array = h.ctx().db.case_def("C01").object("C01_BODY")["rect"]
	await h.tap_canvas(Vector2(body[0] + body[2] * 0.5, body[1] + body[3] * 0.5))   # covered body (decor)
	await h.tap_canvas(Vector2(540, 300))                                            # background wall
	assert_eq(h.route(), "C01_SCENE")
	assert_eq(h.ctx().analytics.recent.size(), before, "no clue feedback or event")
	assert_eq(h.ctx().audio.played.filter(func(s): return s == "SFX_CLUE_FOUND").size(), 0)
	await h.tap_object("C01", "C01_WINDOW")
	assert_eq(h.route(), "C01_INSPECT_WINDOW", "no input obstruction afterwards")

func test_at19_sound_haptics_off() -> void:
	await _boot()
	await _enter("C01")
	h.ctx().perform(CZ.SET_SETTING, {"key": "sound", "value": false})
	h.ctx().perform(CZ.SET_SETTING, {"key": "haptic", "value": false})
	await h.tap_object("C01", "C01_WINDOW")
	await h.wait(CZ.CLUE_TOAST_DELAY_MS + 60)
	assert_true(h.app.shell.toasts().has("Улика открита"), "visual clue feedback without audio")
	assert_eq(h.ctx().haptics.played, [])
	await h.close()
	await _look("C01", "C01_FLOOR")
	var st := await _open_deduction()
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	st.press_submit()
	await h.settle()
	await _look("C01", "C01_MANAGER")
	st = await _open_deduction()
	st.choose_answer("C01_Q2_A1")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C01_SOLVED", "full playable flow")

func test_at20_hint3_all_clues_collected() -> void:
	await _boot(["C01"])
	await _enter("C02")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		await _look("C02", o)
	for i in 3:
		if h.route() != "C02_HINT":
			await h.press("UI_HINT", h.base())
		else:
			await h.press("UI_PRIMARY")
	assert_eq(int(h.run("C02")["hint_level"]), 3)
	await h.close()
	var target := Selectors.hint_target(h.ctx().db.case_def("C02"), h.run("C02"), h.state()["campaign"])
	assert_eq(target, Selectors.UI_EVIDENCE, "points to the current reasoning stage")
	assert_true(h.case_view()._pulses.is_empty(), "no scene object pulses")
