class_name MissionAutopilot
extends RefCounted
## Operates the player's existing design through public flight commands.
## Never grants resources, changes telemetry, or bypasses terminal conditions.

var _last_stage: String = ""


func update(sim, dt: float) -> void:
	var t: FlightTelemetry = sim.telemetry
	var mission: MissionSpec = sim.mission
	sim.set_master_bus(true)
	sim.deploy_panels()
	sim.set_rcs_enabled(true)
	if not t.safety_cover_open:
		sim.toggle_safety_cover()

	var needs_capture: bool = false
	var needs_downlink: bool = false
	for part in sim.design.get_parts_by_category(PartSpec.Category.INSTRUMENT):
		if float(t.instruments_captured.get(part.id, 0.0)) < 0.99:
			needs_capture = true
		if float(t.instruments_captured.get(part.id, 0.0)) > 0.0 and not bool(t.instruments_transmitted.get(part.id, false)):
			needs_downlink = true

	# Science only needs power during capture; radio only needs power to download.
	sim.set_science_bus(false)
	sim.set_comms_bus(needs_downlink)
	sim.set_throttle(0.0)
	var progress: float = (t.elapsed_s + dt) / mission.transit_duration_s
	if mission.requires_orbital_insertion and progress >= mission.insertion_window_start_norm:
		if t.insertion_dv_burned < t.insertion_dv_target:
			_stage(
				sim,
				Loc.pick("INSERCIÓN", "INSERTION"),
				Loc.pick("Frenar en retrógrado permite la captura orbital.", "Retrograde braking enables orbital capture.")
			)
			_burn_toward(sim, FlightTelemetry.AttitudeMode.RETROGRADE, 180.0, t.insertion_dv_target - t.insertion_dv_burned, dt)
			return
	elif t.trajectory_error_km > 12.0:
		_stage(
			sim,
			Loc.pick("CORRECCIÓN TCM", "TCM CORRECTION"),
			Loc.pick("Un pulso en progrado reduce el desvío y gasta propelente.", "A prograde burn cuts course error and uses propellant.")
		)
		_burn_toward(sim, FlightTelemetry.AttitudeMode.PROGRADE, 0.0, (t.trajectory_error_km - 3.0) / 0.24, dt)
		return
	elif progress >= mission.flyby_window_start_norm and progress <= mission.flyby_window_end_norm and needs_capture:
		_stage(
			sim,
			Loc.pick("CAPTURA CIENTÍFICA", "SCIENCE CAPTURE"),
			Loc.pick("Apuntar al objetivo durante el sobrevuelo mejora la calidad.", "Pointing at target during flyby boosts data quality.")
		)
		sim.set_attitude_mode(FlightTelemetry.AttitudeMode.TARGET)
		if t.in_flyby_window and t.target_pointing_ok:
			sim.set_science_bus(true)
			for part in sim.design.get_parts_by_category(PartSpec.Category.INSTRUMENT):
				if float(t.instruments_captured.get(part.id, 0.0)) < 0.99:
					sim.activate_instrument(part.id)
		return

	if needs_downlink:
		_stage(
			sim,
			Loc.pick("DESCARGA A TIERRA", "EARTH DOWNLINK"),
			Loc.pick("Los datos solo suman ciencia al terminar su transmisión.", "Data only counts as science once transmission finishes.")
		)
		sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
	else:
		_stage(
			sim,
			Loc.pick("CRUCERO SOLAR", "SOLAR CRUISE"),
			Loc.pick("Motor apagado y paneles hacia el Sol conservan recursos.", "Engine off and solar-pointing save power and fuel.")
		)
		sim.set_attitude_mode(FlightTelemetry.AttitudeMode.SOLAR)


func _burn_toward(sim, mode: FlightTelemetry.AttitudeMode, angle: float, remaining_dv: float, dt: float) -> void:
	sim.set_attitude_mode(mode)
	var t: FlightTelemetry = sim.telemetry
	var error: float = absf(RocketMath.shortest_angle_diff_deg(t.attitude_deg, angle))
	if error > 8.0 or t.is_tumbling:
		return
	# Limit the pulse by current mass and thrust so slow frames do not overburn.
	var thrust: float = RocketMath.calculate_total_thrust_n(sim.design)
	var mass: float = t.dry_mass_kg + t.propellant_remaining_kg
	var full_step_dv: float = thrust / maxf(mass, 1.0) * dt * sim.BURN_TIME_SCALE
	var throttle: float = clampf(remaining_dv / maxf(full_step_dv, 0.0001) * 0.90, 0.01, 0.75)
	# Ignition has a minimum starting throttle; set the desired pulse afterwards.
	if not t.engine_firing:
		sim.trigger_ignition()
	sim.set_throttle(throttle)


func _stage(sim, stage: String, explanation: String) -> void:
	sim.automatic_action = stage + ": " + explanation
	if stage != _last_stage:
		_last_stage = stage
		sim.telemetry.event_log.append("T+%02ds AUTO %s: %s" % [int(sim.telemetry.elapsed_s), stage, explanation])
