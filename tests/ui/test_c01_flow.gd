extends TestCase
## C01 end-to-end through the real UI shell (App -> Router -> screens/modals -> Store -> save).

var h: UiHarness

func after_each() -> void:
	if h:
		await h.cleanup()

func _boot(device := Vector2(360, 640), fs := 1.0) -> void:
	h = UiHarness.new(device, fs)
	await h.boot()

func _to_scene() -> void:
	await _boot()
	await h.press("UI_PRIMARY")
	await h.frames(2)

func _find_and_close(oid: String) -> void:
	await h.tap_object("C01", oid)
	await h.close()

func test_fresh_install_opens_c01_intro() -> void:
	await _boot()
	assert_eq(h.base_id(), "C01_INTRO")
	assert_true(h.all_text(h.base()).contains(h.ctx().db.case_def("C01").opening_text()), "opening text visible")
	assert_eq(h.button("UI_PRIMARY", h.base()).label_node.text, "Разследвай")
	assert_true(h.analytics_names().has("APP_STARTED"))
	assert_eq(h.app.ctx.analytics.recent[0]["fresh_install"], true)

func test_c01_complete_flow() -> void:
	await _to_scene()
	assert_eq(h.route(), "C01_SCENE")
	assert_true(h.run("C01")["started"])
	# Window -> RAIN
	await h.tap_object("C01", "C01_WINDOW")
	assert_eq(h.route(), "C01_INSPECT_WINDOW")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])
	await h.wait(CZ.CLUE_TOAST_DELAY_MS + 60)
	assert_true(h.app.shell.toasts().has("Улика открита"), "clue toast shown after 180 ms")
	await h.close()
	assert_eq(h.route(), "C01_SCENE")
	await _find_and_close("C01_FLOOR")
	assert_eq(h.button("UI_EVIDENCE", h.base()).label_node.text, "Улики 2/3")
	# Evidence panel -> Q1
	await h.press("UI_EVIDENCE", h.base())
	assert_eq(h.route(), "C01_EVIDENCE")
	assert_false(h.button("UI_PRIMARY").disabled, "deduction CTA enabled with RAIN + DRY_FLOOR")
	await h.press("UI_PRIMARY")
	assert_eq(h.route(), "C01_DEDUCTION_Q1")
	var st := h.top() as StageModal
	assert_true(st._submit.disabled, "submit disabled until an answer is selected")
	st.choose_answer("C01_Q1_A1")
	st.press_submit()
	await h.settle()
	assert_eq(int(h.run("C01")["attempts"]), 1)
	assert_true(st._feedback.visible, "wrong feedback visible")
	assert_eq(h.route(), "C01_DEDUCTION_Q1")
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	assert_true(h.run("C01")["questions"]["C01_Q1"])
	assert_eq(st._submit.label_node.text, "Към показанията")
	st.press_submit()
	await h.settle()
	assert_eq(h.route(), "C01_SCENE")
	# Manager now open -> ADMISSION
	await h.tap_object("C01", "C01_MANAGER")
	assert_eq(h.route(), "C01_INSPECT_MANAGER")
	await h.close()
	assert_eq(h.button("UI_EVIDENCE", h.base()).label_node.text, "Улики 3/3")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	assert_eq(h.route(), "C01_DEDUCTION_Q2")
	st = h.top() as StageModal
	st.choose_answer("C01_Q2_A1")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C01_SOLVED")
	assert_false(h.app.ctx.router.has_modal())
	assert_true(h.state()["campaign"]["completed"]["C01"])
	assert_eq(int(h.state()["campaign"]["xp"]), 100)
	assert_true(h.all_text(h.base()).contains(h.ctx().db.case_def("C01").solved_text()))
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "C01_REWARD")
	await h.wait(CZ.AN_XP_MS + 100)
	assert_eq(h.label_text("XpDelta", h.base()), "+100 XP")
	var names := h.analytics_names()
	for n in ["APP_STARTED", "CASE_STARTED", "OBJECT_TAPPED", "OBJECT_INSPECTED", "CLUE_DISCOVERED", "EVIDENCE_ADDED",
			"EVIDENCE_OPENED", "DEDUCTION_OPENED", "DEDUCTION_SUBMITTED", "DEDUCTION_FAILED", "DEDUCTION_SUCCEEDED",
			"CASE_SOLVED", "REWARD_VIEWED"]:
		assert_true(names.has(n), "analytics has " + n)
	# Persisted: a new process sees the solve.
	await h.kill_and_restart()
	assert_eq(h.base_id(), "G_BOARD")
	assert_true(h.state()["campaign"]["completed"]["C01"])
	assert_eq(int(h.state()["campaign"]["xp"]), 100)

func test_locked_manager_gives_feedback_without_inspection() -> void:
	await _to_scene()
	await h.tap_object("C01", "C01_MANAGER")
	assert_eq(h.route(), "C01_SCENE", "locked manager opens no panel")
	assert_eq(h.run("C01")["objects"]["C01_MANAGER"]["inspection"], CZ.UNSEEN)
	var locked_text := str(h.ctx().db.case_def("C01").object("C01_MANAGER")["locked_text"])
	assert_true(h.app.shell.toasts().has(locked_text), "locked text shown")
	assert_true(h.analytics_names().has("OBJECT_TAPPED"))
	assert_false(h.analytics_names().has("OBJECT_INSPECTED"))

func test_empty_tap_does_nothing() -> void:
	await _to_scene()
	var before := h.app.ctx.analytics.recent.size()
	var idx := int(h.state()["interaction_index"])
	await h.tap_canvas(Vector2(500, 600))   # wall between clock and window
	assert_eq(h.route(), "C01_SCENE")
	assert_eq(h.app.ctx.analytics.recent.size(), before, "no event on empty tap")
	assert_eq(int(h.state()["interaction_index"]), idx)

func test_repeat_inspection_shows_seen_label() -> void:
	await _to_scene()
	await _find_and_close("C01_CUP")
	await h.tap_object("C01", "C01_CUP")
	assert_true(h.find(h.top(), "RepeatLabel") != null, "Прегледано on repeat")
	assert_eq(h.run("C01")["evidence"], [], "optional object adds no evidence")

func test_hint_escalation_and_repeat() -> void:
	await _to_scene()
	await h.press("UI_HINT", h.base())
	assert_eq(h.route(), "C01_HINT")
	assert_eq(int(h.run("C01")["hint_level"]), 1)
	assert_eq(h.label_text("HintText"), "Виж зоната между прозореца и пода.")
	await h.press("UI_PRIMARY")
	assert_eq(int(h.run("C01")["hint_level"]), 2)
	await h.press("UI_PRIMARY")
	assert_eq(int(h.run("C01")["hint_level"]), 3)
	assert_eq(h.button("UI_PRIMARY").label_node.text, "Повтори насоката")
	await h.press("UI_PRIMARY")
	assert_eq(int(h.run("C01")["hint_level"]), 3, "level never exceeds 3")
	await h.close()
	assert_eq(h.route(), "C01_SCENE")
	assert_true(h.case_view()._pulses.has("C01_WINDOW"), "hint target pulses after close")
	# Reopen keeps the level (no new escalation on reopen).
	await h.press("UI_HINT", h.base())
	assert_eq(int(h.run("C01")["hint_level"]), 3)

func test_android_back_contract() -> void:
	await _boot()
	assert_true(await h.back(), "Back on INTRO is handled")
	assert_eq(h.base_id(), "G_BOARD")
	assert_false(await h.back(), "Back on BOARD leaves the app")
	await h.press("UI_BOARD_C01", h.base())
	assert_eq(h.base_id(), "C01_INTRO")
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.route(), "C01_SCENE")
	await h.tap_object("C01", "C01_WINDOW")
	assert_true(await h.back())
	assert_eq(h.route(), "C01_SCENE", "Back closes inspect")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"], "Back never loses a committed finding")
	assert_true(await h.back())
	assert_eq(h.route(), "C01_PAUSE")
	assert_true(await h.back())
	assert_eq(h.route(), "C01_SCENE", "Back on pause resumes")
	await h.back()
	await h.press("UI_PAUSE_RESTART")
	assert_eq(h.route(), "C01_CONFIRM_RESET")
	assert_true(await h.back())
	assert_eq(h.route(), "C01_PAUSE", "Back on confirm = No")
	await h.press("UI_PAUSE_BOARD")
	assert_eq(h.base_id(), "G_BOARD")
	assert_true(h.analytics_names().has("CASE_EXITED"))
	# Resume from board -> SCENE with progress.
	await h.press("UI_BOARD_C01", h.base())
	assert_eq(h.route(), "C01_SCENE")
	assert_true(h.analytics_names().has("CASE_RESUMED"))
	# Back from a deduction never submits.
	await _find_and_close("C01_FLOOR")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	st.choose_answer("C01_Q1_A1")
	await h.back()
	assert_eq(h.route(), "C01_EVIDENCE")
	assert_eq(int(h.run("C01")["attempts"]), 0, "Back is not an attempt")

func test_process_kill_restores_progress() -> void:
	await _to_scene()
	await h.tap_object("C01", "C01_WINDOW")
	# Killed while the inspect panel is open: the clue was committed before the panel opened.
	await h.kill_and_restart()
	assert_eq(h.base_id(), "G_BOARD", "later sessions start on the Board")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])
	await h.press("UI_BOARD_C01", h.base())
	assert_eq(h.route(), "C01_SCENE", "started run resumes in SCENE")
	assert_eq(h.button("UI_EVIDENCE", h.base()).label_node.text, "Улики 1/3")
	# Q1 progress survives too; runtime selections do not.
	await _find_and_close("C01_FLOOR")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	st.choose_answer("C01_Q1_A0")
	st.press_submit()
	await h.settle()
	await h.kill_and_restart()
	assert_true(h.run("C01")["questions"]["C01_Q1"])
	await h.press("UI_BOARD_C01", h.base())
	await h.tap_object("C01", "C01_MANAGER")
	assert_eq(h.route(), "C01_INSPECT_MANAGER", "gate stays open after restart")

func test_write_failure_retry_and_revert() -> void:
	await _to_scene()
	h.ctx().store.repo.debug_fail_next = 1
	await h.tap_object("C01", "C01_WINDOW")
	assert_eq(h.route(), "G_WRITE_ERROR")
	assert_eq(h.run("C01")["evidence"], [], "live state unchanged while unsaved")
	assert_true(h.analytics_names().has("SAVE_FAILED"))
	await h.press("UI_PRIMARY")   # Retry
	assert_eq(h.route(), "C01_INSPECT_WINDOW", "retry continues to the inspect panel")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])
	await h.close()
	h.ctx().store.repo.debug_fail_next = 1
	await h.tap_object("C01", "C01_FLOOR")
	assert_eq(h.route(), "G_WRITE_ERROR")
	await h.press("UI_REVERT")
	assert_eq(h.route(), "C01_SCENE")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"], "revert keeps last committed snapshot")
	await h.kill_and_restart()
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"])

func test_replay_keeps_campaign_and_grants_zero_xp() -> void:
	await _to_scene()
	var fx_solve := func():
		await _find_and_close("C01_WINDOW")
		await _find_and_close("C01_FLOOR")
		await h.press("UI_EVIDENCE", h.base())
		await h.press("UI_PRIMARY")
		var s1 := h.top() as StageModal
		s1.choose_answer("C01_Q1_A0")
		s1.press_submit()
		await h.settle()
		s1.press_submit()
		await h.settle()
		await _find_and_close("C01_MANAGER")
		await h.press("UI_EVIDENCE", h.base())
		await h.press("UI_PRIMARY")
		var s2 := h.top() as StageModal
		s2.choose_answer("C01_Q2_A1")
		s2.press_submit()
		await h.settle()
	await fx_solve.call()
	assert_eq(h.base_id(), "C01_SOLVED")
	await h.press("UI_PRIMARY", h.base())
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "C02_INTRO", "reward 'Следващ случай' opens C02")
	await h.back()
	assert_eq(h.base_id(), "G_BOARD")
	await h.press("UI_BOARD_C01", h.base())
	assert_eq(h.route(), "C01_CONFIRM_RESET", "solved card asks for replay confirmation")
	await h.press("UI_CONFIRM_NO")
	assert_eq(h.route(), "G_BOARD")
	await h.press("UI_BOARD_C01", h.base())
	await h.press("UI_CONFIRM_YES")
	assert_eq(h.base_id(), "C01_INTRO")
	assert_true(h.state()["campaign"]["completed"]["C01"], "completion survives reset")
	assert_eq(int(h.state()["campaign"]["xp"]), 100)
	assert_true(h.analytics_names().has("CASE_RESTARTED"))
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.run("C01")["evidence"], [], "new run starts clean")
	await fx_solve.call()
	assert_eq(h.base_id(), "C01_SOLVED")
	assert_eq(h.app.shell.base_node.title_label.text, "Случаят е решен отново • +0 XP")
	await h.press("UI_PRIMARY", h.base())
	await h.wait(CZ.AN_XP_MS + 100)
	assert_eq(h.label_text("XpDelta", h.base()), "+0 XP")
	assert_eq(int(h.state()["campaign"]["xp"]), 100, "replay grants 0 XP")
