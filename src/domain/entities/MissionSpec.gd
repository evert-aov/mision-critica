class_name MissionSpec
extends RefCounted
## Immutable specification for a spaceflight mission.

var id: String
var order_index: int
var title: String
var subtitle: String
var target_name: String
var difficulty: String
var budget: int
var required_delta_v: float
var delta_v_tolerance: float
var min_twr: float
var distance_au: float
var target_distance_km: float
var transit_duration_s: float
var flyby_window_start_norm: float
var flyby_window_end_norm: float
var shadow_windows: Array[Vector2]
var solar_storm_windows: Array[Vector2]
var target_palette: String
var brief: String


func _init(params: Dictionary = {}) -> void:
	id = str(params.get("id", ""))
	order_index = int(params.get("order_index", 1))
	title = str(params.get("title", ""))
	subtitle = str(params.get("subtitle", ""))
	target_name = str(params.get("target_name", ""))
	difficulty = str(params.get("difficulty", "NORMAL"))
	budget = int(params.get("budget", 100000))
	required_delta_v = float(params.get("required_delta_v", 1000.0))
	delta_v_tolerance = float(params.get("delta_v_tolerance", 120.0))
	min_twr = float(params.get("min_twr", 0.15))
	distance_au = float(params.get("distance_au", 1.0))
	target_distance_km = float(params.get("target_distance_km", 400.0))
	transit_duration_s = float(params.get("transit_duration_s", 60.0))
	flyby_window_start_norm = float(params.get("flyby_window_start_norm", 0.72))
	flyby_window_end_norm = float(params.get("flyby_window_end_norm", 0.96))
	shadow_windows = []
	for w in params.get("shadow_windows", []):
		shadow_windows.append(w)
	solar_storm_windows = []
	for s in params.get("solar_storm_windows", []):
		solar_storm_windows.append(s)
	target_palette = str(params.get("target_palette", "earth"))
	brief = str(params.get("brief", ""))
