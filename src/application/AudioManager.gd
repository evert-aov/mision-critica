extends Node
## Autoload singleton: AudioManager
## Plays retro chiptune sound effects and continuous thruster audio.

var _sfx_players: Array[AudioStreamPlayer] = []
var _engine_player: AudioStreamPlayer
var _cruise_player: AudioStreamPlayer
var _alarm_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _muted: bool = false
var internal_audio_mode: bool = false


func _ready() -> void:
	for _i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	_engine_player = AudioStreamPlayer.new()
	_engine_player.volume_db = -10.0
	add_child(_engine_player)

	_cruise_player = AudioStreamPlayer.new()
	_cruise_player.volume_db = -23.0
	add_child(_cruise_player)

	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.volume_db = -9.0
	add_child(_alarm_player)

	_load_or_synthesize_streams()


func set_muted(muted: bool) -> void:
	_muted = muted
	if _muted:
		stop_engine_loop()
		stop_cruise_loop()
		stop_alarm_loop()


func set_internal_audio_mode(enabled: bool) -> void:
	internal_audio_mode = enabled


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


func set_engine_loop(active: bool, throttle: float = 0.5, braking: bool = false) -> void:
	if _muted or not active or throttle <= 0.01:
		stop_engine_loop()
		return
	var stream_key: String = "retro_hum" if braking and _streams.has("retro_hum") else "engine_hum"
	if _streams.has(stream_key) and _engine_player.stream != _streams[stream_key]:
		_engine_player.stream = _streams[stream_key]
		_engine_player.stop()
	if braking:
		_engine_player.pitch_scale = lerpf(0.72, 1.16, throttle) * (0.78 if internal_audio_mode else 1.0)
		_engine_player.volume_db = lerpf(-15.0, -4.5, throttle) - (5.0 if internal_audio_mode else 0.0)
	else:
		var turbo_boost_db: float = 1.5 if throttle >= 0.95 else 0.0
		_engine_player.pitch_scale = lerpf(0.78, 1.48, throttle) * (0.78 if internal_audio_mode else 1.0)
		_engine_player.volume_db = lerpf(-16.0, -4.5, throttle) + turbo_boost_db - (5.0 if internal_audio_mode else 0.0)
	if not _engine_player.playing and _engine_player.stream != null:
		_engine_player.play()


func stop_engine_loop() -> void:
	if _engine_player != null and _engine_player.playing:
		_engine_player.stop()


func set_cruise_loop(active: bool, speed_factor: float = 0.35) -> void:
	if _muted or not active:
		stop_cruise_loop()
		return
	if _cruise_player.stream == null and _streams.has("cruise_hum"):
		_cruise_player.stream = _streams["cruise_hum"]
	var clamped_speed: float = clampf(speed_factor, 0.0, 1.0)
	_cruise_player.pitch_scale = lerpf(0.84, 1.24, clamped_speed) * (0.85 if internal_audio_mode else 1.0)
	_cruise_player.volume_db = lerpf(-26.0, -18.5, clamped_speed) + (2.5 if internal_audio_mode else 0.0)
	if not _cruise_player.playing and _cruise_player.stream != null:
		_cruise_player.play()


func stop_cruise_loop() -> void:
	if _cruise_player != null and _cruise_player.playing:
		_cruise_player.stop()


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
		"cutoff": "res://assets/audio/cutoff.wav",
		"brake": "res://assets/audio/brake.wav",
		"turbo": "res://assets/audio/turbo.wav",
		"rcs": "res://assets/audio/rcs.wav",
		"servo": "res://assets/audio/servo.wav",
		"deploy": "res://assets/audio/deploy.wav",
		"telemetry": "res://assets/audio/telemetry.wav",
		"science": "res://assets/audio/science.wav",
		"alarm_low": "res://assets/audio/alarm_low.wav",
		"engine_hum": "res://assets/audio/engine_hum.wav",
		"retro_hum": "res://assets/audio/retro_hum.wav",
		"cruise_hum": "res://assets/audio/cruise_hum.wav",
		"victory": "res://assets/audio/victory.wav",
		"failure": "res://assets/audio/failure.wav",
	}
	for key in specs.keys():
		var path: String = specs[key]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if key in ["engine_hum", "retro_hum", "cruise_hum", "alarm_low"] and stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				if wav.loop_end <= 0:
					wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
			_streams[key] = stream
		else:
			_streams[key] = _synthesize_fallback(key)
	for extra_key in ["cover", "window_alert", "separation"]:
		_streams[extra_key] = _synthesize_fallback(extra_key)


func _synthesize_fallback(key: String) -> AudioStreamWAV:
	match key:
		"cover":
			return _build_dual_tone(290.0, 480.0, 0.06, 0.24)
		"window_alert":
			return _build_dual_tone(880.0, 1175.0, 0.16, 0.24)
		"separation":
			return _build_noise_burst(0.18, 0.30, false, 0.28)
		"click":
			return _build_tone(660.0, 0.045, 0.25, "square", false)
		"switch":
			return _build_tone(320.0, 0.07, 0.35, "square", false)
		"ignition":
			return _build_noise_burst(0.32, 0.45)
		"cutoff":
			return _build_sweep(340.0, 82.0, 0.22, 0.32, "saw", 0.25)
		"brake":
			return _build_sweep(390.0, 105.0, 0.28, 0.38, "square", 0.35)
		"turbo":
			return _build_sweep(230.0, 920.0, 0.30, 0.38, "saw", 0.22)
		"rcs":
			return _build_noise_burst(0.065, 0.28, false, 0.42)
		"servo":
			return _build_sweep(420.0, 620.0, 0.065, 0.18, "square", 0.0)
		"deploy":
			return _build_dual_tone(440.0, 740.0, 0.22, 0.26)
		"telemetry":
			return _build_tone(1040.0, 0.09, 0.22, "square", false)
		"science":
			return _build_dual_tone(780.0, 1180.0, 0.24, 0.28)
		"alarm_low":
			return _build_tone(480.0, 0.35, 0.26, "square", true)
		"engine_hum":
			return _build_noise_burst(0.45, 0.25, true)
		"retro_hum":
			return _build_pulse_rumble(74.0, 0.50, 0.32, 9.0)
		"cruise_hum":
			return _build_pulse_rumble(96.0, 0.60, 0.16, 2.5)
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


func _build_noise_burst(duration_s: float, amp: float, loop: bool = false, lp_alpha: float = 0.14) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp: float = 0.0
	var seed_val: int = 1234567
	for i in range(count):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var white: float = (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * (1.0 - lp_alpha) + white * lp_alpha
		var env: float = 1.0 if loop else (1.0 - float(i) / float(count))
		var pcm: int = clampi(int(lp * amp * env * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _pack_wav(data, sample_rate, count, loop)


func _build_sweep(f_start: float, f_end: float, duration_s: float, amp: float, wave: String, noise_mix: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var lp: float = 0.0
	var seed_val: int = 98765
	for i in range(count):
		var frac: float = float(i) / float(maxi(1, count))
		var freq: float = lerpf(f_start, f_end, frac)
		phase = fmod(phase + freq / float(sample_rate), 1.0)
		var osc: float = (1.0 if phase < 0.5 else -1.0) if wave == "square" else (phase * 2.0 - 1.0)
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var white: float = (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * 0.78 + white * 0.22
		var sample_val: float = osc * (1.0 - noise_mix) + lp * noise_mix
		var env: float = (1.0 - frac * 0.85) * minf(1.0, frac * 14.0)
		var pcm: int = clampi(int(sample_val * amp * env * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _pack_wav(data, sample_rate, count, false)


func _build_pulse_rumble(base_freq: float, duration_s: float, amp: float, pulse_hz: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration_s * float(sample_rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp: float = 0.0
	var seed_val: int = 445566
	for i in range(count):
		var t: float = float(i) / float(sample_rate)
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var white: float = (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * 0.88 + white * 0.12
		var mod: float = 0.65 + 0.35 * sin(t * pulse_hz * TAU)
		var hum: float = sin(t * base_freq * TAU) * 0.45 + lp * 0.55
		var pcm: int = clampi(int(hum * mod * amp * 32767.0), -32768, 32767)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	return _pack_wav(data, sample_rate, count, true)


func _pack_wav(data: PackedByteArray, sample_rate: int, count: int, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	return wav
