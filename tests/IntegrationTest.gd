extends Node
## Full SceneTree integration test verifying Autoloads, UI scenes, and end-to-end transitions.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=== RUNNING END-TO-END INTEGRATION TEST ===")
	AudioManager.set_muted(true)

	_assert(MissionData.get_all_parts().size() == 13, "MissionData loaded 13 parts")
	_assert(MissionData.get_all_missions().size() == 3, "MissionData loaded 3 missions")
	_assert(GameState.current_mission != null, "GameState selected initial mission")

	# Instantiate Main router
	var main_scene := load("res://src/presentation/screens/Main.tscn") as PackedScene
	var main_inst := main_scene.instantiate()
	add_child(main_inst)
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.MISSION_SELECT, "Starts in MISSION_SELECT")

	# Enter Assembly for Mars Orbit
	GameState.enter_assembly("mars_orbit")
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.ASSEMBLY, "Transitioned to ASSEMBLY")
	GameState.load_recommended_baseline()
	await get_tree().process_frame
	_assert(bool(GameState.last_evaluation.get("valid_for_launch", false)), "Mars baseline valid for launch")

	# Launch into Cockpit
	var launched := GameState.launch_mission()
	_assert(launched, "Launched into FLIGHT_COCKPIT")
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.FLIGHT_COCKPIT, "Phase is FLIGHT_COCKPIT")
	_assert(GameState.active_simulator != null, "Active simulator initialized")

	# Simulate user actions in cockpit
	var sim := GameState.active_simulator
	sim.deploy_panels()
	sim.toggle_safety_cover()
	sim.set_throttle(1.0)
	sim.trigger_ignition()
	for _i in range(4):
		await get_tree().process_frame
	_assert(sim.telemetry.delta_v_burned > 0.0, "Cockpit simulator burns delta-v live")

	GameState.enter_mission_select()
	await get_tree().process_frame
	main_inst.queue_free()

	print("=== INTEGRATION RESULTS: %d PASSED, %d FAILED ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)
