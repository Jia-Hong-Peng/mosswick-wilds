extends Node
## Autoload: master volume + tiny procedural SFX (square-wave beeps).
## No copyrighted audio assets; streams are generated at runtime.

const SETTINGS_PATH := "user://settings.json"
const MIX_RATE := 22050

var master_volume: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _tone_cache: Dictionary = {}


func _ready() -> void:
	for i in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	load_settings()
	_apply_volume()


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_apply_volume()
	save_settings()


func play_confirm() -> void:
	_play_tone(880.0, 0.07)


func play_cancel() -> void:
	_play_tone(440.0, 0.07)


func play_bump() -> void:
	_play_tone(160.0, 0.05)


func play_hit() -> void:
	_play_tone(220.0, 0.1)


func play_fanfare() -> void:
	_play_tone(660.0, 0.12)


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		master_volume = clampf(float(Dictionary(parsed).get("master_volume", master_volume)), 0.0, 1.0)


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"master_volume": master_volume}))
	file.close()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


func _play_tone(frequency: float, duration: float) -> void:
	if _players.is_empty():
		return
	var key := "%d_%d" % [int(frequency), int(duration * 1000.0)]
	if not _tone_cache.has(key):
		_tone_cache[key] = _make_tone(frequency, duration)
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _tone_cache[key]
	player.play()


static func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(MIX_RATE)
		var envelope := 1.0 - float(i) / float(frames)
		var square := 1.0 if fmod(t * frequency, 1.0) < 0.5 else -1.0
		var sample := 0.25 * envelope * square
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
