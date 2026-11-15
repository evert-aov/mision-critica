@tool
class_name PowerPanel
extends NinePatchRect
## Left Cockpit Panel (166x208): physical bus toggle switches, analog battery meter,
## solar pointing efficiency readout, solar deployment button, and STABLE/CAUTION/CRITICAL badge.

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
var _lbl_title: Label
var _lbl_power: Label
var _lbl_bat_wh: Label
var _lbl_deploy: Label
var _lbl_sys_health: Label
var _last_telemetry: FlightTelemetry

var _green_frames: SpriteFrames
var _red_frames: SpriteFrames
var _amber_frames: SpriteFrames

var _is_master_on: bool = true
var _is_comms_on: bool = true
var _is_science_on: bool = true


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 4.0, true)
	_red_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_red_sheet.png", 8, 8, 7.0, true)
	_amber_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_amber_sheet.png", 8, 8, 5.0, true)
	_build_ui()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String):
			_refresh_static_texts()
			if _last_telemetry != null:
				update_telemetry(_last_telemetry)
		)


func _build_ui() -> void:
	_lbl_title = Label.new()
	_lbl_title.text = Loc.pick("ENERGÍA Y ESTADO", "POWER & STATUS")
	_lbl_title.position = Vector2(7, 5)
	_lbl_title.size = Vector2(152, 10)
	_lbl_title.clip_text = true
	_lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	add_child(_lbl_title)

	# 1. Recessed Switch Bank (x=6, y=17, w=154, h=54)
	var sw_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	sw_box.position = Vector2(6, 17)
	sw_box.size = Vector2(154, 54)
	add_child(sw_box)

	var sw_defs := [
		["F2 BUS", 3],
		["F3 TX", 53],
		["F4 SCI", 103],
	]
	for idx in range(sw_defs.size()):
		var lbl_txt: String = sw_defs[idx][0]
		var col_x: int = sw_defs[idx][1]

		var led := AnimatedSprite2D.new()
		led.position = Vector2(col_x + 24, 8)
		led.sprite_frames = _green_frames
		led.frame = 0
		sw_box.add_child(led)

		var btn := TextureButton.new()
		btn.position = Vector2(col_x + 13, 14)
		btn.size = Vector2(22, 26)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sw_box.add_child(btn)

		var lbl := Label.new()
		lbl.text = lbl_txt
		lbl.position = Vector2(col_x, 42)
		lbl.size = Vector2(48, 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		sw_box.add_child(lbl)

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

	# 2. Battery & Solar Alignment CRT Monitor (x=6, y=74, w=154, h=82)
	var pwr_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	pwr_box.position = Vector2(6, 74)
	pwr_box.size = Vector2(154, 82)
	pwr_box.clip_contents = true
	add_child(pwr_box)

	_dial_control = _BatteryDial.new()
	_dial_control.position = Vector2(5, 6)
	_dial_control.size = Vector2(64, 70)
	pwr_box.add_child(_dial_control)

	_led_battery = AnimatedSprite2D.new()
	_led_battery.position = Vector2(77, 11)
	_led_battery.sprite_frames = _green_frames
	pwr_box.add_child(_led_battery)

	_lbl_bat_wh = Label.new()
	_lbl_bat_wh.position = Vector2(84, 5)
	_lbl_bat_wh.size = Vector2(66, 20)
	_lbl_bat_wh.clip_text = true
	pwr_box.add_child(_lbl_bat_wh)

	_lbl_power = Label.new()
	_lbl_power.position = Vector2(73, 28)
	_lbl_power.size = Vector2(77, 49)
	_lbl_power.clip_text = true
	pwr_box.add_child(_lbl_power)

	# 3. Solar Array Deployment + System State Footer (x=6, y=159, w=154, h=43)
	var sol_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	sol_box.position = Vector2(6, 159)
	sol_box.size = Vector2(154, 43)
	sol_box.clip_contents = true
	add_child(sol_box)

	_btn_deploy = TextureButton.new()
	_btn_deploy.position = Vector2(5, 5)
	_btn_deploy.size = Vector2(56, 18)
	_btn_deploy.texture_normal = load("res://assets/sprites/cockpit/deploy_normal.png")
	_btn_deploy.texture_hover = load("res://assets/sprites/cockpit/deploy_hover.png")
	_btn_deploy.texture_pressed = load("res://assets/sprites/cockpit/deploy_pressed.png")
	_btn_deploy.texture_disabled = load("res://assets/sprites/cockpit/deploy_done.png")
	_btn_deploy.pressed.connect(func():
		AudioManager.play_sfx("telemetry")
		panels_deploy_requested.emit()
	)
	sol_box.add_child(_btn_deploy)

	_lbl_deploy = Label.new()
	_lbl_deploy.text = "SOLAR [P]"
	_lbl_deploy.position = Vector2(65, 9)
	_lbl_deploy.size = Vector2(85, 11)
	_lbl_deploy.clip_text = true
	sol_box.add_child(_lbl_deploy)

	var h_sep := ColorRect.new()
	h_sep.color = Color("1e4632")
	h_sep.position = Vector2(5, 25)
	h_sep.size = Vector2(144, 1)
	sol_box.add_child(h_sep)

	_lbl_sys_health = Label.new()
	_lbl_sys_health.text = "SIS: ESTABLE"
	_lbl_sys_health.position = Vector2(5, 29)
	_lbl_sys_health.size = Vector2(144, 11)
	_lbl_sys_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_sys_health.clip_text = true
	_lbl_sys_health.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	sol_box.add_child(_lbl_sys_health)


func _refresh_static_texts() -> void:
	_lbl_title.text = Loc.pick("ENERGÍA Y ESTADO", "POWER & STATUS")


func update_telemetry(t: FlightTelemetry) -> void:
	if t == null:
		return
	_last_telemetry = t
	_lbl_title.text = Loc.pick("ENERGÍA Y ESTADO", "POWER & STATUS")
	_is_master_on = t.master_bus_on
	_is_comms_on = t.comms_on
	_is_science_on = t.science_bus_on

	_apply_toggle_textures(_btn_master, _led_master, t.master_bus_on)
	_apply_toggle_textures(_btn_comms, _led_comms, t.master_bus_on and t.comms_on)
	_apply_toggle_textures(_btn_science, _led_science, t.master_bus_on and t.science_bus_on)

	var ratio: float = (t.battery_wh / t.battery_max_wh) if t.battery_max_wh > 0.0 else 0.0
	_dial_control.set_ratio(ratio)
	_lbl_bat_wh.text = "BAT %d%%\n%.0f/%.0fWh" % [int(round(ratio * 100.0)), t.battery_wh, t.battery_max_wh]
	_lbl_bat_wh.add_theme_color_override("font_color", ThemeFactory.COL_RED if ratio < 0.25 else ThemeFactory.COL_TEXT)

	if ratio < 0.25 or t.system_state == FlightTelemetry.SystemState.CRITICAL:
		_led_battery.sprite_frames = _red_frames
		if not _led_battery.is_playing():
			_led_battery.play("default")
	elif t.system_state == FlightTelemetry.SystemState.CAUTION:
		_led_battery.sprite_frames = _amber_frames
		_led_battery.stop()
		_led_battery.frame = 0
	else:
		_led_battery.sprite_frames = _green_frames
		_led_battery.stop()
		_led_battery.frame = 0

	var sol_eff: int = int(round(t.solar_pointing_factor * 100.0)) if (t.panels_deployed and not t.in_shadow) else 0
	_lbl_power.text = Loc.pick(
		"SOL:+%.0fW\nAPUN:%d%%\nCON:-%.0fW\nNET:%+.0fW",
		"SUN:+%.0fW\nAIM:%d%%\nUSE:-%.0fW\nNET:%+.0fW"
	) % [
		t.solar_gen_w,
		sol_eff,
		t.power_draw_w,
		t.power_net_w,
	]
	_lbl_power.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if t.power_net_w >= 0.0 else ThemeFactory.COL_AMBER)

	_btn_deploy.disabled = t.panels_deployed
	if t.panels_deployed:
		_lbl_deploy.text = Loc.pick("SOL: ACTIVO", "SUN: ACTIVE")
		_lbl_deploy.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_lbl_deploy.text = "SOLAR [P]"
		_lbl_deploy.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)

	match t.system_state:
		FlightTelemetry.SystemState.STABLE:
			_lbl_sys_health.text = Loc.pick("ESTABLE: NOMINAL", "STABLE: NOMINAL")
			_lbl_sys_health.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		FlightTelemetry.SystemState.CAUTION:
			_lbl_sys_health.text = Loc.pick("SIS: PRECAUCIÓN", "SYS: CAUTION")
			_lbl_sys_health.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
		FlightTelemetry.SystemState.CRITICAL:
			_lbl_sys_health.text = Loc.pick("SIS: CRÍTICO", "SYS: CRITICAL")
			_lbl_sys_health.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	_lbl_sys_health.tooltip_text = t.system_state_reason


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
		draw_rect(Rect2(Vector2.ZERO, size), Color("070d14"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("2b3c52"), false, 1.0)
		var center := Vector2(floorf(size.x * 0.5), size.y - 16.0)
		var radius: float = 23.0
		for i in range(18):
			var a0: float = PI + (float(i) / 18.0) * PI
			var a1: float = PI + (float(i + 1) / 18.0) * PI
			var col: Color = ThemeFactory.COL_RED if i < 4 else (ThemeFactory.COL_AMBER if i < 8 else ThemeFactory.COL_GREEN)
			draw_line(center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius, col, 2.0)

		var needle_ang: float = PI + _ratio * PI
		var tip := center + Vector2(cos(needle_ang), sin(needle_ang)) * (radius - 4.0)
		draw_line(center, tip, ThemeFactory.COL_WHITE, 2.0)
		draw_rect(Rect2(center.x - 2, center.y - 2, 4, 4), ThemeFactory.COL_AMBER)

		var font: Font = ThemeFactory.get_compact_font()
		var font_size: int = ThemeFactory.get_compact_font_size()
		if font != null:
			draw_string(font, Vector2(5, size.y - 4), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_RED)
			draw_string(font, Vector2(size.x - 10, size.y - 4), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_GREEN)
