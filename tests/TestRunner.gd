extends SceneTree
## Headless unit & integration test suite for Misión Crítica.
## Run with: godot --headless --script res://tests/TestRunner.gd

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== RUNNING MISIÓN CRÍTICA TEST SUITE ===")
	_test_tsiolkovski_math()
	_test_solar_inverse_square_and_power()
	_test_budget_and_validation()
	_test_all_three_missions_baseline_viability()
	_test_flight_simulator_propulsion_and_safety()
	_test_flight_simulator_power_and_science()
	_test_flight_simulator_victory_flow()

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


func _test_tsiolkovski_math() -> void:
	var parts := PartCatalog.create_all()
	var design := ProbeDesign.new(parts)
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

	# Multi-engine effective Isp check
	design.add_part("eng_ion") # 3000N, Isp 520s
	var eff_isp := RocketMath.calculate_effective_isp_s(design)
	var expected_isp := (2600.0 + 3000.0) / ((2600.0 / 295.0) + (3000.0 / 520.0))
	_assert_approx(eff_isp, expected_isp, 0.05, "Multi-engine thrust-weighted Isp")


func _test_solar_inverse_square_and_power() -> void:
	var parts := PartCatalog.create_all()
	var design := ProbeDesign.new(parts)
	design.add_part("solar_wing") # 110 W at 1 AU
	design.add_part("bat_liion")  # 120 Wh
	design.add_part("inst_cam")   # 14 W draw

	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, true, false), 110.0, 0.01, "Solar @ 1.0 AU")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.52, true, false), 110.0 / (1.52 * 1.52), 0.05, "Solar @ 1.52 AU (Mars)")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, false, false), 0.0, 0.001, "Solar retracted = 0 W")
	_assert_approx(RocketMath.calculate_solar_generation_w(design, 1.0, true, true), 0.0, 0.001, "Solar in shadow = 0 W")
	_assert_approx(RocketMath.calculate_battery_capacity_wh(design), 160.0, 0.01, "Battery = 40 + 120 Wh")
	_assert_approx(RocketMath.calculate_power_draw_w(design, true, true, true, false), 12.0 + 10.0 + 14.0, 0.01, "Full draw = 36 W")


func _test_budget_and_validation() -> void:
	var parts := PartCatalog.create_all()
	var missions := MissionCatalog.create_all()
	var leo := missions[0]
	var design := ProbeDesign.new(parts)

	var ev_empty := RocketMath.evaluate_design(design, leo)
	_assert_true(not ev_empty["valid_for_launch"], "Empty probe cannot launch")

	design.add_part("eng_ion")
	design.add_part("eng_ion")
	design.add_part("tank_large")
	design.add_part("tank_large")
	var ev_over := RocketMath.evaluate_design(design, leo)
	_assert_true(not ev_over["valid_for_launch"], "Over-budget probe cannot launch")


func _test_all_three_missions_baseline_viability() -> void:
	var parts := PartCatalog.create_all()
	var missions := MissionCatalog.create_all()
	_assert_true(missions.size() == 3, "Exactly 3 MVP missions defined")

	var baselines := {
		"leo_tutorial": ["eng_hydrazine", "tank_small", "solar_compact", "inst_cam"],
		"lunar_flyby": ["eng_biprop", "tank_medium", "tank_small", "solar_wing", "bat_liion", "inst_cam", "inst_spec"],
		"mars_orbit": ["eng_ion", "tank_large", "solar_wing", "solar_compact", "bat_liion", "inst_spec", "inst_radar"],
	}
	for m in missions:
		var design := ProbeDesign.new(parts)
		for pid in baselines[m.id]:
			_assert_true(design.add_part(pid), "Add baseline part %s for %s" % [pid, m.id])
		var ev := RocketMath.evaluate_design(design, m)
		_assert_true(ev["valid_for_launch"], "Baseline valid for %s" % m.id)
		_assert_true(float(ev["delta_v"]) >= m.required_delta_v, "Baseline Δv >= req for %s" % m.id)
		_assert_true(int(ev["budget_remaining"]) >= 0, "Baseline within budget for %s" % m.id)


func _test_flight_simulator_propulsion_and_safety() -> void:
	var parts := PartCatalog.create_all()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts)
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")

	var sim := FlightSimulator.new(leo, design)
	_assert_true(not sim.trigger_ignition(), "Cannot ignite while safety cover is closed")

	sim.toggle_safety_cover()
	sim.set_throttle(1.0)
	_assert_true(sim.trigger_ignition(), "Ignites once cover is open")

	for _i in range(40):
		sim.step(0.1)

	_assert_true(sim.telemetry.delta_v_burned > 100.0, "Delta-v burned increases during firing")
	_assert_approx(
		sim.telemetry.delta_v_burned + sim.telemetry.delta_v_remaining,
		sim.telemetry.delta_v_initial,
		1.0,
		"Delta-v conservation (burned + remaining == initial)"
	)


func _test_flight_simulator_power_and_science() -> void:
	var parts := PartCatalog.create_all()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts)
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")
	design.add_part("inst_cam")

	var sim := FlightSimulator.new(leo, design)
	_assert_true(not sim.telemetry.panels_deployed, "Panels start stowed")
	_assert_true(sim.deploy_panels(), "Panels deploy on command")

	# Capture early (outside flyby window -> 35%)
	var early_res := sim.activate_instrument("inst_cam")
	_assert_true(early_res["ok"] and not early_res["optimal"], "Early capture is non-optimal (35%)")

	# Advance into flyby window (65%..95% of 40s => ~30s)
	for _i in range(300):
		sim.step(0.1)
	_assert_true(sim.telemetry.in_flyby_window, "Entered flyby window")
	var opt_res := sim.activate_instrument("inst_cam")
	_assert_true(opt_res["ok"] and opt_res["optimal"], "Flyby capture is optimal (100%)")

	for _i in range(25):
		sim.step(0.1)
	_assert_true(sim.telemetry.science_score == 150, "Optimal science transmitted (+150 pts)")

	# Test blackout failure when power is negative with no panels
	var sim_fail := FlightSimulator.new(leo, design)
	for _i in range(600):
		sim_fail.step(0.1)
		if sim_fail.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
			break
	_assert_true(sim_fail.telemetry.status == FlightTelemetry.Status.FAILED_POWER, "Stowed panels eventually trigger FAILED_POWER")


func _test_flight_simulator_victory_flow() -> void:
	var parts := PartCatalog.create_all()
	var leo := MissionCatalog.create_all()[0]
	var design := ProbeDesign.new(parts)
	design.add_part("eng_hydrazine")
	design.add_part("tank_small")
	design.add_part("solar_compact")
	design.add_part("bat_liion")
	design.add_part("inst_cam")

	var sim := FlightSimulator.new(leo, design)
	sim.deploy_panels()
	sim.toggle_safety_cover()
	sim.set_throttle(0.8)
	sim.trigger_ignition()

	for _i in range(420):
		sim.step(0.1)
		if sim.telemetry.delta_v_burned >= leo.required_delta_v:
			sim.set_throttle(0.0)
		if sim.telemetry.progress_norm >= 0.72 and not sim.telemetry.instruments_captured.has("inst_cam"):
			sim.activate_instrument("inst_cam")
		if sim.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
			break

	_assert_true(sim.telemetry.status == FlightTelemetry.Status.VICTORY, "LEO mission completes with VICTORY")
	_assert_true(sim.telemetry.science_score == 150, "LEO mission awards 150 science points")
