@tool
extends Control
## Mission selection and campaign briefing screen.

var _cards_hbox: HBoxContainer
var _btn_mute: Button


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	_build_ui()
	_populate_missions()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Header
	var header := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
	header.position = Vector2(4, 4)
	header.size = Vector2(632, 34)
	add_child(header)

	var lbl_title := Label.new()
	lbl_title.text = "MISIÓN CRÍTICA // SIMULADOR DE INGENIERÍA ESPACIAL"
	lbl_title.position = Vector2(10, 12)
	lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	header.add_child(lbl_title)

	_btn_mute = Button.new()
	_btn_mute.position = Vector2(546, 7)
	_btn_mute.size = Vector2(78, 20)
	if Engine.is_editor_hint():
		_btn_mute.text = "AUDIO: ON"
	else:
		_update_mute_label()
		_btn_mute.pressed.connect(func():
			AudioManager.set_muted(not AudioManager.is_muted())
			_update_mute_label()
			AudioManager.play_sfx("click")
		)
	header.add_child(_btn_mute)

	# Cards Row
	_cards_hbox = HBoxContainer.new()
	_cards_hbox.position = Vector2(6, 44)
	_cards_hbox.size = Vector2(628, 278)
	_cards_hbox.add_theme_constant_override("separation", 6)
	add_child(_cards_hbox)

	# Footer
	var footer := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png")
	footer.position = Vector2(4, 328)
	footer.size = Vector2(632, 28)
	add_child(footer)

	var lbl_hint := Label.new()
	lbl_hint.text = "FASE 1: SELECCIONA OBJETIVO -> FASE 2: DISEÑA SONDA -> FASE 3: OPERA CABINA"
	lbl_hint.position = Vector2(12, 9)
	lbl_hint.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
	footer.add_child(lbl_hint)


func _populate_missions() -> void:
	for child in _cards_hbox.get_children():
		child.queue_free()

	var missions: Array[MissionSpec] = MissionCatalog.create_all() if Engine.is_editor_hint() else MissionData.get_all_missions()
	for mission in missions:
		var card := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(204, 278)
		_cards_hbox.add_child(card)

		var lbl_title := Label.new()
		lbl_title.text = mission.title
		lbl_title.position = Vector2(8, 8)
		lbl_title.size = Vector2(188, 14)
		lbl_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
		card.add_child(lbl_title)

		var lbl_diff := Label.new()
		lbl_diff.text = "[%s]" % mission.difficulty
		lbl_diff.position = Vector2(8, 21)
		lbl_diff.add_theme_color_override("font_color", ThemeFactory.COL_AMBER)
		card.add_child(lbl_diff)

		var planet_tex := TextureRect.new()
		var p_path := "res://assets/sprites/space/planet_%s.png" % mission.target_palette
		if ResourceLoader.exists(p_path):
			planet_tex.texture = load(p_path)
		planet_tex.position = Vector2(70, 36)
		planet_tex.size = Vector2(64, 64)
		planet_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(planet_tex)

		var stats_box := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 4)
		stats_box.position = Vector2(8, 106)
		stats_box.size = Vector2(188, 58)
		card.add_child(stats_box)

		var lbl_stats := Label.new()
		lbl_stats.position = Vector2(6, 5)
		lbl_stats.size = Vector2(176, 48)
		lbl_stats.text = "PRESUPUESTO: $%d\nΔv REQ: %.0f (±%.0f) m/s\nSOL: %.2f UA  |  TWR >= %.2f\nTRÁNSITO: %ds" % [
			mission.budget,
			mission.required_delta_v,
			mission.delta_v_tolerance,
			mission.distance_au,
			mission.min_twr,
			int(mission.transit_duration_s),
		]
		lbl_stats.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
		stats_box.add_child(lbl_stats)

		var lbl_brief := Label.new()
		lbl_brief.position = Vector2(8, 166)
		lbl_brief.size = Vector2(188, 60)
		lbl_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_brief.text = mission.brief
		lbl_brief.add_theme_color_override("font_color", ThemeFactory.COL_MUTED)
		card.add_child(lbl_brief)

		var record: Dictionary = {} if Engine.is_editor_hint() else GameState.completed_missions.get(mission.id, {})
		if not record.is_empty():
			var lbl_rec := Label.new()
			lbl_rec.text = "COMPLETADA | CIENCIA: %d" % int(record.get("best_science", 0))
			lbl_rec.position = Vector2(8, 230)
			lbl_rec.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
			card.add_child(lbl_rec)

		var btn := Button.new()
		btn.text = "DISEÑAR SONDA >>"
		btn.position = Vector2(8, 248)
		btn.size = Vector2(188, 22)
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.enter_assembly(mission.id)
		)
		card.add_child(btn)


func _update_mute_label() -> void:
	_btn_mute.text = "AUDIO: OFF" if AudioManager.is_muted() else "AUDIO: ON"
