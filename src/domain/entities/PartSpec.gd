class_name PartSpec
extends RefCounted
## Immutable specification for a spacecraft component in the catalog
## (Propulsion, Propellant Tanks, Energy, Communications, and Scientific Instruments).

enum Category {
	PROPULSION,
	TANK,
	ENERGY,
	COMMS,
	INSTRUMENT,
}

var id: String
var _display_name_es: String = ""
var _display_name_en: String = ""
var display_name: String:
	get:
		return _display_name_en if (Loc.is_en() and not _display_name_en.is_empty()) else _display_name_es
var category: Category
var mass_dry_kg: float
var propellant_kg: float
var cost: int
var thrust_n: float
var isp_s: float
var power_gen_w: float
var power_draw_w: float
var battery_wh: float
var comms_kbps: float
var data_volume_mb: float
var science_value: int
var texture_key: String
var _description_es: String = ""
var _description_en: String = ""
var description: String:
	get:
		return _description_en if (Loc.is_en() and not _description_en.is_empty()) else _description_es
var max_count: int


func _init(params: Dictionary = {}) -> void:
	id = str(params.get("id", ""))
	_display_name_es = str(params.get("display_name", id))
	_display_name_en = str(params.get("display_name_en", ""))
	category = int(params.get("category", Category.PROPULSION)) as Category
	mass_dry_kg = float(params.get("mass_dry_kg", 0.0))
	propellant_kg = float(params.get("propellant_kg", 0.0))
	cost = int(params.get("cost", 0))
	thrust_n = float(params.get("thrust_n", 0.0))
	isp_s = float(params.get("isp_s", 0.0))
	power_gen_w = float(params.get("power_gen_w", 0.0))
	power_draw_w = float(params.get("power_draw_w", 0.0))
	battery_wh = float(params.get("battery_wh", 0.0))
	comms_kbps = float(params.get("comms_kbps", 0.0))
	data_volume_mb = float(params.get("data_volume_mb", 30.0))
	science_value = int(params.get("science_value", 0))
	texture_key = str(params.get("texture_key", id))
	_description_es = str(params.get("description", ""))
	_description_en = str(params.get("description_en", ""))
	max_count = int(params.get("max_count", 4))


static func category_label(cat: Category) -> String:
	match cat:
		Category.PROPULSION:
			return Loc.pick("PROPULSIÓN", "PROPULSION")
		Category.TANK:
			return Loc.pick("TANQUES", "TANKS")
		Category.ENERGY:
			return Loc.pick("ENERGÍA", "POWER")
		Category.COMMS:
			return Loc.pick("COMUNICACIONES", "COMMS")
		Category.INSTRUMENT:
			return Loc.pick("INSTRUMENTOS", "INSTRUMENTS")
	return Loc.pick("OTRO", "OTHER")
