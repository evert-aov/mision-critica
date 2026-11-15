class_name MissionSceneProjection
extends RefCounted
## Presentation-only compressed scene geometry. Does not integrate or change flight physics.


static func reference_direction(local_angle_deg: float, frame_angle: float) -> Vector2:
	return Vector2.RIGHT.rotated(frame_angle + deg_to_rad(local_angle_deg))


static func orbit_point(center: Vector2, radii: Vector2, angle: float) -> Vector2:
	return center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(-0.24)


static func sample(mission: MissionSpec, t: FlightTelemetry, area: Rect2, ending_time: float = 0.0) -> Dictionary:
	var p: float = clampf(t.progress_norm, 0.0, 1.0)
	var density: float = clampf(area.size.x / 612.0, 1.0, 2.2)
	var is_leo: bool = mission.target_palette == "earth"
	var finished: bool = t.status != FlightTelemetry.Status.IN_FLIGHT and t.status != FlightTelemetry.Status.READY
	var orbital_result: bool = t.status == FlightTelemetry.Status.VICTORY or t.status == FlightTelemetry.Status.FAILED_OBJECTIVES
	var min_ins: float = t.insertion_dv_target - mission.delta_v_tolerance
	var max_ins: float = t.insertion_dv_target + mission.delta_v_tolerance * 1.8
	var captured_orbit: bool = orbital_result or (not finished and t.in_insertion_window and t.insertion_dv_burned >= min_ins and t.insertion_dv_burned <= max_ins and t.trajectory_error_km <= mission.max_trajectory_error_km)
	var insertion_ratio: float = clampf(t.insertion_dv_burned / maxf(t.insertion_dv_target, 1.0), 0.0, 1.0)
	# Advance the camera throughout the transfer, including early coasting. A linear
	# component prevents the destination from appearing fixed until the final leg.
	var transit: float = clampf(p / maxf(mission.insertion_window_start_norm, 0.01), 0.0, 1.0)
	var approach: float = transit * 0.70 + transit * transit * 0.30
	var radius_fraction: float = lerpf(0.20, 0.30, approach) if is_leo else lerpf(0.055, 0.28, approach)
	var radius: float = minf(area.size.y * radius_fraction, 76.0 * density)
	radius = maxf(radius, 8.0 * density)
	var planet: Vector2 = area.position + area.size * Vector2(lerpf(0.88, 0.69, approach), lerpf(0.50, 0.57, transit))
	var ship: Vector2 = area.position + area.size * Vector2(lerpf(0.28, 0.46, transit), 0.57 - sin(transit * PI) * 0.10)
	var velocity := Vector2(1.0, -0.20 + p * 0.35).normalized()
	var orbit_radii := Vector2(radius * 1.85, radius * 0.82)
	var orbit_angle: float = -2.5 + p * 1.5
	var stage: String = Loc.pick("TRÁNSITO INTERPLANETARIO", "INTERPLANETARY CRUISE") if mission.target_palette == "mars" else Loc.pick("TRÁNSITO CISLUNAR", "CISLUNAR CRUISE")
	if is_leo:
		stage = Loc.pick("ARCO TERRESTRE / LEO 420 km", "EARTH ARC / LEO 420 km")
		planet = area.position + area.size * Vector2(lerpf(0.83, 0.68, approach), lerpf(0.67, 0.60, transit))
	if p < 0.10:
		stage = Loc.pick("SEPARACIÓN DEL LANZADOR", "BOOSTER SEPARATION")
	elif t.in_gravity_assist_window:
		stage = Loc.pick("HONDA: ", "ASSIST: ") + mission.gravity_assist_body
	elif t.in_flyby_window and not t.in_insertion_window:
		stage = Loc.pick("SOBREVUELO CIENTÍFICO", "SCIENCE FLYBY")
	elif not is_leo and p >= 0.43:
		stage = Loc.pick("APROXIMACIÓN A ", "APPROACH TO ") + mission.target_name
	if t.in_insertion_window:
		stage = Loc.pick("INSERCIÓN / FRENADO RETRÓGRADO", "INSERTION / RETRO BRAKING")
		var orbital_ship: Vector2 = orbit_point(planet, orbit_radii, orbit_angle)
		ship = ship.lerp(orbital_ship, insertion_ratio * 0.65)
	if captured_orbit:
		if finished:
			planet = area.position + area.size * Vector2(0.48, 0.48)
			radius = maxf(10.0, minf(area.size.y * 0.29, 74.0 * density))
			orbit_radii = Vector2(radius * 1.85, radius * 0.82)
			orbit_angle = -1.1 + ending_time * 0.35
		ship = orbit_point(planet, orbit_radii, orbit_angle)
		velocity = Vector2(-sin(orbit_angle) * orbit_radii.x, cos(orbit_angle) * orbit_radii.y).rotated(-0.24).normalized()
		stage = Loc.pick("ÓRBITA ESTABLE", "STABLE ORBIT") if t.status != FlightTelemetry.Status.FAILED_OBJECTIVES else Loc.pick("ÓRBITA LOGRADA / CIENCIA INCOMPLETA", "ORBIT ACHIEVED / SCIENCE INCOMPLETE")
	elif finished:
		planet = area.position + area.size * Vector2(0.28, 0.48)
		var failed_en_route: bool = p < mission.insertion_window_start_norm
		radius = minf(radius, 24.0 * density) if failed_en_route else maxf(10.0, minf(area.size.y * 0.28, 70.0 * density))
		orbit_radii = Vector2(radius * 1.85, radius * 0.82)
		ship = planet + Vector2(radius + 37.0 + minf(ending_time * 5.0, 80.0), -radius * 0.55 - minf(ending_time * 2.0, 40.0))
		stage = Loc.pick("SONDA SIN ENERGÍA", "PROBE OUT OF POWER") if t.status == FlightTelemetry.Status.FAILED_POWER else Loc.pick("TRAYECTORIA SIN CAPTURA", "ESCAPE TRAJECTORY")
	var origin: Vector2 = area.position + area.size * Vector2(lerpf(0.13, 0.01, transit), lerpf(0.70, 0.81, transit))
	var origin_radius: float = maxf(5.0, area.size.y * 0.20 / (1.0 + transit * 4.5))
	if not captured_orbit and not finished:
		# Compressed incoming-leg frame: the target lies at the game's -35° sensor reference.
		# Once captured, the projected orbital tangent above defines the motion direction.
		velocity = (planet - ship).normalized().rotated(deg_to_rad(35.0))
	var frame_angle: float = velocity.angle()
	# Angular size is a scenario/camera approximation; keep the star compact and pushed to the far viewport rim.
	var sun_radius: float = 9.0 * density / maxf(mission.distance_au, 0.5)
	var sun_direction: Vector2 = reference_direction(-90.0, frame_angle)
	var padding: float = minf(sun_radius + 4.0, area.size.y * 0.25)
	var safe_area: Rect2 = area.grow(-padding)
	var ray_length: float = area.size.x + area.size.y
	if sun_direction.x > 0.001:
		ray_length = minf(ray_length, (safe_area.end.x - ship.x) / sun_direction.x)
	elif sun_direction.x < -0.001:
		ray_length = minf(ray_length, (safe_area.position.x - ship.x) / sun_direction.x)
	if sun_direction.y > 0.001:
		ray_length = minf(ray_length, (safe_area.end.y - ship.y) / sun_direction.y)
	elif sun_direction.y < -0.001:
		ray_length = minf(ray_length, (safe_area.position.y - ship.y) / sun_direction.y)
	var sun: Vector2 = (ship + sun_direction * maxf(ray_length, 20.0)).clamp(safe_area.position, safe_area.end)
	return {
		"stage": stage, "planet": planet, "radius": radius, "ship": ship,
		"origin": origin, "origin_radius": origin_radius, "show_origin": not is_leo and not finished,
		"velocity": velocity, "frame_angle": frame_angle, "orbit_radii": orbit_radii,
		"orbit_angle": orbit_angle, "orbit_captured": captured_orbit, "finished": finished,
		"insertion_ratio": insertion_ratio, "ship_behind_planet": captured_orbit and sin(orbit_angle) < -0.12,
		"ship_scale": (0.46 if area.size.y < 100.0 else 0.70) * density * (0.86 if captured_orbit and sin(orbit_angle) < 0.0 else 1.0),
		"sun": sun, "sun_radius": sun_radius, "density": density,
	}
