# 04 — Interfaz pixel art y cabina

[Volver al índice](README.md)

## Sistema visual y assets (`ThemeFactory` y `generate_assets.py`)

El aspecto retro unificado se apoya en dos piezas centrales:

1. **Generador determinista** ([tools/generate_assets.py](../tools/generate_assets.py)):
   Produce sin dependencias externas todos los recursos en `assets/`:
   - `assets/sprites/ui/`: paneles `NinePatchRect` (`panel_metal.png`, `panel_crt.png`) y botones (`btn_normal/hover/pressed/disabled.png`).
   - `assets/sprites/cockpit/`: interruptores `toggle_{on,off}_{normal,hover,pressed}.png`, tapa abatible `cover_{open,closed}_{normal,hover}.png`, ignición, botón de despliegue, sensores y hojas de animación (`led_*_sheet.png`, `radar_sheet.png`, `spark_sheet.png`).
   - `assets/sprites/parts/` y `assets/sprites/space/`: bus central, 15 iconos de piezas (incluyendo antenas Banda-X/Ka), 3 lanzadores (`lv_light/medium/heavy`) y 3 cuerpos celestes `64x64`. Con respaldo procedural en memoria (`ThemeFactory.get_catalog_icon(...)`) si algún PNG aún no ha sido regenerado.
   - `assets/fonts/`: fuentes bitmap AngelCode crisp `pixel_ui.fnt` (`14px`) para interfaz principal + `pixel_5x7.fnt` (`8px`) para instrumentos compactos, con soporte completo ASCII + español (`ÁÉÍÓÚÑáéíóúñ¡¿°Δ±`).
   - `assets/audio/*.wav`: sonidos chiptune (`22050 Hz`, PCM 16-bit mono), incluyendo bucles y avisos de vuelo (`turbo`, `brake`, `cruise_hum`, `retro_hum`).

2. **Fábrica de tema** ([ThemeFactory.gd](../src/presentation/theme/ThemeFactory.gd)):
   Construye y cachea el `Theme` global (`default_font = pixel_ui.fnt` a `14px` o fallback `2x` sobre `pixel_5x7.fnt`), conserva `get_compact_theme()` a `8px` (`1:1`), genera en memoria los íconos faltantes (`get_catalog_icon(key)`), define barras de desplazamiento `VScrollBar` retro de `6 px` para terminales CRT, ajusta márgenes `StyleBoxTexture` compactos y provee `make_sprite_frames(...)`.

3. **Renderizador unificado de sonda** ([ProbeVisualRenderer.gd](../src/presentation/components/ProbeVisualRenderer.gd)):
   Dibuja el `ProbeDesign` exacto ensamblado por el jugador (bus octogonal MLI dorado, antena parabólica diferenciada para Banda-S/X/Ka, tanques, motores, alas fotovoltaicas, baterías e instrumentos) tanto en orientación vertical CAD dentro del envolvente de cofia (`ProbeBlueprintView`) como en rotación 360° en vuelo (`ViewportWindow`).

## Pantallas principales (`src/presentation/screens/`)

Todas las pantallas y widgets usan `@tool` con guardas `Engine.is_editor_hint()` para renderizarse también en la pestaña **2D** del editor de Godot, y emplean contenedores con `clip_contents = true` y `ScrollContainer` en todas las terminales de texto para evitar desbordes:

- **`Main.tscn` / [Main.gd](../src/presentation/screens/Main.gd)**: Enrutador raíz que escucha `GameState.phase_changed`, instancia la pantalla activa y fija el color de fondo `RenderingServer.set_default_clear_color(ThemeFactory.COL_BG)`. (`MISSION_RESULT` no reemplaza la escena porque `CockpitScreen` muestra el informe en la franja inferior).
- **`MissionSelectScreen.tscn` / [MissionSelectScreen.gd](../src/presentation/screens/MissionSelectScreen.gd)**: Fondo estelar, cabecera con selector de perfil sin contraseña (`PILOTO: @username [U]`), botón de silencio (`AudioManager`), 3 tarjetas de misión con globos `PlanetBodyView` animados en vivo, `ScrollContainer` para briefings con análogo NASA, récords con `CML`/insignias y botón `CARGAR` cuando existe un diseño victorioso guardado.
- **`AssemblyScreen.tscn` / [AssemblyScreen.gd](../src/presentation/screens/AssemblyScreen.gd)**:
  - `MarginContainer` y `VBoxContainer` separan acciones, título de misión, cuerpo y ayuda de controles. El `HBoxContainer` del cuerpo reparte catálogo, plano y balance con proporciones 1.12/1/1.08.
  - Catálogo: 6 pestañas (1-6), tarjetas seleccionables con nombres y descripción ajustados, flechas para elegir y +/- para cantidad. `ScrollContainer` mantiene visible el elemento seleccionado. Rueda en lista desplaza y sobre +/- ajusta cantidades; doble clic equipa y derecho quita.
  - Plano: `ProbeBlueprintView` conserva el contorno de cofia y alertas; rueda controla zoom, arrastre desplaza la nave y clic central centra.
  - Balance: indicadores (incluyendo resumen en vivo `NASA CML | M | P | RF`), terminal desplazable y botones MANUAL [F5]/AUTOMÁTICO [F6]. NASA CML [N], AYUDA [F1], ES/EN [F2], BASE [B], LIMPIAR [L] y MISIONES [Esc] quedan en la fila de acciones. `[N]` abre un modal con el informe completo JPL CML / 4 Segmentos / CubeSat 101 y el generador/exportador de `.script` para NASA GMAT R2026a (`user://gmat_<id>.script`).
- **`CockpitScreen.tscn` / [CockpitScreen.gd](../src/presentation/screens/CockpitScreen.gd)**:
  `FlightLayout.calculate` reparte la altura útil en 70% de escena y 30% de cabina, con márgenes de 8 px y separación de 6 px. En 1280×720, la escena mide 1264×488 y la cabina 1264×210. `set_guidance_visible(bool)` y `V` muestran/ocultan ayudas y `set_internal_view(bool)` / `K` (`VISTA: EXT/INT [K]`) alternan entre vista espacial externa y vista interna por modelo (`InternalCabinRenderer`, incluyendo audio filtrado `AudioManager.set_internal_audio_mode` y SFX para tapa, ventana de inserción y separación de cofia) sin cambiar esa composición. La cabina usa un HBox con resumen, energía, navegación, ciencia y acciones; los instrumentos conservan fuente compacta de 8 px. Inyecta `sim.design`, actualiza `sim.step(delta)` y modula audio. Tras finalizar, solo avanza la animación visual, no la simulación.

## Componentes de cabina (`src/presentation/components/`)

| Componente | Archivo | Elementos Godot clave |
| --- | --- | --- |
| `InternalCabinRenderer` | [InternalCabinRenderer.gd](../src/presentation/components/InternalCabinRenderer.gd) | Dibuja interiores diferenciados según el `ProbeDesign` armado (`compact`, `explorer`, `deep_space`), monitores laterales vivos y piezas externas visibles desde el ventanal (paneles, HGA, sensores). |
| `ProbeVisualRenderer` | [ProbeVisualRenderer.gd](../src/presentation/components/ProbeVisualRenderer.gd) | Renderizado procedural pixel-art de `ProbeDesign` en vista vertical (ensamblaje) y horizontal (vuelo con despliegue solar y pluma de motor). |
| `ViewportWindow` | [ViewportWindow.gd](../src/presentation/components/ViewportWindow.gd) | HUD adaptable, cronómetro, etapas, explicaciones, alertas y escena `MissionSpaceView`. |
| `FlightLayout` | [FlightLayout.gd](../src/presentation/components/FlightLayout.gd) | Distribución proporcional 70/30 de escena y cabina. |
| `SpaceEnvironment` | [SpaceEnvironment.gd](../src/presentation/components/SpaceEnvironment.gd) | Partículas, rocas y satélites decorativos con paralaje e inercia visual. |
| `MissionSpaceView` | [MissionSpaceView.gd](../src/presentation/components/MissionSpaceView.gd) | Paralaje, composición por capas, etapa superior, órbitas delante/detrás de planetas, sonda ensamblada, referencias locales y predicción. |
| `MissionSceneProjection` | [MissionSceneProjection.gd](../src/presentation/components/MissionSceneProjection.gd) | Geometría de presentación determinista: cámara, destino, etapa, resultado de captura y posición orbital proyectada. No integra física. |
| `PlanetBodyView` | [PlanetBodyView.gd](../src/presentation/components/PlanetBodyView.gd) | Esfera procedural mediante `planet_sphere.gdshader`: Tierra, Luna, Marte, Venus y Sol emisivo con corona; iluminación cuantizada, relieve, atmósfera y rotación superficial. |
| `PowerPanel` | [PowerPanel.gd](../src/presentation/components/PowerPanel.gd) | Sub-paneles CRT empotrados con 3 `TextureButton` de buses, 4 `AnimatedSprite2D` LEDs, `_BatteryDial` analógico (`E`–`F`) y despliegue solar. |
| `NavigationConsole` | [NavigationConsole.gd](../src/presentation/components/NavigationConsole.gd) | `_CRTDisplay` con corredor verde de $\Delta v$, terminal de bitácora con `ScrollContainer` auto-desplazable, palanca `_ThrottleLever` y botón de ignición con tapa abatible. |
| `SciencePanel` | [SciencePanel.gd](../src/presentation/components/SciencePanel.gd) | Radar `AnimatedSprite2D`, terminal CRT con `ScrollContainer` que aloja los 3 sensores (`TextureButton` + `ProgressBar`) y el registro de paquetes capturados/transmitidos. |
| `MissionResultOverlay` | [MissionResultOverlay.gd](../src/presentation/components/MissionResultOverlay.gd) | Informe ajustado al 30% inferior, con bitácora desplazable, sección de referencia NASA (`CML`, `ODAR EOL` y misión análoga) y botones REPETIR, DISEÑO y MENÚ; deja visible el destino. |

## Composición 2.5D y resultados

La esfera se dibuja mediante un shader de canvas sobre `ColorRect`, con máscara transparente, normales de esfera, ruido de superficie, luz cuantizada y píxeles explícitos. No necesita PNG nuevos. La estrella de fondo, planetas y primer plano usan orden explícito sin índices z negativos que puedan quedar detrás del fondo de la cabina.

`MissionSceneProjection.sample` distingue separación, tránsito, honda, ciencia, inserción y resultado. En el tramo de llegada, OBJ -35° se representa hacia el planeta dentro del marco simplificado; tras captura, la tangente de la elipse proyectada define v. PRO/RET permanecen opuestos aunque cambie el encuadre. Sol y Tierra/radio se rotulan como referencias locales, no coordenadas astronómicas. La escena suaviza cambios de encuadre y adapta la escala de nave y cuerpos a la densidad del viewport. El Sol permanece visible en la dirección de referencia solar; su radio usa la distancia solar del escenario. La iluminación de las esferas apunta hacia ese Sol. El progreso visual usa todo el tránsito hasta el comienzo de la inserción: q=progreso/inicio_inserción y aproximación=0.70q+0.30q². La componente lineal hace visibles desde el comienzo tanto el crecimiento y desplazamiento del destino como la reducción de la distancia nave-superficie. La Tierra de partida se aleja y reduce durante todo el tránsito. LEO también cambia el tamaño y encuadre de la Tierra; los rótulos de fase siguen siendo independientes de la curva de cámara.

`SpaceEnvironment` añade 48 partículas y 8 objetos decorativos con profundidades distintas, incluyendo satélites en LEO. Mantiene movimiento durante el crucero por inercia, lo incrementa al impulsar y lo reduce al frenar. No modifica telemetría, colisiones ni recursos; dt=0 y la pausa de ayuda detienen el ambiente.

El estado VICTORY anima una órbita verde, FAILED_OBJECTIVES conserva la órbita en ámbar, y los fallos de captura/energía/combustible no muestran éxito orbital. En vuelo, el criterio visual de captura verifica el corredor de frenado y el desvío; no cambia la evaluación del simulador. `ending_time` solo mueve la escena después del resultado. El resultado visual centra el planeta sobre el informe inferior.

## Entrada y foco

`ThemeFactory.bind_shortcut` usa `Shortcut` nativo en botones de navegación y lanzamiento. Los botones tienen bordes y estados diferenciados, con foco ámbar, hover cian, pulsado verde y deshabilitado atenuado. El tamaño de fuente global de Label/Button se fija explícitamente a 9; los instrumentos compactos usan 8. El viewport interno es 1280×720 y la ventana inicial 1920×1080, reduciendo el tamaño aparente de las letras respecto al antiguo viewport de 640×360. Los textos ajustados por líneas no usan `clip_text`, que puede anular su altura mínima; sus contenedores delimitan el área.

El vuelo procesa sus teclas en `_input` para que Espacio o las flechas no activen además un botón enfocado. Tab/Intro conservan la navegación de UI. La escena recibe `_gui_input`: clic orienta mediante `point_attitude`, derecho estabiliza, central muestra/oculta ayudas y rueda ajusta empuje (Shift para precisión). La palanca consume sus propios eventos de rueda/clic/arrastre. Listas e informes retienen el desplazamiento nativo.

`FlightTelemetry.AttitudeMode.POINT` permite apuntado libre con los mismos actuadores y recursos que los modos predefinidos. La dirección del puntero se transforma al marco local de la escena. Abrir ayuda o perder el foco de ventana libera el giro sostenido. La guía procesa lectura por teclado aun con el árbol pausado. El informe usa R/D/Esc.

La ventana mantiene relación 16:9 y un mínimo de 1280×720; se preserva la composición pixel art a distintos tamaños y aparecen márgenes si la proporción de ventana difiere. El enrutador retira la pantalla anterior del árbol antes de liberar sus nodos, evitando atajos activos de vistas ya abandonadas.
