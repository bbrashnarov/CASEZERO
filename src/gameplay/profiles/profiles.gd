class_name Profiles
extends RefCounted
## Registry: profile ID (content) -> handler instance.

static var _registry := {}

static func get_profile(profile_id: String) -> InteractionProfile:
	if _registry.is_empty():
		for p in [PInspect.new(), PPhone.new(), PCharger.new(), PManager.new()]:
			_registry[p.id()] = p
	return _registry.get(profile_id)
