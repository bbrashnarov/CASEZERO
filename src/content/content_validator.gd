class_name ContentValidator
extends RefCounted
## Structural content validation (dev/build time, fail fast).
## Solvability (impossible success predicate, cyclic locks) is checked separately by
## Solvability in the gameplay layer, because it needs the reducer.

const KNOWN_PROFILES := ["P_INSPECT", "P_PHONE", "P_CHARGER", "P_MANAGER", "NONE"]
const KNOWN_STAGE_TYPES := ["single_answer", "evidence_set", "timeline"]
const RUN_FIELD_TYPES := ["enum", "bool", "token_slots"]

var errors: Array = []

static func validate(db: ContentDB) -> Array:
	var v := ContentValidator.new()
	v._validate_db(db)
	return v.errors

func _err(where: String, msg: String) -> void:
	errors.append("%s: %s" % [where, msg])

func _validate_db(db: ContentDB) -> void:
	errors.append_array(db.load_errors)
	if db.content_version == "":
		_err("manifest", "content_version missing")
	var seen_assets := {}
	for a in db.manifest.get("assets", []):
		if seen_assets.has(a["id"]):
			_err("manifest", "duplicate asset id %s" % a["id"])
		seen_assets[a["id"]] = true
	for ev_id in db.sound_events:
		var se: Dictionary = db.sound_events[ev_id]
		if not db.assets.has(se.get("asset", "")):
			_err("manifest.sound_events", "%s references missing asset %s" % [ev_id, se.get("asset")])
		if not ["NONE", "LIGHT", "MEDIUM"].has(se.get("haptic", "NONE")):
			_err("manifest.sound_events", "%s has invalid haptic" % ev_id)
	var global_objects := {}
	var global_evidence := {}
	for cid in db.case_order:
		if not db.cases.has(cid):
			_err("manifest", "case %s listed but not loaded" % cid)
			continue
		var def: CaseDef = db.cases[cid]
		_validate_case(db, def, global_objects, global_evidence)
	for key in ["intro_cta", "evidence_cta", "deduction_disabled", "toast_clue_single", "confirm_reset"]:
		if not db.text.has(key):
			_err("ui_text", "missing key %s" % key)

func _validate_case(db: ContentDB, def: CaseDef, global_objects: Dictionary, global_evidence: Dictionary) -> void:
	var c := def.id
	var d := def.data
	for key in ["title", "objective", "opening_text", "scene_id", "solved_text"]:
		if str(d.get(key, "")).strip_edges() == "":
			_err(c, "missing %s" % key)
	if d.get("ambience") != null and not db.sound_events.has(d["ambience"]):
		_err(c, "ambience %s not in sound_events" % d["ambience"])
	var nc = def.next_case()
	if nc != null and not db.case_order.has(nc):
		_err(c, "next_case %s does not exist" % nc)
	_check_asset(db, c, d.get("thumbnail_asset"), "thumbnail")
	var bg := def.background()
	_check_asset(db, c, bg.get("asset_id"), "background")

	# --- run fields -------------------------------------------------------
	var fields := def.run_fields()
	for f in fields:
		var spec: Dictionary = fields[f]
		if not RUN_FIELD_TYPES.has(spec.get("type")):
			_err(c, "run_field %s has invalid type" % f)
		if spec.get("type") == "enum" and not spec.get("values", []).has(spec.get("initial")):
			_err(c, "run_field %s initial not in values" % f)
		if f in ["started", "run_id", "evidence", "objects", "questions", "hint_level", "attempts", "solved", "active_ms"]:
			_err(c, "run_field %s collides with core run field" % f)

	# --- evidence registry -------------------------------------------------
	var ev_ids := {}
	for e in def.evidence:
		var eid: String = e.get("id", "")
		if not eid.begins_with("EV_%s_" % c):
			_err(c, "evidence id %s must start with EV_%s_" % [eid, c])
		if ev_ids.has(eid) or global_evidence.has(eid):
			_err(c, "duplicate evidence id %s" % eid)
		ev_ids[eid] = true
		global_evidence[eid] = true
		if str(e.get("card_text", "")).strip_edges() == "" or str(e.get("name", "")).strip_edges() == "":
			_err(c, "evidence %s missing name/card_text" % eid)
		_check_asset(db, c, e.get("icon"), "evidence icon")
	if def.evidence.size() > 5:
		_err(c, "evidence panel defines 5 card slots; %d evidence entries" % def.evidence.size())

	# --- objects ------------------------------------------------------------
	var obj_ids := {}
	var produced := {}   # evidence id -> [object ids]
	var screens := {}
	var playable := []
	for o in def.objects:
		var oid: String = o.get("id", "")
		var where := "%s.%s" % [c, oid]
		if not oid.begins_with("%s_" % c):
			_err(where, "object id must start with %s_" % c)
		if obj_ids.has(oid) or global_objects.has(oid):
			_err(where, "duplicate object id")
		obj_ids[oid] = true
		global_objects[oid] = true
		var rect = o.get("rect")
		if not _valid_rect(rect):
			_err(where, "invalid rect")
		elif not CZ.SCENE_RECT.encloses(_r(rect)):
			_err(where, "rect outside scene viewport [0,264,1080,1332]")
		_check_asset(db, c, o.get("asset_id"), "object asset", o.get("profile") in ["P_PHONE", "P_CHARGER"])
		if not KNOWN_PROFILES.has(o.get("profile")):
			_err(where, "unknown profile %s" % o.get("profile"))
		if o.get("clickable", false):
			if o.get("input") != "TAP":
				_err(where, "clickable objects must use input TAP")
			var hb = o.get("hitbox")
			if not _valid_rect(hb):
				_err(where, "invalid hitbox")
			else:
				if not CZ.SCENE_RECT.encloses(_r(hb)):
					_err(where, "hitbox outside scene viewport")
				if _valid_rect(rect) and not _r(hb).encloses(_r(rect)):
					_err(where, "hitbox does not enclose visual rect")
				playable.append(o)
			if o.get("priority") == null:
				_err(where, "clickable object needs priority")
			var scr = o.get("inspect_screen")
			if scr == null or not str(scr).begins_with("%s_INSPECT_" % c):
				_err(where, "inspect_screen must be %s_INSPECT_*" % c)
			elif screens.has(scr):
				_err(where, "duplicate screen %s" % scr)
			screens[scr] = true
			_check_asset(db, c, o.get("detail_asset_id"), "detail asset", o.get("profile") in ["P_PHONE", "P_CHARGER"])
			if o.get("gate") == null:
				_err(where, "clickable object needs a gate (true or predicate)")
			_check_pred(def, where + ".gate", o.get("gate"), ev_ids)
			if o.get("gate") is Dictionary and str(o.get("locked_text", "")).strip_edges() == "":
				_err(where, "gated object needs locked_text")
			var outs := []
			if o.has("variants"):
				var vf: String = o.get("variant_field", "")
				if not fields.has(vf):
					_err(where, "variant_field %s is not a run_field" % vf)
				else:
					for val in fields[vf].get("values", []):
						if not o["variants"].has(val):
							_err(where, "variant missing for %s=%s" % [vf, val])
				for val in o["variants"]:
					var var_d: Dictionary = o["variants"][val]
					if str(var_d.get("detail_text", "")).strip_edges() == "":
						_err(where, "variant %s missing detail_text" % val)
					outs.append_array(var_d.get("evidence", []))
			else:
				if str(o.get("detail_text", "")).strip_edges() == "":
					_err(where, "missing detail_text")
				outs.append_array(o.get("evidence", []))
			for eid in outs:
				if not ev_ids.has(eid):
					_err(where, "produces unknown evidence %s" % eid)
				if not produced.has(eid):
					produced[eid] = []
				if not produced[eid].has(oid):
					produced[eid].append(oid)
			if o.get("profile") == "P_PHONE" and not o.has("variants"):
				_err(where, "P_PHONE requires variant_field/variants")
			if o.get("profile") == "P_CHARGER":
				var cta: Dictionary = o.get("cta", {})
				if cta.is_empty() or str(cta.get("label", "")) == "":
					_err(where, "P_CHARGER requires cta")
				else:
					_check_pred(def, where + ".cta.enabled_when", cta.get("enabled_when"), ev_ids)
					for f in cta.get("effects", {}):
						if not fields.has(f):
							_err(where, "cta effect field %s is not a run_field" % f)
						elif not fields[f].get("values", []).has(cta["effects"][f]):
							_err(where, "cta effect %s=%s not an allowed value" % [f, cta["effects"][f]])
		else:
			if o.get("hitbox") != null:
				_err(where, "non-clickable object must have hitbox NONE")
	# Spec Part 2: "Всички playable scene hitboxes са неприпокриващи се на baseline".
	for i in playable.size():
		for j in range(i + 1, playable.size()):
			if _r(playable[i]["hitbox"]).intersects(_r(playable[j]["hitbox"])):
				_err(c, "baseline hitboxes overlap: %s / %s" % [playable[i]["id"], playable[j]["id"]])
	for e in def.evidence:
		var eid: String = e["id"]
		if not produced.has(eid):
			_err(c, "evidence %s has no producing object" % eid)
		elif not produced[eid].has(e.get("source_object")):
			_err(c, "evidence %s source_object %s does not produce it" % [eid, e.get("source_object")])

	# --- stages -------------------------------------------------------------
	var stage_ids := {}
	var finals := 0
	for s in def.stages:
		var sid: String = s.get("id", "")
		var where := "%s.%s" % [c, sid]
		if stage_ids.has(sid):
			_err(where, "duplicate stage id")
		stage_ids[sid] = true
		if not KNOWN_STAGE_TYPES.has(s.get("type")):
			_err(where, "unknown stage type")
		var scr = s.get("screen", "")
		if not str(scr).begins_with("%s_" % c) or screens.has(scr):
			_err(where, "invalid or duplicate screen %s" % scr)
		screens[scr] = true
		if s.get("final", false):
			finals += 1
		_check_pred(def, where + ".unlock", s.get("unlock"), ev_ids)
		if s.has("waiting_cta"):
			_check_pred(def, where + ".waiting_cta", s["waiting_cta"].get("when"), ev_ids)
		var res: Dictionary = s.get("result", {})
		if res.has("question"):
			if res["question"] != sid:
				_err(where, "question result must equal stage id")
		elif res.has("field"):
			if not fields.has(res["field"]) or fields[res["field"]].get("type") != "bool":
				_err(where, "result field %s must be a bool run_field" % res.get("field"))
		else:
			_err(where, "stage needs result.question or result.field")
		for eid in s.get("required_evidence", []):
			if not ev_ids.has(eid):
				_err(where, "required_evidence %s unknown" % eid)
		match s.get("type"):
			"single_answer":
				var ans_ids := {}
				for a in s.get("answers", []):
					if ans_ids.has(a["id"]):
						_err(where, "duplicate answer %s" % a["id"])
					ans_ids[a["id"]] = true
					if not str(a["id"]).begins_with(sid + "_A"):
						_err(where, "answer id %s must be %s_A<n>" % [a["id"], sid])
					if str(a.get("text", "")).strip_edges() == "":
						_err(where, "answer %s missing text" % a["id"])
				if ans_ids.size() != 3:
					_err(where, "expected 3 answers (UI_ANSWER_0..2)")
				if not ans_ids.has(s.get("correct")):
					_err(where, "correct answer %s not among answers" % s.get("correct"))
				for k in ["question", "correct_feedback", "incorrect_feedback"]:
					if str(s.get(k, "")).strip_edges() == "":
						_err(where, "missing %s" % k)
			"evidence_set":
				var cs: Array = s.get("correct_set", [])
				if cs.size() != int(s.get("select_count", -1)):
					_err(where, "correct_set size must equal select_count")
				for eid in cs:
					if not ev_ids.has(eid):
						_err(where, "correct_set references unknown evidence %s" % eid)
				for k in ["question", "incorrect_feedback", "submit_label"]:
					if str(s.get(k, "")).strip_edges() == "":
						_err(where, "missing %s" % k)
			"timeline":
				_validate_timeline(def, where, s, fields, ev_ids)
	if finals != 1:
		_err(c, "exactly one final stage required, found %d" % finals)
	_check_pred(def, c + ".success", def.success(), ev_ids)
	_check_pred(def, c + ".unlock", def.unlock(), ev_ids)
	for inv in def.invariants():
		_check_pred(def, c + ".invariant", inv, ev_ids)

	# --- hints ------------------------------------------------------------
	if def.hint_texts().size() != CZ.HINT_MAX_LEVEL:
		_err(c, "exactly %d hint texts required" % CZ.HINT_MAX_LEVEL)
	for tgt in def.hint_targets():
		if not obj_ids.has(tgt.get("object_id")):
			_err(c, "hint target %s unknown" % tgt.get("object_id"))
		elif not def.object(tgt["object_id"]).get("clickable", false):
			_err(c, "hint target %s is not clickable" % tgt["object_id"])
		_check_pred(def, c + ".hint.satisfied", tgt.get("satisfied"), ev_ids)
		if tgt.has("available"):
			_check_pred(def, c + ".hint.available", tgt["available"], ev_ids)

func _validate_timeline(def: CaseDef, where: String, s: Dictionary, fields: Dictionary, ev_ids: Dictionary) -> void:
	var tokens: Array = s.get("tokens", [])
	var tok_ids := {}
	for t in tokens:
		if tok_ids.has(t["id"]):
			_err(where, "duplicate token %s" % t["id"])
		tok_ids[t["id"]] = true
		if str(t.get("label", "")).strip_edges() == "":
			_err(where, "token %s missing label" % t["id"])
		for eid in t.get("sources", []):
			if not ev_ids.has(eid):
				_err(where, "token %s source %s unknown" % [t["id"], eid])
	var order: Array = s.get("correct_order", [])
	var disp: Array = s.get("display_order", [])
	if order.size() != tokens.size() or disp.size() != tokens.size():
		_err(where, "correct_order/display_order must list every token once")
	for tid in order + disp:
		if not tok_ids.has(tid):
			_err(where, "timeline references unknown token %s" % tid)
	var dedup := {}
	for tid in order:
		dedup[tid] = true
	if dedup.size() != order.size():
		_err(where, "correct_order has duplicate tokens")
	if s.get("slot_labels", []).size() != tokens.size():
		_err(where, "slot_labels count must equal token count")
	var sf: String = s.get("slots_field", "")
	if not fields.has(sf) or fields[sf].get("type") != "token_slots" or int(fields[sf].get("size", -1)) != tokens.size():
		_err(where, "slots_field %s must be a token_slots run_field of size %d" % [sf, tokens.size()])

func _check_pred(def: CaseDef, where: String, p: Variant, ev_ids: Dictionary) -> void:
	var refs := Predicate.collect(p, {})
	for e in refs["errors"]:
		_err(where, e)
	for eid in refs["evidence"]:
		if not ev_ids.has(eid):
			_err(where, "references unknown evidence %s" % eid)
	var qids := def.question_ids()
	for q in refs["questions"]:
		if not qids.has(q):
			_err(where, "references unknown question %s" % q)
	for f in refs["fields"]:
		if not def.run_fields().has(f):
			_err(where, "references unknown run_field %s" % f)

func _check_asset(db: ContentDB, where: String, asset_id: Variant, what: String, needs_variants := false) -> void:
	if asset_id == null:
		return
	if not db.assets.has(asset_id):
		_err(where, "%s %s missing from asset manifest" % [what, asset_id])
	elif needs_variants and not db.assets[asset_id].has("variants"):
		_err(where, "%s %s needs a variant dictionary" % [what, asset_id])

static func _valid_rect(r: Variant) -> bool:
	return r is Array and r.size() == 4 and float(r[2]) > 0 and float(r[3]) > 0

static func _r(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
