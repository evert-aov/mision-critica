@tool
class_name NavigationConsole
extends NinePatchRect
## Central Cockpit Console (292x208):
## - 2D Gyroscopic Attitude Compass (Reaction Wheels + RCS + pointing vectors)
## - Orbital Trajectory & 180° Insertion Braking CRT Monitor
## - Scrollable Flight Event Terminal
## - Attitude Pointing Modes (PRO 0°, RET 180°, SOLAR, TIERRA, OBJET.) + Manual Turn + SAS + RCS
## - Throttle Lever + Safety-Guarded Ignition Switch.

signal throttle_changed(value: float)
signal safety_cover_toggled()
signal ignition_pressed()
signal attitude_mode_requested(mode: int)
signal manual_rotation_changed(turn_dir: float)
signal attitude_nudged(dir: float)
signal stabilize_requested()
signal rcs_toggled()

var _lbl_title: Label
var _lbl_acs_state: Label
var _attitude_compass: _AttitudeCompass
var _crt_display: _CRTDisplay
var _log_scroll: ScrollContainer
var _lbl_log: Label
var _last_log_count: int = 0

var _mode_buttons: Dictionary = {} # AttitudeMode -> Button
var _btn_ccw: Button
var _btn_stab: Button
var _btn_cw: Button
var _btn_rcs: Button

var _throttle_control: _ThrottleLever
var _lbl_throttle: Label
var _lbl_fuel: Label

var _btn_cover: TextureButton
var _btn_ign: TextureButton
var _led_fire: AnimatedSprite2D
var _lbl_arm: Label
var _lbl_ign: Label
var _last_t: FlightTelemetry
var _last_m: MissionSpec

var _amber_frames: SpriteFrames
var _green_frames: SpriteFrames
var _red_frames: SpriteFrames


func _ready() -> void:
	texture = load("res://assets/sprites/ui/panel_metal.png")
	patch_margin_left = 6
	patch_margin_top = 6
	patch_margin_right = 6
	patch_margin_bottom = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

	_amber_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_amber_sheet.png", 8, 8, 8.0, true)
	_green_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_green_sheet.png", 8, 8, 4.0, true)
	_red_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/led_red_sheet.png", 8, 8, 8.0, true)
	_build_ui()
	_refresh_static_texts()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String):
			_refresh_static_texts()
			if _last_t != null and _last_m != null:
				update_telemetry(_last_t, _last_m)
			_attitude_compass.queue_redraw()
			_crt_display.queue_redraw()
		)


func _build_ui() -> void:
	_lbl_title = Label.new()
	_lbl_title.text = "ACTITUD Y TRAYECTORIA"
	_lbl_title.position = Vector2(8, 5)
	_lbl_title.size = Vector2(168, 10)
	_lbl_title.clip_text = true
	_lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	add_child(_lbl_title)

	_lbl_acs_state = Label.new()
	_lbl_acs_state.text = "ACT: ESTABLE"
	_lbl_acs_state.position = Vector2(178, 5)
	_lbl_acs_state.size = Vector2(106, 10)
	_lbl_acs_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_acs_state.clip_text = true
	_lbl_acs_state.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	add_child(_lbl_acs_state)

	# 1. Upper CRT Split Monitor (x=6, y=17, w=280, h=96)
	var crt_frame := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 5)
	crt_frame.position = Vector2(6, 17)
	crt_frame.size = Vector2(280, 96)
	crt_frame.clip_contents = true
	add_child(crt_frame)

	_attitude_compass = _AttitudeCompass.new()
	_attitude_compass.position = Vector2(4, 4)
	_attitude_compass.size = Vector2(78, 88)
	crt_frame.add_child(_attitude_compass)

	var v_div := ColorRect.new()
	v_div.color = Color("1e4632")
	v_div.position = Vector2(85, 4)
	v_div.size = Vector2(1, 88)
	crt_frame.add_child(v_div)

	_crt_display = _CRTDisplay.new()
	_crt_display.position = Vector2(89, 4)
	_crt_display.size = Vector2(186, 46)
	crt_frame.add_child(_crt_display)

	var h_div := ColorRect.new()
	h_div.color = Color("1e4632")
	h_div.position = Vector2(89, 52)
	h_div.size = Vector2(186, 1)
	crt_frame.add_child(h_div)

	# Scrollable Flight Event Terminal inside the CRT
	_log_scroll = ScrollContainer.new()
	_log_scroll.position = Vector2(89, 54)
	_log_scroll.size = Vector2(186, 38)
	_log_scroll.clip_contents = true
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crt_frame.add_child(_log_scroll)

	_lbl_log = Label.new()
	_lbl_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_log.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	_log_scroll.add_child(_lbl_log)

	# 2. Middle Attitude / Orientation Control Deck (x=6, y=115, w=280, h=42)
	var acs_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	acs_box.position = Vector2(6, 115)
	acs_box.size = Vector2(280, 42)
	acs_box.clip_contents = true
	add_child(acs_box)

	var modes_hbox := HBoxContainer.new()
	modes_hbox.position = Vector2(4, 3)
	modes_hbox.size = Vector2(272, 17)
	modes_hbox.add_theme_constant_override("separation", 3)
	acs_box.add_child(modes_hbox)

	var mode_defs := [
		[FlightTelemetry.AttitudeMode.PROGRADE, "1 PRO", "[1] Progrado 0°: corrección TCM"],
		[FlightTelemetry.AttitudeMode.RETROGRADE, "2 RET", "[2] Retrógrado 180°: frenado de inserción"],
		[FlightTelemetry.AttitudeMode.SOLAR, "3 SOL", "[3] Solar -90°: carga máxima"],
		[FlightTelemetry.AttitudeMode.EARTH, "4 TX", "[4] Tierra +90°: descarga"],
		[FlightTelemetry.AttitudeMode.TARGET, "5 OBJ", "[5] Objetivo -35°: sensores"],
	]
	for md in mode_defs:
		var m_enum: int = md[0]
		var btn := Button.new()
		btn.text = md[1]
		btn.tooltip_text = md[2]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			AudioManager.play_sfx("servo", -6.0)
			attitude_mode_requested.emit(m_enum)
		)
		modes_hbox.add_child(btn)
		_mode_buttons[m_enum] = btn

	var manual_hbox := HBoxContainer.new()
	manual_hbox.position = Vector2(4, 22)
	manual_hbox.size = Vector2(272, 17)
	manual_hbox.add_theme_constant_override("separation", 3)
	acs_box.add_child(manual_hbox)

	_btn_ccw = Button.new()
	_btn_ccw.text = "A IZQ"
	_btn_ccw.custom_minimum_size = Vector2(58, 17)
	_btn_ccw.button_down.connect(func():
		AudioManager.play_sfx("click")
		attitude_nudged.emit(-0.5)
		manual_rotation_changed.emit(-1.0)
	)
	_btn_ccw.button_up.connect(func():
		manual_rotation_changed.emit(0.0)
	)
	manual_hbox.add_child(_btn_ccw)

	_btn_stab = Button.new()
	_btn_stab.text = "S ESTAB"
	_btn_stab.custom_minimum_size = Vector2(58, 17)
	_btn_stab.pressed.connect(func():
		AudioManager.play_sfx("telemetry")
		stabilize_requested.emit()
	)
	manual_hbox.add_child(_btn_stab)

	_btn_cw = Button.new()
	_btn_cw.text = "D DER"
	_btn_cw.custom_minimum_size = Vector2(58, 17)
	_btn_cw.button_down.connect(func():
		AudioManager.play_sfx("click")
		attitude_nudged.emit(0.5)
		manual_rotation_changed.emit(1.0)
	)
	_btn_cw.button_up.connect(func():
		manual_rotation_changed.emit(0.0)
	)
	manual_hbox.add_child(_btn_cw)

	_btn_rcs = Button.new()
	_btn_rcs.text = "RCS: OFF"
	_btn_rcs.tooltip_text = "Activar propulsores RCS para giro rápido y desaturar ruedas RW"
	_btn_rcs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_rcs.pressed.connect(func():
		AudioManager.play_sfx("switch")
		rcs_toggled.emit()
	)
	manual_hbox.add_child(_btn_rcs)

	# 3. Bottom Left: Throttle Control Box (x=6, y=159, w=168, h=43)
	var thr_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	thr_box.position = Vector2(6, 159)
	thr_box.size = Vector2(168, 43)
	thr_box.clip_contents = true
	add_child(thr_box)

	_lbl_throttle = Label.new()
	_lbl_throttle.text = "EMPUJE: 0%"
	_lbl_throttle.position = Vector2(5, 3)
	_lbl_throttle.size = Vector2(78, 10)
	_lbl_throttle.clip_text = true
	_lbl_throttle.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	thr_box.add_child(_lbl_throttle)

	_lbl_fuel = Label.new()
	_lbl_fuel.text = "COMB: 0kg"
	_lbl_fuel.position = Vector2(84, 3)
	_lbl_fuel.size = Vector2(79, 10)
	_lbl_fuel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_fuel.clip_text = true
	_lbl_fuel.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	thr_box.add_child(_lbl_fuel)

	_throttle_control = _ThrottleLever.new()
	_throttle_control.tooltip_text = "Clic o arrastrar: fijar empuje. Rueda: +/-5%; Shift+rueda: +/-1%. Derecho: cero. W/Q o flechas arriba/abajo: +/-10%."
	_throttle_control.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_throttle_control.position = Vector2(5, 16)
	_throttle_control.size = Vector2(86, 22)
	_throttle_control.changed.connect(func(v: float):
		throttle_changed.emit(v)
	)
	thr_box.add_child(_throttle_control)

	var presets := [[0.0, "0"], [0.5, "50"], [1.0, "MX"]]
	for i in range(presets.size()):
		var val: float = presets[i][0]
		var btn := Button.new()
		btn.text = presets[i][1]
		if val >= 0.95:
			btn.tooltip_text = Loc.pick("Turbo / Empuje máximo 100% [T]", "Turbo / Max Thrust 100% [T]")
		elif val <= 0.01:
			btn.tooltip_text = Loc.pick("Cortar empuje 0% [X]", "Cut thrust 0% [X]")
		else:
			btn.tooltip_text = Loc.pick("Empuje medio 50%", "Half thrust 50%")
		btn.position = Vector2(95 + i * 24, 18)
		btn.size = Vector2(22, 18)
		btn.pressed.connect(func():
			if val >= 0.95:
				AudioManager.play_sfx("turbo", -3.5)
			elif val <= 0.01:
				AudioManager.play_sfx("switch", -5.0)
			else:
				AudioManager.play_sfx("click")
			throttle_changed.emit(val)
		)
		thr_box.add_child(btn)

	# 4. Bottom Right: Safety-Guarded Ignition Box (x=178, y=159, w=108, h=43)
	var ign_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
	ign_box.position = Vector2(178, 159)
	ign_box.size = Vector2(108, 43)
	ign_box.clip_contents = true
	add_child(ign_box)

	_btn_ign = TextureButton.new()
	_btn_ign.tooltip_text = "[Espacio] o clic: encender/apagar el motor. Abre primero la tapa con C."
	_btn_ign.position = Vector2(6, 11)
	_btn_ign.size = Vector2(30, 28)
	_btn_ign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_ign.texture_normal = load("res://assets/sprites/cockpit/ign_normal.png")
	_btn_ign.texture_hover = load("res://assets/sprites/cockpit/ign_hover.png")
	_btn_ign.texture_pressed = load("res://assets/sprites/cockpit/ign_pressed.png")
	_btn_ign.texture_disabled = load("res://assets/sprites/cockpit/ign_disabled.png")
	_btn_ign.pressed.connect(func():
		if _last_t != null and not _last_t.safety_cover_open:
			AudioManager.play_sfx("click", -5.0)
		ignition_pressed.emit()
	)
	ign_box.add_child(_btn_ign)

	_btn_cover = TextureButton.new()
	_btn_cover.tooltip_text = "[C] o clic: abrir/cerrar la tapa de seguridad."
	_btn_cover.position = Vector2(4, 11)
	_btn_cover.size = Vector2(34, 28)
	_btn_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_cover.pressed.connect(func():
		AudioManager.play_sfx("switch")
		safety_cover_toggled.emit()
	)
	ign_box.add_child(_btn_cover)

	_led_fire = AnimatedSprite2D.new()
	_led_fire.position = Vector2(46, 10)
	_led_fire.sprite_frames = _amber_frames
	ign_box.add_child(_led_fire)

	_lbl_arm = Label.new()
	_lbl_arm.text = "MOTOR"
	_lbl_arm.position = Vector2(54, 5)
	_lbl_arm.size = Vector2(48, 10)
	_lbl_arm.clip_text = true
	ign_box.add_child(_lbl_arm)

	_lbl_ign = Label.new()
	_lbl_ign.text = "TAPA"
	_lbl_ign.position = Vector2(41, 21)
	_lbl_ign.size = Vector2(63, 18)
	_lbl_ign.clip_text = true
	ign_box.add_child(_lbl_ign)


func _refresh_static_texts() -> void:
	_lbl_title.text = Loc.pick("ACTITUD Y TRAYECTORIA", "ATTITUDE & TRAJECTORY")
	if _mode_buttons.has(FlightTelemetry.AttitudeMode.PROGRADE):
		_mode_buttons[FlightTelemetry.AttitudeMode.PROGRADE].text = "1 PRO"
		_mode_buttons[FlightTelemetry.AttitudeMode.PROGRADE].tooltip_text = Loc.pick("[1] Progrado 0°: corrección TCM", "[1] Prograde 0°: TCM burn")
		_mode_buttons[FlightTelemetry.AttitudeMode.RETROGRADE].text = "2 RET"
		_mode_buttons[FlightTelemetry.AttitudeMode.RETROGRADE].tooltip_text = Loc.pick("[2] Retrógrado 180°: frenado de inserción", "[2] Retrograde 180°: insertion burn")
		_mode_buttons[FlightTelemetry.AttitudeMode.SOLAR].text = Loc.pick("3 SOL", "3 SUN")
		_mode_buttons[FlightTelemetry.AttitudeMode.SOLAR].tooltip_text = Loc.pick("[3] Solar -90°: carga máxima", "[3] Solar -90°: max charge")
		_mode_buttons[FlightTelemetry.AttitudeMode.EARTH].text = "4 TX"
		_mode_buttons[FlightTelemetry.AttitudeMode.EARTH].tooltip_text = Loc.pick("[4] Tierra +90°: descarga", "[4] Earth +90°: downlink")
		_mode_buttons[FlightTelemetry.AttitudeMode.TARGET].text = Loc.pick("5 OBJ", "5 TGT")
		_mode_buttons[FlightTelemetry.AttitudeMode.TARGET].tooltip_text = Loc.pick("[5] Objetivo -35°: sensores", "[5] Target -35°: sensors")
	_btn_ccw.text = Loc.pick("A IZQ", "A CCW")
	_btn_ccw.tooltip_text = Loc.pick("Rotar sonda en sentido antihorario (Ruedas / RCS)", "Rotate probe counter-clockwise (RW / RCS)")
	_btn_stab.text = Loc.pick("S ESTAB", "S HOLD")
	_btn_stab.tooltip_text = Loc.pick("Frenar rotación y estabilizar eje actual (SAS)", "Stop spin and hold current attitude (SAS)")
	_btn_cw.text = Loc.pick("D DER", "D CW")
	_btn_cw.tooltip_text = Loc.pick("Rotar sonda en sentido horario (Ruedas / RCS)", "Rotate probe clockwise (RW / RCS)")
	_btn_rcs.tooltip_text = Loc.pick("Activar propulsores RCS para giro rápido y desaturar ruedas RW", "Toggle RCS thrusters for fast slew & RW desaturation")
	_throttle_control.tooltip_text = Loc.pick(
		"Clic o arrastrar: fijar empuje. Rueda: +/-5%; Shift+rueda: +/-1%. Derecho: cero. W/Q o flechas arriba/abajo: +/-10%.",
		"Click or drag: set thrust. Wheel: +/-5%; Shift+wheel: +/-1%. Right-click: zero. W/Q or Up/Down arrows: +/-10%."
	)
	_btn_ign.tooltip_text = Loc.pick("[Espacio] o clic: encender/apagar el motor. Abre primero la tapa con C.", "[Space] or click: ignite/cut engine. Open cover first with C.")
	_btn_cover.tooltip_text = Loc.pick("[C] o clic: abrir/cerrar la tapa de seguridad.", "[C] or click: toggle safety cover.")
	_lbl_arm.text = Loc.pick("MOTOR", "ENGINE")


func update_telemetry(t: FlightTelemetry, mission: MissionSpec) -> void:
	if t == null or mission == null:
		return
	_last_t = t
	_last_m = mission

	_attitude_compass.update_data(t)
	_crt_display.update_data(t, mission)

	# Attitude / ACS top-right status label
	if t.is_tumbling and not t.is_controlled_slew():
		_lbl_acs_state.text = Loc.pick("ACT: ¡GIRO CRÍT!", "ATT: CRIT SPIN!")
		_lbl_acs_state.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	elif not t.attitude_aligned:
		_lbl_acs_state.text = Loc.pick("ACT: ROTANDO...", "ATT: SLEWING...")
		_lbl_acs_state.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	else:
		_lbl_acs_state.text = Loc.pick("ACT: FIJA (%s)", "ATT: LOCK (%s)") % _short_mode(t.attitude_mode)
		_lbl_acs_state.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)

	# Highlight active pointing mode button
	for m_key in _mode_buttons.keys():
		var btn: Button = _mode_buttons[m_key]
		if int(t.attitude_mode) == int(m_key):
			btn.modulate = ThemeFactory.COL_GREEN if t.attitude_aligned else ThemeFactory.COL_AMBER
		elif m_key == FlightTelemetry.AttitudeMode.RETROGRADE and t.in_insertion_window:
			btn.modulate = ThemeFactory.COL_CYAN
		else:
			btn.modulate = Color.WHITE

	# RCS button state
	_btn_rcs.text = "RCS: ON" if t.rcs_enabled else "RCS: OFF"
	_btn_rcs.modulate = ThemeFactory.COL_CYAN if t.rcs_enabled else (ThemeFactory.COL_AMBER if t.rw_saturation >= 0.70 else Color.WHITE)

	# Event Log with deferred auto-scroll
	if t.event_log.size() != _last_log_count:
		_last_log_count = t.event_log.size()
		var lines: PackedStringArray = []
		for entry in t.event_log:
			lines.append("> " + entry)
		_lbl_log.text = "\n".join(lines)
		_scroll_log_to_bottom.call_deferred()

	_throttle_control.set_value(t.throttle)
	_lbl_throttle.text = Loc.pick("EMPUJE:%3d%%", "THRUST:%3d%%") % int(round(t.throttle * 100.0))
	_lbl_fuel.text = Loc.pick("COMB:%.0fkg", "FUEL:%.0fkg") % t.propellant_remaining_kg

	if t.safety_cover_open:
		_btn_cover.position = Vector2(4, 2)
		_btn_cover.size = Vector2(34, 9)
		_btn_cover.texture_normal = load("res://assets/sprites/cockpit/cover_open_normal.png")
		_btn_cover.texture_hover = load("res://assets/sprites/cockpit/cover_open_hover.png")
		_btn_ign.disabled = (not t.master_bus_on or t.propellant_remaining_kg <= 0.0)
	else:
		_btn_cover.position = Vector2(4, 11)
		_btn_cover.size = Vector2(34, 28)
		_btn_cover.texture_normal = load("res://assets/sprites/cockpit/cover_closed_normal.png")
		_btn_cover.texture_hover = load("res://assets/sprites/cockpit/cover_closed_hover.png")
		_btn_ign.disabled = true

	if t.engine_firing:
		_led_fire.sprite_frames = _red_frames if t.wrong_burn_direction else _amber_frames
		if not _led_fire.is_playing():
			_led_fire.play("default")
		_lbl_ign.text = Loc.pick("¡ERROR!", "ERROR!") if t.wrong_burn_direction else Loc.pick("ACTIVO", "FIRING")
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_RED if t.wrong_burn_direction else ThemeFactory.COL_AMBER)
	elif t.safety_cover_open:
		_led_fire.sprite_frames = _green_frames
		_led_fire.stop()
		_led_fire.frame = 0
		_lbl_ign.text = Loc.pick("ARMADO", "ARMED")
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_led_fire.sprite_frames = _amber_frames
		_led_fire.stop()
		_led_fire.frame = 2
		_lbl_ign.text = Loc.pick("SEGURO", "SAFE")
		_lbl_ign.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)


func _short_mode(m: FlightTelemetry.AttitudeMode) -> String:
	match m:
		FlightTelemetry.AttitudeMode.PROGRADE:
			return "PRO"
		FlightTelemetry.AttitudeMode.RETROGRADE:
			return "RET"
		FlightTelemetry.AttitudeMode.SOLAR:
			return Loc.pick("SOL", "SUN")
		FlightTelemetry.AttitudeMode.EARTH:
			return Loc.pick("TIE", "EAR")
		FlightTelemetry.AttitudeMode.TARGET:
			return Loc.pick("OBJ", "TGT")
		FlightTelemetry.AttitudeMode.HOLD:
			return "SAS"
		FlightTelemetry.AttitudeMode.POINT:
			return Loc.pick("LIBRE", "FREE")
	return "MAN"


func _scroll_log_to_bottom() -> void:
	if _log_scroll != null and is_instance_valid(_log_scroll):
		var vbar: VScrollBar = _log_scroll.get_v_scroll_bar()
		if vbar != null:
			_log_scroll.scroll_vertical = int(vbar.max_value)


class _AttitudeCompass extends Control:
	var _t: FlightTelemetry

	func update_data(t: FlightTelemetry) -> void:
		_t = t
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(39.0, 29.0)
		var r: float = 21.0
		draw_circle(center, r, Color("06110c"))
		draw_arc(center, r, 0.0, TAU, 24, Color("245c3c"), 1.0)

		var font: Font = ThemeFactory.get_compact_font()
		var font_size: int = ThemeFactory.get_compact_font_size()
		# Cardinal orbital markers: P (0° right), R (180° left), S (-90° up), T/E (+90° down), O (-35° target)
		var marks := [
			[0.0, "P", ThemeFactory.COL_GREEN],
			[180.0, "R", ThemeFactory.COL_RED],
			[-90.0, "S", ThemeFactory.COL_AMBER],
			[90.0, Loc.pick("T", "E"), ThemeFactory.COL_CYAN],
			[-35.0, "O", ThemeFactory.COL_WHITE],
		]
		for mk in marks:
			var ang: float = deg_to_rad(float(mk[0]))
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(center + dir * (r - 3.0), center + dir * r, mk[2], 1.0)

		if font != null:
			draw_string(font, Vector2(center.x + r + 2, center.y + 3), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_GREEN)
			draw_string(font, Vector2(center.x - r - 7, center.y + 3), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_RED)
			draw_string(font, Vector2(center.x - 2, center.y - r - 1), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_AMBER)
			draw_string(font, Vector2(center.x - 2, center.y + r + 7), Loc.pick("T", "E"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeFactory.COL_CYAN)

		if _t == null:
			return

		# Target heading vector (cyan)
		var targ_rad: float = deg_to_rad(_t.target_attitude_deg)
		var targ_dir := Vector2(cos(targ_rad), sin(targ_rad))
		draw_line(center, center + targ_dir * (r - 4.0), Color(0.25, 0.80, 0.95, 0.45), 1.0)

		# Live spacecraft nose vector (+X) and engine tail (-X)
		var cur_rad: float = deg_to_rad(_t.attitude_deg)
		var nose_dir := Vector2(cos(cur_rad), sin(cur_rad))
		var col: Color = ThemeFactory.COL_RED if _t.is_tumbling and not _t.is_controlled_slew() else (ThemeFactory.COL_GREEN if _t.attitude_aligned else ThemeFactory.COL_AMBER)
		draw_line(center - nose_dir * 9.0, center + nose_dir * (r - 3.0), col, 2.0)
		# Engine bell dot at tail (-nose_dir)
		var tail_pt := center - nose_dir * 10.0
		draw_rect(Rect2(tail_pt.x - 2, tail_pt.y - 2, 4, 4), ThemeFactory.COL_AMBER if _t.engine_firing else Color("7888a0"))
		draw_rect(Rect2(center.x - 1, center.y - 1, 3, 3), ThemeFactory.COL_WHITE)

		if font != null:
			draw_string(font, Vector2(2, 66), "ANG: %+d°" % int(round(_t.attitude_deg)), HORIZONTAL_ALIGNMENT_LEFT, 74, font_size, col)
			draw_string(font, Vector2(2, 75), Loc.pick("GIRO:%+.0f°/s", "SPIN:%+.0f°/s") % _t.angular_vel_deg_s, HORIZONTAL_ALIGNMENT_LEFT, 74, font_size, ThemeFactory.COL_TEXT)

		# Reaction wheel momentum saturation bar at bottom (y=79..85)
		var rw_rect := Rect2(2, 79, 74, 6)
		draw_rect(rw_rect, Color("081410"))
		var rw_col: Color = ThemeFactory.COL_RED if _t.rw_saturation >= 0.90 else (ThemeFactory.COL_AMBER if _t.rw_saturation >= 0.65 else ThemeFactory.COL_CYAN)
		draw_rect(Rect2(3, 80, clampf(_t.rw_saturation, 0.0, 1.0) * 72.0, 4), rw_col)
		draw_rect(rw_rect, Color("245c3c"), false, 1.0)


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
		var font: Font = ThemeFactory.get_compact_font()
		var font_size: int = ThemeFactory.get_compact_font_size()
		var bar_rect := Rect2(2, 12, w - 4, 10)
		draw_rect(bar_rect, Color("07150e"))
		draw_rect(bar_rect, Color("205838"), false, 1.0)

		if _t.in_insertion_window and _m.requires_orbital_insertion:
			# MODE B: 180° RETROGRADE ORBITAL INSERTION BRAKING CORRIDOR
			var max_scale: float = maxf(_t.insertion_dv_target + _m.delta_v_tolerance * 2.3, 1.0)
			var z0: float = clampf((_t.insertion_dv_target - _m.delta_v_tolerance) / max_scale, 0.0, 1.0)
			var z1: float = clampf((_t.insertion_dv_target + _m.delta_v_tolerance * 1.6) / max_scale, 0.0, 1.0)
			draw_rect(Rect2(2 + z0 * (w - 4), 13, (z1 - z0) * (w - 4), 8), Color(0.15, 0.62, 0.34, 0.62))

			var fill_n: float = clampf(_t.insertion_dv_burned / max_scale, 0.0, 1.0)
			var fcol: Color = ThemeFactory.COL_GREEN
			if _t.insertion_dv_burned > _t.insertion_dv_target + _m.delta_v_tolerance * 1.6:
				fcol = ThemeFactory.COL_RED
			elif _t.insertion_dv_burned < _t.insertion_dv_target - _m.delta_v_tolerance:
				fcol = ThemeFactory.COL_AMBER
			draw_rect(Rect2(2, 15, fill_n * (w - 4), 4), fcol)

			var req_x: float = 2.0 + clampf(_t.insertion_dv_target / max_scale, 0.0, 1.0) * (w - 4)
			draw_line(Vector2(req_x, 10), Vector2(req_x, 24), ThemeFactory.COL_WHITE, 1.0)

			if font != null:
				draw_string(font, Vector2(2, 9), Loc.pick("FRENO 180°: %.0f/%.0f m/s", "BRAKE 180°: %.0f/%.0f m/s") % [_t.insertion_dv_burned, _t.insertion_dv_target], HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, ThemeFactory.COL_CYAN)
				var guide: String = Loc.pick("¡CAPTURA LISTA! APAGA MOTOR", "CAPTURE READY! CUT ENGINE")
				var gcol: Color = ThemeFactory.COL_GREEN
				var retro_err: float = absf(RocketMath.shortest_angle_diff_deg(_t.attitude_deg, 180.0))
				if _t.wrong_burn_direction and _t.engine_firing:
					guide = Loc.pick("¡GIRA A [RET 180] YA!", "TURN TO [RET 180] NOW!")
					gcol = ThemeFactory.COL_RED
				elif _t.insertion_dv_burned < _t.insertion_dv_target - _m.delta_v_tolerance:
					if retro_err > 35.0:
						guide = Loc.pick("1) PULSA [RET 180] (GIRAR)", "1) HIT [RET 180] (TURN)")
						gcol = ThemeFactory.COL_AMBER
					else:
						guide = Loc.pick("2) ENCIENDE MOTOR (FRENAR)", "2) IGNITE ENGINE (BRAKE)")
						gcol = ThemeFactory.COL_AMBER
				elif _t.insertion_dv_burned > _t.insertion_dv_target + _m.delta_v_tolerance * 1.6:
					guide = Loc.pick("¡SOBREFRENO! APAGA MOTOR", "OVERBRAKED! CUT ENGINE")
					gcol = ThemeFactory.COL_RED
				draw_string(font, Vector2(2, 33), guide, HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, gcol)
				draw_string(font, Vector2(2, 43), Loc.pick("DESV:%.0fkm | Δv DISP:%.0f", "ERR:%.0fkm | Δv REM:%.0f") % [_t.trajectory_error_km, _t.delta_v_remaining], HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, ThemeFactory.COL_MUTED)
		else:
			# MODE A: CRUISE INERTIAL ORBIT & TCM DEVIATION CORRIDOR
			var max_err: float = maxf(_t.max_trajectory_error_km, 1.0)
			# Green nominal corridor on left (0..15 km)
			var ok_w: float = clampf(15.0 / max_err, 0.1, 1.0) * (w - 4)
			draw_rect(Rect2(2, 13, ok_w, 8), Color(0.15, 0.58, 0.32, 0.55))

			var err_norm: float = clampf(_t.trajectory_error_km / max_err, 0.0, 1.0)
			var ecol: Color = ThemeFactory.COL_GREEN if _t.trajectory_error_km <= 14.0 else (ThemeFactory.COL_AMBER if _t.trajectory_error_km <= max_err * 0.85 else ThemeFactory.COL_RED)
			draw_rect(Rect2(2, 15, err_norm * (w - 4), 4), ecol)
			var mx: float = 2.0 + err_norm * (w - 4)
			draw_line(Vector2(mx, 11), Vector2(mx, 23), ThemeFactory.COL_WHITE, 1.0)

			if font != null:
				draw_string(font, Vector2(2, 9), Loc.pick("DESVÍO TCM: %.0f / %.0f km", "TCM DRIFT: %.0f / %.0f km") % [_t.trajectory_error_km, max_err], HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, ecol)
				var hint: String = Loc.pick("CRUCERO APAGADO (ÓRBITA OK)", "COASTING OFF (ORBIT OK)")
				var hcol: Color = ThemeFactory.COL_GREEN
				if _t.wrong_burn_direction and _t.engine_firing:
					hint = Loc.pick("¡ALINEA [PRO 0°] PARA TCM!", "AIM [PRO 0°] FOR TCM!")
					hcol = ThemeFactory.COL_RED
				elif _t.trajectory_error_km > 14.0:
					hint = Loc.pick("PULSO CORTO EN [PRO 0°]", "SHORT BURN AT [PRO 0°]")
					hcol = ThemeFactory.COL_AMBER
				elif _t.gravity_assist_completed and _t.gravity_assist_dv_gained > 0.0:
					hint = Loc.pick("HONDA OK: +%.0f m/s GRATIS", "ASSIST OK: +%.0f m/s FREE") % _t.gravity_assist_dv_gained
					hcol = ThemeFactory.COL_CYAN
				draw_string(font, Vector2(2, 33), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, hcol)
				draw_string(font, Vector2(2, 43), Loc.pick("Δv DISP:%.0f | INS:%.0fm/s", "Δv REM:%.0f | INS:%.0fm/s") % [_t.delta_v_remaining, _t.insertion_dv_target], HORIZONTAL_ALIGNMENT_LEFT, w - 4, font_size, ThemeFactory.COL_MUTED)


class _ThrottleLever extends Control:
	signal changed(val: float)
	var _val: float = 0.0
	var _dragging: bool = false

	func set_value(v: float) -> void:
		_val = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				if event.pressed:
					_update_from_x(event.position.x)
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_RIGHT]:
				_val = 0.0 if event.button_index == MOUSE_BUTTON_RIGHT else clampf(_val + (0.01 if event.shift_pressed else 0.05) * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0), 0.0, 1.0)
				changed.emit(_val)
				queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_update_from_x(event.position.x)
			accept_event()

	func _update_from_x(mx: float) -> void:
		var v: float = clampf((mx - 5.0) / maxf(size.x - 10.0, 1.0), 0.0, 1.0)
		_val = v
		changed.emit(v)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 6, size.x, 10), Color("0d111a"))
		draw_rect(Rect2(0, 6, size.x, 10), Color("46546c"), false, 1.0)
		var fill_w: float = _val * (size.x - 4.0)
		draw_rect(Rect2(2, 8, fill_w, 6), ThemeFactory.COL_AMBER)
		var knob_x: float = clampf(2.0 + _val * (size.x - 12.0), 1.0, size.x - 10.0)
		draw_rect(Rect2(knob_x, 2, 9, 18), Color("a8b4c6"))
		draw_rect(Rect2(knob_x, 2, 9, 18), Color("080a10"), false, 1.0)
		draw_rect(Rect2(knob_x + 3, 5, 3, 12), ThemeFactory.COL_RED)
