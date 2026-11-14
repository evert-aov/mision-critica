class_name RocketMath
extends RefCounted
## Pure mathematical engine for spacecraft mass, propulsion, power, and science.
## Contains no SceneTree or UI dependencies so it can be unit-tested deterministically.

const G0: float = 9.80665
const SOLAR_CONSTANT_EARTH_FACTOR: float = 1.0


static func calculate_dry_mass_kg(design: ProbeDesign) -> float:
	var total: float = ProbeDesign.BASE_CHASSIS_MASS_KG
	for part in design.get_all_parts():
		total += part.mass_dry_kg
	return total


static func calculate_propellant_mass_kg(design: ProbeDesign) -> float:
	var total: float = 0.0
	for part in design.get_all_parts():
		total += part.propellant_kg
	return total


static func calculate_wet_mass_kg(design: ProbeDesign) -> float:
	return calculate_dry_mass_kg(design) + calculate_propellant_mass_kg(design)


static func calculate_total_cost(design: ProbeDesign) -> int:
	var total: int = ProbeDesign.BASE_CHASSIS_COST
	for part in design.get_all_parts():
		total += part.cost
	return total


static func calculate_total_thrust_n(design: ProbeDesign) -> float:
	var total: float = 0.0
	for part in design.get_all_parts():
		total += part.thrust_n
	return total


static func calculate_effective_isp_s(design: ProbeDesign) -> float:
	var total_thrust: float = 0.0
	var weighted_inv_isp: float = 0.0
	for part in design.get_all_parts():
		if part.thrust_n > 0.0 and part.isp_s > 0.0:
			total_thrust += part.thrust_n
			weighted_inv_isp += part.thrust_n / part.isp_s
	if total_thrust <= 0.0 or weighted_inv_isp <= 0.0:
		return 0.0
	return total_thrust / weighted_inv_isp


static func calculate_delta_v_from_masses(isp_s: float, wet_mass_kg: float, dry_mass_kg: float) -> float:
	if isp_s <= 0.0 or dry_mass_kg <= 0.0 or wet_mass_kg <= dry_mass_kg:
		return 0.0
	return isp_s * G0 * log(wet_mass_kg / dry_mass_kg)


static func calculate_delta_v(design: ProbeDesign) -> float:
	var isp_s: float = calculate_effective_isp_s(design)
	var dry_mass: float = calculate_dry_mass_kg(design)
	var wet_mass: float = dry_mass + calculate_propellant_mass_kg(design)
	return calculate_delta_v_from_masses(isp_s, wet_mass, dry_mass)


static func calculate_twr(design: ProbeDesign, gravity_ms2: float = G0) -> float:
	var wet_mass: float = calculate_wet_mass_kg(design)
	if wet_mass <= 0.0 or gravity_ms2 <= 0.0:
		return 0.0
	return calculate_total_thrust_n(design) / (wet_mass * gravity_ms2)


static func calculate_solar_irradiance_factor(distance_au: float) -> float:
	var d: float = maxf(distance_au, 0.2)
	return SOLAR_CONSTANT_EARTH_FACTOR / (d * d)


static func calculate_solar_generation_w(
	design: ProbeDesign,
	distance_au: float,
	panels_deployed: bool = true,
	in_shadow: bool = false
) -> float:
	if not panels_deployed or in_shadow:
		return 0.0
	var raw_w: float = 0.0
	for part in design.get_all_parts():
		raw_w += part.power_gen_w
	return raw_w * calculate_solar_irradiance_factor(distance_au)


static func calculate_power_draw_w(
	design: ProbeDesign,
	master_on: bool = true,
	comms_on: bool = true,
	science_bus_on: bool = true,
	in_solar_storm: bool = false
) -> float:
	if not master_on:
		return 2.0 # Standby keep-alive draw
	var draw: float = ProbeDesign.BASE_AVIONICS_DRAW_W
	if comms_on:
		draw += ProbeDesign.COMMS_DRAW_W
	if science_bus_on:
		for part in design.get_all_parts():
			if part.category == PartSpec.Category.INSTRUMENT:
				draw += part.power_draw_w
		if in_solar_storm:
			draw += 15.0
	return draw


static func calculate_battery_capacity_wh(design: ProbeDesign) -> float:
	var total: float = ProbeDesign.BASE_BATTERY_WH
	for part in design.get_all_parts():
		total += part.battery_wh
	return total


static func calculate_max_science(design: ProbeDesign) -> int:
	var total: int = 0
	for part in design.get_all_parts():
		if part.category == PartSpec.Category.INSTRUMENT:
			total += part.science_value
	return total


static func evaluate_design(design: ProbeDesign, mission: MissionSpec) -> Dictionary:
	var dry_mass: float = calculate_dry_mass_kg(design)
	var prop_mass: float = calculate_propellant_mass_kg(design)
	var wet_mass: float = dry_mass + prop_mass
	var cost: int = calculate_total_cost(design)
	var thrust_n: float = calculate_total_thrust_n(design)
	var isp_s: float = calculate_effective_isp_s(design)
	var delta_v: float = calculate_delta_v_from_masses(isp_s, wet_mass, dry_mass)
	var twr: float = calculate_twr(design)
	var solar_w: float = calculate_solar_generation_w(design, mission.distance_au, true, false)
	var draw_w: float = calculate_power_draw_w(design, true, true, true, false)
	var net_power_w: float = solar_w - draw_w
	var battery_wh: float = calculate_battery_capacity_wh(design)
	var max_science: int = calculate_max_science(design)

	var errors: Array[String] = []
	var warnings: Array[String] = []

	if cost > mission.budget:
		errors.append("Presupuesto excedido ($%d / $%d)." % [cost, mission.budget])
	if thrust_n <= 0.0:
		errors.append("Falta motor de propulsión.")
	if prop_mass <= 0.0:
		errors.append("Falta tanque de propelente.")

	var min_dv_launch: float = mission.required_delta_v - mission.delta_v_tolerance
	if delta_v > 0.0 and delta_v < min_dv_launch:
		warnings.append("Δv bajo (%.0f / %.0f m/s req.)." % [delta_v, mission.required_delta_v])
	if twr > 0.0 and twr < mission.min_twr:
		warnings.append("TWR bajo (%.2f < %.2f)." % [twr, mission.min_twr])
	if net_power_w < 0.0:
		warnings.append("Balance eléctrico negativo (%.0f W). Añade paneles o alterna buses." % net_power_w)
	if max_science <= 0:
		warnings.append("Sin instrumentos científicos: retorno científico será 0.")

	return {
		"valid_for_launch": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"dry_mass_kg": dry_mass,
		"propellant_kg": prop_mass,
		"wet_mass_kg": wet_mass,
		"cost": cost,
		"budget_remaining": mission.budget - cost,
		"thrust_n": thrust_n,
		"isp_s": isp_s,
		"delta_v": delta_v,
		"twr": twr,
		"solar_gen_w": solar_w,
		"power_draw_w": draw_w,
		"net_power_w": net_power_w,
		"battery_wh": battery_wh,
		"max_science": max_science,
	}
