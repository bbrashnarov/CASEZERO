class_name SaveCodec
extends RefCounted
## Snapshot envelope: {"format", "schema_version", "checksum", "payload"} where payload is the
## canonical JSON string of the GameState and checksum is its SHA-256. Keeping the payload as a
## string makes the checksum independent of key order or float formatting on re-parse.

const FORMAT := "CASEZERO_SAVE"

static func encode(state: Dictionary) -> String:
	var payload := JSON.stringify(state, "", true)
	return JSON.stringify({"format": FORMAT, "schema_version": int(state.get("schema_version", 0)),
		"checksum": payload.sha256_text(), "payload": payload})

## Returns {"ok": bool, "state": Dictionary, "error": String}.
static func decode(text: Variant) -> Dictionary:
	if text == null or str(text).strip_edges() == "":
		return {"ok": false, "state": {}, "error": "empty"}
	var env = _parse(str(text))
	if not (env is Dictionary):
		return {"ok": false, "state": {}, "error": "envelope not json"}
	if env.get("format") != FORMAT or not env.has("payload") or not env.has("checksum"):
		return {"ok": false, "state": {}, "error": "envelope format"}
	var payload := str(env["payload"])
	if payload.sha256_text() != str(env["checksum"]):
		return {"ok": false, "state": {}, "error": "checksum mismatch"}
	var state = _parse(payload)
	if not (state is Dictionary):
		return {"ok": false, "state": {}, "error": "payload not object"}
	return {"ok": true, "state": GameState.normalize(state), "error": ""}

## JSON.parse_string() logs an engine error for invalid input; corruption is an expected case here.
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data
