extends SceneTree
## Headless test runner.
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=<substring>]
## Discovers tests/**/test_*.gd (TestCase subclasses), runs every test_* method, writes
## build/test_results.json and exits non-zero on any failure.

class ErrorCounter extends Logger:
	var count := 0
	var last := ""
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT or error_type == Logger.ERROR_TYPE_ERROR:
			count += 1
			last = "%s %s:%d %s %s" % [function, file, line, code, rationale]
	func _log_message(_message: String, _error: bool) -> void:
		pass

## Script errors abort a test method silently in GDScript; the counter turns them into failures.
var errors := ErrorCounter.new()

const DIRS := ["res://tests/unit", "res://tests/persistence", "res://tests/integration", "res://tests/acceptance", "res://tests/ui"]

func _initialize() -> void:
	OS.add_logger(errors)
	Log.quiet = true
	Log.min_level = Log.Level.WARN
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var results := []
	var total := 0
	var failed := 0
	for dir in DIRS:
		for path in _scripts(dir):
			var script: GDScript = load(path)
			if script == null:
				results.append({"suite": path, "test": "<load>", "ok": false, "failures": ["script failed to load"]})
				failed += 1
				continue
			var methods := []
			for m in script.get_script_method_list():
				if str(m["name"]).begins_with("test_") and not methods.has(m["name"]):
					methods.append(m["name"])
			methods.sort()
			for m in methods:
				var label := "%s::%s" % [path.get_file().get_basename(), m]
				if filter != "" and not label.contains(filter):
					continue
				var inst: TestCase = script.new()
				inst.current_test = m
				inst.before_each()
				var started := Time.get_ticks_msec()
				var errs_before := errors.count
				await inst.call(m)
				inst.after_each()
				if errors.count != errs_before:
					inst.failures.append("engine/script error: " + errors.last)
				total += 1
				var ok := inst.failures.is_empty()
				if not ok:
					failed += 1
				results.append({"suite": path.get_file().get_basename(), "test": m, "ok": ok,
					"failures": inst.failures, "ms": Time.get_ticks_msec() - started})
				print(("PASS  " if ok else "FAIL  ") + label)
				for f in inst.failures:
					print("      " + f)
	print("\n%d tests, %d failed" % [total, failed])
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/test_results.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"engine": Engine.get_version_info()["string"], "total": total,
			"failed": failed, "results": results}, " "))
		f.close()
	quit(1 if failed > 0 or total == 0 else 0)

func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	out.sort()
	return out
