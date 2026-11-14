# 05 — Mapa de directorios y flujos

[Volver al índice](README.md)

## Dónde vive cada responsabilidad

| Ruta desde la raíz | Responsabilidad |
| --- | --- |
| `project.godot` | Configuración del motor (`640x360`, `Nearest`), escena principal y Autoloads. |
| `src/domain/entities/` | Modelos puros `PartSpec`, `MissionSpec`, `ProbeDesign` y `FlightTelemetry`. |
| `src/domain/services/` | Lógica física pura (`RocketMath`) y simulación de vuelo (`FlightSimulator`). |
| `src/data/` | Catálogos (`PartCatalog`, `MissionCatalog`) y Autoload `MissionData`. |
| `src/application/` | Estado de campaña (`GameState`), fachada (`PhysicsCalculator`) y audio (`AudioManager`). |
| `src/presentation/theme/` | `ThemeFactory` (tema retro, NinePatch, SpriteFrames). |
| `src/presentation/components/` | Controles reutilizables de plano de sonda y cabina virtual. |
| `src/presentation/screens/` | Pantallas principales (`Main`, `MissionSelectScreen`, `AssemblyScreen`, `CockpitScreen`). |
| `assets/` | Sprites PNG, fuente BMFont y audio WAV generados. |
| `tools/` | Script `generate_assets.py` de generación determinista de recursos. |
| `tests/` | Suite unitaria (`TestRunner.gd`) y prueba de integración (`IntegrationTest.tscn`). |
| `guia-desarrollador/` | Documentación técnica de arquitectura y módulos. |

## Flujo de datos entre fases

```mermaid
sequenceDiagram
  participant User as Jugador
  participant UI as Presentation (Screens)
  participant GS as GameState
  participant RM as RocketMath / PhysicsCalculator
  participant Sim as FlightSimulator

  User->>UI: Selecciona misión
  UI->>GS: enter_assembly(mission_id)
  GS->>RM: evaluate_design(design, mission)
  RM-->>UI: signal design_changed(evaluation)
  User->>UI: Añade/quita piezas (+/-)
  UI->>GS: add_part(id) / remove_part(id)
  GS->>RM: evaluate_design(...)
  User->>UI: Pulsa LANZAR SONDA >>
  UI->>GS: launch_mission()
  GS->>Sim: FlightSimulator.new(mission, design)
  GS-->>UI: phase_changed(FLIGHT_COCKPIT)
  loop Cada frame (_process)
    UI->>Sim: step(delta)
    UI->>UI: Sincroniza Viewport, Power, Nav y Science
  end
  Sim-->>UI: status != IN_FLIGHT
  UI->>GS: notify_flight_finished(telemetry)
```

## Criterio para extender el proyecto

- **Añadir una nueva pieza**: agregar una entrada `PartSpec.new({...})` en [PartCatalog.gd](../src/data/PartCatalog.gd), añadir su sprite `16x16` en `tools/generate_assets.py` con clave `part_<id>` y regenerar/reimportar assets. Si es un nuevo instrumento activable en cabina, añadir su fila en `_sensor_rows` de [SciencePanel.gd](../src/presentation/components/SciencePanel.gd).
- **Añadir una nueva misión**: agregar una entrada `MissionSpec.new({...})` en [MissionCatalog.gd](../src/data/MissionCatalog.gd) y su configuración base opcional en `GameState.load_recommended_baseline()`. Si introduce un nuevo `target_palette`, generar `planet_<palette>.png` en `tools/generate_assets.py`.
- **Añadir una nueva ecuación física**: implementarla como método estático en [RocketMath.gd](../src/domain/services/RocketMath.gd), exponerla si hace falta en [PhysicsCalculator.gd](../src/application/PhysicsCalculator.gd) y cubrirla con aserciones en [TestRunner.gd](../tests/TestRunner.gd).
