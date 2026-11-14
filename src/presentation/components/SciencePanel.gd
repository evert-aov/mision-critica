@tool
class_name SciencePanel
extends NinePatchRect
## Right Cockpit Panel: scientific sensor activation buttons, flyby window radar,
## transmission progress indicators, and science score counter.

signal instrument_activated(part_id: String)

var _radar_sprite: AnimatedSprite2D
var _led_window: AnimatedSprite2D
var _lbl_window: Label
var _lbl_score: Label

var _sensor_rows: Dictionary = {} # part_id -> { btn, lbl_status, bar }
var _green_frames: SpriteFrames
var _amber_frames: SpriteFrames


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 5.0, true)
	_amber_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_amber_sheet.png", 8, 8, 4.0, true)
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "CIENCIA Y TELEMETRÍA"
	title.position = Vector2(8, 6)
	title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	add_child(title)

	_radar_sprite = AnimatedSprite2D.new()
	_radar_sprite.position = Vector2(24, 38)
	_radar_sprite.sprite_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/radar_sheet.png", 28, 28, 8.0, true)
	add_child(_radar_sprite)

	_led_window = AnimatedSprite2D.new()
	_led_window.position = Vector2(52, 30)
	_led_window.sprite_frames = _amber_frames
	add_child(_led_window)

	_lbl_window = Label.new()
	_lbl_window.text = "EN TRÁNSITO\nESPERA VENTANA"
	_lbl_window.position = Vector2(60, 24)
	_lbl_window.size = Vector2(114, 28)
	add_child(_lbl_window)

	var sensor_defs := [
		["inst_cam", "CÁMARA"],
		["inst_spec", "ESPECTRO"],
		["inst_radar", "RADAR SAR"],
	]
	for idx in range(sensor_defs.size()):
		var pid: String = sensor_defs[idx][0]
		var pname: String = sensor_defs[idx][1]
		var ry: int = 60 + idx * 38

		var btn := TextureButton.new()
		btn.position = Vector2(10, ry)
		btn.size = Vector2(24, 18)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.texture_normal = load("res://assets/sprites/cockpit/sensor_normal.png")
		btn.texture_hover = load("res://assets/sprites/cockpit/sensor_hover.png")
		btn.texture_pressed = load("res://assets/sprites/cockpit/sensor_pressed.png")
		btn.texture_disabled = load("res://assets/sprites/cockpit/sensor_disabled.png")
		btn.pressed.connect(func():
			AudioManager.play_sfx("science")
			instrument_activated.emit(pid)
		)
		add_child(btn)

		var lbl_name := Label.new()
		lbl_name.text = pname
		lbl_name.position = Vector2(38, ry - 1)
		lbl_name.size = Vector2(72, 12)
		add_child(lbl_name)

		var lbl_status := Label.new()
		lbl_status.position = Vector2(108, ry - 1)
		lbl_status.size = Vector2(66, 12)
		lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(lbl_status)

		var bar := ProgressBar.new()
		bar.position = Vector2(38, ry + 13)
		bar.size = Vector2(134, 8)
		bar.max_value = 1.0
		bar.show_percentage = false
		add_child(bar)

		_sensor_rows[pid] = {
			"btn": btn,
			"lbl_status": lbl_status,
			"bar": bar,
		}

	_lbl_score = Label.new()
	_lbl_score.position = Vector2(10, 178)
	_lbl_score.size = Vector2(162, 14)
	_lbl_score.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	add_child(_lbl_score)


func update_telemetry(sim: FlightSimulator) -> void:
	if sim == null:
		return
	var t: FlightTelemetry = sim.telemetry

	if t.in_flyby_window:
		_led_window.sprite_frames = _green_frames
		if not _led_window.is_playing():
			_led_window.play("default")
		_lbl_window.text = "SOBREVUELO\n¡CAPTURAR 100%!"
		_lbl_window.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_led_window.sprite_frames = _amber_frames
		_led_window.stop()
		_led_window.frame = 2
		_lbl_window.text = "TRÁNSITO\n(CAPTURA 35%)"
		_lbl_window.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)

	var transmitting_any: bool = false
	for pid in _sensor_rows.keys():
		var row: Dictionary = _sensor_rows[pid]
		var btn: TextureButton = row["btn"]
		var lbl_status: Label = row["lbl_status"]
		var bar: ProgressBar = row["bar"]

		var installed: bool = sim.design.get_part_count(pid) > 0
		if not installed:
			btn.disabled = true
			lbl_status.text = "NO INST."
			lbl_status.add_theme_color_override("font_color", Color("556070"))
			bar.value = 0.0
			continue

		var quality: float = float(t.instruments_captured.get(pid, 0.0))
		var sent: bool = bool(t.instruments_transmitted.get(pid, false))
		var prog: float = sim.get_transmission_progress(pid)

		var bus_ready: bool = t.master_bus_on and t.science_bus_on
		var can_upgrade: bool = t.in_flyby_window and quality < 0.99
		btn.disabled = (not bus_ready) or (quality > 0.0 and not can_upgrade)

		if sent:
			lbl_status.text = "OK %d%%" % int(round(quality * 100.0))
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
			bar.value = 1.0
		elif quality > 0.0:
			transmitting_any = true
			lbl_status.text = "TX..." if t.comms_on else "EN COLA"
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
			bar.value = prog
		else:
			lbl_status.text = "LISTO" if bus_ready else "SIN BUS"
			lbl_status.add_theme_color_override("font_color", ThemeFactory.COL_AMBER if bus_ready else ThemeFactory.COL_RED)
			bar.value = 0.0

	if (transmitting_any and t.comms_on and t.master_bus_on) or t.in_flyby_window:
		if not _radar_sprite.is_playing():
			_radar_sprite.play("default")
	else:
		_radar_sprite.stop()

	_lbl_score.text = "CIENCIA: %d / %d PTS" % [t.science_score, t.science_max]
