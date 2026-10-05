class_name CZ
extends RefCounted
## Canonical engine-side identifiers that are NOT content data.
## Content IDs (objects, evidence, stages, assets, texts) live only in res://content/*.json.

# --- Semantic domain actions (spec Part 12 §G) -------------------------------
const START_CASE := "START_CASE"
const INSPECT_OBJECT := "INSPECT_OBJECT"
const CONNECT_CHARGER := "CONNECT_CHARGER"
const PLACE_TIMELINE_TOKEN := "PLACE_TIMELINE_TOKEN"
const SUBMIT_STAGE := "SUBMIT_STAGE"
const REQUEST_HINT := "REQUEST_HINT"
const RESET_RUN := "RESET_RUN"
const SET_SETTING := "SET_SETTING"
const NAVIGATE := "NAVIGATE"
## Metrics-only bookkeeping (Part 10 active_ms "checkpoint each 5s"). Not a gameplay action:
## a failed write is logged and retried on the next checkpoint instead of opening G_WRITE_ERROR.
const CHECKPOINT_ACTIVE_TIME := "CHECKPOINT_ACTIVE_TIME"

const GAMEPLAY_ACTIONS := [START_CASE, INSPECT_OBJECT, CONNECT_CHARGER, PLACE_TIMELINE_TOKEN,
	SUBMIT_STAGE, REQUEST_HINT, RESET_RUN, SET_SETTING, NAVIGATE]

# --- Dispatch statuses ----------------------------------------------------------
const OK := "OK"                      # committed (persisted when state changed)
const NOOP := "NOOP"                  # accepted, nothing to change (e.g. locked gate, repeat)
const REJECTED := "REJECTED"          # guard rejection, no state change, no attempt
const DUPLICATE := "DUPLICATE"        # action_id already committed: prior result returned
const WRITE_FAILED := "WRITE_FAILED"  # persistence failed: live state unchanged

# --- Result codes ---------------------------------------------------------------
const PRECONDITION_MISSING := "PRECONDITION_MISSING"
const INVALID_SELECTION := "INVALID_SELECTION"
const GATE_LOCKED := "GATE_LOCKED"
const ROUTE_INVALID := "ROUTE_INVALID"
const UNKNOWN_CASE := "UNKNOWN_CASE"
const UNKNOWN_OBJECT := "UNKNOWN_OBJECT"
const UNKNOWN_STAGE := "UNKNOWN_STAGE"
const NOT_INTERACTIVE := "NOT_INTERACTIVE"
const CASE_LOCKED := "CASE_LOCKED"
const NOT_STARTED := "NOT_STARTED"
const ALREADY_STARTED := "ALREADY_STARTED"
const ALREADY_SOLVED := "ALREADY_SOLVED"
const STAGE_ALREADY_PASSED := "STAGE_ALREADY_PASSED"
const ALREADY_DONE := "ALREADY_DONE"
const CORRECT := "CORRECT"
const WRONG := "WRONG"
const SOLVED := "SOLVED"
const INVALID_PAYLOAD := "INVALID_PAYLOAD"
const INVARIANT_VIOLATION := "INVARIANT_VIOLATION"
const BUSY := "BUSY"

# --- Inspection knowledge state (P_INSPECT) ------------------------------------
const UNSEEN := "UNSEEN"
const SEEN := "SEEN"

# --- Interaction profiles (spec Part 2) ----------------------------------------
const P_INSPECT := "P_INSPECT"
const P_PHONE := "P_PHONE"
const P_CHARGER := "P_CHARGER"
const P_MANAGER := "P_MANAGER"

# --- Stage types ---------------------------------------------------------------
const STAGE_SINGLE_ANSWER := "single_answer"
const STAGE_EVIDENCE_SET := "evidence_set"
const STAGE_TIMELINE := "timeline"

# --- Haptic levels -------------------------------------------------------------
const HAPTIC_NONE := "NONE"
const HAPTIC_LIGHT := "LIGHT"
const HAPTIC_MEDIUM := "MEDIUM"

# --- Rewards (DD09) -----------------------------------------------------------
const XP_FIRST_SOLVE := 100
const HINT_MAX_LEVEL := 3

# --- Canonical canvas (spec Part 3, DD10) -------------------------------------
const CANVAS_W := 1080
const CANVAS_H := 1920
const SCENE_RECT := Rect2(0, 264, 1080, 1332)

# --- Input contract (spec Part 2) ---------------------------------------------
const TAP_MAX_MOVE_DP := 12.0
const TAP_MAX_DURATION_MS := 500
const MIN_TOUCH_DP := 48.0
const PICKER_OVERLAP_RATIO := 0.25
const UI_TAP_SOUND_MIN_INTERVAL_MS := 100

# --- Timings (spec Part 9 animation manifest) ---------------------------------
const AN_PRESS_MS := 80
const AN_MODAL_IN_MS := 180
const AN_MODAL_OUT_MS := 120
const AN_CLUE_SNAP_MS := 120
const AN_CLUE_TOAST_MS := 700
const CLUE_TOAST_DELAY_MS := 180
const AN_HINT_PULSE_MS := 600
const AN_HINT_PULSE_COUNT := 2
const AN_CONNECT_MS := 250
const AN_STAGE_OK_MS := 180
const AN_SOLVED_MS := 300
const AN_XP_MS := 500
const AN_ERROR_MS := 1500
const LOCKED_FEEDBACK_MS := 1500
const Q_INTERMEDIATE_FEEDBACK_MS := 600

# --- Persistence / analytics budgets -----------------------------------------
const SCHEMA_VERSION := 1
const ACTIVE_TIME_CHECKPOINT_MS := 5000
const ANALYTICS_BUDGET_BYTES := 5 * 1024 * 1024
const COMMITTED_ACTION_JOURNAL := 128
