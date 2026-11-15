@tool
class_name ViewportWindow
extends Control
## Resizable space viewport. The 2.5D scene and HUD use separate draw layers.

var _space_view: MissionSpaceView
var _lbl_time: Label
var _lbl_dist: Label
var _lbl_state: Label
var _lbl_stage: Label
var _lbl_explanation: Label
var _lbl_alert: Label
var _lbl_controls: Label
var _mission: MissionSpec
var _telemetry: FlightTelemetry
var _guidance_visible: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true
	_space_view = MissionSpaceView.new()
	add_child(_space_view)
	_lbl_time = _label(Vector2(8, 6), Vector2(80, 12), ThemeFactory.COL_GREEN)
	_lbl_dist = _label(Vector2(90, 6), Vector2(210, 12), ThemeFactory.COL_CYAN)
	_lbl_state = _label(Vector2(306, 6), Vector2(98, 12), ThemeFactory.COL_GREEN)
	_lbl_stage = _label(Vector2(8, 24), Vector2(616, 12), ThemeFactory.COL_WHITE)
	_lbl_explanation = _label(Vector2.ZERO, Vector2(616, 24), ThemeFactory.COL_CYAN)
	_lbl_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_alert = _label(Vector2.ZERO, Vector2(616, 12), ThemeFactory.COL_AMBER)
	_lbl_controls = _label(Vector2.ZERO, Vector2(616, 12), ThemeFactory.COL_MUTED)
	_lbl_controls.text = Loc.pick(
		"A/D GIRAR | 1-5 APUNTAR | RUEDA EMPUJE | C TAPA | ESP MOTOR | F1 AYUDA",
		"A/D TURN | 1-5 AIM | WHEEL THRUST | C COVER | SPACE BURN | F1 HELP"
	)
	resized.connect(_layout)
	_layout()


func _label(pos: Vector2, dimensions: Vector2, col: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.clip_text = true
	label.add_theme_color_override("font_color", col)
	add_child(label)
	return label


func _layout() -> void:
	if _space_view == null or size.x < 100.0 or size.y < 100.0:
		return
	_lbl_time.position = Vector2(10, 4)
	_lbl_time.size = Vector2(150, 20)
	_lbl_dist.position = Vector2(165, 4)
	_lbl_dist.size = Vector2(size.x * 0.38, 20)
	_lbl_state.position = Vector2(size.x * 0.54, 4)
	_lbl_state.size = Vector2(size.x * 0.15, 20)
	_lbl_stage.position = Vector2(10, 27)
	_lbl_stage.size = Vector2(size.x * 0.54 - 16, 20)
	_lbl_alert.position = Vector2(size.x * 0.54, 27)
	_lbl_alert.size = Vector2(size.x * 0.46 - 12, 20)
	_space_view.position = Vector2(2, 49)
	_space_view.size = Vector2(size.x - 4.0, size.y - 93.0)
	_lbl_explanation.position = Vector2(10, size.y - 41)
	_lbl_explanation.size = Vector2(size.x - 20, 19)
	_lbl_explanation.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lbl_controls.position = Vector2(10, size.y - 21)
	_lbl_controls.size = Vector2(size.x - 20, 19)
	_lbl_explanation.visible = _guidance_visible
	_lbl_controls.visible = _guidance_visible
	if _telemetry != null:
		_space_view.update_telemetry(_telemetry, 0.0)
	queue_redraw()


func set_guidance_visible(enabled: bool) -> void:
	_guidance_visible = enabled
	_lbl_explanation.visible = enabled
	_lbl_controls.visible = enabled
	_space_view.guidance_visible = enabled
	_space_view.queue_redraw()
	_space_view._front.queue_redraw()


func set_internal_view(enabled: bool) -> void:
	_space_view.set_internal_view(enabled)
	if _telemetry != null:
		update_telemetry(_telemetry, 0.0)


func is_internal_view() -> bool:
	return _space_view != null and _space_view.internal_view


func setup(mission: MissionSpec, design: ProbeDesign = null) -> void:
	_mission = mission
	_space_view.setup(mission, design)


func update_telemetry(t: FlightTelemetry, dt: float) -> void:
	_telemetry = t
	if t == null or _mission == null:
		return
	_space_view.update_telemetry(t, dt)
	_lbl_time.text = Loc.pick("J+%02ds/%02ds", "T+%02ds/%02ds") % [int(t.elapsed_s), int(_mission.transit_duration_s)]
	_lbl_time.tooltip_text = Loc.pick(
		"Segundos de juego. La escena comprime distancias y tiempos; AYUDA explica las escalas.",
		"Game seconds. The scene compresses distances & times; HELP explains the scales."
	)
	_lbl_dist.text = _mission.target_name
	_lbl_state.text = FlightTelemetry.system_state_label(t.system_state)
	_lbl_state.add_theme_color_override("font_color", [ThemeFactory.COL_GREEN, ThemeFactory.COL_AMBER, ThemeFactory.COL_RED][int(t.system_state)])
	var snapshot: Dictionary = _space_view.get_scene_snapshot()
	var stage_text: String = str(snapshot.get("stage", Loc.pick("PREPARANDO ESCENA", "PREPARING SCENE")))
	if _space_view.internal_view:
		stage_text = "%s  [%s]" % [stage_text, InternalCabinRenderer.archetype_label(str(snapshot.get("cabin_archetype", "explorer")))]
	_lbl_stage.text = stage_text
	_lbl_stage.tooltip_text = Loc.pick(
		"Vista 2.5D externa / cabina interna [K]. Clic izquierdo: orientar. Derecho: estabilizar. Rueda: empuje. Clic central: mostrar/ocultar ayudas.",
		"2.5D external / internal cabin view [K]. Left click: aim. Right click: hold attitude. Wheel: thrust. Middle click: toggle guides."
	)
	_lbl_explanation.text = _explain(t)
	_lbl_explanation.tooltip_text = _lbl_explanation.text
	_lbl_alert.text = " | ".join(t.active_alerts) if not t.active_alerts.is_empty() else Loc.pick(
		"SISTEMAS NOMINALES | MASA, ENERGÍA Y DATOS LIMITADOS",
		"SYSTEMS NOMINAL | MASS, POWER & DATA CONSTRAINED"
	)
	_lbl_controls.text = Loc.pick(
		"A/D GIRAR | 1-5 APUNTAR | K VISTA INT/EXT | RUEDA EMPUJE | C TAPA | ESP MOTOR | F1 AYUDA",
		"A/D TURN | 1-5 AIM | K INT/EXT VIEW | WHEEL THRUST | C COVER | SPACE BURN | F1 HELP"
	)
	_lbl_alert.tooltip_text = _lbl_alert.text
	queue_redraw()


func get_scene_snapshot() -> Dictionary:
	return _space_view.get_scene_snapshot()


func is_space_position(point: Vector2) -> bool:
	return Rect2(_space_view.position, _space_view.size).has_point(point)


func mouse_attitude(point: Vector2) -> float:
	var snapshot: Dictionary = get_scene_snapshot()
	if snapshot.is_empty():
		return 0.0
	if _space_view.internal_view and _telemetry != null:
		var win := InternalCabinRenderer.window_rect(_space_view.size, str(snapshot.get("cabin_archetype", "explorer")))
		var local_x: float = point.x - _space_view.position.x - win.get_center().x
		var delta_deg: float = (local_x / maxf(win.size.x * 0.54, 1.0)) * 60.0
		return RocketMath.normalize_angle_deg(_telemetry.attitude_deg + delta_deg)
	var direction: Vector2 = point - _space_view.position - Vector2(snapshot["ship"])
	return RocketMath.normalize_angle_deg(rad_to_deg(direction.angle() - float(snapshot["frame_angle"])))


func _explain(t: FlightTelemetry) -> String:
	if t.status == FlightTelemetry.Status.VICTORY:
		return Loc.pick(
			"CAPTURA CONFIRMADA: la nave permanece alrededor del destino. La ciencia descargada cumple el objetivo.",
			"CAPTURE CONFIRMED: craft orbits target. Downloaded science fulfills mission objective."
		)
	if t.status == FlightTelemetry.Status.FAILED_OBJECTIVES:
		return Loc.pick(
			"ÓRBITA ALCANZADA, CIENCIA INCOMPLETA: orbitar y transmitir los objetivos son requisitos distintos.",
			"ORBIT REACHED, SCIENCE INCOMPLETE: orbiting and downlinking objectives are separate requirements."
		)
	if t.status != FlightTelemetry.Status.IN_FLIGHT:
		return "" + t.failure_reason
	if t.in_insertion_window:
		return Loc.pick(
			"RET 180° = opuesto a v. El frenado curva la predicción hacia una órbita: %.0f / %.0f m/s. Encender en progrado aleja la captura.",
			"RET 180° = opposite to v. Braking curves trajectory into orbit: %.0f / %.0f m/s. Burning prograde ruins capture."
		) % [t.insertion_dv_burned, t.insertion_dv_target]
	if t.attitude_mode == FlightTelemetry.AttitudeMode.TARGET:
		return Loc.pick(
			"OBJ -35° es la referencia local de sensores. Captura en la ventana de sobrevuelo: el haz resalta la zona observada.",
			"TARGET -35° aims onboard sensors. Capture during flyby window: scan beam marks observed area."
		)
	if t.attitude_mode == FlightTelemetry.AttitudeMode.EARTH:
		return Loc.pick(
			"TIERRA +90° alinea el enlace: %.1f kbps. El marcador de radio es una referencia local esquemática, no la posición del planeta.",
			"EARTH +90° aligns radio link: %.1f kbps. Radio marker is a schematic local pointing reference."
		) % t.downlink_kbps
	if t.attitude_mode == FlightTelemetry.AttitudeMode.SOLAR:
		return Loc.pick(
			"SOLAR -90° orienta la nave para cargar: %.0f W generados. El Sol visible sirve de referencia de paneles; su escala está comprimida.",
			"SOLAR -90° points arrays to charge: %.0f W output. Visible Sun marks solar vector at compressed scale."
		) % t.solar_gen_w
	if t.attitude_mode == FlightTelemetry.AttitudeMode.POINT:
		return Loc.pick(
			"APUNTADO LIBRE: clic hacia %.0f° del marco local. Las ruedas/RCS completan el giro; derecho o S estabiliza. La rueda ajusta empuje.",
			"FREE POINT: aimed toward %.0f° local frame. Wheels/RCS finish slew; right-click or S holds. Wheel adjusts thrust."
		) % t.target_attitude_deg
	return Loc.pick(
		"La flecha v define PRO 0°. Gira la nave con A/D o 1-5; el arco ámbar muestra el giro pendiente. Un pulso PRO reduce el desvío.",
		"Blue v arrow defines PRO 0°. Rotate via A/D or 1-5; amber arc shows pending turn. A PRO pulse trims course error."
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("060c18"))
	draw_rect(Rect2(2, 2, size.x - 4.0, 23), Color("111e2d"))
	draw_rect(Rect2(2, 26, size.x - 4.0, 21), Color("0d1c28"))
	draw_rect(Rect2(2, size.y - 43, size.x - 4.0, 41), Color("0b1824"))
	var x0: float = size.x * 0.70
	var width: float = size.x - x0 - 9.0
	var track := Rect2(x0, 9, width, 6)
	draw_rect(track, Color("060b12"))
	if _mission != null:
		for window in _mission.shadow_windows:
			draw_rect(Rect2(x0 + window.x * width, 9, (window.y - window.x) * width, 6), Color("495469"))
		for window in _mission.tcm_windows:
			draw_rect(Rect2(x0 + window.x * width, 9, (window.y - window.x) * width, 6), Color("2c805b"))
		draw_rect(Rect2(x0 + _mission.flyby_window_start_norm * width, 12, (_mission.flyby_window_end_norm - _mission.flyby_window_start_norm) * width, 3), ThemeFactory.COL_CYAN)
		draw_rect(Rect2(x0 + _mission.insertion_window_start_norm * width, 9, (1.0 - _mission.insertion_window_start_norm) * width, 2), ThemeFactory.COL_RED)
	if _telemetry != null:
		draw_rect(Rect2(x0 + _telemetry.progress_norm * width, 7, 2, 10), ThemeFactory.COL_WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("334b65"), false, 2.0)
