class_name TapGesture
extends RefCounted
## The input contract (spec Part 2) in one place, shared by scene objects and UI controls:
## a tap is accepted on pointer-up when the pointer moved <= 12 dp and was held <= 500 ms.
## One active pointer; extra pointers are ignored; cancel clears the pressed state.
## Long press, drag, swipe and pinch are never converted into taps.

signal pressed(pos: Vector2)
signal released()
signal tapped(pos: Vector2)

var unit := 3.0                  ## logical units per dp
var _active := false
var _index := -1
var _start := Vector2.ZERO
var _start_ms := 0
var _cancelled := false
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

func is_pressed() -> bool:
	return _active and not _cancelled

## Feed a local-space input event. Returns true when the event was consumed.
func feed(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return _touch(event.index, event.pressed, event.position, event.canceled)
	if event is InputEventScreenDrag:
		return _move(event.index, event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _touch(0, event.pressed, event.position, false)
	if event is InputEventMouseMotion and _active:
		return _move(0, event.position)
	return false

func cancel() -> void:
	if _active:
		_active = false
		released.emit()

func _touch(index: int, is_down: bool, pos: Vector2, canceled: bool) -> bool:
	if is_down:
		if _active:
			return true      # second finger: ignored while the first is down
		_active = true
		_cancelled = false
		_index = index
		_start = pos
		_start_ms = now_ms.call()
		pressed.emit(pos)
		return true
	if not _active or index != _index:
		return false
	var was_cancelled := _cancelled or canceled
	_active = false
	released.emit()
	if was_cancelled:
		return true
	var moved := pos.distance_to(_start) > CZ.TAP_MAX_MOVE_DP * unit
	var held: bool = int(now_ms.call()) - _start_ms > CZ.TAP_MAX_DURATION_MS
	if not moved and not held:
		tapped.emit(pos)
	return true

func _move(index: int, pos: Vector2) -> bool:
	if not _active or index != _index:
		return false
	if pos.distance_to(_start) > CZ.TAP_MAX_MOVE_DP * unit and not _cancelled:
		_cancelled = true
		released.emit()
	return true
