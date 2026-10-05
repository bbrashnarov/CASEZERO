class_name InspectModal
extends ModalBase
## <CASE>_INSPECT_<OBJECT>: exact detail copy + aspect-fit detail art. Repeat views show
## "Прегледано". Profiles with a local CTA (P_CHARGER) get it in the footer.

var def: CaseDef
var obj: Dictionary
var _art: ArtView
var _cta: CzButton
var _progress: Label

func setup(context: AppContext, r: Dictionary) -> InspectModal:
	init_modal(context, r)
	def = ctx.db.case_def(r["case_id"])
	obj = def.object(r["object_id"])
	build(str(obj["name"]))
	var info: Dictionary = r.get("info", {})
	var profile := Profiles.get_profile(obj["profile"])
	_art = ArtView.new().setup(ctx, str(obj.get("detail_asset_id", "")), profile.art_variant(obj, ctx.run(def.id)), str(obj["name"]))
	_art.name = "DetailImage"
	body.add_child(_art)
	if info.get("repeat", false):
		add_text(ctx.t("inspect_repeat_label"), UiStyle.SECONDARY_SP, UiStyle.SUBDUED, true).name = "RepeatLabel"
	add_text(str(info.get("detail_text", ""))).name = "DetailText"
	var cta := profile.cta(obj)
	if not cta.is_empty():
		_progress = add_text(ctx.t("charger_progress"), UiStyle.SECONDARY_SP, UiStyle.SUCCESS)
		_progress.visible = false
		_cta = primary_button(str(cta["label"]))
		_cta.activated.connect(_on_cta)
		_refresh_cta()
	return self

func _refresh_cta() -> void:
	if _cta == null:
		return
	var cta := Profiles.get_profile(obj["profile"]).cta(obj)
	var enabled := Predicate.eval(cta.get("enabled_when"), ctx.run(def.id), ctx.state()["campaign"])
	if enabled:
		_cta.set_text(str(cta["label"]))
		_cta.set_disabled(false)
	else:
		_cta.set_text(str(cta.get("done_label", cta["label"])))
		_cta.set_disabled(true)

func _on_cta() -> void:
	ctx.perform(CZ.CONNECT_CHARGER, {"case_id": def.id, "object_id": obj["id"]}, func(res):
		if res["status"] == CZ.OK:
			_progress.visible = true
			_art.variant = Profiles.get_profile(obj["profile"]).art_variant(obj, ctx.run(def.id))
			_art.queue_redraw()
			ctx.pulse_requested.emit("CONNECT:" + str(obj["id"]))
		_refresh_cta())

func refresh() -> void:
	_refresh_cta()
