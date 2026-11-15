@tool
extends Control
## Container layout and contextual keyboard/mouse assembly controls.

enum CatalogTab { LAUNCH_VEHICLE, PROPULSION, TANK, ENERGY, COMMS, INSTRUMENT }
var _selected_tab: CatalogTab = CatalogTab.LAUNCH_VEHICLE
var _selected_index: int = 0
var _tab_buttons: Dictionary = {}
var _catalog_entries: Array = []
var _catalog_cards: Array[PanelContainer] = []
var _catalog_descriptions: Array[Label] = []
var _catalog_scroll: ScrollContainer
var _part_list_vbox: VBoxContainer
var _blueprint_view: ProbeBlueprintView
var _header: PanelContainer
var _body: HBoxContainer
var _lbl_mission: Label
var _lbl_budget: Label
var _bar_budget: ProgressBar
var _lbl_mass: Label
var _lbl_dv: Label
var _bar_dv: ProgressBar
var _lbl_twr_orb: Label
var _lbl_energy: Label
var _lbl_comms: Label
var _lbl_objectives: Label
var _lbl_nasa: Label
var _lbl_validation: Label
var _btn_missions: Button
var _btn_nasa: Button
var _btn_help: Button
var _btn_lang: Button
var _btn_base: Button
var _btn_clear: Button
var _col_headings: Array[Label] = []
var _preview_hint: Label
var _hint_lbl: Label
var _btn_launch: Button
var _btn_auto: Button
var _nasa_modal: PanelContainer
var _nasa_scroll: ScrollContainer
var _nasa_title: Label
var _nasa_text: Label
var _nasa_tab_report: Button
var _nasa_tab_gmat: Button
var _nasa_btn_export: Button
var _nasa_btn_close: Button
var _nasa_export_status: Label
var _nasa_gmat_mode: bool = false
var _last_mission: MissionSpec
var _last_design: ProbeDesign


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_build_ui()
	_refresh_static_texts()
	if Engine.is_editor_hint():
		var design := ProbeDesign.new(PartCatalog.create_all(), LaunchVehicleCatalog.create_all()[0])
		for pid in ["eng_hydrazine", "tank_small", "solar_compact", "bat_liion", "inst_cam"]:
			design.add_part(pid)
		var editor_mission := MissionCatalog.create_all()[0]
		_last_mission = editor_mission
		_last_design = design
		_blueprint_view.set_design(design)
		_populate_catalog(LaunchVehicleCatalog.create_all(), design)
		_apply_telemetry_values(editor_mission, RocketMath.evaluate_design(design, editor_mission))
		return
	GameState.design_changed.connect(_on_design_changed)
	GameState.mission_selected.connect(_on_mission_selected)
	GameState.language_changed.connect(_on_language_changed)
	_refresh_catalog()
	_refresh_telemetry(GameState.last_evaluation)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.COL_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 6
	margin.offset_top = 6
	margin.offset_right = -6
	margin.offset_bottom = -6
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)
	_header = PanelContainer.new()
	root.add_child(_header)
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	_header.add_child(header_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	header_box.add_child(actions)
	_btn_missions = _action(actions, "MISIONES [ESC]", KEY_ESCAPE, func(): GameState.enter_mission_select())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_btn_nasa = _action(actions, "NASA CML [N]", KEY_NONE, func(): _toggle_nasa_modal())
	_btn_help = _action(actions, "AYUDA [F1]", KEY_NONE, func(): GameState.learning_requested.emit())
	_btn_lang = _action(actions, "ES / EN [F2]", KEY_F2, func(): GameState.toggle_language())
	_btn_base = _action(actions, "BASE [B]", KEY_B, func(): GameState.load_recommended_baseline())
	_btn_clear = _action(actions, "LIMPIAR [L]", KEY_L, func(): GameState.clear_design())
	_lbl_mission = _add_stat_label(header_box)
	_lbl_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_mission.clip_text = false
	_lbl_mission.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	root.add_child(_body)
	var left := _column("CATÁLOGO / EQUIPOS", 1.12)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	left.add_child(tabs)
	for index in range(6):
		var button := Button.new()
		button.custom_minimum_size.y = 24
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", ThemeFactory.control_style(Color("142333"), Color("40556d")))
		button.pressed.connect(func(): _switch_tab(index))
		tabs.add_child(button)
		_tab_buttons[index] = button
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_catalog_scroll)
	_part_list_vbox = VBoxContainer.new()
	_part_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_part_list_vbox.add_theme_constant_override("separation", 4)
	_catalog_scroll.add_child(_part_list_vbox)
	var center := _column("DISEÑO / COFIA", 1.0)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(frame)
	_blueprint_view = ProbeBlueprintView.new()
	_blueprint_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blueprint_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_blueprint_view)
	_preview_hint = _add_stat_label(center)
	_preview_hint.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
	var right := _column("BALANCE DE MISIÓN", 1.08)
	_lbl_budget = _add_stat_label(right)
	_bar_budget = _add_bar(right)
	_lbl_mass = _add_stat_label(right)
	_lbl_dv = _add_stat_label(right)
	_bar_dv = _add_bar(right)
	_lbl_twr_orb = _add_stat_label(right)
	_lbl_energy = _add_stat_label(right)
	_lbl_comms = _add_stat_label(right)
	_lbl_objectives = _add_stat_label(right)
	_lbl_nasa = _add_stat_label(right)
	var diagnostic := PanelContainer.new()
	diagnostic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagnostic.custom_minimum_size.y = 48
	right.add_child(diagnostic)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	diagnostic.add_child(scroll)
	_lbl_validation = _add_stat_label(scroll)
	_lbl_validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_validation.clip_text = false
	_btn_launch = _action(right, "MANUAL [F5]", KEY_F5, func(): GameState.launch_mission())
	_btn_auto = _action(right, "AUTOMÁTICO [F6]", KEY_F6, func(): GameState.launch_mission(true))
	_hint_lbl = _add_stat_label(root)
	_hint_lbl.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
	_build_nasa_modal()


func _build_nasa_modal() -> void:
	_nasa_modal = PanelContainer.new()
	_nasa_modal.visible = false
	_nasa_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nasa_modal.offset_left = 48
	_nasa_modal.offset_top = 36
	_nasa_modal.offset_right = -48
	_nasa_modal.offset_bottom = -36
	_nasa_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_nasa_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_nasa_modal.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	_nasa_title = _add_stat_label(top)
	_nasa_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	_nasa_tab_report = _action(top, "INFORME CML", KEY_NONE, func():
		_nasa_gmat_mode = false
		_refresh_nasa_modal()
	)
	_nasa_tab_gmat = _action(top, "GMAT .script", KEY_NONE, func():
		_nasa_gmat_mode = true
		_refresh_nasa_modal()
	)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(frame)
	_nasa_scroll = ScrollContainer.new()
	_nasa_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_nasa_scroll)
	_nasa_text = Label.new()
	_nasa_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nasa_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nasa_scroll.add_child(_nasa_text)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	box.add_child(bottom)
	_nasa_export_status = _add_stat_label(bottom)
	_nasa_export_status.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	_nasa_btn_export = _action(bottom, "EXPORTAR GMAT", KEY_NONE, func(): _export_gmat_script())
	_nasa_btn_close = _action(bottom, "CERRAR [ESC]", KEY_NONE, func(): _toggle_nasa_modal(false))


func _toggle_nasa_modal(force_open: Variant = null) -> void:
	var target: bool = (not _nasa_modal.visible) if force_open == null else bool(force_open)
	_nasa_modal.visible = target
	if target:
		_nasa_export_status.text = ""
		_refresh_nasa_modal()
		_nasa_scroll.scroll_vertical = 0
		_nasa_btn_close.grab_focus()


func _export_gmat_script() -> void:
	var mission: MissionSpec = _last_mission if Engine.is_editor_hint() else GameState.current_mission
	var design: ProbeDesign = _last_design if Engine.is_editor_hint() else GameState.current_design
	if mission == null or design == null:
		return
	var script_body: String = NasaMissionFramework.generate_gmat_script(design, mission)
	var file_path: String = "user://gmat_%s.script" % mission.id
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(script_body)
		file.close()
		_nasa_export_status.text = Loc.pick("Guardado: %s", "Saved: %s") % file_path
		_nasa_export_status.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_nasa_export_status.text = Loc.pick("No se pudo escribir %s", "Failed to write %s") % file_path
		_nasa_export_status.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(script_body)


func _refresh_nasa_modal() -> void:
	if _nasa_modal == null:
		return
	var mission: MissionSpec = _last_mission if Engine.is_editor_hint() else GameState.current_mission
	var design: ProbeDesign = _last_design if Engine.is_editor_hint() else GameState.current_design
	_nasa_title.text = Loc.pick(
		"INGENIERÍA NASA (JPL CML / 4 SEGMENTOS / CUBESAT 101 / GMAT)",
		"NASA ENGINEERING (JPL CML / 4 SEGMENTS / CUBESAT 101 / GMAT)"
	)
	_nasa_tab_report.text = Loc.pick("INFORME CML", "CML REPORT")
	_nasa_tab_gmat.text = Loc.pick("SCRIPT GMAT", "GMAT SCRIPT")
	_nasa_btn_export.text = Loc.pick("EXPORTAR .script", "EXPORT .script")
	_nasa_btn_close.text = Loc.pick("CERRAR [ESC]", "CLOSE [ESC]")
	_nasa_tab_report.add_theme_stylebox_override("normal", ThemeFactory.control_style(Color("12392f") if not _nasa_gmat_mode else Color("142333"), ThemeFactory.COL_GREEN if not _nasa_gmat_mode else Color("40556d")))
	_nasa_tab_gmat.add_theme_stylebox_override("normal", ThemeFactory.control_style(Color("12392f") if _nasa_gmat_mode else Color("142333"), ThemeFactory.COL_GREEN if _nasa_gmat_mode else Color("40556d")))
	if mission == null or design == null:
		return
	if _nasa_gmat_mode:
		_nasa_text.text = NasaMissionFramework.generate_gmat_script(design, mission)
	else:
		_nasa_text.text = NasaMissionFramework.format_summary_report(design, mission)


func _refresh_static_texts() -> void:
	_btn_missions.text = Loc.pick("MISIONES [ESC]", "MISSIONS [ESC]")
	_btn_nasa.text = Loc.pick("NASA CML [N]", "NASA CML [N]")
	_btn_nasa.tooltip_text = Loc.pick(
		"Abrir informe NASA JPL CML 1-5, 4 segmentos, CubeSat 101 y generador GMAT R2026a (.script).",
		"Open NASA JPL CML 1-5, 4 segments, CubeSat 101 & GMAT R2026a (.script) generator."
	)
	_btn_help.text = Loc.pick("AYUDA [F1]", "HELP [F1]")
	_btn_lang.text = Loc.pick("ES / EN [F2]", "EN / ES [F2]")
	_btn_base.text = Loc.pick("BASE [B]", "BASE [B]")
	_btn_clear.text = Loc.pick("LIMPIAR [L]", "CLEAR [L]")
	var col_titles: Array[String] = [
		Loc.pick("CATÁLOGO / EQUIPOS", "PARTS CATALOG"),
		Loc.pick("DISEÑO / COFIA", "BLUEPRINT / FAIRING"),
		Loc.pick("BALANCE DE MISIÓN", "MISSION BALANCE"),
	]
	for idx in range(mini(_col_headings.size(), col_titles.size())):
		_col_headings[idx].text = col_titles[idx]
	var tab_names: Array[String] = [
		Loc.pick("COH", "L/V"),
		"PROP",
		Loc.pick("TANQ", "TANK"),
		Loc.pick("ENER", "PWR"),
		"COMM",
		"INST",
	]
	for idx in range(6):
		if _tab_buttons.has(idx):
			_tab_buttons[idx].text = tab_names[idx]
			_tab_buttons[idx].tooltip_text = Loc.pick(
				"Categoría %d: %s. Teclas 1-6 o flechas izquierda/derecha.",
				"Category %d: %s. Keys 1-6 or Left/Right arrows."
			) % [idx + 1, tab_names[idx]]
	_preview_hint.text = Loc.pick("RUEDA ZOOM | ARRASTRAR", "WHEEL ZOOM | DRAG PAN")
	_preview_hint.tooltip_text = Loc.pick(
		"Rueda: ampliar/reducir. Arrastrar: mover la nave. Clic central: centrar. Bus: 120 kg/$15000; radio base: 18 kbps.",
		"Wheel: zoom. Drag: pan probe view. Middle click: reset. Core bus: 120 kg/$15000; base radio: 18 kbps."
	)
	_btn_launch.text = Loc.pick("MANUAL [F5]", "MANUAL [F5]")
	_btn_auto.text = Loc.pick("AUTOMÁTICO [F6]", "AUTOPILOT [F6]")
	_btn_auto.tooltip_text = Loc.pick(
		"Operar este diseño con piloto automático [F6]. BASE [B] carga una configuración recomendada.",
		"Operate this design with autopilot [F6]. BASE [B] loads a recommended configuration."
	)
	_hint_lbl.text = Loc.pick(
		"1-6 TIPO | FLECHAS EQUIPO | +/- CANTIDAD | N NASA/GMAT | F2 IDIOMA | TAB FOCO",
		"1-6 TYPE | ARROWS PART | +/- COUNT | N NASA/GMAT | F2 LANG | TAB FOCUS"
	)
	_refresh_nasa_modal()


func _column(title: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.clip_contents = true
	_body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var heading := _add_stat_label(box)
	heading.text = title
	heading.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	_col_headings.append(heading)
	return box


func _action(parent: Node, caption: String, key: Key, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 26
	button.pressed.connect(func():
		if not Engine.is_editor_hint():
			AudioManager.play_sfx("click")
			callback.call()
	)
	if key != KEY_NONE:
		ThemeFactory.bind_shortcut(button, key)
	parent.add_child(button)
	return button


func _add_stat_label(parent: Node) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.custom_minimum_size.y = 16
	parent.add_child(label)
	return label


func _add_bar(parent: Node) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 4
	bar.show_percentage = false
	parent.add_child(bar)
	return bar


func _switch_tab(index: int) -> void:
	_selected_tab = posmod(index, 6) as CatalogTab
	_selected_index = 0
	_catalog_scroll.scroll_vertical = 0
	_refresh_catalog()


func _refresh_catalog() -> void:
	if Engine.is_editor_hint():
		return
	var source: Array = MissionData.get_all_launch_vehicles() if _selected_tab == CatalogTab.LAUNCH_VEHICLE else MissionData.get_parts_by_category((_selected_tab - 1) as PartSpec.Category)
	_populate_catalog(source, GameState.current_design)


func _populate_catalog(source: Array, design: ProbeDesign) -> void:
	for child in _part_list_vbox.get_children():
		_part_list_vbox.remove_child(child)
		child.queue_free()
	_catalog_entries = source
	_catalog_cards.clear()
	_catalog_descriptions.clear()
	_selected_index = clampi(_selected_index, 0, maxi(source.size() - 1, 0))
	for key in _tab_buttons:
		_tab_buttons[key].add_theme_stylebox_override("normal", ThemeFactory.control_style(Color("12392f") if int(key) == int(_selected_tab) else Color("142333"), ThemeFactory.COL_GREEN if int(key) == int(_selected_tab) else Color("40556d")))
	for index in range(source.size()):
		var entry = source[index]
		var is_lv: bool = entry is LaunchVehicleSpec
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		card.tooltip_text = entry.description + "\n" + Loc.pick(
			"Clic: seleccionar. Doble clic: equipar. Derecho: quitar. Rueda: desplazar lista; sobre +/- cambia cantidad.",
			"Click: select. Double click: equip. Right click: remove. Wheel: scroll; over +/- adjusts count."
		)
		card.gui_input.connect(func(event: InputEvent): _card_input(event, index, card))
		_part_list_vbox.add_child(card)
		_catalog_cards.append(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = ThemeFactory.get_catalog_icon(entry.id if is_lv else entry.texture_key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_label := _add_stat_label(row)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_text = false
		name_label.text = entry.display_name
		if not is_lv and not Engine.is_editor_hint() and GameState.current_mission.required_instruments.has(entry.id):
			name_label.text = "* " + name_label.text
			name_label.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
		var spec := _add_stat_label(box)
		spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec.clip_text = false
		spec.text = Loc.pick("%.0f kg | %d mód. | +%.0f m/s", "%.0f kg | %d mod | +%.0f m/s") % [entry.max_payload_kg, entry.max_fairing_modules, entry.injection_dv_ms] if is_lv else _format_part_spec(entry)
		spec.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		var description := _add_stat_label(box)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.clip_text = false
		description.text = entry.description
		description.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		description.visible = index == _selected_index
		_catalog_descriptions.append(description)
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 3)
		box.add_child(controls)
		var cost := _add_stat_label(controls)
		cost.text = "$%d" % entry.cost
		cost.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
		if is_lv:
			var active: bool = design.get_launch_vehicle() != null and design.get_launch_vehicle().id == entry.id
			var select := _action(controls, Loc.pick("ACTIVO", "ACTIVE") if active else Loc.pick("ELEGIR", "SELECT"), KEY_NONE, func(): _adjust_count(1, index))
			select.disabled = active
		else:
			var count: int = design.get_part_count(entry.id)
			var minus := _action(controls, "-", KEY_NONE, func(): _adjust_count(-1, index))
			minus.disabled = count <= 0
			var quantity := _add_stat_label(controls)
			quantity.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			quantity.clip_text = false
			quantity.text = "%d/%d" % [count, entry.max_count]
			var plus := _action(controls, "+", KEY_NONE, func(): _adjust_count(1, index))
			plus.disabled = count >= entry.max_count
			for button in [minus, plus]:
				button.tooltip_text = Loc.pick(
					"Clic: cambiar cantidad. Rueda arriba/abajo: añadir/quitar. Teclado: + y -.",
					"Click: adjust count. Wheel up/down: add/remove. Keys: + and -."
				)
				button.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
						button.accept_event()
						_adjust_count(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, index)
				)
	_apply_selection()


func _card_input(event: InputEvent, index: int, card: Control) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		card.accept_event()
		_selected_index = index
		_apply_selection()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_adjust_count(-1)
		elif event.double_click:
			_adjust_count(1)


func _adjust_count(delta: int, index: int = -1) -> void:
	if Engine.is_editor_hint() or _catalog_entries.is_empty():
		return
	if index >= 0:
		_selected_index = index
	var entry = _catalog_entries[_selected_index]
	if entry is LaunchVehicleSpec:
		if delta > 0:
			GameState.set_launch_vehicle(entry.id)
	elif delta > 0:
		GameState.add_part(entry.id)
	else:
		GameState.remove_part(entry.id)


func _apply_selection() -> void:
	for index in range(_catalog_cards.size()):
		_catalog_cards[index].add_theme_stylebox_override("panel", ThemeFactory.control_style(Color("0b1c23"), ThemeFactory.COL_CYAN if index == _selected_index else Color("27404c")))
		_catalog_descriptions[index].visible = index == _selected_index
	call_deferred("_ensure_selection_visible")


func _ensure_selection_visible() -> void:
	if is_inside_tree() and not _catalog_cards.is_empty():
		_catalog_scroll.ensure_control_visible(_catalog_cards[_selected_index])


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or get_tree().paused:
		return
	var key: int = event.keycode
	if _nasa_modal != null and _nasa_modal.visible:
		match key:
			KEY_ESCAPE, KEY_N:
				_toggle_nasa_modal(false)
			KEY_UP:
				_nasa_scroll.scroll_vertical -= 18
			KEY_DOWN:
				_nasa_scroll.scroll_vertical += 18
			KEY_PAGEUP:
				_nasa_scroll.scroll_vertical -= int(_nasa_scroll.size.y) - 18
			KEY_PAGEDOWN:
				_nasa_scroll.scroll_vertical += int(_nasa_scroll.size.y) - 18
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if key == KEY_N:
		_toggle_nasa_modal()
	elif key >= KEY_1 and key <= KEY_6:
		_switch_tab(key - KEY_1)
	elif key in [KEY_UP, KEY_DOWN]:
		_selected_index = clampi(_selected_index + (-1 if key == KEY_UP else 1), 0, maxi(0, _catalog_entries.size() - 1))
		_apply_selection()
	elif key in [KEY_LEFT, KEY_RIGHT]:
		_switch_tab(int(_selected_tab) + (-1 if key == KEY_LEFT else 1))
	elif key in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		_adjust_count(-1 if key in [KEY_MINUS, KEY_KP_SUBTRACT] else 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_mission_selected(_mission: MissionSpec) -> void:
	_refresh_telemetry(GameState.last_evaluation)
	_refresh_catalog()


func _on_design_changed(evaluation: Dictionary) -> void:
	_refresh_telemetry(evaluation)
	_refresh_catalog()


func _on_language_changed(_lang: String) -> void:
	_refresh_static_texts()
	_refresh_catalog()
	_refresh_telemetry(GameState.last_evaluation)


func _refresh_telemetry(evaluation: Dictionary) -> void:
	_last_mission = GameState.current_mission
	_last_design = GameState.current_design
	_blueprint_view.set_design(_last_design)
	_apply_telemetry_values(_last_mission, evaluation)


func _format_part_spec(part: PartSpec) -> String:
	match part.category:
		PartSpec.Category.PROPULSION:
			return "%.0fkg|%ds|%.0fW" % [part.mass_dry_kg, int(part.isp_s), part.power_draw_w]
		PartSpec.Category.TANK:
			return "S:%.0f C:%.0fkg" % [part.mass_dry_kg, part.propellant_kg]
		PartSpec.Category.ENERGY:
			if part.power_gen_w > 0.0:
				return "%.0fkg | +%.0fW" % [part.mass_dry_kg, part.power_gen_w]
			return "%.0fkg | %.0fWh" % [part.mass_dry_kg, part.battery_wh]
		PartSpec.Category.COMMS:
			return "%.0fkg|-%.0fW|+%.0fkb" % [part.mass_dry_kg, part.power_draw_w, part.comms_kbps]
		PartSpec.Category.INSTRUMENT:
			return "-%.0fW|%.0fMB|+%dpt" % [part.power_draw_w, part.data_volume_mb, part.science_value]
	return ""


func _apply_telemetry_values(mission: MissionSpec, ev: Dictionary) -> void:
	if mission == null or ev.is_empty():
		return

	_lbl_mission.text = "%s | %s" % [mission.subtitle, mission.objective_summary]
	_lbl_mission.tooltip_text = _lbl_mission.text

	# 1. Unified Budget (Launch Vehicle + Bus + Subsystems + Instruments)
	var cost: int = int(ev.get("cost", 0))
	var rem: int = int(ev.get("budget_remaining", 0))
	_lbl_budget.text = Loc.pick("PRESUP: $%d / $%d", "BUDGET: $%d / $%d") % [cost, mission.budget]
	_lbl_budget.add_theme_color_override("font_color", ThemeFactory.COL_RED if rem < 0 else ThemeFactory.COL_TEXT)
	_bar_budget.max_value = float(mission.budget)
	_bar_budget.value = clampf(float(cost), 0.0, float(mission.budget))

	# 2. Wet Mass & Fairing Modules vs Launch Vehicle Structural Limits
	var wet_kg: float = float(ev.get("wet_mass_kg", 0.0))
	var max_kg: float = float(ev.get("max_payload_kg", 9999.0))
	var mod_cnt: int = int(ev.get("module_count", 0))
	var max_mod: int = int(ev.get("max_fairing_modules", 99))
	var mass_over: bool = (wet_kg > max_kg) or (mod_cnt > max_mod)
	_lbl_mass.text = Loc.pick("MASA:%.0f/%.0fkg | COF:%d/%d", "MASS:%.0f/%.0fkg | FAIR:%d/%d") % [wet_kg, max_kg, mod_cnt, max_mod]
	_lbl_mass.add_theme_color_override("font_color", ThemeFactory.COL_RED if mass_over else ThemeFactory.COL_TEXT)

	# 3. Total Mission Δv (Probe Tsiolkovski + Rocket Upper-Stage Injection)
	var total_dv: float = float(ev.get("total_delta_v", 0.0))
	var inj_dv: float = float(ev.get("injection_dv", 0.0))
	_lbl_dv.text = Loc.pick("Δv:%.0f/%.0fm/s (+%.0fCOH)", "Δv:%.0f/%.0fm/s (+%.0fLV)") % [total_dv, mission.required_delta_v, inj_dv]
	var dv_ok: bool = total_dv >= (mission.required_delta_v - mission.delta_v_tolerance)
	_lbl_dv.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if dv_ok else ThemeFactory.COL_AMBER)
	_bar_dv.max_value = maxf(mission.required_delta_v * 1.4, 1.0)
	_bar_dv.value = clampf(total_dv, 0.0, _bar_dv.max_value)

	# 4. Orbital Constraints & Thrust-to-Weight Ratio
	var twr: float = float(ev.get("twr", 0.0))
	var ga_b: float = mission.gravity_assist_dv_bonus if mission.has_gravity_assist else 0.0
	_lbl_twr_orb.text = Loc.pick("TWR:%.2f | %.2fUA | GA:+%.0f", "TWR:%.2f | %.2fAU | GA:+%.0f") % [twr, mission.distance_au, ga_b]
	_lbl_twr_orb.add_theme_color_override(
		"font_color",
		ThemeFactory.COL_AMBER if (twr > 0.0 and twr < mission.min_twr) else ThemeFactory.COL_MUTED
	)

	# 5. Solar & Battery Energy Balance at Target AU
	var gen_w: float = float(ev.get("solar_gen_w", 0.0))
	var draw_w: float = float(ev.get("power_draw_w", 0.0))
	var net_w: float = float(ev.get("net_power_w", 0.0))
	var bat_wh: float = float(ev.get("battery_wh", 0.0))
	_lbl_energy.text = Loc.pick("SOL:+%.0f/-%.0fW | BAT:%.0fWh", "SUN:+%.0f/-%.0fW | BAT:%.0fWh") % [gen_w, draw_w, bat_wh]
	_lbl_energy.tooltip_text = Loc.pick(
		"Crucero: %.0f W. Motor al 100%%: %.0f W. La batería cubre el déficit. W es potencia; Wh es energía almacenada.",
		"Cruise: %.0f W. Engine 100%%: %.0f W. Battery covers deficit. W is power; Wh is stored energy."
	) % [draw_w, float(ev.get("burn_power_draw_w", draw_w))]
	_lbl_energy.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if net_w >= 0.0 else ThemeFactory.COL_AMBER)

	# 6. Deep-Space Communications Downlink & Payload Data Volume
	var eff_kbps: float = float(ev.get("comms_kbps", 18.0))
	var data_mb: float = float(ev.get("total_data_mb", 0.0))
	var tx_s: float = float(ev.get("est_tx_time_s", 0.0))
	_lbl_comms.text = "COM:%.1fkbps | %.0fMB (~%.0fs)" % [eff_kbps, data_mb, tx_s]
	_lbl_comms.tooltip_text = Loc.pick(
		"Tierra: %.6f UA. Sol: %.2f UA. Descarga física: %.0f s; juego: %.2f s (datos x%.0f). Tasa compartida, HGA óptima.",
		"Earth: %.6f AU. Sun: %.2f AU. Physical TX: %.0f s; game: %.2f s (data x%.0f). Shared rate, HGA optimal."
	) % [mission.earth_distance_au, mission.distance_au, float(ev.get("est_tx_physical_s", 0.0)), tx_s, RocketMath.DATA_SECONDS_PER_GAME_SECOND]
	_lbl_comms.add_theme_color_override(
		"font_color",
		ThemeFactory.COL_AMBER if (data_mb > 0.0 and tx_s > mission.transit_duration_s * 0.18) else ThemeFactory.COL_CYAN
	)

	# 7. Mission Scientific Objectives & NASA CML / Team X Margins
	var max_sci: int = int(ev.get("max_science", 0))
	var min_sci: int = int(ev.get("min_science_required", 0))
	_lbl_objectives.text = Loc.pick("OBJETIVO: %d / %d pts mín", "OBJECTIVE: %d / %d min pts") % [max_sci, min_sci]
	_lbl_objectives.add_theme_color_override(
		"font_color",
		ThemeFactory.COL_GREEN if max_sci >= min_sci else ThemeFactory.COL_RED
	)
	var design_ref: ProbeDesign = _last_design if Engine.is_editor_hint() else GameState.current_design
	var nasa: Dictionary = NasaMissionFramework.assess(design_ref, mission)
	if not nasa.is_empty():
		var m_nasa: Dictionary = nasa["margins"]
		_lbl_nasa.text = Loc.pick(
			"NASA %s | M:%.0f%% P:%.0f%% RF:%+.1fdB",
			"NASA %s | M:%.0f%% P:%.0f%% RF:%+.1fdB"
		) % [
			nasa["cml_short"],
			float(m_nasa["mass_margin_pct"]),
			float(m_nasa["power_margin_pct"]),
			float(m_nasa["link_margin_db"]),
		]
		_lbl_nasa.tooltip_text = Loc.pick(
			"JPL %s | Clase: %s | Pulsar N para 4 Segmentos NASA y Script GMAT.",
			"JPL %s | Class: %s | Press N for NASA 4 Segments & GMAT Script."
		) % [nasa["cml_label"], nasa["form_factor"]]
		var cml_lvl: int = int(nasa["cml_level"])
		_lbl_nasa.add_theme_color_override(
			"font_color",
			ThemeFactory.COL_GREEN if cml_lvl >= 4 else (ThemeFactory.COL_AMBER if cml_lvl >= 2 else ThemeFactory.COL_RED)
		)
	if _nasa_modal != null and _nasa_modal.visible:
		_refresh_nasa_modal()

	# 8. Scrollable Systems Engineering Audit Terminal
	var errors: Array = ev.get("errors", [])
	var warnings: Array = ev.get("warnings", [])
	var lines: PackedStringArray = []
	lines.append(Loc.pick("LANZADOR: %s ($%d)", "LAUNCHER: %s ($%d)") % [str(ev.get("launch_vehicle_short", "-")), int(ev.get("lv_cost", 0))])
	for err in errors:
		lines.append("[X] " + str(err))
	for warn in warnings:
		lines.append("[!] " + str(warn))
	if errors.is_empty() and warnings.is_empty():
		lines.append(Loc.pick(
			"[OK] Exigencias equilibradas: misión certificada para despegue.",
			"[OK] Balanced demands: mission certified for launch."
		))
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	elif not errors.is_empty():
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	else:
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	_lbl_validation.text = "\n".join(lines)

	_btn_launch.disabled = not bool(ev.get("valid_for_launch", false))
	_btn_auto.disabled = _btn_launch.disabled
