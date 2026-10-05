class_name StageModal
extends ModalBase
## Reusable deduction UI for every stage type (spec Part 4/8):
##   single_answer  UI_ANSWER_0..2 single choice + "Потвърди"
##   evidence_set   discovered evidence rows, checkbox + order badge, exactly N + stage submit label
##   timeline       token cards + slots, tap token then tap slot, persisted on every placement
## The modal only collects a selection; SUBMIT_STAGE validates IDs and prerequisites in the domain.
## Selections (answer / evidence) are runtime-only and are not restored after a kill (spec).

var def: CaseDef
var stage: Dictionary
var _submit: CzButton
var _feedback: Label
var _feedback_until := 0
var _answer_buttons := {}
var _selected_answer = null
var _evidence_buttons := {}
var _selected_evidence: Array = []
var _token_buttons := {}
var _slot_buttons: Array = []
var _selected_token = null
var _passed := false
var _success_cta = null

func setup(context: AppContext, r: Dictionary) -> StageModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	stage = def.stage(r["stage_id"])
	tall = true
	build("")
	var question := str(stage.get("question", ""))
	add_text(question, UiStyle.TITLE_SP, UiStyle.TEXT, true).name = "Question"
	match stage["type"]:
		CZ.STAGE_SINGLE_ANSWER:
			_build_answers()
		CZ.STAGE_EVIDENCE_SET:
			_build_evidence()
		CZ.STAGE_TIMELINE:
			_build_timeline()
	_feedback = add_text("", UiStyle.BODY_SP, UiStyle.ERROR, true)
	_feedback.name = "Feedback"
	_feedback.visible = false
	var submit_label := str(stage.get("submit_label", ctx.t("deduction_submit")))
	_submit = primary_button(submit_label)
	_submit.activated.connect(_on_submit)
	_update_submit()
	return self

# --- single answer -----------------------------------------------------------------------

func _build_answers() -> void:
	var i := 0
	for a in stage["answers"]:
		var b := CzButton.new().setup(ctx, "UI_ANSWER_%d" % i, str(a["text"]))
		b.align_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, ctx.metrics.dp(56))
		var aid: String = a["id"]
		b.activated.connect(func(): _select_answer(aid))
		body.add_child(b)
		_answer_buttons[aid] = b
		i += 1

func _select_answer(aid: String) -> void:
	if _passed:
		return
	_selected_answer = aid
	for k in _answer_buttons:
		_answer_buttons[k].set_selected(k == aid)
		_answer_buttons[k].set_result(CzButton.NORMAL)
	_clear_feedback()
	_update_submit()

# --- evidence set -------------------------------------------------------------------------

func _build_evidence() -> void:
	var run := ctx.run(def.id)
	for e in def.evidence:
		if not run["evidence"].has(e["id"]):
			continue
		var b := CzButton.new().setup(ctx, "UI_EVIDENCE_CARD_" + str(e["id"]), str(e["name"]), str(e["card_text"]))
		b.align_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eid: String = e["id"]
		b.activated.connect(func(): _toggle_evidence(eid))
		body.add_child(b)
		_evidence_buttons[eid] = b

func _toggle_evidence(eid: String) -> void:
	if _passed:
		return
	var limit := int(stage["select_count"])
	if _selected_evidence.has(eid):
		_selected_evidence.erase(eid)
	elif _selected_evidence.size() >= limit:
		ctx.toast(ctx.t("select_max") % limit, CZ.AN_ERROR_MS)
		return
	else:
		_selected_evidence.append(eid)
	for k in _evidence_buttons:
		var b: CzButton = _evidence_buttons[k]
		var idx := _selected_evidence.find(k)
		b.set_selected(idx >= 0)
		b.set_text(("☑ %d  " % (idx + 1) if idx >= 0 else "☐  ") + str(def.evidence_def(k)["name"]))
		b.set_result(CzButton.NORMAL)
	_clear_feedback()
	_update_submit()

# --- timeline ------------------------------------------------------------------------------

func _build_timeline() -> void:
	var tokens := {}
	for t in stage["tokens"]:
		tokens[t["id"]] = t
	for tid in stage["display_order"]:
		var b := CzButton.new().setup(ctx, "UI_TL_TOKEN_" + str(tid), str(tokens[tid]["label"]))
		b.align_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = tid
		b.activated.connect(func(): _select_token(id))
		body.add_child(b)
		_token_buttons[tid] = b
	# Slots: three rows (the spec's small-screen/large-font layout, used everywhere so the
	# layout never needs horizontal scroll).
	var labels: Array = stage["slot_labels"]
	for j in labels.size():
		var s := CzButton.new().setup(ctx, "UI_TL_SLOT_%d" % j, str(labels[j]))
		s.align_left()
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := j
		s.activated.connect(func(): _place(slot))
		body.add_child(s)
		_slot_buttons.append(s)
	_refresh_timeline()

func _slots() -> Array:
	return ctx.run(def.id)[stage["slots_field"]]

func _select_token(tid: String) -> void:
	if _passed:
		return
	_selected_token = tid
	_clear_feedback()
	_refresh_timeline()

func _place(slot: int) -> void:
	if _passed:
		return
	if _selected_token == null:
		ctx.toast(ctx.t("timeline_pick_first"), CZ.AN_ERROR_MS)
		return
	ctx.perform(CZ.PLACE_TIMELINE_TOKEN, {"case_id": def.id, "stage_id": stage["id"], "token_id": _selected_token, "slot": slot},
		func(res):
			if res["status"] in [CZ.OK, CZ.NOOP]:
				_selected_token = null
			_clear_feedback()
			_refresh_timeline())

func _refresh_timeline() -> void:
	var slots := _slots()
	var labels: Array = stage["slot_labels"]
	var tokens := {}
	for t in stage["tokens"]:
		tokens[t["id"]] = t
	for tid in _token_buttons:
		var b: CzButton = _token_buttons[tid]
		var at := slots.find(tid)
		b.set_selected(tid == _selected_token)
		b.set_sub(("→ " + str(labels[at])) if at >= 0 else "")
	for j in _slot_buttons.size():
		var s: CzButton = _slot_buttons[j]
		var occupant = slots[j]
		s.set_text(str(labels[j]) + (":  " + str(tokens[occupant]["label"]) if occupant != null else ""))
		s.set_selected(occupant != null)
	_update_submit()

# --- submit ---------------------------------------------------------------------------------

func _update_submit() -> void:
	if _submit == null:
		return
	if _passed:
		return
	var ready := false
	match stage["type"]:
		CZ.STAGE_SINGLE_ANSWER:
			ready = _selected_answer != null
		CZ.STAGE_EVIDENCE_SET:
			ready = _selected_evidence.size() == int(stage["select_count"])
		CZ.STAGE_TIMELINE:
			var slots := _slots()
			ready = not slots.has(null)
	_submit.set_disabled(not ready)

func _on_submit() -> void:
	if _passed and _success_cta != null:
		_follow(str(_success_cta.get("route", "SCENE")))
		return
	var payload := {"case_id": def.id, "stage_id": stage["id"]}
	match stage["type"]:
		CZ.STAGE_SINGLE_ANSWER:
			payload["answer_id"] = _selected_answer
		CZ.STAGE_EVIDENCE_SET:
			payload["evidence_ids"] = _selected_evidence.duplicate()
	ctx.hold_input()
	ctx.perform(CZ.SUBMIT_STAGE, payload, _on_result)
	ctx.release_input()

func _on_result(res: Dictionary) -> void:
	match res["code"]:
		CZ.WRONG:
			_show_feedback(str(res["data"].get("feedback", "")), UiStyle.ERROR)
			if _selected_answer != null and _answer_buttons.has(_selected_answer):
				_answer_buttons[_selected_answer].set_result(CzButton.ERROR)
		CZ.CORRECT:
			_passed = true
			for k in _answer_buttons:
				_answer_buttons[k].set_result(CzButton.SUCCESS if k == _selected_answer else CzButton.NORMAL)
			var next = res["data"].get("next_screen")
			_success_cta = res["data"].get("success_cta")
			if _success_cta != null:
				# C01 Q1: inline correct feedback, then CTA "Към показанията" back to the scene.
				_show_feedback(str(res["data"].get("feedback", "")), UiStyle.SUCCESS, false)
				_submit.set_text(str(_success_cta["label"]))
				_submit.set_disabled(false)
			elif next != null:
				# Intermediate stages continue to the next stage immediately (AN_STAGE_OK).
				var st = def.stage_for_screen(str(next))
				ctx.router.replace_top(Router.stage(def, st["id"]))
			else:
				ctx.router.pop_to_base()
		CZ.SOLVED, CZ.ALREADY_SOLVED:
			var info := {"xp_delta": int(res["data"].get("xp_delta", 0)), "replay": bool(res["data"].get("replay", false))}
			ctx.router.set_base(Router.solved(def.id, info))
		CZ.PRECONDITION_MISSING:
			_show_feedback(ctx.t("deduction_disabled"), UiStyle.ERROR)
		CZ.STAGE_ALREADY_PASSED:
			ctx.router.pop_to_base()

func _follow(target: String) -> void:
	if target == "SCENE":
		ctx.router.pop_to_base()

func _show_feedback(text: String, color: Color, timed := true) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.visible = true
	if timed:
		# Error highlight lasts 1500 ms; the text stays readable until the next edit (CMP_WRONG_FEEDBACK).
		_feedback_until = Time.get_ticks_msec() + CZ.AN_ERROR_MS

func _clear_feedback() -> void:
	if _passed:
		return
	_feedback.visible = false

## Test hooks (UI tests drive the same handlers a tap reaches).
func choose_answer(aid: String) -> void: _select_answer(aid)
func toggle(eid: String) -> void: _toggle_evidence(eid)
func pick_token(tid: String) -> void: _select_token(tid)
func pick_slot(slot: int) -> void: _place(slot)
func press_submit() -> void: _submit.activate()
