class_name MissionSpec
extends RefCounted
## Immutable specification for a spaceflight mission, modeling competing demands:
## mission objectives, budget, orbital constraints, distance (AU), TCM corridors,
## Gravity Assist keyholes, and 180° Retrograde Orbital Insertion requirements.

var id: String
var order_index: int
var _title_es: String = ""
var _title_en: String = ""
var title: String:
	get:
		return _title_en if (Loc.is_en() and not _title_en.is_empty()) else _title_es
var _subtitle_es: String = ""
var _subtitle_en: String = ""
var subtitle: String:
	get:
		return _subtitle_en if (Loc.is_en() and not _subtitle_en.is_empty()) else _subtitle_es
var _target_name_es: String = ""
var _target_name_en: String = ""
var target_name: String:
	get:
		return _target_name_en if (Loc.is_en() and not _target_name_en.is_empty()) else _target_name_es
var _difficulty_es: String = ""
var _difficulty_en: String = ""
var difficulty: String:
	get:
		return _difficulty_en if (Loc.is_en() and not _difficulty_en.is_empty()) else _difficulty_es
var budget: int
var required_delta_v: float
var delta_v_tolerance: float
var min_twr: float
var distance_au: float
var earth_distance_au: float
var target_distance_km: float
var transit_duration_s: float
var flyby_window_start_norm: float
var flyby_window_end_norm: float
var shadow_windows: Array[Vector2]
var solar_storm_windows: Array[Vector2]
var target_palette: String
var _brief_es: String = ""
var _brief_en: String = ""
var brief: String:
	get:
		return _brief_en if (Loc.is_en() and not _brief_en.is_empty()) else _brief_es

# Mission Objectives (Primary Scientific & Payload Mandates)
var _objective_summary_es: String = ""
var _objective_summary_en: String = ""
var objective_summary: String:
	get:
		return _objective_summary_en if (Loc.is_en() and not _objective_summary_en.is_empty()) else _objective_summary_es
var min_science_required: int
var required_instruments: Array[String]
var recommended_lv_id: String
var require_launch_vehicle: bool

# Trajectory Correction Maneuvers (TCM)
var initial_trajectory_error_km: float
var max_trajectory_error_km: float
var tcm_windows: Array[Vector2]
var drift_rate_km_s: float

# Gravity Assist (Slingshot)
var has_gravity_assist: bool
var _gravity_assist_body_es: String = ""
var _gravity_assist_body_en: String = ""
var gravity_assist_body: String:
	get:
		return _gravity_assist_body_en if (Loc.is_en() and not _gravity_assist_body_en.is_empty()) else _gravity_assist_body_es
var gravity_assist_palette: String
var gravity_assist_window: Vector2
var gravity_assist_dv_bonus: float

# 180° Retrograde Orbital Insertion
var requires_orbital_insertion: bool
var insertion_window_start_norm: float
var insertion_dv_required: float


func _init(params: Dictionary = {}) -> void:
	id = str(params.get("id", ""))
	order_index = int(params.get("order_index", 1))
	_title_es = str(params.get("title", ""))
	_title_en = str(params.get("title_en", _title_es))
	_subtitle_es = str(params.get("subtitle", ""))
	_subtitle_en = str(params.get("subtitle_en", _subtitle_es))
	_target_name_es = str(params.get("target_name", ""))
	_target_name_en = str(params.get("target_name_en", _target_name_es))
	_difficulty_es = str(params.get("difficulty", "NORMAL"))
	_difficulty_en = str(params.get("difficulty_en", _difficulty_es))
	budget = int(params.get("budget", 100000))
	required_delta_v = float(params.get("required_delta_v", 1000.0))
	delta_v_tolerance = float(params.get("delta_v_tolerance", 150.0))
	min_twr = float(params.get("min_twr", 0.15))
	distance_au = float(params.get("distance_au", 1.0))
	target_distance_km = float(params.get("target_distance_km", 400.0))
	# Solar distance and radio range are independent scenario approximations.
	earth_distance_au = maxf(0.000000001, float(params.get("earth_distance_au", target_distance_km / 149597870.7)))
	transit_duration_s = float(params.get("transit_duration_s", 60.0))
	flyby_window_start_norm = float(params.get("flyby_window_start_norm", 0.60))
	flyby_window_end_norm = float(params.get("flyby_window_end_norm", 0.94))

	shadow_windows = []
	for w in params.get("shadow_windows", []):
		shadow_windows.append(w)

	solar_storm_windows = []
	for s in params.get("solar_storm_windows", []):
		solar_storm_windows.append(s)

	target_palette = str(params.get("target_palette", "earth"))
	_brief_es = str(params.get("brief", ""))
	_brief_en = str(params.get("brief_en", _brief_es))

	_objective_summary_es = str(params.get("objective_summary", "Inserción orbital nominal."))
	_objective_summary_en = str(params.get("objective_summary_en", "Nominal orbital insertion."))
	min_science_required = int(params.get("min_science_required", 0))
	required_instruments = []
	for req_id in params.get("required_instruments", []):
		required_instruments.append(str(req_id))
	recommended_lv_id = str(params.get("recommended_lv_id", "lv_light"))
	require_launch_vehicle = bool(params.get("require_launch_vehicle", true))

	initial_trajectory_error_km = float(params.get("initial_trajectory_error_km", 16.0))
	max_trajectory_error_km = float(params.get("max_trajectory_error_km", 45.0))
	tcm_windows = []
	for tw in params.get("tcm_windows", [Vector2(0.20, 0.36)]):
		tcm_windows.append(tw)
	drift_rate_km_s = float(params.get("drift_rate_km_s", 0.55))

	has_gravity_assist = bool(params.get("has_gravity_assist", false))
	_gravity_assist_body_es = str(params.get("gravity_assist_body", ""))
	_gravity_assist_body_en = str(params.get("gravity_assist_body_en", _gravity_assist_body_es))
	gravity_assist_palette = str(params.get("gravity_assist_palette", "moon"))
	gravity_assist_window = params.get("gravity_assist_window", Vector2(0.40, 0.50))
	gravity_assist_dv_bonus = float(params.get("gravity_assist_dv_bonus", 0.0))

	requires_orbital_insertion = bool(params.get("requires_orbital_insertion", true))
	insertion_window_start_norm = float(params.get("insertion_window_start_norm", 0.72))
	insertion_dv_required = float(params.get("insertion_dv_required", required_delta_v * 0.68))
