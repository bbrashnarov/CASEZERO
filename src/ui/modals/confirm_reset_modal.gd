class_name ConfirmResetModal
extends ModalBase
## <CASE>_CONFIRM_RESET for restart and replay: Yes clears only the run (campaign completion and
## XP stay) and opens INTRO; No returns to the opening screen (PAUSE or BOARD).

var def: CaseDef

func setup(context: AppContext, r: Dictionary) -> ConfirmResetModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	closable = false
	build(def.title())
	add_text(ctx.t("confirm_reset")).name = "ConfirmText"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(ctx.metrics.dp(16)))
	footer.add_child(row)
	var yes := CzButton.new().setup(ctx, "UI_CONFIRM_YES", ctx.t("confirm_yes"))
	var no := CzButton.new().setup(ctx, "UI_CONFIRM_NO", ctx.t("confirm_no"))
	for b in [yes, no]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	yes.activated.connect(_on_yes)
	no.activated.connect(func(): ctx.router.pop())
	return self

func _on_yes() -> void:
	var was_completed := bool(ctx.state()["campaign"]["completed"].get(def.id, false))
	ctx.perform(CZ.RESET_RUN, {"case_id": def.id}, func(res):
		if res["status"] == CZ.OK:
			ctx.router.set_base(Router.intro(def.id, "replay" if was_completed else "board")))
