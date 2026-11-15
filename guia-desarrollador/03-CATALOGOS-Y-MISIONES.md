# 03 — Catálogos y misiones

[Volver al índice](README.md)

## Catálogo de vehículos de lanzamiento (`LaunchVehicleCatalog`)

Definido en [LaunchVehicleCatalog.gd](../src/data/LaunchVehicleCatalog.gd) y servido por [MissionData.gd](../src/data/MissionData.gd):

| `id` | Nombre | Costo | Carga máx. | Cofia (mód.) | Inyección $\Delta v$ | Dispersión inicial |
| --- | --- | --- | --- | --- | --- | --- |
| `lv_light` | Vega-C Ligero | `$18,000` | `420 kg` | `6` | `+0 m/s` | `22 km` |
| `lv_medium` | Ariane-62 Medio | `$36,000` | `820 kg` | `9` | `+300 m/s` | `14 km` |
| `lv_heavy` | Vulcan-Centaur Pesado | `$58,000` | `1,500 kg` | `13` | `+650 m/s` | `8 km` |

## Catálogo de piezas (`PartCatalog`)

Definido en [PartCatalog.gd](../src/data/PartCatalog.gd). Contiene **15 piezas** distribuidas en **5 categorías**:

### Propulsión (`PartSpec.Category.PROPULSION`)

| `id` | Nombre | Masa seca | Empuje | $I_{sp}$ | Costo | Máx. |
| --- | --- | --- | --- | --- | --- | --- |
| `eng_hydrazine` | Propulsor R-4D | `22 kg` | `2600 N` | `295 s` | `$12,000` | `2` |
| `eng_biprop` | Motor Aestus II | `45 kg` | `5200 N` | `345 s` | `$28,000` | `2` |
| `eng_ion` | Propulsor Eléctrico XEN-9 (ficticio) | `38 kg` | `3000 N` | `520 s` | `$42,000` | `2` |

La potencia a pleno acelerador es 5 W (`eng_hydrazine`), 8 W (`eng_biprop`) y 60 W (`eng_ion`). El consumo solo se añade con motor activo y escala con `throttle`. Todos los valores son parámetros simplificados de juego.

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

### Comunicaciones (`PartSpec.Category.COMMS`)

| `id` | Nombre | Masa seca | Consumo | Ancho de banda @1UA | Costo | Máx. |
| --- | --- | --- | --- | --- | --- | --- |
| `comm_xband` | Antena Banda-X | `12 kg` | `8 W` | `+42 kbps` | `$10,000` | `1` |
| `comm_kaband` | Transpondedor Banda-Ka | `22 kg` | `16 W` | `+95 kbps` | `$21,000` | `1` |

### Instrumentos científicos (`PartSpec.Category.INSTRUMENT`)

| `id` | Nombre | Masa seca | Consumo | Volumen de datos | Ciencia | Costo | Máx. |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `inst_cam` | Cámara Multiespectral | `12 kg` | `14 W` | `32 MB` | `150 pts` | `$12,000` | `1` |
| `inst_spec` | Espectrómetro IR | `18 kg` | `22 W` | `54 MB` | `250 pts` | `$19,000` | `1` |
| `inst_radar` | Radar Altimétrico SAR | `26 kg` | `32 W` | `90 MB` | `350 pts` | `$26,000` | `1` |

## Catálogo de misiones (`MissionCatalog`)

Definido en [MissionCatalog.gd](../src/data/MissionCatalog.gd):

| `id` | Presupuesto | Lanzador rec. | $\Delta v$ (tol.) | Sol | Tránsito | Objetivo ciencia mín. | Instrumentos req. |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `leo_tutorial` | `$115,000` | `lv_light` | `950 (±190)` | `1.00 UA` | `48 s` | `100 pts` | `inst_cam` |
| `lunar_flyby` | `$185,000` | `lv_medium` | `2200 (±230)` | `1.00 UA` | `58 s` | `220 pts` | `inst_cam`, `inst_spec` |
| `mars_orbit` | `$260,000` | `lv_heavy` | `3500 (±270)` | `1.52 UA` | `68 s` | `400 pts` | `inst_spec`, `inst_radar` |

## Máquina de fases y estado (`GameState`)

[GameState.gd](../src/application/GameState.gd) gestiona las transiciones de fase, la selección de lanzador (`set_launch_vehicle(lv_id)`) y la carga de configuraciones certificadas (`load_recommended_baseline()`), validando las 9 exigencias antes de iniciar `FlightSimulator`.
