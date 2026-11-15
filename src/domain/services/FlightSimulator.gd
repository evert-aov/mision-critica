class_name FlightSimulator
extends RefCounted
## Pure deterministic spaceflight simulation engine.
## Simulates all competing engineering subsystems during flight:
## 1. Launch Vehicle injection state (upper-stage Δv bonus & orbital injection dispersion)
## 2. Attitude Control System (Reaction Wheels + RCS thrusters, pointing modes, tumbling)
## 3. Trajectory Control (Curved coasting, TCM trims, Gravity Assist slingshots, 180° Orbital Insertion)
## 4. Propulsion (Tsiolkovski rocket equation), Power buses/eclipses/storms
## 5. Deep-Space Communications (kbps with 1/d² path loss, HGA Earth pointing, MB packet downlink)
## 6. Mission Objectives verification (mandatory instruments transmitted & minimum science threshold)

const BURN_TIME_SCALE: float = 45.0
const FLIGHT_HOURS_PER_REAL_SEC: float = 0.06
const AUTO_MAX_STEP_S: float = 1.0 / 60.0

var automatic_enabled: bool = false
var automatic_action: String = "Control manual"
var _autopilot := MissionAutopilot.new()

const RW_ACCEL_DEG_S2: float = 55.0
const RW_MAX_SLEW_DEG_S: float = 42.0
const RCS_ACCEL_DEG_S2: float = 105.0
const RCS_MAX_SLEW_DEG_S: float = 78.0

const ANGLE_PROGRADE: float = 0.0
const ANGLE_RETROGRADE: float = 180.0
const ANGLE_SOLAR: float = -90.0
const ANGLE_EARTH: float = 90.0
const ANGLE_TARGET: float = -35.0

var mission: MissionSpec
var design: ProbeDesign
var telemetry: FlightTelemetry

var _total_thrust_n: float = 0.0
var _effective_isp_s: float = 0.0
var _instrument_parts: Array[PartSpec] = []
var _transmission_progress: Dictionary = {} # part_id -> float (0..1)
var _manual_turn_dir: float = 0.0
var _acs_active_draw_w: float = 0.0

var _prev_in_shadow: bool = false
var _prev_in_storm: bool = false
var _prev_in_flyby: bool = false
var _prev_in_tcm: bool = false
var _prev_in_insertion: bool = false
var _logged_wrong_burn: bool = false


func _init(p_mission: MissionSpec, p_design: ProbeDesign) -> void:
	mission = p_mission
	design = p_design.clone()
	telemetry = FlightTelemetry.new()
	_initialize()


func _initialize() -> void:
	_total_thrust_n = RocketMath.calculate_total_thrust_n(design)
	_effective_isp_s = RocketMath.calculate_effective_isp_s(design)

	var lv: LaunchVehicleSpec = design.get_launch_vehicle()
	telemetry.launch_vehicle_name = lv.display_name if lv != null else "Inyección Estándar"
	telemetry.launch_injection_dv = lv.injection_dv_ms if lv != null else 0.0

	telemetry.status = FlightTelemetry.Status.IN_FLIGHT
	telemetry.target_distance_km = mission.target_distance_km
	telemetry.dry_mass_kg = RocketMath.calculate_dry_mass_kg(design)
	telemetry.propellant_max_kg = RocketMath.calculate_propellant_mass_kg(design)
	telemetry.propellant_remaining_kg = telemetry.propellant_max_kg
	telemetry.delta_v_initial = RocketMath.calculate_delta_v(design)
	telemetry.delta_v_remaining = telemetry.delta_v_initial
	telemetry.delta_v_required = mission.required_delta_v
	telemetry.effective_delta_v = telemetry.launch_injection_dv

	telemetry.battery_max_wh = RocketMath.calculate_battery_capacity_wh(design)
	telemetry.battery_wh = telemetry.battery_max_wh
	telemetry.science_max = RocketMath.calculate_max_science(design)
	telemetry.science_min_required = mission.min_science_required

	telemetry.attitude_mode = FlightTelemetry.AttitudeMode.PROGRADE
	telemetry.attitude_deg = ANGLE_PROGRADE
	telemetry.target_attitude_deg = ANGLE_PROGRADE
	telemetry.angular_vel_deg_s = 0.0

	telemetry.trajectory_error_km = lv.injection_dispersion_km if lv != null else mission.initial_trajectory_error_km
	telemetry.max_trajectory_error_km = mission.max_trajectory_error_km
	telemetry.insertion_dv_target = maxf(250.0, mission.insertion_dv_required - telemetry.launch_injection_dv)

	_instrument_parts = design.get_parts_by_category(PartSpec.Category.INSTRUMENT)
	var lv_tag: String = ("%s (+%.0f m/s)" % [lv.short_name, lv.injection_dv_ms]) if lv != null else Loc.pick("Directo", "Direct")
	telemetry.event_log.append(Loc.pick(
		"T+00s: Separación %s hacia %s (dispersión %.0f km).",
		"T+00s: %s separation toward %s (dispersion %.0f km)."
	) % [
		lv_tag,
		mission.target_name,
		telemetry.trajectory_error_km,
	])
	_update_alignment_factors()
	_recompute_power_snapshot()
	_update_downlink_rate()
	_update_system_state_and_alerts()


# --- ATTITUDE / ORIENTATION COMMANDS ---

func set_attitude_mode(mode: FlightTelemetry.AttitudeMode) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return
	_manual_turn_dir = 0.0
	telemetry.attitude_mode = mode
	match mode:
		FlightTelemetry.AttitudeMode.PROGRADE:
			telemetry.target_attitude_deg = ANGLE_PROGRADE
		FlightTelemetry.AttitudeMode.RETROGRADE:
			telemetry.target_attitude_deg = ANGLE_RETROGRADE
		FlightTelemetry.AttitudeMode.SOLAR:
			telemetry.target_attitude_deg = ANGLE_SOLAR
		FlightTelemetry.AttitudeMode.EARTH:
			telemetry.target_attitude_deg = ANGLE_EARTH
		FlightTelemetry.AttitudeMode.TARGET:
			telemetry.target_attitude_deg = ANGLE_TARGET
		FlightTelemetry.AttitudeMode.HOLD:
			telemetry.target_attitude_deg = telemetry.attitude_deg
		FlightTelemetry.AttitudeMode.MANUAL:
			telemetry.target_attitude_deg = telemetry.attitude_deg


func point_attitude(local_angle_deg: float) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return
	set_attitude_mode(FlightTelemetry.AttitudeMode.POINT)
	telemetry.target_attitude_deg = RocketMath.normalize_angle_deg(local_angle_deg)


func set_manual_rotation(turn_dir: float) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return
	_manual_turn_dir = clampf(turn_dir, -1.0, 1.0)
	if absf(_manual_turn_dir) > 0.01:
		telemetry.attitude_mode = FlightTelemetry.AttitudeMode.MANUAL


func nudge_attitude(dir: float) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT or not telemetry.master_bus_on:
		return
	telemetry.attitude_mode = FlightTelemetry.AttitudeMode.MANUAL
	var has_rcs: bool = telemetry.rcs_enabled and telemetry.propellant_remaining_kg > 0.02
	var step_rate: float = 24.0 if has_rcs else 14.0
	if not has_rcs and telemetry.rw_saturation >= 0.995:
		return
	telemetry.angular_vel_deg_s = clampf(telemetry.angular_vel_deg_s + signf(dir) * step_rate, -75.0, 75.0)
	telemetry.rcs_active_jets = int(signf(dir)) if has_rcs else 0


func stabilize_attitude() -> void:
	set_attitude_mode(FlightTelemetry.AttitudeMode.HOLD)


func set_rcs_enabled(enabled: bool) -> bool:
	telemetry.rcs_enabled = enabled
	if not enabled:
		telemetry.rcs_active_jets = 0
	return telemetry.rcs_enabled


func toggle_rcs() -> bool:
	return set_rcs_enabled(not telemetry.rcs_enabled)


# --- PROPULSION, POWER & SCIENCE COMMANDS ---

func set_throttle(value: float) -> void:
	telemetry.throttle = clampf(value, 0.0, 1.0)
	if telemetry.throttle <= 0.0:
		telemetry.engine_firing = false
		telemetry.wrong_burn_direction = false


func toggle_safety_cover() -> void:
	telemetry.safety_cover_open = not telemetry.safety_cover_open
	if not telemetry.safety_cover_open:
		telemetry.engine_armed = false
		telemetry.engine_firing = false
		telemetry.wrong_burn_direction = false


func set_engine_armed(armed: bool) -> void:
	if armed and not telemetry.safety_cover_open:
		return
	telemetry.engine_armed = armed
	if not telemetry.engine_armed:
		telemetry.engine_firing = false
		telemetry.wrong_burn_direction = false


func trigger_ignition() -> bool:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return false
	if not telemetry.safety_cover_open or not telemetry.master_bus_on:
		return false
	if telemetry.propellant_remaining_kg <= 0.0 or _total_thrust_n <= 0.0:
		return false
	telemetry.engine_armed = true
	telemetry.engine_firing = not telemetry.engine_firing
	if telemetry.engine_firing:
		_logged_wrong_burn = false
		if telemetry.throttle < 0.15:
			telemetry.throttle = 0.5
	else:
		telemetry.wrong_burn_direction = false
	return telemetry.engine_firing


func deploy_panels() -> bool:
	if telemetry.panels_deployed or not telemetry.master_bus_on:
		return false
	telemetry.panels_deployed = true
	telemetry.event_log.append(Loc.pick("T+%02ds: Paneles solares desplegados.", "T+%02ds: Solar arrays deployed.") % int(telemetry.elapsed_s))
	_recompute_power_snapshot()
	return true


func set_master_bus(enabled: bool) -> void:
	telemetry.master_bus_on = enabled
	if not enabled:
		telemetry.engine_firing = false
		telemetry.rcs_active_jets = 0
		telemetry.wrong_burn_direction = false
	_recompute_power_snapshot()
	_update_downlink_rate()


func set_comms_bus(enabled: bool) -> void:
	telemetry.comms_on = enabled
	_recompute_power_snapshot()
	_update_downlink_rate()


func set_science_bus(enabled: bool) -> void:
	telemetry.science_bus_on = enabled
	_recompute_power_snapshot()


func activate_instrument(part_id: String) -> Dictionary:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return {"ok": false, "reason": Loc.pick("Misión finalizada", "Mission ended")}
	if not telemetry.master_bus_on or not telemetry.science_bus_on:
		return {"ok": false, "reason": Loc.pick("Bus de ciencia apagado", "Science bus off")}

	var target_part: PartSpec = null
	for part in _instrument_parts:
		if part.id == part_id:
			target_part = part
			break
	if target_part == null:
		return {"ok": false, "reason": Loc.pick("Instrumento no instalado", "Instrument not installed")}

	var quality: float = 0.35
	var tag: String = Loc.pick("CALIBRACIÓN LEJANA 35%", "FAR CALIBRATION 35%")
	if telemetry.in_flyby_window:
		if telemetry.target_pointing_ok:
			quality = 1.0
			tag = Loc.pick("SOBREVUELO ÓPTIMO 100%", "OPTIMAL FLYBY 100%")
		else:
			quality = 0.60
			tag = Loc.pick("DESALINEADO 60% - APUNTA OBJETIVO", "OFF-POINT 60% - AIM AT TARGET")

	var prev_quality: float = float(telemetry.instruments_captured.get(part_id, 0.0))
	if quality <= prev_quality and telemetry.instruments_transmitted.get(part_id, false):
		return {"ok": false, "reason": Loc.pick("Ya capturado a igual o mayor calidad", "Already captured at equal or higher quality")}

	telemetry.instruments_captured[part_id] = maxf(prev_quality, quality)
	telemetry.instruments_transmitted[part_id] = false
	_transmission_progress[part_id] = 0.0

	telemetry.event_log.append(Loc.pick(
		"T+%02ds: %s capturado (%.0f MB, %s).",
		"T+%02ds: %s captured (%.0f MB, %s)."
	) % [
		int(telemetry.elapsed_s),
		target_part.display_name,
		target_part.data_volume_mb,
		tag,
	])
	return {
		"ok": true,
		"quality": quality,
		"optimal": quality >= 0.99,
		"pointed": telemetry.target_pointing_ok,
	}


func get_transmission_progress(part_id: String) -> float:
	if telemetry.instruments_transmitted.get(part_id, false):
		return 1.0
	return float(_transmission_progress.get(part_id, 0.0))


# --- MAIN SIMULATION TICK ---

func step(dt: float) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT or dt <= 0.0:
		return
	if automatic_enabled:
		var remaining: float = dt
		while remaining > 0.0000001 and telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
			var tick: float = minf(remaining, AUTO_MAX_STEP_S)
			_autopilot.update(self, tick)
			_step_once(tick)
			remaining -= tick
	else:
		_step_once(dt)


func set_automatic_enabled(enabled: bool) -> void:
	if telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return
	automatic_enabled = enabled
	set_throttle(0.0)
	set_manual_rotation(0.0)
	stabilize_attitude()
	automatic_action = Loc.pick(
		"Preparando operación automática" if enabled else "Control manual: motor detenido",
		"Preparing automatic ops" if enabled else "Manual control: engine stopped"
	)
	telemetry.event_log.append("T+%02ds: %s." % [int(telemetry.elapsed_s), automatic_action])


func _step_once(dt: float) -> void:

	telemetry.elapsed_s += dt
	telemetry.progress_norm = clampf(telemetry.elapsed_s / mission.transit_duration_s, 0.0, 1.0)
	telemetry.distance_km = telemetry.progress_norm * mission.target_distance_km

	_update_environmental_windows()
	_step_attitude(dt)
	_step_trajectory_and_gravity_assist(dt)
	_step_propulsion(dt)
	_step_power(dt)
	_step_transmissions(dt)
	_update_system_state_and_alerts()
	_evaluate_end_conditions()


func _update_environmental_windows() -> void:
	var p: float = telemetry.progress_norm
	telemetry.in_shadow = _is_in_any_window(p, mission.shadow_windows)
	telemetry.in_solar_storm = _is_in_any_window(p, mission.solar_storm_windows)
	telemetry.in_flyby_window = (p >= mission.flyby_window_start_norm and p <= mission.flyby_window_end_norm)
	telemetry.in_tcm_window = _is_in_any_window(p, mission.tcm_windows)
	telemetry.in_gravity_assist_window = (
		mission.has_gravity_assist
		and p >= mission.gravity_assist_window.x
		and p <= mission.gravity_assist_window.y
	)
	telemetry.in_insertion_window = (
		mission.requires_orbital_insertion
		and p >= mission.insertion_window_start_norm
	)

	if telemetry.in_insertion_window:
		telemetry.flight_phase = FlightTelemetry.FlightPhase.ORBITAL_INSERTION
	elif telemetry.in_gravity_assist_window:
		telemetry.flight_phase = FlightTelemetry.FlightPhase.GRAVITY_ASSIST
	elif telemetry.in_tcm_window:
		telemetry.flight_phase = FlightTelemetry.FlightPhase.TCM_WINDOW
	else:
		telemetry.flight_phase = FlightTelemetry.FlightPhase.CRUISE_COAST

	if telemetry.in_shadow and not _prev_in_shadow:
		telemetry.event_log.append(Loc.pick("T+%02ds: Entrada en eclipse/sombra solar.", "T+%02ds: Entered solar eclipse/shadow.") % int(telemetry.elapsed_s))
	elif not telemetry.in_shadow and _prev_in_shadow:
		telemetry.event_log.append(Loc.pick("T+%02ds: Salida de sombra solar.", "T+%02ds: Exited solar shadow.") % int(telemetry.elapsed_s))

	if telemetry.in_solar_storm and not _prev_in_storm:
		telemetry.event_log.append(Loc.pick("T+%02ds: ¡Tormenta solar! Perturbación de actitud activa.", "T+%02ds: Solar storm! Active attitude disturbance.") % int(telemetry.elapsed_s))
	if telemetry.in_tcm_window and not _prev_in_tcm:
		telemetry.event_log.append(Loc.pick("T+%02ds: Ventana TCM abierta: alinea PROGRADO (0°) y corrige desvío.", "T+%02ds: TCM window open: aim PROGRADE (0°) and fix drift.") % int(telemetry.elapsed_s))
	if telemetry.in_flyby_window and not _prev_in_flyby:
		telemetry.event_log.append(Loc.pick("T+%02ds: Ventana científica abierta: apunta OBJETIVO (-35°) para 100%%.", "T+%02ds: Science window open: aim TARGET (-35°) for 100%%.") % int(telemetry.elapsed_s))
	if telemetry.in_insertion_window and not _prev_in_insertion:
		telemetry.event_log.append(Loc.pick("T+%02ds: ¡INSERCIÓN ORBITAL! Gira 180° RETRÓGRADO y frena ahora.", "T+%02ds: ORBITAL INSERTION! Turn 180° RETROGRADE and brake now.") % int(telemetry.elapsed_s))

	_prev_in_shadow = telemetry.in_shadow
	_prev_in_storm = telemetry.in_solar_storm
	_prev_in_flyby = telemetry.in_flyby_window
	_prev_in_tcm = telemetry.in_tcm_window
	_prev_in_insertion = telemetry.in_insertion_window


func _is_in_any_window(p: float, windows: Array[Vector2]) -> bool:
	for w in windows:
		if p >= w.x and p <= w.y:
			return true
	return false


func _step_attitude(dt: float) -> void:
	telemetry.rcs_active_jets = 0
	_acs_active_draw_w = 0.0

	var ext_accel: float = sin(telemetry.elapsed_s * 0.85) * 1.3
	if telemetry.in_solar_storm:
		ext_accel += sin(telemetry.elapsed_s * 4.4) * 18.0 + 10.0

	var rw_avail: bool = telemetry.master_bus_on and telemetry.rw_saturation < 0.995
	var rcs_avail: bool = telemetry.master_bus_on and telemetry.rcs_enabled and telemetry.propellant_remaining_kg > 0.02

	if rcs_avail and telemetry.rw_saturation > 0.005:
		var desat: float = minf(telemetry.rw_saturation, dt * 0.32)
		telemetry.rw_saturation -= desat
		_consume_rcs_propellant(dt * 0.04)
		telemetry.rcs_active_jets = 2

	var max_accel: float = (RW_ACCEL_DEG_S2 if rw_avail else 0.0) + (RCS_ACCEL_DEG_S2 if rcs_avail else 0.0)
	var max_slew: float = RCS_MAX_SLEW_DEG_S if rcs_avail else RW_MAX_SLEW_DEG_S

	if telemetry.master_bus_on and max_accel > 0.0:
		if telemetry.attitude_mode == FlightTelemetry.AttitudeMode.MANUAL:
			if absf(_manual_turn_dir) > 0.01:
				var cmd_accel: float = _manual_turn_dir * max_accel
				telemetry.angular_vel_deg_s = clampf(
					telemetry.angular_vel_deg_s + (cmd_accel + ext_accel) * dt,
					-max_slew,
					max_slew
				)
				_acs_active_draw_w = 7.0 if rw_avail else 0.0
				if rcs_avail:
					_consume_rcs_propellant(dt * 0.12)
					telemetry.rcs_active_jets = int(signf(_manual_turn_dir))
				elif rw_avail:
					telemetry.rw_saturation = clampf(telemetry.rw_saturation + dt * 0.018, 0.0, 1.0)
			else:
				telemetry.angular_vel_deg_s = clampf(telemetry.angular_vel_deg_s + ext_accel * dt, -85.0, 85.0)
		elif telemetry.attitude_mode == FlightTelemetry.AttitudeMode.HOLD:
			var prev_vel: float = telemetry.angular_vel_deg_s
			telemetry.angular_vel_deg_s = move_toward(telemetry.angular_vel_deg_s + ext_accel * dt, 0.0, max_accel * dt)
			telemetry.target_attitude_deg = telemetry.attitude_deg
			if absf(prev_vel) > 1.5 or absf(ext_accel) > 4.0:
				_acs_active_draw_w = 5.0 if rw_avail else 0.0
				if rcs_avail and absf(prev_vel) > 2.5:
					_consume_rcs_propellant(dt * 0.08)
					telemetry.rcs_active_jets = -int(signf(prev_vel))
				elif rw_avail:
					telemetry.rw_saturation = clampf(telemetry.rw_saturation + absf(ext_accel) * 0.0025 * dt, 0.0, 1.0)
		else:
			var err: float = RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, telemetry.target_attitude_deg)
			var desired_vel: float = clampf(err * 2.3, -max_slew, max_slew)
			if absf(err) < 0.45 and absf(telemetry.angular_vel_deg_s) < 1.8 and not telemetry.in_solar_storm:
				telemetry.attitude_deg = telemetry.target_attitude_deg
				telemetry.angular_vel_deg_s = 0.0
				_acs_active_draw_w = 1.5 if rw_avail else 0.0
			else:
				var vel_diff: float = desired_vel - telemetry.angular_vel_deg_s
				telemetry.angular_vel_deg_s = move_toward(
					telemetry.angular_vel_deg_s + ext_accel * dt,
					desired_vel,
					max_accel * dt
				)
				_acs_active_draw_w = 7.0 if rw_avail else 0.0
				if rcs_avail and (absf(err) > 2.0 or absf(vel_diff) > 4.0):
					_consume_rcs_propellant(dt * 0.10)
					telemetry.rcs_active_jets = int(signf(vel_diff)) if absf(vel_diff) > 1.0 else 2
				elif rw_avail:
					var sat_rate: float = 0.072 if telemetry.in_solar_storm else 0.010
					telemetry.rw_saturation = clampf(telemetry.rw_saturation + sat_rate * dt, 0.0, 1.0)
	else:
		telemetry.angular_vel_deg_s = clampf(telemetry.angular_vel_deg_s + ext_accel * dt, -85.0, 85.0)

	telemetry.attitude_deg = RocketMath.normalize_angle_deg(telemetry.attitude_deg + telemetry.angular_vel_deg_s * dt)
	_update_alignment_factors()


func _consume_rcs_propellant(kg: float) -> void:
	if kg <= 0.0 or telemetry.propellant_remaining_kg <= 0.0:
		return
	telemetry.propellant_remaining_kg = maxf(telemetry.propellant_remaining_kg - kg, 0.0)
	telemetry.delta_v_remaining = RocketMath.calculate_delta_v_from_masses(
		_effective_isp_s,
		telemetry.dry_mass_kg + telemetry.propellant_remaining_kg,
		telemetry.dry_mass_kg
	)


func _update_alignment_factors() -> void:
	telemetry.is_tumbling = absf(telemetry.angular_vel_deg_s) >= 20.0
	var target_err: float = absf(RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, telemetry.target_attitude_deg))
	telemetry.attitude_aligned = (not telemetry.is_tumbling) and (
		telemetry.attitude_mode == FlightTelemetry.AttitudeMode.HOLD
		or target_err <= 8.0
	)

	var sol_err: float = absf(RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, ANGLE_SOLAR))
	if telemetry.is_tumbling:
		telemetry.solar_pointing_factor = 0.25
	else:
		telemetry.solar_pointing_factor = lerpf(1.0, 0.68, clampf(sol_err / 180.0, 0.0, 1.0))

	var earth_err: float = absf(RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, ANGLE_EARTH))
	if telemetry.is_tumbling:
		telemetry.comms_link_factor = 0.0
	elif earth_err <= 30.0:
		telemetry.comms_link_factor = 1.0
	else:
		telemetry.comms_link_factor = 0.32

	var obj_err: float = absf(RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, ANGLE_TARGET))
	telemetry.target_pointing_ok = (not telemetry.is_tumbling) and (obj_err <= 35.0)


func _step_trajectory_and_gravity_assist(dt: float) -> void:
	if telemetry.in_tcm_window:
		telemetry.trajectory_error_km += mission.drift_rate_km_s * dt
	elif telemetry.in_solar_storm:
		telemetry.trajectory_error_km += mission.drift_rate_km_s * 0.65 * dt

	if mission.has_gravity_assist and not telemetry.gravity_assist_completed:
		var ga_trigger: float = (mission.gravity_assist_window.x + mission.gravity_assist_window.y) * 0.5
		if telemetry.progress_norm >= ga_trigger:
			telemetry.gravity_assist_completed = true
			var bonus: float = 0.0
			if telemetry.trajectory_error_km <= 24.0:
				bonus = mission.gravity_assist_dv_bonus
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: ¡Honda gravitatoria óptima en %s! +%.0f m/s gratis.",
					"T+%02ds: Optimal gravity assist at %s! +%.0f m/s free."
				) % [
					int(telemetry.elapsed_s),
					mission.gravity_assist_body,
					bonus,
				])
			elif telemetry.trajectory_error_km <= mission.max_trajectory_error_km:
				bonus = roundf(mission.gravity_assist_dv_bonus * 0.55)
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: Honda gravitatoria parcial en %s (+%.0f m/s; desvío %.0f km).",
					"T+%02ds: Partial gravity assist at %s (+%.0f m/s; error %.0f km)."
				) % [
					int(telemetry.elapsed_s),
					mission.gravity_assist_body,
					bonus,
					telemetry.trajectory_error_km,
				])
			else:
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: Honda gravitatoria perdida en %s por desvío excesivo (%.0f km).",
					"T+%02ds: Gravity assist missed at %s due to high error (%.0f km)."
				) % [
					int(telemetry.elapsed_s),
					mission.gravity_assist_body,
					telemetry.trajectory_error_km,
				])
			telemetry.gravity_assist_dv_gained = bonus
			telemetry.insertion_dv_target = maxf(
				250.0,
				mission.insertion_dv_required - telemetry.launch_injection_dv - bonus
			)
			telemetry.effective_delta_v = (
				telemetry.launch_injection_dv
				+ telemetry.delta_v_burned
				+ telemetry.gravity_assist_dv_gained
			)


func _step_propulsion(dt: float) -> void:
	telemetry.wrong_burn_direction = false
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
	telemetry.effective_delta_v = (
		telemetry.launch_injection_dv
		+ telemetry.delta_v_burned
		+ telemetry.gravity_assist_dv_gained
	)
	telemetry.delta_v_remaining = RocketMath.calculate_delta_v_from_masses(
		_effective_isp_s,
		telemetry.dry_mass_kg + telemetry.propellant_remaining_kg,
		telemetry.dry_mass_kg
	)

	var rad: float = deg_to_rad(telemetry.attitude_deg)
	var prograde_cos: float = cos(rad)
	var retrograde_cos: float = -prograde_cos

	if telemetry.in_insertion_window and mission.requires_orbital_insertion:
		if retrograde_cos >= 0.70 and not telemetry.is_tumbling:
			telemetry.insertion_dv_burned += step_dv * retrograde_cos
			telemetry.trajectory_error_km = maxf(0.0, telemetry.trajectory_error_km - step_dv * 0.12)
		else:
			telemetry.wrong_burn_direction = true
			if retrograde_cos < -0.15:
				telemetry.insertion_dv_burned = maxf(0.0, telemetry.insertion_dv_burned + step_dv * retrograde_cos * 0.5)
			telemetry.trajectory_error_km += step_dv * 0.10
			if not _logged_wrong_burn:
				_logged_wrong_burn = true
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: ¡ALERTA CRÍTICA! Quemado sin girar 180° Retrógrado.",
					"T+%02ds: CRITICAL ALERT! Burning without 180° Retrograde turn."
				) % int(telemetry.elapsed_s))
	else:
		if prograde_cos >= 0.70 and not telemetry.is_tumbling:
			var prev_err: float = telemetry.trajectory_error_km
			telemetry.trajectory_error_km = maxf(0.0, telemetry.trajectory_error_km - step_dv * 0.24)
			if prev_err > 5.0 and telemetry.trajectory_error_km <= 5.0:
				telemetry.tcm_burns_count += 1
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: Corrección TCM #%d completada (trayectoria centrada).",
					"T+%02ds: TCM burn #%d complete (trajectory centered)."
				) % [
					int(telemetry.elapsed_s),
					telemetry.tcm_burns_count,
				])
		else:
			telemetry.wrong_burn_direction = true
			telemetry.trajectory_error_km += step_dv * 0.14
			if not _logged_wrong_burn:
				_logged_wrong_burn = true
				telemetry.event_log.append(Loc.pick(
					"T+%02ds: ¡Empuje desalineado! Apunta PROGRADO (0°) para TCM.",
					"T+%02ds: Misaligned thrust! Aim PROGRADE (0°) for TCM."
				) % int(telemetry.elapsed_s))

	if telemetry.propellant_remaining_kg <= 0.0:
		telemetry.engine_firing = false
		telemetry.event_log.append(Loc.pick("T+%02ds: Tanques de propelente agotados.", "T+%02ds: Propellant tanks depleted.") % int(telemetry.elapsed_s))


func _recompute_power_snapshot() -> void:
	telemetry.solar_gen_w = RocketMath.calculate_solar_generation_w(
		design,
		mission.distance_au,
		telemetry.panels_deployed,
		telemetry.in_shadow,
		telemetry.solar_pointing_factor
	)
	telemetry.power_draw_w = RocketMath.calculate_power_draw_w(
		design,
		telemetry.master_bus_on,
		telemetry.comms_on,
		telemetry.science_bus_on,
		telemetry.in_solar_storm,
		_acs_active_draw_w,
		telemetry.throttle if telemetry.engine_firing else 0.0
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


func _update_downlink_rate() -> void:
	if not telemetry.master_bus_on or not telemetry.comms_on:
		telemetry.downlink_kbps = 0.0
		return
	telemetry.downlink_kbps = (
		RocketMath.calculate_effective_comms_kbps(design, mission.earth_distance_au)
		* telemetry.comms_link_factor
	)


func _step_transmissions(dt: float) -> void:
	_update_downlink_rate()
	if not telemetry.master_bus_on or not telemetry.comms_on:
		return

	var pending_count: int = 0
	for part in _instrument_parts:
		var q: float = float(telemetry.instruments_captured.get(part.id, 0.0))
		if q > 0.0 and not bool(telemetry.instruments_transmitted.get(part.id, false)):
			pending_count += 1

	var shared_mb_per_s: float = RocketMath.calculate_game_downlink_mb_s(telemetry.downlink_kbps) / float(maxi(pending_count, 1))
	var total_score: int = 0

	for part in _instrument_parts:
		var quality: float = float(telemetry.instruments_captured.get(part.id, 0.0))
		if quality <= 0.0:
			continue
		if telemetry.instruments_transmitted.get(part.id, false):
			total_score += int(round(float(part.science_value) * quality))
			continue

		if shared_mb_per_s <= 0.0:
			continue

		var data_mb: float = maxf(part.data_volume_mb, 1.0)
		var prog: float = float(_transmission_progress.get(part.id, 0.0)) + (dt * shared_mb_per_s) / data_mb
		if prog >= 1.0:
			_transmission_progress[part.id] = 1.0
			telemetry.instruments_transmitted[part.id] = true
			var pts: int = int(round(float(part.science_value) * quality))
			total_score += pts
			var ant_tag: String = Loc.pick("HGA Tierra", "Earth HGA") if telemetry.comms_link_factor >= 0.9 else "Omni"
			telemetry.event_log.append(Loc.pick(
				"T+%02ds: %s descargado (%.0f MB vía %s @ %.1f kbps, +%d pts).",
				"T+%02ds: %s downloaded (%.0f MB via %s @ %.1f kbps, +%d pts)."
			) % [
				int(telemetry.elapsed_s),
				part.display_name,
				part.data_volume_mb,
				ant_tag,
				telemetry.downlink_kbps,
				pts,
			])
		else:
			_transmission_progress[part.id] = prog

	telemetry.science_score = total_score


func _update_system_state_and_alerts() -> void:
	telemetry.active_alerts.clear()
	var bat_ratio: float = (telemetry.battery_wh / telemetry.battery_max_wh) if telemetry.battery_max_wh > 0.0 else 0.0
	var min_ins_dv: float = telemetry.insertion_dv_target - mission.delta_v_tolerance
	var retro_err: float = absf(RocketMath.shortest_angle_diff_deg(telemetry.attitude_deg, ANGLE_RETROGRADE))

	var is_critical: bool = false
	var is_caution: bool = false
	var stable_sentinel: String = "STABLE_SENTINEL"
	var reason: String = stable_sentinel

	if not telemetry.master_bus_on:
		is_critical = true
		reason = Loc.pick("BUS MAESTRO APAGADO", "MASTER BUS OFF")
		telemetry.active_alerts.append(Loc.pick("BUS MAESTRO OFF", "MASTER BUS OFF"))
	if bat_ratio < 0.25:
		is_critical = true
		reason = Loc.pick("BATERÍA CRÍTICA", "CRITICAL BATTERY")
		telemetry.active_alerts.append(Loc.pick("BATERÍA CRÍTICA", "CRITICAL BATTERY"))
	elif bat_ratio < 0.45:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("BATERÍA MEDIA", "MEDIUM BATTERY"))

	if telemetry.is_tumbling and not telemetry.is_controlled_slew():
		is_critical = true
		reason = Loc.pick("GIRO DESCONTROLADO", "UNCONTROLLED SPIN")
		telemetry.active_alerts.append(Loc.pick("¡GIRO CRÍTICO! ACTIVA RCS + ESTAB", "CRITICAL SPIN! ENABLE RCS + HOLD"))
	elif telemetry.is_controlled_slew():
		is_caution = true
		reason = Loc.pick("ORIENTANDO NAVE", "SLEWING CRAFT")
		telemetry.active_alerts.append(Loc.pick("GIRO DE ACTITUD: ESPERA ALINEACIÓN", "ATTITUDE SLEW: ALIGNING"))
	elif telemetry.rw_saturation >= 0.92 and not telemetry.rcs_enabled:
		is_critical = true
		reason = Loc.pick("RUEDAS SATURADAS", "WHEELS SATURATED")
		telemetry.active_alerts.append(Loc.pick("RW SATURADAS: ACTIVA RCS", "RW SATURATED: ENABLE RCS"))
	elif telemetry.rw_saturation >= 0.65:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("RW %d%% (USA RCS)", "RW %d%% (USE RCS)") % int(round(telemetry.rw_saturation * 100.0)))

	if telemetry.wrong_burn_direction and telemetry.engine_firing:
		is_critical = true
		reason = Loc.pick("EMPUJE MAL ALINEADO", "MISALIGNED THRUST")
		if telemetry.in_insertion_window:
			telemetry.active_alerts.append(Loc.pick("¡FUEGO SIN GIRAR 180° RET!", "BURN WITHOUT 180° RETRO TURN!"))
		else:
			telemetry.active_alerts.append(Loc.pick("¡APUNTA PROGRADO 0° PARA TCM!", "AIM PROGRADE 0° FOR TCM!"))

	if telemetry.trajectory_error_km > mission.max_trajectory_error_km * 0.85:
		is_critical = true
		reason = Loc.pick("DESVÍO ORBITAL CRÍTICO", "CRITICAL ORBIT DRIFT")
		telemetry.active_alerts.append(Loc.pick("DESVÍO CRÍTICO %.0fkm (TCM PRO 0°)", "CRITICAL DRIFT %.0fkm (TCM PRO 0°)") % telemetry.trajectory_error_km)
	elif telemetry.trajectory_error_km > 14.0:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("CORREGIR TCM (%.0fkm)", "FIX TCM (%.0fkm)") % telemetry.trajectory_error_km)

	if telemetry.in_insertion_window and mission.requires_orbital_insertion:
		if telemetry.insertion_dv_burned < min_ins_dv:
			if retro_err > 35.0:
				if telemetry.progress_norm >= 0.84:
					is_critical = true
					reason = Loc.pick("¡GIRAR 180° Y FRENAR!", "TURN 180° & BRAKE!")
				else:
					is_caution = true
				telemetry.active_alerts.append(Loc.pick("¡GIRA 180° RET Y FRENA!", "TURN 180° RETRO & BRAKE!"))
			elif not telemetry.engine_firing and telemetry.progress_norm >= 0.86:
				is_critical = true
				reason = Loc.pick("¡FRENAR AHORA!", "BRAKE NOW!")
				telemetry.active_alerts.append(Loc.pick("¡IGNICIÓN DE FRENADO AHORA!", "BRAKING IGNITION NOW!"))
			else:
				is_caution = true
				telemetry.active_alerts.append(Loc.pick("FRENANDO EN ÓRBITA...", "ORBITAL BRAKING..."))

	if telemetry.progress_norm >= 0.78 and mission.min_science_required > 0 and telemetry.science_score < mission.min_science_required:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("OBJETIVO CIENCIA %d/%d", "SCIENCE GOAL %d/%d") % [telemetry.science_score, mission.min_science_required])

	if telemetry.in_solar_storm:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("TORMENTA SOLAR", "SOLAR STORM"))
	if telemetry.in_shadow:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("ECLIPSE SOLAR", "SOLAR ECLIPSE"))
	if not telemetry.panels_deployed:
		is_caution = true
		telemetry.active_alerts.append(Loc.pick("ABRIR PANELES SOLARES", "DEPLOY SOLAR ARRAYS"))
	if telemetry.in_gravity_assist_window and not telemetry.gravity_assist_completed:
		telemetry.active_alerts.append(Loc.pick("HONDA: %s", "ASSIST: %s") % mission.gravity_assist_body)
	if telemetry.in_flyby_window:
		telemetry.active_alerts.append(Loc.pick("SOBREVUELO (APUNTA OBJ)", "FLYBY (AIM TARGET)"))

	if not telemetry.attitude_aligned and not is_critical:
		is_caution = true
		if reason == stable_sentinel:
			reason = Loc.pick("ROTANDO ACTITUD", "ROTATING ATTITUDE")

	if is_critical:
		telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
		telemetry.system_state_reason = reason
	elif is_caution:
		telemetry.system_state = FlightTelemetry.SystemState.CAUTION
		telemetry.system_state_reason = reason if reason != stable_sentinel else Loc.pick("PRECAUCIÓN", "CAUTION")
	else:
		telemetry.system_state = FlightTelemetry.SystemState.STABLE
		telemetry.system_state_reason = Loc.pick("ESTABLE", "STABLE")


func _evaluate_end_conditions() -> void:
	if telemetry.battery_wh <= 0.0:
		telemetry.status = FlightTelemetry.Status.FAILED_POWER
		telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
		telemetry.engine_firing = false
		telemetry.failure_reason = Loc.pick(
			"Apagón total: las baterías se agotaron durante la misión.",
			"Total blackout: batteries depleted during the mission."
		)
		return

	if telemetry.progress_norm < 1.0:
		return

	telemetry.engine_firing = false

	if telemetry.trajectory_error_km > mission.max_trajectory_error_km:
		telemetry.status = FlightTelemetry.Status.FAILED_MISSED_TARGET
		telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
		telemetry.failure_reason = Loc.pick(
			"Trayectoria desviada (%.0f km > %.0f km máx.): faltaron maniobras TCM en Progrado (0°) y la sonda pasó lejos del objetivo.",
			"Trajectory off course (%.0f km > %.0f km max): Prograde (0°) TCM burns were missed and the probe flew past the target."
		) % [
			telemetry.trajectory_error_km,
			mission.max_trajectory_error_km,
		]
		return

	if mission.requires_orbital_insertion:
		var min_ins: float = telemetry.insertion_dv_target - mission.delta_v_tolerance
		var max_ins: float = telemetry.insertion_dv_target + mission.delta_v_tolerance * 1.8

		if telemetry.insertion_dv_burned < min_ins:
			telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
			if telemetry.propellant_remaining_kg <= 0.05:
				telemetry.status = FlightTelemetry.Status.FAILED_FUEL
				telemetry.failure_reason = Loc.pick(
					"Propelente agotado durante la inserción orbital: frenado a 180° alcanzado %.0f / %.0f m/s.",
					"Propellant depleted during orbital insertion: 180° braking reached %.0f / %.0f m/s."
				) % [
					telemetry.insertion_dv_burned,
					telemetry.insertion_dv_target,
				]
			else:
				telemetry.status = FlightTelemetry.Status.FAILED_MISSED_TARGET
				telemetry.failure_reason = Loc.pick(
					"Fallo de Inserción Orbital (%.0f / %.0f m/s en Retrógrado 180°): la sonda no frenó en el momento exacto, siguió de largo y se perdió en el espacio.",
					"Orbital Insertion Failure (%.0f / %.0f m/s Retrograde 180°): probe failed to brake in window, overshot and drifted into deep space."
				) % [
					telemetry.insertion_dv_burned,
					telemetry.insertion_dv_target,
				]
			return

		if telemetry.insertion_dv_burned > max_ins:
			telemetry.status = FlightTelemetry.Status.FAILED_MISSED_TARGET
			telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
			telemetry.failure_reason = Loc.pick(
				"Sobrefrenado en inserción (%.0f m/s): la órbita decayó dentro de la atmósfera planetaria.",
				"Over-braked during insertion (%.0f m/s): orbit decayed into the planetary atmosphere."
			) % telemetry.insertion_dv_burned
			return

	# Verify Mission Scientific & Communications Downlink Objectives
	var missing_reqs: Array[String] = []
	for req_id in mission.required_instruments:
		if not bool(telemetry.instruments_transmitted.get(req_id, false)):
			var spec: PartSpec = design.get_part_spec(req_id)
			missing_reqs.append(spec.display_name if spec != null else req_id)

	if not missing_reqs.is_empty():
		telemetry.status = FlightTelemetry.Status.FAILED_OBJECTIVES
		telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
		telemetry.failure_reason = Loc.pick(
			"Órbita alcanzada, pero objetivos de misión incumplidos: no se capturó/transmitió a Tierra [%s].",
			"Orbit reached, but mission objectives failed: not captured/transmitted to Earth [%s]."
		) % ", ".join(missing_reqs)
		return

	if mission.min_science_required > 0 and telemetry.science_score < mission.min_science_required:
		telemetry.status = FlightTelemetry.Status.FAILED_OBJECTIVES
		telemetry.system_state = FlightTelemetry.SystemState.CRITICAL
		telemetry.failure_reason = Loc.pick(
			"Retorno científico transmitido insuficiente (%d / %d pts mín.): mide en ventana de sobrevuelo apuntando OBJETIVO (-35°) y descarga apuntando TIERRA (+90°).",
			"Insufficient transmitted science return (%d / %d min pts): measure in flyby window aiming TARGET (-35°) and downlink aiming EARTH (+90°)."
		) % [
			telemetry.science_score,
			mission.min_science_required,
		]
		return

	telemetry.status = FlightTelemetry.Status.VICTORY
	telemetry.system_state = FlightTelemetry.SystemState.STABLE
