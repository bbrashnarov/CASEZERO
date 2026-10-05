extends TestCase
## C02, C03 and the campaign ending through the real UI shell. Earlier cases are solved through
## the domain fixture on the same storage, so each test starts where a player would.

var h: UiHarness

func after_each() -> void:
	if h:
		await h.cleanup()

func _boot_after(solved: Array) -> Fx:
	var fx := Fx.new()
	if solved.has("C01"):
		fx.solve_c01()
	if solved.has("C02"):
		fx.solve_c02()
	h = UiHarness.new(Vector2(360, 800), 1.0, [0, 0, 0, 0], fx.backend)
	await h.boot()
	return fx

func _enter(cid: String) -> void:
	assert_eq(h.base_id(), "G_BOARD")
	await h.press("UI_BOARD_" + cid, h.base())
	assert_eq(h.base_id(), cid + "_INTRO")
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.route(), cid + "_SCENE")

func _inspect_close(cid: String, oid: String) -> void:
	await h.tap_object(cid, oid)
	assert_eq(h.route(), "%s_INSPECT_%s" % [cid, oid.substr(4)])
	await h.close()

func test_c02_full_flow_with_charger_and_connect() -> void:
	await _boot_after(["C01"])
	await _enter("C02")
	# Phone first: empty battery.
	await h.tap_object("C02", "C02_PHONE")
	assert_eq(h.label_text("DetailText"), "При намиране: 0%. Не знаем кога е изгаснал.")
	await h.close()
	# Charger: panel with the local CTA; opening never charges.
	await h.tap_object("C02", "C02_CHARGER")
	assert_eq(h.run("C02")["phone_power"], "EMPTY")
	var cta := h.button("UI_PRIMARY")
	assert_eq(cta.label_node.text, "Свържи")
	await h.press("UI_PRIMARY")
	assert_eq(h.run("C02")["charger"], "CONNECTED")
	assert_eq(h.run("C02")["phone_power"], "RESTORED")
	assert_eq(h.route(), "C02_INSPECT_CHARGER", "panel stays open after connect")
	assert_true(h.all_text().contains("След кратко зареждане…"))
	assert_eq(h.button("UI_PRIMARY").label_node.text, "Свързан")
	assert_true(h.button("UI_PRIMARY").disabled)
	assert_true(h.ctx().audio.played.has("SFX_CONNECT"))
	await h.close()
	assert_eq(h.case_view().ctx.run("C02")["charger"], "CONNECTED")
	await h.tap_object("C02", "C02_PHONE")
	assert_eq(h.label_text("DetailText"), "Собственик: Иво; номер B. Последен запис A → B: ден D, 22:48, пропуснат, 0 s.")
	await h.close()
	await _inspect_close("C02", "C02_RECORD")
	await _inspect_close("C02", "C02_WATCH")
	assert_eq(h.button("UI_EVIDENCE", h.base()).label_node.text, "Улики 3/3")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	assert_eq(h.route(), "C02_CONNECT")
	var st := h.top() as StageModal
	assert_eq(st._evidence_buttons.size(), 4, "all discovered cards incl. battery")
	assert_eq(st._submit.label_node.text, "Свържи")
	for e in ["EV_C02_BATTERY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	assert_false(st._submit.disabled, "exactly three enables submit")
	st.toggle("EV_C02_IDENTITY")
	assert_eq(st._selected_evidence.size(), 3, "a fourth selection is refused")
	st.press_submit()
	await h.settle()
	assert_eq(int(h.run("C02")["attempts"]), 1)
	assert_true(st._feedback.visible)
	assert_eq(st._selected_evidence.size(), 3, "selection retained after wrong set")
	st.toggle("EV_C02_BATTERY")
	st.toggle("EV_C02_IDENTITY")
	st.press_submit()
	await h.settle()
	assert_eq(h.route(), "C02_DEDUCTION_Q1", "valid set continues to Q1")
	st = h.top() as StageModal
	st.choose_answer("C02_Q1_A2")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C02_SOLVED")
	assert_eq(int(h.state()["campaign"]["xp"]), 200)
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "C02_REWARD")
	assert_true(h.all_text(h.base()).contains("Следващият случай е отключен"))
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "C03_INTRO")
	assert_true(h.analytics_names().has("CHARGER_CONNECTED"))

func test_c02_charger_kill_restores_connected_state() -> void:
	await _boot_after(["C01"])
	await _enter("C02")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.kill_and_restart()
	assert_eq(h.run("C02")["charger"], "CONNECTED")
	await h.press("UI_BOARD_C02", h.base())
	await h.tap_object("C02", "C02_CHARGER")
	assert_true(h.button("UI_PRIMARY").disabled, "CTA disabled once connected")

func test_c03_timeline_link_and_campaign_end() -> void:
	await _boot_after(["C01", "C02"])
	await _enter("C03")
	for o in ["C03_PLATFORM", "C03_PHOTO", "C03_CLOCK", "C03_TICKET", "C03_TIMETABLE"]:
		await _inspect_close("C03", o)
	assert_eq(h.button("UI_EVIDENCE", h.base()).label_node.text, "Улики 5/5")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	assert_eq(h.route(), "C03_TIMELINE")
	var st := h.top() as StageModal
	assert_eq(st._token_buttons.keys(), ["TL_PHOTO", "TL_DEPART", "TL_CLAIM"], "display order PHOTO, DEPART, CLAIM")
	st.pick_slot(0)
	await h.settle()
	assert_true(h.app.shell.toasts().has("Първо избери събитие"), "slot without token: hint toast, no penalty")
	assert_eq(int(h.run("C03")["attempts"]), 0)
	# Wrong order first.
	st.pick_token("TL_PHOTO"); st.pick_slot(0)
	st.pick_token("TL_DEPART"); st.pick_slot(1)
	assert_true(st._submit.disabled, "submit needs all three slots")
	st.pick_token("TL_CLAIM"); st.pick_slot(2)
	await h.settle()
	assert_eq(h.run("C03")["timeline"], ["TL_PHOTO", "TL_DEPART", "TL_CLAIM"], "every placement persists")
	st.press_submit()
	await h.settle()
	assert_eq(int(h.run("C03")["attempts"]), 1)
	assert_false(h.run("C03")["timeline_ok"])
	# Close mid-way and come back: slots are kept.
	await h.close()
	await h.close()
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	st = h.top() as StageModal
	assert_eq(h.run("C03")["timeline"], ["TL_PHOTO", "TL_DEPART", "TL_CLAIM"])
	st.pick_token("TL_DEPART"); st.pick_slot(0)
	assert_eq(h.run("C03")["timeline"], ["TL_DEPART", null, "TL_CLAIM"], "displaced PHOTO back in the pool")
	st.pick_token("TL_CLAIM"); st.pick_slot(1)
	st.pick_token("TL_PHOTO"); st.pick_slot(2)
	st.press_submit()
	await h.settle()
	assert_true(h.run("C03")["timeline_ok"])
	assert_eq(h.route(), "C03_LINK")
	st = h.top() as StageModal
	assert_eq(st._evidence_buttons.size(), 5)
	for e in ["EV_C03_PHOTO", "EV_C03_CLOCK_SYNC", "EV_C03_PLATFORM"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	assert_eq(h.route(), "C03_DEDUCTION_Q1")
	st = h.top() as StageModal
	st.choose_answer("C03_Q1_A0")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C03_SOLVED")
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "C03_REWARD")
	assert_eq(int(h.state()["campaign"]["xp"]), 300)
	assert_eq(h.label_text("XpTotal", h.base()), "Общо Detective XP: 300")
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "G_END")
	assert_eq(h.label_text("EndText", h.base()), "Три случая. Една нова следа: АРХИВ 0.")
	await h.press("UI_PRIMARY", h.base())
	assert_eq(h.base_id(), "G_BOARD")
	for c in ["C01", "C02", "C03"]:
		assert_true(h.button("UI_BOARD_" + c, h.base()).sub_label.text.contains("Решен"), c + " solved stamp")

func test_at11_timeline_back_keeps_progress() -> void:
	await _boot_after(["C01", "C02"])
	await _enter("C03")
	for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
		await _inspect_close("C03", o)
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	st.pick_token("TL_DEPART"); st.pick_slot(0)
	st.pick_token("TL_CLAIM"); st.pick_slot(1)
	st.pick_token("TL_PHOTO"); st.pick_slot(2)
	st.press_submit()
	await h.settle()
	assert_eq(h.route(), "C03_LINK")
	await h.back()
	assert_eq(h.route(), "C03_EVIDENCE", "Back from LINK -> evidence review")
	await h.press("UI_EVIDENCE_CARD_EV_C03_TICKET")
	assert_eq(h.route(), "C03_DETAIL_CARD")
	assert_eq(h.ctx().router.current()["evidence_id"], "EV_C03_TICKET")
	await h.back()
	await h.back()
	assert_eq(h.route(), "C03_SCENE")
	assert_true(h.run("C03")["timeline_ok"], "timeline stays valid")
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	assert_eq(h.route(), "C03_LINK", "LINK remains the next stage")

func test_at19_sound_and_haptics_off_full_flow() -> void:
	await _boot_after(["C01"])
	h.ctx().perform(CZ.SET_SETTING, {"key": "sound", "value": false})
	h.ctx().perform(CZ.SET_SETTING, {"key": "haptic", "value": false})
	await _enter("C02")
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		await _inspect_close("C02", o)
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	for e in ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	st = h.top() as StageModal
	st.choose_answer("C02_Q1_A2")
	st.press_submit()
	await h.settle()
	assert_eq(h.base_id(), "C02_SOLVED", "fully playable without audio/haptics")
	assert_eq(h.ctx().haptics.played, [], "no haptics when disabled")
