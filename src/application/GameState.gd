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
signal profile_changed(profile: Dictionary)

var save_path: String = "user://profiles.json"
var language: String = "es"
var current_phase: Phase = Phase.MISSION_SELECT
var current_mission: MissionSpec
var current_design: ProbeDesign
var active_simulator: FlightSimulator
var last_evaluation: Dictionary = {}
var profiles: Dictionary = {}
var active_username: String = ""
var completed_missions: Dictionary = {} # mission_id -> { "best_science": int, "victories": int, "best_cml": int, "badges": Array }
var last_flight_badges: Array[String] = []
var last_flight_manual: bool = false


func _ready() -> void:
	Loc.set_lang(language)
	current_design = ProbeDesign.new(
		MissionData.get_all_parts(),
		MissionData.get_default_launch_vehicle()
	)
	load_profiles()
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
	var used_auto: bool = active_simulator != null and active_simulator.autopilot_used
	last_flight_manual = not used_auto
	last_flight_badges = []
	if telemetry.status == FlightTelemetry.Status.VICTORY and current_mission != null:
		var nasa: Dictionary = NasaMissionFramework.assess(current_design, current_mission, telemetry)
		var cml_num: int = int(nasa.get("cml_level", 1))
		last_flight_badges = NasaMissionFramework.evaluate_badges(current_design, current_mission, telemetry, last_flight_manual)
		var record: Dictionary = completed_missions.get(current_mission.id, {
			"best_science": 0,
			"victories": 0,
			"best_cml": 1,
			"badges": [],
		})
		record["best_science"] = maxi(int(record.get("best_science", 0)), telemetry.science_score)
		record["victories"] = int(record.get("victories", 0)) + 1
		record["best_cml"] = maxi(int(record.get("best_cml", 1)), cml_num)
		var merged_badges: Array = []
		for existing in record.get("badges", []):
			if not merged_badges.has(str(existing)):
				merged_badges.append(str(existing))
		for earned in last_flight_badges:
			if not merged_badges.has(earned):
				merged_badges.append(earned)
		record["badges"] = merged_badges
		completed_missions[current_mission.id] = record
		save_mission_design(current_mission.id)
		save_profiles()
	_set_phase(Phase.MISSION_RESULT)
	flight_ended.emit(telemetry)


func set_save_path(path: String) -> void:
	save_path = path


func has_active_profile() -> bool:
	return not active_username.is_empty() and profiles.has(active_username)


func get_active_profile() -> Dictionary:
	if not has_active_profile():
		return {}
	return profiles[active_username].duplicate(true)


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys: Array = profiles.keys()
	keys.sort()
	for uname in keys:
		result.append(profiles[uname].duplicate(true))
	return result


func register_profile(display_name: String, username: String) -> Dictionary:
	var check: Dictionary = NasaMissionFramework.validate_profile(display_name, username)
	if not bool(check.get("ok", false)):
		return check
	var uname: String = str(check.get("username", ""))
	var dname: String = str(check.get("name", ""))
	if profiles.has(uname):
		return {
			"ok": false,
			"username": uname,
			"name": dname,
			"error": Loc.pick("Ese usuario ya existe; selecciónalo en la lista.", "That username already exists; select it from the list."),
		}
	profiles[uname] = {
		"display_name": dname,
		"username": uname,
		"completed_missions": {},
		"saved_designs": {},
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	active_username = uname
	completed_missions.clear()
	save_profiles()
	profile_changed.emit(get_active_profile())
	return {"ok": true, "username": uname, "name": dname, "error": ""}


func switch_profile(username: String) -> bool:
	var uname: String = NasaMissionFramework.sanitize_username(username)
	if not profiles.has(uname):
		return false
	active_username = uname
	_sync_completed_from_profile()
	save_profiles()
	profile_changed.emit(get_active_profile())
	return true


func load_profiles() -> void:
	profiles.clear()
	active_username = ""
	completed_missions.clear()
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				var raw_profiles: Variant = parsed.get("profiles", {})
				if raw_profiles is Dictionary:
					for uname in raw_profiles.keys():
						if raw_profiles[uname] is Dictionary:
							profiles[str(uname)] = raw_profiles[uname]
				var candidate: String = str(parsed.get("active_username", ""))
				if profiles.has(candidate):
					active_username = candidate
				_sync_completed_from_profile()
	profile_changed.emit(get_active_profile())


func save_profiles() -> bool:
	if has_active_profile():
		profiles[active_username]["completed_missions"] = completed_missions.duplicate(true)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var payload := {
		"version": 1,
		"active_username": active_username,
		"profiles": profiles,
	}
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func _sync_completed_from_profile() -> void:
	completed_missions.clear()
	if not has_active_profile():
		return
	var comp: Variant = profiles[active_username].get("completed_missions", {})
	if comp is Dictionary:
		completed_missions = (comp as Dictionary).duplicate(true)


func save_mission_design(mission_id: String = "") -> bool:
	var mid: String = mission_id if not mission_id.is_empty() else (current_mission.id if current_mission != null else "")
	if mid.is_empty() or not has_active_profile() or current_design == null:
		return false
	var lv: LaunchVehicleSpec = current_design.get_launch_vehicle()
	var saved_raw: Variant = profiles[active_username].get("saved_designs", {})
	var saved: Dictionary = (saved_raw as Dictionary).duplicate(true) if saved_raw is Dictionary else {}
	saved[mid] = {
		"lv_id": lv.id if lv != null else "",
		"parts": current_design.get_counts_snapshot(),
	}
	profiles[active_username]["saved_designs"] = saved
	return save_profiles()


func has_saved_design(mission_id: String) -> bool:
	if not has_active_profile() or mission_id.is_empty():
		return false
	var saved_raw: Variant = profiles[active_username].get("saved_designs", {})
	return (saved_raw is Dictionary) and (saved_raw as Dictionary).has(mission_id)


func load_mission_design(mission_id: String = "") -> bool:
	var mid: String = mission_id if not mission_id.is_empty() else (current_mission.id if current_mission != null else "")
	if not has_saved_design(mid):
		return false
	var saved: Dictionary = profiles[active_username]["saved_designs"]
	var payload_raw: Variant = saved.get(mid, {})
	if not (payload_raw is Dictionary):
		return false
	var payload: Dictionary = payload_raw
	current_design.clear()
	var lv_id: String = str(payload.get("lv_id", ""))
	if not lv_id.is_empty():
		var lv: LaunchVehicleSpec = MissionData.get_launch_vehicle(lv_id)
		if lv != null:
			current_design.set_launch_vehicle(lv)
	var parts_raw: Variant = payload.get("parts", {})
	if parts_raw is Dictionary:
		for pid in (parts_raw as Dictionary).keys():
			current_design.set_part_count(str(pid), int(parts_raw[pid]))
	_recompute_evaluation()
	return true


func get_budget_remaining() -> int:
	return int(last_evaluation.get("budget_remaining", 0))


func _recompute_evaluation() -> void:
	last_evaluation = PhysicsCalculator.evaluate_design(current_design, current_mission)
	design_changed.emit(last_evaluation)


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(current_phase)
