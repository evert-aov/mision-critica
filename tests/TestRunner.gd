extends SceneTree
## Headless unit & simulation test suite for Misión Crítica.
## Covers all 9 competing spaceflight engineering demands.
## Run with: godot --headless --script res://tests/TestRunner.gd

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== RUNNING MISIÓN CRÍTICA TEST SUITE ===")
	_test_tsiolkovski_math()
	_test_solar_comms_inverse_square_and_power()
	_test_launch_vehicles_mass_fairing_budget_and_objectives()
	_test_all_three_missions_baseline_viability()
	_test_flight_simulator_propulsion_and_safety()
	_test_attitude_control_wheels_rcs_and_pointing()
	_test_trajectory_tcm_gravity_assist_and_180_insertion()
	_test_flight_simulator_power_and_comms_downlink()
	_test_missed_insertion_and_failed_objectives()
	_test_educational_units_distances_and_engine_power()
	_test_automatic_missions_and_resource_limits()
	_test_scene_projection_outcomes_and_local_frame()
	_test_hd_layout_and_environment_motion()
	_test_continuous_transit_progress()
	_test_localization_and_pixel_typography()
	_test_nasa_framework()
	_test_internal_cabin_archetypes()
	_test_profiles_and_nasa_badges()

	print("=== RESULTS: %d PASSED, %d FAILED ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert_true(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)


func _assert_approx(actual: float, expected: float, tol: float, label: String) -> void:
	if absf(actual - expected) <= tol:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] %s (got %.4f, expected %.4f ± %.4f)" % [label, actual, expected, tol])


func _get_lv_map() -> Dictionary:
	var out: Dictionary = {}
	for lv in LaunchVehicleCatalog.create_all():
		out[lv.id] = lv
	return out


func _test_tsiolkovski_math() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var design := ProbeDesign.new(parts, lvs["lv_light"])
	design.add_part("eng_hydrazine") # 22kg, 2600N, Isp 295s
	design.add_part("tank_small")    # 18kg dry, 140kg prop

	var dry := RocketMath.calculate_dry_mass_kg(design)
	var prop := RocketMath.calculate_propellant_mass_kg(design)
	var wet := RocketMath.calculate_wet_mass_kg(design)
	_assert_approx(dry, 160.0, 0.01, "Dry mass = 120 + 22 + 18")
	_assert_approx(prop, 140.0, 0.01, "Propellant mass = 140")
	_assert_approx(wet, 300.0, 0.01, "Wet mass = 300")

	var expected_dv: float = 295.0 * 9.80665 * log(300.0 / 160.0)
	_assert_approx(RocketMath.calculate_delta_v(design), expected_dv, 0.05, "Tsiolkovski Δv exact")

	var expected_twr: float = 2600.0 / (300.0 * 9.80665)
	_assert_approx(RocketMath.calculate_twr(design), expected_twr, 0.001, "TWR exact")

	design.add_part("eng_ion") # 3000N, Isp 520s
	var eff_isp := RocketMath.calculate_effective_isp_s(design)
	var expected_isp := (2600.0 + 3000.0) / ((2600.0 / 295.0) + (3000.0 / 520.0))
	_assert_approx(eff_isp, expected_isp, 0.05, "Multi-engine thrust-weighted Isp")


func _test_solar_comms_inverse_square_and_power() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var design := ProbeDesign.new(parts, lvs["lv_medium"])
	design.add_part("solar_wing") # 110 W at 1 AU
	design.add_part("bat_liion")  # 120 Wh
	design.add_part("comm_xband") # +42 kbps, 8 W draw
	design.add_part("inst_cam")   # 14 W draw, 32 MB

	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, true, false, 1.0), 110.0, 0.01, "Solar @ 1.0 AU optimal pointing")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.52, true, false, 1.0), 110.0 / (1.52 * 1.52), 0.05, "Solar @ 1.52 AU (Mars)")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, false, false, 1.0), 0.0, 0.001, "Solar retracted = 0 W")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, true, true, 1.0), 0.0, 0.001, "Solar in shadow = 0 W")
	_assert_approx(RocketMath.calculate_battery_capacity_wh(design), 160.0, 0.01, "Battery = 40 + 120 Wh")
	_assert_approx(RocketMath.calculate_power_draw_w(design, true, true, true, false), 12.0 + 10.0 + 8.0 + 14.0, 0.01, "Full draw with X-band comms = 44 W")

	# Deep-space Comms bandwidth & 1/d² path loss
	_assert_approx(RocketMath.calculate_raw_comms_kbps(design), 18.0 + 42.0, 0.01, "Raw comms bandwidth = 60 kbps with X-band")
	_assert_approx(RocketMath.calculate_effective_comms_kbps(design, 1.52), 60.0 / (1.52 * 1.52), 0.05, "Comms path loss 1/d² at Mars 1.52 AU")


func _test_launch_vehicles_mass_fairing_budget_and_objectives() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var missions := MissionCatalog.create_all()
	var leo := missions[0]

	# 1. Empty probe cannot launch
	var ev_empty := RocketMath.evaluate_design(ProbeDesign.new(parts, lvs["lv_light"]), leo)
	_assert_true(not ev_empty["valid_for_launch"], "Empty probe cannot launch")

	# 2. Missing launch vehicle blocks launch
	var no_lv := ProbeDesign.new(parts, null)
	no_lv.add_part("eng_hydrazine")
	no_lv.add_part("tank_small")
	no_lv.add_part("inst_cam")
	_assert_true(not RocketMath.evaluate_design(no_lv, leo)["valid_for_launch"], "Missing launch vehicle blocks launch")

	# 3. Payload mass exceeding Vega-C (420 kg) blocks launch
	var heavy_on_light := ProbeDesign.new(parts, lvs["lv_light"])
	heavy_on_light.add_part("eng_hydrazine")
	heavy_on_light.add_part("tank_medium") # 320 prop -> wet 497 kg > 420 kg
	heavy_on_light.add_part("inst_cam")
	var ev_heavy := RocketMath.evaluate_design(heavy_on_light, leo)
	_assert_true(not ev_heavy["valid_for_launch"], "Wet mass > Vega-C 420kg max payload blocks launch")

	# 4. Fairing volume exceeding Vega-C (6 modules max) blocks launch
	var packed := ProbeDesign.new(parts, lvs["lv_light"])
	packed.add_part("eng_hydrazine")
	packed.add_part("tank_small")
	for _i in range(4):
		packed.add_part("solar_compact")
	packed.add_part("inst_cam") # 7 modules > 6 max fairing slots
	_assert_true(not RocketMath.evaluate_design(packed, leo)["valid_for_launch"], "Module count > Vega-C fairing capacity blocks launch")

	# 5. Missing mandatory objective instrument blocks launch
	var no_cam := ProbeDesign.new(parts, lvs["lv_light"])
	no_cam.add_part("eng_hydrazine")
	no_cam.add_part("tank_small")
	no_cam.add_part("solar_compact")
	_assert_true(not RocketMath.evaluate_design(no_cam, leo)["valid_for_launch"], "Missing required inst_cam blocks LEO launch")


func _test_all_three_missions_baseline_viability() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var missions := MissionCatalog.create_all()
	_assert_true(parts.size() == 15, "Catalog defines 15 spacecraft parts")
	_assert_true(lvs.size() == 3, "Catalog defines 3 Launch Vehicles")
	_assert_true(missions.size() == 3, "Exactly 3 progressive missions defined")

	var baselines := {
		"leo_tutorial": ["eng_hydrazine", "tank_small", "solar_compact", "bat_liion", "inst_cam"],
		"lunar_flyby": ["eng_biprop", "tank_medium", "tank_small", "solar_wing", "bat_liion", "comm_xband", "inst_cam", "inst_spec"],
		"mars_orbit": ["eng_ion", "tank_large", "solar_wing", "solar_wing", "bat_liion", "comm_xband", "inst_spec", "inst_radar"],
	}
	for m in missions:
		var lv: LaunchVehicleSpec = lvs[m.recommended_lv_id]
		var design := ProbeDesign.new(parts, lv)
		for pid in baselines[m.id]:
			_assert_true(design.add_part(pid), "Add baseline part %s for %s" % [pid, m.id])
		var ev := RocketMath.evaluate_design(design, m)
		_assert_true(ev["valid_for_launch"], "Baseline certified with 0 errors for %s" % m.id)
		_assert_true(float(ev["total_delta_v"]) >= m.required_delta_v, "Baseline Δv (probe+LV) >= req for %s" % m.id)
		_assert_true(int(ev["budget_remaining"]) >= 0, "Baseline within unified budget for %s" % m.id)
		_assert_true(ev["warnings"].is_empty(), "Baseline passes with 0 engineering warnings for %s" % m.id)


func _test_flight_simulator_propulsion_and_safety() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts, lvs["lv_light"])
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")
	design.add_part("inst_cam")

	var sim := FlightSimulator.new(leo, design)
	_assert_true(not sim.trigger_ignition(), "Cannot ignite while safety cover is closed")

	sim.toggle_safety_cover()
	sim.set_throttle(1.0)
	_assert_true(sim.trigger_ignition(), "Ignites once cover is open")

	for _i in range(25):
		sim.step(0.1)

	_assert_true(sim.telemetry.delta_v_burned > 100.0, "Delta-v burned increases during firing")
	_assert_approx(
		sim.telemetry.delta_v_burned + sim.telemetry.delta_v_remaining,
		sim.telemetry.delta_v_initial,
		1.0,
		"Delta-v conservation (burned + remaining == initial)"
	)


func _test_attitude_control_wheels_rcs_and_pointing() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var mars := MissionCatalog.create_all()[2]
	var design := ProbeDesign.new(parts, lvs["lv_heavy"])
	design.add_part("eng_ion")
	design.add_part("tank_large")
	design.add_part("solar_wing")
	design.add_part("bat_liion")
	design.add_part("inst_spec")

	var sim := FlightSimulator.new(mars, design)
	sim.deploy_panels()

	var prop_before := sim.telemetry.propellant_remaining_kg
	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.SOLAR)
	for _i in range(5):
		sim.step(0.1)
	_assert_true(sim.telemetry.is_controlled_slew(), "Commanded solar slew is distinguished from uncontrolled spin")
	_assert_true(sim.telemetry.system_state == FlightTelemetry.SystemState.CAUTION, "A normal commanded turn shows caution rather than a critical control failure")
	for _i in range(45):
		sim.step(0.1)
	_assert_approx(sim.telemetry.attitude_deg, -90.0, 2.0, "Reaction wheels slew probe to SOLAR (-90°)")
	_assert_approx(sim.telemetry.propellant_remaining_kg, prop_before, 0.001, "Reaction wheels consume 0 kg propellant")
	_assert_approx(sim.telemetry.solar_pointing_factor, 1.0, 0.02, "Solar pointing factor = 100% at -90°")

	sim.set_rcs_enabled(true)
	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
	for _i in range(35):
		sim.step(0.1)
	_assert_approx(sim.telemetry.attitude_deg, 90.0, 2.0, "RCS + RW slew probe 180° to EARTH (+90°)")
	_assert_approx(sim.telemetry.comms_link_factor, 1.0, 0.01, "High-Gain Antenna locks 100% on Earth")

	sim.nudge_attitude(1.0)
	sim.nudge_attitude(1.0)
	sim.step(0.05)
	_assert_true(sim.telemetry.is_tumbling, "High angular velocity triggers tumbling")
	_assert_true(sim.telemetry.system_state == FlightTelemetry.SystemState.CRITICAL, "Tumbling sets SystemState.CRITICAL")

	sim.telemetry.rw_saturation = 0.95
	sim.stabilize_attitude()
	for _i in range(30):
		sim.step(0.1)
	_assert_true(not sim.telemetry.is_tumbling and absf(sim.telemetry.angular_vel_deg_s) < 1.0, "SAS + RCS damps tumbling back to 0°/s")
	_assert_true(sim.telemetry.rw_saturation < 0.20, "RCS desaturates Reaction Wheels")
	sim.point_attitude(405.0)
	_assert_approx(sim.telemetry.target_attitude_deg, 45.0, 0.001, "Free pointing normalizes mouse-directed angles")
	for _i in range(50):
		sim.step(0.1)
	_assert_approx(sim.telemetry.attitude_deg, 45.0, 2.0, "Free pointing uses the ordinary attitude actuators to reach its target")


func _test_trajectory_tcm_gravity_assist_and_180_insertion() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var mars := MissionCatalog.create_all()[2]
	var design := ProbeDesign.new(parts, lvs["lv_heavy"]) # +650 m/s upper-stage injection
	design.add_part("eng_ion")
	design.add_part("tank_large")
	design.add_part("solar_wing")
	design.add_part("solar_wing")
	design.add_part("bat_liion")
	design.add_part("comm_xband")
	design.add_part("inst_spec")
	design.add_part("inst_radar")

	var sim := FlightSimulator.new(mars, design)
	sim.deploy_panels()
	sim.toggle_safety_cover()

	_assert_approx(sim.telemetry.launch_injection_dv, 650.0, 0.1, "Vulcan-Centaur grants +650 m/s upper-stage injection")

	# 1. Trim TCM error in PROGRADE (0°)
	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.PROGRADE)
	sim.set_throttle(0.8)
	sim.trigger_ignition()
	for _i in range(25):
		sim.step(0.1)
		if sim.telemetry.trajectory_error_km <= 2.0:
			sim.set_throttle(0.0)
			break
	_assert_true(sim.telemetry.trajectory_error_km <= 3.0, "TCM burn in PROGRADE (0°) trims trajectory error near 0 km")
	_assert_true(not sim.telemetry.engine_firing, "Main engine shut off for inertial coasting")

	sim.step(0.1)
	_assert_true(sim.telemetry.system_state == FlightTelemetry.SystemState.STABLE, "Probe reports SystemState.STABLE during clean cruise")

	# 2. Coast with engine OFF through Venus Gravity Assist
	var prop_coast := sim.telemetry.propellant_remaining_kg
	while sim.telemetry.progress_norm < 0.50:
		sim.step(0.2)
	_assert_true(sim.telemetry.gravity_assist_completed, "Venus Gravity Assist completed")
	_assert_approx(sim.telemetry.gravity_assist_dv_gained, 650.0, 1.0, "Venus slingshot grants +650 m/s free Δv")
	_assert_approx(sim.telemetry.propellant_remaining_kg, prop_coast, 0.001, "Gravity assist spends 0 kg propellant")

	# 3. Complete Mars mission with HGA downlink + 180° Retrograde Insertion
	sim.set_rcs_enabled(true)
	var science_done := false
	while sim.telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
		if not sim.telemetry.in_insertion_window:
			if sim.telemetry.trajectory_error_km > 12.0:
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.PROGRADE)
				if sim.telemetry.attitude_aligned:
					sim.set_throttle(0.7)
					if not sim.telemetry.engine_firing:
						sim.trigger_ignition()
			else:
				if sim.telemetry.engine_firing:
					sim.set_throttle(0.0)
				if sim.telemetry.in_flyby_window and not science_done:
					sim.set_attitude_mode(FlightTelemetry.AttitudeMode.TARGET)
					if sim.telemetry.target_pointing_ok:
						sim.activate_instrument("inst_spec")
						sim.activate_instrument("inst_radar")
						science_done = true
				elif science_done:
					sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
		else:
			sim.set_attitude_mode(FlightTelemetry.AttitudeMode.RETROGRADE)
			var retro_err := absf(RocketMath.shortest_angle_diff_deg(sim.telemetry.attitude_deg, 180.0))
			if retro_err < 15.0 and sim.telemetry.insertion_dv_burned < sim.telemetry.insertion_dv_target:
				sim.set_throttle(1.0)
				if not sim.telemetry.engine_firing:
					sim.trigger_ignition()
			elif sim.telemetry.insertion_dv_burned >= sim.telemetry.insertion_dv_target:
				sim.set_throttle(0.0)
		sim.step(0.1)

	_assert_true(sim.telemetry.status == FlightTelemetry.Status.VICTORY, "Mars mission completes with VICTORY via LV + TCM + Venus GA + HGA + 180° MOI")
	_assert_true(sim.telemetry.science_score == 600, "Mars optimal science captured & downloaded via X-band HGA (+600 pts)")


func _test_flight_simulator_power_and_comms_downlink() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts, lvs["lv_light"])
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")
	design.add_part("bat_liion") # Reserve needed during the long pointing/capture sequence.
	design.add_part("inst_cam") # 32 MB

	var sim := FlightSimulator.new(leo, design)
	_assert_true(not sim.telemetry.panels_deployed, "Panels start stowed")
	_assert_true(sim.deploy_panels(), "Panels deploy on command")

	var early_res := sim.activate_instrument("inst_cam")
	_assert_true(early_res["ok"] and not early_res["optimal"], "Early capture is non-optimal (35%)")

	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
	for _i in range(300):
		sim.step(0.1)
	_assert_true(sim.telemetry.in_flyby_window, "Entered flyby window")
	var off_axis_res := sim.activate_instrument("inst_cam")
	_assert_approx(float(off_axis_res["quality"]), 0.60, 0.01, "Off-axis flyby capture yields 60%")

	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.TARGET)
	for _i in range(45):
		sim.step(0.1)
	_assert_true(sim.telemetry.target_pointing_ok, "Pointed at TARGET (-35°)")
	var opt_res := sim.activate_instrument("inst_cam")
	_assert_true(opt_res["ok"] and opt_res["optimal"], "Target-pointed flyby capture upgrades to 100%")

	sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
	for _i in range(110):
		sim.step(0.1)
		if bool(sim.telemetry.instruments_transmitted.get("inst_cam", false)):
			break
	_assert_approx(float(sim.telemetry.science_score), 150.0, 0.1, "Optimal 32MB packet downloaded via HGA (+150 pts)")

	# Test blackout failure when panels remain stowed
	var blackout_design := design.clone()
	blackout_design.remove_part("bat_liion")
	var sim_fail := FlightSimulator.new(leo, blackout_design)
	for _i in range(700):
		sim_fail.step(0.1)
		if sim_fail.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
			break
	_assert_true(sim_fail.telemetry.status == FlightTelemetry.Status.FAILED_POWER, "Stowed panels eventually trigger FAILED_POWER")


func _test_missed_insertion_and_failed_objectives() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts, lvs["lv_light"])
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")
	design.add_part("bat_liion")
	design.add_part("inst_cam")

	# Case A: Fail to rotate 180° and brake -> overshoot
	var sim_miss := FlightSimulator.new(leo, design)
	sim_miss.deploy_panels()
	sim_miss.toggle_safety_cover()
	sim_miss.set_throttle(0.7)
	sim_miss.trigger_ignition()
	for _i in range(15):
		sim_miss.step(0.1)
	sim_miss.set_throttle(0.0)
	while sim_miss.telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
		sim_miss.step(0.2)
	_assert_true(sim_miss.telemetry.status == FlightTelemetry.Status.FAILED_MISSED_TARGET, "Failing to rotate 180° and brake causes probe to overshoot")

	# Case B: Achieve orbit cleanly (TCM + 180° MOI) WITHOUT ever capturing inst_cam -> FAILED_OBJECTIVES!
	var sim_obj := FlightSimulator.new(leo, design)
	sim_obj.deploy_panels()
	sim_obj.toggle_safety_cover()
	sim_obj.set_throttle(0.7)
	sim_obj.trigger_ignition()
	for _i in range(20):
		sim_obj.step(0.1)
		if sim_obj.telemetry.trajectory_error_km <= 2.0:
			sim_obj.set_throttle(0.0)
			break
	while sim_obj.telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
		if sim_obj.telemetry.in_insertion_window:
			sim_obj.set_attitude_mode(FlightTelemetry.AttitudeMode.RETROGRADE)
			var retro_err := absf(RocketMath.shortest_angle_diff_deg(sim_obj.telemetry.attitude_deg, 180.0))
			if retro_err < 15.0 and sim_obj.telemetry.insertion_dv_burned < sim_obj.telemetry.insertion_dv_target:
				sim_obj.set_throttle(0.8)
				if not sim_obj.telemetry.engine_firing:
					sim_obj.trigger_ignition()
			elif sim_obj.telemetry.insertion_dv_burned >= sim_obj.telemetry.insertion_dv_target:
				sim_obj.set_throttle(0.0)
		sim_obj.step(0.1)
	_assert_true(sim_obj.telemetry.status == FlightTelemetry.Status.FAILED_OBJECTIVES, "Completing orbit without transmitting required science triggers FAILED_OBJECTIVES")


func _test_educational_units_distances_and_engine_power() -> void:
	_assert_approx(RocketMath.kbps_to_mb_per_second(8000.0), 1.0, 0.000001, "8000 kbps equals 1 MB/s before game acceleration")
	_assert_approx(32.0 / RocketMath.kbps_to_mb_per_second(18.0), 14222.2222, 0.001, "32 MB at 18 kbps requires 14222 physical seconds")
	_assert_approx(RocketMath.calculate_game_downlink_mb_s(18.0), 20.7, 0.000001, "Explicit data acceleration preserves playable transfer rate")
	var design := ProbeDesign.new(PartCatalog.create_all(), _get_lv_map()["lv_heavy"])
	design.add_part("eng_ion")
	design.add_part("tank_large")
	design.add_part("solar_wing")
	design.add_part("comm_xband")
	_assert_approx(RocketMath.calculate_effective_comms_kbps(design, 0.001), 60.0, 0.0001, "Nearby downlink is capped by transmitter hardware")
	_assert_approx(RocketMath.calculate_effective_comms_kbps(design, 2.0), 15.0, 0.0001, "Doubling Earth range quarters the link")
	var near_sun := MissionSpec.new({"distance_au": 1.0, "earth_distance_au": 2.0})
	var far_sun := MissionSpec.new({"distance_au": 2.0, "earth_distance_au": 2.0})
	var near_eval := RocketMath.evaluate_design(design, near_sun)
	var far_eval := RocketMath.evaluate_design(design, far_sun)
	_assert_approx(near_eval["comms_kbps"], far_eval["comms_kbps"], 0.0001, "Changing solar distance alone does not alter the radio link")
	_assert_approx(float(far_eval["solar_gen_w"]) * 4.0, near_eval["solar_gen_w"], 0.0001, "Changing solar distance changes panel generation independently")
	_assert_approx(float(near_eval["est_tx_time_s"]) * RocketMath.DATA_SECONDS_PER_GAME_SECOND, near_eval["est_tx_physical_s"], 0.0001, "Planning estimate exposes both physical and game time")
	var coast := RocketMath.calculate_power_draw_w(design)
	_assert_approx(RocketMath.calculate_power_draw_w(design, true, true, true, false, 0.0, 1.0) - coast, 60.0, 0.0001, "XEN-9 full thrust adds 60 W")
	_assert_approx(RocketMath.calculate_power_draw_w(design, true, true, true, false, 0.0, 0.5) - coast, 30.0, 0.0001, "Engine electrical consumption follows throttle")
	var sim := FlightSimulator.new(MissionCatalog.create_all()[2], design)
	sim.toggle_safety_cover()
	sim.set_throttle(1.0)
	sim.trigger_ignition()
	sim.step(0.01)
	var active_draw: float = sim.telemetry.power_draw_w
	sim.set_throttle(0.0)
	sim.set_science_bus(true) # Refresh the power snapshot at the same attitude state.
	_assert_approx(active_draw - sim.telemetry.power_draw_w, 60.0, 0.0001, "Flight power snapshot includes active propulsion")


func _test_automatic_missions_and_resource_limits() -> void:
	var baselines := {
		"leo_tutorial": ["eng_hydrazine", "tank_small", "solar_compact", "bat_liion", "inst_cam"],
		"lunar_flyby": ["eng_biprop", "tank_medium", "tank_small", "solar_wing", "bat_liion", "comm_xband", "inst_cam", "inst_spec"],
		"mars_orbit": ["eng_ion", "tank_large", "solar_wing", "solar_wing", "bat_liion", "comm_xband", "inst_spec", "inst_radar"],
	}
	for mission in MissionCatalog.create_all():
		for tick in [1.0 / 60.0, 0.1, 0.5]:
			var design := ProbeDesign.new(PartCatalog.create_all(), _get_lv_map()[mission.recommended_lv_id])
			for pid in baselines[mission.id]:
				design.add_part(pid)
			var counts_before := design.get_counts_snapshot()
			var sim := FlightSimulator.new(mission, design)
			sim.set_automatic_enabled(true)
			for i in range(5000):
				sim.step(tick)
				if sim.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
					break
			_assert_true(sim.telemetry.status == FlightTelemetry.Status.VICTORY, "AUTO %s dt=%.4f wins (%s)" % [mission.id, tick, sim.telemetry.failure_reason])
			_assert_true(sim.telemetry.science_score == sim.telemetry.science_max, "AUTO downloads optimal science for %s" % mission.id)
			_assert_true(sim.telemetry.propellant_remaining_kg < sim.telemetry.propellant_max_kg, "AUTO spends actual fuel for %s" % mission.id)
			_assert_true(design.get_counts_snapshot() == counts_before, "AUTO preserves player's design for %s" % mission.id)
			_assert_true(sim.telemetry.event_log.any(func(entry: String): return "AUTO" in entry), "AUTO explains its actions for %s" % mission.id)
	var mars := MissionCatalog.create_all()[2]
	var insufficient := ProbeDesign.new(PartCatalog.create_all(), _get_lv_map()["lv_heavy"])
	for pid in baselines["mars_orbit"]:
		if pid != "solar_wing" and pid != "bat_liion":
			insufficient.add_part(pid)
	var failing := FlightSimulator.new(mars, insufficient)
	failing.set_automatic_enabled(true)
	for i in range(200):
		failing.step(0.5)
		if failing.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
			break
	_assert_true(failing.telemetry.status == FlightTelemetry.Status.FAILED_POWER, "AUTO cannot rescue a design with inadequate energy")
	var switching := FlightSimulator.new(mars, insufficient)
	switching.set_automatic_enabled(true)
	switching.step(0.1)
	switching.set_automatic_enabled(false)
	_assert_true(not switching.automatic_enabled and not switching.telemetry.engine_firing, "Taking manual control stops the engine")
	var frozen_time := switching.telemetry.elapsed_s
	switching.step(0.0)
	_assert_approx(switching.telemetry.elapsed_s, frozen_time, 0.000001, "Zero timestep does not advance the mission")


func _test_scene_projection_outcomes_and_local_frame() -> void:
	var area := Rect2(10, 8, 612, 230)
	for mission in MissionCatalog.create_all():
		var t := FlightTelemetry.new()
		t.status = FlightTelemetry.Status.IN_FLIGHT
		t.progress_norm = 0.02
		var initial := MissionSceneProjection.sample(mission, t, area)
		_assert_true(initial["stage"] == "SEPARACIÓN DEL LANZADOR", "Scene starts with separation for %s" % mission.id)
		_assert_true(float(initial["radius"]) > 0.0 and area.has_point(initial["planet"]), "Destination is visible at departure for %s" % mission.id)
		t.progress_norm = 0.65
		t.in_flyby_window = true
		var flyby := MissionSceneProjection.sample(mission, t, area)
		_assert_true(flyby["stage"] == "SOBREVUELO CIENTÍFICO", "Scene identifies the science window for %s" % mission.id)
		var sensor_direction := MissionSceneProjection.reference_direction(-35.0, flyby["frame_angle"])
		var target_direction: Vector2 = (Vector2(flyby["planet"]) - Vector2(flyby["ship"])).normalized()
		_assert_approx(sensor_direction.dot(target_direction), 1.0, 0.00001, "Sensor reference points at the visible destination during approach for %s" % mission.id)
		_assert_true(float(flyby["radius"]) >= float(initial["radius"]), "Destination grows during approach for %s" % mission.id)
		t.in_insertion_window = true
		t.insertion_dv_target = 1000.0
		t.insertion_dv_burned = 0.0
		var no_burn := MissionSceneProjection.sample(mission, t, area)
		_assert_true(not no_burn["orbit_captured"], "Scene does not grant an orbit without retrograde burn for %s" % mission.id)
		t.insertion_dv_burned = 1000.0
		var captured := MissionSceneProjection.sample(mission, t, area)
		_assert_true(captured["orbit_captured"], "Adequate insertion produces a captured scene for %s" % mission.id)
		t.insertion_dv_burned = 1000.0 + mission.delta_v_tolerance * 2.0
		_assert_true(not MissionSceneProjection.sample(mission, t, area)["orbit_captured"], "Overburn does not show successful capture for %s" % mission.id)
		t.status = FlightTelemetry.Status.VICTORY
		t.progress_norm = 1.0
		var end_0 := MissionSceneProjection.sample(mission, t, area, 0.0)
		var end_4 := MissionSceneProjection.sample(mission, t, area, 4.0)
		_assert_true(end_0["orbit_captured"] and end_0["stage"] == "ÓRBITA ESTABLE", "Victory shows a stable orbit for %s" % mission.id)
		_assert_true(Vector2(end_0["ship"]).distance_to(end_4["ship"]) > 10.0, "Result orbit keeps moving without advancing physics for %s" % mission.id)
		_assert_true(area.encloses(Rect2(Vector2(end_0["planet"]) - Vector2.ONE * float(end_0["radius"]), Vector2.ONE * float(end_0["radius"]) * 2.0)), "Result planet remains inside the space scene for %s" % mission.id)
		t.status = FlightTelemetry.Status.FAILED_OBJECTIVES
		var science_failure := MissionSceneProjection.sample(mission, t, area)
		_assert_true(science_failure["orbit_captured"] and "CIENCIA INCOMPLETA" in str(science_failure["stage"]), "Scientific failure preserves achieved orbit for %s" % mission.id)
		for status in [FlightTelemetry.Status.FAILED_POWER, FlightTelemetry.Status.FAILED_FUEL, FlightTelemetry.Status.FAILED_MISSED_TARGET]:
			t.status = status
			_assert_true(not MissionSceneProjection.sample(mission, t, area)["orbit_captured"], "Failed approach does not animate an orbit for %s/%d" % [mission.id, status])
	for frame in [0.0, 0.8, -1.7]:
		var pro := MissionSceneProjection.reference_direction(0.0, frame)
		var retro := MissionSceneProjection.reference_direction(180.0, frame)
		_assert_approx(pro.dot(retro), -1.0, 0.00001, "Retrograde remains opposite velocity when the camera frame rotates")


func _test_hd_layout_and_environment_motion() -> void:
	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var layout := FlightLayout.calculate(dimensions)
		var scene: Rect2 = layout["scene"]
		var deck: Rect2 = layout["deck"]
		_assert_approx(scene.size.y / (scene.size.y + deck.size.y), 0.70, 0.002, "Scene retains 70 percent at %s" % dimensions)
		_assert_true(scene.end.y < deck.position.y and Rect2(Vector2.ZERO, dimensions).encloses(deck), "Cabin fits below scene at %s" % dimensions)
	var area := Rect2(0, 0, 1260, 406)
	for mission in MissionCatalog.create_all():
		var telemetry := FlightTelemetry.new()
		telemetry.status = FlightTelemetry.Status.IN_FLIGHT
		telemetry.progress_norm = 0.02
		var departure := MissionSceneProjection.sample(mission, telemetry, area)
		telemetry.progress_norm = 0.78
		var arrival := MissionSceneProjection.sample(mission, telemetry, area)
		for geometry in [departure, arrival]:
			var sun: Vector2 = geometry["sun"]
			var radius: float = geometry["sun_radius"]
			_assert_true(area.encloses(Rect2(sun - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)), "Visible Sun fits HD scene for %s" % mission.id)
			_assert_true(sun.distance_to(Vector2(geometry["ship"])) > 140.0, "Visible Sun keeps generous sky clearance from the spacecraft for %s" % mission.id)
			var sun_direction := MissionSceneProjection.reference_direction(-90.0, geometry["frame_angle"])
			_assert_approx(sun_direction.dot((sun - Vector2(geometry["ship"])).normalized()), 1.0, 0.00001, "Solar attitude points towards visible Sun for %s" % mission.id)
		if mission.target_palette != "earth":
			_assert_true(float(arrival["origin_radius"]) < float(departure["origin_radius"]), "Earth recedes during transfer for %s" % mission.id)
			_assert_true(float(arrival["radius"]) > float(departure["radius"]), "Destination grows during arrival for %s" % mission.id)
	var t := FlightTelemetry.new()
	t.status = FlightTelemetry.Status.IN_FLIGHT
	t.battery_wh = 100.0
	t.propellant_remaining_kg = 200.0
	var environment := SpaceEnvironment.new()
	environment.update(1.0, t, 1.0)
	_assert_true(environment.travel_px > 0.0 and not t.engine_firing, "Coasting still produces visual travel")
	var coast_speed := environment.visual_speed
	var traveled := environment.travel_px
	environment.update(0.0, t, 1.0)
	_assert_approx(environment.travel_px, traveled, 0.00001, "Paused environment stays still")
	t.engine_firing = true
	t.throttle = 1.0
	environment.update(1.0, t, 1.0)
	_assert_true(environment.visual_speed > coast_speed, "Active thrust increases visual motion")
	t.in_insertion_window = true
	t.insertion_dv_target = 1000.0
	t.insertion_dv_burned = 900.0
	environment.update(1.0, t, 1.0)
	_assert_true(environment.visual_speed < coast_speed, "Insertion braking reduces visual motion")
	_assert_true(t.elapsed_s == 0.0 and t.battery_wh == 100.0 and t.propellant_remaining_kg == 200.0 and t.science_score == 0, "Ambient motion preserves mission resources and time")
	_assert_true(environment.snapshot()["object_count"] > 0 and environment.snapshot()["mote_count"] > 0, "Space contains depth objects and motes")
	environment.reset()
	_assert_approx(environment.travel_px, 0.0, 0.00001, "New flight resets environmental travel")


func _test_continuous_transit_progress() -> void:
	var area := Rect2(10, 8, 1240, 386)
	for mission in MissionCatalog.create_all():
		var t := FlightTelemetry.new()
		t.status = FlightTelemetry.Status.IN_FLIGHT
		t.progress_norm = 0.05
		var previous := MissionSceneProjection.sample(mission, t, area)
		# Check each part of the cruise, especially the first half where the old
		# late smoothstep held destination size and position completely still.
		for progress in [0.15, 0.25, 0.35, 0.45, 0.55, 0.65]:
			t.progress_norm = progress
			var current := MissionSceneProjection.sample(mission, t, area)
			_assert_true(float(current["radius"]) > float(previous["radius"]) + 3.0, "Destination visibly grows through %d%% cruise for %s" % [progress * 100, mission.id])
			_assert_true(Vector2(current["planet"]).distance_to(previous["planet"]) > 15.0, "Destination moves throughout %d%% cruise for %s" % [progress * 100, mission.id])
			var previous_gap: float = Vector2(previous["ship"]).distance_to(previous["planet"]) - float(previous["radius"])
			var current_gap: float = Vector2(current["ship"]).distance_to(current["planet"]) - float(current["radius"])
			_assert_true(current_gap < previous_gap - 25.0, "Ship closes distance throughout %d%% cruise for %s" % [progress * 100, mission.id])
			if mission.target_palette != "earth":
				_assert_true(float(current["origin_radius"]) < float(previous["origin_radius"]) and Vector2(current["origin"]).x < Vector2(previous["origin"]).x, "Earth keeps receding throughout %d%% cruise for %s" % [progress * 100, mission.id])
			previous = current
		t.progress_norm = 0.25
		var early := MissionSceneProjection.sample(mission, t, area)
		_assert_true("TRÁNSITO" in str(early["stage"]) or "ARCO TERRESTRE" in str(early["stage"]), "Visible early progress preserves cruise stage for %s" % mission.id)
		_assert_true(not early["orbit_captured"], "Visible early progress does not grant orbital capture for %s" % mission.id)


func _test_localization_and_pixel_typography() -> void:
	Loc.set_lang("es")
	_assert_true(not Loc.is_en(), "Spanish is active by default")
	var m_es := MissionCatalog.create_all()[0]
	var p_es := PartCatalog.create_all()[0]
	var l_es := LaunchVehicleCatalog.create_all()[0]
	_assert_true("ÓRBITA" in m_es.title, "Mission catalog returns Spanish title in es mode")
	_assert_true("PROPULSIÓN" in PartSpec.category_label(p_es.category), "Part category label is Spanish in es mode")
	_assert_true("Ligero" in l_es.display_name, "Launch vehicle uses Spanish label in es mode")
	_assert_true(ThemeFactory.get_ui_font_size() in [14, 16], "UI font uses crisp 1:1 14px or 2x 16px pixel sizing")
	_assert_true(ThemeFactory.get_compact_font_size() == 8, "Compact deck font uses exact 1:1 8px pixel sizing")

	Loc.set_lang("en")
	_assert_true(Loc.is_en(), "Loc.set_lang switches to English")
	_assert_true("Earth" in m_es.target_name and "ORBIT" in m_es.title, "Mission spec switches dynamically to English")
	_assert_true("PROPULSION" in PartSpec.category_label(p_es.category), "Part category switches to English")
	_assert_true("Light" in l_es.display_name, "Launch vehicle switches to English label")
	var telemetry := FlightTelemetry.new()
	_assert_true(FlightTelemetry.system_state_label(telemetry.system_state) == "STABLE", "System state label switches to English")
	_assert_true(FlightTelemetry.flight_phase_label(telemetry.flight_phase) == "INERTIAL CRUISE", "Flight phase switches to English")
	var empty_design := ProbeDesign.new()
	var eval: Dictionary = RocketMath.evaluate_design(empty_design, m_es)
	_assert_true((eval["errors"] as Array).any(func(msg: String) -> bool: return "launch vehicle" in msg.to_lower()), "Design validation errors translate to English")
	telemetry.progress_norm = 0.25
	var early_en := MissionSceneProjection.sample(m_es, telemetry, Rect2(10, 8, 1240, 386))
	_assert_true("CRUISE" in str(early_en["stage"]) or "EARTH ARC" in str(early_en["stage"]), "Scene projection stage translates to English")
	_assert_true("FIRST FLIGHT" in LearningOverlay.get_guide_text(), "Learning guide switches cleanly to English")
	Loc.set_lang("es")
	_assert_true("PRIMER VUELO" in LearningOverlay.get_guide_text(), "Learning guide switches back cleanly to Spanish")


func _test_nasa_framework() -> void:
	Loc.set_lang("es")
	var missions := MissionCatalog.create_all()
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()

	var empty_design := ProbeDesign.new(parts, lvs["lv_light"])
	var cml1: Dictionary = NasaMissionFramework.assess(empty_design, missions[0])
	_assert_true(int(cml1["cml_level"]) == 1, "Empty design stays at JPL CML 1 (Concept)")
	_assert_true((cml1["segments"] as Array).size() == 4, "NASA SMD framework models all 4 mission segments")

	var leo_design := ProbeDesign.new(parts, lvs["lv_light"])
	for pid in ["eng_hydrazine", "tank_small", "solar_compact", "bat_liion", "inst_cam"]:
		leo_design.add_part(pid)
	var leo_nasa: Dictionary = NasaMissionFramework.assess(leo_design, missions[0])
	_assert_true(int(leo_nasa["cml_level"]) >= 4, "Balanced LEO design reaches at least JPL CML 4")
	_assert_approx(float(leo_nasa["margins"]["link_req_db"]), 6.0, 0.01, "LEO proximity link margin requires >= 6 dB per JPL Team X")
	_assert_true("PUNCH" in str(leo_nasa["nasa_analogue"]["mission_name"]), "LEO mission maps to NASA PUNCH/BisonSat analogue")
	_assert_true("SmallSat" in NasaMissionFramework.classify_form_factor(250.0), "Sub-300 kg spacecraft classifies as SmallSat per CubeSat 101")
	_assert_true("Bus" in str(leo_nasa["form_factor"]), "340 kg+ wet-mass LEO stack classifies above 300 kg SmallSat cap")

	var mars_design := ProbeDesign.new(parts, lvs["lv_heavy"])
	for pid in ["eng_ion", "tank_large", "solar_array", "solar_array", "bat_hv", "bat_hv", "comms_hga", "inst_spec", "inst_radar"]:
		mars_design.add_part(pid)
	var mars_nasa: Dictionary = NasaMissionFramework.assess(mars_design, missions[2])
	_assert_approx(float(mars_nasa["margins"]["link_req_db"]), 3.0, 0.01, "Deep-space Mars link margin requires >= 3 dB per JPL Team X")
	_assert_true("MAVEN" in str(mars_nasa["nasa_analogue"]["mission_name"]), "Mars mission maps to NASA MAVEN/Dawn analogue")

	var mars_script: String = NasaMissionFramework.generate_gmat_script(mars_design, missions[2])
	_assert_true("Create Spacecraft Probe;" in mars_script and "Mars50c.cof" in mars_script, "GMAT generator writes Mars50c gravity force model")
	_assert_true("SRP.Flux = 1358;" in mars_script and "149597870.691" in mars_script, "GMAT generator uses official R2026a SRP flux and Nominal_Sun")
	_assert_true("ImpulsiveBurn TCM1;" in mars_script and "Axes = VNB;" in mars_script, "GMAT generator exports VNB impulsive TCM maneuver")

	var lunar_script: String = NasaMissionFramework.generate_gmat_script(leo_design, missions[1])
	_assert_true("LP165P.cof" in lunar_script, "GMAT lunar script includes LP165P lunar gravity potential")

	Loc.set_lang("en")
	_assert_true("LAUNCH SEGMENT" in NasaMissionFramework.format_summary_report(leo_design, missions[0]), "NASA summary report localizes to English")
	_assert_true("NASA FRAMEWORK" in LearningOverlay.get_guide_text(), "Learning guide includes NASA CML/GMAT framework section in English")
	Loc.set_lang("es")
	_assert_true("MARCO NASA" in LearningOverlay.get_guide_text(), "Learning guide includes NASA CML/GMAT framework section in Spanish")


func _test_internal_cabin_archetypes() -> void:
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var missions := MissionCatalog.create_all()

	var compact_probe := ProbeDesign.new(parts, lvs["lv_light"])
	compact_probe.add_part("eng_hydrazine")
	compact_probe.add_part("inst_cam")
	_assert_true(InternalCabinRenderer.classify_archetype(compact_probe, missions[0]) == "compact", "Light launcher probe selects compact cupola internal view")

	var explorer_probe := ProbeDesign.new(parts, lvs["lv_medium"])
	explorer_probe.add_part("eng_biprop")
	explorer_probe.add_part("tank_medium")
	_assert_true(InternalCabinRenderer.classify_archetype(explorer_probe, missions[1]) == "explorer", "Medium launcher probe selects explorer bay internal view")

	var heavy_probe := ProbeDesign.new(parts, lvs["lv_heavy"])
	heavy_probe.add_part("eng_ion")
	heavy_probe.add_part("tank_large")
	_assert_true(InternalCabinRenderer.classify_archetype(heavy_probe, missions[2]) == "deep_space", "Heavy ion probe selects deep-space bridge internal view")

	var w_compact := InternalCabinRenderer.window_rect(Vector2(1260, 480), "compact")
	var w_explorer := InternalCabinRenderer.window_rect(Vector2(1260, 480), "explorer")
	var w_deep := InternalCabinRenderer.window_rect(Vector2(1260, 480), "deep_space")
	_assert_true(w_compact.size.x < w_explorer.size.x and w_deep.size.x > w_compact.size.x, "Internal window dimensions differ cleanly between spacecraft models")
	Loc.set_lang("en")
	_assert_true(InternalCabinRenderer.archetype_label("deep_space") == "DEEP-SPACE BRIDGE", "Internal cabin archetype label translates to English")
	Loc.set_lang("es")
	_assert_true(InternalCabinRenderer.archetype_label("compact") == "CÚPULA COMPACTA", "Internal cabin archetype label translates cleanly to Spanish")


func _test_profiles_and_nasa_badges() -> void:
	Loc.set_lang("es")
	_assert_true(NasaMissionFramework.sanitize_username("  Elena_Vance 01!! ") == "elena_vance01", "sanitize_username normalizes case and strips disallowed symbols")
	var bad_name := NasaMissionFramework.validate_profile(" ", "evance")
	_assert_true(not bool(bad_name["ok"]), "validate_profile rejects empty display name")
	var bad_user := NasaMissionFramework.validate_profile("Elena", "a!")
	_assert_true(not bool(bad_user["ok"]), "validate_profile rejects usernames shorter than 2 valid chars")
	var good := NasaMissionFramework.validate_profile("Elena Vance", "EVance-9")
	_assert_true(bool(good["ok"]) and str(good["username"]) == "evance-9", "validate_profile accepts valid passwordless Name + Username")

	var missions := MissionCatalog.create_all()
	var parts := PartCatalog.create_all()
	var lvs := _get_lv_map()
	var leo_design := ProbeDesign.new(parts, lvs["lv_light"])
	for pid in ["eng_hydrazine", "tank_small", "solar_wing", "bat_liion", "inst_cam"]:
		leo_design.add_part(pid)
	var sim := FlightSimulator.new(missions[0], leo_design)
	sim.telemetry.status = FlightTelemetry.Status.VICTORY
	sim.telemetry.science_score = sim.telemetry.science_min_required
	sim.telemetry.effective_delta_v = missions[0].required_delta_v * 1.40
	sim.telemetry.propellant_remaining_kg = sim.telemetry.propellant_max_kg * 0.06
	var badges := NasaMissionFramework.evaluate_badges(leo_design, missions[0], sim.telemetry, true)
	_assert_true(badges.has("CML 5") and badges.has("TEAM X >=35%") and badges.has("PILOTO MANUAL"), "evaluate_badges awards NASA CML 5, Team X margin, and Manual Pilot badges")
