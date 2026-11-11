extends Node
## Plays short sounds by name from res://assets/audio/sfx/<name>.wav.
## A missing file is silently skipped, so gameplay code can name a sound
## before it exists.

const DIR := "res://assets/audio/sfx/"
const VOICES := 12

var muted := false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + String(sound) + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func play(sound: StringName, volume_db: float = 0.0, pitch_spread: float = 0.07) -> void:
	if muted:
		return
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


## Start a looping bed (ambience). Calling it again with the same name is a no-op.
func loop(sound: StringName, volume_db: float = -8.0) -> void:
	if muted or _loops.has(sound):
		return
	var stream := _stream(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	_loops[sound] = p
