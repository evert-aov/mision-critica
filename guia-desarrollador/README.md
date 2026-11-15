# Guía del desarrollador — Misión Crítica (Godot 4.7 GDScript)

**Misión Crítica** es un simulador espacial 2D en estilo pixel art (`1280x720` internos, ventana `1920x1080`) construido sobre Godot 4.7 con separación estricta en capas (**Clean Architecture**): el dominio matemático y físico (`src/domain/`) no depende del `SceneTree` ni de nodos visuales; los catálogos viven en `src/data/`; la coordinación de estado y audio vive en `src/application/`; y las pantallas y widgets retro residen en `src/presentation/`.

## Contenido

| Capítulo | Tema |
| --- | --- |
| [00 — Arquitectura y configuración](00-ARQUITECTURA-Y-CONFIGURACION.md) | Capas, regla de dependencias, ajustes pixel art en `project.godot` y Autoloads. |
| [01 — Dominio y motor matemático](01-DOMINIO-Y-MOTOR-MATEMATICO.md) | Entidades puras, ecuación de Tsiolkovski, irradiancia solar y validación pre-vuelo. |
| [02 — Simulador de vuelo](02-SIMULADOR-DE-VUELO.md) | Bucle `step(dt)`, quemado de combustible, buses eléctricos, ventanas y condiciones finales. |
| [03 — Catálogos y misiones](03-CATALOGOS-Y-MISIONES.md) | `PartCatalog`, `MissionCatalog`, `MissionData` y máquina de fases `GameState`. |
| [04 — Interfaz pixel art y cabina](04-INTERFAZ-PIXEL-ART-Y-CABINA.md) | `ThemeFactory`, generador de assets, soporte `@tool`, pantallas y componentes de cabina. |
| [05 — Directorios y flujos](05-MAPA-DE-DIRECTORIOS-Y-FLUJOS.md) | Mapa del repositorio, flujo entre pantallas y criterios de extensión. |
| [06 — Pruebas y operación](06-PRUEBAS-Y-OPERACION.md) | Suites headless (`TestRunner` / `IntegrationTest`), importación y exportación. |

## Inicio rápido

Desde la raíz del proyecto (`project.godot`):

```sh
# Importar recursos (necesario tras regenerar sprites, fuentes o audio)
godot --headless --import --quit

# Abrir o ejecutar el proyecto
godot --path .
```

La escena principal configurada en `project.godot` es `res://src/presentation/screens/Main.tscn`.

## Verificación

```sh
godot --headless --script res://tests/TestRunner.gd
godot --headless res://tests/IntegrationTest.tscn
```

Ejecutar ambas suites tras modificar reglas de dominio, catálogos, escenas o el generador de assets. No usar resultados históricos; reportar conteos exactos de la última ejecución.

## Reglas de contribución

- **Aislamiento de dominio**: `src/domain/` no debe importar nodos de `Control`/`Node2D` ni invocar Autoloads (`GameState`, `MissionData`, `AudioManager`).
- **Alineación pixel art**: mantener dimensiones enteras, filtro `Nearest` y evitar coordenadas fraccionarias al dibujar primitivas en `_draw()`.
- **Previsualización `@tool`**: cualquier pantalla o componente nuevo que construya UI en `_ready()` debe proteger el acceso a Autoloads con `Engine.is_editor_hint()`.
- **Código e identificadores**: nombres de clases, métodos y variables en inglés; textos visibles al jugador, docstrings clave y documentación en español.
- **Documentación sincronizada**: actualizar el capítulo correspondiente de `guia-desarrollador/` cuando cambien contratos, ecuaciones o pantallas.

Ver también el [README principal](../README.md) y la [Guía del Juego y Objetivos](../GUIA-JUEGO-Y-OBJETIVOS.md).
