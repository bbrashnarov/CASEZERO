class_name SaveRepository
extends RefCounted
## Crash-safe snapshot persistence.
##
## commit(): the previous committed snapshot is first copied to save.bak (itself an atomic write),
## then the new snapshot atomically replaces save.json. Readers therefore always find at least one
## complete, checksummed snapshot.
## load(): save.json -> (corrupt) keep a diagnostic copy, fall back to save.bak -> (corrupt)
## report CORRUPT so boot can show the recovery dialog. Nothing is silently deleted.

const PRIMARY := "save.json"
const BACKUP := "save.bak"
const CORRUPT_PREFIX := "save.corrupt."

const FRESH := "FRESH"
const LOADED := "LOADED"
const RECOVERED_FROM_BACKUP := "RECOVERED_FROM_BACKUP"
const CORRUPT := "CORRUPT"

var backend: SaveBackend
var last_error := ""
## Dev/QA only (debug overlay, tests): the next N primary writes fail with ERR_FILE_CANT_WRITE.
var debug_fail_next := 0

func _init(b: SaveBackend) -> void:
	backend = b

## Returns {"ok": bool, "error_category": String}.
func commit(state: Dictionary) -> Dictionary:
	var text := SaveCodec.encode(state)
	var prev = backend.read_text(PRIMARY)
	if prev != null and SaveCodec.decode(prev)["ok"]:
		var berr := backend.write_atomic(BACKUP, prev)
		if berr != OK:
			# The backup is a recovery aid; failing to refresh it must not block progress, the
			# primary write below is still atomic.
			Log.w(Log.SAVE, "backup rotation failed", {"err": berr})
	var err: int
	if debug_fail_next > 0:
		# Simulated failure: nothing is written, the previous snapshot stays intact.
		debug_fail_next -= 1
		err = ERR_FILE_CANT_WRITE
	else:
		err = backend.write_atomic(PRIMARY, text)
	if err != OK:
		last_error = error_string(err)
		Log.e(Log.SAVE, "snapshot write failed", {"err": err, "msg": last_error})
		return {"ok": false, "error_category": _category(err)}
	return {"ok": true, "error_category": ""}

## Returns {"status", "state", "source", "error"}.
func load() -> Dictionary:
	var primary = backend.read_text(PRIMARY)
	if primary == null:
		var b = backend.read_text(BACKUP)
		if b == null:
			return {"status": FRESH, "state": {}, "source": "", "error": ""}
		var bd := SaveCodec.decode(b)
		if bd["ok"]:
			return {"status": RECOVERED_FROM_BACKUP, "state": bd["state"], "source": BACKUP, "error": "primary missing"}
		_preserve_corrupt(BACKUP, b)
		return {"status": CORRUPT, "state": {}, "source": "", "error": "backup corrupt: " + bd["error"]}
	var pd := SaveCodec.decode(primary)
	if pd["ok"]:
		return {"status": LOADED, "state": pd["state"], "source": PRIMARY, "error": ""}
	Log.e(Log.SAVE, "primary snapshot corrupt", {"error": pd["error"]})
	_preserve_corrupt(PRIMARY, primary)
	var backup = backend.read_text(BACKUP)
	if backup != null:
		var bd2 := SaveCodec.decode(backup)
		if bd2["ok"]:
			return {"status": RECOVERED_FROM_BACKUP, "state": bd2["state"], "source": BACKUP, "error": pd["error"]}
	return {"status": CORRUPT, "state": {}, "source": "", "error": pd["error"]}

## Keeps a corrupt or unsupported snapshot for local diagnosis before anything replaces it.
func preserve_current(tag: String) -> void:
	var t = backend.read_text(PRIMARY)
	if t != null:
		_preserve_corrupt(tag, t)

func _preserve_corrupt(tag: String, text: String) -> void:
	var name := "%s%s.%d" % [CORRUPT_PREFIX, tag, Time.get_unix_time_from_system()]
	backend.write_atomic(name, text)

static func _category(err: int) -> String:
	match err:
		ERR_FILE_NO_PERMISSION:
			return "PERMISSION"
		ERR_OUT_OF_MEMORY:
			return "NO_SPACE"
		ERR_FILE_CORRUPT:
			return "VERIFY_FAILED"
		_:
			return "WRITE_FAILED"
