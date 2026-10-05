extends TestCase
## Snapshot persistence, failure handling, corruption recovery, migrations and simulated kills.

func test_fresh_boot_routes_to_first_intro_then_board() -> void:
	var fx := Fx.new()
	assert_eq(fx.boot_result["status"], BootService.FRESH)
	assert_eq(fx.boot_result["route"], "C01_INTRO")
	assert_true(fx.boot_result["fresh_install"])
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.OK)
	assert_eq(fx2.boot_result["route"], "G_BOARD")
	assert_false(fx2.boot_result["fresh_install"])

func test_snapshot_roundtrip_preserves_types() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	var loaded := fx.repo.load()
	assert_eq(loaded["status"], SaveRepository.LOADED)
	assert_eq(typeof(loaded["state"]["campaign"]["xp"]), TYPE_INT)
	assert_eq(loaded["state"], fx.state())

func test_write_failure_keeps_last_committed_state() -> void:
	var fx := Fx.new()
	fx.start("C01")
	var failed := []
	fx.store.write_failed.connect(func(a, _r): failed.append(a["type"]))
	fx.backend.fail_writes = 1
	var r := fx.inspect("C01", "C01_WINDOW")
	assert_eq(r["status"], CZ.WRITE_FAILED)
	assert_eq(fx.run("C01")["evidence"], [], "no visual success that was not saved")
	assert_eq(failed, [CZ.INSPECT_OBJECT])
	assert_true(fx.store.has_pending())
	assert_eq(fx.inspect("C01", "C01_FLOOR")["code"], CZ.BUSY, "nothing commits over a pending write")
	var retry := fx.store.retry_pending()
	assert_eq(retry["status"], CZ.OK)
	assert_eq(fx.run("C01")["evidence"], ["EV_C01_RAIN"])
	assert_eq(fx.kill_and_restart().run("C01")["evidence"], ["EV_C01_RAIN"])

func test_write_failure_revert_returns_to_last_snapshot() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.backend.fail_writes = 1
	fx.inspect("C01", "C01_WINDOW")
	assert_true(fx.store.revert_pending())
	assert_false(fx.store.has_pending())
	assert_eq(fx.run("C01")["evidence"], [])
	assert_eq(fx.inspect("C01", "C01_WINDOW")["status"], CZ.OK, "play continues after revert")

func test_at17_save_fails_on_solve() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	fx.answer("C01", "C01_Q1", "C01_Q1_A0")
	fx.inspect("C01", "C01_MANAGER")
	fx.backend.fail_writes = 1
	var r := fx.answer("C01", "C01_Q2", "C01_Q2_A1")
	assert_eq(r["status"], CZ.WRITE_FAILED)
	assert_false(fx.run("C01")["solved"], "no fake committed success")
	assert_eq(fx.state()["campaign"]["xp"], 0)
	assert_false(fx.kill_and_restart().run("C01")["solved"])
	var retry := fx.store.retry_pending()
	assert_eq(retry["status"], CZ.OK)
	assert_true(fx.run("C01")["solved"])
	assert_eq(fx.state()["campaign"]["xp"], 100)
	assert_eq(fx.kill_and_restart().state()["campaign"]["xp"], 100)

func test_checkpoint_write_failure_does_not_block_play() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.backend.fail_writes = 1
	var r := fx.act(CZ.CHECKPOINT_ACTIVE_TIME, {"case_id": "C01", "add_ms": 5000})
	assert_eq(r["status"], CZ.WRITE_FAILED)
	assert_false(fx.store.has_pending())
	assert_eq(fx.inspect("C01", "C01_WINDOW")["status"], CZ.OK)

func test_corrupt_primary_recovers_from_backup() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	fx.backend.files[SaveRepository.PRIMARY] = fx.backend.files[SaveRepository.PRIMARY].substr(0, 40)
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.OK)
	assert_true(fx2.boot_result["save_recovered"])
	# The backup holds the snapshot before the last write.
	assert_eq(fx2.run("C01")["evidence"], ["EV_C01_RAIN"])
	var corrupt_copies := fx.backend.files.keys().filter(func(k): return str(k).begins_with(SaveRepository.CORRUPT_PREFIX))
	assert_true(corrupt_copies.size() >= 1, "corrupt snapshot kept for diagnosis")

func test_checksum_detects_tampering() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	var env: Dictionary = JSON.parse_string(fx.backend.files[SaveRepository.PRIMARY])
	env["payload"] = str(env["payload"]).replace("\"xp\":100", "\"xp\":900")
	assert_false(SaveCodec.decode(JSON.stringify(env))["ok"])

func test_both_snapshots_corrupt_offers_full_recovery() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.backend.files[SaveRepository.PRIMARY] = "garbage"
	fx.backend.files[SaveRepository.BACKUP] = "{}"
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.RECOVERY)
	assert_eq(fx2.boot_result["recovery"]["kind"], BootService.RECOVER_ALL)
	var applied := BootService.apply_recovery(fx2.db, fx2.repo, BootService.RECOVER_ALL, {}, [])
	assert_eq(applied["status"], BootService.OK)
	assert_eq(applied["state"]["runs"], {})

func test_newer_schema_is_unsupported_and_not_overwritten() -> void:
	var fx := Fx.new()
	var s := fx.state().duplicate(true)
	s["schema_version"] = 99
	fx.backend.files[SaveRepository.PRIMARY] = SaveCodec.encode(s)
	var original: String = fx.backend.files[SaveRepository.PRIMARY]
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.RECOVERY)
	assert_eq(fx2.boot_result["recovery"]["kind"], BootService.RECOVER_UNSUPPORTED)
	assert_eq(fx.backend.files[SaveRepository.PRIMARY], original, "never silently overwritten")

func test_migration_contract() -> void:
	assert_eq(Migrations.migrate({"schema_version": 1})["status"], "OK")
	assert_eq(Migrations.migrate({"schema_version": 2})["status"], "UNSUPPORTED")
	assert_eq(Migrations.migrate({"schema_version": 0})["status"], "INVALID")
	assert_eq(Migrations.migrate({})["status"], "INVALID")

func test_invalid_run_resets_only_that_run() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	fx.reset("C01")
	fx.start("C01")
	var s := fx.state().duplicate(true)
	s["runs"]["C01"]["evidence"] = ["EV_C01_UNKNOWN"]
	fx.backend.files[SaveRepository.PRIMARY] = SaveCodec.encode(s)
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.RECOVERY)
	assert_eq(fx2.boot_result["recovery"]["kind"], BootService.RECOVER_RUNS)
	assert_eq(fx2.boot_result["recovery"]["cases"], ["C01"])
	var applied := BootService.apply_recovery(fx2.db, fx2.repo, BootService.RECOVER_RUNS, fx2.boot_result["state"], ["C01"])
	assert_eq(applied["status"], BootService.OK)
	assert_false(applied["state"]["runs"].has("C01"))
	assert_eq(applied["state"]["campaign"]["xp"], 100, "campaign is never wiped automatically")
	assert_true(applied["state"]["campaign"]["completed"]["C01"])

func test_content_extension_adds_new_case_keys() -> void:
	var fx := Fx.new()
	var s := fx.state().duplicate(true)
	s["campaign"]["completed"].erase("C01")
	s["campaign"]["reward_granted"].erase("C01")
	fx.backend.files[SaveRepository.PRIMARY] = SaveCodec.encode(s)
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["status"], BootService.OK)
	assert_eq(fx2.state()["campaign"]["completed"]["C01"], false)

func test_at03_kill_after_correct_q1() -> void:
	var fx := Fx.new()
	fx.start("C01")
	fx.inspect("C01", "C01_WINDOW")
	fx.inspect("C01", "C01_FLOOR")
	fx.answer("C01", "C01_Q1", "C01_Q1_A0")
	var fx2 := fx.kill_and_restart()
	assert_eq(fx2.boot_result["route"], "G_BOARD")
	var run := fx2.run("C01")
	assert_true(run["questions"]["C01_Q1"])
	assert_false(run["solved"], "no premature solve")
	var def := fx2.db.case_def("C01")
	assert_true(Selectors.gate_open(def.object("C01_MANAGER"), run, fx2.state()["campaign"]), "manager unlocked on resume")
	assert_eq(Selectors.board_status(fx2.db, fx2.state(), "C01"), "in_progress")

func test_at12_kill_after_solve_before_reward() -> void:
	var fx := Fx.new()
	fx.solve_c01()
	var fx2 := fx.kill_and_restart()
	assert_true(fx2.state()["campaign"]["completed"]["C01"])
	assert_true(fx2.state()["campaign"]["reward_granted"]["C01"])
	assert_eq(fx2.state()["campaign"]["xp"], 100)
	assert_eq(fx2.boot_result["route"], "G_BOARD", "logical route: board with solved stamp")
	assert_eq(Selectors.board_status(fx2.db, fx2.state(), "C01"), "solved")
	fx2.reset("C01")
	fx2.solve_c01()
	assert_eq(fx2.state()["campaign"]["xp"], 100, "XP never granted twice")

func test_file_backend_atomic_write() -> void:
	var dir := "user://test_save_%d" % Time.get_ticks_usec()
	var b := FileSaveBackend.new(dir)
	assert_eq(b.write_atomic("save.json", "one"), OK)
	assert_eq(b.write_atomic("save.json", "two"), OK, "rename must replace an existing file")
	assert_eq(b.read_text("save.json"), "two")
	assert_false(FileAccess.file_exists(dir.path_join("save.json.tmp")), "no temp file left behind")
	var repo := SaveRepository.new(b)
	var db := ContentDB.load_default()
	var s := GameState.new_state(db.content_version, db.case_order)
	assert_true(repo.commit(s)["ok"])
	assert_true(repo.commit(s)["ok"])
	assert_eq(repo.load()["status"], SaveRepository.LOADED)
	assert_true(b.exists(SaveRepository.BACKUP))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
