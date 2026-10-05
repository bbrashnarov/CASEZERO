class_name InteractionProfile
extends RefCounted
## Reusable object interaction handler. The object definition chooses a profile and supplies
## its parameters; the profile turns (object, run) into what an accepted TAP reveals.
## Profiles never mutate state: the reducer applies their resolution transactionally.

func id() -> String:
	return "NONE"

## Returns {"detail_text", "evidence": [EvidenceID], "variant": String}.
func resolve(obj: Dictionary, _run: Dictionary) -> Dictionary:
	return {"detail_text": str(obj.get("detail_text", "")), "evidence": obj.get("evidence", []).duplicate(), "variant": "BASE"}

## Local CTA inside the inspection panel (only P_CHARGER in this slice).
func cta(_obj: Dictionary) -> Dictionary:
	return {}

## Visual variant key for scene/detail art (physical state), independent of inspection state.
func art_variant(obj: Dictionary, run: Dictionary) -> String:
	var vf = obj.get("variant_field")
	if vf != null and run.has(vf):
		return str(run[vf])
	return "BASE"
