class_name FlightSimulator
extends RefCounted
## Pure deterministic spaceflight simulation engine.
## Operates solely on Domain entities (MissionSpec, ProbeDesign, FlightTelemetry).

# Scales rocket mass-flow so orbital maneuvers take ~8-30 real seconds of burn
# while preserving the exact Tsiolkovski delta-v integral.
const BURN_TIME_SCALE: float = 26.0
# 1 real second corresponds to 0.06 flight-hours (3.6 flight-minutes) for battery Wh math.
const FLIGHT_HOURS_PER_REAL_SEC: float = 0.06

var mission: MissionSpec
var design: ProbeDesign
var telemetry: FlightTelemetry

var _total_thrust_n: float = 0.0
var _effective_isp_s: float = 0.0
var _instrument_parts: Array[PartSpec] = []
var _transmission_progress: Dictionary = {} # part_id -> float (0..1)
var _prev_in_shadow: bool = false
var _prev_in_storm: bool = false
var _prev_in_flyby: bool = false


func _init(p_mission: MissionSpec, p_design: ProbeDesign) -> void:
	mission = p_mission
	design = p_design.clone()
	telemetry = FlightTelemetry.new()
	_initialize()


func _initialize() -> void:
	_total_thrust_n = RocketMath.calculate_total_thrust_n(design)
	_effective_isp_s = RocketMath.calculate_effective_isp_s(design)

	telemetry.status = FlightTelemetry.Status.IN_FLIGHT
	telemetry.target_distance_km = mission.target_distance_km
	telemetry.dry_mass_kg = RocketMath.calculate_dry_mass_kg(design)
	telemetry.propellant_max_kg = RocketMath.calculate_propellant_mass_kg(design)
	telemetry.propellant_remaining_kg = telemetry.propellant_max_kg
	telemetry.delta_v_initial = RocketMath.calculate_delta_v(design)
	telemetry.delta_v_remaining = telemetry.delta_v_initial
	telemetry.delta_v_required = mission.required_delta_v

	telemetry.battery_max_wh = RocketMath.calculate_battery_capacity_wh(design)
	telemetry.battery_wh = telemetry.battery_max_wh
	telemetry.science_max = RocketMath.calculate_max_science(design)

	_instrument_parts = design.get_parts_by_category(PartSpec.Category.INSTRUMENT)
	telemetry.event_log.append("T+00s: Inserción en trayectoria hacia %s." % mission.target_name)
	_recompute_power_snapshot()


func set_throttle(value: float) -> void:
	telemetry.throttle = clampf(value, 0.0, 1.0)
	if telemetry.throttle <= 0.0:
		telemetry.engine_firing = false


func toggle_safety_cover() -> void:
	telemetry.safety_cover_open = not telemetry.safety_cover_open
	if not telemetry.safety_cover_open:
		telemetry.engine_armed = false
		telemetry.engine_firing = false


func set_engine_armed(armed: bool) -> void:
	if armed and not telemetry.safety_cover_open:
		return
	telemetry.engine_armed = armed
	if not telemetry.engine_armed:
		telemetry.engine_firing = false


func trigger_ignition() -> bool:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return false
	if not telemetry.safety_cover_open or not telemetry.master_bus_on:
		return false
	if telemetry.propellant_remaining_kg <= 0.0 or _total_thrust_n <= 0.0:
		return false
	telemetry.engine_armed = true
	telemetry.engine_firing = not telemetry.engine_firing
	if telemetry.engine_firing and telemetry.throttle < 0.15:
		telemetry.throttle = 0.5
	return telemetry.engine_firing


func deploy_panels() -> bool:
	if telemetry.panels_deployed or not telemetry.master_bus_on:
		return false
	telemetry.panels_deployed = true
	telemetry.event_log.append("T+%02ds: Paneles solares desplegados." % int(telemetry.elapsed_s))
	_recompute_power_snapshot()
	return true


func set_master_bus(enabled: bool) -> void:
	telemetry.master_bus_on = enabled
	if not enabled:
		telemetry.engine_firing = false
	_recompute_power_snapshot()


func set_comms_bus(enabled: bool) -> void:
	telemetry.comms_on = enabled
	_recompute_power_snapshot()


func set_science_bus(enabled: bool) -> void:
	telemetry.science_bus_on = enabled
	_recompute_power_snapshot()


func activate_instrument(part_id: String) -> Dictionary:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return {"ok": false, "reason": "Misión finalizada"}
	if not telemetry.master_bus_on or not telemetry.science_bus_on:
		return {"ok": false, "reason": "Bus de ciencia apagado"}

	var target_part: PartSpec = null
	for part in _instrument_parts:
		if part.id == part_id:
			target_part = part
			break
	if target_part == null:
		return {"ok": false, "reason": "Instrumento no instalado"}

	var quality: float = 1.0 if telemetry.in_flyby_window else 0.35
	var prev_quality: float = float(telemetry.instruments_captured.get(part_id, 0.0))
	if quality <= prev_quality and telemetry.instruments_transmitted.get(part_id, false):
		return {"ok": false, "reason": "Ya capturado a máxima calidad"}

	telemetry.instruments_captured[part_id] = maxf(prev_quality, quality)
	telemetry.instruments_transmitted[part_id] = false
	_transmission_progress[part_id] = 0.0

	var tag: String = "SOBREVUELO ÓPTIMO" if telemetry.in_flyby_window else "CALIBRACIÓN LEJANA"
	telemetry.event_log.append("T+%02ds: %s capturado (%s)." % [int(telemetry.elapsed_s), target_part.display_name, tag])
	return {"ok": true, "quality": quality, "optimal": telemetry.in_flyby_window}


func get_transmission_progress(part_id: String) -> float:
	if telemetry.instruments_transmitted.get(part_id, false):
		return 1.0
	return float(_transmission_progress.get(part_id, 0.0))


func step(dt: float) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT or dt <= 0.0:
		return

	telemetry.elapsed_s += dt
	telemetry.progress_norm = clampf(telemetry.elapsed_s / mission.transit_duration_s, 0.0, 1.0)
	telemetry.distance_km = telemetry.progress_norm * mission.target_distance_km

	_update_environmental_windows()
	_step_propulsion(dt)
	_step_power(dt)
	_step_transmissions(dt)
	_update_alerts()
	_evaluate_end_conditions()


func _update_environmental_windows() -> void:
	var p: float = telemetry.progress_norm
	telemetry.in_shadow = _is_in_any_window(p, mission.shadow_windows)
	telemetry.in_solar_storm = _is_in_any_window(p, mission.solar_storm_windows)
	telemetry.in_flyby_window = (p >= mission.flyby_window_start_norm and p <= mission.flyby_window_end_norm)

	if telemetry.in_shadow and not _prev_in_shadow:
		telemetry.event_log.append("T+%02ds: Entrada en zona de eclipse/sombra." % int(telemetry.elapsed_s))
	elif not telemetry.in_shadow and _prev_in_shadow:
		telemetry.event_log.append("T+%02ds: Salida de zona de sombra." % int(telemetry.elapsed_s))

	if telemetry.in_solar_storm and not _prev_in_storm:
		telemetry.event_log.append("T+%02ds: ¡Alerta! Tormenta solar detectada." % int(telemetry.elapsed_s))
	if telemetry.in_flyby_window and not _prev_in_flyby:
		telemetry.event_log.append("T+%02ds: Ventana óptima de sobrevuelo abierta." % int(telemetry.elapsed_s))

	_prev_in_shadow = telemetry.in_shadow
	_prev_in_storm = telemetry.in_solar_storm
	_prev_in_flyby = telemetry.in_flyby_window


func _is_in_any_window(p: float, windows: Array[Vector2]) -> bool:
	for w in windows:
		if p >= w.x and p <= w.y:
			return true
	return false


func _step_propulsion(dt: float) -> void:
	if not telemetry.engine_firing or not telemetry.engine_armed or not telemetry.master_bus_on:
		telemetry.engine_firing = false
		return
	if telemetry.throttle <= 0.0 or telemetry.propellant_remaining_kg <= 0.0 or _total_thrust_n <= 0.0:
		telemetry.engine_firing = false
		return

	var current_wet_mass: float = telemetry.dry_mass_kg + telemetry.propellant_remaining_kg
	var mass_flow_kg_s: float = (_total_thrust_n * telemetry.throttle) / (_effective_isp_s * RocketMath.G0)
	var consumed_kg: float = minf(mass_flow_kg_s * dt * BURN_TIME_SCALE, telemetry.propellant_remaining_kg)
	var new_wet_mass: float = maxf(current_wet_mass - consumed_kg, telemetry.dry_mass_kg)

	var step_dv: float = RocketMath.calculate_delta_v_from_masses(_effective_isp_s, current_wet_mass, new_wet_mass)
	telemetry.propellant_remaining_kg = maxf(telemetry.propellant_remaining_kg - consumed_kg, 0.0)
	telemetry.delta_v_burned += step_dv
	telemetry.delta_v_remaining = RocketMath.calculate_delta_v_from_masses(
		_effective_isp_s,
		telemetry.dry_mass_kg + telemetry.propellant_remaining_kg,
		telemetry.dry_mass_kg
	)

	if telemetry.propellant_remaining_kg <= 0.0:
		telemetry.engine_firing = false
		telemetry.event_log.append("T+%02ds: Tanques de propelente agotados." % int(telemetry.elapsed_s))


func _recompute_power_snapshot() -> void:
	telemetry.solar_gen_w = RocketMath.calculate_solar_generation_w(
		design,
		mission.distance_au,
		telemetry.panels_deployed,
		telemetry.in_shadow
	)
	telemetry.power_draw_w = RocketMath.calculate_power_draw_w(
		design,
		telemetry.master_bus_on,
		telemetry.comms_on,
		telemetry.science_bus_on,
		telemetry.in_solar_storm
	)
	telemetry.power_net_w = telemetry.solar_gen_w - telemetry.power_draw_w


func _step_power(dt: float) -> void:
	_recompute_power_snapshot()
	var dt_hours: float = dt * FLIGHT_HOURS_PER_REAL_SEC
	telemetry.battery_wh = clampf(
		telemetry.battery_wh + telemetry.power_net_w * dt_hours,
		0.0,
		telemetry.battery_max_wh
	)


func _step_transmissions(dt: float) -> void:
	if not telemetry.master_bus_on or not telemetry.comms_on:
		return

	var total_score: int = 0
	for part in _instrument_parts:
		var quality: float = float(telemetry.instruments_captured.get(part.id, 0.0))
		if quality <= 0.0:
			continue
		if telemetry.instruments_transmitted.get(part.id, false):
			total_score += int(round(float(part.science_value) * quality))
			continue

		var prog: float = float(_transmission_progress.get(part.id, 0.0)) + dt * 0.55
		if prog >= 1.0:
			_transmission_progress[part.id] = 1.0
			telemetry.instruments_transmitted[part.id] = true
			var pts: int = int(round(float(part.science_value) * quality))
			total_score += pts
			telemetry.event_log.append("T+%02ds: Telemetría %s transmitida (+%d pts)." % [int(telemetry.elapsed_s), part.display_name, pts])
		else:
			_transmission_progress[part.id] = prog

	telemetry.science_score = total_score


func _update_alerts() -> void:
	telemetry.active_alerts.clear()
	if telemetry.battery_max_wh > 0.0 and (telemetry.battery_wh / telemetry.battery_max_wh) < 0.25:
		telemetry.active_alerts.append("BATERÍA BAJA")
	if telemetry.in_shadow:
		telemetry.active_alerts.append("ZONA DE SOMBRA")
	if telemetry.in_solar_storm:
		telemetry.active_alerts.append("TORMENTA SOLAR")
	if not telemetry.panels_deployed:
		telemetry.active_alerts.append("PANELES REPLEGADOS")
	if telemetry.in_flyby_window:
		telemetry.active_alerts.append("VENTANA DE SOBREVUELO")


func _evaluate_end_conditions() -> void:
	if telemetry.battery_wh <= 0.0:
		telemetry.status = FlightTelemetry.Status.FAILED_POWER
		telemetry.engine_firing = false
		telemetry.failure_reason = "Apagón total: las baterías se agotaron durante la misión."
		return

	if telemetry.progress_norm < 1.0:
		return

	var min_dv: float = mission.required_delta_v - mission.delta_v_tolerance
	var max_dv: float = mission.required_delta_v + mission.delta_v_tolerance * 2.0

	if telemetry.delta_v_burned < min_dv:
		if telemetry.propellant_remaining_kg <= 0.01:
			telemetry.status = FlightTelemetry.Status.FAILED_FUEL
			telemetry.failure_reason = "Propelente insuficiente: Δv alcanzado %.0f / %.0f m/s." % [
				telemetry.delta_v_burned,
				mission.required_delta_v
			]
		else:
			telemetry.status = FlightTelemetry.Status.FAILED_MISSED_TARGET
			telemetry.failure_reason = "Maniobra incompleta: faltó impulso orbital (%.0f / %.0f m/s)." % [
				telemetry.delta_v_burned,
				mission.required_delta_v
			]
		return

	if telemetry.delta_v_burned > max_dv:
		telemetry.status = FlightTelemetry.Status.FAILED_MISSED_TARGET
		telemetry.failure_reason = "Sobreimpulso excesivo: la sonda superó el corredor orbital (%.0f m/s)." % telemetry.delta_v_burned
		return

	telemetry.status = FlightTelemetry.Status.VICTORY
	telemetry.engine_firing = false
