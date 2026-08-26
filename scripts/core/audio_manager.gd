extends Node
## Autoload：主音量＋程序化 SFX（方波／噪音合成，零版權素材）。
## 音效分類見 docs/asset-licenses.md；所有波形於執行期生成並快取。

const SETTINGS_PATH := "user://settings.json"
const MIX_RATE := 22050

var master_volume: float = 0.8

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	load_settings()
	_apply_volume()


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_apply_volume()
	save_settings()


# --- 介面音 ---
func play_confirm() -> void:
	_play("confirm", func() -> AudioStreamWAV: return _tone([[760.0, 0.05], [1020.0, 0.05]], 0.22))


func play_cancel() -> void:
	_play("cancel", func() -> AudioStreamWAV: return _tone([[520.0, 0.05], [380.0, 0.05]], 0.2))


func play_bump() -> void:
	_play("bump", func() -> AudioStreamWAV: return _noise(0.05, 0.18, 900.0))


func play_talk() -> void:
	_play("talk", func() -> AudioStreamWAV: return _tone([[880.0, 0.03], [660.0, 0.03]], 0.16))


func play_item() -> void:
	_play("item", func() -> AudioStreamWAV: return _tone([[620.0, 0.05], [820.0, 0.05], [1040.0, 0.06]], 0.22))


func play_door() -> void:
	_play("door", func() -> AudioStreamWAV: return _tone([[300.0, 0.05], [220.0, 0.07]], 0.2))


# --- 腳步 ---
func play_step(kind: String) -> void:
	match kind:
		"grass":
			_play("step_grass", func() -> AudioStreamWAV: return _noise(0.035, 0.1, 2200.0))
		"splash":
			_play("step_splash", func() -> AudioStreamWAV: return _noise(0.07, 0.16, 1400.0))
		_:
			_play("step_hard", func() -> AudioStreamWAV: return _noise(0.03, 0.12, 600.0))


# --- 戰鬥 ---
func play_encounter() -> void:
	_play("encounter", func() -> AudioStreamWAV: return _tone([[880.0, 0.05], [660.0, 0.05], [440.0, 0.05], [330.0, 0.08]], 0.24))


func play_attack() -> void:
	_play("attack", func() -> AudioStreamWAV: return _noise(0.08, 0.16, 3200.0))


func play_hit() -> void:
	_play("hit", func() -> AudioStreamWAV: return _tone([[180.0, 0.04], [140.0, 0.06]], 0.26))


func play_heal() -> void:
	_play("heal", func() -> AudioStreamWAV: return _tone([[523.0, 0.06], [659.0, 0.06], [784.0, 0.08]], 0.2))


func play_capture_throw() -> void:
	_play("throw", func() -> AudioStreamWAV: return _tone([[440.0, 0.04], [560.0, 0.04], [700.0, 0.04]], 0.18))


func play_capture_success() -> void:
	_play("caught", func() -> AudioStreamWAV: return _tone([[523.0, 0.08], [659.0, 0.08], [784.0, 0.08], [1046.0, 0.14]], 0.22))


func play_capture_fail() -> void:
	_play("escaped", func() -> AudioStreamWAV: return _tone([[500.0, 0.06], [420.0, 0.06], [330.0, 0.1]], 0.2))


func play_fanfare() -> void:
	play_capture_success()


# --- 內部 ---

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


func _play(key: String, builder: Callable) -> void:
	if _players.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = builder.call()
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _cache[key]
	player.play()


## 方波音序：notes = [[頻率, 秒數], ...]
static func _tone(notes: Array, volume: float) -> AudioStreamWAV:
	var total := 0.0
	for note: Variant in notes:
		total += float(Array(note)[1])
	var frames := int(total * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var index := 0
	for note: Variant in notes:
		var freq := float(Array(note)[0])
		var duration := float(Array(note)[1])
		var note_frames := int(duration * MIX_RATE)
		for i in range(note_frames):
			if index >= frames:
				break
			var t := float(index) / float(MIX_RATE)
			var envelope := 1.0 - float(index) / float(frames)
			var square := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
			data.encode_s16(index * 2, int(clampf(volume * envelope * square, -1.0, 1.0) * 32767.0))
			index += 1
	return _wrap(data)


## 濾波噪音（腳步、撞擊、揮擊）
static func _noise(duration: float, volume: float, cutoff: float) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff)
	var previous := 0.0
	var alpha := clampf(cutoff / float(MIX_RATE), 0.02, 0.9)
	for i in range(frames):
		var envelope := 1.0 - float(i) / float(frames)
		var raw := rng.randf_range(-1.0, 1.0)
		previous += alpha * (raw - previous)
		data.encode_s16(i * 2, int(clampf(volume * envelope * previous * 2.0, -1.0, 1.0) * 32767.0))
	return _wrap(data)


static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
