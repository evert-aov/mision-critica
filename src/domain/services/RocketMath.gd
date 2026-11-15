class_name RocketMath
extends RefCounted
## Pure mathematical engine for the 9 competing space mission engineering demands:
## Mission Objectives, Spacecraft Design (fairing modules), Scientific Instruments (pts/W/MB),
## Launch Vehicles (cost/payload cap/fairing/injection Δv), Unified Budget, Solar/Bus Power,
## Dry/Wet Mass, Deep-Space Communications (kbps & 1/d² path loss), and Orbital Constraints.
## Contains no SceneTree or UI dependencies so it can be unit-tested deterministically.

const G0: float = 9.80665
const SOLAR_CONSTANT_EARTH_FACTOR: float = 1.0
# Decimal units: 1 MB = 8000 kilobits. Data transfer is accelerated for short rounds.
const KILOBITS_PER_MEGABYTE: float = 8000.0
const DATA_SECONDS_PER_GAME_SECOND: float = 9200.0


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


static func calculate_spacecraft_cost(design: ProbeDesign) -> int:
	var total: int = ProbeDesign.BASE_CHASSIS_COST
	for part in design.get_all_parts():
		total += part.cost
	return total


static func calculate_launch_vehicle_cost(design: ProbeDesign) -> int:
	if design.launch_vehicle == null:
		return 0
	return design.launch_vehicle.cost


static func calculate_total_cost(design: ProbeDesign) -> int:
	return calculate_spacecraft_cost(design) + calculate_launch_vehicle_cost(design)


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


static func calculate_injection_delta_v(design: ProbeDesign) -> float:
	if design.launch_vehicle == null:
		return 0.0
	return design.launch_vehicle.injection_dv_ms


static func calculate_total_mission_delta_v(design: ProbeDesign) -> float:
	return calculate_delta_v(design) + calculate_injection_delta_v(design)


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
	in_shadow: bool = false,
	pointing_factor: float = 1.0
) -> float:
	if not panels_deployed or in_shadow:
		return 0.0
	var raw_w: float = 0.0
	for part in design.get_all_parts():
		raw_w += part.power_gen_w
	return raw_w * calculate_solar_irradiance_factor(distance_au) * clampf(pointing_factor, 0.0, 1.2)


static func calculate_power_draw_w(
	design: ProbeDesign,
	master_on: bool = true,
	comms_on: bool = true,
	science_bus_on: bool = true,
	in_solar_storm: bool = false,
	acs_extra_draw_w: float = 0.0,
	engine_throttle: float = 0.0
) -> float:
	if not master_on:
		return 2.0 # Standby keep-alive draw
	var draw: float = ProbeDesign.BASE_AVIONICS_DRAW_W + maxf(acs_extra_draw_w, 0.0)
	for part in design.get_all_parts():
		if part.category == PartSpec.Category.PROPULSION:
			draw += part.power_draw_w * clampf(engine_throttle, 0.0, 1.0)
	if comms_on:
		draw += ProbeDesign.COMMS_DRAW_W
		for part in design.get_all_parts():
			if part.category == PartSpec.Category.COMMS:
				draw += part.power_draw_w
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


static func calculate_raw_comms_kbps(design: ProbeDesign) -> float:
	var kbps: float = ProbeDesign.BASE_COMMS_KBPS
	for part in design.get_all_parts():
		if part.category == PartSpec.Category.COMMS:
			kbps += part.comms_kbps
	return kbps


static func calculate_effective_comms_kbps(design: ProbeDesign, earth_distance_au: float) -> float:
	# Link normalized at 1 AU, limited by transmitter capacity at shorter ranges.
	var range_au: float = maxf(earth_distance_au, 0.000000001)
	return calculate_raw_comms_kbps(design) * minf(1.0, 1.0 / (range_au * range_au))


static func kbps_to_mb_per_second(kbps: float) -> float:
	return maxf(kbps, 0.0) / KILOBITS_PER_MEGABYTE


static func calculate_game_downlink_mb_s(kbps: float) -> float:
	return kbps_to_mb_per_second(kbps) * DATA_SECONDS_PER_GAME_SECOND


static func calculate_total_science_data_mb(design: ProbeDesign) -> float:
	var total_mb: float = 0.0
	for part in design.get_all_parts():
		if part.category == PartSpec.Category.INSTRUMENT:
			total_mb += part.data_volume_mb
	return total_mb


static func calculate_max_science(design: ProbeDesign) -> int:
	var total: int = 0
	for part in design.get_all_parts():
		if part.category == PartSpec.Category.INSTRUMENT:
			total += part.science_value
	return total


static func normalize_angle_deg(angle_deg: float) -> float:
	var a: float = fposmod(angle_deg + 180.0, 360.0) - 180.0
	return a


static func shortest_angle_diff_deg(from_deg: float, to_deg: float) -> float:
	return normalize_angle_deg(to_deg - from_deg)


static func evaluate_design(design: ProbeDesign, mission: MissionSpec) -> Dictionary:
	var lv: LaunchVehicleSpec = design.get_launch_vehicle()
	var dry_mass: float = calculate_dry_mass_kg(design)
	var prop_mass: float = calculate_propellant_mass_kg(design)
	var wet_mass: float = dry_mass + prop_mass
	var spacecraft_cost: int = calculate_spacecraft_cost(design)
	var lv_cost: int = calculate_launch_vehicle_cost(design)
	var cost: int = spacecraft_cost + lv_cost
	var module_count: int = design.get_total_module_count()
	var max_payload_kg: float = lv.max_payload_kg if lv != null else 99999.0
	var max_fairing_modules: int = lv.max_fairing_modules if lv != null else 99

	var thrust_n: float = calculate_total_thrust_n(design)
	var isp_s: float = calculate_effective_isp_s(design)
	var delta_v: float = calculate_delta_v_from_masses(isp_s, wet_mass, dry_mass)
	var injection_dv: float = calculate_injection_delta_v(design)
	var total_delta_v: float = delta_v + injection_dv
	var twr: float = calculate_twr(design)

	var solar_w: float = calculate_solar_generation_w(design, mission.distance_au, true, false, 1.0)
	var draw_w: float = calculate_power_draw_w(design, true, true, true, false, 0.0)
	var net_power_w: float = solar_w - draw_w
	var battery_wh: float = calculate_battery_capacity_wh(design)

	var raw_kbps: float = calculate_raw_comms_kbps(design)
	var eff_kbps: float = calculate_effective_comms_kbps(design, mission.earth_distance_au)
	var total_data_mb: float = calculate_total_science_data_mb(design)
	var est_tx_physical_s: float = total_data_mb / maxf(kbps_to_mb_per_second(eff_kbps), 0.000000001)
	var est_tx_time_s: float = est_tx_physical_s / DATA_SECONDS_PER_GAME_SECOND
	var max_science: int = calculate_max_science(design)

	var errors: Array[String] = []
	var warnings: Array[String] = []

	# 1. Launch Vehicle & Payload/Fairing Structural Limits
	if mission.require_launch_vehicle and lv == null:
		errors.append(Loc.pick(
			"Falta seleccionar vehículo de lanzamiento (pestaña COH).",
			"Missing launch vehicle selection (L/V tab)."
		))
	elif lv != null:
		if wet_mass > lv.max_payload_kg:
			errors.append(Loc.pick(
				"Masa total (%.0f kg) supera capacidad de %s (%.0f kg).",
				"Total mass (%.0f kg) exceeds %s capacity (%.0f kg)."
			) % [
				wet_mass,
				lv.short_name,
				lv.max_payload_kg,
			])
		if module_count > lv.max_fairing_modules:
			errors.append(Loc.pick(
				"Cofia saturada (%d / %d módulos máx. en %s).",
				"Fairing full (%d / %d max modules in %s)."
			) % [
				module_count,
				lv.max_fairing_modules,
				lv.short_name,
			])

	# 2. Unified Mission Budget (Launch Vehicle + Bus + Subsystems + Payload)
	if cost > mission.budget:
		errors.append(Loc.pick(
			"Presupuesto excedido ($%d / $%d).",
			"Budget exceeded ($%d / $%d)."
		) % [cost, mission.budget])

	# 3. Spacecraft Propulsion Readiness
	if thrust_n <= 0.0:
		errors.append(Loc.pick("Falta motor de propulsión.", "Missing propulsion engine."))
	if prop_mass <= 0.0:
		errors.append(Loc.pick("Falta tanque de propelente.", "Missing propellant tank."))

	# 4. Mission Objectives & Mandatory Scientific Instruments
	for req_id in mission.required_instruments:
		if design.get_part_count(req_id) <= 0:
			var req_spec: PartSpec = design.get_part_spec(req_id)
			var req_name: String = req_spec.display_name if req_spec != null else req_id
			errors.append(Loc.pick("Objetivo exige instalar: %s.", "Objective requires: %s.") % req_name)
	if mission.min_science_required > 0 and max_science < mission.min_science_required:
		errors.append(Loc.pick(
			"Ciencia potencial insuficiente (%d / %d pts mín.).",
			"Insufficient potential science (%d / %d min pts)."
		) % [
			max_science,
			mission.min_science_required,
		])

	# 5. Orbital Constraints, Energy Balance & Deep-Space Comms Warnings
	var ga_credit: float = mission.gravity_assist_dv_bonus if mission.has_gravity_assist else 0.0
	var min_dv_launch: float = mission.required_delta_v - mission.delta_v_tolerance - ga_credit
	if delta_v > 0.0 and total_delta_v < min_dv_launch:
		warnings.append(Loc.pick(
			"Δv total bajo (%.0f / %.0f m/s req.).",
			"Low total Δv (%.0f / %.0f m/s req.)."
		) % [total_delta_v, mission.required_delta_v])
	elif delta_v > 0.0 and total_delta_v < (mission.required_delta_v - mission.delta_v_tolerance):
		warnings.append(Loc.pick(
			"Δv ajustado: exige aprovechar honda gravitatoria (+%.0f m/s).",
			"Tight Δv: requires gravity assist boost (+%.0f m/s)."
		) % ga_credit)
	if twr > 0.0 and twr < mission.min_twr:
		warnings.append(Loc.pick("TWR bajo (%.2f < %.2f).", "Low TWR (%.2f < %.2f).") % [twr, mission.min_twr])
	if net_power_w < 0.0:
		warnings.append(Loc.pick(
			"Déficit eléctrico a %.2f UA (%.0f W). Añade paneles o alterna buses.",
			"Power deficit at %.2f AU (%.0f W). Add panels or cycle buses."
		) % [
			mission.distance_au,
			net_power_w,
		])
	if total_data_mb > 0.0 and est_tx_time_s > mission.transit_duration_s * 0.18:
		warnings.append(Loc.pick(
			"Enlace lento a %.2f UA (%.1f kbps -> ~%.0fs HGA): instala Banda-X/Ka.",
			"Slow link at %.2f AU (%.1f kbps -> ~%.0fs HGA): fit X/Ka-Band."
		) % [
			mission.earth_distance_au,
			eff_kbps,
			est_tx_time_s,
		])
	elif max_science <= 0:
		warnings.append(Loc.pick("Sin instrumentos científicos instalados.", "No scientific instruments installed."))

	return {
		"valid_for_launch": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"launch_vehicle_name": lv.display_name if lv != null else Loc.pick("Sin Lanzador", "No Launcher"),
		"launch_vehicle_short": lv.short_name if lv != null else Loc.pick("NINGUNO", "NONE"),
		"spacecraft_cost": spacecraft_cost,
		"lv_cost": lv_cost,
		"cost": cost,
		"budget_remaining": mission.budget - cost,
		"dry_mass_kg": dry_mass,
		"propellant_kg": prop_mass,
		"wet_mass_kg": wet_mass,
		"max_payload_kg": max_payload_kg,
		"module_count": module_count,
		"max_fairing_modules": max_fairing_modules,
		"thrust_n": thrust_n,
		"isp_s": isp_s,
		"delta_v": delta_v,
		"injection_dv": injection_dv,
		"total_delta_v": total_delta_v,
		"twr": twr,
		"solar_gen_w": solar_w,
		"power_draw_w": draw_w,
		"burn_power_draw_w": calculate_power_draw_w(design, true, true, true, false, 0.0, 1.0),
		"net_power_w": net_power_w,
		"battery_wh": battery_wh,
		"raw_comms_kbps": raw_kbps,
		"comms_kbps": eff_kbps,
		"total_data_mb": total_data_mb,
		"est_tx_time_s": est_tx_time_s,
		"est_tx_physical_s": est_tx_physical_s,
		"max_science": max_science,
		"min_science_required": mission.min_science_required,
	}
