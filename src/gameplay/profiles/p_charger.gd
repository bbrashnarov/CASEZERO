class_name PCharger
extends InteractionProfile
## P_CHARGER (spec Part 2): opening the panel never charges the phone. The local CTA dispatches
## CONNECT_CHARGER, which applies the content-defined effects atomically.

func id() -> String:
	return CZ.P_CHARGER

func cta(obj: Dictionary) -> Dictionary:
	return obj.get("cta", {})
