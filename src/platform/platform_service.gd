class_name PlatformService
extends RefCounted
## Android/desktop differences in one place: safe area, density (dp), system font scale,
## vibration capability and build flavour. Gameplay never talks to the platform directly.

var is_mobile := OS.has_feature("mobile")
var is_dev := OS.has_feature("dev") or OS.has_feature("editor")
var is_playtest := OS.has_feature("playtest")
## QA override (dev builds / tests): {"font_scale": float, "insets_dp": [l, t, r, b], "unit": float}
var override := {}

func build_flavor() -> String:
	if is_playtest:
		return "playtest"
	if is_dev:
		return "dev"
	return "release"

func build_id() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return "%s-%s" % [v, build_flavor()]

## Logical units per dp for a shell of `logical_size` shown in the current window.
func units_per_dp(logical_size: Vector2) -> float:
	if override.has("unit"):
		return float(override["unit"])
	if is_mobile:
		var dpi := float(DisplayServer.screen_get_dpi())
		var win := Vector2(DisplayServer.window_get_size())
		if dpi > 0 and win.x > 0 and logical_size.x > 0:
			var px_per_logical := win.x / logical_size.x
			return (dpi / 160.0) / px_per_logical
	# Desktop preview: the canonical 1080 px width represents a 360 dp phone (spec baseline).
	return 3.0

## Safe rect inside a full-window shell of `logical_size` (status bar, navigation bar, cutouts).
func safe_rect(logical_size: Vector2) -> Rect2:
	var unit := units_per_dp(logical_size)
	if override.has("insets_dp"):
		var ins: Array = override["insets_dp"]
		return Rect2(ins[0] * unit, ins[1] * unit, logical_size.x - (ins[0] + ins[2]) * unit, logical_size.y - (ins[1] + ins[3]) * unit)
	if is_mobile:
		var win := Vector2(DisplayServer.window_get_size())
		var sa := DisplayServer.get_display_safe_area()
		if win.x > 0 and sa.size.x > 0:
			var k := logical_size.x / win.x
			return Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k).intersection(Rect2(Vector2.ZERO, logical_size))
	return Rect2(Vector2.ZERO, logical_size)

## Android system font scale (Settings > Display > Font size), clamped to the supported 1.0–2.0.
func font_scale() -> float:
	if override.has("font_scale"):
		return clampf(float(override["font_scale"]), 1.0, 2.0)
	if OS.get_name() == "Android":
		var s := _android_font_scale()
		if s > 0.0:
			return clampf(s, 1.0, 2.0)
	return 1.0

func _android_font_scale() -> float:
	# Settings.System.getFloat(resolver, "font_scale", 1.0) through the JNI wrapper; any failure
	# falls back to 1.0 instead of breaking boot.
	if not Engine.has_singleton("AndroidRuntime"):
		return -1.0
	var rt = Engine.get_singleton("AndroidRuntime")
	if rt == null or not rt.has_method("getActivity"):
		return -1.0
	var activity = rt.getActivity()
	if activity == null:
		return -1.0
	var settings = JavaClassWrapper.wrap("android.provider.Settings$System")
	if settings == null:
		return -1.0
	var v = settings.getFloat(activity.getContentResolver(), "font_scale", 1.0)
	if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
		return float(v)
	return -1.0

func vibrate(duration_ms: int, amplitude: float) -> void:
	if is_mobile:
		Input.vibrate_handheld(duration_ms, amplitude)
