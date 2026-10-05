class_name SettingsScreen
extends ScreenBase
## G_SETTINGS: Sound, Haptic, Reduced Motion toggles, persisted immediately via SET_SETTING.
## Playtest/dev builds additionally show the build version and the explicit log export.

const TOGGLES := [["UI_SOUND", "sound", "setting_sound"], ["UI_HAPTIC", "haptic", "setting_haptic"],
	["UI_REDUCED_MOTION", "reduced_motion", "setting_reduced_motion"]]

var _buttons := {}

func setup(context: AppContext, r: Dictionary) -> SettingsScreen:
	init_screen(context, r, context.t("settings_title"))
	var close := CzButton.new().setup(ctx, "UI_CLOSE", "✕")
	if "accessibility_name" in close:
		close.set("accessibility_name", ctx.t("close"))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.activated.connect(func(): ctx.router.set_base(Router.board()))
	top_bar.add_child(close)
	for t in TOGGLES:
		var b := CzButton.new().setup(ctx, t[0], "")
		b.align_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, ctx.metrics.dp(56))
		var key: String = t[1]
		b.activated.connect(func(): _toggle(key))
		body.add_child(b)
		_buttons[key] = [b, t[2]]
	if ctx.platform.is_playtest or ctx.platform.is_dev:
		add_text(ctx.t("build_version") % ctx.platform.build_id(), UiStyle.SECONDARY_SP, UiStyle.SUBDUED).name = "BuildVersion"
		var export := CzButton.new().setup(ctx, "UI_EXPORT_LOG", ctx.t("export_log"))
		export.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		export.activated.connect(_export)
		body.add_child(export)
	refresh()
	return self

func refresh() -> void:
	var s: Dictionary = ctx.state()["settings"]
	for key in _buttons:
		var b: CzButton = _buttons[key][0]
		var on := bool(s[key])
		b.set_text("%s: %s" % [ctx.t(_buttons[key][1]), ctx.t("setting_on") if on else ctx.t("setting_off")])
		b.set_selected(on)

func _toggle(key: String) -> void:
	var v := not bool(ctx.state()["settings"][key])
	ctx.perform(CZ.SET_SETTING, {"key": key, "value": v}, func(_r):
		ctx.settings_changed.emit()
		refresh())

func _export() -> void:
	var r := ctx.analytics.export_log()
	if r["ok"]:
		DisplayServer.clipboard_set(r["json"])
		ctx.toast(ctx.t("export_done") % r["path"], 4000)
	else:
		ctx.toast(ctx.t("export_failed"), 2500, "error")
