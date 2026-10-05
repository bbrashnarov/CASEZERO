extends TestCase
## C01 domain behaviour through the real Store (reducer + invariants + persistence).

var fx: Fx

func before_each() -> void:
	fx = Fx.new()

func test_start_case_creates_full_run_atomically() -> void:
	var r := fx.start("C01")
	assert_eq(r["status"], CZ.OK)
	var run := fx.run("C01")
	assert_true(run["started"])
	assert_eq(run["evidence"], [])
	assert_eq(run["hint_level"], 0)
	assert_eq(run["attempts"], 0)
	assert_false(run["solved"])
	assert_eq(run["questions"], {"C01_Q1": false, "C01_Q2": false})
	for oid in ["C01_WINDOW", "C01_FLOOR", "C01_SHOES", "C01_CUP", "C01_CLOCK", "C01_MANAGER"]:
		assert_eq(run["objects"][oid]["inspection"], CZ.UNSEEN, oid)
	assert_false(run["objects"].has("C01_BODY"), "decor has no inspection state")
	assert_ne(run["run_id"], "")
	assert_eq(event_names(r), ["CASE_STARTED"])
	assert_eq(r["events"][0]["props"]["replay"], false)
	# Persisted before commit.
	var reloaded := fx.kill_and_restart()
	assert_true(reloaded.run("C01")["started"], "start must be persisted")

func test_second_start_is_noop() -> void:
	fx.start("C01")
	var r := fx.start("C01")
	assert_eq(r["status"], CZ.NOOP)
	assert_eq(r["code"], CZ.ALREADY_STARTED)

func test_inspect_requires_scene_route() -> void:
	fx.start("C01")
	fx.route = "C01_EVIDENCE"
	var r := fx.act(CZ.INSPECT_OBJECT, {"case_id": "C01", "object_id": "C01_WINDOW"})
	assert_eq(r["code"], CZ.ROUTE_INVALID)
	assert_eq(fx.run("C01")["evidence"], [])

func test_inspect_requires_started_run() -> void:
	fx.route = "C01_SCENE"
	var r := fx.act(CZ.INSPECT_OBJECT, {"case_id": "C01", "object_id": "C01_WINDOW"})
	assert_eq(r["code"], CZ.NOT_STARTED)

func test_first_inspect_adds_evidence_and_feedback() -> void:
	fx.start("C01")
	var r := fx.inspect("C01", "C01_WINDOW")
	assert_eq(r["status"], CZ.OK)
	assert_true(r["persist"])
	assert_eq(fx.run("C01")["objects"]["C01_WINDOW"]["inspection"], CZ.SEEN)
	assert_eq(fx.run("C01")["evidence"], ["EV_C01_RAIN"])
	assert_eq(event_names(r), ["OBJECT_TAPPED", "OBJECT_INSPECTED", "CLUE_DISCOVERED", "EVIDENCE_ADDED"])
	assert_eq(r["feedback"]["sfx"], ["SFX_CLUE_FOUND"])
	assert_eq(r["feedback"]["haptic"], CZ.HAPTIC_LIGHT)
	assert_eq(r["feedback"]["toast"], "Улика открита")
	assert_eq(r["data"]["detail_text"], "Дъжд от 19:00. Към огледа в 22:12 капките влизат навътре и мокрят вътрешния перваз. Няма козирка.")
	assert_eq(r["events"][2]["props"]["discovery_key"], fx.run("C01")["run_id"] + ":EV_C01_RAIN")

func test_repeat_inspect_is_idempotent() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	var writes := fx.backend.write_count
	var r := fx.inspect("C01", "C01_WINDOW")
	assert_eq(r["status"], CZ.OK)
	assert_false(r["persist"], "nothing changed, nothing to write")
	assert_eq(fx.backend.write_count, writes)
	assert_eq(fx.run("C01")["evidence"], ["EV_C01_RAIN"])
	assert_eq(event_names(r), ["OBJECT_TAPPED", "OBJECT_INSPECTED"])
	assert_eq(r["events"][1]["props"]["first_inspection"], false)
	assert_eq(r["feedback"]["sfx"], [])
	assert_eq(r["feedback"]["haptic"], CZ.HAPTIC_NONE)
	assert_true(r["data"]["repeat"])

func test_optional_object_gives_observation_only() -> void:
	fx.start("C01")
	var r := fx.inspect("C01", "C01_CUP")
	assert_eq(fx.run("C01")["objects"]["C01_CUP"]["inspection"], CZ.SEEN)
	assert_eq(fx.run("C01")["evidence"], [])
	assert_eq(r["feedback"]["sfx"], [], "no clue sound without evidence")
	assert_eq(r["data"]["detail_text"], "Тъмният ръб е следа от кафе. Няма видими данни за отрова; вкусът и външният вид не могат да я изключат.")

func test_decor_never_intercepts_input() -> void:
	fx.start("C01")
	var r := fx.inspect("C01", "C01_BODY")
	assert_eq(r["code"], CZ.NOT_INTERACTIVE)
	assert_eq(r["events"], [])

func test_at02_manager_locked_before_q1() -> void:
	fx.start("C01")
	var before := fx.state().duplicate(true)
	var r := fx.inspect("C01", "C01_MANAGER")
	assert_eq(r["status"], CZ.NOOP)
	assert_eq(r["code"], CZ.GATE_LOCKED)
	assert_eq(r["data"]["locked_text"], "Първо сравни прозореца и пода.")
	assert_eq(event_names(r), ["OBJECT_TAPPED"])
	assert_eq(r["events"][0]["props"]["gate_passed"], false)
	assert_eq(fx.state(), before, "locked tap must not change state")
	assert_not_has(fx.run("C01")["evidence"], "EV_C01_ADMISSION")

func test_at01_floor_before_window_keeps_q1_locked() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_FLOOR")
	var def := fx.db.case_def("C01")
	var cta := Selectors.deduction_cta(def, fx.run("C01"), fx.state()["campaign"])
	assert_eq(cta["kind"], "blocked")
	var r := fx.answer("C01", "C01_Q1", "C01_Q1_A0")
	assert_eq(r["code"], CZ.PRECONDITION_MISSING)
	assert_eq(fx.run("C01")["attempts"], 0, "premature submit is not an attempt")
	fx.inspect("C01", "C01_WINDOW")
	cta = Selectors.deduction_cta(def, fx.run("C01"), fx.state()["campaign"])
	assert_eq(cta["kind"], "open")
	assert_eq(cta["stage"]["id"], "C01_Q1")

func test_wrong_answer_counts_attempt_and_keeps_progress() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	var r := fx.answer("C01", "C01_Q1", "C01_Q1_A1")
	assert_eq(r["status"], CZ.OK)
	assert_eq(r["code"], CZ.WRONG)
	assert_eq(fx.run("C01")["attempts"], 1)
	assert_false(fx.run("C01")["questions"]["C01_Q1"])
	assert_eq(fx.run("C01")["evidence"], ["EV_C01_RAIN", "EV_C01_DRY_FLOOR"])
	assert_eq(fx.state()["campaign"]["xp"], 0, "no XP penalty")
	assert_eq(r["data"]["feedback"], "Наблюдението подсказва промяна, но не доказва извършител или точен момент.")
	assert_eq(r["feedback"]["sfx"], ["SFX_WRONG_DEDUCTION"])
	assert_eq(event_names(r), ["DEDUCTION_SUBMITTED", "DEDUCTION_FAILED"])
	assert_eq(r["events"][1]["props"]["reason"], "WRONG_ANSWER")
	# Still playable: the correct answer is accepted afterwards.
	assert_eq(fx.answer("C01", "C01_Q1", "C01_Q1_A0")["code"], CZ.CORRECT)

func test_invalid_selection_is_not_an_attempt() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	assert_eq(fx.answer("C01", "C01_Q1", null)["code"], CZ.INVALID_SELECTION)
	assert_eq(fx.answer("C01", "C01_Q1", "C01_Q2_A1")["code"], CZ.INVALID_SELECTION)
	assert_eq(fx.run("C01")["attempts"], 0)

func test_q1_correct_opens_manager_and_waiting_cta() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	var r := fx.answer("C01", "C01_Q1", "C01_Q1_A0")
	assert_eq(r["code"], CZ.CORRECT)
	assert_true(fx.run("C01")["questions"]["C01_Q1"])
	assert_false(fx.run("C01")["solved"], "no solve or XP after Q1")
	assert_eq(fx.state()["campaign"]["xp"], 0)
	assert_eq(r["data"]["success_cta"]["label"], "Към показанията")
	assert_eq(r["data"]["feedback"], "Версията е съмнителна. Сега попитай кой е отворил прозореца.")
	assert_eq(r["feedback"]["sfx"], ["SFX_DEDUCTION_CORRECT"])
	var def := fx.db.case_def("C01")
	var cta := Selectors.deduction_cta(def, fx.run("C01"), fx.state()["campaign"])
	assert_eq(cta["kind"], "waiting")
	assert_eq(cta["stage"]["waiting_cta"]["label"], "Провери показанията")
	var m := fx.inspect("C01", "C01_MANAGER")
	assert_eq(m["status"], CZ.OK)
	assert_has(fx.run("C01")["evidence"], "EV_C01_ADMISSION")
	assert_eq(fx.answer("C01", "C01_Q1", "C01_Q1_A0")["code"], CZ.STAGE_ALREADY_PASSED)

func test_final_solve_is_atomic_and_rewarded_once() -> void:
	var r := fx.solve_c01()
	assert_eq(r["code"], CZ.SOLVED)
	var s := fx.state()
	assert_true(s["runs"]["C01"]["solved"])
	assert_true(s["campaign"]["completed"]["C01"])
	assert_true(s["campaign"]["reward_granted"]["C01"])
	assert_eq(s["campaign"]["xp"], 100)
	assert_eq(r["data"]["xp_delta"], 100)
	assert_eq(r["feedback"]["sfx"], ["SFX_CASE_SOLVED"])
	assert_eq(r["feedback"]["haptic"], CZ.HAPTIC_MEDIUM)
	assert_eq(event_names(r), ["DEDUCTION_SUBMITTED", "CASE_SOLVED"])
	assert_eq(r["events"][1]["props"]["xp_delta"], 100)
	# Repeated submit after solve: no-op, no event, no reward.
	var again := fx.answer("C01", "C01_Q2", "C01_Q2_A1")
	assert_eq(again["status"], CZ.NOOP)
	assert_eq(again["code"], CZ.ALREADY_SOLVED)
	assert_eq(again["events"], [])
	assert_eq(fx.state()["campaign"]["xp"], 100)

func test_restart_clears_run_only() -> void:
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	var old_id: String = fx.run("C01")["run_id"]
	var r := fx.reset("C01")
	assert_eq(r["status"], CZ.OK)
	assert_ne(fx.run("C01")["run_id"], old_id, "restart generates a new run_id")
	assert_false(fx.run("C01")["started"])
	assert_eq(fx.run("C01")["evidence"], [])
	assert_eq(event_names(r), ["CASE_RESTARTED"])
	assert_eq(r["events"][0]["props"]["old_run_id"], old_id)

func test_replay_gives_zero_xp_and_keeps_completion() -> void:
	fx.solve_c01()
	fx.reset("C01")
	assert_true(fx.state()["campaign"]["completed"]["C01"], "completion survives reset")
	assert_true(fx.state()["campaign"]["reward_granted"]["C01"])
	assert_eq(fx.state()["campaign"]["xp"], 100)
	var start := fx.start("C01")
	assert_eq(start["events"][0]["props"]["replay"], true)
	var r := fx.solve_c01()
	assert_eq(r["code"], CZ.SOLVED)
	assert_true(fx.run("C01")["solved"])
	assert_eq(r["data"]["xp_delta"], 0)
	assert_eq(r["data"]["replay"], true)
	assert_eq(fx.state()["campaign"]["xp"], 100, "replay never pays twice")

func test_hint_levels_and_repeat() -> void:
	fx.start("C01")
	var r := fx.hint("C01", Hints.MODE_OPEN)
	assert_eq(fx.run("C01")["hint_level"], 1)
	assert_eq(r["data"]["text"], "Виж зоната между прозореца и пода.")
	assert_eq(r["data"]["target"], "C01_WINDOW")
	assert_eq(event_names(r), ["HINT_REQUESTED"])
	var again := fx.hint("C01", Hints.MODE_OPEN)
	assert_eq(again["status"], CZ.NOOP, "re-opening does not escalate")
	assert_eq(again["events"], [])
	fx.hint("C01", Hints.MODE_NEXT)
	var third := fx.hint("C01", Hints.MODE_NEXT)
	assert_eq(fx.run("C01")["hint_level"], 3)
	assert_eq(third["data"]["text"], "Докосни прозореца и сухия под. След първия извод провери картата на управителя.")
	var rep := fx.hint("C01", Hints.MODE_NEXT)
	assert_eq(fx.run("C01")["hint_level"], 3)
	assert_eq(rep["events"][0]["props"]["is_repeat"], true)
	assert_eq(fx.state()["campaign"]["xp"], 0, "hints never cost XP")

func test_at20_hint_target_follows_case_order() -> void:
	var def := fx.db.case_def("C01")
	fx.start("C01")
	var target := func() -> String: return Selectors.hint_target(def, fx.run("C01"), fx.state()["campaign"])
	assert_eq(target.call(), "C01_WINDOW")
	fx.inspect("C01", "C01_WINDOW")
	assert_eq(target.call(), "C01_FLOOR")
	fx.inspect("C01", "C01_FLOOR")
	assert_eq(target.call(), Selectors.UI_EVIDENCE, "manager only offered after Q1")
	fx.answer("C01", "C01_Q1", "C01_Q1_A0")
	assert_eq(target.call(), "C01_MANAGER")
	fx.inspect("C01", "C01_MANAGER")
	assert_eq(target.call(), Selectors.UI_EVIDENCE, "all clues found: point at the reasoning stage")

func test_at14_duplicate_dispatch_id_executes_once() -> void:
	fx.start("C01")
	fx.scene("C01")
	var a := fx.store.make_action(CZ.INSPECT_OBJECT, {"case_id": "C01", "object_id": "C01_WINDOW"})
	var first := fx.store.dispatch(a)
	var events_after_first := fx.events.size()
	var second := fx.store.dispatch(a.duplicate())
	assert_eq(first["status"], CZ.OK)
	assert_eq(second["status"], CZ.DUPLICATE)
	assert_eq(second["feedback"]["haptic"], CZ.HAPTIC_NONE, "no second haptic")
	assert_eq(fx.events.size(), events_after_first, "no second analytics emission")
	assert_eq(fx.run("C01")["evidence"], ["EV_C01_RAIN"])
	# Survives a process kill: the persisted journal still recognises the action ID.
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.store.dispatch(a.duplicate())["status"], CZ.DUPLICATE)

func test_settings_persist_immediately() -> void:
	var r := fx.act(CZ.SET_SETTING, {"key": "sound", "value": false})
	assert_eq(r["status"], CZ.OK)
	assert_false(fx.kill_and_restart().state()["settings"]["sound"])
	assert_eq(fx.act(CZ.SET_SETTING, {"key": "volume", "value": false})["code"], CZ.INVALID_PAYLOAD)

func test_board_status_and_unlock() -> void:
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C01"), "new")
	fx.start("C01")
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C01"), "in_progress")
	fx.solve_c01()
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C01"), "solved")
	fx.reset("C01")
	assert_eq(Selectors.board_status(fx.db, fx.state(), "C01"), "solved", "completed stamp stays after reset")

func test_invariants_reject_inconsistent_state() -> void:
	var s := fx.state().duplicate(true)
	s["campaign"]["xp"] = 200
	assert_false(GameState.is_valid(GameState.check(s, fx.db)))
	fx.start("C01")
	var s2 := fx.state().duplicate(true)
	s2["runs"]["C01"]["evidence"].append("EV_C01_RAIN")
	s2["runs"]["C01"]["evidence"].append("EV_C01_RAIN")
	assert_false(GameState.is_valid(GameState.check(s2, fx.db)), "duplicate evidence")
	var s3 := fx.state().duplicate(true)
	s3["runs"]["C01"]["solved"] = true
	assert_false(GameState.is_valid(GameState.check(s3, fx.db)), "solved without predicate")
