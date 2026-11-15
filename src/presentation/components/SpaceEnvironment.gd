class_name SpaceEnvironment
extends RefCounted
## Decorative depth cues. No collisions, force, fuel or science changes.

var travel_px: float = 0.0
var visual_speed: float = 38.0
var elapsed_s: float = 0.0
var _motes: Array[Vector4] = []
var _objects: Array[Vector4] = []


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91337
	for i in range(48):
		_motes.append(Vector4(rng.randf(), rng.randf_range(0.10, 0.92), rng.randf_range(0.4, 1.7), rng.randf_range(0.6, 1.4)))
	for i in range(8):
		_objects.append(Vector4(rng.randf(), rng.randf_range(0.15, 0.86), rng.randf_range(0.2, 0.95), rng.randf_range(0.0, TAU)))


func reset() -> void:
	travel_px = 0.0
	visual_speed = 38.0
	elapsed_s = 0.0


func update(dt: float, t: FlightTelemetry, density: float) -> void:
	if dt <= 0.0:
		return
	visual_speed = 38.0
	if t.in_insertion_window:
		var braking: float = clampf(t.insertion_dv_burned / maxf(t.insertion_dv_target, 1.0), 0.0, 1.0)
		visual_speed = lerpf(38.0, 8.0, braking)
	elif t.engine_firing:
		visual_speed += 12.0 * t.throttle
	if t.status != FlightTelemetry.Status.IN_FLIGHT:
		visual_speed = 4.0
	elapsed_s += dt
	travel_px += dt * visual_speed * density


func draw(c: CanvasItem, dimensions: Vector2, density: float, palette: String) -> void:
	if dimensions.x <= 0.0 or dimensions.y <= 0.0:
		return
	for mote in _motes:
		var x: float = fposmod(mote.x * dimensions.x - travel_px * mote.z, dimensions.x + 32.0) - 16.0
		var point := Vector2(floorf(x), floorf(mote.y * dimensions.y))
		var side: float = maxf(1.0, mote.w * density)
		var color := Color(0.48, 0.62, 0.76, 0.25 + mote.z * 0.16)
		c.draw_rect(Rect2(point, Vector2(side, maxf(1.0, side * 0.65))), color)
		if mote.z > 1.2:
			c.draw_line(point, point + Vector2(4.0 * density, 0), Color(color, 0.15))
	for i in range(_objects.size()):
		var object: Vector4 = _objects[i]
		var x: float = fposmod(object.x * dimensions.x - travel_px * (0.22 + object.z * 0.55), dimensions.x + 160.0) - 80.0
		var point := Vector2(x, object.y * dimensions.y + sin(elapsed_s * 0.15 + i) * 3.0)
		var radius: float = (2.0 + object.z * 4.0) * density
		c.draw_set_transform(point.floor(), object.w + elapsed_s * 0.04)
		if palette == "earth" and i % 3 == 0:
			c.draw_rect(Rect2(-radius, -radius * 0.6, radius * 2, radius * 1.2), Color("8297ad"))
			c.draw_rect(Rect2(-radius * 3.0, -radius * 0.40, radius * 1.8, radius * 0.8), Color("244a72"))
			c.draw_rect(Rect2(radius * 1.2, -radius * 0.40, radius * 1.8, radius * 0.8), Color("244a72"))
		else:
			var polygon := PackedVector2Array()
			for vertex in range(7):
				var angle: float = float(vertex) * TAU / 7.0
				var roughness: float = 0.75 + sin(vertex * 7.3 + object.w) * 0.20
				polygon.append(Vector2(cos(angle), sin(angle)) * radius * roughness)
			c.draw_colored_polygon(polygon, Color("263440"))
			c.draw_line(polygon[3], polygon[4], Color("586573"), 1.0)
		c.draw_set_transform(Vector2.ZERO)


func draw_forward_warp(
	c: CanvasItem,
	dimensions: Vector2,
	density: float,
	palette: String,
	vanish: Vector2,
	throttle_ratio: float
) -> void:
	if dimensions.x <= 0.0 or dimensions.y <= 0.0:
		return
	var max_span: float = maxf(dimensions.x, dimensions.y) * 0.65
	var phase_scroll: float = travel_px * 0.0085
	for i in range(_motes.size()):
		var mote: Vector4 = _motes[i]
		var z_prog: float = fposmod(mote.z * 0.65 + phase_scroll * (0.45 + mote.z * 0.55), 1.0)
		var radial: float = pow(z_prog, 1.55)
		var angle: float = (mote.x * TAU) + (mote.y - 0.5) * 2.4
		var dir := Vector2(cos(angle), sin(angle) * 0.62)
		var point := vanish + dir * (radial * max_span)
		if not Rect2(Vector2(-12, -12), dimensions + Vector2(24, 24)).has_point(point):
			continue
		var side: float = maxf(1.0, (0.8 + z_prog * 2.4) * density)
		var alpha: float = clampf(z_prog * 0.68, 0.08, 0.72)
		var color := Color(0.56, 0.75, 0.98, alpha)
		c.draw_rect(Rect2(point.floor(), Vector2.ONE * side), color)
		if z_prog > 0.25 or throttle_ratio > 0.15:
			var streak: float = (3.5 + 14.0 * throttle_ratio) * z_prog * density
			c.draw_line(point, point - dir * streak, Color(color, alpha * 0.55), 1.0)
	for i in range(_objects.size()):
		var obj: Vector4 = _objects[i]
		var z_prog: float = fposmod(obj.z + phase_scroll * 0.38, 1.0)
		var radial: float = pow(z_prog, 1.7)
		var angle: float = obj.w + (obj.x - 0.5) * 1.4
		var dir := Vector2(cos(angle), sin(angle) * 0.55)
		var point := vanish + dir * (radial * max_span * 0.92)
		if not Rect2(Vector2(-32, -32), dimensions + Vector2(64, 64)).has_point(point):
			continue
		var radius: float = maxf(1.5, (1.5 + z_prog * 8.5) * density)
		c.draw_set_transform(point.floor(), obj.w + elapsed_s * 0.08)
		if palette == "earth" and i % 3 == 0:
			c.draw_rect(Rect2(-radius, -radius * 0.55, radius * 2.0, radius * 1.1), Color("8297ad"))
			c.draw_rect(Rect2(-radius * 2.8, -radius * 0.35, radius * 1.6, radius * 0.7), Color("244a72"))
			c.draw_rect(Rect2(radius * 1.2, -radius * 0.35, radius * 1.6, radius * 0.7), Color("244a72"))
		else:
			var polygon := PackedVector2Array()
			for vertex in range(7):
				var v_angle: float = float(vertex) * TAU / 7.0
				var roughness: float = 0.76 + sin(vertex * 7.3 + obj.w) * 0.18
				polygon.append(Vector2(cos(v_angle), sin(v_angle)) * radius * roughness)
			c.draw_colored_polygon(polygon, Color("293846"))
			c.draw_line(polygon[3], polygon[4], Color("657688"), 1.0)
		c.draw_set_transform(Vector2.ZERO)


func snapshot() -> Dictionary:
	return {"travel_px": travel_px, "visual_speed": visual_speed, "object_count": _objects.size(), "mote_count": _motes.size()}
