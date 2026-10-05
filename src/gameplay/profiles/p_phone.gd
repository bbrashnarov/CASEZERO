class_name PPhone
extends InteractionProfile
## P_PHONE (spec Part 2): what the tap reveals depends on the fictional phone_power run field
## (never the device battery API). Each variant lists its evidence; the reducer's idempotent
## add means "+ EV_C02_BATTERY if missing" on the RESTORED tap needs no special case.

func id() -> String:
	return CZ.P_PHONE

func resolve(obj: Dictionary, run: Dictionary) -> Dictionary:
	var key := str(run.get(obj["variant_field"]))
	var v: Dictionary = obj["variants"][key]
	return {"detail_text": str(v["detail_text"]), "evidence": v.get("evidence", []).duplicate(), "variant": key}
