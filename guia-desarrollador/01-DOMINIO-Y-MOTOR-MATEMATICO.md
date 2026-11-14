# 01 — Dominio y motor matemático

[Volver al índice](README.md)

## Entidades del dominio (`src/domain/entities/`)

Todas heredan de `RefCounted` y usan `class_name` global para ser accesibles desde cualquier capa sin rutas acopladas:

| Clase | Archivo | Contenido principal |
| --- | --- | --- |
| `PartSpec` | [PartSpec.gd](../src/domain/entities/PartSpec.gd) | Especificación inmutable de pieza: `id`, `display_name`, `category` (`PROPULSION`, `TANK`, `ENERGY`, `INSTRUMENT`), `mass_dry_kg`, `propellant_kg`, `cost`, `thrust_n`, `isp_s`, `power_gen_w`, `power_draw_w`, `battery_wh`, `science_value`, `texture_key`, `max_count`. |
| `MissionSpec` | [MissionSpec.gd](../src/domain/entities/MissionSpec.gd) | Parámetros de misión: `budget`, `required_delta_v`, `delta_v_tolerance`, `min_twr`, `distance_au`, `target_distance_km`, `transit_duration_s`, `flyby_window_start_norm`, `flyby_window_end_norm`, `shadow_windows`, `solar_storm_windows`, `target_palette`. |
| `ProbeDesign` | [ProbeDesign.gd](../src/domain/entities/ProbeDesign.gd) | Configuración mutable de la sonda (`_counts: Dictionary` de `part_id -> int`), respetando `max_count` por componente y proveyendo `clone()` para aislar la simulación de ediciones posteriores. |
| `FlightTelemetry` | [FlightTelemetry.gd](../src/domain/entities/FlightTelemetry.gd) | Snapshot completo del estado en vuelo: `Status`, tiempos, progreso, masas, $\Delta v$, batería, buses, ventanas ambientales, capturas/transmisiones científicas, alertas y `event_log`. |

### Constantes del chasis base (`ProbeDesign`)

| Constante | Valor | Significado |
| --- | --- | --- |
| `BASE_CHASSIS_MASS_KG` | `120.0` | Masa seca estructural del bus de la sonda. |
| `BASE_CHASSIS_COST` | `15000` | Costo base del bus incluido en toda configuración. |
| `BASE_AVIONICS_DRAW_W` | `12.0` | Consumo continuo de computadora de vuelo con `master_bus_on`. |
| `COMMS_DRAW_W` | `10.0` | Consumo adicional del transpondedor cuando `comms_on` está activo. |
| `BASE_BATTERY_WH` | `40.0` | Reserva eléctrica interna mínima del chasis base. |

## Ecuaciones implementadas (`RocketMath`)

Implementadas como métodos estáticos puros en [RocketMath.gd](../src/domain/services/RocketMath.gd) con gravedad estándar $g_0 = 9.80665\ \text{m/s}^2$:

1. **Masas y costo**:
   - $m_f = \text{BASE\_CHASSIS\_MASS\_KG} + \sum \text{mass\_dry\_kg}$
   - $m_{\text{prop}} = \sum \text{propellant\_kg}$
   - $m_0 = m_f + m_{\text{prop}}$
   - $\text{Costo} = \text{BASE\_CHASSIS\_COST} + \sum \text{cost}$

2. **$I_{sp}$ efectivo y ecuación de Tsiolkovski**:
   Cuando existen múltiples motores encendidos simultáneamente, el impulso específico efectivo se calcula ponderando por el flujo másico ($F / I_{sp}$):
   $$I_{sp,\text{eff}} = \frac{\sum F_i}{\sum (F_i / I_{sp,i})}$$
   $$\Delta v = I_{sp,\text{eff}} \cdot g_0 \cdot \ln\left(\frac{m_0}{m_f}\right)$$

3. **Relación empuje-peso (TWR)**:
   $$\text{TWR} = \frac{\sum F_i}{m_0 \cdot g_0}$$

4. **Generación fotovoltaica y consumo eléctrico**:
   La irradiancia solar decae con el inverso del cuadrado de la distancia al Sol (acotada en el mínimo `0.2 UA`):
   $$P_{\text{solar}} = \begin{cases} 0 & \text{si } \neg\text{panels\_deployed} \lor \text{in\_shadow} \\ \left(\sum P_{\text{gen}, i}\right) \cdot \frac{1.0}{\max(d_{\text{UA}}, 0.2)^2} & \text{en otro caso} \end{cases}$$
   Consumo eléctrico según estado de buses:
   - Si `master_on == false`: consumo mínimo de supervivencia `2.0 W`.
   - Si `master_on == true`: `12.0 W` + (`10.0 W` si `comms_on`) + ($\sum \text{power\_draw\_w}$ de instrumentos si `science_bus_on`) + (`15.0 W` extra si `science_bus_on` y `in_solar_storm`).

## Validación pre-vuelo (`RocketMath.evaluate_design`)

Retorna un `Dictionary` consumido por `AssemblyScreen` y `GameState.launch_mission()`:

- **`errors`** (bloquean `valid_for_launch`):
  - `cost > mission.budget`
  - `thrust_n <= 0.0` (falta motor)
  - `prop_mass <= 0.0` (falta tanque)
- **`warnings`** (informativas, permiten lanzar):
  - $\Delta v < \text{required\_delta\_v} - \text{delta\_v\_tolerance}$
  - $\text{TWR} < \text{mission.min\_twr}$
  - Balance energético neto negativo ($P_{\text{solar}} - P_{\text{draw}} < 0$)
  - `max_science <= 0` (sin instrumentos)
