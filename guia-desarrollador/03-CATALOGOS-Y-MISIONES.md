# 03 — Catálogos y misiones

[Volver al índice](README.md)

## Catálogo de piezas (`PartCatalog`)

Definido en [PartCatalog.gd](../src/data/PartCatalog.gd) y servido por el Autoload [MissionData.gd](../src/data/MissionData.gd). Contiene 13 piezas distribuidas en 4 categorías:

### Propulsión (`PartSpec.Category.PROPULSION`)

| `id` | Nombre | Masa seca | Empuje | $I_{sp}$ | Costo | Máx. |
| --- | --- | --- | --- | --- | --- | --- |
| `eng_hydrazine` | Propulsor R-4D | `22 kg` | `2600 N` | `295 s` | `$12,000` | `2` |
| `eng_biprop` | Motor Aestus II | `45 kg` | `5200 N` | `345 s` | `$28,000` | `2` |
| `eng_ion` | Propulsor Iónico XEN-9 | `38 kg` | `3000 N` | `520 s` | `$42,000` | `2` |

### Tanques (`PartSpec.Category.TANK`)

| `id` | Nombre | Masa seca | Propelente | Costo | Máx. |
| --- | --- | --- | --- | --- | --- |
| `tank_small` | Tanque Esférico S-140 | `18 kg` | `140 kg` | `$8,000` | `4` |
| `tank_medium` | Tanque Cilíndrico M-320 | `35 kg` | `320 kg` | `$17,000` | `4` |
| `tank_large` | Tanque Criogénico L-640 | `68 kg` | `640 kg` | `$32,000` | `3` |

### Energía (`PartSpec.Category.ENERGY`)

| `id` | Nombre | Masa seca | Generación @1UA / Capacidad | Costo | Máx. |
| --- | --- | --- | --- | --- | --- |
| `solar_compact` | Panel Solar Compacto | `10 kg` | `+45 W` | `$9,000` | `4` |
| `solar_wing` | Ala Fotovoltaica Doble | `24 kg` | `+110 W` | `$21,000` | `4` |
| `bat_liion` | Batería Li-Ion 120Wh | `14 kg` | `120 Wh` | `$8,500` | `4` |
| `bat_heavy` | Banco Sólido 260Wh | `28 kg` | `260 Wh` | `$18,000` | `3` |

### Instrumentos científicos (`PartSpec.Category.INSTRUMENT`)

| `id` | Nombre | Masa seca | Consumo | Ciencia | Costo | Máx. |
| --- | --- | --- | --- | --- | --- | --- |
| `inst_cam` | Cámara Multiespectral | `12 kg` | `14 W` | `150 pts` | `$12,000` | `1` |
| `inst_spec` | Espectrómetro IR | `18 kg` | `22 W` | `250 pts` | `$19,000` | `1` |
| `inst_radar` | Radar Altimétrico SAR | `26 kg` | `32 W` | `350 pts` | `$26,000` | `1` |

## Catálogo de misiones (`MissionCatalog`)

Definido en [MissionCatalog.gd](../src/data/MissionCatalog.gd):

| `id` | Presupuesto | $\Delta v$ (tol.) | Sol | Tránsito | Sombras | Tormentas | Sobrevuelo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `leo_tutorial` | `$110,000` | `950 (±180)` | `1.00 UA` | `40 s` | `[0.35, 0.52]` | — | `[0.65, 0.95]` |
| `lunar_flyby` | `$145,000` | `2200 (±210)` | `1.00 UA` | `52 s` | `[0.28, 0.44]`, `[0.58, 0.70]` | — | `[0.72, 0.95]` |
| `mars_orbit` | `$195,000` | `3500 (±250)` | `1.52 UA` | `64 s` | `[0.30, 0.45]` | `[0.52, 0.67]` | `[0.74, 0.96]` |

## Máquina de fases y estado (`GameState`)

[GameState.gd](../src/application/GameState.gd) gestiona las transiciones de fase mediante el enum `GameState.Phase`:

- `MISSION_SELECT` $\rightarrow$ `enter_assembly(mission_id)` $\rightarrow$ `ASSEMBLY`
- `ASSEMBLY` $\rightarrow$ `launch_mission()` (valida `last_evaluation.valid_for_launch` e instancia `FlightSimulator`) $\rightarrow$ `FLIGHT_COCKPIT`
- `FLIGHT_COCKPIT` $\rightarrow$ `notify_flight_finished(telemetry)` (actualiza `completed_missions` si `VICTORY`) $\rightarrow$ `MISSION_RESULT`

`GameState.load_recommended_baseline()` carga configuraciones pre-validadas para cualquiera de las 3 misiones, permitiendo probar la cabina inmediatamente o utilizarla como referencia de balanceo.
