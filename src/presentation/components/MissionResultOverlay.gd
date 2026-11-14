@tool
class_name MissionResultOverlay
extends Control
## Modal debrief overlay displayed when a mission succeeds or fails.

signal retry_requested()
signal assembly_requested()
signal menu_requested()

var _lbl_banner: Label
var _lbl_details: Label


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var modal := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_metal.png", 6)
	modal.position = Vector2(140, 60)
	modal.size = Vector2(360, 240)
	add_child(modal)

	_lbl_banner = Label.new()
	_lbl_banner.position = Vector2(16, 14)
	_lbl_banner.size = Vector2(328, 18)
	_lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal.add_child(_lbl_banner)

	var crt := ThemeFactory.make_ninepatch_rect("res://assets/sprites/ui/panel_crt.png", 6)
	crt.position = Vector2(16, 38)
	crt.size = Vector2(328, 152)
	modal.add_child(crt)

	_lbl_details = Label.new()
	_lbl_details.position = Vector2(10, 10)
	_lbl_details.size = Vector2(308, 132)
	_lbl_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crt.add_child(_lbl_details)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(16, 198)
	hbox.size = Vector2(328, 28)
	hbox.add_theme_constant_override("separation", 8)
	modal.add_child(hbox)

	var btn_retry := Button.new()
	btn_retry.text = "REINTENTAR"
	btn_retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_retry.pressed.connect(func():
		AudioManager.play_sfx("click")
		retry_requested.emit()
	)
	hbox.add_child(btn_retry)

	var btn_asm := Button.new()
	btn_asm.text = "ENSAMBLAJE"
	btn_asm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_asm.pressed.connect(func():
		AudioManager.play_sfx("click")
		assembly_requested.emit()
	)
	hbox.add_child(btn_asm)

	var btn_menu := Button.new()
	btn_menu.text = "MISIONES"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.pressed.connect(func():
		AudioManager.play_sfx("click")
		menu_requested.emit()
	)
	hbox.add_child(btn_menu)


func show_result(t: FlightTelemetry, mission: MissionSpec) -> void:
	visible = true
	var is_victory: bool = t.status == FlightTelemetry.Status.VICTORY
	if is_victory:
		_lbl_banner.text = "=== MISIÓN CUMPLIDA: INSERCIÓN EXITOSA ==="
		_lbl_banner.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_lbl_banner.text = "=== MISIÓN FALLIDA ==="
		_lbl_banner.add_theme_color_override("font_color", ThemeFactory.COL_RED)

	var status_msg: String = "Órbita/sobrevuelo completado dentro del corredor nominal." if is_victory else t.failure_reason
	_lbl_details.text = "%s\n\nOBJETIVO: %s\nΔv QUEMADO: %.0f / %.0f m/s\nPROPELENTE RESTANTE: %.0f kg\nBATERÍA FINAL: %.0f / %.0f Wh\nRETORNO CIENTÍFICO: %d / %d PTS" % [
		status_msg,
		mission.target_name if mission else "-",
		t.delta_v_burned,
		t.delta_v_required,
		t.propellant_remaining_kg,
		t.battery_wh,
		t.battery_max_wh,
		t.science_score if is_victory else 0,
		t.science_max,
	]
