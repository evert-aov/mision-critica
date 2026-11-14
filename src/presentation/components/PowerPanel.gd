@tool
class_name PowerPanel
extends NinePatchRect
## Left Cockpit Panel: physical bus toggle switches, analog battery meter,
## status LEDs (AnimatedSprite2D), and solar panel deployment control.

signal master_toggled(enabled: bool)
signal comms_toggled(enabled: bool)
signal science_toggled(enabled: bool)
signal panels_deploy_requested()

var _btn_master: TextureButton
var _btn_comms: TextureButton
var _btn_science: TextureButton
var _btn_deploy: TextureButton

var _led_master: AnimatedSprite2D
var _led_comms: AnimatedSprite2D
var _led_science: AnimatedSprite2D
var _led_battery: AnimatedSprite2D

var _dial_control: _BatteryDial
var _lbl_power: Label
var _lbl_bat_wh: Label
var _lbl_deploy: Label

var _green_frames: SpriteFrames
var _red_frames: SpriteFrames


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 4.0, true)
	_red_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_red_sheet.png", 8, 8, 6.0, true)
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "ENERGÍA Y SISTEMAS"
	title.position = Vector2(8, 6)
	title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	add_child(title)

	# 3 Toggle switches (Master, Comms, Science)
	var sw_defs := [
		["BUS\nMAES", 10],
		["COMMS", 66],
		["CIENC", 122],
	]
	for idx in range(sw_defs.size()):
		var lbl_txt: String = sw_defs[idx][0]
		var sx: int = sw_defs[idx][1]

		var btn := TextureButton.new()
		btn.position = Vector2(sx + 8, 26)
		btn.size = Vector2(22, 26)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(btn)

		var led := AnimatedSprite2D.new()
		led.position = Vector2(sx + 36, 39)
		led.sprite_frames = _green_frames
		led.frame = 0
		add_child(led)

		var lbl := Label.new()
		lbl.text = lbl_txt
		lbl.position = Vector2(sx, 54)
		lbl.size = Vector2(46, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)

		if idx == 0:
			_btn_master = btn
			_led_master = led
			btn.pressed.connect(func():
				AudioManager.play_sfx("switch")
				master_toggled.emit(not _is_master_on)
			)
		elif idx == 1:
			_btn_comms = btn
			_led_comms = led
			btn.pressed.connect(func():
				AudioManager.play_sfx("switch")
				comms_toggled.emit(not _is_comms_on)
			)
		else:
			_btn_science = btn
			_led_science = led
			btn.pressed.connect(func():
				AudioManager.play_sfx("switch")
				science_toggled.emit(not _is_science_on)
			)

	# Analog Battery Dial
	_dial_control = _BatteryDial.new()
	_dial_control.position = Vector2(10, 78)
	_dial_control.size = Vector2(76, 56)
	add_child(_dial_control)

	_led_battery = AnimatedSprite2D.new()
	_led_battery.position = Vector2(96, 86)
	_led_battery.sprite_frames = _red_frames
	add_child(_led_battery)

	_lbl_bat_wh = Label.new()
	_lbl_bat_wh.position = Vector2(106, 82)
	_lbl_bat_wh.size = Vector2(70, 24)
	add_child(_lbl_bat_wh)

	_lbl_power = Label.new()
	_lbl_power.position = Vector2(92, 108)
	_lbl_power.size = Vector2(84, 34)
	_lbl_power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_lbl_power)

	# Solar deploy button
	_btn_deploy = TextureButton.new()
	_btn_deploy.position = Vector2(14, 152)
	_btn_deploy.size = Vector2(56, 18)
	_btn_deploy.texture_normal = load("res://assets/sprites/cockpit/deploy_normal.png")
	_btn_deploy.texture_hover = load("res://assets/sprites/cockpit/deploy_hover.png")
	_btn_deploy.texture_pressed = load("res://assets/sprites/cockpit/deploy_pressed.png")
	_btn_deploy.texture_disabled = load("res://assets/sprites/cockpit/deploy_done.png")
	_btn_deploy.pressed.connect(func():
		AudioManager.play_sfx("telemetry")
		panels_deploy_requested.emit()
	)
	add_child(_btn_deploy)

	_lbl_deploy = Label.new()
	_lbl_deploy.text = "DESPLEGAR\nPANELES"
	_lbl_deploy.position = Vector2(76, 150)
	_lbl_deploy.size = Vector2(98, 24)
	add_child(_lbl_deploy)


var _is_master_on: bool = true
var _is_comms_on: bool = true
var _is_science_on: bool = true


func update_telemetry(t: FlightTelemetry) -> void:
	if t == null:
		return
	_is_master_on = t.master_bus_on
	_is_comms_on = t.comms_on
	_is_science_on = t.science_bus_on

	_apply_toggle_textures(_btn_master, _led_master, t.master_bus_on)
	_apply_toggle_textures(_btn_comms, _led_comms, t.master_bus_on and t.comms_on)
	_apply_toggle_textures(_btn_science, _led_science, t.master_bus_on and t.science_bus_on)

	var ratio: float = (t.battery_wh / t.battery_max_wh) if t.battery_max_wh > 0.0 else 0.0
	_dial_control.set_ratio(ratio)
	_lbl_bat_wh.text = "BAT: %d%%\n%.0f/%.0fWh" % [int(round(ratio * 100.0)), t.battery_wh, t.battery_max_wh]
	_lbl_bat_wh.add_theme_color_override("font_color", ThemeFactory.COL_RED if ratio < 0.25 else ThemeFactory.COL_TEXT)

	if ratio < 0.25:
		_led_battery.sprite_frames = _red_frames
		if not _led_battery.is_playing():
			_led_battery.play("default")
	else:
		_led_battery.sprite_frames = _green_frames
		_led_battery.stop()
		_led_battery.frame = 0

	_lbl_power.text = "SOL:+%.0fW\nCON:-%.0fW\nNET:%+.0fW" % [t.solar_gen_w, t.power_draw_w, t.power_net_w]
	_lbl_power.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if t.power_net_w >= 0.0 else ThemeFactory.COL_AMBER)

	_btn_deploy.disabled = t.panels_deployed
	if t.panels_deployed:
		_lbl_deploy.text = "PANELES\nACTIVOS"
		_lbl_deploy.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_lbl_deploy.text = "DESPLEGAR\nPANELES"
		_lbl_deploy.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)


func _apply_toggle_textures(btn: TextureButton, led: AnimatedSprite2D, is_on: bool) -> void:
	var state := "on" if is_on else "off"
	btn.texture_normal = load("res://assets/sprites/cockpit/toggle_%s_normal.png" % state)
	btn.texture_hover = load("res://assets/sprites/cockpit/toggle_%s_hover.png" % state)
	btn.texture_pressed = load("res://assets/sprites/cockpit/toggle_%s_pressed.png" % state)
	led.sprite_frames = _green_frames if is_on else _red_frames
	led.frame = 0 if is_on else 1


class _BatteryDial extends Control:
	var _ratio: float = 1.0

	func set_ratio(r: float) -> void:
		_ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0a1018"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("38465c"), false, 1.0)
		var center := Vector2(floorf(size.x * 0.5), size.y - 10.0)
		var radius: float = 28.0
		# Semicircle arc segments (PI to 2*PI)
		for i in range(18):
			var a0: float = PI + (float(i) / 18.0) * PI
			var a1: float = PI + (float(i + 1) / 18.0) * PI
			var col: Color = ThemeFactory.COL_RED if i < 4 else (ThemeFactory.COL_AMBER if i < 8 else ThemeFactory.COL_GREEN)
			draw_line(center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius, col, 2.0)

		var needle_ang: float = PI + _ratio * PI
		var tip := center + Vector2(cos(needle_ang), sin(needle_ang)) * (radius - 4.0)
		draw_line(center, tip, ThemeFactory.COL_WHITE, 2.0)
		draw_rect(Rect2(center.x - 2, center.y - 2, 4, 4), ThemeFactory.COL_AMBER)
