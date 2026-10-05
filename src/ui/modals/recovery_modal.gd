class_name RecoveryModal
extends ModalBase
## Boot recovery (spec Part 10 Restore): invalid run -> offer resetting only that run;
## unreadable campaign or unsupported version -> offer a full restart after keeping the old file.

signal resolved(choice: String)

func setup(context: AppContext, r: Dictionary) -> RecoveryModal:
	init_modal(context, r)
	closable = false
	var info: Dictionary = r.get("info", {})
	build(ctx.t("recovery_title"))
	match info.get("kind"):
		BootService.RECOVER_RUNS:
			for c in info.get("cases", []):
				add_text(ctx.t("recovery_case") % c)
			var b := primary_button(ctx.t("recovery_reset_case"))
			b.activated.connect(func(): resolved.emit(BootService.RECOVER_RUNS))
		BootService.RECOVER_UNSUPPORTED:
			add_text(ctx.t("recovery_unsupported"))
			var b2 := primary_button(ctx.t("recovery_reset_all"))
			b2.activated.connect(func(): resolved.emit(BootService.RECOVER_ALL))
		_:
			add_text(ctx.t("write_error_no_snapshot"))
			var b3 := primary_button(ctx.t("recovery_reset_all"))
			b3.activated.connect(func(): resolved.emit(BootService.RECOVER_ALL))
	return self
