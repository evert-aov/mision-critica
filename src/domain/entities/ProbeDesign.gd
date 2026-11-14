class_name ProbeDesign
extends RefCounted
## Holds the player's current probe configuration in a UI-independent domain model.

const BASE_CHASSIS_MASS_KG: float = 120.0
const BASE_CHASSIS_COST: int = 15000
const BASE_AVIONICS_DRAW_W: float = 12.0
const COMMS_DRAW_W: float = 10.0
const BASE_BATTERY_WH: float = 40.0

var _catalog_by_id: Dictionary = {}
var _counts: Dictionary = {}


func _init(parts_catalog: Array[PartSpec] = []) -> void:
	set_catalog(parts_catalog)


func set_catalog(parts_catalog: Array[PartSpec]) -> void:
	_catalog_by_id.clear()
	for part in parts_catalog:
		_catalog_by_id[part.id] = part


func add_part(part_id: String) -> bool:
	if not _catalog_by_id.has(part_id):
		return false
	var part: PartSpec = _catalog_by_id[part_id]
	var current: int = int(_counts.get(part_id, 0))
	if current >= part.max_count:
		return false
	_counts[part_id] = current + 1
	return true


func remove_part(part_id: String) -> bool:
	var current: int = int(_counts.get(part_id, 0))
	if current <= 0:
		return false
	if current == 1:
		_counts.erase(part_id)
	else:
		_counts[part_id] = current - 1
	return true


func set_part_count(part_id: String, count: int) -> void:
	if not _catalog_by_id.has(part_id):
		return
	var part: PartSpec = _catalog_by_id[part_id]
	var clamped: int = clampi(count, 0, part.max_count)
	if clamped == 0:
		_counts.erase(part_id)
	else:
		_counts[part_id] = clamped


func get_part_count(part_id: String) -> int:
	return int(_counts.get(part_id, 0))


func clear() -> void:
	_counts.clear()


func get_all_parts() -> Array[PartSpec]:
	var result: Array[PartSpec] = []
	for part_id in _counts.keys():
		var part: PartSpec = _catalog_by_id.get(part_id)
		if part == null:
			continue
		var count: int = int(_counts[part_id])
		for _i in range(count):
			result.append(part)
	return result


func get_unique_parts() -> Array[PartSpec]:
	var result: Array[PartSpec] = []
	for part_id in _counts.keys():
		var part: PartSpec = _catalog_by_id.get(part_id)
		if part != null and int(_counts[part_id]) > 0:
			result.append(part)
	return result


func get_parts_by_category(cat: PartSpec.Category) -> Array[PartSpec]:
	var result: Array[PartSpec] = []
	for part in get_all_parts():
		if part.category == cat:
			result.append(part)
	return result


func get_counts_snapshot() -> Dictionary:
	return _counts.duplicate(true)


func clone() -> ProbeDesign:
	var copy := ProbeDesign.new()
	copy._catalog_by_id = _catalog_by_id.duplicate()
	copy._counts = _counts.duplicate(true)
	return copy
