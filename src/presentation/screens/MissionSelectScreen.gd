@tool
extends Control
## Mission selection and campaign briefing screen with container-driven cards
## and scrollable CRT mission briefing terminals presenting all 9 engineering demands.

var _cards_hbox: HBoxContainer
var _title_lbl: Label
var _btn_profile: Button
var _help_btn: Button
var _btn_lang: Button
var _btn_mute: Button
var _hint_lbl: Label

var _planet_views: Array[Dictionary] = []
var _spin_time: float = 0.0

var _profile_backdrop: ColorRect
var _profile_title: Label
var _profile_sub: Label
var _lbl_name: Label
var _lbl_user: Label
var _input_name: LineEdit
var _input_user: LineEdit
var _lbl_profile_err: Label
var _btn_create_profile: Button
var _btn_close_profile: Button
var _lbl_existing_profiles: Label
var _profiles_list_vbox: VBoxContainer
var _mission_buttons: Array[Button] = []


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_build_ui()
	_refresh_texts()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String): _refresh_texts())
		GameState.profile_changed.connect(func(_p: Dictionary): _refresh_texts())
		if not GameState.has_active_profile():
			_open_profile_modal()


func _process(delta: float) -> void:
	if not visible:
		return
	_spin_time += delta
	for entry in _planet_views:
		var view: PlanetBodyView = entry.get("view")
		if is_instance_valid(view):
			view.update_body(str(entry.get("palette", "earth")), 17.0, _spin_time)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _profile_backdrop != null and _profile_backdrop.visible and event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE and GameState.has_active_profile():
			_close_profile_modal()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg := _SpaceBackdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 6
	margin.offset_top = 6
	margin.offset_right = -6
	margin.offset_bottom = -6
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var header := PanelContainer.new()
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header.add_child(header_row)
	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.clip_text = true
	_title_lbl.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	header_row.add_child(_title_lbl)
	_btn_profile = Button.new()
	_btn_profile.custom_minimum_size.y = 26
	if not Engine.is_editor_hint():
		ThemeFactory.bind_shortcut(_btn_profile, KEY_U)
		_btn_profile.pressed.connect(func():
			AudioManager.play_sfx("click")
			_open_profile_modal()
		)
	header_row.add_child(_btn_profile)
	_help_btn = Button.new()
	_help_btn.custom_minimum_size.y = 26
	_help_btn.pressed.connect(func():
		if not Engine.is_editor_hint():
			GameState.learning_requested.emit()
	)
	header_row.add_child(_help_btn)
	_btn_lang = Button.new()
	_btn_lang.custom_minimum_size.y = 26
	if not Engine.is_editor_hint():
		ThemeFactory.bind_shortcut(_btn_lang, KEY_F2)
		_btn_lang.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.toggle_language()
		)
	header_row.add_child(_btn_lang)
	_btn_mute = Button.new()
	_btn_mute.custom_minimum_size.y = 26
	if not Engine.is_editor_hint():
		ThemeFactory.bind_shortcut(_btn_mute, KEY_F10)
		_btn_mute.pressed.connect(func():
			AudioManager.set_muted(not AudioManager.is_muted())
			_update_mute_label()
		)
	header_row.add_child(_btn_mute)
	_cards_hbox = HBoxContainer.new()
	_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_hbox.add_theme_constant_override("separation", 6)
	root.add_child(_cards_hbox)
	_hint_lbl = Label.new()
	_hint_lbl.clip_text = true
	_hint_lbl.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	root.add_child(_hint_lbl)
	_build_profile_modal()


func _build_profile_modal() -> void:
	_profile_backdrop = ColorRect.new()
	_profile_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile_backdrop.color = Color(0.02, 0.04, 0.08, 0.86)
	_profile_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_backdrop.visible = false
	add_child(_profile_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile_backdrop.add_child(center)

	var modal := PanelContainer.new()
	modal.custom_minimum_size = Vector2(450, 320)
	center.add_child(modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	modal.add_child(vbox)

	_profile_title = Label.new()
	_profile_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	vbox.add_child(_profile_title)

	_profile_sub = Label.new()
	_profile_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_sub.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
	vbox.add_child(_profile_sub)

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 8)
	form.add_theme_constant_override("v_separation", 6)
	vbox.add_child(form)

	_lbl_name = Label.new()
	_lbl_name.custom_minimum_size.x = 120
	form.add_child(_lbl_name)
	_input_name = LineEdit.new()
	_input_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_input_name)

	_lbl_user = Label.new()
	_lbl_user.custom_minimum_size.x = 120
	form.add_child(_lbl_user)
	_input_user = LineEdit.new()
	_input_user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_input_user)

	_lbl_profile_err = Label.new()
	_lbl_profile_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_profile_err.add_theme_color_override("font_color", ThemeFactory.COL_RED)
	_lbl_profile_err.visible = false
	vbox.add_child(_lbl_profile_err)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_btn_create_profile = Button.new()
	_btn_create_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_create_profile.custom_minimum_size.y = 28
	_btn_create_profile.pressed.connect(_on_create_profile_pressed)
	btn_row.add_child(_btn_create_profile)

	_btn_close_profile = Button.new()
	_btn_close_profile.custom_minimum_size = Vector2(110, 28)
	_btn_close_profile.pressed.connect(_close_profile_modal)
	btn_row.add_child(_btn_close_profile)

	_lbl_existing_profiles = Label.new()
	_lbl_existing_profiles.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	vbox.add_child(_lbl_existing_profiles)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 78)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_profiles_list_vbox = VBoxContainer.new()
	_profiles_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profiles_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_profiles_list_vbox)


func _open_profile_modal() -> void:
	_lbl_profile_err.visible = false
	_profile_backdrop.visible = true
	_refresh_profile_modal_texts()
	_set_card_buttons_disabled(true)
	if is_inside_tree():
		_input_name.grab_focus()


func _close_profile_modal() -> void:
	if not Engine.is_editor_hint() and not GameState.has_active_profile():
		return
	_profile_backdrop.visible = false
	_set_card_buttons_disabled(false)


func _set_card_buttons_disabled(disabled: bool) -> void:
	for btn in _mission_buttons:
		if is_instance_valid(btn):
			btn.disabled = disabled


func _on_create_profile_pressed() -> void:
	if Engine.is_editor_hint():
		return
	var res: Dictionary = GameState.register_profile(_input_name.text, _input_user.text)
	if not bool(res.get("ok", false)):
		_lbl_profile_err.text = str(res.get("error", Loc.pick("Datos inválidos.", "Invalid profile data.")))
		_lbl_profile_err.visible = true
		return
	AudioManager.play_sfx("click")
	_input_name.text = ""
	_input_user.text = ""
	_lbl_profile_err.visible = false
	_close_profile_modal()


func _refresh_profile_modal_texts() -> void:
	_profile_title.text = Loc.pick(
		"REGISTRO DE COMANDANTE (SIN CONTRASEÑA)",
		"COMMANDER PROFILE (NO PASSWORD)"
	)
	_profile_sub.text = Loc.pick(
		"Ingresa solo tu nombre y username para guardar tus misiones, CML, insignias y diseños en este equipo.",
		"Enter only your name and username to save your campaign progress, CML, badges, and designs locally."
	)
	_lbl_name.text = Loc.pick("NOMBRE:", "NAME:")
	_lbl_user.text = Loc.pick("USERNAME:", "USERNAME:")
	_input_name.placeholder_text = Loc.pick("Ej. Elena Vance", "e.g. Elena Vance")
	_input_user.placeholder_text = Loc.pick("Ej. evance (mín. 2: a-z, 0-9, _,-)", "e.g. evance (min 2: a-z, 0-9, _,-)")
	_btn_create_profile.text = Loc.pick("CREAR PERFIL Y CONTINUAR", "CREATE PROFILE & CONTINUE")
	_btn_close_profile.text = Loc.pick("CERRAR [ESC]", "CLOSE [ESC]")
	_lbl_existing_profiles.text = Loc.pick("PERFILES GUARDADOS:", "SAVED PROFILES:")
	if not Engine.is_editor_hint():
		_btn_close_profile.visible = GameState.has_active_profile()
		for c in _profiles_list_vbox.get_children():
			c.queue_free()
		var list: Array[Dictionary] = GameState.get_all_profiles()
		if list.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = Loc.pick("Aún no hay perfiles guardados.", "No saved profiles yet.")
			empty_lbl.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
			_profiles_list_vbox.add_child(empty_lbl)
		else:
			for prof in list:
				var uname: String = str(prof.get("username", ""))
				var dname: String = str(prof.get("display_name", ""))
				var comp_count: int = (prof.get("completed_missions", {}) as Dictionary).size()
				var is_cur: bool = (uname == GameState.active_username)
				var pbtn := Button.new()
				pbtn.text = ("%s (@%s) — %d/3" % [dname, uname, comp_count]) + (Loc.pick(" [ACTIVO]", " [ACTIVE]") if is_cur else "")
				pbtn.custom_minimum_size.y = 24
				pbtn.pressed.connect(func():
					AudioManager.play_sfx("click")
					GameState.switch_profile(uname)
					_close_profile_modal()
				)
				_profiles_list_vbox.add_child(pbtn)


func _refresh_texts() -> void:
	_title_lbl.text = Loc.pick("MISIÓN CRÍTICA / ELIGE TU DESTINO", "CRITICAL MISSION / SELECT DESTINATION")
	_help_btn.text = Loc.pick("AYUDA [F1]", "HELP [F1]")
	_btn_lang.text = Loc.pick("ES / EN [F2]", "EN / ES [F2]")
	_hint_lbl.text = Loc.pick(
		"1-3 ELEGIR MISIÓN | U PERFIL | F2 IDIOMA | TAB FOCO | INTRO CONFIRMAR",
		"1-3 PICK MISSION | U PROFILE | F2 LANG | TAB FOCUS | ENTER CONFIRM"
	)
	if not Engine.is_editor_hint():
		_update_mute_label()
		if GameState.has_active_profile():
			var p: Dictionary = GameState.get_active_profile()
			_btn_profile.text = Loc.pick("PILOTO: @%s [U]", "PILOT: @%s [U]") % str(p.get("username", ""))
			_btn_profile.tooltip_text = "%s (@%s)" % [str(p.get("display_name", "")), str(p.get("username", ""))]
		else:
			_btn_profile.text = Loc.pick("CREAR PERFIL [U]", "CREATE PROFILE [U]")
			_btn_profile.tooltip_text = ""
	else:
		_btn_profile.text = "PILOT @demo [U]"
		_btn_mute.text = "AUDIO [F10]"
	_populate_missions()
	_refresh_profile_modal_texts()
	if _profile_backdrop != null:
		_set_card_buttons_disabled(_profile_backdrop.visible)


func _populate_missions() -> void:
	_planet_views.clear()
	_mission_buttons.clear()
	for child in _cards_hbox.get_children():
		child.queue_free()

	var missions: Array[MissionSpec] = MissionCatalog.create_all() if Engine.is_editor_hint() else MissionData.get_all_missions()
	var lvs_fallback: Array[LaunchVehicleSpec] = LaunchVehicleCatalog.create_all() if Engine.is_editor_hint() else MissionData.get_all_launch_vehicles()

	for mission in missions:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		_cards_hbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var lbl_title := Label.new()
		lbl_title.text = mission.title
		lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
		vbox.add_child(lbl_title)

		var sub_hbox := HBoxContainer.new()
		vbox.add_child(sub_hbox)

		var lbl_sub := Label.new()
		lbl_sub.text = {
			"earth": "LEO 420 km",
			"moon": Loc.pick("LUNA", "MOON"),
			"mars": Loc.pick("MARTE", "MARS"),
		}.get(mission.target_palette, mission.target_name)
		lbl_sub.tooltip_text = mission.target_name
		lbl_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_sub.clip_text = true
		lbl_sub.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		sub_hbox.add_child(lbl_sub)

		var lbl_diff := Label.new()
		lbl_diff.text = "[%s]" % mission.difficulty
		lbl_diff.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
		sub_hbox.add_child(lbl_diff)

		# Preview uses containers so the animated body and statistics cannot overlap.
		var preview := PanelContainer.new()
		vbox.add_child(preview)
		var preview_row := HBoxContainer.new()
		preview_row.add_theme_constant_override("separation", 6)
		preview.add_child(preview_row)
		var planet_frame := Control.new()
		planet_frame.custom_minimum_size = Vector2(46, 46)
		planet_frame.clip_contents = true
		planet_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_row.add_child(planet_frame)
		var planet_view := PlanetBodyView.new()
		planet_view.palette = mission.target_palette
		planet_view.radius = 17.0
		planet_view.position = Vector2(23, 23)
		planet_frame.add_child(planet_view)
		_planet_views.append({"view": planet_view, "palette": mission.target_palette})
		var stats := Label.new()
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.text = Loc.pick(
			"$%s\nΔv %.0f m/s\nCIENCIA %d pts\nSOL %.2f UA\nVUELO %d s",
			"$%s\nΔv %.0f m/s\nSCIENCE %d pts\nSUN %.2f AU\nFLIGHT %d s"
		) % [_format_thousands(mission.budget), mission.required_delta_v, mission.min_science_required, mission.distance_au, int(mission.transit_duration_s)]
		stats.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		stats.tooltip_text = Loc.pick(
			"Tierra: %.6f UA. Honda: +%.0f m/s. %s",
			"Earth: %.6f AU. Assist: +%.0f m/s. %s"
		) % [mission.earth_distance_au, mission.gravity_assist_dv_bonus, mission.target_name]
		preview_row.add_child(stats)

		# Scrollable Briefing Terminal (Objectives, Recommended Launcher, and Mission Brief)
		var brief_panel := Panel.new()
		brief_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		brief_panel.custom_minimum_size = Vector2(0, 68)
		brief_panel.clip_contents = true
		vbox.add_child(brief_panel)

		var brief_scroll := ScrollContainer.new()
		brief_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		brief_scroll.offset_left = 5
		brief_scroll.offset_top = 5
		brief_scroll.offset_right = -5
		brief_scroll.offset_bottom = -5
		brief_scroll.clip_contents = true
		brief_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		brief_panel.add_child(brief_scroll)

		var rec_lv_name: String = mission.recommended_lv_id
		for lv in lvs_fallback:
			if lv.id == mission.recommended_lv_id:
				rec_lv_name = "%s (%.0fkg)" % [lv.short_name, lv.max_payload_kg]
				break

		var analogue: Dictionary = NasaMissionFramework.get_mission_analogue(mission.id)
		var lbl_brief := Label.new()
		lbl_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_brief.text = Loc.pick("OBJ: %s\nCOHETE REC: %s\nNASA: %s\n\n%s", "OBJ: %s\nREC LAUNCHER: %s\nNASA: %s\n\n%s") % [
			mission.objective_summary,
			rec_lv_name,
			str(analogue.get("mission_name", "-")),
			mission.brief,
		]
		lbl_brief.add_theme_color_override("font_color", ThemeFactory.COL_TEXT)
		brief_scroll.add_child(lbl_brief)

		var record: Dictionary = {} if Engine.is_editor_hint() else GameState.completed_missions.get(mission.id, {})
		var lbl_rec := Label.new()
		lbl_rec.clip_text = true
		if not record.is_empty():
			var cml_num: int = int(record.get("best_cml", 1))
			var badges: Array = record.get("badges", [])
			var badge_str: String = (" | " + " · ".join(badges)) if not badges.is_empty() else ""
			lbl_rec.text = Loc.pick(
				"OK | RÉCORD: %d PTS | CML %d%s",
				"OK | BEST: %d PTS | CML %d%s"
			) % [int(record.get("best_science", 0)), cml_num, badge_str]
			lbl_rec.tooltip_text = lbl_rec.text
			lbl_rec.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		else:
			lbl_rec.text = Loc.pick("POR EXPLORAR", "UNEXPLORED")
			lbl_rec.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		vbox.add_child(lbl_rec)

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 4)
		vbox.add_child(action_row)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = Loc.pick("DISEÑAR [%d]", "DESIGN [%d]") % mission.order_index
		ThemeFactory.bind_shortcut(btn, (KEY_1 + mission.order_index - 1) as Key)
		btn.custom_minimum_size = Vector2(0, 26)
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.enter_assembly(mission.id)
		)
		action_row.add_child(btn)
		_mission_buttons.append(btn)

		if not Engine.is_editor_hint() and GameState.has_saved_design(mission.id):
			var btn_load := Button.new()
			btn_load.text = Loc.pick("CARGAR", "LOAD")
			btn_load.tooltip_text = Loc.pick(
				"Cargar la última sonda victoriosa guardada para esta misión.",
				"Load the last saved winning spacecraft for this mission."
			)
			btn_load.custom_minimum_size = Vector2(72, 26)
			btn_load.pressed.connect(func():
				AudioManager.play_sfx("click")
				GameState.select_mission(mission.id)
				GameState.load_mission_design(mission.id)
				GameState.enter_assembly(mission.id)
			)
			action_row.add_child(btn_load)
			_mission_buttons.append(btn_load)


func _format_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" + out) if n < 0 else out


func _update_mute_label() -> void:
	_btn_mute.text = Loc.pick(
		"SONIDO OFF [F10]" if AudioManager.is_muted() else "SONIDO ON [F10]",
		"AUDIO OFF [F10]" if AudioManager.is_muted() else "AUDIO ON [F10]"
	)


class _SpaceBackdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), ThemeFactory.COL_BG)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9001
		for _i in range(70):
			var sx: float = floorf(rng.randf_range(2.0, maxf(size.x - 2.0, 3.0)))
			var sy: float = floorf(rng.randf_range(2.0, maxf(size.y - 2.0, 3.0)))
			var bright: float = rng.randf_range(0.25, 0.75)
			draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(bright, bright * 1.05, 0.95, 0.6))
