class_name FlightTelemetry
extends RefCounted
## Pure snapshot of the probe's flight, propulsion, power, and science state.

enum Status {
	READY,
	IN_FLIGHT,
	VICTORY,
	FAILED_FUEL,
	FAILED_POWER,
	FAILED_MISSED_TARGET,
}

var status: Status = Status.READY
var failure_reason: String = ""

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

var in_shadow: bool = false
var in_solar_storm: bool = false
var in_flyby_window: bool = false

var instruments_captured: Dictionary = {} # part_id -> float (0.0..1.0 capture quality)
var instruments_transmitted: Dictionary = {} # part_id -> bool
var science_score: int = 0
var science_max: int = 0

var active_alerts: Array[String] = []
var event_log: Array[String] = []
