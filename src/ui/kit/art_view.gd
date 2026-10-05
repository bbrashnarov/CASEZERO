class_name ArtView
extends Control
## Aspect-fit image by AssetID (spec: detail image aspect-fit, no cropped timestamps). Missing
## binaries render as a labelled greybox so placeholder art is never mistaken for final art.

var ctx: AppContext
var asset_id := ""
var variant := ""
var caption := ""
var aspect := 888.0 / 456.0

func setup(context: AppContext, id: String, v := "", cap := "", aspect_ratio := 888.0 / 456.0) -> ArtView:
	ctx = context
	asset_id = id
	variant = v
	caption = cap
	aspect = aspect_ratio
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return self

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		custom_minimum_size.y = size.x / aspect
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var tex := ctx.assets.texture(asset_id, variant) if asset_id != "" else null
	if tex:
		var ts := tex.get_size()
		var k := minf(r.size.x / ts.x, r.size.y / ts.y)
		var d := ts * k
		draw_texture_rect(tex, Rect2(r.position + (r.size - d) * 0.5, d), false)
		return
	draw_rect(r, InvestigationView.GREY_OBJ)
	draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
	var fs := ctx.metrics.sp(UiStyle.SECONDARY_SP)
	var y := fs + 8.0
	for line in [caption, asset_id + (" · " + variant if variant != "" else ""), "GREYBOX"]:
		if line != "":
			draw_string(UiStyle.regular, Vector2(12, y), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, fs, Color(1, 1, 1, 0.85))
			y += fs + 6
