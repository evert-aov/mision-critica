class_name InternalCabinRenderer
extends RefCounted
## Renders distinct spacecraft interiors and visible external attachments
## for the cockpit first-person internal view based on assembled ProbeDesign.


static func classify_archetype(design: ProbeDesign, mission: MissionSpec = null) -> String:
	if design == null:
		return "explorer"
	var wet_kg: float = RocketMath.calculate_wet_mass_kg(design)
	var lv: LaunchVehicleSpec = design.get_launch_vehicle()
	var lv_id: String = lv.id if lv != null else ""
	if design.get_part_count("eng_ion") > 0 or lv_id == "lv_heavy" or wet_kg >= 580.0:
		return "deep_space"
	if lv_id == "lv_light" or wet_kg < 300.0:
		return "compact"
	if mission != null and mission.id == "mars_orbit" and wet_kg >= 450.0:
		return "deep_space"
	return "explorer"


static func archetype_label(archetype: String) -> String:
	match archetype:
		"compact":
			return Loc.pick("CÚPULA COMPACTA", "COMPACT CUPOLA")
		"deep_space":
			return Loc.pick("PUENTE ESPACIO PROFUNDO", "DEEP-SPACE BRIDGE")
		_:
			return Loc.pick("BAHÍA EXPLORADORA", "EXPLORER BAY")


static func window_rect(dimensions: Vector2, archetype: String) -> Rect2:
	match archetype:
		"compact":
			var margin_x: float = clampf(dimensions.x * 0.19, 90.0, 250.0)
			var top_y: float = clampf(dimensions.y * 0.13, 36.0, 62.0)
			var bot_y: float = clampf(dimensions.y * 0.18, 44.0, 82.0)
			return Rect2(margin_x, top_y, maxf(120.0, dimensions.x - margin_x * 2.0), maxf(80.0, dimensions.y - top_y - bot_y))
		"deep_space":
			var margin_x: float = clampf(dimensions.x * 0.14, 70.0, 195.0)
			var top_y: float = clampf(dimensions.y * 0.11, 30.0, 52.0)
			var bot_y: float = clampf(dimensions.y * 0.17, 42.0, 76.0)
			return Rect2(margin_x, top_y, maxf(120.0, dimensions.x - margin_x * 2.0), maxf(80.0, dimensions.y - top_y - bot_y))
		_:
			var margin_x: float = clampf(dimensions.x * 0.15, 76.0, 210.0)
			var top_y: float = clampf(dimensions.y * 0.10, 28.0, 50.0)
			var bot_y: float = clampf(dimensions.y * 0.16, 40.0, 72.0)
			return Rect2(margin_x, top_y, maxf(120.0, dimensions.x - margin_x * 2.0), maxf(80.0, dimensions.y - top_y - bot_y))


static func draw_exterior_attachments(
	c: CanvasItem,
	dimensions: Vector2,
	design: ProbeDesign,
	t: FlightTelemetry,
	deploy_ratio: float,
	anim_t: float,
	capture_flash_s: float,
	archetype: String,
	shake: Vector2
) -> void:
	if design == null or t == null:
		return
	var win := window_rect(dimensions, archetype)
	var center_y: float = win.get_center().y + shake.y * 0.5

	# Solar wings extending from left/right flanks outside the viewport rim.
	var has_solar: bool = (
		design.get_part_count("solar_compact") > 0
		or design.get_part_count("solar_wing") > 0
		or design.get_part_count("solar_array") > 0
	)
	if has_solar:
		var wing_len: float = lerpf(16.0, win.size.x * 0.19, clampf(deploy_ratio, 0.0, 1.0))
		var wing_h: float = 28.0 if design.get_part_count("solar_array") > 0 else 20.0
		var wing_col := Color("1c4b8c") if deploy_ratio > 0.2 else Color("34465e")
		var frame_col := Color("627996")
		for dir in [-1.0, 1.0]:
			var base_x: float = win.position.x if dir < 0.0 else win.end.x
			var tip_x: float = base_x - dir * wing_len
			var pts := PackedVector2Array([
				Vector2(base_x, center_y - wing_h * 0.65),
				Vector2(tip_x, center_y - wing_h * 0.36),
				Vector2(tip_x, center_y + wing_h * 0.36),
				Vector2(base_x, center_y + wing_h * 0.65),
			])
			c.draw_colored_polygon(pts, wing_col)
			c.draw_polyline(pts + PackedVector2Array([pts[0]]), frame_col, 2.0)
			if deploy_ratio > 0.35:
				for seg in [0.33, 0.66]:
					var sx: float = lerpf(base_x, tip_x, seg)
					var sh: float = lerpf(wing_h * 0.62, wing_h * 0.38, seg)
					c.draw_line(Vector2(sx, center_y - sh), Vector2(sx, center_y + sh), Color("4ea8ef", 0.55), 1.0)

	# Parabolic HGA dish / comms boom protruding into upper-right rim.
	var has_hga: bool = (
		design.get_part_count("comm_xband") > 0
		or design.get_part_count("comm_kaband") > 0
	)
	if has_hga:
		var is_ka: bool = design.get_part_count("comm_kaband") > 0
		var anchor := Vector2(win.end.x + 12.0, win.position.y + 18.0) + shake * 0.4
		var dish_pos := Vector2(win.end.x - (46.0 if is_ka else 40.0), win.position.y + 38.0) + shake * 0.4
		c.draw_line(anchor, dish_pos, Color("7e92aa"), 3.0)
		c.draw_arc(dish_pos, 23.0 if is_ka else 19.0, deg_to_rad(110.0), deg_to_rad(250.0), 14, Color("c8d8e8"), 3.0)
		var dish_led: Color = ThemeFactory.COL_CYAN if (t.comms_on and t.comms_link_factor >= 0.6) else Color("4a5d72")
		c.draw_circle(dish_pos + Vector2(-8.0, 0.0), 3.0, dish_led)

	# Forward RCS gas thruster puffs visible at window corners when slewing with RCS active.
	if t.rcs_active_jets != 0 or (t.rcs_enabled and absf(t.angular_vel_deg_s) > 2.0):
		var turn_sign: float = float(t.rcs_active_jets) if t.rcs_active_jets != 0 else signf(t.angular_vel_deg_s)
		var pulse_len: float = (18.0 + 14.0 * absf(sin(anim_t * 22.0)))
		var jet_a := Vector2(win.position.x + 8.0, win.position.y + 22.0) if turn_sign > 0.0 else Vector2(win.end.x - 8.0, win.position.y + 22.0)
		var jet_b := Vector2(win.end.x - 8.0, win.end.y - 22.0) if turn_sign > 0.0 else Vector2(win.position.x + 8.0, win.end.y - 22.0)
		var dir_a := Vector2(1.0, 0.25) if turn_sign > 0.0 else Vector2(-1.0, 0.25)
		var dir_b := Vector2(-1.0, -0.25) if turn_sign > 0.0 else Vector2(1.0, -0.25)
		for jet in [[jet_a, dir_a], [jet_b, dir_b]]:
			var origin: Vector2 = jet[0]
			var vdir: Vector2 = jet[1]
			var perp := vdir.rotated(PI * 0.5) * 5.0
			var plume := PackedVector2Array([origin, origin + vdir * pulse_len + perp, origin + vdir * pulse_len - perp])
			c.draw_colored_polygon(plume, Color(0.90, 0.96, 1.0, 0.55))

	# Forward scientific instrument bay visible along lower viewport sill.
	var inst_count: int = (
		design.get_part_count("inst_cam")
		+ design.get_part_count("inst_spec")
		+ design.get_part_count("inst_radar")
	)
	if inst_count > 0:
		var sill_y: float = win.end.y + shake.y * 0.35
		var bay_x: float = win.get_center().x + shake.x * 0.35
		if design.get_part_count("inst_cam") > 0:
			var lens_pos := Vector2(bay_x - 74.0, sill_y - 10.0)
			c.draw_rect(Rect2(lens_pos - Vector2(14, 8), Vector2(28, 16)), Color("384c62"))
			c.draw_circle(lens_pos, 5.0, ThemeFactory.COL_CYAN if capture_flash_s > 0.0 else Color("17314a"))
		if design.get_part_count("inst_spec") > 0:
			var spec_pos := Vector2(bay_x, sill_y - 12.0)
			c.draw_rect(Rect2(spec_pos - Vector2(18, 8), Vector2(36, 16)), Color("425368"))
			c.draw_rect(Rect2(spec_pos - Vector2(10, 4), Vector2(20, 6)), ThemeFactory.COL_GREEN if capture_flash_s > 0.0 else Color("24594a"))
		if design.get_part_count("inst_radar") > 0:
			var sar_pos := Vector2(bay_x + 76.0, sill_y - 11.0)
			c.draw_rect(Rect2(sar_pos - Vector2(22, 6), Vector2(44, 12)), Color("4e6074"))
			var ping: float = 0.4 + 0.6 * absf(sin(anim_t * 3.0))
			c.draw_line(sar_pos + Vector2(-18, -7), sar_pos + Vector2(18, -7), Color(ThemeFactory.COL_AMBER, ping if capture_flash_s > 0.0 else 0.45), 2.0)


static func draw_interior_frame(
	c: CanvasItem,
	dimensions: Vector2,
	design: ProbeDesign,
	t: FlightTelemetry,
	archetype: String,
	anim_t: float,
	shake: Vector2
) -> void:
	if dimensions.x < 80.0 or dimensions.y < 60.0:
		return
	var win := window_rect(dimensions, archetype)
	var hull_dark := Color("111b28")
	var hull_mid := Color("1e2c3e")
	var hull_light := Color("334860")
	var accent: Color = ThemeFactory.COL_CYAN
	if archetype == "compact":
		hull_dark = Color("18202c")
		hull_mid = Color("2a3444")
		hull_light = Color("4c5c72")
		accent = ThemeFactory.COL_AMBER
	elif archetype == "deep_space":
		hull_dark = Color("0c1320")
		hull_mid = Color("162235")
		hull_light = Color("2d425e")
		accent = Color("54d8ff")

	var is_ion: bool = design != null and design.get_part_count("eng_ion") > 0
	var thrust_glow: Color = Color(0.25, 0.85, 1.0, 0.22 * t.throttle) if is_ion else Color(1.0, 0.58, 0.18, 0.20 * t.throttle)

	# Outer bulkhead surround around the viewport opening.
	var outer := Rect2(Vector2.ZERO, dimensions)
	var w_shifted := Rect2(win.position + shake, win.size)
	_draw_wall_ring(c, outer, w_shifted, hull_dark, hull_mid, hull_light)

	# Inner chamfered corners and perspective ribs.
	var chamfer: float = 34.0 if archetype == "compact" else 24.0
	var tl := w_shifted.position
	var tr := Vector2(w_shifted.end.x, w_shifted.position.y)
	var bl := Vector2(w_shifted.position.x, w_shifted.end.y)
	var br := w_shifted.end

	# Corner triangular gussets / gold MLI foil accents for compact cupola.
	var corner_col: Color = Color("966a22") if archetype == "compact" else hull_mid
	_draw_corner_gusset(c, tl, Vector2(1, 0), Vector2(0, 1), chamfer, corner_col, hull_light)
	_draw_corner_gusset(c, tr, Vector2(-1, 0), Vector2(0, 1), chamfer, corner_col, hull_light)
	_draw_corner_gusset(c, bl, Vector2(1, 0), Vector2(0, -1), chamfer, corner_col, hull_light)
	_draw_corner_gusset(c, br, Vector2(-1, 0), Vector2(0, -1), chamfer, corner_col, hull_light)

	# Perspective ceiling and floor bulkhead lines converging toward window edges.
	c.draw_line(Vector2.ZERO, tl, hull_light, 2.0)
	c.draw_line(Vector2(dimensions.x, 0.0), tr, hull_light, 2.0)
	c.draw_line(Vector2(0.0, dimensions.y), bl, hull_light, 2.0)
	c.draw_line(dimensions, br, hull_light, 2.0)

	# Archetype-specific interior structures & mounted displays.
	if archetype == "compact":
		# ISS Cupola-inspired radial struts + rivet studs.
		var w_center := w_shifted.get_center()
		for angle_deg in [-55.0, -125.0, 55.0, 125.0]:
			var dir := Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
			var inner_pt := w_center + dir * minf(w_shifted.size.x, w_shifted.size.y) * 0.44
			var outer_pt := w_center + dir * maxf(dimensions.x, dimensions.y) * 0.52
			c.draw_line(inner_pt, outer_pt, hull_light, 4.0)
			c.draw_line(inner_pt, outer_pt, hull_dark, 1.5)
	elif archetype == "deep_space":
		# Reinforced deep-space twin bay pillars + radiation shield ribs.
		var mid_x: float = w_shifted.get_center().x
		c.draw_line(Vector2(mid_x - w_shifted.size.x * 0.24, w_shifted.position.y), Vector2(mid_x - w_shifted.size.x * 0.28, w_shifted.end.y), Color(hull_light, 0.55), 3.0)
		c.draw_line(Vector2(mid_x + w_shifted.size.x * 0.24, w_shifted.position.y), Vector2(mid_x + w_shifted.size.x * 0.28, w_shifted.end.y), Color(hull_light, 0.55), 3.0)
		c.draw_rect(Rect2(mid_x - 42.0, w_shifted.position.y - 12.0, 84.0, 10.0), hull_light)
	else:
		# Explorer panoramic bay: overhead light vents.
		var vent_w: float = minf(w_shifted.size.x * 0.45, 220.0)
		var vent_x: float = w_shifted.get_center().x - vent_w * 0.5
		for i in range(5):
			var vx: float = vent_x + float(i) * (vent_w / 5.0)
			c.draw_rect(Rect2(vx + 3.0, maxf(6.0, w_shifted.position.y * 0.28), vent_w / 5.0 - 8.0, 7.0), Color("8cbfe6", 0.38))

	# Live bulkhead diagnostic monitors (left & right walls) reflecting real telemetry.
	_draw_wall_monitors(c, w_shifted, dimensions, t, accent, anim_t)

	# Engine burn rim glow on the lower sill & subtle glass edge reflection.
	if t != null and t.engine_firing and t.throttle > 0.02:
		c.draw_rect(Rect2(w_shifted.position.x, w_shifted.end.y - 4.0, w_shifted.size.x, 8.0), thrust_glow)
	c.draw_rect(w_shifted, Color(accent, 0.35), false, 1.5)

	# Subtle lower sill cockpit crossbar reticle.
	var sill_center := Vector2(w_shifted.get_center().x, w_shifted.end.y + 8.0)
	c.draw_rect(Rect2(sill_center - Vector2(68.0, 4.0), Vector2(136.0, 10.0)), hull_dark)
	c.draw_rect(Rect2(sill_center - Vector2(68.0, 4.0), Vector2(136.0, 10.0)), hull_light, false, 1.0)
	var font: Font = ThemeFactory.get_compact_font()
	var fsize: int = ThemeFactory.get_compact_font_size()
	if font != null:
		var lbl: String = archetype_label(archetype)
		var tw: float = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		c.draw_string(font, Vector2(floorf(sill_center.x - tw * 0.5), floorf(sill_center.y + 4.0)), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, accent)


static func _draw_wall_ring(c: CanvasItem, outer: Rect2, hole: Rect2, dark: Color, mid: Color, light: Color) -> void:
	# Top, bottom, left, right strips framing the viewport cutout.
	var top_h: float = maxf(0.0, hole.position.y - outer.position.y)
	var bot_y: float = hole.end.y
	var bot_h: float = maxf(0.0, outer.end.y - bot_y)
	var left_w: float = maxf(0.0, hole.position.x - outer.position.x)
	var right_x: float = hole.end.x
	var right_w: float = maxf(0.0, outer.end.x - right_x)

	if top_h > 0.0:
		c.draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, top_h), dark)
		c.draw_rect(Rect2(hole.position.x - 4.0, maxf(0.0, hole.position.y - 10.0), hole.size.x + 8.0, 10.0), mid)
	if bot_h > 0.0:
		c.draw_rect(Rect2(outer.position.x, bot_y, outer.size.x, bot_h), dark)
		c.draw_rect(Rect2(hole.position.x - 6.0, bot_y, hole.size.x + 12.0, minf(14.0, bot_h)), mid)
	if left_w > 0.0:
		c.draw_rect(Rect2(outer.position.x, hole.position.y, left_w, hole.size.y), mid)
		c.draw_rect(Rect2(outer.position.x, hole.position.y, left_w * 0.55, hole.size.y), dark)
		c.draw_line(Vector2(hole.position.x - 1.0, hole.position.y), Vector2(hole.position.x - 1.0, hole.end.y), light, 2.0)
	if right_w > 0.0:
		c.draw_rect(Rect2(right_x, hole.position.y, right_w, hole.size.y), mid)
		c.draw_rect(Rect2(right_x + right_w * 0.45, hole.position.y, right_w * 0.55, hole.size.y), dark)
		c.draw_line(Vector2(hole.end.x + 1.0, hole.position.y), Vector2(hole.end.x + 1.0, hole.end.y), light, 2.0)


static func _draw_corner_gusset(c: CanvasItem, corner: Vector2, dx: Vector2, dy: Vector2, size_px: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array([corner, corner + dx * size_px, corner + dy * size_px])
	c.draw_colored_polygon(pts, fill)
	c.draw_line(corner + dx * size_px, corner + dy * size_px, edge, 2.0)


static func _draw_wall_monitors(c: CanvasItem, win: Rect2, dimensions: Vector2, t: FlightTelemetry, accent: Color, anim_t: float) -> void:
	var left_w: float = win.position.x - 16.0
	var right_w: float = dimensions.x - win.end.x - 16.0
	var mon_h: float = clampf(win.size.y * 0.48, 48.0, 118.0)
	var mon_y: float = win.get_center().y - mon_h * 0.5

	if left_w >= 46.0:
		var lrect := Rect2(8.0, mon_y, minf(left_w - 6.0, 110.0), mon_h)
		c.draw_rect(lrect, Color("07131e"))
		c.draw_rect(lrect, Color("2e4b66"), false, 1.5)
		var bat_ratio: float = clampf(t.battery_wh / maxf(t.battery_max_wh, 1.0), 0.0, 1.0) if t != null else 0.7
		var fuel_ratio: float = clampf(t.propellant_remaining_kg / 200.0, 0.0, 1.0) if t != null else 0.7
		var bar_w: float = lrect.size.x - 14.0
		c.draw_rect(Rect2(lrect.position + Vector2(7, 10), Vector2(bar_w * bat_ratio, 6)), ThemeFactory.COL_GREEN if bat_ratio > 0.3 else ThemeFactory.COL_AMBER)
		c.draw_rect(Rect2(lrect.position + Vector2(7, 22), Vector2(bar_w * fuel_ratio, 6)), accent)
		var wave_y: float = lrect.position.y + mon_h * 0.68
		for i in range(6):
			var amp: float = absf(sin(anim_t * 3.0 + float(i))) * (mon_h * 0.18)
			c.draw_line(Vector2(lrect.position.x + 8 + i * (bar_w / 6.0), wave_y), Vector2(lrect.position.x + 8 + i * (bar_w / 6.0), wave_y - amp), accent, 2.0)
		if t != null and t.in_solar_storm:
			for s in range(3):
				var sy: float = lrect.position.y + 8.0 + fposmod(anim_t * 48.0 + float(s) * 19.0, maxf(mon_h - 14.0, 6.0))
				c.draw_line(Vector2(lrect.position.x + 3.0, sy), Vector2(lrect.end.x - 3.0, sy), Color(ThemeFactory.COL_AMBER, 0.65), 1.0)

	if right_w >= 46.0:
		var rw: float = minf(right_w - 6.0, 110.0)
		var rrect := Rect2(dimensions.x - rw - 8.0, mon_y, rw, mon_h)
		c.draw_rect(rrect, Color("07131e"))
		c.draw_rect(rrect, Color("2e4b66"), false, 1.5)
		var scan_c := rrect.get_center()
		var rad: float = minf(rw, mon_h) * 0.28
		c.draw_arc(scan_c, rad, 0.0, TAU, 18, Color("24576d"), 1.0)
		var sweep: float = fposmod(anim_t * 1.9, TAU)
		c.draw_line(scan_c, scan_c + Vector2.RIGHT.rotated(sweep) * rad, ThemeFactory.COL_GREEN if (t != null and t.comms_on) else ThemeFactory.COL_AMBER, 1.5)
		if t != null and t.in_solar_storm:
			for s in range(3):
				var sy: float = rrect.position.y + 8.0 + fposmod(anim_t * 53.0 + float(s) * 23.0, maxf(mon_h - 14.0, 6.0))
				c.draw_line(Vector2(rrect.position.x + 3.0, sy), Vector2(rrect.end.x - 3.0, sy), Color(ThemeFactory.COL_AMBER, 0.65), 1.0)
