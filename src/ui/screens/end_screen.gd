class_name EndScreen
extends ScreenBase
## G_END after the C03 reward.

func setup(context: AppContext, r: Dictionary) -> EndScreen:
	init_screen(context, r, context.t("archive_zero"))
	add_text(ctx.t("end_text"), UiStyle.TITLE_SP, UiStyle.PANEL, true).name = "EndText"
	var b := primary_button(ctx.t("end_cta"))
	b.activated.connect(func(): ctx.router.set_base(Router.board()))
	return self
