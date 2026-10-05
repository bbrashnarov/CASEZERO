class_name DetailCardModal
extends ModalBase
## <CASE>_DETAIL_CARD(evidence_id): icon, name and the full card text; close returns to EVIDENCE.

func setup(context: AppContext, r: Dictionary) -> DetailCardModal:
	init_modal(context, r)
	var def := ctx.db.case_def(r["case_id"])
	var e: Dictionary = def.evidence_def(r["evidence_id"])
	build(str(e["name"]))
	var icon := ArtView.new().setup(ctx, str(e["icon"]), "", str(e["name"]), 1.0)
	icon.custom_minimum_size = Vector2(ctx.metrics.dp(48), ctx.metrics.dp(48))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(icon)
	if not e.get("required", false):
		add_text(ctx.t("evidence_optional_label"), UiStyle.SECONDARY_SP, UiStyle.SUBDUED, true)
	add_text(str(e["card_text"]), UiStyle.TIMESTAMP_SP).name = "CardText"
	return self
