class_name BoardScreen
extends ScreenBase
## G_BOARD (Case Board / minimal Detective Office, DD12): XP, Settings and one card per case in
## campaign order. Card tap: new -> INTRO, started -> SCENE (resume), solved -> replay confirmation.

var _xp: Label
var _cards := {}

func setup(context: AppContext, r: Dictionary) -> BoardScreen:
	init_screen(context, r, ctx_title(context))
	var settings := CzButton.new().setup(ctx, "UI_SETTINGS", "⚙")
	if "accessibility_name" in settings:
		settings.set("accessibility_name", ctx.t("settings_button"))
	settings.size_flags_horizontal = Control.SIZE_SHRINK_END
	settings.activated.connect(func(): ctx.router.set_base(Router.settings()))
	top_bar.add_child(settings)
	_xp = add_text("", UiStyle.BODY_SP, UiStyle.ACCENT, true)
	_xp.name = "XP"
	for cid in ctx.db.case_order:
		var b := CzButton.new().setup(ctx, "UI_BOARD_" + str(cid), "")
		b.align_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, ctx.metrics.dp(80))
		var id: String = cid
		b.activated.connect(func(): CaseFlow.enter_case(ctx, id, "board"))
		body.add_child(b)
		_cards[cid] = b
	var stamp := UiStyle.label(ctx.metrics, ctx.t("archive_zero"), UiStyle.SECONDARY_SP, UiStyle.SUBDUED, true)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(stamp)
	refresh()
	return self

static func ctx_title(c: AppContext) -> String:
	return c.t("board_title")

func refresh() -> void:
	var s := ctx.state()
	_xp.text = ctx.t("board_xp") % int(s["campaign"]["xp"])
	for cid in _cards:
		var def := ctx.db.case_def(cid)
		var b: CzButton = _cards[cid]
		var status := Selectors.board_status(ctx.db, s, cid)
		var run := Selectors.run_of(s, cid)
		var line := "%s — %s" % [cid, def.title()]
		b.set_text(line)
		match status:
			"locked":
				b.set_disabled(true, ctx.t("board_locked"))
			"new":
				b.set_disabled(false)
				b.set_sub(ctx.t("board_new"))
			"in_progress":
				b.set_disabled(false)
				var sub := ctx.t("evidence_button") % [Selectors.required_found(def, run), Selectors.required_total(def)]
				if s["last_case"] == cid:
					sub = ctx.t("board_continue") + " • " + sub
				b.set_sub(sub)
			"solved":
				b.set_disabled(false)
				b.set_sub("✓ " + ctx.t("board_solved") + " • " + ctx.t("archive_zero"))
