@tool
extends Control
## Phase 3: Spacecraft Assembly Screen (Catalog | Blueprint | Pre-flight Telemetry).

var _selected_category: PartSpec.Category = PartSpec.Category.PROPULSION
var _tab_buttons: Dictionary = {}
var _part_list_vbox: VBoxContainer
var _blueprint_view: ProbeBlueprintView

var _lbl_mission: Label
var _lbl_budget: Label
var _bar_budget: ProgressBar
var _lbl_mass: Label
var _lbl_dv: Label
var _bar_dv: ProgressBar
var _lbl_twr: Label
var _lbl_energy: Label
var _lbl_science: Label
var _lbl_validation: Label
var _btn_launch: Button


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_build_ui()
	if Engine.is_editor_hint():
		var parts := PartCatalog.create_all()
		var preview_mission := MissionCatalog.create_all()[0]
		var preview_design := ProbeDesign.new(parts)
		preview_design.add_part("eng_hydrazine")
		preview_design.add_part("tank_small")
		preview_design.add_part("solar_compact")
		preview_design.add_part("inst_cam")
		_blueprint_view.set_design(preview_design)
		_refresh_catalog_from_list(PartCatalog.create_all(), preview_design)
		_apply_telemetry_values(preview_mission, RocketMath.evaluate_design(preview_design, preview_mission))
		return
	GameState.design_changed.connect(_on_design_changed)
	GameState.mission_selected.connect(_on_mission_selected)
	_refresh_catalog()
	_refresh_telemetry(GameState.last_evaluation)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top Header Bar (y=4..30)
	var header := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
	header.position = Vector2(4, 4)
	header.size = Vector2(632, 28)
	add_child(header)

	var btn_back := Button.new()
	btn_back.text = "< MISIONES"
	btn_back.position = Vector2(6, 4)
	btn_back.size = Vector2(82, 20)
	btn_back.pressed.connect(func():
		AudioManager.play_sfx("click")
		GameState.enter_mission_select()
	)
	header.add_child(btn_back)

	_lbl_mission = Label.new()
	_lbl_mission.position = Vector2(96, 10)
	_lbl_mission.size = Vector2(372, 12)
	_lbl_mission.clip_text = true
	_lbl_mission.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	header.add_child(_lbl_mission)

	var btn_base := Button.new()
	btn_base.text = "AUTO-BASE"
	btn_base.position = Vector2(476, 4)
	btn_base.size = Vector2(78, 20)
	btn_base.pressed.connect(func():
		AudioManager.play_sfx("click")
		GameState.load_recommended_baseline()
	)
	header.add_child(btn_base)

	var btn_clear := Button.new()
	btn_clear.text = "LIMPIAR"
	btn_clear.position = Vector2(558, 4)
	btn_clear.size = Vector2(68, 20)
	btn_clear.pressed.connect(func():
		AudioManager.play_sfx("click")
		GameState.clear_design()
	)
	header.add_child(btn_clear)

	# --- LEFT PANEL: CATALOG (x=4..228, y=36..356) ---
	var left_panel := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
	left_panel.position = Vector2(4, 36)
	left_panel.size = Vector2(224, 320)
	add_child(left_panel)

	var lbl_cat := Label.new()
	lbl_cat.text = "CATÁLOGO DE PIEZAS"
	lbl_cat.position = Vector2(8, 6)
	lbl_cat.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	left_panel.add_child(lbl_cat)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.position = Vector2(6, 20)
	tabs_hbox.size = Vector2(212, 20)
	tabs_hbox.add_theme_constant_override("separation", 2)
	left_panel.add_child(tabs_hbox)

	var tab_defs := [
		[PartSpec.Category.PROPULSION, "PROP"],
		[PartSpec.Category.TANK, "TANQ"],
		[PartSpec.Category.ENERGY, "ENER"],
		[PartSpec.Category.INSTRUMENT, "INST"],
	]
	for td in tab_defs:
		var cat: PartSpec.Category = td[0]
		var btn := Button.new()
		btn.text = td[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_selected_category = cat
			_refresh_catalog()
		)
		tabs_hbox.add_child(btn)
		_tab_buttons[cat] = btn

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 44)
	scroll.size = Vector2(212, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)

	_part_list_vbox = VBoxContainer.new()
	_part_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_part_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_part_list_vbox)

	# --- CENTER PANEL: BLUEPRINT (x=232..438, y=36..356) ---
	var center_panel := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
	center_panel.position = Vector2(232, 36)
	center_panel.size = Vector2(206, 320)
	add_child(center_panel)

	var lbl_bp := Label.new()
	lbl_bp.text = "PLANO DE ENSAMBLAJE"
	lbl_bp.position = Vector2(8, 6)
	lbl_bp.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	center_panel.add_child(lbl_bp)

	var crt_frame := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png")
	crt_frame.position = Vector2(8, 22)
	crt_frame.size = Vector2(190, 268)
	center_panel.add_child(crt_frame)

	_blueprint_view = ProbeBlueprintView.new()
	_blueprint_view.position = Vector2(4, 4)
	_blueprint_view.size = Vector2(182, 260)
	crt_frame.add_child(_blueprint_view)

	var lbl_bp_hint := Label.new()
	lbl_bp_hint.text = "Bus Base: 120 kg | $15,000"
	lbl_bp_hint.position = Vector2(8, 296)
	lbl_bp_hint.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
	center_panel.add_child(lbl_bp_hint)

	# --- RIGHT PANEL: PRE-FLIGHT TELEMETRY (x=442..636, y=36..356) ---
	var right_panel := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
	right_panel.position = Vector2(442, 36)
	right_panel.size = Vector2(194, 320)
	add_child(right_panel)

	var lbl_tel := Label.new()
	lbl_tel.text = "TELEMETRÍA PRE-VUELO"
	lbl_tel.position = Vector2(8, 6)
	lbl_tel.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	right_panel.add_child(lbl_tel)

	var tel_vbox := VBoxContainer.new()
	tel_vbox.position = Vector2(8, 20)
	tel_vbox.size = Vector2(178, 258)
	tel_vbox.add_theme_constant_override("separation", 3)
	right_panel.add_child(tel_vbox)

	_lbl_budget = _add_stat_label(tel_vbox)
	_bar_budget = _add_bar(tel_vbox, 8)
	_lbl_mass = _add_stat_label(tel_vbox)
	_lbl_dv = _add_stat_label(tel_vbox)
	_bar_dv = _add_bar(tel_vbox, 8)
	_lbl_twr = _add_stat_label(tel_vbox)
	_lbl_energy = _add_stat_label(tel_vbox)
	_lbl_science = _add_stat_label(tel_vbox)

	var val_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png")
	val_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	val_box.custom_minimum_size = Vector2(178, 76)
	tel_vbox.add_child(val_box)

	var val_scroll := ScrollContainer.new()
	val_scroll.position = Vector2(5, 5)
	val_scroll.size = Vector2(168, 68)
	val_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	val_scroll.offset_left = 5
	val_scroll.offset_top = 5
	val_scroll.offset_right = -5
	val_scroll.offset_bottom = -5
	val_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	val_box.add_child(val_scroll)

	_lbl_validation = Label.new()
	_lbl_validation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val_scroll.add_child(_lbl_validation)

	_btn_launch = Button.new()
	_btn_launch.text = "LANZAR SONDA >>"
	_btn_launch.position = Vector2(8, 284)
	_btn_launch.size = Vector2(178, 28)
	_btn_launch.pressed.connect(func():
		AudioManager.play_sfx("ignition", -5.0)
		GameState.launch_mission()
	)
	right_panel.add_child(_btn_launch)


func _add_stat_label(parent: Node) -> Label:
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


func _add_bar(parent: Node, height_px: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, height_px)
	bar.show_percentage = false
	parent.add_child(bar)
	return bar


func _refresh_catalog() -> void:
	_refresh_catalog_from_list(MissionData.get_parts_by_category(_selected_category), GameState.current_design)


func _refresh_catalog_from_list(source_parts: Array[PartSpec], design_ref: ProbeDesign) -> void:
	for cat in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cat]
		btn.modulate = ThemeFactory.COL_GREEN if cat == _selected_category else Color.WHITE

	for child in _part_list_vbox.get_children():
		child.queue_free()

	for part in source_parts:
		if part.category != _selected_category:
			continue
		var card := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
		card.custom_minimum_size = Vector2(196, 56)
		_part_list_vbox.add_child(card)

		var tex_rect := TextureRect.new()
		var tex_path := "res://assets/sprites/parts/%s.png" % part.texture_key
		if ResourceLoader.exists(tex_path):
			tex_rect.texture = load(tex_path)
		tex_rect.position = Vector2(5, 6)
		tex_rect.size = Vector2(16, 16)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(tex_rect)

		var lbl_name := Label.new()
		lbl_name.text = part.display_name
		lbl_name.position = Vector2(25, 5)
		lbl_name.size = Vector2(128, 12)
		lbl_name.add_theme_color_override("font_color", ThemeFactory.COL_TEXT)
		card.add_child(lbl_name)

		var lbl_cost := Label.new()
		lbl_cost.text = "$%d" % part.cost
		lbl_cost.position = Vector2(150, 5)
		lbl_cost.size = Vector2(46, 12)
		lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_cost.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
		card.add_child(lbl_cost)

		var lbl_spec := Label.new()
		lbl_spec.text = _format_part_spec(part)
		lbl_spec.position = Vector2(25, 19)
		lbl_spec.size = Vector2(170, 14)
		lbl_spec.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		card.add_child(lbl_spec)

		var count: int = design_ref.get_part_count(part.id) if design_ref != null else 0
		var btn_rem := Button.new()
		btn_rem.text = "-"
		btn_rem.position = Vector2(120, 33)
		btn_rem.size = Vector2(22, 18)
		btn_rem.disabled = count <= 0
		btn_rem.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.remove_part(part.id)
			_refresh_catalog()
		)
		card.add_child(btn_rem)

		var lbl_cnt := Label.new()
		lbl_cnt.text = "%d/%d" % [count, part.max_count]
		lbl_cnt.position = Vector2(144, 38)
		lbl_cnt.size = Vector2(26, 10)
		lbl_cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(lbl_cnt)

		var btn_add := Button.new()
		btn_add.text = "+"
		btn_add.position = Vector2(171, 33)
		btn_add.size = Vector2(22, 18)
		btn_add.disabled = count >= part.max_count
		btn_add.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.add_part(part.id)
			_refresh_catalog()
		)
		card.add_child(btn_add)


func _format_part_spec(part: PartSpec) -> String:
	match part.category:
		PartSpec.Category.PROPULSION:
			return "%.0fkg | %.0fN | Isp %ds" % [part.mass_dry_kg, part.thrust_n, int(part.isp_s)]
		PartSpec.Category.TANK:
			return "Seco %.0fkg | Comb %.0fkg" % [part.mass_dry_kg, part.propellant_kg]
		PartSpec.Category.ENERGY:
			if part.power_gen_w > 0.0:
				return "%.0fkg | +%.0fW @1UA" % [part.mass_dry_kg, part.power_gen_w]
			return "%.0fkg | %.0fWh Bat" % [part.mass_dry_kg, part.battery_wh]
		PartSpec.Category.INSTRUMENT:
			return "%.0fkg | -%.0fW | +%d pts" % [part.mass_dry_kg, part.power_draw_w, part.science_value]
	return ""


func _on_mission_selected(_mission: MissionSpec) -> void:
	_refresh_telemetry(GameState.last_evaluation)


func _on_design_changed(evaluation: Dictionary) -> void:
	_refresh_telemetry(evaluation)
	_refresh_catalog()


func _refresh_telemetry(ev: Dictionary) -> void:
	if _blueprint_view != null:
		_blueprint_view.set_design(GameState.current_design)

	_apply_telemetry_values(GameState.current_mission, ev)


func _apply_telemetry_values(mission: MissionSpec, ev: Dictionary) -> void:
	if mission == null or ev.is_empty():
		return

	_lbl_mission.text = "%s | Δv %.0f m/s | %.2f UA" % [mission.subtitle, mission.required_delta_v, mission.distance_au]

	var cost: int = int(ev.get("cost", 0))
	var rem: int = int(ev.get("budget_remaining", 0))
	_lbl_budget.text = "PRESUP: $%d / $%d" % [cost, mission.budget]
	_lbl_budget.add_theme_color_override("font_color", ThemeFactory.COL_RED if rem < 0 else ThemeFactory.COL_TEXT)
	_bar_budget.max_value = float(mission.budget)
	_bar_budget.value = clampf(float(cost), 0.0, float(mission.budget))

	_lbl_mass.text = "MASA: %.0fkg (S:%.0f + C:%.0f)" % [
		float(ev.get("wet_mass_kg", 0.0)),
		float(ev.get("dry_mass_kg", 0.0)),
		float(ev.get("propellant_kg", 0.0)),
	]

	var dv: float = float(ev.get("delta_v", 0.0))
	_lbl_dv.text = "Δv DISP: %.0f / %.0f m/s" % [dv, mission.required_delta_v]
	var dv_ok: bool = dv >= (mission.required_delta_v - mission.delta_v_tolerance)
	_lbl_dv.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if dv_ok else ThemeFactory.COL_AMBER)
	_bar_dv.max_value = maxf(mission.required_delta_v * 1.4, 1.0)
	_bar_dv.value = clampf(dv, 0.0, _bar_dv.max_value)

	var twr: float = float(ev.get("twr", 0.0))
	_lbl_twr.text = "TWR: %.2f (Mín %.2f)" % [twr, mission.min_twr]

	var gen_w: float = float(ev.get("solar_gen_w", 0.0))
	var draw_w: float = float(ev.get("power_draw_w", 0.0))
	var net_w: float = float(ev.get("net_power_w", 0.0))
	var bat_wh: float = float(ev.get("battery_wh", 0.0))
	_lbl_energy.text = "ENER: +%.0fW -%.0fW (Neto %+.0fW)\nBATERÍA: %.0f Wh" % [gen_w, draw_w, net_w, bat_wh]
	_lbl_energy.add_theme_color_override("font_color", ThemeFactory.COL_GREEN if net_w >= 0.0 else ThemeFactory.COL_AMBER)

	_lbl_science.text = "CIENCIA MÁXIMA: %d pts" % int(ev.get("max_science", 0))
	_lbl_science.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)

	var errors: Array = ev.get("errors", [])
	var warnings: Array = ev.get("warnings", [])
	var lines: PackedStringArray = []
	for err in errors:
		lines.append("[X] " + str(err))
	for warn in warnings:
		lines.append("[!] " + str(warn))
	if lines.is_empty():
		lines.append("[OK] Sonda certificada para lanzamiento.")
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	elif not errors.is_empty():
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	else:
		_lbl_validation.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	_lbl_validation.text = "\n".join(lines)

	_btn_launch.disabled = not bool(ev.get("valid_for_launch", false))
