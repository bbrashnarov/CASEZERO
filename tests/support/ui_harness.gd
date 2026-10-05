class_name UiHarness
extends RefCounted
## Boots the real App (composition root, shell, screens, modals) inside a SubViewport of a given
## device size, with in-memory storage and an isolated analytics directory. Device sizes are given
## in dp and converted the way the project's canvas_items/expand stretch does on a phone.
## `kill_and_restart()` frees the whole App and boots a new one from the same storage.

var tree: SceneTree
var holder: SubViewportContainer
var vp: SubViewport
var app: App
var backend: MemorySaveBackend
var dp_size := Vector2(360, 640)
var font_scale := 1.0
var insets_dp := [0, 0, 0, 0]
var analytics_dir := ""
static var _seq := 0

func _init(device_dp := Vector2(360, 640), fs := 1.0, insets := [0, 0, 0, 0], shared: MemorySaveBackend = null) -> void:
	tree = Engine.get_main_loop() as SceneTree
	dp_size = device_dp
	font_scale = fs
	insets_dp = insets
	backend = shared if shared != null else MemorySaveBackend.new()
	_seq += 1
	analytics_dir = "user://test_analytics/%d_%d" % [Time.get_ticks_usec(), _seq]

## Logical shell size for a phone of `dp_size`: base 1080×1920 expanded along the longer axis.
func logical_size() -> Vector2:
	var aspect := dp_size.y / dp_size.x
	if aspect >= 1920.0 / 1080.0:
		return Vector2(1080, round(1080 * aspect))
	return Vector2(round(1920 / aspect), 1920)

func unit() -> float:
	return logical_size().x / dp_size.x

func boot() -> App:
	holder = SubViewportContainer.new()
	vp = SubViewport.new()
	vp.size = Vector2i(logical_size())
	vp.handle_input_locally = true
	vp.gui_embed_subwindows = true
	holder.add_child(vp)
	tree.root.add_child(holder)
	app = App.new()
	app.backend_override = backend
	app.analytics_dir_override = analytics_dir
	app.platform_override = {"unit": unit(), "font_scale": font_scale, "insets_dp": insets_dp}
	app.size = logical_size()
	vp.add_child(app)
	await frames(2)
	return app

func free_app() -> void:
	if holder and is_instance_valid(holder):
		holder.queue_free()
	await frames(2)

func kill_and_restart() -> App:
	# Nothing in memory survives; only the storage backend does (process-kill model).
	await free_app()
	return await boot()

func cleanup() -> void:
	await free_app()
	_rm_rf(analytics_dir)

static func _rm_rf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)

# --- time ---------------------------------------------------------------------------------

func frames(n := 1) -> void:
	for i in n:
		await tree.process_frame

func wait(ms: int) -> void:
	await tree.create_timer(ms / 1000.0).timeout
	await frames(1)

## Waits out modal transitions / input locks.
func settle() -> void:
	await wait(CZ.AN_MODAL_IN_MS + 40)
	var guard := 0
	while app.ctx.input_locked() and guard < 50:
		await wait(20)
		guard += 1

# --- queries ------------------------------------------------------------------------------

func ctx() -> AppContext:
	return app.ctx

func route() -> String:
	return app.ctx.router.current_id()

func base_id() -> String:
	return str(app.ctx.router.base["id"])

func base() -> Control:
	return app.shell.base_node

func top() -> Control:
	var ms: Array = app.shell._modals
	return ms.back()["node"] if not ms.is_empty() else app.shell.base_node

func run(cid: String) -> Dictionary:
	return app.ctx.run(cid)

func state() -> Dictionary:
	return app.ctx.state()

func find(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name and not root.is_queued_for_deletion():
		return root
	for c in root.get_children():
		var r := find(c, node_name)
		if r:
			return r
	return null

func button(ui_id: String, root: Node = null) -> CzButton:
	return find(root if root else top(), ui_id) as CzButton

func label_text(node_name: String, root: Node = null) -> String:
	var n := find(root if root else top(), node_name)
	return (n as Label).text if n is Label else ""

func all_text(root: Node = null) -> String:
	var out := []
	_collect_text(root if root else top(), out)
	return "\n".join(out)

func _collect_text(n: Node, out: Array) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_text(c, out)

# --- intents (same handlers a tap reaches) -------------------------------------------------

func press(ui_id: String, root: Node = null) -> bool:
	var b := button(ui_id, root)
	if b == null:
		return false
	b.activate()
	await settle()
	return true

func case_view() -> InvestigationView:
	var b := base()
	return (b as CaseScreen).view if b is CaseScreen else null

func tap_object(cid: String, oid: String) -> void:
	var o: Dictionary = app.ctx.db.case_def(cid).object(oid)
	var hb: Array = o["hitbox"]
	case_view().tap_canvas(Vector2(hb[0] + hb[2] * 0.5, hb[1] + hb[3] * 0.5))
	await settle()

func tap_canvas(p: Vector2) -> void:
	case_view().tap_canvas(p)
	await settle()

func close() -> void:
	(top() as ModalBase).request_close()
	await settle()
	await wait(CZ.AN_MODAL_OUT_MS + 40)

func back() -> bool:
	var handled := app.back()
	await settle()
	await wait(CZ.AN_MODAL_OUT_MS + 40)
	return handled

## Real pointer events through the SubViewport (tap contract end to end).
func pointer_tap(screen_pos: Vector2, hold_ms := 60, move := Vector2.ZERO) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen_pos
	down.global_position = screen_pos
	vp.push_input(down)
	await wait(hold_ms)
	if move != Vector2.ZERO:
		var mv := InputEventMouseMotion.new()
		mv.position = screen_pos + move
		mv.global_position = screen_pos + move
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen_pos + move
	up.global_position = screen_pos + move
	vp.push_input(up)
	await settle()

func object_screen_center(cid: String, oid: String) -> Vector2:
	var v := case_view()
	var hb: Array = app.ctx.db.case_def(cid).object(oid)["hitbox"]
	return v.position + v.canvas_to_local(Vector2(hb[0] + hb[2] * 0.5, hb[1] + hb[3] * 0.5))

func analytics_names() -> Array:
	return app.ctx.analytics.recent.map(func(e): return e["event_name"])
