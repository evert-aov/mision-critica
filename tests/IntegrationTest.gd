extends Node
## Full SceneTree integration test verifying Autoloads, UI scenes, Launch Vehicle & Comms integration,
## and EVERY cockpit control signal (Power buses, Solar deploy, Attitude modes, Manual slew,
## SAS Stabilize, RCS toggle, Throttle, Safety Cover, Ignition, and Science capture).

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=== RUNNING END-TO-END INTEGRATION TEST ===")
	AudioManager.set_muted(true)

	_assert(MissionData.get_all_parts().size() == 15, "MissionData loaded 15 parts")
	_assert(MissionData.get_all_launch_vehicles().size() == 3, "MissionData loaded 3 launch vehicles")
	_assert(MissionData.get_all_missions().size() == 3, "MissionData loaded 3 missions")
	_assert(GameState.current_mission != null, "GameState selected initial mission")

	# Instantiate Main router
	var main_scene := load("res://src/presentation/screens/Main.tscn") as PackedScene
	var main_inst := main_scene.instantiate()
	add_child(main_inst)
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.MISSION_SELECT, "Starts in MISSION_SELECT")
	await _test_keyboard_and_mouse(main_inst)

	# Enter Assembly for Mars Orbit & test Launch Vehicle selection
	GameState.enter_assembly("mars_orbit")
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.ASSEMBLY, "Transitioned to ASSEMBLY")
	_assert(GameState.set_launch_vehicle("lv_medium"), "Selectable Launch Vehicle changes via GameState")
	GameState.load_recommended_baseline()
	await get_tree().process_frame
	_assert(GameState.current_design.get_launch_vehicle().id == "lv_heavy", "Mars baseline equips lv_heavy")
	_assert(GameState.current_design.get_part_count("comm_xband") == 1, "Mars baseline equips X-band antenna")
	_assert(bool(GameState.last_evaluation.get("valid_for_launch", false)), "Mars baseline valid for launch")
	var vbounds := ProbeVisualRenderer.compute_vertical_bounds(GameState.current_design)
	_assert(vbounds.x > 60.0 and vbounds.y > 70.0, "ProbeVisualRenderer computes valid bounds for Mars design")

	# Launch into Cockpit
	var launched := GameState.launch_mission()
	_assert(launched, "Launched into FLIGHT_COCKPIT")
	await get_tree().process_frame
	_assert(GameState.current_phase == GameState.Phase.FLIGHT_COCKPIT, "Phase is FLIGHT_COCKPIT")
	_assert(GameState.active_simulator != null, "Active simulator initialized")

	var cockpit = main_inst.get("_current_view")
	_assert(cockpit != null, "Cockpit view instantiated")
	var layout: Dictionary = cockpit.get_layout_snapshot()
	var scene_rect: Rect2 = layout["scene"]
	var deck_rect: Rect2 = layout["deck"]
	_assert(absf(scene_rect.size.y / (scene_rect.size.y + deck_rect.size.y) - 0.70) < 0.01, "Flight uses a 70 percent scene and 30 percent deck")
	_assert(cockpit._nav_console.visible and cockpit._power_panel.visible and cockpit._science_panel.visible, "All cockpit controls stay visible during flight")
	_assert(scene_rect.end.y < deck_rect.position.y, "Scene and deck do not overlap")
	cockpit._btn_view.pressed.emit()
	_assert(not cockpit._guidance_visible and cockpit._nav_console.visible, "V hides guidance without hiding the cockpit")
	_assert(cockpit.get_layout_snapshot() == layout, "Changing guidance preserves the 70/30 split")
	cockpit._btn_view.pressed.emit()
	_assert(cockpit._guidance_visible, "V restores guidance")
	var sim := GameState.active_simulator
	_assert(sim.telemetry.downlink_kbps > 0.0, "Deep-space comms downlink speed initialized")

	# 1. Verify PowerPanel UI signals -> FlightSimulator
	cockpit._power_panel.panels_deploy_requested.emit()
	_assert(sim.telemetry.panels_deployed, "PowerPanel deploy signal deploys solar panels")
	cockpit._power_panel.comms_toggled.emit(false)
	_assert(not sim.telemetry.comms_on, "PowerPanel comms toggle turns comms OFF")
	cockpit._power_panel.comms_toggled.emit(true)
	_assert(sim.telemetry.comms_on, "PowerPanel comms toggle turns comms ON")
	cockpit._power_panel.science_toggled.emit(false)
	_assert(not sim.telemetry.science_bus_on, "PowerPanel science toggle turns science OFF")
	cockpit._power_panel.science_toggled.emit(true)
	_assert(sim.telemetry.science_bus_on, "PowerPanel science toggle turns science ON")

	# 2. Verify NavigationConsole Attitude & RCS UI signals -> FlightSimulator
	cockpit._nav_console.rcs_toggled.emit()
	_assert(sim.telemetry.rcs_enabled, "NavigationConsole RCS button enables RCS thrusters")
	cockpit._nav_console.attitude_mode_requested.emit(FlightTelemetry.AttitudeMode.RETROGRADE)
	_assert(sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.RETROGRADE, "NavigationConsole RET 180 button sets RETROGRADE target")
	cockpit._nav_console.attitude_nudged.emit(1.0)
	_assert(sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.MANUAL and absf(sim.telemetry.angular_vel_deg_s) > 0.0, "NavigationConsole manual turn nudges angular velocity")
	cockpit._nav_console.stabilize_requested.emit()
	_assert(sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.HOLD, "NavigationConsole ESTAB button activates SAS HOLD")
	cockpit._nav_console.attitude_mode_requested.emit(FlightTelemetry.AttitudeMode.PROGRADE)

	# 3. Verify NavigationConsole Propulsion UI signals -> FlightSimulator
	cockpit._nav_console.safety_cover_toggled.emit()
	_assert(sim.telemetry.safety_cover_open, "NavigationConsole cover signal opens safety cover")
	cockpit._nav_console.throttle_changed.emit(0.85)
	_assert(absf(sim.telemetry.throttle - 0.85) < 0.01, "NavigationConsole throttle lever updates throttle")
	cockpit._nav_console.ignition_pressed.emit()
	_assert(sim.telemetry.engine_firing, "NavigationConsole ignition button fires engine")

	# 4. Verify SciencePanel UI signal -> FlightSimulator
	cockpit._science_panel.instrument_activated.emit("inst_spec")
	_assert(sim.telemetry.instruments_captured.has("inst_spec"), "SciencePanel sensor button captures instrument telemetry")

	for _i in range(4):
		await get_tree().process_frame
	_assert(sim.telemetry.delta_v_burned > 0.0, "Cockpit simulator steps physics and burns delta-v live")

	# Launch through the actual assembly AUTO button and exercise takeover/help/retry.
	GameState.enter_assembly("leo_tutorial")
	await get_tree().process_frame
	GameState.clear_design()
	var assembly = main_inst.get("_current_view")
	_assert(assembly._btn_auto.disabled, "Invalid designs disable the automatic launch button")
	_assert(not GameState.launch_mission(true), "Automatic launch still enforces design validation")
	GameState.load_recommended_baseline()
	_assert(not assembly._btn_auto.disabled, "A valid design enables automatic flight")
	await _tap_key(KEY_F6)
	cockpit = main_inst.get("_current_view")
	sim = GameState.active_simulator
	_assert(sim.automatic_enabled, "Assembly AUTO button launches the automatic simulator")
	cockpit._process(0.5)
	_assert(sim.telemetry.panels_deployed, "Automatic flight deploys panels through ordinary commands")
	cockpit._btn_auto.pressed.emit()
	_assert(not sim.automatic_enabled and not sim.telemetry.engine_firing, "AUTO button returns to manual control with engine stopped")
	cockpit._btn_auto.pressed.emit()
	cockpit._nav_console.attitude_mode_requested.emit(FlightTelemetry.AttitudeMode.EARTH)
	_assert(not sim.automatic_enabled and sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.EARTH, "A manual navigation command takes control from AUTO")
	cockpit._btn_auto.pressed.emit()
	GameState.learning_requested.emit()
	var guide = main_inst.get("_learning_overlay")
	_assert(guide.visible and get_tree().paused, "In-game learning guide pauses the mission")
	var paused_at: float = sim.telemetry.elapsed_s
	var paused_travel: float = cockpit._viewport_win.get_scene_snapshot()["environment"]["travel_px"]
	await get_tree().process_frame
	_assert(is_equal_approx(sim.telemetry.elapsed_s, paused_at), "Reading educational help does not spend mission time")
	_assert(is_equal_approx(cockpit._viewport_win.get_scene_snapshot()["environment"]["travel_px"], paused_travel), "Reading help also pauses ambient space motion")
	guide.close_guide()
	_assert(not guide.visible and not get_tree().paused, "Closing help restores normal play")
	for i in range(110):
		cockpit._process(0.5)
		if GameState.current_phase == GameState.Phase.MISSION_RESULT:
			break
	_assert(sim.telemetry.status == FlightTelemetry.Status.VICTORY, "Automatic flight reaches victory through the cockpit process loop")
	_assert(cockpit._result_overlay.visible, "Automatic victory opens the mission result report")
	var result_snapshot: Dictionary = cockpit._viewport_win.get_scene_snapshot()
	_assert(result_snapshot["orbit_captured"], "Result scene displays the orbit actually achieved")
	var ended_at: float = sim.telemetry.elapsed_s
	var initial_ship: Vector2 = result_snapshot["ship"]
	cockpit._process(3.0)
	_assert(Vector2(cockpit._viewport_win.get_scene_snapshot()["ship"]).distance_to(initial_ship) > 5.0, "Final orbit continues to animate next to the report")
	_assert(is_equal_approx(sim.telemetry.elapsed_s, ended_at), "Final animation leaves terminal mission physics unchanged")
	_assert(not cockpit._control_dock.visible and cockpit._result_overlay.visible, "Final report replaces the deck while keeping the space scene visible")
	_assert("QUÉ APRENDER" in cockpit._result_overlay._lbl_details.text, "Mission report includes educational feedback")
	await _tap_key(KEY_R)
	_assert(GameState.active_simulator != sim and GameState.active_simulator.automatic_enabled, "Retry creates a fresh mission and preserves automatic mode")
	_assert(GameState.current_phase == GameState.Phase.FLIGHT_COCKPIT, "Retry restores the cockpit phase")
	cockpit = main_inst.get("_current_view")
	_assert(ThemeFactory.get_theme().default_font_size in [14, 16], "Primary UI theme uses crisp integer pixel font scaling")
	_assert(cockpit._power_panel.theme.default_font_size == 8, "Compact cockpit subpanels preserve 1:1 8px pixel font")

	GameState.enter_mission_select()
	await get_tree().process_frame
	var select_view = main_inst.get("_current_view")
	await _tap_key(KEY_F2)
	_assert(GameState.language == "en" and Loc.is_en(), "F2 in mission select toggles language to English")
	_assert(select_view._title_lbl.text == "CRITICAL MISSION / SELECT DESTINATION" and select_view._help_btn.text == "HELP [F1]", "Mission select headers update immediately to English")
	await _tap_key(KEY_F2)
	_assert(GameState.language == "es" and not Loc.is_en() and select_view._help_btn.text == "AYUDA [F1]", "F2 in mission select toggles language back to Spanish")
	main_inst.queue_free()

	print("=== INTEGRATION RESULTS: %d PASSED, %d FAILED ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)


func _tap_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = code
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _mouse_button(point: Vector2, code: MouseButton, shift: bool = false, double: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = code
	event.pressed = true
	event.shift_pressed = shift
	event.double_click = double
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _test_keyboard_and_mouse(main: Node) -> void:
	await _tap_key(KEY_3)
	_assert(GameState.current_phase == GameState.Phase.ASSEMBLY and GameState.current_mission.id == "mars_orbit", "Mission hotkey 3 selects Mars through the input pipeline")
	await _tap_key(KEY_B)
	_assert(GameState.current_design.get_part_count("inst_spec") == 1, "B shortcut loads the mission baseline")
	var assembly = main.get("_current_view")
	_assert(assembly._header.get_global_rect().end.y <= assembly._body.get_global_rect().position.y, "Assembly header and body do not overlap")
	var title_rect: Rect2 = assembly._lbl_mission.get_global_rect()
	_assert(assembly._header.get_global_rect().encloses(title_rect), "Mission title stays inside its header")
	await _tap_key(KEY_2)
	_assert(int(assembly._selected_tab) == 1, "Numeric category shortcuts select propulsion")
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_PLUS)
	_assert(GameState.current_design.get_part_count("eng_biprop") == 1, "Arrows and plus equip the highlighted catalog item")
	await _tap_key(KEY_MINUS)
	_assert(GameState.current_design.get_part_count("eng_biprop") == 0, "Minus removes the highlighted part")
	await _tap_key(KEY_4)
	await get_tree().process_frame
	# Exercise overflow with a larger catalog, independent of the available screen height.
	var expanded_entries: Array = []
	for i in range(5):
		expanded_entries.append_array(assembly._catalog_entries)
	assembly._populate_catalog(expanded_entries, GameState.current_design)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll: ScrollContainer = assembly._catalog_scroll
	var scroll_at: int = scroll.scroll_vertical
	await _mouse_button(scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	_assert(scroll.scroll_vertical > scroll_at, "Wheel over the catalog scrolls equipment")
	await _tap_key(KEY_2)
	var card: Control = assembly._catalog_cards[0]
	await _mouse_button(card.get_global_rect().position + Vector2(45, 12), MOUSE_BUTTON_LEFT, false, true)
	_assert(GameState.current_design.get_part_count("eng_hydrazine") == 1, "Double click equips the catalog part")
	card = assembly._catalog_cards[0]
	await _mouse_button(card.get_global_rect().position + Vector2(45, 12), MOUSE_BUTTON_RIGHT)
	_assert(GameState.current_design.get_part_count("eng_hydrazine") == 0, "Right click removes a catalog part")
	card = assembly._catalog_cards[0]
	var quantity_controls: Control = card.get_child(0).get_child(card.get_child(0).get_child_count() - 1)
	var plus: Control = quantity_controls.get_child(quantity_controls.get_child_count() - 1)
	await _mouse_button(plus.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_assert(GameState.current_design.get_part_count("eng_hydrazine") == 1, "Wheel on plus equips one part without scrolling the list")
	card = assembly._catalog_cards[0]
	quantity_controls = card.get_child(0).get_child(card.get_child(0).get_child_count() - 1)
	plus = quantity_controls.get_child(quantity_controls.get_child_count() - 1)
	await _mouse_button(plus.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	_assert(GameState.current_design.get_part_count("eng_hydrazine") == 0, "Wheel down on quantity controls removes one part")
	var blueprint: Control = assembly._blueprint_view
	await _mouse_button(blueprint.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_assert(float(blueprint.get("_zoom")) > 1.0, "Blueprint wheel zoom works")
	await _mouse_button(blueprint.get_global_rect().get_center(), MOUSE_BUTTON_MIDDLE)
	_assert(is_equal_approx(float(blueprint.get("_zoom")), 1.0), "Middle click resets blueprint zoom")
	await _tap_key(KEY_F5)
	_assert(GameState.current_phase == GameState.Phase.FLIGHT_COCKPIT, "F5 launches manual flight")
	var cockpit = main.get("_current_view")
	var sim: FlightSimulator = GameState.active_simulator
	await _tap_key(KEY_W)
	_assert(is_equal_approx(sim.telemetry.throttle, 0.1), "W adjusts throttle once through the input pipeline")
	var space: Vector2 = cockpit._viewport_win.get_global_rect().position + Vector2(320, 170)
	await _mouse_button(space, MOUSE_BUTTON_WHEEL_UP)
	_assert(is_equal_approx(sim.telemetry.throttle, 0.15), "Wheel over space adds five percent throttle")
	await _mouse_button(space, MOUSE_BUTTON_WHEEL_DOWN, true)
	_assert(is_equal_approx(sim.telemetry.throttle, 0.14), "Shift wheel makes a one percent adjustment")
	await _mouse_button(space, MOUSE_BUTTON_LEFT)
	_assert(sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.POINT, "Scene left click commands free pointing")
	await _mouse_button(space, MOUSE_BUTTON_RIGHT)
	_assert(sim.telemetry.attitude_mode == FlightTelemetry.AttitudeMode.HOLD, "Scene right click stabilizes the spacecraft")
	await _mouse_button(space, MOUSE_BUTTON_MIDDLE)
	_assert(not cockpit._guidance_visible and cockpit._nav_console.visible, "Middle click toggles guidance while keeping cockpit controls visible")
	var lever: Control = cockpit._nav_console._throttle_control
	await _mouse_button(lever.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_assert(is_equal_approx(sim.telemetry.throttle, 0.19), "Wheel on the lever changes throttle without a second scene action")
	await _mouse_button(lever.get_global_rect().position + Vector2(lever.size.x * 0.75, 10), MOUSE_BUTTON_LEFT)
	_assert(sim.telemetry.throttle > 0.65 and sim.telemetry.throttle < 0.85, "Lever left click sets proportional thrust")
	await _mouse_button(lever.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_assert(is_equal_approx(sim.telemetry.throttle, 0.0), "Right click on the lever sets zero throttle")
	await _tap_key(KEY_V)
	_assert(cockpit._guidance_visible, "V restores flight guidance")
	await _tap_key(KEY_C)
	cockpit._btn_view.grab_focus()
	var guidance_before: bool = cockpit._guidance_visible
	await _tap_key(KEY_SPACE)
	_assert(sim.telemetry.engine_firing, "Space ignites when the cover is open")
	_assert(cockpit._guidance_visible == guidance_before, "Flight Space does not also activate a focused UI button")
	await _tap_key(KEY_X)
	AudioManager.set_muted(false)
	sim.telemetry.attitude_deg = 0.0
	await _tap_key(KEY_1)
	await _tap_key(KEY_T)
	_assert(is_equal_approx(sim.telemetry.throttle, 1.0) and sim.telemetry.engine_firing, "T triggers 100% turbo burn")
	cockpit._process(0.05)
	_assert(AudioManager._streams.has("turbo") and AudioManager._streams.has("brake") and AudioManager._streams.has("cruise_hum") and AudioManager._streams.has("retro_hum"), "AudioManager provides turbo, brake, retro, and cruise streams")
	_assert(AudioManager._cruise_player.stream == AudioManager._streams["cruise_hum"] and AudioManager._engine_player.stream == AudioManager._streams["engine_hum"] and AudioManager._engine_player.pitch_scale > 1.35, "Forward turbo burn configures high-pitch engine and cruise loops")
	await _tap_key(KEY_2)
	sim.telemetry.attitude_deg = 180.0
	cockpit._process(0.05)
	_assert(AudioManager._engine_player.stream == AudioManager._streams["retro_hum"] and AudioManager._engine_player.pitch_scale < 1.2, "Retrograde braking switches engine audio to pulsed retro_hum")
	await _tap_key(KEY_X)
	_assert(not sim.telemetry.engine_firing and is_equal_approx(sim.telemetry.throttle, 0.0), "X cuts turbo burn back to zero")
	AudioManager.set_muted(true)
	await _tap_key(KEY_F3)
	_assert(not sim.telemetry.comms_on, "F3 toggles the radio bus")
	await _tap_key(KEY_F3)
	await _tap_key(KEY_F8)
	_assert(sim.telemetry.instruments_captured.has("inst_spec"), "F8 captures the installed spectrometer")
	var held := InputEventKey.new()
	held.keycode = KEY_A
	held.pressed = true
	get_viewport().push_input(held, true)
	await _tap_key(KEY_F1)
	var guide = main.get("_learning_overlay")
	_assert(guide.visible and get_tree().paused, "F1 opens the paused controls guide")
	_assert(not cockpit._key_ccw_held and not cockpit._key_cw_held, "Opening help releases held rotation input")
	var before_page: int = guide._scroll.scroll_vertical
	await _tap_key(KEY_PAGEDOWN)
	_assert(guide._scroll.scroll_vertical > before_page, "Page Down scrolls help while the game is paused")
	await _tap_key(KEY_ESCAPE)
	_assert(not guide.visible and not get_tree().paused, "Escape closes help without reopening it")
	GameState.enter_mission_select()
	await get_tree().process_frame
