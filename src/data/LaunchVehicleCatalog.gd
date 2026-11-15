class_name LaunchVehicleCatalog
extends RefCounted
## Static repository of selectable Launch Vehicles (cohetes portadores).
## Models the competing trade-offs between launch cost, max wet payload mass,
## fairing module capacity, upper-stage injection Δv, and initial orbital dispersion.


static func create_all() -> Array[LaunchVehicleSpec]:
	return [
		LaunchVehicleSpec.new({
			"id": "lv_light",
			"display_name": "Vega-C Ligero",
			"display_name_en": "Vega-C Light",
			"short_name": "Vega-C",
			"cost": 18000,
			"max_payload_kg": 420.0,
			"max_fairing_modules": 6,
			"injection_dv_ms": 0.0,
			"injection_dispersion_km": 22.0,
			"description": "Lanzador ligero económico para LEO (carga máx. 420 kg, cofia 6 mód., disp. 22 km).",
			"description_en": "Budget light launcher for LEO (max payload 420 kg, 6-mod fairing, 22 km disp.).",
		}),
		LaunchVehicleSpec.new({
			"id": "lv_medium",
			"display_name": "Ariane-62 Medio",
			"display_name_en": "Ariane-62 Medium",
			"short_name": "Ariane-62",
			"cost": 36000,
			"max_payload_kg": 820.0,
			"max_fairing_modules": 9,
			"injection_dv_ms": 300.0,
			"injection_dispersion_km": 14.0,
			"description": "Lanzador cislunar medio (+300 m/s inyección, carga 820 kg, cofia 9 mód., disp. 14 km).",
			"description_en": "Medium cislunar launcher (+300 m/s injection, 820 kg max, 9-mod fairing, 14 km disp.).",
		}),
		LaunchVehicleSpec.new({
			"id": "lv_heavy",
			"display_name": "Vulcan-Centaur Pesado",
			"display_name_en": "Vulcan-Centaur Heavy",
			"short_name": "Vulcan-H",
			"cost": 58000,
			"max_payload_kg": 1500.0,
			"max_fairing_modules": 13,
			"injection_dv_ms": 650.0,
			"injection_dispersion_km": 8.0,
			"description": "Cohete interplanetario pesado (+650 m/s etapa Centaur, 1500 kg, cofia 13 mód., disp. 8 km).",
			"description_en": "Heavy interplanetary rocket (+650 m/s Centaur stage, 1500 kg max, 13-mod fairing, 8 km disp.).",
		}),
	]
