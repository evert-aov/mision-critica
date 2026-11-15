class_name NasaMissionFramework
extends RefCounted
## NASA Systems Engineering assessment & GMAT R2026a trajectory script generator.
## Synthesizes NASA resources into pure domain calculations:
## - JPL Concept Maturity Levels (CML 1..5) & Team X technical margins (35% mass/power, 3/6 dB link)
## - NASA SMD 4 Mission Segments (Launch, Space, Ground, User)
## - CubeSat 101 form factors, MEL, ODAR disposal, and DITL/TVAC readiness gates
## - NASA GMAT R2026a Spacecraft, ForceModel (JGM2/LP165P/Mars50c, SRP, Nominal_Sun), and VNB burns

const GMAT_NOMINAL_SUN_KM: float = 149597870.691
const GMAT_SRP_FLUX_1AU: float = 1367.0
const GMAT_SRP_FLUX_DEEP_SPACE: float = 1358.0

const TEAMX_MASS_MARGIN_TARGET_PCT: float = 35.0
const TEAMX_POWER_MARGIN_TARGET_PCT: float = 35.0
const LINK_MARGIN_PROXIMITY_DB: float = 6.0
const LINK_MARGIN_DEEP_SPACE_DB: float = 3.0
const ODAR_EOL_RESERVE_PCT: float = 3.0


static func get_mission_analogue(mission_id: String) -> Dictionary:
	match mission_id:
		"leo_tutorial":
			return {
				"mission_name": "PUNCH / BisonSat / Dellingr (NASA LEO)",
				"discipline": Loc.pick("Heliofísica y Observación Terrestre", "Heliophysics & Earth Observation"),
				"agency_program": Loc.pick("NASA SMD / CSLI SmallSat & CubeSat", "NASA SMD / CSLI SmallSat & CubeSat"),
				"srp_flux": GMAT_SRP_FLUX_1AU,
				"force_model": "JGM2 (8x8) + SRP (1367 W/m²) + Drag",
				"why_similar": Loc.pick(
					"Múltiples sensores ópticos en LEO, límite estricto de masa/cofia y verificación ODAR/DITL antes del despliegue.",
					"Compact LEO optical payload, strict launcher mass/volume envelope, and ODAR/DITL checks prior to deploy."
				),
			}
		"lunar_flyby":
			return {
				"mission_name": "CAPSTONE / Lunar Trailblazer (NASA Artemis)",
				"discipline": Loc.pick("Ciencia Planetaria Lunar y Navegación Cislunar", "Lunar Planetary Science & Cislunar Nav"),
				"agency_program": Loc.pick("NASA Artemis / SIMPLEx SmallSat", "NASA Artemis / SIMPLEx SmallSat"),
				"srp_flux": GMAT_SRP_FLUX_1AU,
				"force_model": "Earth JGM2 (20x20) + Luna LP165P (20x20) + SRP",
				"why_similar": Loc.pick(
					"Emplea asistencia cislunar, maniobras TCM en marco VNB y espectrometría IR/óptica bajo ciclos de eclipse.",
					"Uses cislunar gravity assist, VNB trajectory correction burns, and IR/optical mapping across eclipse cycles."
				),
			}
		"mars_orbit":
			return {
				"mission_name": "MAVEN / Mars Odyssey / Dawn (NASA Discovery)",
				"discipline": Loc.pick("Exploración Planetaria y Atmósfera Marciana", "Planetary Exploration & Mars Aeronomy"),
				"agency_program": Loc.pick("NASA Mars Scout / Discovery", "NASA Mars Scout / Discovery"),
				"srp_flux": GMAT_SRP_FLUX_DEEP_SPACE,
				"force_model": "Sun + Venus/Earth + Mars50c (8x8) + SRP (1358 W/m²)",
				"why_similar": Loc.pick(
					"Crucero interplanetario 1.52 UA con asistencia en Venus, correcciones TCM hacia B-Plane e inserción retrógrada.",
					"1.52 AU deep-space cruise via Venus slingshot, B-Plane TCM trim burns, and retrograde capture burn."
				),
			}
		_:
			return {
				"mission_name": "NASA SMD Explorers / CSLI",
				"discipline": Loc.pick("Ciencia Espacial Aplicada", "Applied Space Science"),
				"agency_program": "NASA SMD",
				"srp_flux": GMAT_SRP_FLUX_1AU,
				"force_model": "EarthMJ2000Eq RungeKutta89",
				"why_similar": Loc.pick(
					"Arquitectura por 4 segmentos (Lanzamiento, Espacio, Tierra y Usuario).",
					"4-segment architecture (Launch, Space, Ground, User)."
				),
			}


static func classify_form_factor(wet_mass_kg: float) -> String:
	if wet_mass_kg <= 1.33:
		return Loc.pick("1U CubeSat (<=1.33 kg, prot. <=6.5mm)", "1U CubeSat (<=1.33 kg, <=6.5mm prot.)")
	if wet_mass_kg <= 4.0:
		return Loc.pick("3U CubeSat (<=4.0 kg, DISPENSER)", "3U CubeSat (<=4.0 kg, DISPENSER)")
	if wet_mass_kg <= 24.0:
		return Loc.pick("6U-12U CubeSat (<=24 kg)", "6U-12U CubeSat (<=24 kg)")
	if wet_mass_kg < 300.0:
		return Loc.pick("SmallSat / ESPA (<300 kg, CubeSat 101)", "SmallSat / ESPA (<300 kg, CubeSat 101)")
	return Loc.pick("Bus Espacial Medio (>=300 kg)", "Medium Deep-Space Bus (>=300 kg)")


static func assess(design: ProbeDesign, mission: MissionSpec, telemetry: FlightTelemetry = null) -> Dictionary:
	if design == null or mission == null:
		return {}
	var ev: Dictionary = RocketMath.evaluate_design(design, mission)
	var analogue: Dictionary = get_mission_analogue(mission.id)

	var lv: LaunchVehicleSpec = design.get_launch_vehicle()
	var wet_kg: float = float(ev.get("wet_mass_kg", 0.0))
	var dry_kg: float = float(ev.get("dry_mass_kg", 0.0))
	var prop_kg: float = float(ev.get("propellant_kg", 0.0))
	var max_kg: float = float(ev.get("max_payload_kg", 0.0))
	var mod_cnt: int = int(ev.get("module_count", 0))
	var max_mod: int = int(ev.get("max_fairing_modules", 0))
	var cost: int = int(ev.get("cost", 0))

	var ga_credit: float = mission.gravity_assist_dv_bonus if mission.has_gravity_assist else 0.0
	var total_dv: float = float(ev.get("total_delta_v", 0.0))
	var min_dv_needed: float = mission.required_delta_v - mission.delta_v_tolerance - ga_credit

	var solar_w: float = float(ev.get("solar_gen_w", 0.0))
	var draw_w: float = float(ev.get("power_draw_w", 0.0))
	var net_w: float = float(ev.get("net_power_w", 0.0))
	var eff_kbps: float = float(ev.get("comms_kbps", 0.0))
	var data_mb: float = float(ev.get("total_data_mb", 0.0))
	var max_sci: int = int(ev.get("max_science", 0))

	# JPL Team X CML-4 technical margins
	var mass_margin_pct: float = ((max_kg - wet_kg) / max_kg) * 100.0 if (lv != null and max_kg > 0.0) else -100.0
	var power_margin_pct: float = ((solar_w - draw_w) / solar_w) * 100.0 if solar_w > 0.0 else -100.0

	var tx_budget_game_s: float = maxf(mission.transit_duration_s * 0.18, 0.5)
	var req_kbps: float = 4.0
	if data_mb > 0.0:
		req_kbps = (data_mb * RocketMath.KILOBITS_PER_MEGABYTE) / (tx_budget_game_s * RocketMath.DATA_SECONDS_PER_GAME_SECOND)
	var link_margin_db: float = 10.0 * (log(maxf(eff_kbps, 0.01) / maxf(req_kbps, 0.1)) / log(10.0))
	var link_req_db: float = LINK_MARGIN_PROXIMITY_DB if mission.earth_distance_au < 0.05 else LINK_MARGIN_DEEP_SPACE_DB

	var disposal_reserve_pct: float = 0.0
	if telemetry != null and prop_kg > 0.0:
		disposal_reserve_pct = clampf((telemetry.propellant_remaining_kg / prop_kg) * 100.0, 0.0, 100.0)
	elif total_dv > 0.0:
		disposal_reserve_pct = clampf(((total_dv - maxf(min_dv_needed, 0.0)) / total_dv) * 100.0, -100.0, 100.0)

	# JPL CML 1..5 cumulative gates
	var has_req_inst: bool = true
	for req_id in mission.required_instruments:
		if design.get_part_count(req_id) <= 0:
			has_req_inst = false
			break

	var cml1_ok: bool = true
	var cml2_ok: bool = cml1_ok and (lv != null) and float(ev.get("thrust_n", 0.0)) > 0.0 and prop_kg > 0.0 and total_dv >= min_dv_needed
	var cml3_ok: bool = cml2_ok and cost <= mission.budget and wet_kg <= max_kg and mod_cnt <= max_mod and has_req_inst and max_sci >= mission.min_science_required
	var valid_launch: bool = bool(ev.get("valid_for_launch", false))
	var warnings: Array = ev.get("warnings", [])
	var cml4_ok: bool = cml3_ok and valid_launch and net_w >= 0.0 and link_margin_db >= 0.0
	var cml5_ok: bool = cml4_ok and warnings.is_empty() and disposal_reserve_pct >= ODAR_EOL_RESERVE_PCT

	var cml_level: int = 1
	if cml5_ok:
		cml_level = 5
	elif cml4_ok:
		cml_level = 4
	elif cml3_ok:
		cml_level = 3
	elif cml2_ok:
		cml_level = 2

	var cml_names: Array[String] = [
		Loc.pick("CML 1: Concepto Inicial (Objetivo y Destino)", "CML 1: Cocktail Napkin (Goal & Target)"),
		Loc.pick("CML 2: Viabilidad Inicial (Lanzador y Δv)", "CML 2: Initial Feasibility (LV & Δv)"),
		Loc.pick("CML 3: Espacio de Compromisos (Masa/Presup./Ciencia)", "CML 3: Trade Space (Mass/Cost/Science)"),
		Loc.pick("CML 4: Diseño Puntual (Márgenes Team X)", "CML 4: Point Design (Team X Margins)"),
		Loc.pick("CML 5: Concepto Base / MCR Listo para Vuelo", "CML 5: Baseline Concept / MCR Flight Ready"),
	]

	var checks: Array[Dictionary] = [
		{"level": 1, "name": cml_names[0], "ok": cml1_ok},
		{"level": 2, "name": cml_names[1], "ok": cml2_ok},
		{"level": 3, "name": cml_names[2], "ok": cml3_ok},
		{"level": 4, "name": cml_names[3], "ok": cml4_ok},
		{"level": 5, "name": cml_names[4], "ok": cml5_ok},
	]

	# NASA 4 Mission Segments (Launch, Space, Ground, User)
	var seg_launch_ok: bool = lv != null and wet_kg <= max_kg and mod_cnt <= max_mod and cost <= mission.budget
	var seg_space_ok: bool = float(ev.get("thrust_n", 0.0)) > 0.0 and prop_kg > 0.0 and net_w >= 0.0
	var seg_ground_ok: bool = eff_kbps > 0.0 and link_margin_db >= 0.0
	var seg_user_ok: bool = has_req_inst and max_sci >= mission.min_science_required

	var segments: Array[Dictionary] = [
		{
			"id": "launch",
			"title": Loc.pick("1. SEGMENTO DE LANZAMIENTO", "1. LAUNCH SEGMENT"),
			"ok": seg_launch_ok,
			"detail": Loc.pick("%s | Carga %.0f/%.0f kg | Cofia %d/%d", "%s | Load %.0f/%.0f kg | Fairing %d/%d") % [
				str(ev.get("launch_vehicle_short", "-")),
				wet_kg,
				max_kg,
				mod_cnt,
				max_mod,
			],
		},
		{
			"id": "space",
			"title": Loc.pick("2. SEGMENTO ESPACIAL (SONDA)", "2. SPACE SEGMENT (SPACECRAFT)"),
			"ok": seg_space_ok,
			"detail": Loc.pick("%s | MEL %d mód | %.0f kg seco | %+.0f W", "%s | MEL %d mod | %.0f kg dry | %+.0f W") % [
				classify_form_factor(wet_kg),
				mod_cnt,
				dry_kg,
				net_w,
			],
		},
		{
			"id": "ground",
			"title": Loc.pick("3. SEGMENTO TERRENO (MOS/GDS)", "3. GROUND SEGMENT (MOS/GDS)"),
			"ok": seg_ground_ok,
			"detail": Loc.pick("Enlace %.1f kbps | Margen %.1f dB (req >= %.0f dB)", "Link %.1f kbps | Margin %.1f dB (req >= %.0f dB)") % [
				eff_kbps,
				link_margin_db,
				link_req_db,
			],
		},
		{
			"id": "user",
			"title": Loc.pick("4. SEGMENTO DE USUARIO (CIENCIA)", "4. USER SEGMENT (SCIENCE)"),
			"ok": seg_user_ok,
			"detail": Loc.pick("%s | %d pts / %.0f MB | Análogo: %s", "%s | %d pts / %.0f MB | Analogue: %s") % [
				analogue["discipline"],
				max_sci,
				data_mb,
				analogue["mission_name"],
			],
		},
	]

	# CubeSat 101 Verification Gates (MEL, ODAR, DITL, TVAC/Vibe)
	var verification_gates: Array[Dictionary] = [
		{
			"code": "MEL",
			"ok": mod_cnt > 0 and wet_kg <= max_kg,
			"text": Loc.pick(
				"MEL (Lista Maestra de Equipos): bus 120 kg + %d módulos = %.0f kg húmedo.",
				"MEL (Master Equipment List): 120 kg bus + %d modules = %.0f kg wet."
			) % [mod_cnt, wet_kg],
		},
		{
			"code": "ODAR",
			"ok": disposal_reserve_pct >= ODAR_EOL_RESERVE_PCT,
			"text": Loc.pick(
				"ODAR (Basura Orbital): reserva fin de vida %.1f%% (rec >= %.0f%%) y pasivación.",
				"ODAR (Orbital Debris): EOL disposal reserve %.1f%% (rec >= %.0f%%) & passivation."
			) % [disposal_reserve_pct, ODAR_EOL_RESERVE_PCT],
		},
		{
			"code": "DITL",
			"ok": seg_space_ok and seg_ground_ok,
			"text": Loc.pick(
				"DITL (Día en la Vida): inhibición eléctrica en desacople, TLE y prueba TX.",
				"DITL (Day In The Life): deploy inhibits, TLE acquisition & TX commissioning."
			),
		},
		{
			"code": "TVAC",
			"ok": mod_cnt <= max_mod and float(ev.get("battery_wh", 0.0)) > 0.0,
			"text": Loc.pick(
				"Vibración / TVAC (Horneado y Vacío Térmico): cofia %d/%d e integridad térmica en eclipse.",
				"Vibration / TVAC (Thermal Vacuum): fairing %d/%d & eclipse thermal survival."
			) % [mod_cnt, max_mod],
		},
	]

	return {
		"cml_level": cml_level,
		"cml_label": cml_names[cml_level - 1],
		"cml_short": "CML %d/5" % cml_level,
		"checks": checks,
		"segments": segments,
		"verification_gates": verification_gates,
		"nasa_analogue": analogue,
		"form_factor": classify_form_factor(wet_kg),
		"margins": {
			"mass_margin_pct": mass_margin_pct,
			"mass_teamx_ok": mass_margin_pct >= TEAMX_MASS_MARGIN_TARGET_PCT,
			"power_margin_pct": power_margin_pct,
			"power_teamx_ok": power_margin_pct >= TEAMX_POWER_MARGIN_TARGET_PCT,
			"link_margin_db": link_margin_db,
			"link_req_db": link_req_db,
			"link_ok": link_margin_db >= link_req_db,
			"disposal_reserve_pct": disposal_reserve_pct,
			"odar_ok": disposal_reserve_pct >= ODAR_EOL_RESERVE_PCT,
		},
		"evaluation": ev,
	}


static func format_summary_report(design: ProbeDesign, mission: MissionSpec) -> String:
	var report: Dictionary = assess(design, mission)
	if report.is_empty():
		return ""
	var m: Dictionary = report["margins"]
	var analogue: Dictionary = report["nasa_analogue"]
	var lines: PackedStringArray = []
	lines.append(Loc.pick("NIVEL DE MADUREZ JPL (CML 1-5): %s", "JPL CONCEPT MATURITY LEVEL (CML 1-5): %s") % report["cml_label"])
	for chk in report["checks"]:
		lines.append("  [%s] %s" % ["OK" if chk["ok"] else "..", chk["name"]])
	lines.append("")
	lines.append(Loc.pick("4 SEGMENTOS DE MISIÓN NASA (SMD):", "4 NASA SCIENCE MISSION SEGMENTS (SMD):"))
	for seg in report["segments"]:
		lines.append("  [%s] %s -> %s" % ["OK" if seg["ok"] else "!!", seg["title"], seg["detail"]])
	lines.append("")
	lines.append(Loc.pick("MÁRGENES TÉCNICOS TEAM X (CML-4) Y CUBESAT 101:", "TEAM X TECHNICAL MARGINS (CML-4) & CUBESAT 101:"))
	lines.append(Loc.pick(
		"  Clase: %s\n  Margen Masa Lanzador: %.1f%% (Meta CML-4 JPL >= 35%%)\n  Margen Energía Solar: %.1f%% (Meta CML-4 JPL >= 35%%)\n  Margen Enlace RF: %+.1f dB (Req JPL >= %.0f dB)\n  Reserva Δv / ODAR EOL: %.1f%% (Mín ODAR >= 3%%)",
		"  Class: %s\n  Launcher Mass Margin: %.1f%% (JPL CML-4 Goal >= 35%%)\n  Solar Power Margin: %.1f%% (JPL CML-4 Goal >= 35%%)\n  RF Link Margin: %+.1f dB (JPL Req >= %.0f dB)\n  Δv / ODAR EOL Reserve: %.1f%% (ODAR Min >= 3%%)"
	) % [
		report["form_factor"],
		float(m["mass_margin_pct"]),
		float(m["power_margin_pct"]),
		float(m["link_margin_db"]),
		float(m["link_req_db"]),
		float(m["disposal_reserve_pct"]),
	])
	lines.append("")
	lines.append(Loc.pick("VERIFICACIÓN PREVIA AL VUELO (CUBESAT 101):", "PRE-FLIGHT VERIFICATION GATES (CUBESAT 101):"))
	for gate in report["verification_gates"]:
		lines.append("  [%s] %s" % ["OK" if gate["ok"] else "!!", gate["text"]])
	lines.append("")
	lines.append(Loc.pick("MISIÓN ANÁLOGA NASA: %s (%s)", "NASA ANALOGOUS MISSION: %s (%s)") % [analogue["mission_name"], analogue["agency_program"]])
	lines.append("  %s" % analogue["why_similar"])
	lines.append(Loc.pick("  Modelo Dinámico GMAT: %s", "  GMAT Force Model: %s") % analogue["force_model"])
	return "\n".join(lines)


static func generate_gmat_script(design: ProbeDesign, mission: MissionSpec) -> String:
	if design == null or mission == null:
		return ""
	var ev: Dictionary = RocketMath.evaluate_design(design, mission)
	var analogue: Dictionary = get_mission_analogue(mission.id)
	var dry_mass: float = maxf(float(ev.get("dry_mass_kg", 120.0)), 1.0)
	var prop_mass: float = maxf(float(ev.get("propellant_kg", 20.0)), 0.0)
	var wet_mass: float = dry_mass + prop_mass
	var isp: float = maxf(float(ev.get("isp_s", 220.0)), 100.0)
	var thrust_n: float = maxf(float(ev.get("thrust_n", 100.0)), 1.0)

	var srp_flux: float = float(analogue["srp_flux"])
	var tcm_dv_kms: float = clampf((mission.initial_trajectory_error_km / maxf(mission.target_distance_km, 420.0)) * 0.8 + 0.025, 0.015, 0.250)
	var moi_dv_kms: float = maxf(mission.insertion_dv_required / 1000.0, 0.35)

	var central_body: String = "Earth"
	var grav_line: String = "GMAT FM_Mission.GravityField.Earth.Degree = 8;\nGMAT FM_Mission.GravityField.Earth.Order = 8;\nGMAT FM_Mission.GravityField.Earth.PotentialFile = 'JGM2.cof';"
	var point_masses: String = "{Luna, Sun}"
	var drag_line: String = "GMAT FM_Mission.Drag.AtmosphereModel = 'JacchiaRoberts';"
	var sma_km: float = 6798.14
	var ecc: float = 0.0012
	var inc_deg: float = 51.6
	var transfer_days: float = 0.5

	if mission.id == "lunar_flyby":
		grav_line = "GMAT FM_Mission.GravityField.Earth.Degree = 20;\nGMAT FM_Mission.GravityField.Earth.Order = 20;\nGMAT FM_Mission.GravityField.Earth.PotentialFile = 'JGM2.cof';\nGMAT FM_Mission.GravityField.Luna.Degree = 20;\nGMAT FM_Mission.GravityField.Luna.Order = 20;\nGMAT FM_Mission.GravityField.Luna.PotentialFile = 'LP165P.cof';"
		point_masses = "{Sun}"
		drag_line = "GMAT FM_Mission.Drag = None;"
		sma_km = 198500.0
		ecc = 0.962
		inc_deg = 28.5
		transfer_days = 4.5
	elif mission.id == "mars_orbit":
		central_body = "Sun"
		grav_line = "GMAT FM_Mission.GravityField.Mars.Degree = 8;\nGMAT FM_Mission.GravityField.Mars.Order = 8;\nGMAT FM_Mission.GravityField.Mars.PotentialFile = 'Mars50c.cof';"
		point_masses = "{Earth, Venus, Mars}"
		drag_line = "GMAT FM_Mission.Drag = None;"
		sma_km = 194500000.0
		ecc = 0.215
		inc_deg = 2.4
		transfer_days = 240.0

	var lv_name: String = str(ev.get("launch_vehicle_name", "None"))
	var script_lines: PackedStringArray = [
		"%--------------------------------------------------------------------------",
		"% NASA GMAT R2026a Trajectory Model - Exported from Mision Critica",
		"%% Mission: %s (%s)" % [mission.id, analogue["mission_name"]],
		"%% Launcher: %s | Wet Mass: %.1f kg | Isp: %.0f s | Thrust: %.0f N" % [lv_name, wet_mass, isp, thrust_n],
		"%--------------------------------------------------------------------------",
		"",
		"Create Spacecraft Probe;",
		"GMAT Probe.DateFormat = UTCGregorian;",
		"GMAT Probe.Epoch = '01 Jul 2026 12:00:00.000';",
		"GMAT Probe.CoordinateSystem = EarthMJ2000Eq;",
		"GMAT Probe.DisplayStateType = Keplerian;",
		"GMAT Probe.SMA = %.2f;" % sma_km,
		"GMAT Probe.ECC = %.4f;" % ecc,
		"GMAT Probe.INC = %.2f;" % inc_deg,
		"GMAT Probe.RAAN = 45.0;",
		"GMAT Probe.AOP = 15.0;",
		"GMAT Probe.TA = 0.0;",
		"GMAT Probe.DryMass = %.2f;" % dry_mass,
		"GMAT Probe.Cr = 1.7;",
		"GMAT Probe.DragArea = 6.0;",
		"GMAT Probe.SRPArea = 12.0;",
		"",
		"Create ChemicalTank MainTank;",
		"GMAT MainTank.FuelMass = %.2f;" % prop_mass,
		"GMAT MainTank.Pressure = 1500;",
		"GMAT MainTank.Volume = %.2f;" % maxf(prop_mass / 950.0, 0.05),
		"GMAT Probe.Tanks = {MainTank};",
		"",
		"Create ChemicalThruster MainEngine;",
		"GMAT MainEngine.Tank = {MainTank};",
		"GMAT MainEngine.C1 = %.2f;" % thrust_n,
		"GMAT MainEngine.K1 = %.2f;" % isp,
		"GMAT Probe.Thrusters = {MainEngine};",
		"",
		"Create ForceModel FM_Mission;",
		"GMAT FM_Mission.CentralBody = %s;" % central_body,
		"GMAT FM_Mission.PrimaryBodies = {%s};" % ("Earth, Luna" if mission.id == "lunar_flyby" else ("Mars" if mission.id == "mars_orbit" else "Earth")),
		grav_line,
		"GMAT FM_Mission.PointMasses = %s;" % point_masses,
		drag_line,
		"GMAT FM_Mission.SRP = On;",
		"GMAT FM_Mission.SRP.Flux = %.0f;" % srp_flux,
		"GMAT FM_Mission.SRP.Nominal_Sun = %.3f;" % GMAT_NOMINAL_SUN_KM,
		"",
		"Create Propagator PropRK89;",
		"GMAT PropRK89.FM = FM_Mission;",
		"GMAT PropRK89.Type = RungeKutta89;",
		"GMAT PropRK89.InitialStepSize = 60;",
		"GMAT PropRK89.Accuracy = 1e-11;",
		"",
		"Create ImpulsiveBurn TCM1;",
		"GMAT TCM1.CoordinateSystem = Local;",
		"GMAT TCM1.Origin = Earth;",
		"GMAT TCM1.Axes = VNB;",
		"GMAT TCM1.Element1 = %.4f;   %% VNB Velocity Trim (km/s)" % tcm_dv_kms,
		"GMAT TCM1.DecrementMass = true;",
		"GMAT TCM1.Tank = {MainTank};",
		"GMAT TCM1.Isp = %.1f;" % isp,
		"",
		"Create ImpulsiveBurn RetroInsertionBurn;",
		"GMAT RetroInsertionBurn.CoordinateSystem = Local;",
		"GMAT RetroInsertionBurn.Origin = %s;" % ("Mars" if mission.id == "mars_orbit" else ("Luna" if mission.id == "lunar_flyby" else "Earth")),
		"GMAT RetroInsertionBurn.Axes = VNB;",
		"GMAT RetroInsertionBurn.Element1 = -%.4f;  %% 180 deg Retrograde Braking (km/s)" % moi_dv_kms,
		"GMAT RetroInsertionBurn.DecrementMass = true;",
		"GMAT RetroInsertionBurn.Tank = {MainTank};",
		"GMAT RetroInsertionBurn.Isp = %.1f;" % isp,
		"",
		"BeginMissionSequence;",
		"Propagate PropRK89(Probe) {Probe.ElapsedDays = %.2f};" % (transfer_days * 0.25),
		"Maneuver TCM1(Probe);",
		"Propagate PropRK89(Probe) {Probe.ElapsedDays = %.2f};" % (transfer_days * 0.75),
		"Maneuver RetroInsertionBurn(Probe);",
	]
	return "\n".join(script_lines)


static func sanitize_username(raw: String) -> String:
	var lowered: String = raw.strip_edges().to_lower()
	var out: String = ""
	for i in range(lowered.length()):
		var ch: String = lowered.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_alnum: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if is_alnum or ch == "_" or ch == "-":
			out += ch
	return out


static func validate_profile(display_name: String, username: String) -> Dictionary:
	var clean_name: String = display_name.strip_edges()
	var clean_user: String = sanitize_username(username)
	if clean_name.length() < 2:
		return {
			"ok": false,
			"name": clean_name,
			"username": clean_user,
			"error": Loc.pick("Ingresa tu nombre (mínimo 2 letras).", "Enter your name (at least 2 letters)."),
		}
	if clean_user.length() < 2:
		return {
			"ok": false,
			"name": clean_name,
			"username": clean_user,
			"error": Loc.pick("El username debe tener al menos 2 caracteres (letras, números, _ o -).", "Username must be at least 2 characters (letters, numbers, _ or -)."),
		}
	return {
		"ok": true,
		"name": clean_name,
		"username": clean_user,
		"error": "",
	}


static func evaluate_badges(design: ProbeDesign, mission: MissionSpec, telemetry: FlightTelemetry, manual_only: bool = false) -> Array[String]:
	var badges: Array[String] = []
	if design == null or mission == null or telemetry == null:
		return badges
	if telemetry.status != FlightTelemetry.Status.VICTORY:
		return badges
	var nasa: Dictionary = assess(design, mission, telemetry)
	if nasa.is_empty():
		return badges
	var m: Dictionary = nasa["margins"]
	if int(nasa.get("cml_level", 1)) >= 5:
		badges.append("CML 5")
	if bool(m.get("mass_teamx_ok", false)) or bool(m.get("power_teamx_ok", false)):
		badges.append("TEAM X >=35%")
	if bool(m.get("odar_ok", false)):
		badges.append("ODAR EOL >=3%")
	if bool(m.get("link_ok", false)):
		badges.append("RF TEAM X")
	if manual_only:
		badges.append(Loc.pick("PILOTO MANUAL", "MANUAL PILOT"))
	return badges
