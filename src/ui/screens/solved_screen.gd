class_name SolvedScreen
extends ScreenBase
## <CASE>_SOLVED: shown only after the atomic solve committed. Text and CTA are visible
## immediately; the 300 ms accent draw is decorative.

func setup(context: AppContext, r: Dictionary) -> SolvedScreen:
	var def := context.db.case_def(r["case_id"])
	var info: Dictionary = r.get("info", {})
	var replay := bool(info.get("replay", false))
	init_screen(context, r, context.t("solved_replay") if replay else "✓ " + context.t("solved_title"))
	add_text(def.title(), UiStyle.BODY_SP, UiStyle.ACCENT, true)
	add_text(def.solved_text()).name = "ResolutionText"
	var b := primary_button(ctx.t("solved_cta"))
	b.activated.connect(func(): ctx.router.set_base(Router.reward(def.id, info)))
	var ms := ctx.anim_ms(CZ.AN_SOLVED_MS)
	if ms > 0:
		title_label.scale = Vector2(0.96, 0.96)
		create_tween().tween_property(title_label, "scale", Vector2.ONE, ms / 1000.0)
	return self
