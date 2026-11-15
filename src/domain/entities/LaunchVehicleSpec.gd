class_name LaunchVehicleSpec
extends RefCounted
## Immutable specification for a carrier Launch Vehicle (cohete lanzador).
## Models the competing trade-offs between launch cost, payload lift mass capacity,
## fairing volume (max modules), upper-stage injection Δv, and orbital insertion dispersion.

var id: String
var _display_name_es: String = ""
var _display_name_en: String = ""
var display_name: String:
	get:
		return _display_name_en if (Loc.is_en() and not _display_name_en.is_empty()) else _display_name_es
var short_name: String
var cost: int
var max_payload_kg: float
var max_fairing_modules: int
var injection_dv_ms: float
var injection_dispersion_km: float
var _description_es: String = ""
var _description_en: String = ""
var description: String:
	get:
		return _description_en if (Loc.is_en() and not _description_en.is_empty()) else _description_es


func _init(params: Dictionary = {}) -> void:
	id = str(params.get("id", ""))
	_display_name_es = str(params.get("display_name", id))
	_display_name_en = str(params.get("display_name_en", ""))
	short_name = str(params.get("short_name", _display_name_es))
	cost = int(params.get("cost", 0))
	max_payload_kg = float(params.get("max_payload_kg", 500.0))
	max_fairing_modules = int(params.get("max_fairing_modules", 8))
	injection_dv_ms = float(params.get("injection_dv_ms", 0.0))
	injection_dispersion_km = float(params.get("injection_dispersion_km", 18.0))
	_description_es = str(params.get("description", ""))
	_description_en = str(params.get("description_en", ""))
