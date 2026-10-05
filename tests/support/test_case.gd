class_name TestCase
extends RefCounted
## Minimal assertion base for the headless runner (no third-party addon needed).

var failures: Array = []
var current_test := ""

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])

func assert_true(v: bool, msg := "expected true") -> void:
	if not v:
		fail(msg)

func assert_false(v: bool, msg := "expected false") -> void:
	if v:
		fail(msg)

## Numbers compare by value (JSON content parses ints as floats); containers compare deeply.
static func deep_eq(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not deep_eq(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not deep_eq(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b

func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if deep_eq(actual, expected):
		return
	fail("%s expected <%s> got <%s>" % [msg, str(expected), str(actual)])

func assert_ne(actual: Variant, other: Variant, msg := "") -> void:
	if actual == other:
		fail("%s expected value different from <%s>" % [msg, str(other)])

func assert_has(container: Variant, item: Variant, msg := "") -> void:
	if not container.has(item):
		fail("%s expected %s to contain <%s>" % [msg, str(container), str(item)])

func assert_not_has(container: Variant, item: Variant, msg := "") -> void:
	if container.has(item):
		fail("%s expected %s NOT to contain <%s>" % [msg, str(container), str(item)])

func event_names(res: Dictionary) -> Array:
	return res.get("events", []).map(func(e): return e["name"])
