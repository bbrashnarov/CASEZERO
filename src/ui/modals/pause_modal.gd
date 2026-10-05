class_name PauseModal
extends ModalBase
## <CASE>_PAUSE (Android Back from SCENE): Board (state is already committed), Restart, Resume.

signal board_requested()

var def: CaseDef

func setup(context: AppContext, r: Dictionary) -> PauseModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	closable = false
	build(ctx.t("pause_title"))
	var board := CzButton.new().setup(ctx, "UI_PAUSE_BOARD", ctx.t("pause_board"))
	var restart := CzButton.new().setup(ctx, "UI_PAUSE_RESTART", ctx.t("pause_restart"))
	var resume := CzButton.new().setup(ctx, "UI_PAUSE_RESUME", ctx.t("pause_resume"))
	for b in [board, restart, resume]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, ctx.metrics.dp(56))
		body.add_child(b)
	board.activated.connect(func(): board_requested.emit())
	restart.activated.connect(func(): ctx.router.push(Router.confirm_reset(def.id, "PAUSE")))
	resume.activated.connect(func(): ctx.router.pop())
	return self
