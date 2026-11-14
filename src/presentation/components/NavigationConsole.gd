@tool
class_name NavigationConsole
extends NinePatchRect
## Central Cockpit Console: CRT trajectory & delta-v monitor, throttle lever,
## safety-guarded ignition switch, and live flight event log.

signal throttle_changed(value: float)
signal safety_cover_toggled()
signal ignition_pressed()

var _crt_display: _CRTDisplay
var _lbl_fuel: Label
var _lbl_log: Label
var _throttle_control: _ThrottleLever
var _lbl_throttle: Label

var _btn_cover: TextureButton
var _btn_ign: TextureButton
var _led_fire: AnimatedSprite2D
var _lbl_ign: Label

var _amber_frames: SpriteFrames
var _green_frames: SpriteFrames


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_amber_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_amber_sheet.png", 8, 8, 8.0, true)
	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 4.0, true)
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "CONSOLA CENTRAL // NAVEGACIÓN"
	title.position = Vector2(8, 6)
	title.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	add_child(title)

	# CRT Frame
	var crt_frame := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 6)
	crt_frame.position = Vector2(8, 20)
	crt_frame.size = Vector2(244, 98)
	add_child(crt_frame)

	_crt_display = _CRTDisplay.new()
	_crt_display.position = Vector2(4, 4)
	_crt_display.size = Vector2(236, 46)
	crt_frame.add_child(_crt_display)

	_lbl_fuel = Label.new()
	_lbl_fuel.position = Vector2(6, 52)
	_lbl_fuel.size = Vector2(232, 14)
	_lbl_fuel.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	crt_frame.add_child(_lbl_fuel)

	_lbl_log = Label.new()
	_lbl_log.position = Vector2(6, 67)
	_lbl_log.size = Vector2(232, 26)
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_log.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	crt_frame.add_child(_lbl_log)

	# Throttle section (left bottom)
	var lbl_thr_title := Label.new()
	lbl_thr_title.text = "EMPUJE"
	lbl_thr_title.position = Vector2(10, 122)
	add_child(lbl_thr_title)

	_lbl_throttle = Label.new()
	_lbl_throttle.text = "0%"
	_lbl_throttle.position = Vector2(56, 122)
	_lbl_throttle.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	add_child(_lbl_throttle)

	_throttle_control = _ThrottleLever.new()
	_throttle_control.position = Vector2(10, 136)
	_throttle_control.size = Vector2(128, 24)
	_throttle_control.changed.connect(func(v: float):
		throttle_changed.emit(v)
	)
	add_child(_throttle_control)

	var presets := [[0.0, "0%"], [0.5, "50%"], [1.0, "100%"]]
	for i in range(presets.size()):
		var val: float = presets[i][0]
		var btn := Button.new()
		btn.text = presets[i][1]
		btn.position = Vector2(10 + i * 44, 166)
		btn.size = Vector2(40, 20)
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			throttle_changed.emit(val)
		)
		add_child(btn)

	# Ignition + Safety Cover section (right bottom)
	var lbl_arm := Label.new()
	lbl_arm.text = "IGNICIÓN"
	lbl_arm.position = Vector2(166, 122)
	add_child(lbl_arm)

	_led_fire = AnimatedSprite2D.new()
	_led_fire.position = Vector2(226, 127)
	_led_fire.sprite_frames = _amber_frames
	add_child(_led_fire)

	_btn_ign = TextureButton.new()
	_btn_ign.position = Vector2(178, 144)
	_btn_ign.size = Vector2(30, 28)
	_btn_ign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_ign.texture_normal = load("res://assets/sprites/cockpit/ign_normal.png")
	_btn_ign.texture_hover = load("res://assets/sprites/cockpit/ign_hover.png")
	_btn_ign.texture_pressed = load("res://assets/sprites/cockpit/ign_pressed.png")
	_btn_ign.texture_disabled = load("res://assets/sprites/cockpit/ign_disabled.png")
	_btn_ign.pressed.connect(func():
		AudioManager.play_sfx("ignition", -6.0)
		ignition_pressed.emit()
	)
	add_child(_btn_ign)

	_btn_cover = TextureButton.new()
	_btn_cover.position = Vector2(176, 144)
	_btn_cover.size = Vector2(34, 28)
	_btn_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_cover.pressed.connect(func():
		AudioManager.play_sfx("switch")
		safety_cover_toggled.emit()
	)
	add_child(_btn_cover)

	_lbl_ign = Label.new()
	_lbl_ign.text = "TAPA CERRADA"
	_lbl_ign.position = Vector2(144, 176)
	_lbl_ign.size = Vector2(106, 16)
	_lbl_ign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_ign)


func update_telemetry(t: FlightTelemetry, mission: MissionSpec) -> void:
	if t == null or mission == null:
		return

	_crt_display.update_data(t, mission)
	_lbl_fuel.text = "COMB: %.0fkg | Δv REST: %.0f m/s" % [t.propellant_remaining_kg, t.delta_v_remaining]

	var log_count: int = t.event_log.size()
	if log_count >= 2:
		_lbl_log.text = t.event_log[log_count - 2] + "\n" + t.event_log[log_count - 1]
	elif log_count == 1:
		_lbl_log.text = t.event_log[0]

	_throttle_control.set_value(t.throttle)
	_lbl_throttle.text = "%d%%" % int(round(t.throttle * 100.0))

	if t.safety_cover_open:
		_btn_cover.position = Vector2(176, 134)
		_btn_cover.size = Vector2(34, 10)
		_btn_cover.texture_normal = load("res://assets/sprites/cockpit/cover_open_normal.png")
		_btn_cover.texture_hover = load("res://assets/sprites/cockpit/cover_open_hover.png")
		_btn_ign.disabled = (not t.master_bus_on or t.propellant_remaining_kg <= 0.0)
	else:
		_btn_cover.position = Vector2(176, 144)
		_btn_cover.size = Vector2(34, 28)
		_btn_cover.texture_normal = load("res://assets/sprites/cockpit/cover_closed_normal.png")
		_btn_cover.texture_hover = load("res://assets/sprites/cockpit/cover_closed_hover.png")
		_btn_ign.disabled = true

	if t.engine_firing:
		_led_fire.sprite_frames = _amber_frames
		if not _led_fire.is_playing():
			_led_fire.play("default")
		_lbl_ign.text = "MOTOR ACTIVO"
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	elif t.safety_cover_open:
		_led_fire.sprite_frames = _green_frames
		_led_fire.stop()
		_led_fire.frame = 0
		_lbl_ign.text = "ARMADO // IGNITAR"
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_led_fire.stop()
		_led_fire.frame = 2
		_lbl_ign.text = "TAPA CERRADA"
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)


class _CRTDisplay extends Control:
	var _t: FlightTelemetry
	var _m: MissionSpec

	func update_data(t: FlightTelemetry, m: MissionSpec) -> void:
		_t = t
		_m = m
		queue_redraw()

	func _draw() -> void:
		if _t == null or _m == null:
			return
		var w: float = size.x
		# Delta-v Target Bar
		var max_dv_scale: float = maxf(_m.required_delta_v + _m.delta_v_tolerance * 2.5, 1.0)
		var bar_rect := Rect2(4, 16, w - 8, 12)
		draw_rect(bar_rect, Color("081810"))
		draw_rect(bar_rect, Color("205838"), false, 1.0)

		# Green target zone
		var z_start: float = clampf((_m.required_delta_v - _m.delta_v_tolerance) / max_dv_scale, 0.0, 1.0)
		var z_end: float = clampf((_m.required_delta_v + _m.delta_v_tolerance * 1.5) / max_dv_scale, 0.0, 1.0)
		draw_rect(Rect2(4 + z_start * (w - 8), 17, (z_end - z_start) * (w - 8), 10), Color(0.15, 0.55, 0.30, 0.55))

		# Current delta_v_burned fill
		var fill_norm: float = clampf(_t.delta_v_burned / max_dv_scale, 0.0, 1.0)
		var fill_col: Color = ThemeFactory.COL_GREEN
		if _t.delta_v_burned > _m.required_delta_v + _m.delta_v_tolerance * 1.5:
			fill_col = ThemeFactory.COL_RED
		elif _t.delta_v_burned < _m.required_delta_v - _m.delta_v_tolerance:
			fill_col = ThemeFactory.COL_AMBER
		draw_rect(Rect2(4, 19, fill_norm * (w - 8), 6), fill_col)

		# Target center tick
		var req_x: float = 4.0 + clampf(_m.required_delta_v / max_dv_scale, 0.0, 1.0) * (w - 8)
		draw_line(Vector2(req_x, 14), Vector2(req_x, 30), ThemeFactory.COL_WHITE, 1.0)

		var font: Font = ThemeFactory.get_theme().default_font
		if font != null:
			var txt := "Δv QUEMADO: %.0f / %.0f m/s" % [_t.delta_v_burned, _m.required_delta_v]
			draw_string(font, Vector2(4, 11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ThemeFactory.COL_GREEN)
			var status_txt := "CORREDOR ORBITAL: EN RANGO" if fill_col == ThemeFactory.COL_GREEN else ("SOBREIMPULSO" if fill_col == ThemeFactory.COL_RED else "FALTA IMPULSO Δv")
			draw_string(font, Vector2(4, 42), status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, fill_col)


class _ThrottleLever extends Control:
	signal changed(val: float)
	var _val: float = 0.0
	var _dragging: bool = false

	func set_value(v: float) -> void:
		_val = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_update_from_x(event.position.x)
		elif event is InputEventMouseMotion and _dragging:
			_update_from_x(event.position.x)

	func _update_from_x(mx: float) -> void:
		var v: float = clampf((mx - 6.0) / maxf(size.x - 12.0, 1.0), 0.0, 1.0)
		_val = v
		changed.emit(v)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 6, size.x, 12), Color("10141e"))
		draw_rect(Rect2(0, 6, size.x, 12), Color("46546c"), false, 1.0)
		var fill_w: float = _val * (size.x - 4.0)
		draw_rect(Rect2(2, 8, fill_w, 8), ThemeFactory.COL_AMBER)
		var knob_x: float = clampf(4.0 + _val * (size.x - 14.0), 2.0, size.x - 12.0)
		draw_rect(Rect2(knob_x, 2, 10, 20), Color("a8b4c6"))
		draw_rect(Rect2(knob_x, 2, 10, 20), Color("080a10"), false, 1.0)
		draw_rect(Rect2(knob_x + 3, 5, 4, 14), ThemeFactory.COL_RED)
