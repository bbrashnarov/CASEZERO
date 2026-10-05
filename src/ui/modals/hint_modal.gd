class_name HintModal
extends ModalBase
## <CASE>_HINT: current level text; the CTA escalates (never time-based) and repeats at level 3.

var def: CaseDef
var _text: Label
var _cta: CzButton

func setup(context: AppContext, r: Dictionary) -> HintModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	build("")
	_text = add_text("")
	_text.name = "HintText"
	_cta = primary_button("")
	_cta.activated.connect(_on_next)
	refresh()
	return self

func refresh() -> void:
	var level := int(ctx.run(def.id).get("hint_level", 0))
	title_label.text = ctx.t("hint_title") % level
	_text.text = Selectors.hint_text(def, level)
	_cta.set_text(ctx.t("hint_repeat") if level >= CZ.HINT_MAX_LEVEL else ctx.t("hint_next"))

func _on_next() -> void:
	ctx.perform(CZ.REQUEST_HINT, {"case_id": def.id, "mode": Hints.MODE_NEXT}, func(_res): refresh())
