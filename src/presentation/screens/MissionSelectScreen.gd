@tool
extends Control
## Mission selection and campaign briefing screen with container-driven cards
## and scrollable CRT mission briefing terminals presenting all 9 engineering demands.

var _cards_hbox: HBoxContainer
var _title_lbl: Label
var _help_btn: Button
var _btn_lang: Button
var _btn_mute: Button
var _hint_lbl: Label


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_build_ui()
	_refresh_texts()
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String): _refresh_texts())


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


func _refresh_texts() -> void:
	_title_lbl.text = Loc.pick("MISIÓN CRÍTICA / ELIGE TU DESTINO", "CRITICAL MISSION / SELECT DESTINATION")
	_help_btn.text = Loc.pick("AYUDA [F1]", "HELP [F1]")
	_btn_lang.text = Loc.pick("ES / EN [F2]", "EN / ES [F2]")
	_hint_lbl.text = Loc.pick(
		"1-3 ELEGIR MISIÓN | F2 IDIOMA | TAB FOCO | INTRO CONFIRMAR | RUEDA LEER INFORMES",
		"1-3 PICK MISSION | F2 LANG | TAB FOCUS | ENTER CONFIRM | WHEEL SCROLL BRIEF"
	)
	if not Engine.is_editor_hint():
		_update_mute_label()
	else:
		_btn_mute.text = "AUDIO [F10]"
	_populate_missions()


func _populate_missions() -> void:
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
		lbl_title.clip_text = true
		lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_title.clip_text = false
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

		# Preview uses containers so the illustration and statistics cannot overlap.
		var preview := PanelContainer.new()
		vbox.add_child(preview)
		var preview_row := HBoxContainer.new()
		preview_row.add_theme_constant_override("separation", 5)
		preview.add_child(preview_row)
		var planet := TextureRect.new()
		planet.texture = load("res://assets/sprites/space/planet_%s.png" % mission.target_palette)
		planet.custom_minimum_size = Vector2(38, 38)
		planet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		planet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_row.add_child(planet)
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

		var lbl_brief := Label.new()
		lbl_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_brief.text = Loc.pick("OBJ: %s\nCOHETE REC: %s\n\n%s", "OBJ: %s\nREC LAUNCHER: %s\n\n%s") % [
			mission.objective_summary,
			rec_lv_name,
			mission.brief,
		]
		lbl_brief.add_theme_color_override("font_color", ThemeFactory.COL_TEXT)
		brief_scroll.add_child(lbl_brief)

		var record: Dictionary = {} if Engine.is_editor_hint() else GameState.completed_missions.get(mission.id, {})
		var lbl_rec := Label.new()
		lbl_rec.clip_text = true
		if not record.is_empty():
			lbl_rec.text = Loc.pick("COMPLETADA | RÉCORD: %d PTS", "COMPLETED | BEST: %d PTS") % int(record.get("best_science", 0))
			lbl_rec.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		else:
			lbl_rec.text = Loc.pick("POR EXPLORAR", "UNEXPLORED")
			lbl_rec.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		vbox.add_child(lbl_rec)

		var btn := Button.new()
		btn.text = Loc.pick("DISEÑAR [%d]", "DESIGN [%d]") % mission.order_index
		ThemeFactory.bind_shortcut(btn, (KEY_1 + mission.order_index - 1) as Key)
		btn.custom_minimum_size = Vector2(0, 26)
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.enter_assembly(mission.id)
		)
		vbox.add_child(btn)


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
