@tool
class_name ViewportWindow
extends Control
## Top cockpit viewport: parallax starfield, approaching target body, trajectory,
## pixel exhaust particles, and environmental hazard overlays.

var _stars: Array[Dictionary] = []
var _planet_sprite: Sprite2D
var _exhaust_particles: CPUParticles2D
var _spark_sprite: AnimatedSprite2D
var _shadow_overlay: ColorRect
var _storm_overlay: ColorRect

var _lbl_time: Label
var _lbl_dist: Label
var _lbl_alert: Label

var _telemetry: FlightTelemetry
var _mission: MissionSpec
var _star_offset: float = 0.0
var _storm_timer: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_generate_stars()
	_build_layers()


func setup(mission: MissionSpec) -> void:
	_mission = mission
	var p_path := "res://assets/sprites/space/planet_%s.png" % mission.target_palette
	if ResourceLoader.exists(p_path):
		_planet_sprite.texture = load(p_path)
	_planet_sprite.scale = Vector2(0.45, 0.45)
	_planet_sprite.position = Vector2(490, 62)


func update_telemetry(telemetry: FlightTelemetry, dt: float) -> void:
	_telemetry = telemetry
	if telemetry == null:
		return

	var speed: float = 12.0 + (telemetry.throttle * 110.0 if telemetry.engine_firing else 0.0)
	_star_offset += speed * dt

	# Approach target planet smoothly
	var p: float = telemetry.progress_norm
	var s: float = lerpf(0.45, 1.55, p)
	_planet_sprite.scale = Vector2(s, s)
	_planet_sprite.position = Vector2(lerpf(505.0, 440.0, p), lerpf(58.0, 74.0, p))

	# Exhaust particles
	_exhaust_particles.emitting = telemetry.engine_firing and telemetry.throttle > 0.01
	_exhaust_particles.initial_velocity_min = lerpf(40.0, 95.0, telemetry.throttle)
	_exhaust_particles.initial_velocity_max = lerpf(70.0, 145.0, telemetry.throttle)

	# Shadow & solar storm overlays
	_shadow_overlay.visible = telemetry.in_shadow
	if telemetry.in_solar_storm:
		_storm_timer += dt * 14.0
		_storm_overlay.visible = true
		_storm_overlay.color = Color(0.95, 0.55, 0.12, 0.14 + 0.08 * sin(_storm_timer))
	else:
		_storm_overlay.visible = false

	# Spark alert sprite
	var has_hazard: bool = telemetry.in_solar_storm or (not telemetry.active_alerts.is_empty() and telemetry.battery_max_wh > 0.0 and (telemetry.battery_wh / telemetry.battery_max_wh) < 0.25)
	_spark_sprite.visible = has_hazard
	if has_hazard and not _spark_sprite.is_playing():
		_spark_sprite.play("default")
	elif not has_hazard and _spark_sprite.is_playing():
		_spark_sprite.stop()

	_lbl_time.text = "T+%02ds / %02ds" % [int(telemetry.elapsed_s), int(_mission.transit_duration_s) if _mission else 0]
	_lbl_dist.text = "OBJETIVO: %s (%.0f%%)" % [
		_mission.target_name if _mission else "",
		p * 100.0,
	]

	if telemetry.active_alerts.is_empty():
		_lbl_alert.text = "SISTEMAS NOMINALES"
		_lbl_alert.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	else:
		_lbl_alert.text = " | ".join(telemetry.active_alerts)
		_lbl_alert.add_theme_color_override("font_color", ThemeFactory.COL_AMBER if telemetry.in_flyby_window and telemetry.active_alerts.size() == 1 else ThemeFactory.COL_RED)

	queue_redraw()


func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for _i in range(85):
		var layer: int = rng.randi_range(1, 3)
		_stars.append({
			"x": rng.randf_range(4.0, 624.0),
			"y": rng.randf_range(6.0, 140.0),
			"layer": layer,
			"col": Color(0.6, 0.7, 0.9, 0.45) if layer == 1 else (Color(0.85, 0.9, 1.0, 0.75) if layer == 2 else Color(1.0, 0.96, 0.85, 0.95)),
		})


func _build_layers() -> void:
	var space_bg := ColorRect.new()
	space_bg.color = Color("060810")
	space_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	space_bg.z_index = -2
	add_child(space_bg)

	_planet_sprite = Sprite2D.new()
	_planet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_planet_sprite.position = Vector2(490, 62)
	add_child(_planet_sprite)

	_exhaust_particles = CPUParticles2D.new()
	_exhaust_particles.position = Vector2(180, 142)
	_exhaust_particles.direction = Vector2(-1, 0)
	_exhaust_particles.spread = 22.0
	_exhaust_particles.gravity = Vector2.ZERO
	_exhaust_particles.lifetime = 0.55
	_exhaust_particles.amount = 28
	_exhaust_particles.scale_amount_min = 2.0
	_exhaust_particles.scale_amount_max = 4.0
	_exhaust_particles.color = Color("f8b838")
	_exhaust_particles.emitting = false
	add_child(_exhaust_particles)

	_shadow_overlay = ColorRect.new()
	_shadow_overlay.color = Color(0.01, 0.02, 0.05, 0.58)
	_shadow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow_overlay.visible = false
	_shadow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow_overlay)

	_storm_overlay = ColorRect.new()
	_storm_overlay.color = Color(0.95, 0.55, 0.12, 0.16)
	_storm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_storm_overlay.visible = false
	_storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_storm_overlay)

	_spark_sprite = AnimatedSprite2D.new()
	_spark_sprite.sprite_frames = ThemeFactory.make_sprite_frames("res://assets/sprites/cockpit/spark_sheet.png", 16, 16, 10.0, true)
	_spark_sprite.position = Vector2(604, 24)
	_spark_sprite.visible = false
	add_child(_spark_sprite)

	_lbl_time = Label.new()
	_lbl_time.position = Vector2(10, 8)
	_lbl_time.add_theme_color_override("font_color", ThemeFactory.COL_GREEN)
	add_child(_lbl_time)

	_lbl_dist = Label.new()
	_lbl_dist.position = Vector2(130, 8)
	_lbl_dist.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	add_child(_lbl_dist)

	_lbl_alert = Label.new()
	_lbl_alert.position = Vector2(10, 128)
	_lbl_alert.size = Vector2(580, 14)
	add_child(_lbl_alert)


func _draw() -> void:
	# Parallax stars
	for star in _stars:
		var layer: int = int(star["layer"])
		var sx: float = fposmod(float(star["x"]) - _star_offset * (0.25 * layer), size.x)
		var sy: float = float(star["y"])
		var sz: float = 1.0 if layer < 3 else 2.0
		draw_rect(Rect2(floorf(sx), floorf(sy), sz, sz), star["col"])

	# Trajectory preview arc
	var start_pt := Vector2(36.0, 96.0)
	var end_pt := Vector2(360.0, 74.0)
	var steps: int = 24
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pt := start_pt.lerp(end_pt, t)
		pt.y -= sin(t * PI) * 26.0
		var col := Color(0.25, 0.85, 0.50, 0.35)
		if _mission != null and t >= _mission.flyby_window_start_norm and t <= _mission.flyby_window_end_norm:
			col = Color(0.25, 0.80, 0.96, 0.9)
		draw_rect(Rect2(floorf(pt.x), floorf(pt.y), 2.0, 2.0), col)

	if _telemetry != null:
		var p: float = _telemetry.progress_norm
		var probe_pt := start_pt.lerp(end_pt, p)
		probe_pt.y -= sin(p * PI) * 26.0
		draw_rect(Rect2(floorf(probe_pt.x) - 2, floorf(probe_pt.y) - 2, 5, 5), ThemeFactory.COL_AMBER)
		if _telemetry.engine_firing:
			draw_line(probe_pt, probe_pt - Vector2(10.0 * _telemetry.throttle + 3.0, 0), ThemeFactory.COL_RED, 2.0)

	# Cockpit window bezel frame
	draw_rect(Rect2(0, 0, size.x, size.y), Color("2e3848"), false, 2.0)
