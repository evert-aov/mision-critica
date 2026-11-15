@tool
class_name ProbeBlueprintView
extends Control
## Schematic CAD pixel-art preview of the probe and its Launch Vehicle Fairing Envelope
## in AssemblyScreen. Highlights mass or fairing-module structural overload in red.

var _design: ProbeDesign
var _anim_t: float = 0.0
var _zoom: float = 1.0
var _pan := Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	tooltip_text = Loc.pick(
		"Rueda: zoom. Arrastrar con clic izquierdo: mover. Clic central: centrar.",
		"Wheel: zoom. Left drag: pan. Middle click: center."
	)
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	if not Engine.is_editor_hint():
		GameState.language_changed.connect(func(_lang: String):
			tooltip_text = Loc.pick(
				"Rueda: zoom. Arrastrar con clic izquierdo: mover. Clic central: centrar.",
				"Wheel: zoom. Left drag: pan. Middle click: center."
			)
			queue_redraw()
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom + (0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1), 0.7, 2.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			_zoom = 1.0
			_pan = Vector2.ZERO
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_pan = _pan.clamp(-size * 0.5, size * 0.5)
		accept_event()
	queue_redraw()


func set_design(design: ProbeDesign) -> void:
	_design = design
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# Subtle CRT CAD grid
	var step: int = 16
	for gx in range(0, int(w), step):
		draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.08, 0.26, 0.18, 0.42), 1.0)
	for gy in range(0, int(h), step):
		draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.08, 0.26, 0.18, 0.42), 1.0)

	var cx: float = floorf(w * 0.5)
	var cy: float = floorf(h * 0.50)

	# Engineering center axes
	draw_line(Vector2(cx, 16), Vector2(cx, h - 18), Color(0.25, 0.90, 0.50, 0.20), 1.0)
	draw_line(Vector2(8, cy), Vector2(w - 8, cy), Color(0.25, 0.90, 0.50, 0.14), 1.0)

	var lv: LaunchVehicleSpec = _design.get_launch_vehicle() if _design != null else null
	var wet_mass: float = RocketMath.calculate_wet_mass_kg(_design) if _design != null else 120.0
	var mod_cnt: int = _design.get_total_module_count() if _design != null else 0
	var mod_over: bool = lv != null and mod_cnt > lv.max_fairing_modules
	var mass_over: bool = lv != null and wet_mass > lv.max_payload_kg
	var overloaded: bool = mod_over or mass_over

	# Launch Vehicle Payload Fairing Envelope (aerodynamic ogive cone + cylindrical shroud)
	var fair_half_w: float = 56.0
	if lv != null:
		if lv.id == "lv_medium":
			fair_half_w = 68.0
		elif lv.id == "lv_heavy":
			fair_half_w = 80.0
	fair_half_w = minf(fair_half_w, w * 0.5 - 10.0)

	var f_col: Color = Color(0.94, 0.28, 0.28, 0.78) if overloaded else Color(0.25, 0.78, 0.94, 0.40)
	var nose_y: float = 18.0
	var shoulder_y: float = 54.0
	var base_y: float = h - 22.0
	draw_line(Vector2(cx, nose_y), Vector2(cx - fair_half_w, shoulder_y), f_col, 1.0)
	draw_line(Vector2(cx, nose_y), Vector2(cx + fair_half_w, shoulder_y), f_col, 1.0)
	draw_line(Vector2(cx - fair_half_w, shoulder_y), Vector2(cx - fair_half_w, base_y), f_col, 1.0)
	draw_line(Vector2(cx + fair_half_w, shoulder_y), Vector2(cx + fair_half_w, base_y), f_col, 1.0)
	# Payload adapter ring at base of fairing
	draw_rect(Rect2(cx - 26.0, base_y - 3.0, 52.0, 4.0), f_col)

	# Auto-fit scale so large multi-tank/solar configurations fit inside the CAD frame
	var bounds: Vector2 = ProbeVisualRenderer.compute_vertical_bounds(_design)
	var scale_x: float = (w - 26.0) / maxf(bounds.x, 1.0)
	var scale_y: float = (h - 52.0) / maxf(bounds.y, 1.0)
	var fit_scale: float = clampf(minf(scale_x, scale_y), 0.62, 2.40)

	draw_set_transform(Vector2(cx, cy + 2.0) + _pan, 0.0, Vector2.ONE * fit_scale * _zoom)
	ProbeVisualRenderer.draw_vertical(self, Vector2.ZERO, _design, _anim_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Top & Bottom CAD captions inside CRT
	var font: Font = ThemeFactory.get_ui_font()
	var font_size: int = ThemeFactory.get_ui_font_size()
	if font != null:
		var lv_tag: String = Loc.pick("SIN COHETE SELECCIONADO", "NO LAUNCHER SELECTED")
		if lv != null:
			lv_tag = Loc.pick("COFIA %s: %d/%d MÓD", "FAIRING %s: %d/%d MOD") % [lv.short_name, mod_cnt, lv.max_fairing_modules]
		draw_string(
			font,
			Vector2(6, 17),
			lv_tag,
			HORIZONTAL_ALIGNMENT_LEFT,
			w - 12,
			font_size,
			ThemeFactory.COL_RED if (lv == null or mod_over) else ThemeFactory.COL_CYAN
		)

		var mass_tag: String = Loc.pick("MASA: %.0f kg", "MASS: %.0f kg") % wet_mass
		if lv != null:
			mass_tag = Loc.pick("CARGA: %.0f / %.0f kg", "PAYLOAD: %.0f / %.0f kg") % [wet_mass, lv.max_payload_kg]
		draw_string(
			font,
			Vector2(6, h - 6),
			mass_tag,
			HORIZONTAL_ALIGNMENT_LEFT,
			w - 12,
			font_size,
			ThemeFactory.COL_RED if mass_over else ThemeFactory.COL_GREEN
		)
