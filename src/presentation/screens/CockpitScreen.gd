@tool
extends Control
## Phase 4: Interactive Virtual Cockpit hosting ViewportWindow, PowerPanel,
## NavigationConsole (Attitude ACS + Trajectory/Propulsion), SciencePanel,
## keyboard flight controls, Camera2D screen shake, and MissionResultOverlay.

var _camera: Camera2D
var _viewport_win: ViewportWindow
var _power_panel: PowerPanel
var _nav_console: NavigationConsole
var _science_panel: SciencePanel
var _result_overlay: MissionResultOverlay
var _btn_auto: Button
var _lbl_auto: Label
var _btn_view: Button
var _btn_cam: Button
var _btn_help: Button
var _btn_abort: Button
var _btn_lang: Button
var _lbl_summary_head: Label
var _lbl_ops_head: Label
var _lbl_ops_hint: Label
var _guidance_visible: bool = true
var _internal_view: bool = false
var _deck_frame: Control
var _control_dock: HBoxContainer
var _lbl_mission_status: Label
var _lbl_cabin_alert: Label
var _progress_bar: ProgressBar

var _rng := RandomNumberGenerator.new()
var _finished_notified: bool = false
var _prev_phase: FlightTelemetry.FlightPhase = FlightTelemetry.FlightPhase.CRUISE_COAST
var _prev_engine_firing: bool = false
var _prev_braking: bool = false
var _prev_throttle: float = 0.0
var _prev_panels_deployed: bool = false
var _prev_attitude_mode: FlightTelemetry.AttitudeMode = FlightTelemetry.AttitudeMode.PROGRADE
var _prev_safety_cover: bool = false
var _prev_in_insertion: bool = false
var _separation_sfx_played: bool = false
var _prev_captured_count: int = 0
var _prev_transmitted_count: int = 0
var _rcs_sfx_cooldown_s: float = 0.0
var _turbo_sfx_cooldown_s: float = 0.0
var _key_ccw_held: bool = false
var _key_cw_held: bool = false


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_rng.randomize()
	_build_ui()
	if Engine.is_editor_hint():
		var parts := PartCatalog.create_all()
		var preview_mission := MissionCatalog.create_all()[2]
		var preview_design := ProbeDesign.new(parts)
		preview_design.add_part("eng_ion")
		preview_design.add_part("tank_large")
		preview_design.add_part("solar_wing")
		preview_design.add_part("bat_liion")
		preview_design.add_part("inst_spec")
		preview_design.add_part("inst_radar")
		var preview_sim := FlightSimulator.new(preview_mission, preview_design)
		preview_sim.deploy_panels()
		_viewport_win.setup(preview_mission, preview_sim.design)
		_viewport_win.update_telemetry(preview_sim.telemetry, 0.0)
		_power_panel.update_telemetry(preview_sim.telemetry)
		_nav_console.update_telemetry(preview_sim.telemetry, preview_mission)
		_science_panel.update_telemetry(preview_sim)
		return
	_connect_signals()
	if GameState.active_simulator != null:
		_reset_audio_tracking(GameState.active_simulator.telemetry)
		_viewport_win.setup(GameState.active_simulator.mission, GameState.active_simulator.design)
		_sync_views(0.0)
	_layout_flight()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	AudioManager.stop_engine_loop()
	AudioManager.stop_cruise_loop()
	AudioManager.stop_alarm_loop()
	AudioManager.set_internal_audio_mode(false)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.COL_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_camera = Camera2D.new()
	_camera.position = get_viewport_rect().size * 0.5
	add_child(_camera)
	_viewport_win = ViewportWindow.new()
	add_child(_viewport_win)
	_deck_frame = Control.new()
	add_child(_deck_frame)
	_control_dock = HBoxContainer.new()
	_control_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_control_dock.add_theme_constant_override("separation", 6)
	_deck_frame.add_child(_control_dock)
	var summary := _deck_card("CONTROL DE MISIÓN", 1.0)
	_lbl_summary_head = summary.get_child(0) as Label
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 5
	_progress_bar.max_value = 1.0
	_progress_bar.show_percentage = false
	summary.add_child(_progress_bar)
	_lbl_mission_status = _deck_label(summary)
	_lbl_auto = _deck_label(summary)
	_lbl_auto.custom_minimum_size.y = 30
	_lbl_auto.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	_lbl_cabin_alert = _deck_label(summary)
	_lbl_cabin_alert.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	# Preserve the compact physical instruments at exact 1:1 native 8px pixel scale.
	var compact_theme := ThemeFactory.get_theme().duplicate() as Theme
	var compact_font: Font = ThemeFactory.get_compact_font()
	var compact_size: int = ThemeFactory.get_compact_font_size()
	if compact_font != null:
		compact_theme.default_font = compact_font
	compact_theme.default_font_size = compact_size
	compact_theme.set_constant("line_spacing", "Label", 1)
	for kind in ["Label", "Button", "PopupMenu", "TooltipLabel"]:
		compact_theme.set_font_size("font_size", kind, compact_size)
	_power_panel = PowerPanel.new()
	_power_panel.custom_minimum_size = Vector2(166, 208)
	_power_panel.theme = compact_theme
	_control_dock.add_child(_power_panel)
	_nav_console = NavigationConsole.new()
	_nav_console.custom_minimum_size = Vector2(292, 208)
	_nav_console.theme = compact_theme
	_control_dock.add_child(_nav_console)
	_science_panel = SciencePanel.new()
	_science_panel.custom_minimum_size = Vector2(166, 208)
	_science_panel.theme = compact_theme
	_control_dock.add_child(_science_panel)
	var actions := _deck_card("OPERACIÓN / ATAJOS", 1.15)
	_lbl_ops_head = actions.get_child(0) as Label
	var ops_header := HBoxContainer.new()
	ops_header.add_theme_constant_override("separation", 4)
	actions.remove_child(_lbl_ops_head)
	_lbl_ops_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ops_header.add_child(_lbl_ops_head)
	_btn_lang = _deck_button(ops_header, "ES/EN", func():
		if not Engine.is_editor_hint():
			GameState.toggle_language()
	)
	_btn_lang.size_flags_horizontal = Control.SIZE_SHRINK_END
	_btn_lang.custom_minimum_size = Vector2(56, 20)
	actions.add_child(ops_header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 4)
	actions.add_child(grid)
	_btn_auto = _deck_button(grid, "AUTO [M]", _toggle_automatic)
	_btn_view = _deck_button(grid, "AYUDAS ON [V]", func(): set_guidance_visible(not _guidance_visible))
	_btn_help = _deck_button(grid, "AYUDA [F1]", func(): GameState.learning_requested.emit())
	_btn_abort = _deck_button(grid, "ABORTAR", func(): GameState.enter_assembly())
	_btn_cam = _deck_button(actions, "VISTA: EXT [K]", func(): set_internal_view(not _internal_view))
	_btn_cam.custom_minimum_size.y = 22
	var hint_scroll := ScrollContainer.new()
	hint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(hint_scroll)
	_lbl_ops_hint = _deck_label(hint_scroll)
	_lbl_ops_hint.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
	_result_overlay = MissionResultOverlay.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_frame.add_child(_result_overlay)
	_refresh_static_texts()
	resized.connect(_layout_flight)
	_layout_flight()


func _refresh_static_texts() -> void:
	_lbl_summary_head.text = Loc.pick("CONTROL DE MISIÓN", "MISSION CONTROL")
	_lbl_ops_head.text = Loc.pick("OPERACIÓN / ATAJOS", "OPS / SHORTCUTS")
	_btn_lang.text = Loc.pick("ES/EN", "EN/ES")
	_btn_help.text = Loc.pick("AYUDA [F1]", "HELP [F1]")
	_btn_abort.text = Loc.pick("ABORTAR", "ABORT")
	_btn_view.text = Loc.pick(
		"AYUDAS ON [V]" if _guidance_visible else "AYUDAS OFF [V]",
		"GUIDES ON [V]" if _guidance_visible else "GUIDES OFF [V]"
	)
	_btn_view.tooltip_text = Loc.pick(
		"Ocultar/mostrar brújula y explicaciones sin cambiar la proporción escena/cabina.",
		"Show/hide compass & overlays without resizing scene vs cockpit deck."
	)
	_btn_cam.text = Loc.pick(
		"VISTA: INT [K]" if _internal_view else "VISTA: EXT [K]",
		"VIEW: INT [K]" if _internal_view else "VIEW: EXT [K]"
	)
	_btn_cam.tooltip_text = Loc.pick(
		"Alternar entre vista espacial externa y vista interna por el ventanal de tu modelo de nave.",
		"Switch between external 2.5D space view and first-person internal cabin view."
	)
	_lbl_ops_hint.text = Loc.pick(
		"A/D girar | 1-5 orientar | K vista\nW/Q o rueda: empuje | T turbo\nC tapa | Espacio motor | X cero\nP paneles | R RCS | S estabilizar\nClic: apuntar | Der.: estabilizar",
		"A/D turn | 1-5 orient | K view\nW/Q or wheel: thrust | T turbo\nC cover | Space burn | X zero\nP panels | R RCS | S hold\nClick: aim | Right: hold"
	)


func _deck_card(title: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.clip_contents = true
	_control_dock.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var heading := _deck_label(box)
	heading.text = title
	heading.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	return box


func _deck_label(parent: Node) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _deck_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 24
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _layout_flight() -> void:
	if _viewport_win == null or _deck_frame == null:
		return
	var layout := FlightLayout.calculate(size)
	_viewport_win.position = layout["scene"].position
	_viewport_win.size = layout["scene"].size
	_deck_frame.position = layout["deck"].position
	_deck_frame.size = layout["deck"].size
	_camera.position = get_viewport_rect().size * 0.5


func get_layout_snapshot() -> Dictionary:
	return {"scene": _viewport_win.get_rect(), "deck": _deck_frame.get_rect()}


func _connect_signals() -> void:
	_viewport_win.gui_input.connect(_scene_mouse_input)
	GameState.learning_requested.connect(_release_held_rotation)
	GameState.language_changed.connect(func(_lang: String):
		_refresh_static_texts()
		if GameState.active_simulator != null:
			_sync_views(0.0)
	)
	_power_panel.master_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_master_bus(enabled)
	)
	_power_panel.comms_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_comms_bus(enabled)
	)
	_power_panel.science_toggled.connect(func(enabled: bool):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_science_bus(enabled)
	)
	_power_panel.panels_deploy_requested.connect(func():
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.deploy_panels()
	)

	_nav_console.throttle_changed.connect(func(v: float):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_throttle(v)
	)
	_nav_console.safety_cover_toggled.connect(func():
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.toggle_safety_cover()
	)
	_nav_console.ignition_pressed.connect(func():
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.trigger_ignition()
	)
	_nav_console.attitude_mode_requested.connect(func(mode: int):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_attitude_mode(mode as FlightTelemetry.AttitudeMode)
	)
	_nav_console.manual_rotation_changed.connect(func(turn_dir: float):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.set_manual_rotation(turn_dir)
	)
	_nav_console.attitude_nudged.connect(func(dir: float):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.nudge_attitude(dir)
	)
	_nav_console.stabilize_requested.connect(func():
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.stabilize_attitude()
	)
	_nav_console.rcs_toggled.connect(func():
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.toggle_rcs()
	)

	_science_panel.instrument_activated.connect(func(pid: String):
		if GameState.active_simulator:
			_take_manual_control()
			GameState.active_simulator.activate_instrument(pid)
	)

	_result_overlay.retry_requested.connect(func():
		_finished_notified = false
		_key_ccw_held = false
		_key_cw_held = false
		_result_overlay.visible = false
		GameState.launch_mission(GameState.active_simulator.automatic_enabled)
	)
	_result_overlay.assembly_requested.connect(func():
		GameState.enter_assembly()
	)
	_result_overlay.menu_requested.connect(func():
		GameState.enter_mission_select()
	)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or get_tree().paused or not event is InputEventKey:
		return
	var sim: FlightSimulator = GameState.active_simulator
	if sim == null or sim.telemetry.status != FlightTelemetry.Status.IN_FLIGHT:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if event.pressed and not event.echo and key in [KEY_M, KEY_V, KEY_K, KEY_ESCAPE]:
		match key:
			KEY_M: _toggle_automatic()
			KEY_V: set_guidance_visible(not _guidance_visible)
			KEY_K:
				if not Engine.is_editor_hint():
					AudioManager.play_sfx("click", -6.0)
				set_internal_view(not _internal_view)
			KEY_ESCAPE: GameState.learning_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT]:
		if event.pressed:
			_take_manual_control()
		if key in [KEY_A, KEY_LEFT]:
			_key_ccw_held = event.pressed
		else:
			_key_cw_held = event.pressed
		sim.set_manual_rotation((-1.0 if _key_ccw_held else 0.0) + (1.0 if _key_cw_held else 0.0))
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if key in [KEY_W, KEY_UP, KEY_Q, KEY_DOWN]:
		var prev_thr: float = sim.telemetry.throttle
		_change_throttle(0.10 if key in [KEY_W, KEY_UP] else -0.10)
		if sim.telemetry.throttle >= 0.95 and prev_thr < 0.95 and _turbo_sfx_cooldown_s <= 0.0:
			AudioManager.play_sfx("turbo", -4.0)
			_turbo_sfx_cooldown_s = 0.45
		elif absf(sim.telemetry.throttle - prev_thr) > 0.005:
			AudioManager.play_sfx("click", -9.0)
	elif not event.echo and key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_S, KEY_R, KEY_P, KEY_C, KEY_SPACE, KEY_T, KEY_X, KEY_F2, KEY_F3, KEY_F4, KEY_F7, KEY_F8, KEY_F9]:
		_take_manual_control()
		match key:
			KEY_1:
				AudioManager.play_sfx("servo", -6.0)
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.PROGRADE)
			KEY_2:
				AudioManager.play_sfx("servo", -6.0)
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.RETROGRADE)
			KEY_3:
				AudioManager.play_sfx("servo", -6.0)
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.SOLAR)
			KEY_4:
				AudioManager.play_sfx("servo", -6.0)
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.EARTH)
			KEY_5:
				AudioManager.play_sfx("servo", -6.0)
				sim.set_attitude_mode(FlightTelemetry.AttitudeMode.TARGET)
			KEY_S:
				AudioManager.play_sfx("telemetry", -5.0)
				sim.stabilize_attitude()
			KEY_R:
				AudioManager.play_sfx("switch", -5.0)
				sim.toggle_rcs()
			KEY_P:
				sim.deploy_panels()
			KEY_C:
				AudioManager.play_sfx("switch", -5.0)
				sim.toggle_safety_cover()
			KEY_SPACE:
				if not sim.telemetry.safety_cover_open:
					AudioManager.play_sfx("click", -5.0)
				sim.trigger_ignition()
			KEY_T:
				if not sim.telemetry.safety_cover_open:
					sim.toggle_safety_cover()
				sim.set_throttle(1.0)
				if not sim.telemetry.engine_firing:
					sim.trigger_ignition()
				if _turbo_sfx_cooldown_s <= 0.0:
					AudioManager.play_sfx("turbo", -3.0)
					_turbo_sfx_cooldown_s = 0.45
			KEY_X:
				if sim.telemetry.engine_firing:
					AudioManager.play_sfx("cutoff", -5.0)
				else:
					AudioManager.play_sfx("switch", -5.0)
				sim.set_throttle(0.0)
			KEY_F2:
				AudioManager.play_sfx("switch", -5.0)
				sim.set_master_bus(not sim.telemetry.master_bus_on)
			KEY_F3:
				AudioManager.play_sfx("switch", -5.0)
				sim.set_comms_bus(not sim.telemetry.comms_on)
			KEY_F4:
				AudioManager.play_sfx("switch", -5.0)
				sim.set_science_bus(not sim.telemetry.science_bus_on)
			KEY_F7:
				AudioManager.play_sfx("click", -5.0)
				sim.activate_instrument("inst_cam")
			KEY_F8:
				AudioManager.play_sfx("click", -5.0)
				sim.activate_instrument("inst_spec")
			KEY_F9:
				AudioManager.play_sfx("click", -5.0)
				sim.activate_instrument("inst_radar")
	else:
		return
	_sync_views(0.0)
	get_viewport().set_input_as_handled()


func _scene_mouse_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var sim: FlightSimulator = GameState.active_simulator
	if sim == null or sim.telemetry.status != FlightTelemetry.Status.IN_FLIGHT or not _viewport_win.is_space_position(event.position):
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			_change_throttle((0.01 if event.shift_pressed else 0.05) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
		MOUSE_BUTTON_LEFT:
			_take_manual_control()
			sim.point_attitude(_viewport_win.mouse_attitude(event.position))
		MOUSE_BUTTON_RIGHT:
			_take_manual_control()
			sim.stabilize_attitude()
		MOUSE_BUTTON_MIDDLE:
			set_guidance_visible(not _guidance_visible)
		_:
			return
	_sync_views(0.0)
	_viewport_win.accept_event()


func _change_throttle(delta: float) -> void:
	var sim: FlightSimulator = GameState.active_simulator
	if sim == null:
		return
	var value: float = sim.telemetry.throttle + delta
	_take_manual_control()
	sim.set_throttle(value)
	_sync_views(0.0)


func _release_held_rotation() -> void:
	if _key_ccw_held or _key_cw_held:
		_key_ccw_held = false
		_key_cw_held = false
		if GameState.active_simulator:
			GameState.active_simulator.set_manual_rotation(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and not Engine.is_editor_hint():
		_release_held_rotation()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sim: FlightSimulator = GameState.active_simulator
	if sim == null:
		return

	if sim.telemetry.status == FlightTelemetry.Status.IN_FLIGHT:
		sim.step(delta)
		if sim.telemetry.flight_phase != _prev_phase:
			_prev_phase = sim.telemetry.flight_phase
			if _prev_phase == FlightTelemetry.FlightPhase.ORBITAL_INSERTION or _prev_phase == FlightTelemetry.FlightPhase.GRAVITY_ASSIST:
				AudioManager.play_sfx("telemetry", -4.0)
		_sync_views(delta)
		_update_audio_and_shake(sim.telemetry, delta)
	elif not _finished_notified:
		_finished_notified = true
		_control_dock.visible = false
		_sync_views(0.0)
		_camera.offset = Vector2.ZERO
		AudioManager.stop_engine_loop()
		AudioManager.stop_cruise_loop()
		AudioManager.stop_alarm_loop()
		if sim.telemetry.status == FlightTelemetry.Status.VICTORY:
			AudioManager.play_sfx("victory", -2.0)
		else:
			AudioManager.play_sfx("failure", -2.0)
		GameState.notify_flight_finished(sim.telemetry)
		_result_overlay.show_result(sim.telemetry, sim.mission)
	else:
		# Keep the captured orbit or failure drift visible after the simulation stops.
		_viewport_win.update_telemetry(sim.telemetry, delta)


func set_guidance_visible(enabled: bool) -> void:
	_guidance_visible = enabled
	_viewport_win.set_guidance_visible(enabled)
	_btn_view.text = Loc.pick(
		"AYUDAS ON [V]" if enabled else "AYUDAS OFF [V]",
		"GUIDES ON [V]" if enabled else "GUIDES OFF [V]"
	)


func set_internal_view(enabled: bool) -> void:
	_internal_view = enabled
	_viewport_win.set_internal_view(enabled)
	if not Engine.is_editor_hint():
		AudioManager.set_internal_audio_mode(enabled)
	_btn_cam.text = Loc.pick(
		"VISTA: INT [K]" if enabled else "VISTA: EXT [K]",
		"VIEW: INT [K]" if enabled else "VIEW: EXT [K]"
	)


func _sync_views(dt: float) -> void:
	var sim: FlightSimulator = GameState.active_simulator
	_btn_auto.text = Loc.pick(
		"AUTO: ON [M]" if sim.automatic_enabled else "AUTO: OFF [M]",
		"AUTO: ON [M]" if sim.automatic_enabled else "AUTO: OFF [M]"
	)
	_btn_auto.disabled = sim.telemetry.status != FlightTelemetry.Status.IN_FLIGHT
	_lbl_auto.text = sim.automatic_action
	_lbl_auto.tooltip_text = sim.automatic_action
	_progress_bar.value = sim.telemetry.progress_norm
	_lbl_mission_status.text = Loc.pick(
		"%s\nCIENCIA %d / %d pts\nTRAYECTO %d%% | TCM %.1f km",
		"%s\nSCIENCE %d / %d pts\nCRUISE %d%% | TCM %.1f km"
	) % [sim.mission.target_name, sim.telemetry.science_score, sim.telemetry.science_min_required, int(sim.telemetry.progress_norm * 100.0), sim.telemetry.trajectory_error_km]
	_lbl_cabin_alert.text = " | ".join(sim.telemetry.active_alerts) if not sim.telemetry.active_alerts.is_empty() else Loc.pick("Sistemas nominales", "Systems nominal")
	_viewport_win.update_telemetry(sim.telemetry, dt)
	_power_panel.update_telemetry(sim.telemetry)
	_nav_console.update_telemetry(sim.telemetry, sim.mission)
	_science_panel.update_telemetry(sim)


func _toggle_automatic() -> void:
	if GameState.active_simulator:
		_key_ccw_held = false
		_key_cw_held = false
		GameState.active_simulator.set_automatic_enabled(not GameState.active_simulator.automatic_enabled)
		_sync_views(0.0)


func _take_manual_control() -> void:
	if GameState.active_simulator and GameState.active_simulator.automatic_enabled:
		GameState.active_simulator.set_automatic_enabled(false)


func _reset_audio_tracking(t: FlightTelemetry) -> void:
	_prev_phase = t.flight_phase
	_prev_engine_firing = t.engine_firing
	_prev_braking = t.engine_firing and absf(RocketMath.shortest_angle_diff_deg(t.attitude_deg, FlightSimulator.ANGLE_RETROGRADE)) <= 45.0
	_prev_throttle = t.throttle
	_prev_panels_deployed = t.panels_deployed
	_prev_attitude_mode = t.attitude_mode
	_prev_safety_cover = t.safety_cover_open
	_prev_in_insertion = t.in_insertion_window
	_separation_sfx_played = false
	if not Engine.is_editor_hint():
		AudioManager.set_internal_audio_mode(_internal_view)
	_prev_captured_count = t.instruments_captured.size()
	_prev_transmitted_count = t.instruments_transmitted.size()
	_rcs_sfx_cooldown_s = 0.0
	_turbo_sfx_cooldown_s = 0.0


func _update_audio_and_shake(t: FlightTelemetry, dt: float) -> void:
	_rcs_sfx_cooldown_s = maxf(0.0, _rcs_sfx_cooldown_s - dt)
	_turbo_sfx_cooldown_s = maxf(0.0, _turbo_sfx_cooldown_s - dt)

	var is_braking: bool = t.engine_firing and absf(RocketMath.shortest_angle_diff_deg(t.attitude_deg, FlightSimulator.ANGLE_RETROGRADE)) <= 45.0
	var cruise_speed_factor: float = clampf(0.25 + t.progress_norm * 0.65 - (0.18 if is_braking else 0.0), 0.15, 1.0)
	AudioManager.set_cruise_loop(t.status == FlightTelemetry.Status.IN_FLIGHT, cruise_speed_factor)
	AudioManager.set_engine_loop(t.engine_firing, t.throttle, is_braking)
	var alarm_active: bool = (t.system_state == FlightTelemetry.SystemState.CRITICAL)
	AudioManager.set_alarm_loop(alarm_active)

	if t.engine_firing and not _prev_engine_firing:
		if is_braking:
			AudioManager.play_sfx("brake", -4.0)
		else:
			AudioManager.play_sfx("ignition", -5.0)
		if t.throttle >= 0.95 and _turbo_sfx_cooldown_s <= 0.0:
			AudioManager.play_sfx("turbo", -4.0)
			_turbo_sfx_cooldown_s = 0.45
	elif t.engine_firing and _prev_engine_firing:
		if is_braking and not _prev_braking:
			AudioManager.play_sfx("brake", -4.5)
		if t.throttle >= 0.95 and _prev_throttle < 0.95 and _turbo_sfx_cooldown_s <= 0.0:
			AudioManager.play_sfx("turbo", -4.0)
			_turbo_sfx_cooldown_s = 0.45
	elif not t.engine_firing and _prev_engine_firing:
		AudioManager.play_sfx("cutoff", -5.0)

	if t.rcs_active_jets != 0 and _rcs_sfx_cooldown_s <= 0.0:
		AudioManager.play_sfx("rcs", -10.5)
		_rcs_sfx_cooldown_s = 0.18
	if t.attitude_mode != _prev_attitude_mode:
		AudioManager.play_sfx("servo", -8.0)
	if t.panels_deployed and not _prev_panels_deployed:
		AudioManager.play_sfx("deploy", -5.0)
	if t.safety_cover_open != _prev_safety_cover:
		AudioManager.play_sfx("cover", -6.0)
	if t.in_insertion_window and not _prev_in_insertion:
		AudioManager.play_sfx("window_alert", -4.0)
	if not _separation_sfx_played and t.elapsed_s >= 0.35 and t.progress_norm < 0.08:
		_separation_sfx_played = true
		AudioManager.play_sfx("separation", -5.0)

	var captured_now: int = t.instruments_captured.size()
	if captured_now > _prev_captured_count:
		AudioManager.play_sfx("science", -4.0)
	var transmitted_now: int = t.instruments_transmitted.size()
	if transmitted_now > _prev_transmitted_count:
		AudioManager.play_sfx("telemetry", -3.0)

	_prev_engine_firing = t.engine_firing
	_prev_braking = is_braking
	_prev_throttle = t.throttle
	_prev_panels_deployed = t.panels_deployed
	_prev_attitude_mode = t.attitude_mode
	_prev_safety_cover = t.safety_cover_open
	_prev_in_insertion = t.in_insertion_window
	_prev_captured_count = captured_now
	_prev_transmitted_count = transmitted_now

	if t.engine_firing and t.throttle > 0.01:
		var amp: float = (3.2 if t.wrong_burn_direction else 2.2) * t.throttle
		_camera.offset = Vector2(
			roundf(_rng.randf_range(-amp, amp)),
			roundf(_rng.randf_range(-amp, amp))
		)
	elif t.is_tumbling and not t.is_controlled_slew():
		_camera.offset = Vector2(
			roundf(_rng.randf_range(-1.0, 1.0)),
			roundf(_rng.randf_range(-1.0, 1.0))
		)
	else:
		_camera.offset = Vector2.ZERO
