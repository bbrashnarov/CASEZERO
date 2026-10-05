class_name HapticsService
extends RefCounted
## NONE / LIGHT / MEDIUM abstraction (spec Part 9). Settings off or no actuator -> silent; there
## is never a gameplay dependency on haptics.

const PATTERNS := {"LIGHT": [18, 0.35], "MEDIUM": [40, 0.7]}

var platform: PlatformService
var enabled_provider: Callable = func() -> bool: return true
var played: Array = []   ## recent levels, for tests and the debug overlay

func _init(p: PlatformService) -> void:
	platform = p

func play(level: String) -> void:
	if level == CZ.HAPTIC_NONE or not PATTERNS.has(level):
		return
	if not enabled_provider.call():
		return
	played.append(level)
	if played.size() > 20:
		played.pop_front()
	platform.vibrate(PATTERNS[level][0], PATTERNS[level][1])
