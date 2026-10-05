class_name PickerModal
extends ModalBase
## G_PICKER: when expanded hitboxes overlap too much, list the candidates instead of guessing.
## Rows are ordered by priority descending; the same gates apply after selection.

signal picked(object_id: String)

func setup(context: AppContext, r: Dictionary) -> PickerModal:
	init_modal(context, r)
	var def := ctx.db.case_def(r["case_id"])
	build(ctx.t("picker_title"))
	for oid in r["object_ids"]:
		var o: Dictionary = def.object(oid)
		var b := CzButton.new().setup(ctx, "UI_PICK_" + str(oid), str(o["name"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.silent = true
		var id: String = oid
		b.activated.connect(func(): picked.emit(id))
		body.add_child(b)
	return self
