@tool
class_name MissionResultOverlay
extends Control
## Modal debrief overlay displayed when a mission succeeds or fails,
## with a scrollable CRT engineering analysis covering all 9 mission demands.

signal retry_requested()
signal assembly_requested()
signal menu_requested()

var _lbl_banner: Label
var _lbl_details: Label
var _action_buttons: Array[Button] = []
var _last_telemetry: FlightTelemetry
var _last_mission: MissionSpec


func _ready() -> void:
	visible = false
	_build_ui()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String):
			_refresh_button_labels()
			if visible and _last_telemetry != null:
				show_result(_last_telemetry, _last_mission)
		)


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	_lbl_banner = Label.new()
	_lbl_banner.custom_minimum_size.y = 24
	_lbl_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lbl_banner)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_lbl_details = Label.new()
	_lbl_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_lbl_details)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 3)
	box.add_child(actions)
	var definitions := [["REPETIR [R]", KEY_R, retry_requested], ["DISEÑO [D]", KEY_D, assembly_requested], ["MENÚ [ESC]", KEY_ESCAPE, menu_requested]]
	for definition in definitions:
		var button := Button.new()
		button.text = definition[0]
		button.custom_minimum_size.x = 140
		button.custom_minimum_size.y = 26
		ThemeFactory.bind_shortcut(button, definition[1])
		var action: Signal = definition[2]
		button.pressed.connect(func():
			AudioManager.play_sfx("click")
			action.emit()
		)
		actions.add_child(button)
		_action_buttons.append(button)
	_refresh_button_labels()


func _refresh_button_labels() -> void:
	if _action_buttons.size() < 3:
		return
	_action_buttons[0].text = Loc.pick("REPETIR [R]", "RETRY [R]")
	_action_buttons[1].text = Loc.pick("DISEÑO [D]", "DESIGN [D]")
	_action_buttons[2].text = Loc.pick("MENÚ [ESC]", "MENU [ESC]")


func show_result(t: FlightTelemetry, mission: MissionSpec) -> void:
	_last_telemetry = t
	_last_mission = mission
	_refresh_button_labels()
	visible = true
	var is_victory: bool = t.status == FlightTelemetry.Status.VICTORY
	if is_victory:
		_lbl_banner.text = Loc.pick(
			"MISIÓN CUMPLIDA\nÓRBITA Y CIENCIA CONFIRMADAS",
			"MISSION ACCOMPLISHED\nORBIT & SCIENCE CONFIRMED"
		)
		_lbl_banner.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	elif t.status == FlightTelemetry.Status.FAILED_OBJECTIVES:
		_lbl_banner.text = Loc.pick(
			"ÓRBITA LOGRADA\nOBJETIVOS CIENTÍFICOS PENDIENTES",
			"ORBIT ACHIEVED\nSCIENCE OBJECTIVES INCOMPLETE"
		)
		_lbl_banner.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	else:
		_lbl_banner.text = Loc.pick(
			"MISIÓN FALLIDA\nREVISA LA TRAYECTORIA Y LOS RECURSOS",
			"MISSION FAILED\nCHECK TRAJECTORY & RESOURCES"
		)
		_lbl_banner.add_theme_color_override("font_color", ThemeFactory.COL_RED)

	var status_msg: String = (
		Loc.pick(
			"Órbita alcanzada, objetivos científicos transmitidos y sistemas estables.",
			"Orbit reached, science objectives transmitted and systems stable."
		)
		if is_victory else t.failure_reason
	)
	var log_tail: PackedStringArray = []
	var start_idx: int = maxi(0, t.event_log.size() - 8)
	for i in range(start_idx, t.event_log.size()):
		log_tail.append("  > " + t.event_log[i])

	_lbl_details.text = Loc.pick(
		"%s\n\nOBJETIVO: %s\nVEHÍCULO LANZADOR: %s (+%.0f m/s inyección)\nENLACE COMMS: %.1f kbps | CIENCIA: %d / %d pts (Mín: %d)\nDESVÍO FINAL TCM: %.1f km (Máx %.0f km | Correcciones: %d)\nASISTENCIA GRAVITATORIA: +%.0f m/s sin gasto de combustible\nFRENADO INSERCIÓN 180°: %.0f / %.0f m/s\nΔv PROPULSIVO: %.0f m/s (Efectivo total: %.0f m/s)\nACTITUD FINAL: %+.0f° (%s)\nMASA SECA / PROP. REST.: %.0f kg / %.1f kg\nBATERÍA FINAL: %.0f / %.0f Wh\n\nBITÁCORA DE VUELO:\n%s",
		"%s\n\nOBJECTIVE: %s\nLAUNCH VEHICLE: %s (+%.0f m/s injection)\nCOMMS LINK: %.1f kbps | SCIENCE: %d / %d pts (Min: %d)\nFINAL TCM ERROR: %.1f km (Max %.0f km | Burns: %d)\nGRAVITY ASSIST: +%.0f m/s propellant-free\nRETRO INSERTION 180°: %.0f / %.0f m/s\nPROPULSIVE Δv: %.0f m/s (Total effective: %.0f m/s)\nFINAL ATTITUDE: %+.0f° (%s)\nDRY MASS / REM. FUEL: %.0f kg / %.1f kg\nFINAL BATTERY: %.0f / %.0f Wh\n\nFLIGHT LOG:\n%s"
	) % [
		status_msg,
		mission.objective_summary if mission else "-",
		t.launch_vehicle_name,
		t.launch_injection_dv,
		t.downlink_kbps,
		t.science_score,
		t.science_max,
		t.science_min_required,
		t.trajectory_error_km,
		t.max_trajectory_error_km,
		t.tcm_burns_count,
		t.gravity_assist_dv_gained,
		t.insertion_dv_burned,
		t.insertion_dv_target,
		t.delta_v_burned,
		t.effective_delta_v,
		t.attitude_deg,
		FlightTelemetry.system_state_label(t.system_state),
		t.dry_mass_kg,
		t.propellant_remaining_kg,
		t.battery_wh,
		t.battery_max_wh,
		"\n".join(log_tail),
	]
	_lbl_details.text += Loc.pick("\n\nQUÉ APRENDER:\n", "\n\nKEY TAKEAWAY:\n") + _learning_feedback(t)
	_lbl_details.text += Loc.pick(
		"\n\nMODELO: segundos de juego; datos x9200. Consulta AYUDA para unidades y simplificaciones.",
		"\n\nMODEL: game seconds; comms x9200. Check HELP for units & game-scale notes."
	)


func _learning_feedback(t: FlightTelemetry) -> String:
	match t.status:
		FlightTelemetry.Status.FAILED_POWER:
			return Loc.pick(
				"La batería cubre consumo menos generación. Añade paneles o Wh de reserva, apunta al Sol y apaga buses inactivos. Encender el motor también consume W.",
				"Battery covers load minus solar gen. Add panels or Wh storage, point Solar, and switch off idle buses. Firing engines also consumes W."
			)
		FlightTelemetry.Status.FAILED_FUEL:
			return Loc.pick(
				"Más masa reduce el delta-v disponible. Reserva propelente para el frenado final, usa pulsos TCM breves y compara motores/tanques antes de repetir.",
				"Extra mass reduces available delta-v. Save propellant for final braking, use brief TCM burns, and compare engines/tanks before retrying."
			)
		FlightTelemetry.Status.FAILED_MISSED_TARGET:
			return Loc.pick(
				"La orientación y el momento del impulso importan. Corrige en progrado, conserva combustible y frena en retrógrado dentro de la ventana; más empuje por sí solo no asegura la órbita.",
				"Orientation and burn timing matter. Trim prograde, conserve fuel, and brake retrograde inside the window; raw thrust alone cannot capture orbit."
			)
		FlightTelemetry.Status.FAILED_OBJECTIVES:
			return Loc.pick(
				"Llegar al destino no basta: instala los sensores requeridos, captura apuntando al objetivo durante el sobrevuelo y termina la descarga a Tierra antes del final.",
				"Reaching target isn't enough: mount required sensors, capture aimed at target during flyby, and finish Earth downlink before end."
			)
		_:
			return Loc.pick(
				"El éxito combina trayectoria, energía y ciencia descargada. Prueba una antena distinta o menos masa y compara batería, combustible y ciencia en el siguiente vuelo.",
				"Success balances trajectory, power, and downloaded science. Try another dish or lighter mass and compare margins on your next flight."
			)
