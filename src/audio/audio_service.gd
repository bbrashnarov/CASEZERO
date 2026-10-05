class_name AudioService
extends Node
## Sound Event ID -> AssetID (manifest) -> stream. Gameplay only knows event IDs. Reads settings,
## never writes state. Ambience pauses in background and resumes from the loop boundary.

const POOL := 6

var db: ContentDB
var assets: AssetRegistry
var enabled_provider: Callable = func() -> bool: return true
var played: Array = []    ## recent event IDs (tests, debug overlay)
var _players: Array[AudioStreamPlayer] = []
var _amb: AudioStreamPlayer
var _amb_event := ""
var _last_tap_ms := -100000
var _next := 0

func setup(content: ContentDB, registry: AssetRegistry) -> void:
	db = content
	assets = registry
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = -10.0
	add_child(_amb)

func play(event_id: String) -> void:
	var se = db.sound_events.get(event_id)
	if se == null:
		Log.w(Log.AUDIO, "unknown sound event", {"event": event_id})
		return
	if event_id == "SFX_UI_TAP":
		# Spec Part 9: at most one UI tap sound per 100 ms.
		var now := Time.get_ticks_msec()
		if now - _last_tap_ms < CZ.UI_TAP_SOUND_MIN_INTERVAL_MS:
			return
		_last_tap_ms = now
	played.append(event_id)
	if played.size() > 30:
		played.pop_front()
	if not enabled_provider.call():
		return
	var stream := assets.audio(str(se["asset"]))
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

func start_ambience(event_id: String) -> void:
	if _amb_event == event_id and _amb.playing:
		return
	_amb_event = event_id
	_apply_ambience()

func stop_ambience() -> void:
	_amb_event = ""
	if _amb:
		_amb.stop()

func refresh_settings() -> void:
	_apply_ambience()

func on_background() -> void:
	if _amb:
		_amb.stream_paused = true

func on_foreground() -> void:
	if _amb and _amb_event != "":
		_amb.stream_paused = false
		_apply_ambience()

func _apply_ambience() -> void:
	if _amb == null:
		return
	if _amb_event == "" or not enabled_provider.call():
		_amb.stop()
		return
	var se = db.sound_events.get(_amb_event)
	if se == null:
		return
	var stream := assets.audio(str(se["asset"]))
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	if _amb.stream != stream:
		_amb.stream = stream
	if not _amb.playing:
		_amb.play()
