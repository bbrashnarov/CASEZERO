class_name AssetRegistry
extends RefCounted
## AssetID -> manifest -> runtime resource. Domain code only ever holds AssetIDs.
##
## Resolution outcomes:
##   OK        resource loaded (variant-aware for P_PHONE / P_CHARGER physical states)
##   GREYBOX   no binary delivered yet and the manifest allows greybox: render a labelled
##             placeholder that is honestly marked as such (spec Development greybox)
##   MISSING   critical asset declared but unavailable: the case must not start with an
##             invisible clickable object; callers show a readable error with Asset ID/Case ID/type

const OK := "OK"
const GREYBOX := "GREYBOX"
const MISSING := "MISSING"

var db: ContentDB
var _cache := {}

func _init(content: ContentDB) -> void:
	db = content

func status(asset_id: String, variant := "") -> String:
	var entry = db.assets.get(asset_id)
	if entry == null:
		return MISSING
	var path = _path(entry, variant)
	if path == null:
		if bool(entry.get("critical", false)) and not db.greybox_allowed():
			return MISSING
		return GREYBOX
	if not ResourceLoader.exists(str(path)):
		return MISSING if bool(entry.get("critical", false)) else GREYBOX
	return OK

func texture(asset_id: String, variant := "") -> Texture2D:
	var res = _load(asset_id, variant)
	return res if res is Texture2D else null

func audio(asset_id: String) -> AudioStream:
	var res = _load(asset_id, "")
	return res if res is AudioStream else null

func font(asset_id: String) -> Font:
	var res = _load(asset_id, "")
	return res if res is Font else null

## Critical asset problems for a case, checked before its scene starts (spec Part 12 §D).
## Returns [{asset_id, case_id, expected_type}] — empty when the case may start.
func case_failures(def: CaseDef) -> Array:
	var out := []
	var check := func(asset_id, variants: Array) -> void:
		if asset_id == null:
			return
		var entry = db.assets.get(asset_id)
		var keys := variants if not variants.is_empty() else [""]
		for v in keys:
			if status(str(asset_id), v) == MISSING:
				out.append({"asset_id": asset_id, "case_id": def.id,
					"expected_type": entry.get("type", "unknown") if entry != null else "unknown",
					"variant": v})
	check.call(def.background().get("asset_id"), [])
	for o in def.objects:
		var variants := []
		if o.has("variant_field"):
			variants = def.run_fields()[o["variant_field"]].get("values", [])
		check.call(o.get("asset_id"), variants)
		check.call(o.get("detail_asset_id"), variants)
	for e in def.evidence:
		check.call(e.get("icon"), [])
	return out

func _path(entry: Dictionary, variant: String) -> Variant:
	if variant != "" and entry.has("variants"):
		return entry["variants"].get(variant)
	return entry.get("path")

func _load(asset_id: String, variant: String) -> Variant:
	var key := "%s|%s" % [asset_id, variant]
	if _cache.has(key):
		return _cache[key]
	var entry = db.assets.get(asset_id)
	if entry == null:
		Log.e(Log.ASSET, "unknown asset id", {"asset_id": asset_id})
		return null
	var path = _path(entry, variant)
	if path == null or not ResourceLoader.exists(str(path)):
		return null
	var res = load(str(path))
	if res == null:
		Log.e(Log.ASSET, "asset failed to load", {"asset_id": asset_id, "path_known": true})
	_cache[key] = res
	return res

## Case switches must not accumulate textures (spec Performance): drop everything case-scoped.
func release_case(case_id: String) -> void:
	for key in _cache.keys():
		var aid := str(key).split("|")[0]
		var entry = db.assets.get(aid, {})
		if entry.get("case") == case_id:
			_cache.erase(key)
