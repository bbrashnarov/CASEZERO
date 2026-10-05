class_name Log
extends RefCounted
## Structured logging with the categories required by the brief.
## Production builds log WARN and above; dev builds are verbose.

const BOOT := "BOOT"
const NAV := "NAV"
const GAMEPLAY := "GAMEPLAY"
const STATE := "STATE"
const SAVE := "SAVE"
const CONTENT := "CONTENT"
const ASSET := "ASSET"
const AUDIO := "AUDIO"
const ANALYTICS := "ANALYTICS"
const ERROR := "ERROR"

enum Level { DEBUG, INFO, WARN, ERR }

static var min_level: int = Level.INFO
static var capture: Array = []  ## Tests can inspect recent lines.
static var capture_enabled := false
static var quiet := false

static func configure(verbose: bool) -> void:
	min_level = Level.DEBUG if verbose else Level.WARN

static func d(cat: String, msg: String, data: Dictionary = {}) -> void:
	_emit(Level.DEBUG, cat, msg, data)

static func i(cat: String, msg: String, data: Dictionary = {}) -> void:
	_emit(Level.INFO, cat, msg, data)

static func w(cat: String, msg: String, data: Dictionary = {}) -> void:
	_emit(Level.WARN, cat, msg, data)

static func e(cat: String, msg: String, data: Dictionary = {}) -> void:
	_emit(Level.ERR, cat, msg, data)

static func _emit(level: int, cat: String, msg: String, data: Dictionary) -> void:
	if level < min_level:
		return
	var names := ["D", "I", "W", "E"]
	var line := "[%s][%s] %s" % [names[level], cat, msg]
	if not data.is_empty():
		line += " " + JSON.stringify(data)
	if capture_enabled:
		capture.append(line)
		if capture.size() > 500:
			capture.pop_front()
	if quiet:
		return
	if level >= Level.ERR:
		printerr(line)
	else:
		print(line)
