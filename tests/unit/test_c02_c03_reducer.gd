extends TestCase
## C02 / C03 domain behaviour and campaign progression through the real Store.

var fx: Fx

func before_each() -> void:
	fx = Fx.new()

func _open_c02() -> void:
	fx.solve_c01()
	fx.start("C02")

func _open_c03() -> void:
	fx.solve_c01()
	fx.solve_c02()
	fx.start("C03")

# --- campaign ---------------------------------------------------------------------------

func test_c02_locked_until_c01_solved() -> void:
	var r := fx.start("C02")
	assert_eq(r["code"], CZ.CASE_LOCKED)
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C02"), "locked")
	fx.solve_c01()
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C02"), "new")
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C03"), "locked")

func test_campaign_three_first_solves_give_300_xp() -> void:
	fx.solve_c01()
	var r2 := fx.solve_c02()
	assert_eq(r2["code"], CZ.SOLVED)
	assert_eq(int(r2["data"]["xp_delta"]), 100)
	var r3 := fx.solve_c03()
	assert_eq(r3["code"], CZ.SOLVED)
	assert_eq(int(fx.state()["campaign"]["xp"]), 300)
	for c in ["C01", "C02", "C03"]:
		assert_true(fx.state()["campaign"]["completed"][c], c)

func test_at13_replay_all_three_keeps_300() -> void:
	fx.solve_c01()
	fx.solve_c02()
	fx.solve_c03()
	for c in ["C01", "C02", "C03"]:
		fx.reset(c)
		var r: Dictionary
		match c:
			"C01": r = fx.solve_c01()
			"C02": r = fx.solve_c02()
			"C03": r = fx.solve_c03()
		assert_eq(r["code"], CZ.SOLVED, c)
		assert_eq(int(r["data"]["xp_delta"]), 0, c + " replay xp")
		assert_true(r["data"]["replay"], c + " replay flag")
	assert_eq(int(fx.state()["campaign"]["xp"]), 300)
	var again := fx.kill_and_restart()
	assert_eq(int(again.state()["campaign"]["xp"]), 300)

# --- C02 ----------------------------------------------------------------------------------

func test_at04_phone_empty_then_charger_then_phone() -> void:
	_open_c02()
	var r1 := fx.inspect("C02", "C02_PHONE")
	assert_eq(r1["data"]["detail_text"], "При намиране: 0%. Не знаем кога е изгаснал.")
	assert_eq(fx.run("C02")["evidence"], ["EV_C02_BATTERY"])
	assert_eq(r1["feedback"]["toast"], "Улика открита")
	fx.inspect("C02", "C02_CHARGER")
	var c := fx.connect_charger("C02", "C02_CHARGER")
	assert_eq(c["status"], CZ.OK)
	assert_eq(fx.run("C02")["charger"], "CONNECTED")
	assert_eq(fx.run("C02")["phone_power"], "RESTORED")
	assert_eq(event_names(c), ["CHARGER_CONNECTED"])
	assert_eq(c["events"][0]["props"]["prior_power"], "EMPTY")
	assert_eq(c["events"][0]["props"]["object_id"], "C02_CHARGER")
	assert_eq(c["feedback"]["sfx"], ["SFX_CONNECT"])
	assert_eq(fx.run("C02")["evidence"], ["EV_C02_BATTERY"], "charging adds no evidence by itself")
	var r2 := fx.inspect("C02", "C02_PHONE")
	assert_eq(r2["data"]["detail_text"], "Собственик: Иво; номер B. Последен запис A → B: ден D, 22:48, пропуснат, 0 s.")
	assert_eq(fx.run("C02")["evidence"], ["EV_C02_BATTERY", "EV_C02_IDENTITY"], "BATTERY once, IDENTITY on second inspect")
	assert_eq(r2["feedback"]["toast"], "Улика открита")
	assert_eq(fx.run("C02")["objects"]["C02_PHONE"]["inspection"], CZ.SEEN, "phone stays SEEN")
	assert_false(r2["data"]["first_inspection"])
	assert_false(r2["data"]["repeat"], "a new evidence branch is a finding, not a plain repeat")

func test_at05_charger_first_then_phone_gives_both() -> void:
	_open_c02()
	fx.inspect("C02", "C02_CHARGER")
	fx.connect_charger("C02", "C02_CHARGER")
	var r := fx.inspect("C02", "C02_PHONE")
	assert_eq(fx.run("C02")["evidence"], ["EV_C02_BATTERY", "EV_C02_IDENTITY"])
	assert_eq(r["feedback"]["toast"], "2 наблюдения добавени")
	assert_eq(r["feedback"]["haptic"], CZ.HAPTIC_LIGHT)
	assert_eq(r["feedback"]["sfx"].count("SFX_CLUE_FOUND"), 1, "one clue sound/haptic for both")
	var res := fx.solve_c02()
	assert_eq(res["code"], CZ.SOLVED, "same solve reachable")

func test_charger_cta_requires_open_panel_and_is_idempotent() -> void:
	_open_c02()
	fx.scene("C02")
	var r := fx.act(CZ.CONNECT_CHARGER, {"case_id": "C02", "object_id": "C02_CHARGER"})
	assert_eq(r["code"], CZ.ROUTE_INVALID, "CTA only from C02_INSPECT_CHARGER")
	fx.inspect("C02", "C02_CHARGER")
	fx.connect_charger("C02", "C02_CHARGER")
	var again := fx.connect_charger("C02", "C02_CHARGER")
	assert_eq(again["status"], CZ.NOOP)
	assert_eq(fx.names().count("CHARGER_CONNECTED"), 1)

func test_c02_connect_locked_until_three_required() -> void:
	_open_c02()
	fx.inspect("C02", "C02_PHONE")
	fx.inspect("C02", "C02_RECORD")
	fx.inspect("C02", "C02_WATCH")
	var cta := Selectors.deduction_cta(fx.db.case_def("C02"), fx.run("C02"), fx.state()["campaign"])
	assert_eq(cta["kind"], "blocked", "IDENTITY missing -> disabled")
	var r := fx.select_set("C02", "C02_CONNECT", ["EV_C02_BATTERY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"])
	assert_eq(r["code"], CZ.PRECONDITION_MISSING)
	assert_eq(int(fx.run("C02")["attempts"]), 0, "premature submit is not an attempt")

func test_at06_wrong_set_keeps_evidence() -> void:
	_open_c02()
	fx.inspect("C02", "C02_PHONE")
	fx.inspect("C02", "C02_CHARGER")
	fx.connect_charger("C02", "C02_CHARGER")
	fx.inspect("C02", "C02_PHONE")
	fx.inspect("C02", "C02_RECORD")
	fx.inspect("C02", "C02_WATCH")
	var before: Array = fx.run("C02")["evidence"].duplicate()
	var r := fx.select_set("C02", "C02_CONNECT", ["EV_C02_BATTERY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"])
	assert_eq(r["code"], CZ.WRONG)
	assert_eq(r["data"]["feedback"], "Батерията при огледа не определя какво е станало в 23:30.")
	assert_eq(int(fx.run("C02")["attempts"]), 1)
	assert_false(fx.run("C02")["link_ok"])
	assert_eq(fx.run("C02")["evidence"], before, "no evidence lost")
	var bad_count := fx.select_set("C02", "C02_CONNECT", ["EV_C02_NETWORK", "EV_C02_WATCH_LOG"])
	assert_eq(bad_count["code"], CZ.INVALID_SELECTION, "exactly three")
	var ok := fx.select_set("C02", "C02_CONNECT", ["EV_C02_WATCH_LOG", "EV_C02_IDENTITY", "EV_C02_NETWORK"])
	assert_eq(ok["code"], CZ.CORRECT, "order-independent")
	assert_true(fx.run("C02")["link_ok"])
	assert_eq(ok["data"]["next_screen"], "C02_DEDUCTION_Q1")
	assert_eq(ok["feedback"]["sfx"], ["SFX_DEDUCTION_CORRECT"])
	assert_eq(ok["feedback"]["haptic"], CZ.HAPTIC_NONE)

func test_at07_wrong_final_answer() -> void:
	_open_c02()
	fx.inspect("C02", "C02_CHARGER")
	fx.connect_charger("C02", "C02_CHARGER")
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		fx.inspect("C02", o)
	fx.select_set("C02", "C02_CONNECT", ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"])
	var r := fx.answer("C02", "C02_Q1", "C02_Q1_A0")
	assert_eq(r["code"], CZ.WRONG)
	assert_eq(int(fx.run("C02")["attempts"]), 1)
	assert_false(fx.run("C02")["solved"])
	assert_false(fx.run("C02")["questions"]["C02_Q1"])
	assert_eq(r["data"]["feedback"], "Сравни вид обаждане, номера, интервал и статус. Батерията при огледа не доказва миналото.")
	var ok := fx.answer("C02", "C02_Q1", "C02_Q1_A2")
	assert_eq(ok["code"], CZ.SOLVED, "answer remains editable")

func test_c02_invariant_charger_iff_restored() -> void:
	_open_c02()
	var s := fx.state().duplicate(true)
	s["runs"]["C02"]["charger"] = "CONNECTED"
	var rep := GameState.check(s, fx.db)
	assert_true(rep["runs"].has("C02"), "CONNECTED with EMPTY phone is invalid")
	s["runs"]["C02"]["phone_power"] = "RESTORED"
	assert_false(GameState.check(s, fx.db)["runs"].has("C02"))

func test_c02_hint_targets() -> void:
	_open_c02()
	var def := fx.db.case_def("C02")
	var t := func(): return Selectors.hint_target(def, fx.run("C02"), fx.state()["campaign"])
	assert_eq(t.call(), "C02_CHARGER")
	fx.inspect("C02", "C02_PHONE")
	assert_eq(t.call(), "C02_CHARGER", "SEEN phone without IDENTITY does not satisfy")
	fx.inspect("C02", "C02_CHARGER")
	fx.connect_charger("C02", "C02_CHARGER")
	assert_eq(t.call(), "C02_PHONE")
	fx.inspect("C02", "C02_PHONE")
	assert_eq(t.call(), "C02_RECORD")
	fx.inspect("C02", "C02_RECORD")
	assert_eq(t.call(), "C02_WATCH")
	fx.inspect("C02", "C02_WATCH")
	assert_eq(t.call(), Selectors.UI_EVIDENCE, "AT20: after required evidence -> current reasoning stage")

# --- C03 ----------------------------------------------------------------------------------

func test_at08_arbitrary_order_unlocks_timeline() -> void:
	_open_c03()
	var def := fx.db.case_def("C03")
	for o in ["C03_PLATFORM", "C03_PHOTO", "C03_CLOCK", "C03_TICKET"]:
		fx.inspect("C03", o)
		assert_eq(Selectors.deduction_cta(def, fx.run("C03"), fx.state()["campaign"])["kind"], "blocked")
	fx.inspect("C03", "C03_TIMETABLE")
	var cta := Selectors.deduction_cta(def, fx.run("C03"), fx.state()["campaign"])
	assert_eq(cta["kind"], "open")
	assert_eq(cta["stage"]["id"], "C03_TIMELINE")
	assert_eq(Selectors.required_found(def, fx.run("C03")), 5)

func _five() -> void:
	for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
		fx.inspect("C03", o)

func test_at09_place_into_occupied_slot() -> void:
	_open_c03()
	_five()
	fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 0)
	var r := fx.place("C03", "C03_TIMELINE", "TL_DEPART", 0)
	assert_eq(fx.run("C03")["timeline"], ["TL_DEPART", null, null], "old occupant returns to the pool")
	assert_eq(r["events"].back()["props"]["displaced_token"], "TL_PHOTO")
	fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 2)
	fx.place("C03", "C03_TIMELINE", "TL_DEPART", 1)
	assert_eq(fx.run("C03")["timeline"], [null, "TL_DEPART", "TL_PHOTO"], "moving a token clears its old slot")
	var tl: Array = fx.run("C03")["timeline"]
	assert_eq(tl.filter(func(x): return x == "TL_DEPART").size(), 1, "no duplicate tokens")

func test_at10_wrong_order() -> void:
	_open_c03()
	_five()
	fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 0)
	fx.place("C03", "C03_TIMELINE", "TL_DEPART", 1)
	var incomplete := fx.submit_timeline("C03", "C03_TIMELINE")
	assert_eq(incomplete["code"], CZ.INVALID_SELECTION, "submit needs all three")
	assert_eq(int(fx.run("C03")["attempts"]), 0)
	fx.place("C03", "C03_TIMELINE", "TL_CLAIM", 2)
	var r := fx.submit_timeline("C03", "C03_TIMELINE")
	assert_eq(r["code"], CZ.WRONG)
	assert_false(fx.run("C03")["timeline_ok"])
	assert_eq(fx.run("C03")["timeline"], ["TL_PHOTO", "TL_DEPART", "TL_CLAIM"], "array retained")
	assert_eq(r["data"]["feedback"], "Подреди по показаните часове. Началото на алибито е твърдение, не доказан факт.")
	assert_eq(r["events"][1]["props"]["reason"], "WRONG_ORDER")

func test_at11_correct_timeline_persists_and_link_next() -> void:
	_open_c03()
	_five()
	fx.place("C03", "C03_TIMELINE", "TL_DEPART", 0)
	fx.place("C03", "C03_TIMELINE", "TL_CLAIM", 1)
	fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 2)
	var r := fx.submit_timeline("C03", "C03_TIMELINE")
	assert_eq(r["code"], CZ.CORRECT)
	assert_eq(r["data"]["next_screen"], "C03_LINK")
	var again := fx.kill_and_restart()
	assert_true(again.run("C03")["timeline_ok"])
	assert_eq(again.run("C03")["timeline"], ["TL_DEPART", "TL_CLAIM", "TL_PHOTO"])
	# Evidence can still be reviewed (inspect still works), LINK stays next.
	again.inspect("C03", "C03_TICKET")
	var cta := Selectors.deduction_cta(again.db.case_def("C03"), again.run("C03"), again.state()["campaign"])
	assert_eq(cta["stage"]["id"], "C03_LINK")
	var replace := again.place("C03", "C03_TIMELINE", "TL_PHOTO", 0)
	assert_true(replace["status"] != CZ.OK, "passed timeline is not editable")

func test_c03_link_wrong_then_right_then_final() -> void:
	_open_c03()
	_five()
	fx.place("C03", "C03_TIMELINE", "TL_DEPART", 0)
	fx.place("C03", "C03_TIMELINE", "TL_CLAIM", 1)
	fx.place("C03", "C03_TIMELINE", "TL_PHOTO", 2)
	fx.submit_timeline("C03", "C03_TIMELINE")
	var w := fx.select_set("C03", "C03_LINK", ["EV_C03_TICKET", "EV_C03_PHOTO", "EV_C03_CLOCK_SYNC"])
	assert_eq(w["code"], CZ.WRONG)
	assert_eq(w["data"]["feedback"], "Билетът показва право на пътуване. Търсим провереното време и мястото в кадъра.")
	var ok := fx.select_set("C03", "C03_LINK", ["EV_C03_PLATFORM", "EV_C03_PHOTO", "EV_C03_CLOCK_SYNC"])
	assert_eq(ok["data"]["next_screen"], "C03_DEDUCTION_Q1")
	var bad := fx.answer("C03", "C03_Q1", "C03_Q1_A1")
	assert_eq(bad["code"], CZ.WRONG)
	var fin := fx.answer("C03", "C03_Q1", "C03_Q1_A0")
	assert_eq(fin["code"], CZ.SOLVED)
	assert_eq(int(fx.run("C03")["attempts"]), 2)

func test_c03_hint_targets_and_at20() -> void:
	_open_c03()
	var def := fx.db.case_def("C03")
	var t := func(): return Selectors.hint_target(def, fx.run("C03"), fx.state()["campaign"])
	var expected := ["C03_TICKET", "C03_PHOTO", "C03_TIMETABLE", "C03_CLOCK", "C03_PLATFORM"]
	for o in expected:
		assert_eq(t.call(), o)
		fx.inspect("C03", o)
	assert_eq(t.call(), Selectors.UI_EVIDENCE, "hint 3 points at the reasoning stage")
