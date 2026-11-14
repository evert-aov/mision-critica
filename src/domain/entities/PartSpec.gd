class_name PartSpec
extends RefCounted
## Immutable specification for a spacecraft component in the catalog.

enum Category {
	PROPULSION,
	TANK,
	ENERGY,
	INSTRUMENT,
}

var id: String
var display_name: String
var category: Category
var mass_dry_kg: float
var propellant_kg: float
var cost: int
var thrust_n: float
var isp_s: float
var power_gen_w: float
var power_draw_w: float
var battery_wh: float
var science_value: int
var texture_key: String
var description: String
var max_count: int


func _init(params: Dictionary = {}) -> void:
	id = str(params.get("id", ""))
	display_name = str(params.get("display_name", id))
	category = int(params.get("category", Category.PROPULSION)) as Category
	mass_dry_kg = float(params.get("mass_dry_kg", 0.0))
	propellant_kg = float(params.get("propellant_kg", 0.0))
	cost = int(params.get("cost", 0))
	thrust_n = float(params.get("thrust_n", 0.0))
	isp_s = float(params.get("isp_s", 0.0))
	power_gen_w = float(params.get("power_gen_w", 0.0))
	power_draw_w = float(params.get("power_draw_w", 0.0))
	battery_wh = float(params.get("battery_wh", 0.0))
	science_value = int(params.get("science_value", 0))
	texture_key = str(params.get("texture_key", id))
	description = str(params.get("description", ""))
	max_count = int(params.get("max_count", 4))


static func category_label(cat: Category) -> String:
	match cat:
		Category.PROPULSION:
			return "PROPULSIÓN"
		Category.TANK:
			return "TANQUES"
		Category.ENERGY:
			return "ENERGÍA"
		Category.INSTRUMENT:
			return "INSTRUMENTOS"
	return "OTRO"
