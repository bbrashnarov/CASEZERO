extends TestCase
## Local-first analytics (spec Part 11): every event in the table is emitted with its required
## properties during a real campaign through the UI, the log stays within budget (FIFO), no PII
## or story text is recorded, and export works.

const REQUIRED := {
	"APP_STARTED": ["fresh_install", "save_recovered"],
	"CASE_STARTED": ["entry_source", "replay"],
	"CASE_RESUMED": ["evidence_count", "stage"],
	"OBJECT_TAPPED": ["object_id", "inspection_state", "physical_state", "gate_passed"],
	"OBJECT_INSPECTED": ["object_id", "first_inspection", "detail_variant"],
	"CLUE_DISCOVERED": ["evidence_id", "source_object_id", "discovery_key"],
	"EVIDENCE_ADDED": ["evidence_id", "required_count_after", "discovery_key"],
	"CHARGER_CONNECTED": ["object_id", "prior_power"],
	"EVIDENCE_OPENED": ["required_found", "required_total"],
	"HINT_REQUESTED": ["level_before", "level_after", "target_id", "is_repeat"],
	"DEDUCTION_OPENED": ["stage_id", "prerequisite_ids"],
	"TIMELINE_CHANGED": ["token_id", "from_slot", "to_slot", "displaced_token"],
	"DEDUCTION_SUBMITTED": ["stage_id", "answer_id", "selected_evidence_ids", "timeline_token_ids"],
	"DEDUCTION_FAILED": ["stage_id", "reason", "attempts_after"],
	"DEDUCTION_SUCCEEDED": ["stage_id"],
	"CASE_SOLVED": ["attempts_total", "hint_level", "active_ms", "required_count", "replay", "xp_delta"],
	"REWARD_VIEWED": ["xp_delta", "campaign_xp"],
	"CASE_EXITED": ["stage", "evidence_count", "reason"],
	"CASE_RESTARTED": ["old_run_id", "new_run_id", "was_solved"],
	"SAVE_FAILED": ["action_type", "error_category"],
}
const COMMON := ["event_id", "event_name", "schema_version", "build_id", "content_version", "session_id", "run_id",
	"case_id", "timestamp_utc", "elapsed_active_ms", "interaction_index", "route"]

var h: UiHarness

func after_each() -> void:
	if h:
		await h.cleanup()

func _all_events() -> Array:
	return h.ctx().analytics.read_all()

func test_every_event_emitted_with_required_properties() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	h = UiHarness.new(Vector2(360, 800), 1.0, [0, 0, 0, 0], fx.backend)
	await h.boot()
	# C02 via UI: charger, hint, wrong set, exit + resume, restart, solve, reward.
	await h.press("UI_BOARD_C02", h.base())
	await h.press("UI_PRIMARY", h.base())
	await h.press("UI_HINT", h.base())
	await h.close()
	await h.tap_object("C02", "C02_CHARGER")
	await h.press("UI_PRIMARY")
	await h.close()
	await h.back()
	await h.press("UI_PAUSE_BOARD")
	await h.press("UI_BOARD_C02", h.base())
	for o in ["C02_PHONE", "C02_RECORD", "C02_WATCH"]:
		await h.tap_object("C02", o)
		await h.close()
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	var st := h.top() as StageModal
	for e in ["EV_C02_BATTERY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"]:
		st.toggle(e)
	st.press_submit()
	await h.settle()
	st.toggle("EV_C02_BATTERY")
	st.toggle("EV_C02_IDENTITY")
	st.press_submit()
	await h.settle()
	st = h.top() as StageModal
	st.choose_answer("C02_Q1_A2")
	st.press_submit()
	await h.settle()
	await h.press("UI_PRIMARY", h.base())    # -> REWARD
	await h.press("UI_PRIMARY", h.base())    # -> C03_INTRO
	await h.press("UI_PRIMARY", h.base())
	for o in ["C03_TICKET", "C03_CLOCK", "C03_TIMETABLE", "C03_PHOTO", "C03_PLATFORM"]:
		await h.tap_object("C03", o)
		await h.close()
	await h.press("UI_EVIDENCE", h.base())
	await h.press("UI_PRIMARY")
	st = h.top() as StageModal
	st.pick_token("TL_DEPART"); st.pick_slot(0)
	await h.settle()
	# Restart C03 via pause, then a failed write for SAVE_FAILED.
	await h.close()
	await h.close()
	await h.back()
	await h.press("UI_PAUSE_RESTART")
	await h.press("UI_CONFIRM_YES")
	await h.press("UI_PRIMARY", h.base())
	h.ctx().store.repo.debug_fail_next = 1
	await h.tap_object("C03", "C03_TICKET")
	await h.press("UI_REVERT")
	var events := _all_events()
	var by_name := {}
	for e in events:
		if not by_name.has(e["event_name"]):
			by_name[e["event_name"]] = e
	for name in REQUIRED:
		assert_true(by_name.has(name), "event emitted: " + name)
		if not by_name.has(name):
			continue
		var e: Dictionary = by_name[name]
		for k in COMMON + REQUIRED[name]:
			assert_true(e.has(k), "%s has %s" % [name, k])
		assert_eq(int(e["schema_version"]), 1)
	assert_eq(by_name["CHARGER_CONNECTED"]["prior_power"], "EMPTY")
	assert_eq(by_name["CASE_EXITED"]["reason"], "board")
	assert_eq(by_name["SAVE_FAILED"]["action_type"], CZ.INSPECT_OBJECT)
	assert_eq(by_name["DEDUCTION_OPENED"]["prerequisite_ids"], ["EV_C02_IDENTITY", "EV_C02_NETWORK", "EV_C02_WATCH_LOG"])
	# Events describe committed state only: no OBJECT_INSPECTED for the failed write.
	var last_inspect: Array = events.filter(func(e): return e["event_name"] == "OBJECT_INSPECTED" and e["object_id"] == "C03_TICKET")
	assert_eq(last_inspect.size(), 1, "the failed write emitted no OBJECT_INSPECTED")
	# One session id, monotonic interaction_index.
	var sids := {}
	var last_idx := -1
	var mono := true
	for e in events:
		sids[e["session_id"]] = true
		if int(e["interaction_index"]) < last_idx:
			mono = false
		last_idx = int(e["interaction_index"])
	assert_eq(sids.size(), 1)
	assert_true(mono, "interaction_index monotonic within session")

func test_no_pii_or_story_text_in_events() -> void:
	var fx := Fx.new()
	h = UiHarness.new(Vector2(360, 640), 1.0, [0, 0, 0, 0], fx.backend)
	await h.boot()
	await h.press("UI_BOARD_C01", h.base())
	await h.press("UI_PRIMARY", h.base())
	await h.tap_object("C01", "C01_WINDOW")
	await h.close()
	await h.tap_object("C01", "C01_MANAGER")
	var raw := FileAccess.get_file_as_string(h.analytics_dir.path_join(AnalyticsService.FILE))
	assert_true(raw.length() > 0)
	var def := h.ctx().db.case_def("C01")
	for o in def.objects:
		var txt := str(o.get("detail_text", ""))
		if txt.length() > 10:
			assert_false(raw.contains(txt.substr(0, 20)), "no story text from " + o["id"])
	assert_false(raw.contains(str(def.object("C01_MANAGER")["locked_text"])), "no locked text")
	assert_false(raw.contains(OS.get_user_data_dir()), "no filesystem paths")
	for forbidden in ["\"email\"", "\"device_id\"", "\"advertising_id\"", "\"user\""]:
		assert_false(raw.contains(forbidden), forbidden)
	var a := h.ctx().analytics
	a.track("TEST_EVENT", {"text": "secret", "name": "Ivo", "ok": 1})
	var ev: Dictionary = a.recent.back()
	assert_false(ev.has("text") or ev.has("name"), "free text / name keys dropped")

func test_budget_fifo_and_export() -> void:
	var dir := "user://test_analytics/budget_%d" % Time.get_ticks_usec()
	var a := AnalyticsService.new("0.1.0-dev", "case-zero-v1.0")
	a.dir = dir
	a.budget_bytes = 20000
	for i in 400:
		a.track("OBJECT_TAPPED", {"object_id": "C01_WINDOW", "seq": i})
	var path := dir.path_join(AnalyticsService.FILE)
	var size := FileAccess.open(path, FileAccess.READ).get_length()
	assert_true(size <= 20000, "log within budget: %d" % size)
	var events := a.read_all()
	assert_true(events.size() > 10)
	assert_eq(int(events.back()["seq"]), 399, "newest kept")
	assert_true(int(events[0]["seq"]) > 0, "oldest dropped first")
	var ex := a.export_log()
	assert_true(ex["ok"])
	var doc = JSON.parse_string(ex["json"])
	assert_eq(doc["export_format"], "casezero-playtest-log-1")
	assert_eq(doc["events"].size(), events.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ex["path"]))
	UiHarness._rm_rf(dir)

func test_analytics_failure_never_blocks_gameplay() -> void:
	var fx := Fx.new()
	h = UiHarness.new(Vector2(360, 640), 1.0, [0, 0, 0, 0], fx.backend)
	# The analytics "directory" is an existing regular file: every append fails.
	var blocker := "user://analytics_blocker_%d" % Time.get_ticks_usec()
	var f := FileAccess.open(blocker, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	h.analytics_dir = blocker
	await h.boot()
	await h.press("UI_BOARD_C01", h.base())
	await h.press("UI_PRIMARY", h.base())
	await h.tap_object("C01", "C01_WINDOW")
	assert_eq(h.run("C01")["evidence"], ["EV_C01_RAIN"], "save path independent of analytics")
	assert_true(h.ctx().analytics.write_failures > 0, "analytics writes really failed")
	DirAccess.remove_absolute(blocker)
