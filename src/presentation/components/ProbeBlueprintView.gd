@tool
class_name ProbeBlueprintView
extends Control
## Schematic pixel-art preview of the probe that updates live as parts are added/removed.

var _design: ProbeDesign
var _textures: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preload_textures()


func set_design(design: ProbeDesign) -> void:
	_design = design
	queue_redraw()


func _preload_textures() -> void:
	var bus_path := "res://assets/sprites/parts/probe_bus.png"
	if ResourceLoader.exists(bus_path):
		_textures["bus"] = load(bus_path)
	for part in PartCatalog.create_all():
		var path := "res://assets/sprites/parts/%s.png" % part.texture_key
		if ResourceLoader.exists(path):
			_textures[part.id] = load(path)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# Blueprint CRT grid (integer pixel alignment)
	var step: int = 16
	for gx in range(0, int(w), step):
		draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.10, 0.30, 0.22, 0.45), 1.0)
	for gy in range(0, int(h), step):
		draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.10, 0.30, 0.22, 0.45), 1.0)

	# Centerline axis
	var cx: float = floorf(w * 0.5)
	var cy: float = floorf(h * 0.44)
	draw_line(Vector2(cx, 8), Vector2(cx, h - 8), Color(0.25, 0.90, 0.50, 0.22), 1.0)

	if _design == null:
		return

	var tanks: Array[PartSpec] = _design.get_parts_by_category(PartSpec.Category.TANK)
	var engines: Array[PartSpec] = _design.get_parts_by_category(PartSpec.Category.PROPULSION)
	var energy: Array[PartSpec] = _design.get_parts_by_category(PartSpec.Category.ENERGY)
	var instruments: Array[PartSpec] = _design.get_parts_by_category(PartSpec.Category.INSTRUMENT)

	var solar_parts: Array[PartSpec] = []
	var battery_parts: Array[PartSpec] = []
	for e in energy:
		if e.power_gen_w > 0.0:
			solar_parts.append(e)
		else:
			battery_parts.append(e)

	# 1. Draw Solar Panels extending left/right from bus
	for i in range(solar_parts.size()):
		var p: PartSpec = solar_parts[i]
		var tex: Texture2D = _textures.get(p.id)
		if tex == null:
			continue
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var tier: int = i / 2
		var px: float = cx + side * (28.0 + tier * 24.0) - 12.0
		var py: float = cy - 12.0
		draw_line(Vector2(cx, cy), Vector2(px + 12.0, py + 12.0), Color("a8b4c6"), 2.0)
		draw_texture_rect(tex, Rect2(Vector2(px, py), Vector2(24, 24)), false)

	# 2. Draw Tanks stacked below bus
	var stack_y: float = cy + 20.0
	for i in range(tanks.size()):
		var t: PartSpec = tanks[i]
		var tex: Texture2D = _textures.get(t.id)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(cx - 12.0, stack_y), Vector2(24, 24)), false)
		stack_y += 22.0

	# 3. Draw Engines below tanks (side-by-side if 2)
	if not engines.is_empty():
		var eng_count: int = engines.size()
		var spacing: float = 26.0
		var start_x: float = cx - ((eng_count - 1) * spacing * 0.5) - 12.0
		for i in range(eng_count):
			var eng: PartSpec = engines[i]
			var tex: Texture2D = _textures.get(eng.id)
			if tex != null:
				draw_texture_rect(tex, Rect2(Vector2(start_x + i * spacing, stack_y), Vector2(24, 24)), false)

	# 4. Draw Core Probe Bus (central)
	var bus_tex: Texture2D = _textures.get("bus")
	if bus_tex != null:
		draw_texture_rect(bus_tex, Rect2(Vector2(cx - 24.0, cy - 24.0), Vector2(48, 48)), false)

	# 5. Draw Batteries on lower-side structural bays
	for i in range(battery_parts.size()):
		var b: PartSpec = battery_parts[i]
		var tex: Texture2D = _textures.get(b.id)
		if tex == null:
			continue
		var side: float = -1.0 if (i % 2 == 0) else 1.0
		var row: int = i / 2
		var bx: float = cx + side * 28.0 - 8.0
		var by: float = cy + 16.0 + row * 18.0
		draw_texture_rect(tex, Rect2(Vector2(bx, by), Vector2(16, 16)), false)

	# 6. Draw Scientific Instruments on top payload deck
	if not instruments.is_empty():
		var inst_count: int = instruments.size()
		var spacing: float = 26.0
		var start_x: float = cx - ((inst_count - 1) * spacing * 0.5) - 10.0
		for i in range(inst_count):
			var inst: PartSpec = instruments[i]
			var tex: Texture2D = _textures.get(inst.id)
			if tex != null:
				draw_line(Vector2(cx, cy - 18.0), Vector2(start_x + i * spacing + 10.0, cy - 38.0), Color("40e880"), 1.0)
				draw_texture_rect(tex, Rect2(Vector2(start_x + i * spacing, cy - 52.0), Vector2(20, 20)), false)
