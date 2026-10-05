class_name WriteErrorModal
extends ModalBase
## G_WRITE_ERROR: the last action was not saved. Retry re-commits the same transaction; Revert
## returns to the last committed snapshot. No success screen is reachable from here.

func setup(context: AppContext, r: Dictionary) -> WriteErrorModal:
	init_modal(context, r)
	closable = false
	build(ctx.t("write_error_title"))
	var retry := primary_button(ctx.t("write_error_retry"))
	retry.activated.connect(func():
		if not ctx.retry_write():
			ctx.toast(ctx.t("write_error_title"), CZ.AN_ERROR_MS, "error"))
	var revert := CzButton.new().setup(ctx, "UI_REVERT", ctx.t("write_error_revert"))
	revert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	revert.visible = not ctx.state().is_empty()
	revert.activated.connect(func(): ctx.revert_write())
	footer.add_child(revert)
	return self
