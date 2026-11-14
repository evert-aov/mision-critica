@tool
extends Control
## Phase 4: Interactive Virtual Cockpit hosting ViewportWindow, PowerPanel,
## NavigationConsole, SciencePanel, Camera2D screen shake, and MissionResultOverlay.

var _camera: Camera2D
var _viewport_win: ViewportWindow
var _power_panel: PowerPanel
var _nav_console: NavigationConsole
var _science_panel: SciencePanel
var _result_overlay: MissionResultOverlay

var _rng := RandomNumberGenerator.new()
var _finished_notified: bool = false


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_rng.randomize()
	_build_ui()
	if Engine.is_editor_hint():
		var parts := PartCatalog.create_all()
		var preview_mission := MissionCatalog.create_all()[0]
		var preview_design := ProbeDesign.new(parts)
		preview_design.add_part("eng_hydrazine")
		preview_design.add_part("tank_small")
		preview_design.add_part("solar_compact")
		preview_design.add_part("inst_cam")
		var preview_sim := FlightSimulator.new(preview_mission, preview_design)
		preview_sim.deploy_panels()
		_viewport_win.setup(preview_mission)
		_viewport_win.update_telemetry(preview_sim.telemetry, 0.0)
		_power_panel.update_telemetry(preview_sim.telemetry)
		_nav_console.update_telemetry(preview_sim.telemetry, preview_mission)
		_science_panel.update_telemetry(preview_sim)
		return
	_connect_signals()
	if GameState.active_simulator != null:
		_viewport_win.setup(GameState.active_simulator.mission)
		_sync_views(0.0)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	AudioManager.stop_engine_loop()
	AudioManager.stop_alarm_loop()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_camera = Camera2D.new()
	_camera.position = Vector2(320, 180)
	_camera.enabled = true
	add_child(_camera)

	# Top Viewport Window (632x148)
	_viewport_win = ViewportWindow.new()
	_viewport_win.position = Vector2(4, 4)
	_viewport_win.size = Vector2(632, 148)
	add_child(_viewport_win)

	# Quick Abort/Back to Assembly button in top-right of viewport
	var btn_abort := Button.new()
	btn_abort.text = "ABORTAR"
	btn_abort.position = Vector2(560, 124)
	btn_abort.size = Vector2(66, 18)
	btn_abort.pressed.connect(func():
		AudioManager.play_sfx("click")
		AudioManager.stop_engine_loop()
		AudioManager.stop_alarm_loop()
		GameState.enter_assembly()
	)
	_viewport_win.add_child(btn_abort)

	# Left Panel: Energía y Sistemas (182x200)
	_power_panel = PowerPanel.new()
	_power_panel.position = Vector2(4, 156)
	_power_panel.size = Vector2(182, 200)
	add_child(_power_panel)

	# Center Console: Navegación (260x200)
	_nav_console = NavigationConsole.new()
	_nav_console.position = Vector2(190, 156)
	_nav_console.size = Vector2(260, 200)
	add_child(_nav_console)

	# Right Panel: Ciencia y Telemetría (182x200)
	_science_panel = SciencePanel.new()
	_science_panel.position = Vector2(454, 156)
	_science_panel.size = Vector2(182, 200)
	add_child(_science_panel)

	# Modal Result Overlay
	_result_overlay = MissionResultOverlay.new()
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_result_overlay)


func _connect_signals() -> void:
	_power_panel.master_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			GameState.active_simulator.set_master_bus(enabled)
	)
	_power_panel.comms_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			GameState.active_simulator.set_comms_bus(enabled)
	)
	_power_panel.science_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			GameState.active_simulator.set_science_bus(enabled)
	)
	_power_panel.panels_deploy_requested.connect(func():
		if GameState.active_simulator:
			GameState.active_simulator.deploy_panels()
	)

	_nav_console.throttle_changed.connect(func(v: float):
		if GameState.active_simulator:
			GameState.active_simulator.set_throttle(v)
	)
	_nav_console.safety_cover_toggled.connect(func():
		if GameState.active_simulator:
			GameState.active_simulator.toggle_safety_cover()
	)
	_nav_console.ignition_pressed.connect(func():
		if GameState.active_simulator:
			GameState.active_simulator.trigger_ignition()
	)

	_science_panel.instrument_activated.connect(func(pid: String):
		if GameState.active_simulator:
			GameState.active_simulator.activate_instrument(pid)
	)

	_result_overlay.retry_requested.connect(func():
		_finished_notified = false
		_result_overlay.visible = false
		GameState.launch_mission()
		if GameState.active_simulator != null:
			_viewport_win.setup(GameState.active_simulator.mission)
			_sync_views(0.0)
	)
	_result_overlay.assembly_requested.connect(func():
		GameState.enter_assembly()
	)
	_result_overlay.menu_requested.connect(func():
		GameState.enter_mission_select()
	)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sim: FlightSimulator = GameState.active_simulator
	if sim == null:
		return

	if sim.telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
		sim.step(delta)
		_sync_views(delta)
		_update_audio_and_shake(sim.telemetry)
	elif not _finished_notified:
		_finished_notified = true
		_sync_views(0.0)
		_camera.offset = Vector2.ZERO
		AudioManager.stop_engine_loop()
		AudioManager.stop_alarm_loop()
		if sim.telemetry.status == FlightTelemetry.Status.VICTORY:
			AudioManager.play_sfx("victory", -2.0)
		else:
			AudioManager.play_sfx("failure", -2.0)
		GameState.notify_flight_finished(sim.telemetry)
		_result_overlay.show_result(sim.telemetry, sim.mission)


func _sync_views(dt: float) -> void:
	var sim: FlightSimulator = GameState.active_simulator
	_viewport_win.update_telemetry(sim.telemetry, dt)
	_power_panel.update_telemetry(sim.telemetry)
	_nav_console.update_telemetry(sim.telemetry, sim.mission)
	_science_panel.update_telemetry(sim)


func _update_audio_and_shake(t: FlightTelemetry) -> void:
	AudioManager.set_engine_loop(t.engine_firing, t.throttle)
	var low_bat: bool = t.battery_max_wh > 0.0 and (t.battery_wh / t.battery_max_wh) < 0.25
	AudioManager.set_alarm_loop(low_bat)

	if t.engine_firing and t.throttle > 0.01:
		var amp: float = 2.5 * t.throttle
		_camera.offset = Vector2(
			roundf(_rng.randf_range(-amp, amp)),
			roundf(_rng.randf_range(-amp, amp))
		)
	else:
		_camera.offset = Vector2.ZERO
