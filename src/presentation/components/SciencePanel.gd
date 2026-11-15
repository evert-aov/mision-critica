@tool
class_name SciencePanel
extends NinePatchRect
## Right Cockpit Panel (166x208): flyby & pointing/HGA header with live kbps rate,
## scrollable CRT science terminal (sensors, MB progress, required markers), and goal bar.

signal instrument_activated(part_id: String)

var _lbl_title: Label
var _radar_sprite: AnimatedSprite2D
var _led_window: AnimatedSprite2D
var _lbl_window: Label
var _lbl_term_hdr: Label
var _lbl_score: Label

var _terminal_scroll: ScrollContainer
var _lbl_data_log: Label
var _last_packet_hash: String = ""
var _last_sim: FlightSimulator

var _sensor_rows: Dictionary = {} # part_id -> { btn, lbl_name, lbl_status, bar }
var _green_frames: SpriteFrames
var _amber_frames: SpriteFrames
var _red_frames: SpriteFrames


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 5.0, true)
	_amber_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_amber_sheet.png", 8, 8, 4.0, true)
	_red_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_red_sheet.png", 8, 8, 6.0, true)
	_build_ui()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String):
			_refresh_static_texts()
			if _last_sim != null:
				update_telemetry(_last_sim)
		)


func _build_ui() -> void:
	_lbl_title = Label.new()
	_lbl_title.text = Loc.pick("CIENCIA Y COMMS", "SCIENCE & COMMS")
	_lbl_title.position = Vector2(7, 5)
	_lbl_title.size = Vector2(152, 10)
	_lbl_title.clip_text = true
	_lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	add_child(_lbl_title)

	# 1. Radar, Sensor Pointing & Earth HGA Link Speed Box (x=6, y=17, w=154, h=38)
	var hdr_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	hdr_box.position = Vector2(6, 17)
	hdr_box.size = Vector2(154, 38)
	hdr_box.clip_contents = true
	add_child(hdr_box)

	_radar_sprite = AnimatedSprite2D.new()
	_radar_sprite.position = Vector2(17, 19)
	_radar_sprite.sprite_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/radar_sheet.png", 28, 28, 8.0, true)
	hdr_box.add_child(_radar_sprite)

	_led_window = AnimatedSprite2D.new()
	_led_window.position = Vector2(38, 9)
	_led_window.sprite_frames = _amber_frames
	hdr_box.add_child(_led_window)

	_lbl_window = Label.new()
	_lbl_window.text = "LEJOS (35%)\nOMNI 18.0kb"
	_lbl_window.position = Vector2(45, 4)
	_lbl_window.size = Vector2(105, 30)
	_lbl_window.clip_text = true
	hdr_box.add_child(_lbl_window)

	# 2. Central Scrollable CRT Science Terminal (x=6, y=58, w=154, h=122)
	var crt_terminal := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 5)
	crt_terminal.position = Vector2(6, 58)
	crt_terminal.size = Vector2(154, 122)
	crt_terminal.clip_contents = true
	add_child(crt_terminal)

	_terminal_scroll = ScrollContainer.new()
	_terminal_scroll.position = Vector2(4, 4)
	_terminal_scroll.size = Vector2(146, 114)
	_terminal_scroll.clip_contents = true
	_terminal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crt_terminal.add_child(_terminal_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	_terminal_scroll.add_child(vbox)

	var sensor_defs := [
		["inst_cam", "F7 CÁMARA"],
		["inst_spec", "F8 ESPECTRO"],
		["inst_radar", "F9 RADAR"],
	]
	for idx in range(sensor_defs.size()):
		var pid: String = sensor_defs[idx][0]
		var pname: String = sensor_defs[idx][1]

		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 4)
		vbox.add_child(row_hbox)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(24, 18)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.texture_normal = load("res://assets/sprites/cockpit/sensor_normal.png")
		btn.texture_hover = load("res://assets/sprites/cockpit/sensor_hover.png")
		btn.texture_pressed = load("res://assets/sprites/cockpit/sensor_pressed.png")
		btn.texture_disabled = load("res://assets/sprites/cockpit/sensor_disabled.png")
		btn.pressed.connect(func():
			AudioManager.play_sfx("science")
			instrument_activated.emit(pid)
		)
		row_hbox.add_child(btn)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		row_hbox.add_child(info_vbox)

		var top_line := HBoxContainer.new()
		top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_child(top_line)

		var lbl_name := Label.new()
		lbl_name.text = pname
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.clip_text = true
		top_line.add_child(lbl_name)

		var lbl_status := Label.new()
		lbl_status.text = "LISTO"
		lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_line.add_child(lbl_status)

		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 1.0
		bar.show_percentage = false
		info_vbox.add_child(bar)

		_sensor_rows[pid] = {
			"btn": btn,
			"base_name": pname,
			"lbl_name": lbl_name,
			"lbl_status": lbl_status,
			"bar": bar,
		}

	var sep := ColorRect.new()
	sep.color = Color("1e4632")
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	_lbl_term_hdr = Label.new()
	_lbl_term_hdr.text = Loc.pick("TERMINAL DE ENLACE:", "DOWNLINK TERMINAL:")
	_lbl_term_hdr.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	vbox.add_child(_lbl_term_hdr)

	_lbl_data_log = Label.new()
	_lbl_data_log.text = Loc.pick("> Apunta [OBJET.] en sobrevuelo y [TIERRA] para HGA.", "> Aim [TARGET] on flyby & [EARTH] for HGA.")
	_lbl_data_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_data_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_data_log.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	vbox.add_child(_lbl_data_log)

	# 3. Bottom Score / Mission Goal Footer (x=6, y=183, w=154, h=19)
	var score_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	score_box.position = Vector2(6, 183)
	score_box.size = Vector2(154, 19)
	add_child(score_box)

	_lbl_score = Label.new()
	_lbl_score.position = Vector2(5, 5)
	_lbl_score.size = Vector2(144, 10)
	_lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_score.clip_text = true
	_lbl_score.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	score_box.add_child(_lbl_score)


func _refresh_static_texts() -> void:
	_lbl_title.text = Loc.pick("CIENCIA Y COMMS", "SCIENCE & COMMS")
	_lbl_term_hdr.text = Loc.pick("TERMINAL DE ENLACE:", "DOWNLINK TERMINAL:")
	var names := {
		"inst_cam": Loc.pick("F7 CÁMARA", "F7 CAMERA"),
		"inst_spec": Loc.pick("F8 ESPECTRO", "F8 IR SPEC"),
		"inst_radar": Loc.pick("F9 RADAR", "F9 RADAR"),
	}
	for pid in _sensor_rows.keys():
		if names.has(pid):
			_sensor_rows[pid]["base_name"] = names[pid]


func update_telemetry(sim: FlightSimulator) -> void:
	if sim == null:
		return
	_last_sim = sim
	_refresh_static_texts()
	var t: FlightTelemetry = sim.telemetry

	var ant_txt: String = Loc.pick("GIRO 0kb", "SPIN 0kb")
	if not t.comms_on or not t.master_bus_on:
		ant_txt = "COMMS OFF"
	elif t.comms_link_factor > 0.0:
		var ant_mode: String = "HGA" if t.comms_link_factor >= 0.9 else "OMNI"
		ant_txt = "%s %.0fkb" % [ant_mode, t.downlink_kbps]

	if t.in_flyby_window:
		if t.target_pointing_ok:
			_led_window.sprite_frames = _green_frames
			if not _led_window.is_playing():
				_led_window.play("default")
			_lbl_window.text = Loc.pick("OBJETIVO 100%%\n%s", "TARGET 100%%\n%s") % ant_txt
			_lbl_window.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		else:
			_led_window.sprite_frames = _amber_frames
			if not _led_window.is_playing():
				_led_window.play("default")
			_lbl_window.text = Loc.pick("APUNTA [OBJ]\n%s", "AIM [TARGET]\n%s") % ant_txt
			_lbl_window.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	else:
		_led_window.sprite_frames = _red_frames if t.is_tumbling else _amber_frames
		_led_window.stop()
		_led_window.frame = 0 if t.is_tumbling else 2
		_lbl_window.text = Loc.pick("CRUCERO 35%%\n%s", "CRUISE 35%%\n%s") % ant_txt
		_lbl_window.add_theme_color_override("font_color", ThemeFactory.COL_RED if t.is_tumbling else ThemeFactory.COL_MUTED)

	var transmitting_any: bool = false
	var packet_lines: PackedStringArray = []
	var req_ids: Array[String] = sim.mission.required_instruments if sim.mission != null else []

	for pid in _sensor_rows.keys():
		var row: Dictionary = _sensor_rows[pid]
		var btn: TextureButton = row["btn"]
		var lbl_name: Label = row["lbl_name"]
		var lbl_status: Label = row["lbl_status"]
		var bar: ProgressBar = row["bar"]
		var is_req: bool = req_ids.has(pid)
		lbl_name.text = ("*" if is_req else "") + str(row["base_name"])

		var installed: bool = sim.design.get_part_count(pid) > 0
		if not installed:
			btn.disabled = true
			lbl_status.text = "N/A"
			lbl_status.add_theme_color_override("font_color", Color("556070"))
			bar.value = 0.0
			continue

		var part_spec: PartSpec = sim.design.get_part_spec(pid)
		var data_mb: float = part_spec.data_volume_mb if part_spec != null else 30.0
		var quality: float = float(t.instruments_captured.get(pid, 0.0))
		var sent: bool = bool(t.instruments_transmitted.get(pid, false))
		var prog: float = sim.get_transmission_progress(pid)

		var bus_ready: bool = t.master_bus_on and t.science_bus_on
		var available_q: float = (1.0 if t.target_pointing_ok else 0.60) if t.in_flyby_window else 0.35
		var can_upgrade: bool = available_q > quality + 0.01
		btn.disabled = (not bus_ready) or (quality > 0.0 and not can_upgrade)

		var short_id: String = "CAM" if pid == "inst_cam" else (Loc.pick("ESP", "IR") if pid == "inst_spec" else "SAR")
		if sent:
			lbl_status.text = "OK %d%%" % int(round(quality * 100.0))
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if quality >= 0.99 else ThemeFactory.COL_AMBER)
			bar.value = 1.0
			packet_lines.append("[TX OK] %s %.0fMB (%d%%)" % [short_id, data_mb, int(round(quality * 100.0))])
		elif quality > 0.0:
			transmitting_any = true
			if not t.comms_on:
				lbl_status.text = Loc.pick("COLA", "QUEUE")
			elif t.comms_link_factor <= 0.0:
				lbl_status.text = Loc.pick("GIRO!", "SPIN!")
			else:
				lbl_status.text = "TX %d%%" % int(round(prog * 100.0))
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_CYAN if t.comms_link_factor > 0.0 else ThemeFactory.COL_RED)
			bar.value = prog
			packet_lines.append("[%s] %.0f/%.0fMB" % [short_id, prog * data_mb, data_mb])
		else:
			lbl_status.text = Loc.pick("LISTO", "READY") if bus_ready else "OFF"
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_AMBER if bus_ready else ThemeFactory.COL_RED)
			bar.value = 0.0

	for entry in t.event_log:
		if (
			entry.find("capturado") != -1 or entry.find("descargado") != -1 or entry.find("transmitido") != -1
			or entry.find("captured") != -1 or entry.find("downloaded") != -1 or entry.find("transmitted") != -1
		):
			packet_lines.append("> " + entry)

	var combined_log: String = Loc.pick(
		"> *Obligatorio. Apunta [OBJET.] y transmite en [TIERRA].",
		"> *Required. Aim [TARGET] & downlink on [EARTH]."
	) if packet_lines.is_empty() else "\n".join(packet_lines)
	if combined_log != _last_packet_hash:
		_last_packet_hash = combined_log
		_lbl_data_log.text = combined_log

	if (transmitting_any and t.comms_on and t.master_bus_on and t.comms_link_factor > 0.0) or t.in_flyby_window:
		if not _radar_sprite.is_playing():
			_radar_sprite.play("default")
	else:
		_radar_sprite.stop()

	if t.science_min_required > 0:
		_lbl_score.text = "SCI:%d/%d (MIN %d)" % [t.science_score, t.science_max, t.science_min_required]
		_lbl_score.add_theme_color_override(
			"font_color",
			ThemeFactory.COL_GREEN if t.science_score >= t.science_min_required else ThemeFactory.COL_AMBER
		)
	else:
		_lbl_score.text = Loc.pick("CIENCIA: %d / %d PTS", "SCIENCE: %d / %d PTS") % [t.science_score, t.science_max]
		_lbl_score.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
