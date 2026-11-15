@tool
class_name ProbeVisualRenderer
extends RefCounted
## Renders the player's exact assembled ProbeDesign in crisp pixel art:
## - Vertical schematic view for AssemblyScreen (ProbeBlueprintView)
## - Full 360°-rotatable in-flight view for CockpitScreen (ViewportWindow) with
##   Reaction Wheel flywheel indicator, RCS corner gas puffs, unfolding solar wings,
##   directional engine plumes, S/X/Ka-band HGA antennas, and sensor scan beams.

const COL_OUTLINE := Color("080b12")
const COL_GOLD := Color("ecb236")
const COL_GOLD_HI := Color("ffe27a")
const COL_GOLD_DARK := Color("a4701c")
const COL_SILVER := Color("b8c6da")
const COL_STEEL := Color("606e84")
const COL_DARK_METAL := Color("283244")
const COL_SOLAR := Color("1c54ac")
const COL_SOLAR_HI := Color("4892ee")
const COL_SOLAR_GRID := Color("102c60")
const COL_GREEN := Color("40e880")
const COL_AMBER := Color("f8b838")
const COL_RED := Color("e84444")
const COL_CYAN := Color("40c8f0")
const COL_WHITE := Color("ecf2f8")


static func compute_vertical_bounds(design: ProbeDesign) -> Vector2:
	if design == null:
		return Vector2(80, 90)
	var tanks: Array[PartSpec] = design.get_parts_by_category(PartSpec.Category.TANK)
	var engines: Array[PartSpec] = design.get_parts_by_category(PartSpec.Category.PROPULSION)
	var energy: Array[PartSpec] = design.get_parts_by_category(PartSpec.Category.ENERGY)
	var instruments: Array[PartSpec] = design.get_parts_by_category(PartSpec.Category.INSTRUMENT)

	var solar_span: float = 0.0
	for e in energy:
		if e.power_gen_w > 0.0:
			solar_span += (26.0 if e.id == "solar_wing" else 18.0)
	var half_w: float = 28.0 + solar_span * 0.65

	var height_px: float = 52.0
	if not instruments.is_empty():
		height_px += 22.0
	for t in tanks:
		height_px += _tank_length(t.id) + 2.0
	if not engines.is_empty():
		height_px += 20.0
	return Vector2(half_w * 2.0, height_px)


static func _comms_tier(design: ProbeDesign) -> int:
	if design == null:
		return 0
	if design.get_part_count("comm_kaband") > 0:
		return 2
	if design.get_part_count("comm_xband") > 0:
		return 1
	return 0


static func draw_vertical(c: CanvasItem, center: Vector2, design: ProbeDesign, anim_t: float = 0.0) -> void:
	var cx: float = floorf(center.x)
	var tanks: Array[PartSpec] = []
	var engines: Array[PartSpec] = []
	var solar_parts: Array[PartSpec] = []
	var battery_parts: Array[PartSpec] = []
	var instruments: Array[PartSpec] = []
	var comm_tier: int = _comms_tier(design)

	if design != null:
		tanks = design.get_parts_by_category(PartSpec.Category.TANK)
		engines = design.get_parts_by_category(PartSpec.Category.PROPULSION)
		instruments = design.get_parts_by_category(PartSpec.Category.INSTRUMENT)
		for e in design.get_parts_by_category(PartSpec.Category.ENERGY):
			if e.power_gen_w > 0.0:
				solar_parts.append(e)
			else:
				battery_parts.append(e)

	var tank_total_h: float = 0.0
	for t in tanks:
		tank_total_h += _tank_length(t.id) + 2.0
	var top_extra: float = 26.0 if not instruments.is_empty() else 14.0
	var bot_extra: float = tank_total_h + (18.0 if not engines.is_empty() else 4.0)
	var bus_cy: float = floorf(center.y + (top_extra - bot_extra) * 0.35)

	# 1. Solar Wings
	var left_offset: float = 17.0
	var right_offset: float = 17.0
	for i in range(solar_parts.size()):
		var p: PartSpec = solar_parts[i]
		var panel_len: float = 34.0 if p.id == "solar_wing" else 22.0
		var panel_h: float = 14.0 if p.id == "solar_wing" else 10.0
		if i % 2 == 0:
			var x0: float = cx - left_offset - panel_len
			c.draw_line(Vector2(cx - 14.0, bus_cy), Vector2(x0 + panel_len, bus_cy), COL_SILVER, 2.0)
			_draw_solar_rect_h(c, Rect2(x0, bus_cy - panel_h * 0.5, panel_len, panel_h), p.id == "solar_wing")
			left_offset += panel_len + 4.0
		else:
			var x0: float = cx + right_offset
			c.draw_line(Vector2(cx + 14.0, bus_cy), Vector2(x0, bus_cy), COL_SILVER, 2.0)
			_draw_solar_rect_h(c, Rect2(x0, bus_cy - panel_h * 0.5, panel_len, panel_h), p.id == "solar_wing")
			right_offset += panel_len + 4.0

	# 2. Communications Antenna (Base S-Band / X-Band Dish / Ka-Band Transponder)
	var deck_top_y: float = bus_cy - 15.0
	_draw_parabolic_dish_up(c, Vector2(cx, deck_top_y - (16.0 if not instruments.is_empty() else 2.0)), comm_tier)

	# 3. Scientific Instruments
	if not instruments.is_empty():
		var boom_y: float = deck_top_y - 8.0
		c.draw_rect(Rect2(cx - 18.0, boom_y, 36.0, 3.0), COL_STEEL)
		var count: int = instruments.size()
		var spacing: float = 18.0
		var sx: float = cx - (count - 1) * spacing * 0.5
		for i in range(count):
			var inst: PartSpec = instruments[i]
			var ix: float = floorf(sx + i * spacing)
			_draw_instrument_up(c, Vector2(ix, boom_y - 4.0), inst.id)

	# 4. Fuel Tanks
	var cur_y: float = bus_cy + 15.0
	for t in tanks:
		var th: float = _tank_length(t.id)
		var tw: float = _tank_width(t.id)
		c.draw_line(Vector2(cx - 6.0, cur_y - 2.0), Vector2(cx - 6.0, cur_y + 2.0), COL_STEEL, 1.0)
		c.draw_line(Vector2(cx + 6.0, cur_y - 2.0), Vector2(cx + 6.0, cur_y + 2.0), COL_STEEL, 1.0)
		_draw_tank_v(c, Rect2(floorf(cx - tw * 0.5), cur_y, tw, th), t.id)
		cur_y += th + 2.0

	# 5. Battery Modules
	for i in range(battery_parts.size()):
		var b: PartSpec = battery_parts[i]
		var is_heavy: bool = (b.id == "bat_heavy")
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var row: int = i / 2
		var bx: float = cx + side * 19.0 - 4.0
		var by: float = bus_cy + 8.0 + row * 12.0
		c.draw_line(Vector2(cx + side * 12.0, by + 5.0), Vector2(bx + 4.0, by + 5.0), COL_STEEL, 1.0)
		c.draw_rect(Rect2(bx, by, 8.0, 10.0), COL_OUTLINE)
		c.draw_rect(Rect2(bx + 1.0, by + 1.0, 6.0, 8.0), COL_STEEL)
		c.draw_rect(Rect2(bx + 2.0, by + 3.0, 4.0, 4.0), COL_AMBER if is_heavy else COL_GREEN)

	# 6. Engines
	if not engines.is_empty():
		var e_count: int = engines.size()
		var e_spacing: float = 16.0
		var ex0: float = cx - (e_count - 1) * e_spacing * 0.5
		if e_count > 1:
			c.draw_rect(Rect2(cx - 12.0, cur_y - 1.0, 24.0, 3.0), COL_SILVER)
		for i in range(e_count):
			var eng: PartSpec = engines[i]
			_draw_engine_down(c, Vector2(floorf(ex0 + i * e_spacing), cur_y + 1.0), eng.id)

	# 7. Core Spacecraft Bus
	_draw_bus_core(c, Vector2(cx, bus_cy), anim_t, true, FlightTelemetry.SystemState.STABLE, 0.0, 0)


## Draws the assembled probe in flight rotated around `bus_pos` by `telemetry.attitude_deg`.
static func draw_flight_horizontal(
	c: CanvasItem,
	bus_pos: Vector2,
	design: ProbeDesign,
	telemetry: FlightTelemetry,
	deploy_ratio: float,
	anim_t: float,
	view_rotation_deg: float = 0.0,
	view_scale: Vector2 = Vector2.ONE
) -> Dictionary:
	var center := Vector2(floorf(bus_pos.x), floorf(bus_pos.y))
	var attitude_deg: float = telemetry.attitude_deg if telemetry != null else 0.0
	var rad: float = deg_to_rad(attitude_deg + view_rotation_deg)

	var tanks: Array[PartSpec] = []
	var engines: Array[PartSpec] = []
	var solar_parts: Array[PartSpec] = []
	var battery_parts: Array[PartSpec] = []
	var instruments: Array[PartSpec] = []
	var comm_tier: int = _comms_tier(design)

	if design != null:
		tanks = design.get_parts_by_category(PartSpec.Category.TANK)
		engines = design.get_parts_by_category(PartSpec.Category.PROPULSION)
		instruments = design.get_parts_by_category(PartSpec.Category.INSTRUMENT)
		for e in design.get_parts_by_category(PartSpec.Category.ENERGY):
			if e.power_gen_w > 0.0:
				solar_parts.append(e)
			else:
				battery_parts.append(e)

	var firing: bool = telemetry != null and telemetry.engine_firing and telemetry.throttle > 0.01
	var throttle: float = telemetry.throttle if telemetry != null else 0.0
	var bus_on: bool = telemetry == null or (telemetry.master_bus_on and telemetry.status != FlightTelemetry.Status.FAILED_POWER)
	var sys_state: FlightTelemetry.SystemState = telemetry.system_state if telemetry != null else FlightTelemetry.SystemState.STABLE
	var rw_sat: float = telemetry.rw_saturation if telemetry != null else 0.0
	var rcs_jets: int = telemetry.rcs_active_jets if telemetry != null else 0

	c.draw_set_transform(center, rad, view_scale)

	# 1. Solar Wings extending UP (-Y) and DOWN (+Y) in local frame
	var up_off: float = 15.0
	var dn_off: float = 15.0
	for i in range(solar_parts.size()):
		var p: PartSpec = solar_parts[i]
		var full_len: float = 30.0 if p.id == "solar_wing" else 19.0
		var cur_len: float = lerpf(4.0, full_len, deploy_ratio)
		var pw: float = 12.0 if p.id == "solar_wing" else 9.0
		if i % 2 == 0:
			var y0: float = -up_off - cur_len
			c.draw_line(Vector2(0, -12.0), Vector2(0, y0 + cur_len), COL_SILVER, 2.0)
			_draw_solar_rect_v(c, Rect2(-pw * 0.5, y0, pw, cur_len), p.id == "solar_wing", deploy_ratio)
			up_off += cur_len + 3.0
		else:
			var y0: float = dn_off
			c.draw_line(Vector2(0, 12.0), Vector2(0, y0), COL_SILVER, 2.0)
			_draw_solar_rect_v(c, Rect2(-pw * 0.5, y0, pw, cur_len), p.id == "solar_wing", deploy_ratio)
			dn_off += cur_len + 3.0

	# 2. Fuel Tanks extending AFT (-X) in local frame
	var cur_x: float = -15.0
	for t in tanks:
		var tlen: float = _tank_length(t.id)
		var tw: float = _tank_width(t.id)
		cur_x -= tlen
		_draw_tank_h(c, Rect2(cur_x, floorf(-tw * 0.5), tlen, tw), t.id)
		cur_x -= 2.0

	# 3. Battery Modules on aft flanks
	for i in range(battery_parts.size()):
		var b: PartSpec = battery_parts[i]
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var col_idx: int = i / 2
		var bat_x: float = -16.0 - col_idx * 11.0
		var bat_y: float = side * 15.0 - 4.0
		c.draw_rect(Rect2(bat_x, bat_y, 9.0, 8.0), COL_OUTLINE)
		c.draw_rect(Rect2(bat_x + 1.0, bat_y + 1.0, 7.0, 6.0), COL_STEEL)
		c.draw_rect(Rect2(bat_x + 2.0, bat_y + 2.0, 5.0, 4.0), COL_AMBER if b.id == "bat_heavy" else COL_GREEN)

	# 4. Engines at AFT tail (-X local) + Exhaust Plumes
	var local_nozzle_x: float = cur_x
	var has_ion: bool = false
	if not engines.is_empty():
		var e_count: int = engines.size()
		var ey_sep: float = 14.0
		var ey0: float = -(e_count - 1) * ey_sep * 0.5
		if e_count > 1:
			c.draw_rect(Rect2(cur_x - 2.0, -10.0, 3.0, 20.0), COL_SILVER)
		for i in range(e_count):
			var eng: PartSpec = engines[i]
			if eng.id == "eng_ion":
				has_ion = true
			var ey: float = floorf(ey0 + i * ey_sep)
			_draw_engine_left(c, Vector2(cur_x, ey), eng.id, firing, throttle, anim_t)
		local_nozzle_x = cur_x - 14.0

	# 5. Forward Payload Deck + S/X/Ka-Band Antenna (+X local nose)
	var local_nose_x: float = 15.0
	var hga_active: bool = telemetry != null and telemetry.comms_on and bus_on and telemetry.comms_link_factor > 0.0
	var hga_strong: bool = telemetry != null and telemetry.comms_link_factor >= 0.9
	_draw_parabolic_dish_right(c, Vector2(6.0, -16.0), comm_tier, hga_active, hga_strong, anim_t)

	if not instruments.is_empty():
		c.draw_rect(Rect2(local_nose_x, -14.0, 4.0, 28.0), COL_STEEL)
		var count: int = instruments.size()
		var isep: float = 12.0
		var iy0: float = -(count - 1) * isep * 0.5
		for i in range(count):
			var inst: PartSpec = instruments[i]
			var iy: float = floorf(iy0 + i * isep)
			var active_scan: bool = false
			if telemetry != null and bus_on and telemetry.science_bus_on:
				var q: float = float(telemetry.instruments_captured.get(inst.id, 0.0))
				var tx_done: bool = bool(telemetry.instruments_transmitted.get(inst.id, false))
				active_scan = (q > 0.0 and not tx_done) or (telemetry.in_flyby_window and telemetry.target_pointing_ok)
			_draw_instrument_right(c, Vector2(local_nose_x + 4.0, iy), inst.id, active_scan, anim_t)
		local_nose_x += 14.0

	# 6. Core Spacecraft Bus + RCS gas puffs + Reaction Wheel indicator
	_draw_bus_core(c, Vector2.ZERO, anim_t, bus_on, sys_state, rw_sat, rcs_jets)

	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	return {
		"nozzle_pos": center + (Vector2(local_nozzle_x, 0.0) * view_scale).rotated(rad),
		"nose_pos": center + (Vector2(local_nose_x, 0.0) * view_scale).rotated(rad),
		"exhaust_dir": Vector2(-1.0, 0.0).rotated(rad),
		"is_ion": has_ion,
	}


static func _tank_length(tid: String) -> float:
	match tid:
		"tank_small":
			return 14.0
		"tank_medium":
			return 20.0
		"tank_large":
			return 28.0
	return 16.0


static func _tank_width(tid: String) -> float:
	match tid:
		"tank_small":
			return 14.0
		"tank_medium":
			return 18.0
		"tank_large":
			return 22.0
	return 16.0


static func _draw_bus_core(
	c: CanvasItem,
	p: Vector2,
	anim_t: float,
	powered: bool,
	sys_state: FlightTelemetry.SystemState,
	rw_sat: float,
	rcs_jets: int
) -> void:
	var x: float = p.x - 14.0
	var y: float = p.y - 14.0

	var rcs_quads := [
		Vector2(-2, 2),
		Vector2(26, 2),
		Vector2(-2, 22),
		Vector2(26, 22),
	]
	for off in rcs_quads:
		c.draw_rect(Rect2(x + off.x, y + off.y, 4, 4), COL_STEEL)

	if powered and rcs_jets != 0:
		var puff_len: float = 6.0 + fmod(anim_t * 38.0, 5.0)
		var puff_col := Color(0.92, 0.97, 1.0, 0.88)
		if rcs_jets > 0 and rcs_jets != 2:
			c.draw_line(Vector2(x + 28, y + 2), Vector2(x + 28, y + 2 - puff_len), puff_col, 2.0)
			c.draw_line(Vector2(x + 0, y + 26), Vector2(x + 0, y + 26 + puff_len), puff_col, 2.0)
		elif rcs_jets < 0:
			c.draw_line(Vector2(x + 0, y + 2), Vector2(x + 0, y + 2 - puff_len), puff_col, 2.0)
			c.draw_line(Vector2(x + 28, y + 26), Vector2(x + 28, y + 26 + puff_len), puff_col, 2.0)
		else:
			if fmod(anim_t * 16.0, 1.0) < 0.55:
				c.draw_line(Vector2(x + 28, y + 2), Vector2(x + 28, y - 3), puff_col, 1.5)
				c.draw_line(Vector2(x + 0, y + 2), Vector2(x + 0, y - 3), puff_col, 1.5)
				c.draw_line(Vector2(x + 28, y + 26), Vector2(x + 28, y + 31), puff_col, 1.5)
				c.draw_line(Vector2(x + 0, y + 26), Vector2(x + 0, y + 31), puff_col, 1.5)

	c.draw_rect(Rect2(x, y, 28, 28), COL_OUTLINE)
	c.draw_rect(Rect2(x + 1, y + 1, 26, 26), COL_STEEL)
	c.draw_rect(Rect2(x + 3, y + 3, 22, 22), COL_GOLD)
	c.draw_rect(Rect2(x + 3, y + 3, 22, 3), COL_GOLD_HI)
	c.draw_rect(Rect2(x + 3, y + 21, 22, 4), COL_GOLD_DARK)
	c.draw_line(Vector2(x + 3, y + 10), Vector2(x + 25, y + 10), COL_GOLD_DARK, 1.0)
	c.draw_line(Vector2(x + 3, y + 18), Vector2(x + 25, y + 18), COL_GOLD_DARK, 1.0)
	c.draw_line(Vector2(x + 14, y + 3), Vector2(x + 14, y + 25), COL_GOLD_DARK, 1.0)

	c.draw_rect(Rect2(x + 8, y + 8, 12, 12), COL_OUTLINE)
	var led_col: Color = COL_RED
	if powered:
		match sys_state:
			FlightTelemetry.SystemState.STABLE:
				led_col = COL_GREEN
			FlightTelemetry.SystemState.CAUTION:
				led_col = COL_AMBER
			FlightTelemetry.SystemState.CRITICAL:
				led_col = COL_RED if fmod(anim_t * 6.0, 1.0) < 0.55 else COL_WHITE
	c.draw_rect(Rect2(x + 10, y + 10, 8, 8), led_col)

	if powered:
		var spin_ang: float = anim_t * (3.5 + rw_sat * 15.0)
		var dot_pos := Vector2(p.x + cos(spin_ang) * 2.5, p.y + sin(spin_ang) * 2.5)
		c.draw_rect(Rect2(roundf(dot_pos.x) - 1, roundf(dot_pos.y) - 1, 2, 2), COL_OUTLINE)


static func _draw_parabolic_dish_up(c: CanvasItem, tip: Vector2, comm_tier: int) -> void:
	if comm_tier == 0:
		# Compact base S-band omni antenna
		c.draw_line(Vector2(tip.x, tip.y + 8), Vector2(tip.x, tip.y - 2), COL_SILVER, 2.0)
		c.draw_rect(Rect2(tip.x - 6, tip.y + 4, 12, 3), COL_STEEL)
		c.draw_rect(Rect2(tip.x - 2, tip.y - 4, 4, 2), COL_AMBER)
	elif comm_tier == 1:
		# Wide X-band High-Gain Parabolic Dish
		c.draw_line(Vector2(tip.x, tip.y + 8), Vector2(tip.x, tip.y - 6), COL_WHITE, 2.0)
		c.draw_rect(Rect2(tip.x - 13, tip.y + 2, 26, 4), COL_SILVER)
		c.draw_rect(Rect2(tip.x - 9, tip.y + 6, 18, 3), COL_STEEL)
		c.draw_rect(Rect2(tip.x - 3, tip.y - 8, 6, 2), COL_CYAN)
	else:
		# Deep-space Ka-band Gold/Laser Dish + Transponder
		c.draw_line(Vector2(tip.x, tip.y + 9), Vector2(tip.x, tip.y - 7), COL_WHITE, 2.0)
		c.draw_rect(Rect2(tip.x - 15, tip.y + 1, 30, 5), COL_GOLD)
		c.draw_rect(Rect2(tip.x - 13, tip.y + 2, 26, 2), COL_WHITE)
		c.draw_rect(Rect2(tip.x - 8, tip.y + 6, 16, 3), COL_GOLD_DARK)
		c.draw_rect(Rect2(tip.x - 4, tip.y - 9, 8, 3), COL_GREEN)


static func _draw_parabolic_dish_right(
	c: CanvasItem,
	base: Vector2,
	comm_tier: int,
	tx_active: bool,
	hga_strong: bool,
	anim_t: float
) -> void:
	c.draw_line(base + Vector2(0, 4), base + Vector2(0, -4), COL_STEEL, 2.0)
	var dish_h: float = 9.0 if comm_tier == 0 else (14.0 if comm_tier == 1 else 18.0)
	var dish_col: Color = COL_GOLD if comm_tier == 2 else COL_SILVER
	c.draw_rect(Rect2(base.x - 2, base.y - 4.0 - dish_h * 0.5, 4, dish_h), dish_col)
	var boom_len: float = 7.0 if comm_tier == 0 else (10.0 if comm_tier == 1 else 12.0)
	c.draw_line(base + Vector2(2, -4), base + Vector2(boom_len, -4), COL_WHITE, 1.0)
	c.draw_rect(
		Rect2(base.x + boom_len - 1.0, base.y - 6, 3, 4),
		COL_GREEN if hga_strong else (COL_CYAN if tx_active else COL_STEEL)
	)
	if tx_active and fmod(anim_t * (5.5 if hga_strong else 2.2), 1.0) < 0.70:
		var wave_col: Color = Color(0.25, 0.95, 0.55, 0.85) if hga_strong else Color(0.25, 0.85, 0.95, 0.45)
		c.draw_arc(base + Vector2(boom_len + 1.0, -4), 5.0 + fmod(anim_t * 15.0, 9.0), -0.65, 0.65, 8, wave_col, 1.3)
		if comm_tier >= 1 and hga_strong:
			c.draw_arc(base + Vector2(boom_len + 1.0, -4), 9.0 + fmod(anim_t * 15.0, 9.0), -0.50, 0.50, 8, wave_col, 1.0)


static func _draw_solar_rect_h(c: CanvasItem, r: Rect2, is_wing: bool) -> void:
	c.draw_rect(r, COL_SILVER)
	var inner := r.grow(-1.0)
	c.draw_rect(inner, COL_SOLAR)
	var cells: int = 4 if is_wing else 2
	for i in range(1, cells):
		var gx: float = inner.position.x + (inner.size.x / cells) * i
		c.draw_line(Vector2(gx, inner.position.y), Vector2(gx, inner.end.y), COL_SOLAR_GRID, 1.0)
	c.draw_line(Vector2(inner.position.x, inner.position.y + 1), Vector2(inner.end.x, inner.position.y + 1), COL_SOLAR_HI, 1.0)


static func _draw_solar_rect_v(c: CanvasItem, r: Rect2, is_wing: bool, deploy_ratio: float) -> void:
	c.draw_rect(r, COL_SILVER)
	if r.size.y < 5.0:
		return
	var inner := r.grow(-1.0)
	c.draw_rect(inner, COL_SOLAR)
	if deploy_ratio > 0.35:
		var cells: int = 4 if is_wing else 2
		for i in range(1, cells):
			var gy: float = inner.position.y + (inner.size.y / cells) * i
			c.draw_line(Vector2(inner.position.x, gy), Vector2(inner.end.x, gy), COL_SOLAR_GRID, 1.0)
		c.draw_line(Vector2(inner.position.x + 1, inner.position.y), Vector2(inner.position.x + 1, inner.end.y), COL_SOLAR_HI, 1.0)


static func _draw_tank_v(c: CanvasItem, r: Rect2, tid: String) -> void:
	var stripe: Color = COL_AMBER if tid == "tank_small" else (COL_CYAN if tid == "tank_medium" else COL_RED)
	c.draw_rect(r, COL_OUTLINE)
	c.draw_rect(r.grow(-1.0), COL_WHITE if tid == "tank_small" else COL_SILVER)
	c.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, 2, r.size.y - 4), COL_WHITE)
	c.draw_rect(Rect2(r.position.x + 1, r.position.y + r.size.y * 0.5 - 2, r.size.x - 2, 4), stripe)


static func _draw_tank_h(c: CanvasItem, r: Rect2, tid: String) -> void:
	var stripe: Color = COL_AMBER if tid == "tank_small" else (COL_CYAN if tid == "tank_medium" else COL_RED)
	c.draw_rect(r, COL_OUTLINE)
	c.draw_rect(r.grow(-1.0), COL_WHITE if tid == "tank_small" else COL_SILVER)
	c.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 2), COL_WHITE)
	c.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 2, r.position.y + 1, 4, r.size.y - 2), stripe)


static func _draw_engine_down(c: CanvasItem, top_center: Vector2, eid: String) -> void:
	var glow: Color = COL_CYAN if eid == "eng_ion" else (COL_RED if eid == "eng_biprop" else COL_AMBER)
	c.draw_rect(Rect2(top_center.x - 4, top_center.y, 8, 5), COL_STEEL)
	c.draw_rect(Rect2(top_center.x - 6, top_center.y + 5, 12, 6), COL_DARK_METAL)
	c.draw_rect(Rect2(top_center.x - 7, top_center.y + 11, 14, 3), COL_SILVER)
	c.draw_rect(Rect2(top_center.x - 4, top_center.y + 14, 8, 2), glow)


static func _draw_engine_left(c: CanvasItem, mount: Vector2, eid: String, firing: bool, throttle: float, anim_t: float) -> void:
	var is_ion: bool = (eid == "eng_ion")
	var glow: Color = COL_CYAN if is_ion else (COL_RED if eid == "eng_biprop" else COL_AMBER)
	c.draw_rect(Rect2(mount.x - 5, mount.y - 4, 5, 8), COL_STEEL)
	c.draw_rect(Rect2(mount.x - 11, mount.y - 6, 6, 12), COL_DARK_METAL)
	c.draw_rect(Rect2(mount.x - 14, mount.y - 7, 3, 14), COL_SILVER)
	c.draw_rect(Rect2(mount.x - 15, mount.y - 4, 2, 8), glow if firing else COL_DARK_METAL)

	if firing:
		var jitter: float = sin(anim_t * 42.0) * 3.0
		var plen: float = (14.0 + 28.0 * throttle) + jitter
		var outer_col: Color = Color(0.25, 0.82, 1.0, 0.78) if is_ion else Color(0.95, 0.45, 0.15, 0.85)
		var pts_outer := PackedVector2Array([
			Vector2(mount.x - 14, mount.y - 5),
			Vector2(mount.x - 14 - plen, mount.y),
			Vector2(mount.x - 14, mount.y + 5),
		])
		var pts_core := PackedVector2Array([
			Vector2(mount.x - 14, mount.y - 2),
			Vector2(mount.x - 14 - plen * 0.55, mount.y),
			Vector2(mount.x - 14, mount.y + 2),
		])
		c.draw_colored_polygon(pts_outer, outer_col)
		c.draw_colored_polygon(pts_core, COL_WHITE)


static func _draw_instrument_up(c: CanvasItem, pos: Vector2, iid: String) -> void:
	match iid:
		"inst_cam":
			c.draw_rect(Rect2(pos.x - 4, pos.y - 6, 8, 8), COL_STEEL)
			c.draw_rect(Rect2(pos.x - 2, pos.y - 8, 4, 3), COL_CYAN)
		"inst_spec":
			c.draw_rect(Rect2(pos.x - 5, pos.y - 6, 10, 7), COL_GOLD_DARK)
			c.draw_rect(Rect2(pos.x - 3, pos.y - 5, 2, 3), COL_RED)
			c.draw_rect(Rect2(pos.x + 1, pos.y - 5, 2, 3), COL_GREEN)
		"inst_radar":
			c.draw_line(Vector2(pos.x, pos.y + 2), Vector2(pos.x, pos.y - 8), COL_SILVER, 2.0)
			c.draw_rect(Rect2(pos.x - 7, pos.y - 9, 14, 3), COL_WHITE)


static func _draw_instrument_right(c: CanvasItem, pos: Vector2, iid: String, scanning: bool, anim_t: float) -> void:
	match iid:
		"inst_cam":
			c.draw_rect(Rect2(pos.x, pos.y - 4, 8, 8), COL_STEEL)
			c.draw_rect(Rect2(pos.x + 7, pos.y - 2, 3, 4), COL_CYAN)
		"inst_spec":
			c.draw_rect(Rect2(pos.x, pos.y - 4, 9, 8), COL_GOLD_DARK)
			c.draw_rect(Rect2(pos.x + 6, pos.y - 3, 2, 2), COL_RED)
			c.draw_rect(Rect2(pos.x + 6, pos.y + 1, 2, 2), COL_GREEN)
		"inst_radar":
			c.draw_line(pos, pos + Vector2(9, 0), COL_SILVER, 2.0)
			c.draw_rect(Rect2(pos.x + 8, pos.y - 6, 3, 12), COL_WHITE)

	if scanning:
		var pulse: float = fmod(anim_t * 24.0, 26.0)
		var beam_col := Color(0.25, 0.95, 0.65, 0.60 * (1.0 - pulse / 26.0))
		c.draw_arc(pos + Vector2(10, 0), 5.0 + pulse, -0.48, 0.48, 8, beam_col, 1.5)
