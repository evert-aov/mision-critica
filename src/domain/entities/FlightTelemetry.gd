class_name FlightTelemetry
extends RefCounted
## Pure snapshot of the probe's flight, attitude (ACS), trajectory, launch vehicle injection,
## propulsion, power, communications downlink, and mission objective state.

enum Status {
	READY,
	IN_FLIGHT,
	VICTORY,
	FAILED_FUEL,
	FAILED_POWER,
	FAILED_MISSED_TARGET,
	FAILED_OBJECTIVES,
}

enum SystemState {
	STABLE,
	CAUTION,
	CRITICAL,
}

enum AttitudeMode {
	MANUAL,
	HOLD,
	PROGRADE,
	RETROGRADE,
	SOLAR,
	EARTH,
	TARGET,
	POINT,
}

enum FlightPhase {
	CRUISE_COAST,
	TCM_WINDOW,
	GRAVITY_ASSIST,
	ORBITAL_INSERTION,
}

var status: Status = Status.READY
var system_state: SystemState = SystemState.STABLE
var system_state_reason: String = "NOMINAL"
var flight_phase: FlightPhase = FlightPhase.CRUISE_COAST
var failure_reason: String = ""

var launch_vehicle_name: String = "Sin Lanzador"
var launch_injection_dv: float = 0.0

var elapsed_s: float = 0.0
var progress_norm: float = 0.0
var distance_km: float = 0.0
var target_distance_km: float = 400.0

var dry_mass_kg: float = 0.0
var propellant_remaining_kg: float = 0.0
var propellant_max_kg: float = 0.0
var delta_v_burned: float = 0.0
var delta_v_remaining: float = 0.0
var delta_v_initial: float = 0.0
var delta_v_required: float = 0.0
var effective_delta_v: float = 0.0

var battery_wh: float = 0.0
var battery_max_wh: float = 0.0
var solar_gen_w: float = 0.0
var power_draw_w: float = 0.0
var power_net_w: float = 0.0

var throttle: float = 0.0
var safety_cover_open: bool = false
var engine_armed: bool = false
var engine_firing: bool = false

var master_bus_on: bool = true
var comms_on: bool = true
var science_bus_on: bool = true
var panels_deployed: bool = false

# 1. Attitude Control System (Reaction Wheels + RCS)
var attitude_mode: AttitudeMode = AttitudeMode.PROGRADE
var attitude_deg: float = 0.0
var target_attitude_deg: float = 0.0
var angular_vel_deg_s: float = 0.0
var attitude_aligned: bool = true
var is_tumbling: bool = false
var rw_saturation: float = 0.0
var rcs_enabled: bool = false
var rcs_active_jets: int = 0
var solar_pointing_factor: float = 0.84
var comms_link_factor: float = 0.32
var downlink_kbps: float = 0.0
var target_pointing_ok: bool = false

# 2. Trajectory Control (TCM, Gravity Assist, 180° Orbital Insertion)
var trajectory_error_km: float = 0.0
var max_trajectory_error_km: float = 45.0
var tcm_burns_count: int = 0
var in_tcm_window: bool = false
var in_gravity_assist_window: bool = false
var gravity_assist_completed: bool = false
var gravity_assist_dv_gained: float = 0.0
var in_insertion_window: bool = false
var insertion_dv_burned: float = 0.0
var insertion_dv_target: float = 0.0
var wrong_burn_direction: bool = false

var in_shadow: bool = false
var in_solar_storm: bool = false
var in_flyby_window: bool = false

var instruments_captured: Dictionary = {} # part_id -> float (0.0..1.0 capture quality)
var instruments_transmitted: Dictionary = {} # part_id -> bool
var science_score: int = 0
var science_max: int = 0
var science_min_required: int = 0

var active_alerts: Array[String] = []
var event_log: Array[String] = []


func is_controlled_slew() -> bool:
	# Rapid commanded turns temporarily affect pointing, but are not lost attitude control.
	return is_tumbling and master_bus_on and attitude_mode not in [AttitudeMode.MANUAL, AttitudeMode.HOLD] and (rw_saturation < 0.995 or (rcs_enabled and propellant_remaining_kg > 0.02))


static func system_state_label(s: SystemState) -> String:
	match s:
		SystemState.STABLE:
			return Loc.pick("ESTABLE", "STABLE")
		SystemState.CAUTION:
			return Loc.pick("PRECAUCIÓN", "CAUTION")
		SystemState.CRITICAL:
			return Loc.pick("CRÍTICO", "CRITICAL")
	return Loc.pick("ESTABLE", "STABLE")


static func attitude_mode_label(m: AttitudeMode) -> String:
	match m:
		AttitudeMode.MANUAL:
			return "MANUAL"
		AttitudeMode.HOLD:
			return Loc.pick("ESTABILIZAR", "HOLD SAS")
		AttitudeMode.PROGRADE:
			return Loc.pick("PROGRADO 0°", "PROGRADE 0°")
		AttitudeMode.RETROGRADE:
			return Loc.pick("RETRÓGRADO 180°", "RETROGRADE 180°")
		AttitudeMode.SOLAR:
			return "SOLAR -90°"
		AttitudeMode.EARTH:
			return Loc.pick("TIERRA +90°", "EARTH +90°")
		AttitudeMode.TARGET:
			return Loc.pick("OBJETIVO -35°", "TARGET -35°")
		AttitudeMode.POINT:
			return Loc.pick("APUNTADO LIBRE", "FREE POINT")
	return "MANUAL"


static func flight_phase_label(p: FlightPhase) -> String:
	match p:
		FlightPhase.CRUISE_COAST:
			return Loc.pick("CRUCERO INERCIAL", "INERTIAL CRUISE")
		FlightPhase.TCM_WINDOW:
			return Loc.pick("CORRECCIÓN TCM", "TCM CORRECTION")
		FlightPhase.GRAVITY_ASSIST:
			return Loc.pick("HONDA GRAVITATORIA", "GRAVITY ASSIST")
		FlightPhase.ORBITAL_INSERTION:
			return Loc.pick("INSERCIÓN ORBITAL 180°", "ORBITAL INSERTION 180°")
	return Loc.pick("CRUCERO", "CRUISE")
