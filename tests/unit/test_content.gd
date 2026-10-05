extends TestCase
## Content validation against the authoritative IDs, geometry and texts of the spec.

var db: ContentDB

func before_each() -> void:
	db = ContentDB.load_default()

func test_shipped_content_is_valid() -> void:
	var errs := ContentValidator.validate(db)
	assert_eq(errs.size(), 0, "validator errors: %s" % str(errs))

func test_shipped_content_is_solvable() -> void:
	var errs := Solvability.check(db)
	assert_eq(errs.size(), 0, "solvability errors: %s" % str(errs))

func test_c01_object_ids_geometry_and_profiles_match_spec() -> void:
	var def := db.case_def("C01")
	var expect := {
		"C01_WINDOW": [[648, 336, 336, 480], [624, 312, 384, 528], 10, 100, "P_INSPECT"],
		"C01_FLOOR": [[624, 936, 360, 216], [600, 912, 408, 264], 11, 101, "P_INSPECT"],
		"C01_SHOES": [[408, 1224, 168, 168], [384, 1200, 216, 216], 12, 102, "P_INSPECT"],
		"C01_CUP": [[144, 768, 168, 192], [120, 744, 216, 240], 13, 103, "P_INSPECT"],
		"C01_CLOCK": [[144, 360, 192, 168], [120, 336, 240, 216], 14, 104, "P_INSPECT"],
		"C01_MANAGER": [[696, 1272, 264, 192], [672, 1248, 312, 240], 15, 105, "P_MANAGER"],
	}
	for oid in expect:
		var o = def.object(oid)
		assert_true(o != null, "missing %s" % oid)
		if o == null:
			continue
		assert_eq(o["rect"], expect[oid][0], oid + " rect")
		assert_eq(o["hitbox"], expect[oid][1], oid + " hitbox")
		assert_eq(o["z"], expect[oid][2], oid + " z")
		assert_eq(o["priority"], expect[oid][3], oid + " priority")
		assert_eq(o["profile"], expect[oid][4], oid + " profile")
	var body = def.object("C01_BODY")
	assert_eq(body["clickable"], false)
	assert_eq(body["hitbox"], null)
	assert_eq(def.evidence_ids(), ["EV_C01_RAIN", "EV_C01_DRY_FLOOR", "EV_C01_ADMISSION"])

func test_validator_detects_broken_content() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.MANIFEST_PATH))
	var c01: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/cases/C01.json"))
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.UI_TEXT_PATH))
	m["cases"] = ["C01"]
	c01["objects"].append(c01["objects"][0].duplicate(true))                 # duplicate object id
	c01["objects"][1]["evidence"] = ["EV_C01_NOPE"]                          # invalid evidence ref
	c01["objects"][2]["asset_id"] = "A_MISSING"                              # missing asset
	c01["objects"][3]["hitbox"] = [120, 744, -1, 240]                        # invalid hitbox
	c01["objects"][4]["rect"] = [1000, 360, 192, 168]                        # outside scene bounds
	c01["stages"][0]["correct"] = "C01_Q1_A9"                                # answer ref missing
	c01["stages"][1]["unlock"] = {"q": "C01_Q7"}                             # prerequisite ref missing
	var db2 := ContentDB.from_data(m, [c01], ui)
	var errs := ContentValidator.validate(db2)
	var joined := "\n".join(errs)
	for needle in ["duplicate object id", "unknown evidence EV_C01_NOPE", "A_MISSING missing", "invalid hitbox",
			"outside scene viewport", "C01_Q1_A9", "unknown question C01_Q7"]:
		assert_true(joined.contains(needle), "validator did not report '%s'\n%s" % [needle, joined])

func test_solvability_detects_cyclic_lock() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.MANIFEST_PATH))
	var c01: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/cases/C01.json"))
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.UI_TEXT_PATH))
	m["cases"] = ["C01"]
	# Required clue locked behind a question that itself needs that clue.
	c01["objects"][5]["gate"] = {"q": "C01_Q2"}
	var db2 := ContentDB.from_data(m, [c01], ui)
	var errs := Solvability.check(db2)
	assert_eq(errs.size(), 1, "expected unsolvable C01")
