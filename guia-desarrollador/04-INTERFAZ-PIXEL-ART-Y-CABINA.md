# 04 — Interfaz pixel art y cabina

[Volver al índice](README.md)

## Sistema visual y assets (`ThemeFactory` y `generate_assets.py`)

El aspecto retro unificado se apoya en dos piezas centrales:

1. **Generador determinista** ([tools/generate_assets.py](../tools/generate_assets.py)):
   Produce sin dependencias externas todos los recursos en `assets/`:
   - `assets/sprites/ui/`: paneles `NinePatchRect` (`panel_metal.png`, `panel_crt.png`) y botones (`btn_normal/hover/pressed/disabled.png`).
   - `assets/sprites/cockpit/`: interruptores `toggle_{on,off}_{normal,hover,pressed}.png`, tapa abatible `cover_{open,closed}_{normal,hover}.png`, ignición, botón de despliegue, sensores y hojas de animación (`led_*_sheet.png`, `radar_sheet.png`, `spark_sheet.png`).
   - `assets/sprites/parts/` y `assets/sprites/space/`: bus central, 13 iconos de piezas y 3 cuerpos celestes `64x64` (`earth`, `moon`, `mars`).
   - `assets/fonts/pixel_5x7.fnt` + `pixel_5x7.png`: fuente bitmap AngelCode `5x7` (`lineHeight=8`, `xadvance=6`) con soporte completo ASCII + español (`ÁÉÍÓÚÑáéíóúñ¡¿°Δ±`).
   - `assets/audio/*.wav`: 9 sonidos chiptune (`22050 Hz`, PCM 16-bit mono).

2. **Fábrica de tema** ([ThemeFactory.gd](../src/presentation/theme/ThemeFactory.gd)):
   Construye y cachea el `Theme` global (`default_font = pixel_5x7.fnt`, `default_font_size = 8`), ajusta márgenes `StyleBoxTexture` compactos para botones de `18–20 px` de alto y provee `make_sprite_frames(...)` para dividir spritesheets horizontales en `AtlasTexture`.

## Pantallas principales (`src/presentation/screens/`)

Todas las pantallas y widgets usan `@tool` con guardas `Engine.is_editor_hint()` para renderizarse también en la pestaña **2D** del editor de Godot:

- **`Main.tscn` / [Main.gd](../src/presentation/screens/Main.gd)**: Enrutador raíz que escucha `GameState.phase_changed`, instancia la pantalla activa y fija el color de fondo `RenderingServer.set_default_clear_color(ThemeFactory.COL_BG)`. (`MISSION_RESULT` no reemplaza la escena porque `CockpitScreen` muestra el modal encima).
- **`MissionSelectScreen.tscn` / [MissionSelectScreen.gd](../src/presentation/screens/MissionSelectScreen.gd)**: Cabecera con botón de silencio (`AudioManager`), 3 tarjetas de misión y récords científicos.
- **`AssemblyScreen.tscn` / [AssemblyScreen.gd](../src/presentation/screens/AssemblyScreen.gd)**:
  - Izquierda (`224x320`): pestañas de categoría + `ScrollContainer` de piezas con botones `-`/`+`.
  - Centro (`206x320`): `ProbeBlueprintView` sobre marco CRT (`182x260`) que dibuja bus, tanques apilados, motores, paneles laterales, baterías e instrumentos.
  - Derecha (`194x320`): telemetría en `VBoxContainer` (`PRESUP`, `MASA`, `Δv DISP`, `TWR`, `ENER/BATERÍA`, `CIENCIA MÁXIMA`), `ScrollContainer` de validación y botón `LANZAR SONDA >>`.
- **`CockpitScreen.tscn` / [CockpitScreen.gd](../src/presentation/screens/CockpitScreen.gd)**:
  Coordina los 4 cuadrantes sobre `640x360`, actualiza `sim.step(delta)`, modula `AudioManager` y aplica sacudida discreta de píxeles en `Camera2D` proporcional a `throttle` mientras `engine_firing` está activo.

## Componentes de cabina (`src/presentation/components/`)

| Componente | Archivo | Elementos Godot clave |
| --- | --- | --- |
| `ViewportWindow` | [ViewportWindow.gd](../src/presentation/components/ViewportWindow.gd) | 3 capas de estrellas paralaje (`_draw()`), `Sprite2D` del planeta objetivo, `CPUParticles2D` de escape, `AnimatedSprite2D` de chispas y `ColorRect` para eclipses/tormentas. |
| `PowerPanel` | [PowerPanel.gd](../src/presentation/components/PowerPanel.gd) | 3 `TextureButton` de buses, 4 `AnimatedSprite2D` LEDs, subcontrol `_BatteryDial` analógico y botón `TextureButton` de despliegue solar. |
| `NavigationConsole` | [NavigationConsole.gd](../src/presentation/components/NavigationConsole.gd) | Subcontrol `_CRTDisplay` con corredor verde de $\Delta v$, palanca interactiva `_ThrottleLever` (arrastre + presets `0%`, `50%`, `100%`), tapa de seguridad superpuesta y botón de ignición. |
| `SciencePanel` | [SciencePanel.gd](../src/presentation/components/SciencePanel.gd) | Radar `AnimatedSprite2D`, LED de ventana óptima, 3 botones `TextureButton` de sensores y `ProgressBar` de transmisión. |
| `MissionResultOverlay` | [MissionResultOverlay.gd](../src/presentation/components/MissionResultOverlay.gd) | Modal centrado sobre `CockpitScreen` con reporte final y botones `REINTENTAR`, `ENSAMBLAJE` y `MISIONES`. |
