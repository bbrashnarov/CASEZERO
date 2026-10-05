class_name EvidenceModal
extends ModalBase
## <CASE>_EVIDENCE: evidence registry order (not discovery order), locked cards without spoilers,
## required counter, and the guarded deduction CTA that routes to the current stage.

var def: CaseDef
var _list: VBoxContainer
var _cta: CzButton
var _counter: Label

func setup(context: AppContext, r: Dictionary) -> EvidenceModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	tall = true
	build(ctx.t("evidence_title"))
	_counter = add_text("", UiStyle.SECONDARY_SP, UiStyle.SUBDUED, true)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(ctx.metrics.dp(8)))
	body.add_child(_list)
	_cta = primary_button(ctx.t("evidence_cta"))
	_cta.activated.connect(_on_cta)
	refresh()
	return self

func refresh() -> void:
	var run := ctx.run(def.id)
	_counter.text = ctx.t("evidence_button") % [Selectors.required_found(def, run), Selectors.required_total(def)]
	for c in _list.get_children():
		c.queue_free()
	for e in def.evidence:
		var found: bool = run.get("evidence", []).has(e["id"])
		var card := CzButton.new().setup(ctx, "UI_EVIDENCE_CARD_" + str(e["id"]),
			str(e["name"]) if found else ctx.t("evidence_locked_card"))
		card.align_left()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if found:
			var sub := str(e["card_text"])
			if not e.get("required", false):
				sub = ctx.t("evidence_optional_label") + " • " + sub
			card.set_sub(sub)
			card.activated.connect(func(): ctx.router.push(Router.detail_card(def.id, e["id"])))
		else:
			card.set_disabled(true)
		_list.add_child(card)
	var cta := Selectors.deduction_cta(def, run, ctx.state()["campaign"])
	match cta["kind"]:
		"open":
			_cta.set_text(ctx.t("evidence_cta"))
			_cta.set_sub(ctx.t("stage_progress") % [int(cta["index"]) + 1, def.stages.size()])
			_cta.set_disabled(false)
		"waiting":
			_cta.set_text(str(cta["stage"]["waiting_cta"]["label"]))
			_cta.set_sub("")
			_cta.set_disabled(false)
		"solved":
			_cta.set_text(ctx.t("evidence_cta"))
			_cta.set_disabled(true, "")
		_:
			_cta.set_text(ctx.t("evidence_cta"))
			_cta.set_disabled(true, ctx.t("deduction_disabled"))

func _on_cta() -> void:
	var run := ctx.run(def.id)
	var cta := Selectors.deduction_cta(def, run, ctx.state()["campaign"])
	match cta["kind"]:
		"open":
			ctx.router.push(Router.stage(def, cta["stage"]["id"]))
		"waiting":
			ctx.router.pop_to_base()
