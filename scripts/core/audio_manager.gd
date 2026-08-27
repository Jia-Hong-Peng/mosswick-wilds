extends Node
## Autoload：音量／輔助設定、程序化 SFX、環境音狀態機與頭目戰音樂。
## 所有聲音皆於執行期以方波／正弦／濾波噪音合成（零外部素材，見
## docs/asset-licenses.md）。環境音參與敘事：霧港村「缺少鐘聲」→
## 通關後鐘聲回歸（docs/vertical-slice-audit.md §9）。

const SETTINGS_PATH := "user://settings.json"
const MIX_RATE := 22050

var master_volume: float = 0.8
var reduce_flash := false
var reduce_shake := false
## Web 品質分級（High：陰影/柔焦/全粒子；Low：blob 陰影、關柔焦、粒子減半）
var quality_high := true

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _cache: Dictionary = {}

var _amb_player: AudioStreamPlayer
var _hum_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_layer: AudioStreamPlayer
var _ambience_profile := ""
var _observing := false


func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_amb_player = AudioStreamPlayer.new()
	_hum_player = AudioStreamPlayer.new()
	_music_player = AudioStreamPlayer.new()
	_music_layer = AudioStreamPlayer.new()
	for extra: AudioStreamPlayer in [_amb_player, _hum_player, _music_player, _music_layer]:
		add_child(extra)
	load_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		quality_high = not is_mobile()
	_apply_volume()


## 行動裝置判定：只看平台，不看「有無觸控螢幕」——
## Windows 觸控筆電算電腦，不顯示螢幕按鍵、預設高畫質。
static func is_mobile() -> bool:
	if OS.has_feature("web"):
		return OS.has_feature("web_android") or OS.has_feature("web_ios")
	return OS.get_name() in ["Android", "iOS"]


# ====== 設定（含 Accessibility） ======

func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_reduce_flash(active: bool) -> void:
	reduce_flash = active
	save_settings()


func set_reduce_shake(active: bool) -> void:
	reduce_shake = active
	save_settings()


func set_quality_high(active: bool) -> void:
	quality_high = active
	save_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		var data := Dictionary(parsed)
		master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
		reduce_flash = bool(data.get("reduce_flash", false))
		reduce_shake = bool(data.get("reduce_shake", false))
		quality_high = bool(data.get("quality_high", not is_mobile()))


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"master_volume": master_volume,
		"reduce_flash": reduce_flash,
		"reduce_shake": reduce_shake,
		"quality_high": quality_high,
	}))
	file.close()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


# ====== 環境音狀態機 ======

## profile: harbor_muted | harbor_restored | trail | station | none
func set_ambience(profile: String) -> void:
	if profile == _ambience_profile:
		return
	_ambience_profile = profile
	if profile == "none":
		_fade_out(_amb_player)
		return
	var key := "amb_" + profile
	if not _cache.has(key):
		_cache[key] = _build_ambience(profile)
	_amb_player.stream = _cache[key]
	_amb_player.volume_db = -60.0
	_amb_player.play()
	var tween := create_tween()
	tween.tween_property(_amb_player, "volume_db", _amb_target_db(), 0.8)


## 觀測模式：環境聲收窄（壓低）＋細微儀器嗡鳴
func set_observe_filter(active: bool) -> void:
	if _observing == active:
		return
	_observing = active
	var tween := create_tween()
	tween.tween_property(_amb_player, "volume_db", _amb_target_db(), 0.4)
	if active:
		if not _cache.has("amb_hum"):
			_cache["amb_hum"] = _build_hum()
		_hum_player.stream = _cache["amb_hum"]
		_hum_player.volume_db = -26.0
		_hum_player.play()
	else:
		_fade_out(_hum_player)


func _amb_target_db() -> float:
	return -22.0 if _observing else -8.0


func play_music(kind: String) -> void:
	if kind == "":
		_fade_out(_music_player)
		_fade_out(_music_layer)
		return
	var key := "music_" + kind
	if not _cache.has(key):
		_cache[key] = _build_music()
	_music_player.stream = _cache[key]
	_music_player.volume_db = -14.0
	_music_player.play()


## 頭目第二階段：加入高音琶音層
func set_music_layer(active: bool) -> void:
	if active:
		if not _cache.has("music_layer"):
			_cache["music_layer"] = _build_music_layer()
		_music_layer.stream = _cache["music_layer"]
		_music_layer.volume_db = -16.0
		_music_layer.play()
	else:
		_fade_out(_music_layer)


func stop_music() -> void:
	play_music("")


func _fade_out(player: AudioStreamPlayer) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, 0.6)
	tween.tween_callback(player.stop)


# ====== 介面與世界 SFX ======

func play_confirm() -> void:
	_play("confirm", func() -> AudioStreamWAV: return _tone([[760.0, 0.05], [1020.0, 0.05]], 0.22))


func play_cancel() -> void:
	_play("cancel", func() -> AudioStreamWAV: return _tone([[520.0, 0.05], [380.0, 0.05]], 0.2))


func play_bump() -> void:
	_play("bump", func() -> AudioStreamWAV: return _noise_sfx(0.05, 0.18, 900.0))


func play_talk() -> void:
	_play("talk", func() -> AudioStreamWAV: return _tone([[880.0, 0.03], [660.0, 0.03]], 0.16))


func play_item() -> void:
	_play("item", func() -> AudioStreamWAV: return _tone([[620.0, 0.05], [820.0, 0.05], [1040.0, 0.06]], 0.22))


func play_door() -> void:
	_play("door", func() -> AudioStreamWAV: return _tone([[300.0, 0.05], [220.0, 0.07]], 0.2))


func play_step(kind: String) -> void:
	match kind:
		"grass":
			_play("step_grass", func() -> AudioStreamWAV: return _noise_sfx(0.035, 0.1, 2200.0))
		"splash":
			_play("step_splash", func() -> AudioStreamWAV: return _noise_sfx(0.07, 0.16, 1400.0))
		_:
			_play("step_hard", func() -> AudioStreamWAV: return _noise_sfx(0.03, 0.12, 600.0))


func play_observe_on() -> void:
	_play("observe_on", func() -> AudioStreamWAV: return _tone([[420.0, 0.06], [560.0, 0.09]], 0.16, "sine"))


func play_observe_off() -> void:
	_play("observe_off", func() -> AudioStreamWAV: return _tone([[560.0, 0.05], [420.0, 0.07]], 0.14, "sine"))


func play_clue() -> void:
	_play("clue", func() -> AudioStreamWAV: return _tone([[700.0, 0.05], [940.0, 0.05], [1180.0, 0.08]], 0.2, "sine"))


func play_bell() -> void:
	_play("bell", func() -> AudioStreamWAV: return _bell_tone())


## 伴獸叫聲：每隻有自己的音色輪廓
func play_cry(creature_id: String) -> void:
	match creature_id:
		"sproutwing":
			_play("cry_sprout", func() -> AudioStreamWAV: return _tone([[880.0, 0.05], [740.0, 0.05], [990.0, 0.09]], 0.2, "sine"))
		"emberhorn":
			_play("cry_ember", func() -> AudioStreamWAV: return _tone([[330.0, 0.06], [262.0, 0.05], [392.0, 0.08]], 0.22))
		"tidecrest":
			_play("cry_tide", func() -> AudioStreamWAV: return _tone([[1180.0, 0.04], [1560.0, 0.04], [1180.0, 0.04], [1760.0, 0.07]], 0.18, "sine"))
		"rockbadger":
			_play("cry_badger", func() -> AudioStreamWAV: return _tone([[130.0, 0.09], [98.0, 0.12]], 0.26))
		_:
			pass


## 認養完成的小樂句
func play_adopt_jingle() -> void:
	_play("adopt", func() -> AudioStreamWAV: return _tone([[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1046.0, 0.16], [880.0, 0.1], [1318.0, 0.26]], 0.22, "sine"))


## 圍欄被撞破的巨響
func play_crash() -> void:
	_play("crash", func() -> AudioStreamWAV: return _crash_sfx())


## 三系技能音色：草＝葉聲、火＝炭裂、水＝水花
func play_skill(element: String) -> void:
	match element:
		"grass":
			_play("skill_grass", func() -> AudioStreamWAV: return _noise_sfx(0.12, 0.14, 2600.0))
		"fire":
			_play("skill_fire", func() -> AudioStreamWAV: return _crackle_sfx())
		"water":
			_play("skill_water", func() -> AudioStreamWAV: return _noise_sfx(0.14, 0.16, 1300.0))
		_:
			play_attack()


## 安撫成功：緩慢上行的暖音
func play_soothe() -> void:
	_play("soothe", func() -> AudioStreamWAV: return _tone([[392.0, 0.12], [440.0, 0.12], [523.0, 0.16], [659.0, 0.26]], 0.2, "sine"))


# ====== 戰鬥 SFX ======

func play_encounter() -> void:
	_play("encounter", func() -> AudioStreamWAV: return _tone([[880.0, 0.05], [660.0, 0.05], [440.0, 0.05], [330.0, 0.08]], 0.24))


func play_attack() -> void:
	_play("attack", func() -> AudioStreamWAV: return _noise_sfx(0.08, 0.16, 3200.0))


func play_hit() -> void:
	_play("hit", func() -> AudioStreamWAV: return _tone([[180.0, 0.04], [140.0, 0.06]], 0.26))


func play_heal() -> void:
	_play("heal", func() -> AudioStreamWAV: return _tone([[523.0, 0.06], [659.0, 0.06], [784.0, 0.08]], 0.2))


func play_guard() -> void:
	_play("guard", func() -> AudioStreamWAV: return _tone([[240.0, 0.05], [240.0, 0.08]], 0.22, "sine"))


func play_jam() -> void:
	_play("jam", func() -> AudioStreamWAV: return _tone([[1400.0, 0.03], [900.0, 0.03], [1400.0, 0.03], [700.0, 0.05]], 0.2))


func play_phase_shift() -> void:
	_play("phase", func() -> AudioStreamWAV: return _tone([[220.0, 0.08], [277.0, 0.08], [330.0, 0.12], [415.0, 0.16]], 0.24))


func play_capture_throw() -> void:
	_play("throw", func() -> AudioStreamWAV: return _tone([[440.0, 0.04], [560.0, 0.04], [700.0, 0.04]], 0.18))


func play_capture_success() -> void:
	_play("caught", func() -> AudioStreamWAV: return _tone([[523.0, 0.08], [659.0, 0.08], [784.0, 0.08], [1046.0, 0.14]], 0.22))


func play_capture_fail() -> void:
	_play("escaped", func() -> AudioStreamWAV: return _tone([[500.0, 0.06], [420.0, 0.06], [330.0, 0.1]], 0.2))


func play_resonance_success() -> void:
	_play("resonance", func() -> AudioStreamWAV: return _tone([[392.0, 0.1], [523.0, 0.1], [659.0, 0.1], [784.0, 0.2], [1046.0, 0.28]], 0.22, "sine"))


func play_level_complete() -> void:
	_play("level_done", func() -> AudioStreamWAV: return _tone([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1046.0, 0.2], [784.0, 0.1], [1046.0, 0.3]], 0.24, "sine"))


func play_fanfare() -> void:
	play_capture_success()


# ====== 合成核心 ======

func _play(key: String, builder: Callable) -> void:
	if _players.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = builder.call()
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _cache[key]
	player.play()


static func _buffer(seconds: float) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(int(seconds * MIX_RATE) * 2)
	return data


static func _mix_add(data: PackedByteArray, index: int, sample: float) -> void:
	var offset := index * 2
	if offset + 1 >= data.size():
		return
	var current := data.decode_s16(offset)
	var mixed := clampi(current + int(sample * 32767.0), -32767, 32767)
	data.encode_s16(offset, mixed)


static func _add_tone(data: PackedByteArray, start_s: float, dur_s: float, freq: float, vol: float, shape: String = "square", decay: bool = true) -> void:
	var start := int(start_s * MIX_RATE)
	var frames := int(dur_s * MIX_RATE)
	for i in range(frames):
		var t := float(i) / float(MIX_RATE)
		var envelope := (1.0 - float(i) / float(frames)) if decay else 1.0
		var value: float
		if shape == "sine":
			value = sin(TAU * freq * t)
		else:
			value = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		_mix_add(data, start + i, vol * envelope * value)


static func _add_noise(data: PackedByteArray, start_s: float, dur_s: float, vol: float, cutoff: float, seed_value: int, fade_in: bool = false) -> void:
	var start := int(start_s * MIX_RATE)
	var frames := int(dur_s * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var previous := 0.0
	var alpha := clampf(cutoff / float(MIX_RATE), 0.01, 0.9)
	for i in range(frames):
		var t := float(i) / float(frames)
		var envelope := sin(t * PI) if fade_in else (1.0 - t)
		previous += alpha * (rng.randf_range(-1.0, 1.0) - previous)
		_mix_add(data, start + i, vol * envelope * previous * 2.0)


static func _wrap_loop(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = data.size() / 2
	return stream


static func _tone(notes: Array, volume: float, shape: String = "square") -> AudioStreamWAV:
	var total := 0.0
	for note: Variant in notes:
		total += float(Array(note)[1])
	var data := _buffer(total)
	var cursor := 0.0
	var index := 0
	for note: Variant in notes:
		var freq := float(Array(note)[0])
		var dur := float(Array(note)[1])
		var fade := 1.0 - cursor / maxf(total, 0.01) * 0.5
		_add_tone(data, cursor, dur, freq, volume * fade, shape)
		cursor += dur
		index += 1
	return _wrap_plain(data)


static func _noise_sfx(duration: float, volume: float, cutoff: float) -> AudioStreamWAV:
	var data := _buffer(duration)
	_add_noise(data, 0.0, duration, volume, cutoff, int(cutoff))
	return _wrap_plain(data)


static func _wrap_plain(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _crash_sfx() -> AudioStreamWAV:
	var data := _buffer(0.6)
	_add_noise(data, 0.0, 0.5, 0.3, 700.0, 71)
	_add_tone(data, 0.0, 0.3, 70.0, 0.24)
	_add_tone(data, 0.05, 0.25, 55.0, 0.18)
	return _wrap_plain(data)


static func _crackle_sfx() -> AudioStreamWAV:
	var data := _buffer(0.22)
	_add_noise(data, 0.0, 0.08, 0.16, 3600.0, 72)
	_add_noise(data, 0.09, 0.06, 0.13, 3200.0, 73)
	_add_tone(data, 0.0, 0.18, 196.0, 0.1)
	return _wrap_plain(data)


static func _bell_tone() -> AudioStreamWAV:
	var data := _buffer(1.4)
	_add_tone(data, 0.0, 1.4, 660.0, 0.16, "sine")
	_add_tone(data, 0.0, 1.1, 990.0, 0.07, "sine")
	_add_tone(data, 0.0, 0.7, 1320.0, 0.04, "sine")
	return _wrap_plain(data)


## 環境音（8 秒循環）：以敘事狀態組層
static func _build_ambience(profile: String) -> AudioStreamWAV:
	var data := _buffer(8.0)
	match profile:
		"harbor_muted", "harbor_restored", "title":
			# 海風（持續低頻噪）＋兩次浪湧
			_add_noise(data, 0.0, 8.0, 0.10, 300.0, 11, true)
			_add_noise(data, 0.6, 2.6, 0.14, 900.0, 12, true)
			_add_noise(data, 4.4, 2.8, 0.13, 900.0, 13, true)
			if profile == "harbor_restored":
				# 浮標鐘聲回歸：每循環一響＋遠處回聲
				_add_tone(data, 1.2, 1.4, 660.0, 0.12, "sine")
				_add_tone(data, 1.2, 1.0, 990.0, 0.05, "sine")
				_add_tone(data, 5.6, 1.2, 660.0, 0.06, "sine")
		"trail":
			# 山風＋葉浪，混入零星異常刮痕
			_add_noise(data, 0.0, 8.0, 0.09, 500.0, 21, true)
			_add_noise(data, 1.4, 1.2, 0.10, 2400.0, 22, true)
			_add_noise(data, 5.2, 1.4, 0.10, 2400.0, 23, true)
			_add_tone(data, 3.1, 0.05, 1800.0, 0.06)
			_add_tone(data, 3.2, 0.04, 1400.0, 0.05)
			_add_tone(data, 6.9, 0.06, 1700.0, 0.06)
		"station":
			# 不穩定機械脈衝＋斷續靜電
			for i in range(6):
				var beat := 0.4 + float(i) * 1.3 + (0.18 if i % 2 == 1 else 0.0)
				_add_tone(data, beat, 0.14, 78.0, 0.16)
				_add_tone(data, beat, 0.06, 156.0, 0.06)
			_add_noise(data, 2.2, 0.3, 0.08, 4000.0, 31)
			_add_noise(data, 5.7, 0.22, 0.08, 4000.0, 32)
			_add_tone(data, 6.6, 0.05, 2100.0, 0.05)
	return _wrap_loop(data)


static func _build_hum() -> AudioStreamWAV:
	var data := _buffer(2.0)
	_add_tone(data, 0.0, 2.0, 110.0, 0.05, "sine", false)
	_add_tone(data, 0.0, 2.0, 220.0, 0.025, "sine", false)
	return _wrap_loop(data)


## 頭目戰底層：3.27 秒（110bpm、8 分）方波 bass 循環
static func _build_music() -> AudioStreamWAV:
	var eighth := 60.0 / 110.0 / 2.0
	var bass_notes: Array = [110.0, 110.0, 130.8, 110.0, 98.0, 98.0, 123.5, 130.8,
		110.0, 110.0, 130.8, 146.8, 98.0, 98.0, 87.3, 98.0]
	var data := _buffer(eighth * bass_notes.size())
	for i in range(bass_notes.size()):
		_add_tone(data, float(i) * eighth, eighth * 0.85, float(bass_notes[i]), 0.11)
		if i % 4 == 0:
			_add_noise(data, float(i) * eighth, 0.05, 0.10, 800.0, 40 + i)
	return _wrap_loop(data)


## 第二階段附加層：高八度 16 分琶音
static func _build_music_layer() -> AudioStreamWAV:
	var sixteenth := 60.0 / 110.0 / 4.0
	var arp: Array = [440.0, 523.3, 659.3, 523.3, 440.0, 523.3, 698.5, 659.3,
		440.0, 523.3, 659.3, 880.0, 392.0, 493.9, 587.3, 493.9,
		440.0, 523.3, 659.3, 523.3, 440.0, 523.3, 698.5, 659.3,
		349.2, 440.0, 523.3, 698.5, 392.0, 493.9, 587.3, 784.0]
	var data := _buffer(sixteenth * arp.size())
	for i in range(arp.size()):
		_add_tone(data, float(i) * sixteenth, sixteenth * 0.7, float(arp[i]), 0.05)
	return _wrap_loop(data)
