class_name BootScreen
extends ScreenBase
## G_BOOT: static CASE ZERO logo, no artificial minimum wait; readable error + retry on failure.

signal retry_requested()

var _status: Label

func setup(context: AppContext, r: Dictionary) -> BootScreen:
	init_screen(context, r, "")
	var logo := UiStyle.label(ctx.metrics, ctx.t("app_title"), 40, UiStyle.PANEL, true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.name = "Logo"
	body.add_child(logo)
	_status = add_text(ctx.t("boot_loading"), UiStyle.SECONDARY_SP, UiStyle.SUBDUED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return self

func show_error(detail: String) -> void:
	_status.text = ctx.t("boot_error") + ("\n" + detail if ctx.platform.is_dev and detail != "" else "")
	_status.add_theme_color_override("font_color", UiStyle.ERROR)
	if footer.get_child_count() == 0:
		var b := primary_button(ctx.t("boot_retry"))
		b.activated.connect(func(): retry_requested.emit())
