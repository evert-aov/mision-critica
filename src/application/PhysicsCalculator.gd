extends Node
## Autoload singleton: PhysicsCalculator
## Application-level facade over pure RocketMath domain calculations.


func evaluate_design(design: ProbeDesign, mission: MissionSpec) -> Dictionary:
	if design == null or mission == null:
		return {"valid_for_launch": false, "errors": ["Diseño o misión no inicializados."], "warnings": []}
	return RocketMath.evaluate_design(design, mission)


func calculate_delta_v(design: ProbeDesign) -> float:
	return RocketMath.calculate_delta_v(design)


func calculate_total_mission_delta_v(design: ProbeDesign) -> float:
	return RocketMath.calculate_total_mission_delta_v(design)


func calculate_twr(design: ProbeDesign) -> float:
	return RocketMath.calculate_twr(design)


func calculate_dry_mass_kg(design: ProbeDesign) -> float:
	return RocketMath.calculate_dry_mass_kg(design)


func calculate_wet_mass_kg(design: ProbeDesign) -> float:
	return RocketMath.calculate_wet_mass_kg(design)


func calculate_total_cost(design: ProbeDesign) -> int:
	return RocketMath.calculate_total_cost(design)


func calculate_effective_comms_kbps(design: ProbeDesign, earth_distance_au: float) -> float:
	return RocketMath.calculate_effective_comms_kbps(design, earth_distance_au)


func calculate_solar_generation_w(design: ProbeDesign, distance_au: float, deployed: bool = true, in_shadow: bool = false) -> float:
	return RocketMath.calculate_solar_generation_w(design, distance_au, deployed, in_shadow)
