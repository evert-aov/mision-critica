extends Node
## Autoload singleton: MissionData
## Central read-only catalog for launch vehicles, spacecraft parts, and mission specifications.

var _launch_vehicles: Array[LaunchVehicleSpec] = []
var _launch_vehicles_by_id: Dictionary = {}
var _parts: Array[PartSpec] = []
var _parts_by_id: Dictionary = {}
var _missions: Array[MissionSpec] = []
var _missions_by_id: Dictionary = {}


func _ready() -> void:
	_launch_vehicles = LaunchVehicleCatalog.create_all()
	for lv in _launch_vehicles:
		_launch_vehicles_by_id[lv.id] = lv

	_parts = PartCatalog.create_all()
	for part in _parts:
		_parts_by_id[part.id] = part

	_missions = MissionCatalog.create_all()
	for mission in _missions:
		_missions_by_id[mission.id] = mission


func get_all_launch_vehicles() -> Array[LaunchVehicleSpec]:
	return _launch_vehicles.duplicate()


func get_launch_vehicle(lv_id: String) -> LaunchVehicleSpec:
	return _launch_vehicles_by_id.get(lv_id)


func get_default_launch_vehicle() -> LaunchVehicleSpec:
	if _launch_vehicles.is_empty():
		return null
	return _launch_vehicles[0]


func get_all_parts() -> Array[PartSpec]:
	return _parts.duplicate()


func get_parts_by_category(category: PartSpec.Category) -> Array[PartSpec]:
	var result: Array[PartSpec] = []
	for part in _parts:
		if part.category == category:
			result.append(part)
	return result


func get_part(part_id: String) -> PartSpec:
	return _parts_by_id.get(part_id)


func get_all_missions() -> Array[MissionSpec]:
	return _missions.duplicate()


func get_mission(mission_id: String) -> MissionSpec:
	return _missions_by_id.get(mission_id)
