class_name RewardScreen
extends ScreenBase
## <CASE>_REWARD: XP delta (+100 first solve / +0 replay) counted up over 500 ms (tap skips), the
## campaign total, and the next step: next case INTRO, G_END for the last case, else the Board.
## The reward itself was already granted in the solve transaction; this screen only displays it.

var def: CaseDef
var _xp_label: Label
var _delta := 0
var _shown := 0.0
var _tw: Tween

func setup(context: AppContext, r: Dictionary) -> RewardScreen:
	def = context.db.case_def(r["case_id"])
	var info: Dictionary = r.get("info", {})
	_delta = int(info.get("xp_delta", 0))
	init_screen(context, r, context.t("reward_title"))
	add_text(def.title(), UiStyle.BODY_SP, UiStyle.ACCENT, true)
	_xp_label = add_text("", UiStyle.TITLE_SP, UiStyle.PANEL, true)
	_xp_label.name = "XpDelta"
	add_text(ctx.t("reward_total") % int(ctx.state()["campaign"]["xp"]), UiStyle.BODY_SP, UiStyle.PANEL).name = "XpTotal"
	var nxt = def.next_case()
	if nxt != null and _delta > 0 and Selectors.case_unlocked(ctx.db, ctx.state(), str(nxt)):
		add_text(ctx.t("reward_next_unlocked"), UiStyle.SECONDARY_SP, UiStyle.SUBDUED)
	var cta: CzButton
	if nxt != null:
		cta = primary_button(ctx.t("reward_next"))
		cta.activated.connect(func(): CaseFlow.enter_case(ctx, str(nxt), "next"))
	elif def.data.get("on_complete") == "G_END":
		cta = primary_button(ctx.t("reward_continue"))
		cta.activated.connect(func(): ctx.router.set_base(Router.end_screen()))
	else:
		cta = primary_button(ctx.t("reward_continue"))
		cta.activated.connect(func(): ctx.router.set_base(Router.board()))
	var ms := ctx.anim_ms(CZ.AN_XP_MS)
	if ms > 0 and _delta > 0:
		_tw = create_tween()
		_tw.tween_method(_set_shown, 0.0, float(_delta), ms / 1000.0)
	else:
		_set_shown(float(_delta))
	return self

func _set_shown(v: float) -> void:
	_shown = v
	_xp_label.text = ctx.t("reward_xp_delta") % int(round(v))

func _gui_input(event: InputEvent) -> void:
	# Tap anywhere skips the visual count (spec CMP_XP).
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed and _tw and _tw.is_running():
		_tw.kill()
		_set_shown(float(_delta))
