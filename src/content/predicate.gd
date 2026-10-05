class_name Predicate
extends RefCounted
## JSON predicate DSL used by gates, stage unlocks, success predicates, hint targets and
## content invariants. Evaluated only against domain state (run + campaign), never UI state.
##
##   true / false
##   {"all": [p...]} {"any": [p...]} {"not": p}
##   {"has_all": [EvidenceID...]}       every ID is in runs[case].evidence
##   {"q": QuestionID}                  runs[case].questions[id] == true
##   {"field": name, "eq": value}       runs[case][name] == value (case run_fields)
##   {"campaign_completed": CaseID}

const OPS := ["all", "any", "not", "has_all", "q", "field", "campaign_completed"]

static func eval(p: Variant, run: Dictionary, campaign: Dictionary) -> bool:
	if p == null:
		return false
	if typeof(p) == TYPE_BOOL:
		return p
	if not (p is Dictionary):
		Log.e(Log.CONTENT, "predicate: unsupported node", {"node": str(p)})
		return false
	var d: Dictionary = p
	if d.has("all"):
		for c in d["all"]:
			if not eval(c, run, campaign):
				return false
		return true
	if d.has("any"):
		for c in d["any"]:
			if eval(c, run, campaign):
				return true
		return false
	if d.has("not"):
		return not eval(d["not"], run, campaign)
	if d.has("has_all"):
		var ev: Array = run.get("evidence", [])
		for id in d["has_all"]:
			if not ev.has(id):
				return false
		return true
	if d.has("q"):
		return bool(run.get("questions", {}).get(d["q"], false))
	if d.has("field"):
		return run.get(d["field"]) == d.get("eq")
	if d.has("campaign_completed"):
		return bool(campaign.get("completed", {}).get(d["campaign_completed"], false))
	Log.e(Log.CONTENT, "predicate: unknown operator", {"node": JSON.stringify(d)})
	return false

## Collects every reference a predicate makes, for the content validator.
static func collect(p: Variant, out: Dictionary) -> Dictionary:
	for k in ["evidence", "questions", "fields", "cases", "errors"]:
		if not out.has(k):
			out[k] = []
	if p == null or typeof(p) == TYPE_BOOL:
		return out
	if not (p is Dictionary):
		out["errors"].append("non-dictionary node %s" % str(p))
		return out
	var d: Dictionary = p
	var known := false
	for op in OPS:
		if d.has(op):
			known = true
	if not known:
		out["errors"].append("unknown operator in %s" % JSON.stringify(d))
		return out
	for key in ["all", "any"]:
		if d.has(key):
			for c in d[key]:
				collect(c, out)
	if d.has("not"):
		collect(d["not"], out)
	if d.has("has_all"):
		out["evidence"].append_array(d["has_all"])
	if d.has("q"):
		out["questions"].append(d["q"])
	if d.has("field"):
		out["fields"].append(d["field"])
	if d.has("campaign_completed"):
		out["cases"].append(d["campaign_completed"])
	return out
