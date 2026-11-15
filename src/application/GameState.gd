extends Node
## Autoload singleton: GameState
## Coordinates active phase, mission selection, launch vehicle & probe assembly, budget, and flight lifecycle.

enum Phase {
	MISSION_SELECT,
	ASSEMBLY,
	FLIGHT_COCKPIT,
	MISSION_RESULT,
}

signal phase_changed(new_phase: Phase)
signal mission_selected(mission: MissionSpec)
signal design_changed(evaluation: Dictionary)
signal flight_started(simulator: FlightSimulator)
signal flight_ended(telemetry: FlightTelemetry)
signal learning_requested()
signal language_changed(lang: String)

var language: String = "es"
var current_phase: Phase = Phase.MISSION_SELECT
var current_mission: MissionSpec
var current_design: ProbeDesign
var active_simulator: FlightSimulator
var last_evaluation: Dictionary = {}
var completed_missions: Dictionary = {} # mission_id -> { "best_science": int, "victories": int }


func _ready() -> void:
	Loc.set_lang(language)
	current_design = ProbeDesign.new(
		MissionData.get_all_parts(),
		MissionData.get_default_launch_vehicle()
	)
	var missions: Array[MissionSpec] = MissionData.get_all_missions()
	if not missions.is_empty():
		select_mission(missions[0].id)


func set_language(lang: String) -> void:
	var norm: String = "en" if lang.to_lower() == "en" else "es"
	if language == norm and Loc.lang == norm:
		return
	language = norm
	Loc.set_lang(norm)
	if current_design != null and current_mission != null:
		_recompute_evaluation()
	language_changed.emit(language)


func toggle_language() -> String:
	set_language("en" if language == "es" else "es")
	return language


func select_mission(mission_id: String) -> void:
	var mission: MissionSpec = MissionData.get_mission(mission_id)
	if mission == null:
		return
	current_mission = mission
	if current_design.get_launch_vehicle() == null:
		var rec_lv: LaunchVehicleSpec = MissionData.get_launch_vehicle(mission.recommended_lv_id)
		if rec_lv == null:
			rec_lv = MissionData.get_default_launch_vehicle()
		current_design.set_launch_vehicle(rec_lv)
	_recompute_evaluation()
	mission_selected.emit(current_mission)


func enter_assembly(mission_id: String = "") -> void:
	if not mission_id.is_empty():
		select_mission(mission_id)
	_set_phase(Phase.ASSEMBLY)
	_recompute_evaluation()


func enter_mission_select() -> void:
	active_simulator = null
	_set_phase(Phase.MISSION_SELECT)


func set_launch_vehicle(lv_id: String) -> bool:
	var lv: LaunchVehicleSpec = MissionData.get_launch_vehicle(lv_id)
	if lv == null:
		return false
	current_design.set_launch_vehicle(lv)
	_recompute_evaluation()
	return true


func add_part(part_id: String) -> bool:
	var added: bool = current_design.add_part(part_id)
	if added:
		_recompute_evaluation()
	return added


func remove_part(part_id: String) -> bool:
	var removed: bool = current_design.remove_part(part_id)
	if removed:
		_recompute_evaluation()
	return removed


func clear_design() -> void:
	current_design.clear()
	_recompute_evaluation()


func load_recommended_baseline() -> void:
	current_design.clear()
	if current_mission == null:
		return
	var rec_lv: LaunchVehicleSpec = MissionData.get_launch_vehicle(current_mission.recommended_lv_id)
	if rec_lv != null:
		current_design.set_launch_vehicle(rec_lv)
	match current_mission.id:
		"leo_tutorial":
			current_design.add_part("eng_hydrazine")
			current_design.add_part("tank_small")
			current_design.add_part("solar_compact")
			current_design.add_part("bat_liion")
			current_design.add_part("inst_cam")
		"lunar_flyby":
			current_design.add_part("eng_biprop")
			current_design.add_part("tank_medium")
			current_design.add_part("tank_small")
			current_design.add_part("solar_wing")
			current_design.add_part("bat_liion")
			current_design.add_part("comm_xband")
			current_design.add_part("inst_cam")
			current_design.add_part("inst_spec")
		"mars_orbit":
			current_design.add_part("eng_ion")
			current_design.add_part("tank_large")
			current_design.add_part("solar_wing")
			current_design.add_part("solar_wing")
			current_design.add_part("bat_liion")
			current_design.add_part("comm_xband")
			current_design.add_part("inst_spec")
			current_design.add_part("inst_radar")
	_recompute_evaluation()


func launch_mission(automatic: bool = false) -> bool:
	_recompute_evaluation()
	if not bool(last_evaluation.get("valid_for_launch", false)):
		return false
	active_simulator = FlightSimulator.new(current_mission, current_design)
	if automatic:
		active_simulator.set_automatic_enabled(true)
	_set_phase(Phase.FLIGHT_COCKPIT)
	flight_started.emit(active_simulator)
	return true


func notify_flight_finished(telemetry: FlightTelemetry) -> void:
	if current_phase != Phase.FLIGHT_COCKPIT:
		return
	if telemetry.status == FlightTelemetry.Status.VICTORY and current_mission != null:
		var record: Dictionary = completed_missions.get(current_mission.id, {"best_science": 0, "victories": 0})
		record["best_science"] = maxi(int(record["best_science"]), telemetry.science_score)
		record["victories"] = int(record["victories"]) + 1
		completed_missions[current_mission.id] = record
	_set_phase(Phase.MISSION_RESULT)
	flight_ended.emit(telemetry)


func get_budget_remaining() -> int:
	return int(last_evaluation.get("budget_remaining", 0))


func _recompute_evaluation() -> void:
	last_evaluation = PhysicsCalculator.evaluate_design(current_design, current_mission)
	design_changed.emit(last_evaluation)


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(current_phase)
