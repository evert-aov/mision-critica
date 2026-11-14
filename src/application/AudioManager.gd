extends Node
## Autoload singleton: AudioManager
## Plays retro chiptune sound effects and continuous thruster audio.

var _sfx_players: Array[AudioStreamPlayer] = []
var _engine_player: AudioStreamPlayer
var _alarm_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _muted: bool = false


func _ready() -> void:
	for _i in range(6):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	_engine_player = AudioStreamPlayer.new()
	_engine_player.volume_db = -10.0
	add_child(_engine_player)

	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.volume_db = -9.0
	add_child(_alarm_player)

	_load_or_synthesize_streams()


func set_muted(muted: bool) -> void:
	_muted = muted
	if _muted:
		stop_engine_loop()
		stop_alarm_loop()


func is_muted() -> bool:
	return _muted


func play_sfx(sfx_name: String, volume_db: float = -4.0) -> void:
	if _muted or not _streams.has(sfx_name):
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = _streams[sfx_name]
			player.volume_db = volume_db
			player.play()
			return
	_sfx_players[0].stream = _streams[sfx_name]
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


func set_engine_loop(active: bool, throttle: float = 0.5) -> void:
	if _muted or not active or throttle <= 0.01:
		stop_engine_loop()
		return
	if _engine_player.stream == null and _streams.has("engine_hum"):
		_engine_player.stream = _streams["engine_hum"]
	_engine_player.pitch_scale = lerpf(0.8, 1.35, throttle)
	_engine_player.volume_db = lerpf(-16.0, -5.0, throttle)
	if not _engine_player.playing and _engine_player.stream != null:
		_engine_player.play()


func stop_engine_loop() -> void:
	if _engine_player != null and _engine_player.playing:
		_engine_player.stop()


func set_alarm_loop(active: bool) -> void:
	if _muted or not active:
		stop_alarm_loop()
		return
	if _alarm_player.stream == null and _streams.has("alarm_low"):
		_alarm_player.stream = _streams["alarm_low"]
	if not _alarm_player.playing and _alarm_player.stream != null:
		_alarm_player.play()


func stop_alarm_loop() -> void:
	if _alarm_player != null and _alarm_player.playing:
		_alarm_player.stop()


func _load_or_synthesize_streams() -> void:
	var specs := {
		"click": "res://assets/audio/click.wav",
		"switch": "res://assets/audio/switch.wav",
		"ignition": "res://assets/audio/ignition.wav",
		"telemetry": "res://assets/audio/telemetry.wav",
		"science": "res://assets/audio/science.wav",
		"alarm_low": "res://assets/audio/alarm_low.wav",
		"engine_hum": "res://assets/audio/engine_hum.wav",
		"victory": "res://assets/audio/victory.wav",
		"failure": "res://assets/audio/failure.wav",
	}
	for key in specs.keys():
		var path: String = specs[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			_streams[key] = _synthesize_fallback(key)


func _synthesize_fallback(key: String) -> AudioStreamWAV:
	match key:
		"click":
			return _build_tone(660.0, 0.045, 0.25, "square", false)
		"switch":
			return _build_tone(320.0, 0.07, 0.35, "square", false)
		"ignition":
			return _build_noise_burst(0.32, 0.45)
		"telemetry":
			return _build_tone(1040.0, 0.09, 0.22, "square", false)
		"science":
			return _build_dual_tone(780.0, 1180.0, 0.24, 0.28)
		"alarm_low":
			return _build_tone(480.0, 0.35, 0.26, "square", true)
		"engine_hum":
			return _build_noise_burst(0.45, 0.25, true)
		"victory":
			return _build_dual_tone(523.25, 783.99, 0.45, 0.32)
		_:
			return _build_tone(180.0, 0.4, 0.3, "saw", false)


func _build_tone(freq: float, duration_s: float, amp: float, wave: String, loop: bool) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(count)) if not loop else (1.0 if fmod(t, 0.35) < 0.16 else 0.05)
		var phase: float = fmod(t * freq, 1.0)
		var sample_val: float = 0.0
		if wave == "square":
			sample_val = 1.0 if phase < 0.5 else -1.0
		elif wave == "saw":
			sample_val = phase * 2.0 - 1.0
		else:
			sample_val = sin(phase * TAU)
		var pcm: int = clampi(int(sample_val * amp * env * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	return wav


func _build_dual_tone(freq1: float, freq2: float, duration_s: float, amp: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(sample_rate)
		var f: float = freq1 if i < count / 2 else freq2
		var env: float = 1.0 - 0.5 * (float(i) / float(count))
		var s: float = 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0
		var pcm: int = clampi(int(s * amp * env * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav


func _build_noise_burst(duration_s: float, amp: float, loop: bool = false) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp: float = 0.0
	var seed_val: int = 1234567
	for i in range(count):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var white: float = (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * 0.86 + white * 0.14
		var env: float = 1.0 if loop else (1.0 - float(i) / float(count))
		var pcm: int = clampi(int(lp * amp * env * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	return wav
