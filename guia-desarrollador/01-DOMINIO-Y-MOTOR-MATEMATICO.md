# 01 — Dominio y motor matemático

[Volver al índice](README.md)

## Entidades del dominio (`src/domain/entities/`)

Todas heredan de `RefCounted` y usan `class_name` global para mantener aislamiento total frente a la UI:

| Clase | Archivo | Contenido principal |
| --- | --- | --- |
| `LaunchVehicleSpec` | [LaunchVehicleSpec.gd](../src/domain/entities/LaunchVehicleSpec.gd) | Cohete lanzador inmutable: `id`, `display_name`, `short_name`, `cost`, `max_payload_kg`, `max_fairing_modules`, `injection_dv_ms`, `injection_dispersion_km`. |
| `PartSpec` | [PartSpec.gd](../src/domain/entities/PartSpec.gd) | Pieza de nave: `category` (`PROPULSION`, `TANK`, `ENERGY`, `COMMS`, `INSTRUMENT`), masa, costo, propulsión, generación/consumo, `comms_kbps`, `data_volume_mb`, `science_value`, `max_count`. |
| `MissionSpec` | [MissionSpec.gd](../src/domain/entities/MissionSpec.gd) | Requisitos y limitaciones orbitales: `budget`, `required_delta_v`, `min_science_required`, `required_instruments`, `recommended_lv_id`, `distance_au`, ventanas TCM, Honda Gravitatoria e Inserción `180°`. |
| `ProbeDesign` | [ProbeDesign.gd](../src/domain/entities/ProbeDesign.gd) | Integración mutable nave + lanzador (`launch_vehicle: LaunchVehicleSpec` inyectado, `_counts: Dictionary`), con `get_total_module_count()` y `clone()`. |
| `FlightTelemetry` | [FlightTelemetry.gd](../src/domain/entities/FlightTelemetry.gd) | Snapshot completo en vuelo: `Status` (incl. `FAILED_OBJECTIVES`), `SystemState`, `AttitudeMode`, `downlink_kbps`, masas, $\Delta v$, trayectoria y bitácora. |

### Constantes del chasis base (`ProbeDesign`)

| Constante | Valor | Significado |
| --- | --- | --- |
| `BASE_CHASSIS_MASS_KG` | `120.0` | Masa seca estructural del bus base. |
| `BASE_CHASSIS_COST` | `15000` | Costo base del bus incluido en toda sonda. |
| `BASE_AVIONICS_DRAW_W` | `12.0` | Consumo continuo de computadora de vuelo con `master_bus_on`. |
| `COMMS_DRAW_W` | `10.0` | Consumo base del transpondedor Banda-S integrado. |
| `BASE_COMMS_KBPS` | `18.0` | Tasa nominal base a `1.0 UA` del enlace omnidireccional integrado. |
| `BASE_BATTERY_WH` | `40.0` | Reserva eléctrica mínima del chasis base. |

## Ecuaciones implementadas (`RocketMath`)

Implementadas como métodos estáticos puros en [RocketMath.gd](../src/domain/services/RocketMath.gd) con $g_0 = 9.80665\ \text{m/s}^2$:

1. **Masas y presupuesto unificado**:
   - $m_f = \text{BASE\_CHASSIS\_MASS\_KG} + \sum \text{mass\_dry\_kg}$
   - $m_0 = m_f + \sum \text{propellant\_kg}$
   - $\text{Costo Total} = \text{launch\_vehicle.cost} + \text{BASE\_CHASSIS\_COST} + \sum \text{part.cost}$

2. **Propulsión e inyección del lanzador**:
   - $I_{sp,\text{eff}} = \frac{\sum F_i}{\sum (F_i / I_{sp,i})}$, $\Delta v_{\text{sonda}} = I_{sp,\text{eff}} \cdot g_0 \cdot \ln\left(\frac{m_0}{m_f}\right)$
   - $\Delta v_{\text{total}} = \Delta v_{\text{sonda}} + \text{launch\_vehicle.injection\_dv\_ms}$

3. **Energía solar y enlace a Tierra independientes**:
   - Solar: `mission.distance_au`, factor `1 / max(d_sol, 0.2)²`.
   - Radio: `mission.earth_distance_au`, factor `min(1, 1 / max(d_tierra, 1e-9)²)`. La tasa se normaliza a 1 UA y se limita al transmisor cerca de Tierra.
   - Por defecto la distancia a Tierra se deriva de `target_distance_km / 149597870.7`; puede declararse explícitamente en el escenario.
   - $\text{Tasa Bruta} = \text{BASE\_COMMS\_KBPS} + \sum \text{comms\_kbps}$
   - `Tasa Efectiva = Tasa Bruta * factor_radio(d_tierra)`.
   - El consumo en `comms_on` suma `COMMS_DRAW_W` + $\sum \text{power\_draw\_w}$ de módulos `Category.COMMS`.
   - `calculate_power_draw_w(..., engine_throttle)` añade potencia de propulsión proporcional al acelerador. `evaluate_design` expone `power_draw_w` de crucero y `burn_power_draw_w` a plena potencia.

4. **Unidades de datos y escala de juego**:
   - `kbps_to_mb_per_second(kbps) = kbps / 8000` (unidades decimales).
   - `calculate_game_downlink_mb_s(kbps) = MB/s * DATA_SECONDS_PER_GAME_SECOND`, constante explícita `9200`.
   - `est_tx_physical_s = MB / MB_s`; `est_tx_time_s = est_tx_physical_s / 9200`. Ambos corresponden a enlace HGA óptimo; orientación real y paquetes compartidos modifican el vuelo.

## Validación pre-vuelo (`RocketMath.evaluate_design`)

Verifica de forma integral las **9 exigencias contrapuestas**:
- **Errores bloqueantes**: falta lanzador (`require_launch_vehicle`), `wet_mass_kg > lv.max_payload_kg`, `module_count > lv.max_fairing_modules`, `cost > mission.budget`, falta motor o tanque, falta algún instrumento en `mission.required_instruments` o `max_science < mission.min_science_required`.
- **Advertencias operativas**: $\Delta v$ total insuficiente (aun con crédito de honda), `TWR < min_twr`, balance eléctrico negativo en `distance_au` o descarga acelerada demasiado lenta frente al tiempo de tránsito.

## Marco de Ingeniería NASA y GMAT (`NasaMissionFramework`)

Implementado en dominio puro ([NasaMissionFramework.gd](../src/domain/services/NasaMissionFramework.gd), `RefCounted`) sin acoplamiento a UI:

- **`assess(design, mission, telemetry = null)`**:
  - Evalúa **JPL CML 1–5** y márgenes Team X (`35.0%` en masa lanzador y energía solar; `6.0 dB` en proximidad LEO y `3.0 dB` en espacio profundo; `3.0%` de reserva EOL para `ODAR`).
  - Construye los **4 Segmentos NASA SMD** (*Launch*, *Space*, *Ground MOS/GDS*, *User Science*), la clase CubeSat 101 (`1U` `<=1.33 kg`, `3U` `<=4 kg`, `6U-12U` `<=24 kg`, `SmallSat / ESPA <300 kg`, `Bus >=300 kg`) y las compuertas `MEL / ODAR / DITL / TVAC`.
  - Mapea cada escenario a misiones reales NASA (`PUNCH / BisonSat / Dellingr`, `CAPSTONE / Lunar Trailblazer`, `MAVEN / Mars Odyssey / Dawn`).
- **`generate_gmat_script(design, mission)`**: genera un script **NASA GMAT R2026a** listo para análisis (`Create Spacecraft Probe`, `ForceModel` con `JGM2.cof`/`LP165P.cof`/`Mars50c.cof`, `SRP.Flux` `1367`/`1358`, `Nominal_Sun = 149597870.691` y quemados `ImpulsiveBurn` en coordenadas `VNB`).
