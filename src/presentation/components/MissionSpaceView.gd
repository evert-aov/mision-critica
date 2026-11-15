@tool
class_name MissionSpaceView
extends Control
## Layered 2.5D scene: shaded bodies, perspective orbits, depth occlusion and local guidance.

var _mission: MissionSpec
var _design: ProbeDesign
var _telemetry: FlightTelemetry
var _planet: PlanetBodyView
var _sun: PlanetBodyView
var guidance_visible: bool = true
var internal_view: bool = false
var _cabin_archetype: String = "explorer"
var _environment := SpaceEnvironment.new()
var _origin: PlanetBodyView
var _assist: PlanetBodyView
var _front: _Foreground
var _stars: Array[Vector3] = []
var _snapshot: Dictionary = {}
var _anim_t: float = 0.0
var _ending_t: float = 0.0
var _deploy_ratio: float = 0.0
var _capture_signature: int = 0
var _capture_flash_s: float = 0.0
var _last_size := Vector2.ZERO
var _internal_vanish := Vector2.ZERO
var _internal_target_pos := Vector2.ZERO
var _internal_target_vis: bool = false
var _internal_shake := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(125):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.25, 1.0)))
	_sun = PlanetBodyView.new()
	_origin = PlanetBodyView.new()
	_planet = PlanetBodyView.new()
	_assist = PlanetBodyView.new()
	for body in [_sun, _origin, _planet, _assist]:
		add_child(body)
	_front = _Foreground.new()
	_front.scene = self
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)


func setup(mission: MissionSpec, design: ProbeDesign) -> void:
	_mission = mission
	_design = design
	_cabin_archetype = InternalCabinRenderer.classify_archetype(design, mission)
	_anim_t = 0.0
	_ending_t = 0.0
	_deploy_ratio = 0.0
	_capture_signature = {}.hash()
	_capture_flash_s = 0.0
	_snapshot.clear()
	_environment.reset()
	_last_size = Vector2.ZERO


func set_internal_view(enabled: bool) -> void:
	if internal_view == enabled:
		return
	internal_view = enabled
	if _telemetry != null and not _snapshot.is_empty():
		_apply_body_layout()
	queue_redraw()
	if _front != null:
		_front.queue_redraw()


func update_telemetry(t: FlightTelemetry, dt: float) -> void:
	_telemetry = t
	if t == null or _mission == null or _planet == null:
		return
	_anim_t += maxf(dt, 0.0)
	_capture_flash_s = maxf(0.0, _capture_flash_s - maxf(dt, 0.0))
	var capture_signature: int = t.instruments_captured.hash()
	if capture_signature != _capture_signature:
		_capture_signature = capture_signature
		if not t.instruments_captured.is_empty():
			_capture_flash_s = 3.0
	if t.status != FlightTelemetry.Status.IN_FLIGHT:
		_ending_t += maxf(dt, 0.0)
	var target_deploy: float = 1.0 if t.panels_deployed else 0.0
	_deploy_ratio = move_toward(_deploy_ratio, target_deploy, dt * 1.8) if dt > 0.0 else target_deploy
	var area := Rect2(10, 8, size.x - 20.0, maxf(size.y - 20.0, 36.0))
	var previous: Dictionary = _snapshot
	_snapshot = MissionSceneProjection.sample(_mission, t, area, _ending_t)
	if not previous.is_empty() and _last_size == size:
		var blend: float = 1.0 - exp(-maxf(dt, 0.0) * 8.0)
		for key in ["planet", "ship", "origin", "orbit_radii", "sun"]:
			_snapshot[key] = Vector2(previous[key]).lerp(_snapshot[key], blend)
		_snapshot["radius"] = lerpf(previous["radius"], _snapshot["radius"], blend)
		var old_frame: float = previous["frame_angle"]
		_snapshot["frame_angle"] = lerp_angle(old_frame, _snapshot["frame_angle"], blend)
		_snapshot["velocity"] = Vector2.RIGHT.rotated(_snapshot["frame_angle"])
	_last_size = size
	_cabin_archetype = InternalCabinRenderer.classify_archetype(_design, _mission)
	_environment.update(dt, t, _snapshot["density"])
	if dt > 0.0 and t.engine_firing and t.throttle > 0.05:
		_internal_shake = Vector2(sin(_anim_t * 47.0), cos(_anim_t * 59.0)) * (1.4 * t.throttle)
	else:
		_internal_shake = Vector2.ZERO
	_apply_body_layout()
	queue_redraw()
	_front.queue_redraw()


func _apply_body_layout() -> void:
	if _telemetry == null or _mission == null or _snapshot.is_empty():
		return
	if not internal_view:
		_sun.visible = true
		_planet.visible = true
		_planet.position = _snapshot["planet"]
		_sun.position = _snapshot["sun"]
		_sun.update_body("sun", _snapshot["sun_radius"], _anim_t)
		var light: Vector2 = (_sun.position - _planet.position).normalized()
		_planet.update_body(_mission.target_palette, _snapshot["radius"], _anim_t, Vector3(light.x, light.y, 0.65))
		_origin.visible = _snapshot["show_origin"]
		_origin.position = _snapshot["origin"]
		var origin_light: Vector2 = (_sun.position - _origin.position).normalized()
		_origin.update_body("earth", _snapshot["origin_radius"], _anim_t, Vector3(origin_light.x, origin_light.y, 0.65))
		var area_ext := Rect2(10, 8, size.x - 20.0, maxf(size.y - 20.0, 36.0))
		_assist.visible = _telemetry.in_gravity_assist_window and not bool(_snapshot["finished"])
		_assist.position = Vector2(_snapshot["ship"]) + Vector2(-54, minf(42.0, area_ext.size.y * 0.25))
		_assist.update_body(_mission.gravity_assist_palette, maxf(10.0, minf(area_ext.size.y * 0.12, 30.0 * float(_snapshot["density"]))), _anim_t)
		return

	# First-person internal viewport projection relative to probe heading (attitude_deg).
	var win := InternalCabinRenderer.window_rect(size, _cabin_archetype)
	var win_center := win.get_center() + _internal_shake * 0.5
	var fov_half_deg: float = 60.0
	var px_per_deg: float = (win.size.x * 0.54) / fov_half_deg
	var heading: float = _telemetry.attitude_deg

	# Forward prograde vanishing point shifts opposite to heading offset.
	var rel_pro: float = RocketMath.shortest_angle_diff_deg(heading, 0.0)
	_internal_vanish = Vector2(
		clampf(win_center.x + rel_pro * px_per_deg * 0.55, win.position.x + 24.0, win.end.x - 24.0),
		win_center.y - win.size.y * 0.06
	)

	# Target planet projection inside window (-35 deg approach reference or drifting orbital sweep).
	var target_deg: float = -35.0
	if bool(_snapshot["orbit_captured"]):
		target_deg = RocketMath.normalize_angle_deg(sin(float(_snapshot["orbit_angle"])) * 44.0)
	var rel_target: float = RocketMath.shortest_angle_diff_deg(heading, target_deg)
	var err_shift: float = clampf(_telemetry.trajectory_error_km / maxf(_telemetry.max_trajectory_error_km, 1.0), 0.0, 1.5) * 18.0
	_internal_target_pos = Vector2(win_center.x + rel_target * px_per_deg + err_shift, win_center.y - win.size.y * 0.04)
	var target_rad: float = float(_snapshot["radius"]) * (1.55 if bool(_snapshot["orbit_captured"]) else 1.28)
	var target_bounds := Rect2(win.position - Vector2.ONE * (target_rad + 18.0), win.size + Vector2.ONE * (target_rad * 2.0 + 36.0))
	_internal_target_vis = absf(rel_target) <= 84.0 and target_bounds.has_point(_internal_target_pos)
	_planet.visible = _internal_target_vis
	_planet.position = _internal_target_pos

	# Sun projection (-90 deg).
	var rel_sun: float = RocketMath.shortest_angle_diff_deg(heading, -90.0)
	var sun_pos := Vector2(win_center.x + rel_sun * px_per_deg, win.position.y + win.size.y * 0.24)
	_sun.visible = absf(rel_sun) <= 82.0
	_sun.position = sun_pos
	_sun.update_body("sun", float(_snapshot["sun_radius"]) * 1.15, _anim_t)

	var light_vec: Vector2 = (sun_pos - _internal_target_pos).normalized()
	_planet.update_body(_mission.target_palette, target_rad, _anim_t, Vector3(light_vec.x, light_vec.y, 0.65))

	# Departure Earth visible when looking retrograde / behind (180 deg) on non-LEO legs.
	var rel_origin: float = RocketMath.shortest_angle_diff_deg(heading, 180.0)
	_origin.visible = bool(_snapshot["show_origin"]) and absf(rel_origin) <= 80.0
	_origin.position = Vector2(win_center.x + rel_origin * px_per_deg, win_center.y + win.size.y * 0.08)
	var origin_l: Vector2 = (sun_pos - _origin.position).normalized()
	_origin.update_body("earth", float(_snapshot["origin_radius"]) * 1.2, _anim_t, Vector3(origin_l.x, origin_l.y, 0.65))

	# Gravity assist body passing along the flank when inside assist keyhole.
	_assist.visible = _telemetry.in_gravity_assist_window and not bool(_snapshot["finished"])
	if _assist.visible:
		var rel_ga: float = RocketMath.shortest_angle_diff_deg(heading, 42.0)
		_assist.position = Vector2(win_center.x + rel_ga * px_per_deg, win.end.y - win.size.y * 0.22)
		_assist.update_body(_mission.gravity_assist_palette, maxf(14.0, 34.0 * float(_snapshot["density"])), _anim_t)
		_assist.visible = absf(rel_ga) <= 82.0


func get_scene_snapshot() -> Dictionary:
	var result: Dictionary = _snapshot.duplicate(true)
	result["environment"] = _environment.snapshot()
	result["internal_view"] = internal_view
	result["cabin_archetype"] = _cabin_archetype
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050a16"))
	if _snapshot.is_empty():
		return
	if internal_view:
		var yaw_shift: float = (_telemetry.attitude_deg / 180.0) * size.x * 0.55 if _telemetry != null else 0.0
		for star in _stars:
			var x: float = fposmod(star.x * size.x - yaw_shift * (0.4 + star.z * 0.6), size.x)
			var y: float = fposmod(star.y * size.y + sin(deg_to_rad(_telemetry.attitude_deg)) * 6.0 * star.z, size.y)
			draw_rect(Rect2(Vector2(floorf(x), floorf(y)), Vector2.ONE * (2.0 if star.z > 0.88 else 1.0)), Color(0.70, 0.82, 1.0, star.z))
		var thr: float = _telemetry.throttle if (_telemetry != null and _telemetry.engine_firing) else 0.0
		_environment.draw_forward_warp(self, size, float(_snapshot["density"]), _mission.target_palette, _internal_vanish, thr)
		return
	# Scanline nebula and stars at different depths preserve the pixel-art silhouette.
	for y in range(0, int(size.y), 3):
		var haze: float = pow(maxf(0.0, sin(float(y) / maxf(size.y, 1.0) * PI)), 3.0)
		draw_line(Vector2(0, y), Vector2(size.x, y - 18), Color(0.08, 0.12, 0.24, haze * 0.23))
	for star in _stars:
		var x: float = fposmod(star.x * size.x - _environment.travel_px * (0.025 + star.z * 0.055), size.x)
		var point := Vector2(floorf(x), floorf(star.y * size.y))
		draw_rect(Rect2(point, Vector2.ONE * (2.0 if star.z > 0.9 else 1.0)), Color(0.68, 0.79, 0.99, star.z))
	_environment.draw(self, size, _snapshot["density"], _mission.target_palette)
	_draw_orbit(self, false)
	if _snapshot["ship_behind_planet"]:
		_draw_probe(self)
	if _snapshot["show_origin"]:
		_label(self, Vector2(_snapshot["origin"]) + Vector2(0, -float(_snapshot["origin_radius"]) - 8), Loc.pick("TIERRA / PARTIDA", "EARTH / ORIGIN"), ThemeFactory.COL_CYAN)
	if _telemetry.progress_norm < 0.10:
		_draw_separation(self)
	if _assist.visible:
		draw_arc(_assist.position, _assist.radius + 12.0, -PI, 0.0, 30, ThemeFactory.COL_AMBER)
		_label(self, _assist.position + Vector2(-25, _assist.radius + 10), _mission.gravity_assist_body, ThemeFactory.COL_AMBER)


func _draw_front(c: CanvasItem) -> void:
	if _snapshot.is_empty():
		return
	if internal_view:
		_draw_internal_foreground(c)
		return
	_draw_orbit(c, true)
	if not _snapshot["ship_behind_planet"]:
		_draw_probe(c)
	var planet: Vector2 = _snapshot["planet"]
	var r: float = _snapshot["radius"]
	_label(c, _sun.position + Vector2(_sun.radius + 10.0, 3), Loc.pick("SOL", "SUN"), ThemeFactory.COL_AMBER)
	var body_name: String = {"earth": Loc.pick("TIERRA / LEO", "EARTH / LEO"), "moon": Loc.pick("LUNA", "MOON"), "mars": Loc.pick("MARTE", "MARS")}.get(_mission.target_palette, _mission.target_name)
	_label(c, planet + Vector2(-r * 0.6, r + 13), body_name, ThemeFactory.COL_CYAN)
	if size.y > 120.0:
		if not _snapshot["finished"] and guidance_visible:
			_draw_guidance(c)
			_draw_local_compass(c)
		else:
			var ship: Vector2 = _snapshot["ship"]
			var velocity: Vector2 = _snapshot["velocity"]
			_arrow(c, ship, ship + velocity * 38.0, ThemeFactory.COL_CYAN)
	if _telemetry.in_shadow:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.09, 0.27))
		_label(c, Vector2(12, size.y - 10), Loc.pick("ECLIPSE: GENERACIÓN SOLAR = 0 W", "ECLIPSE: SOLAR OUTPUT = 0 W"), ThemeFactory.COL_AMBER)
	if _telemetry.in_solar_storm:
		for i in range(8):
			var x: float = fposmod(i * 91.0 + _anim_t * 120.0, size.x)
			c.draw_line(Vector2(x, 0), Vector2(x - 20, 18), Color(1.0, 0.60, 0.2, 0.5))


func _draw_internal_foreground(c: CanvasItem) -> void:
	var win := InternalCabinRenderer.window_rect(size, _cabin_archetype)
	var captured: bool = bool(_snapshot["orbit_captured"])
	var body_name: String = {"earth": Loc.pick("TIERRA / LEO", "EARTH / LEO"), "moon": Loc.pick("LUNA", "MOON"), "mars": Loc.pick("MARTE", "MARS")}.get(_mission.target_palette, _mission.target_name)

	# 1. Perspective trajectory tunnel & destination vector inside the window.
	if not _snapshot["finished"]:
		var aim_target: Vector2 = _internal_target_pos if _internal_target_vis else _internal_vanish
		var start_base := Vector2(win.get_center().x, win.end.y - 8.0)
		var path_col: Color = ThemeFactory.COL_GREEN if captured else (ThemeFactory.COL_RED if _telemetry.wrong_burn_direction else ThemeFactory.COL_AMBER)
		if not captured and _telemetry.trajectory_error_km <= _telemetry.max_trajectory_error_km * 0.45:
			path_col = ThemeFactory.COL_CYAN
		# Left & right corridor rails converging downrange.
		c.draw_line(start_base + Vector2(-46.0, 0.0), aim_target + Vector2(-8.0, 0.0), Color(path_col, 0.32), 1.5)
		c.draw_line(start_base + Vector2(46.0, 0.0), aim_target + Vector2(8.0, 0.0), Color(path_col, 0.32), 1.5)
		# Moving perspective brackets flowing forward along trajectory to show ship motion.
		var gate_scroll: float = fposmod(_environment.travel_px * 0.012, 1.0)
		for idx in range(5):
			var depth: float = fposmod(float(idx) / 5.0 + gate_scroll, 1.0)
			var perspective: float = pow(depth, 1.45)
			var gate_pos: Vector2 = aim_target.lerp(start_base, perspective)
			var half_w: float = lerpf(8.0, 44.0, perspective)
			var half_h: float = lerpf(4.0, 16.0, perspective)
			var alpha: float = clampf(sin(depth * PI) * 0.85, 0.15, 0.85)
			c.draw_rect(Rect2(gate_pos - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0)), Color(path_col, alpha), false, 1.5)

	# 2. Target planet & sun labels inside the glass.
	if _sun.visible and win.grow(16.0).has_point(_sun.position):
		_label(c, _sun.position + Vector2(_sun.radius + 8.0, 4.0), Loc.pick("SOL", "SUN"), ThemeFactory.COL_AMBER)
	if _planet.visible:
		_label(c, _planet.position + Vector2(-28.0, _planet.radius + 14.0), body_name, ThemeFactory.COL_CYAN)
	if _origin.visible and win.grow(16.0).has_point(_origin.position):
		_label(c, _origin.position + Vector2(-34.0, -_origin.radius - 8.0), Loc.pick("TIERRA (ATRÁS)", "EARTH (ASTERN)"), ThemeFactory.COL_MUTED)
	if _assist.visible and win.grow(16.0).has_point(_assist.position):
		_label(c, _assist.position + Vector2(-26.0, _assist.radius + 10.0), _mission.gravity_assist_body, ThemeFactory.COL_AMBER)

	# 3. Science scan cone from lower sensor bay to target + fairing jettison at departure.
	if _telemetry.progress_norm < 0.10:
		var sep_t: float = clampf(_telemetry.progress_norm / 0.10, 0.0, 1.0)
		var scale_f: float = lerpf(1.0, 0.35, sep_t)
		for side in [-1.0, 1.0]:
			var fairing_pos := Vector2(win.get_center().x + side * lerpf(55.0, win.size.x * 0.44, sep_t), win.get_center().y + sep_t * 42.0)
			c.draw_set_transform(fairing_pos, side * sep_t * 0.55, Vector2.ONE * scale_f)
			var half_shell := PackedVector2Array([Vector2(-12, -28), Vector2(10, -20), Vector2(14, 24), Vector2(-10, 26)])
			c.draw_colored_polygon(half_shell, Color("c4d0e0", 1.0 - sep_t * 0.45))
			c.draw_polyline(half_shell + PackedVector2Array([half_shell[0]]), Color("4e6176"), 1.5)
			c.draw_set_transform(Vector2.ZERO)
		_label(c, Vector2(win.get_center().x - 54.0, win.position.y + 38.0), Loc.pick("SEPARACIÓN DE COFIA", "FAIRING JETTISON"), ThemeFactory.COL_MUTED)
	if _planet.visible and (_telemetry.attitude_mode == FlightTelemetry.AttitudeMode.TARGET or _capture_flash_s > 0.0):
		var sensor_origin := Vector2(win.get_center().x, win.end.y - 10.0)
		var scan_col: Color = ThemeFactory.COL_GREEN if _capture_flash_s > 0.0 or (_telemetry.target_pointing_ok and _telemetry.in_flyby_window) else ThemeFactory.COL_AMBER
		c.draw_line(sensor_origin, _planet.position, Color(scan_col, 0.72), 1.5)
		c.draw_arc(_planet.position, maxf(10.0, _planet.radius * 0.65), 0.0, TAU, 16, Color(scan_col, 0.70), 1.5)

	# 4. Real spacecraft exterior attachments + distinct model interior hull.
	InternalCabinRenderer.draw_exterior_attachments(c, size, _design, _telemetry, _deploy_ratio, _anim_t, _capture_flash_s, _cabin_archetype, _internal_shake)
	InternalCabinRenderer.draw_interior_frame(c, size, _design, _telemetry, _cabin_archetype, _anim_t, _internal_shake)

	# 5. Window heading tape & subtle flight alerts when guides are visible.
	if size.y > 120.0 and guidance_visible and not _snapshot["finished"]:
		_draw_internal_heading_tape(c, win)
	if _telemetry.in_shadow:
		c.draw_rect(Rect2(win.position, win.size), Color(0.02, 0.03, 0.09, 0.25))
		_label(c, Vector2(win.position.x + 10.0, win.end.y - 12.0), Loc.pick("ECLIPSE: SOLAR = 0 W", "ECLIPSE: SOLAR = 0 W"), ThemeFactory.COL_AMBER)
	if _telemetry.in_insertion_window and not _snapshot["finished"]:
		var remaining_dv: float = maxf(0.0, _telemetry.insertion_dv_target - _telemetry.insertion_dv_burned)
		_label(c, Vector2(win.get_center().x - 62.0, win.end.y - 26.0), Loc.pick("POR FRENAR: %.0f m/s", "TO BRAKE: %.0f m/s") % remaining_dv, ThemeFactory.COL_AMBER)
	if _telemetry.in_solar_storm:
		for i in range(8):
			var x: float = fposmod(i * 91.0 + _anim_t * 120.0, win.size.x) + win.position.x
			c.draw_line(Vector2(x, win.position.y), Vector2(x - 18.0, win.position.y + 18.0), Color(1.0, 0.60, 0.2, 0.5))


func _draw_internal_heading_tape(c: CanvasItem, win: Rect2) -> void:
	var tape_w: float = minf(win.size.x * 0.72, 380.0)
	var tape := Rect2(win.get_center().x - tape_w * 0.5, win.position.y + 6.0, tape_w, 22.0)
	c.draw_rect(tape, Color(0.03, 0.07, 0.12, 0.80))
	c.draw_rect(tape, Color("2e4d69"), false, 1.0)
	var mid_x: float = tape.get_center().x
	c.draw_line(Vector2(mid_x, tape.end.y - 5.0), Vector2(mid_x, tape.end.y + 2.0), ThemeFactory.COL_WHITE, 2.0)
	var markers := [
		["PRO", 0.0, ThemeFactory.COL_CYAN],
		[Loc.pick("OBJ", "TGT"), -35.0, ThemeFactory.COL_GREEN],
		[Loc.pick("SOL", "SUN"), -90.0, ThemeFactory.COL_AMBER],
		[Loc.pick("TIE", "EAR"), 90.0, ThemeFactory.COL_CYAN],
		["RET", 180.0, ThemeFactory.COL_RED],
	]
	for item in markers:
		var rel: float = RocketMath.shortest_angle_diff_deg(_telemetry.attitude_deg, float(item[1]))
		if absf(rel) <= 75.0:
			var mx: float = mid_x + (rel / 75.0) * (tape_w * 0.45)
			c.draw_line(Vector2(mx, tape.position.y + 2.0), Vector2(mx, tape.position.y + 6.0), item[2], 1.5)
			_label(c, Vector2(mx - 10.0, tape.position.y + 18.0), str(item[0]), item[2])
	var rel_cmd: float = RocketMath.shortest_angle_diff_deg(_telemetry.attitude_deg, _telemetry.target_attitude_deg)
	if absf(rel_cmd) <= 75.0 and not _telemetry.attitude_aligned:
		var cx: float = mid_x + (rel_cmd / 75.0) * (tape_w * 0.45)
		c.draw_circle(Vector2(cx, tape.end.y - 2.0), 3.0, ThemeFactory.COL_AMBER)


func _draw_orbit(c: CanvasItem, front_half: bool) -> void:
	var planet: Vector2 = _snapshot["planet"]
	var radii: Vector2 = _snapshot["orbit_radii"]
	var captured: bool = _snapshot["orbit_captured"]
	var col: Color = ThemeFactory.COL_GREEN if captured else Color(0.30, 0.53, 0.66, 0.38)
	if _telemetry.status == FlightTelemetry.Status.FAILED_OBJECTIVES:
		col = ThemeFactory.COL_AMBER
	for i in range(64):
		var angle: float = float(i) * TAU / 64.0
		if (sin(angle) >= 0.0) != front_half:
			continue
		var a: Vector2 = MissionSceneProjection.orbit_point(planet, radii, angle)
		var b: Vector2 = MissionSceneProjection.orbit_point(planet, radii, angle + TAU / 64.0)
		c.draw_line(a, b, col, 1.0 if not captured else 2.0)
	if not front_half or captured:
		return
	var ship: Vector2 = _snapshot["ship"]
	var error_factor: float = clampf(_telemetry.trajectory_error_km / maxf(_telemetry.max_trajectory_error_km, 1.0), 0.0, 2.0)
	var goal: Vector2 = planet + Vector2(-radii.x * 0.70, -radii.y * 0.65)
	var miss: Vector2 = planet + Vector2(radii.x * 1.8, -radii.y * (1.2 + error_factor))
	var capture_mix: float = _snapshot["insertion_ratio"]
	if _snapshot["finished"]:
		capture_mix = 0.0
	var end: Vector2 = miss.lerp(goal, capture_mix)
	var velocity: Vector2 = _snapshot["velocity"]
	var control_a: Vector2 = ship + velocity * minf(110.0, ship.distance_to(end) * 0.5)
	var control_b: Vector2 = end - velocity.rotated(-0.45) * minf(90.0, ship.distance_to(end) * 0.4)
	var trajectory_color: Color = ThemeFactory.COL_RED if _snapshot["finished"] or _telemetry.wrong_burn_direction else ThemeFactory.COL_AMBER
	for i in range(24):
		var f: float = float(i) / 24.0
		var point: Vector2 = ship.bezier_interpolate(control_a, control_b, end, f)
		c.draw_rect(Rect2(point.floor(), Vector2(2, 1)), trajectory_color)
	if not _snapshot["finished"]:
		# Animated pulses flowing downrange along the transfer curve + wake behind ship.
		var pulse_shift: float = fposmod(_environment.travel_px * 0.010, 1.0)
		for j in range(4):
			var fp: float = fposmod(float(j) * 0.25 + pulse_shift, 1.0)
			var pt: Vector2 = ship.bezier_interpolate(control_a, control_b, end, fp)
			c.draw_rect(Rect2(pt.floor() - Vector2(1, 1), Vector2(3, 3)), Color(ThemeFactory.COL_CYAN, 0.80))
		for s in range(3):
			var trail_phase: float = fposmod(_environment.travel_px * 0.03 + float(s) * 0.33, 1.0)
			var tail_start: Vector2 = ship - velocity * (16.0 + trail_phase * 22.0)
			c.draw_line(tail_start, tail_start - velocity * 10.0, Color(ThemeFactory.COL_CYAN, (1.0 - trail_phase) * 0.45), 1.5)
	if size.y > 120.0:
		_label(c, end + Vector2(-55, -6), Loc.pick("PREDICCIÓN", "PREDICTION") if not _snapshot["finished"] else Loc.pick("SIN CAPTURA", "NO CAPTURE"), trajectory_color)


func _draw_probe(c: CanvasItem) -> void:
	var pos: Vector2 = _snapshot["ship"]
	var scale_factor: float = _snapshot["ship_scale"]
	var frame_angle: float = _snapshot["frame_angle"]
	# A compressed body axis gives perspective while preserving installed modules.
	ProbeVisualRenderer.draw_flight_horizontal(c, pos, _design, _telemetry, _deploy_ratio, _anim_t, rad_to_deg(frame_angle), Vector2(scale_factor, scale_factor * 0.82))


func _draw_guidance(c: CanvasItem) -> void:
	var ship: Vector2 = _snapshot["ship"]
	var frame: float = _snapshot["frame_angle"]
	var velocity: Vector2 = _snapshot["velocity"]
	_arrow(c, ship, ship + velocity * 64.0, ThemeFactory.COL_CYAN)
	_label(c, ship + velocity * 69.0 + Vector2(-10, -4), "v / PRO 0°", ThemeFactory.COL_CYAN)
	var actual: Vector2 = MissionSceneProjection.reference_direction(_telemetry.attitude_deg, frame)
	_arrow(c, ship, ship + actual * 43.0, ThemeFactory.COL_WHITE)
	var desired: Vector2 = MissionSceneProjection.reference_direction(_telemetry.target_attitude_deg, frame)
	c.draw_arc(ship, 34, frame + deg_to_rad(_telemetry.attitude_deg), frame + deg_to_rad(_telemetry.attitude_deg + RocketMath.shortest_angle_diff_deg(_telemetry.attitude_deg, _telemetry.target_attitude_deg)), 20, ThemeFactory.COL_AMBER)
	if not _telemetry.attitude_aligned:
		_arrow(c, ship, ship + desired * 53.0, ThemeFactory.COL_AMBER)
	if _telemetry.engine_firing:
		_arrow(c, ship, ship + actual * 76.0, ThemeFactory.COL_RED if _telemetry.wrong_burn_direction else ThemeFactory.COL_AMBER)
		var sign_label: String = Loc.pick("FRENADO", "BRAKE") if actual.dot(velocity) < -0.7 else Loc.pick("EMPUJE", "THRUST")
		_label(c, ship + actual * 80.0 + Vector2(-18, 10), sign_label, ThemeFactory.COL_AMBER)
	if _telemetry.attitude_mode == FlightTelemetry.AttitudeMode.SOLAR:
		c.draw_line(ship, _sun.position, Color(0.95, 0.74, 0.25, 0.30))
	elif _telemetry.attitude_mode == FlightTelemetry.AttitudeMode.EARTH:
		var ground: Vector2 = ship + MissionSceneProjection.reference_direction(90.0, frame) * 68.0
		c.draw_circle(ground, 5, ThemeFactory.COL_CYAN)
		c.draw_line(ship, ground, ThemeFactory.COL_CYAN if _telemetry.comms_link_factor >= 0.9 else ThemeFactory.COL_MUTED)
		_label(c, ground + Vector2(9, 3), Loc.pick("RADIO / TIERRA +90°", "RADIO / EARTH +90°"), ThemeFactory.COL_CYAN)
	if _telemetry.attitude_mode == FlightTelemetry.AttitudeMode.TARGET or _capture_flash_s > 0.0:
		var surface: Vector2 = Vector2(_snapshot["planet"]).move_toward(ship, float(_snapshot["radius"]) * 0.80)
		var scan_col: Color = ThemeFactory.COL_GREEN if _capture_flash_s > 0.0 or (_telemetry.target_pointing_ok and _telemetry.in_flyby_window) else ThemeFactory.COL_AMBER
		if _telemetry.attitude_mode == FlightTelemetry.AttitudeMode.TARGET:
			c.draw_line(ship, surface, scan_col)
		c.draw_arc(surface, 8, 0, TAU, 12, scan_col)
		_label(c, surface + Vector2(-20, -12), Loc.pick("CIENCIA CAPTURADA", "SCIENCE CAPTURED") if _capture_flash_s > 0.0 else Loc.pick("ZONA DE OBSERVACIÓN", "OBSERVATION ZONE"), scan_col)
	if _telemetry.in_insertion_window and not _snapshot["finished"]:
		var planet: Vector2 = _snapshot["planet"]
		var remaining_dv: float = maxf(0.0, _telemetry.insertion_dv_target - _telemetry.insertion_dv_burned)
		_label(c, planet + Vector2(-60.0, float(_snapshot["radius"]) + 25.0), Loc.pick("POR FRENAR: %.0f m/s", "TO BRAKE: %.0f m/s") % remaining_dv, ThemeFactory.COL_AMBER)


func _draw_local_compass(c: CanvasItem) -> void:
	var center := Vector2(94, 62)
	c.draw_rect(Rect2(5, 0, 206, 114), Color(0.025, 0.065, 0.11, 0.85))
	c.draw_rect(Rect2(5, 0, 206, 114), Color("2b435c"), false, 1.0)
	_label(c, Vector2(12, 16), Loc.pick("ACTITUD LOCAL", "LOCAL ATTITUDE"), ThemeFactory.COL_MUTED)
	c.draw_arc(center, 25.0, 0, TAU, 32, Color("3a526b"))
	c.draw_line(center - Vector2(27, 0), center + Vector2(27, 0), Color("344b5d"))
	c.draw_line(center - Vector2(0, 27), center + Vector2(0, 27), Color("344b5d"))
	_label(c, Vector2(127, 67), "PRO 0", ThemeFactory.COL_CYAN)
	_label(c, Vector2(12, 67), "RET", ThemeFactory.COL_AMBER)
	_label(c, Vector2(82, 32), Loc.pick("SOL", "SUN"), ThemeFactory.COL_AMBER)
	_label(c, Vector2(68, 107), Loc.pick("TIERRA", "EARTH"), ThemeFactory.COL_CYAN)
	_label(c, Vector2(126, 38), Loc.pick("OBJ -35", "TGT -35"), ThemeFactory.COL_GREEN)
	var desired: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(_telemetry.target_attitude_deg))
	var actual: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(_telemetry.attitude_deg))
	c.draw_line(center, center + desired * 23, ThemeFactory.COL_AMBER)
	_arrow(c, center, center + actual * 21, ThemeFactory.COL_WHITE)


func _draw_separation(c: CanvasItem) -> void:
	var ship: Vector2 = _snapshot["ship"]
	var backwards: Vector2 = -Vector2(_snapshot["velocity"])
	var away: float = 42.0 + _telemetry.progress_norm * 350.0
	var booster: Vector2 = ship + backwards * away
	c.draw_set_transform(booster, Vector2(_snapshot["velocity"]).angle(), Vector2.ONE)
	c.draw_rect(Rect2(-30, -6, 52, 12), Color("707e94"))
	c.draw_rect(Rect2(-26, -5, 38, 4), Color("d8e0ec"))
	c.draw_rect(Rect2(-32, -4, 5, 8), Color("303b50"))
	c.draw_polygon(PackedVector2Array([Vector2(22, -6), Vector2(31, 0), Vector2(22, 6)]), PackedColorArray([Color("bac6dc")]))
	c.draw_set_transform(Vector2.ZERO)
	if size.y > 120.0:
		_label(c, booster + Vector2(-42, 24), Loc.pick("ETAPA SUPERIOR", "UPPER STAGE"), ThemeFactory.COL_MUTED)


func _arrow(c: CanvasItem, start: Vector2, end: Vector2, col: Color) -> void:
	var direction: Vector2 = (end - start).normalized()
	c.draw_line(start, end, col, 1.5)
	c.draw_line(end, end - direction.rotated(0.5) * 7, col, 1.5)
	c.draw_line(end, end - direction.rotated(-0.5) * 7, col, 1.5)


func _label(c: CanvasItem, point: Vector2, text: String, col: Color) -> void:
	var font: Font = ThemeFactory.get_ui_font()
	var font_size: int = ThemeFactory.get_ui_font_size()
	if font != null:
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x: float = clampf(point.x, 4.0, maxf(4.0, size.x - text_w - 6.0))
		var y: float = clampf(point.y, float(font_size) + 2.0, size.y - 4.0)
		var pos := Vector2(x, y).floor()
		c.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.04, 0.08, 0.90))
		c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


class _Foreground extends Control:
	var scene: MissionSpaceView
	func _draw() -> void:
		scene._draw_front(self)
