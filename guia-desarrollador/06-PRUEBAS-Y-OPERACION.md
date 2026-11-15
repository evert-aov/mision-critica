# 06 — Pruebas y operación

[Volver al índice](README.md)

## Verificación local (Headless)

Antes de cerrar cualquier cambio en dominio, catálogos, escenas o assets, ejecutar la importación y ambas suites de pruebas:

```sh
# 1. Reimportar assets modificados (si aplica)
godot --headless --import --quit

# 2. Suite unitaria de dominio (sin SceneTree completo)
godot --headless --script res://tests/TestRunner.gd

# 3. Prueba de integración con Autoloads y pantallas UI
godot --headless res://tests/IntegrationTest.tscn
```

### Qué valida cada suite

La suite de dominio también cubre conversiones físicas de datos, escala explícita, distancias solar/radio independientes, potencia del motor y nueve vuelos automáticos (tres misiones con pasos de `1/60`, `0.1` y `0.5 s`). Comprueba que AUTO puede fallar por falta de energía y no altera el diseño.

La integración cubre el botón AUTOMÁTICO [F6], validación previa, cambio manual/automático, ayuda con pausa y reanudación, victoria desde cabina, feedback educativo y reintento en el mismo modo. La prueba de transmisión exitosa lleva batería adicional; el caso de apagón conserva una configuración sin esa batería.

La geometría visual también tiene regresiones: destino visible, crecimiento y desplazamiento continuos desde la salida (tramos 5%, 15%, 25%, 35%, 45%, 55% y 65% en las tres misiones), reducción de distancia nave-superficie, orientación de sensores hacia el destino, PRO/RET opuestos en un marco rotado, captura suficiente frente a ausencia/sobrefrenado, órbita con ciencia incompleta y ausencia de órbita en fallos. Las pruebas verifican la proporción 70/30 en varios tamaños, el Sol visible y coherente con la orientación, la Tierra alejándose, el destino creciendo y el movimiento ambiental por inercia y frenado sin cambios de recursos. La integración verifica que V mantiene la cabina y la proporción, que la ayuda pausa el ambiente y que la animación final no avanza la física. La comprobación gráfica incluye las tres misiones en separación, crucero, ciencia, aproximación y resultado, más ayudas y ensamblaje a 1920×1080 con OpenGL de software.

Los controles se verifican con `Viewport.push_input` y eventos completos de pulsación/liberación: misión 3, B, categorías, flechas, +/-; rueda en lista y cantidades, doble clic/derecho, zoom/centrado del plano, F5/F6, empuje por teclado/rueda/Shift, clic proporcional en palanca, apuntado libre, estabilización, V, C/Espacio, F3/F8, ayuda pausada, lectura por teclado y reintento R. Se comprueba que Espacio no active también un botón enfocado y que abrir ayuda libere el giro sostenido. El dominio verifica la normalización y convergencia del comando `point_attitude`.

| Suite | Archivo | Cobertura |
| --- | --- | --- |
| **Unitaria** | [tests/TestRunner.gd](../tests/TestRunner.gd) | Catálogo de 15 piezas (5 categorías) y 3 lanzadores (`lv_light`, `lv_medium`, `lv_heavy`), masas seca/húmeda, Tsiolkovski + inyección de cohete, sobrecarga de cofia/masa, TWR, irradiancia solar a `1.0 UA` y `1.52 UA`, atenuación de enlace `kbps` por $1/d^2$ y ganancia `TIERRA +90°`, evaluación integral de los 9 pilares en las 3 misiones base, estado terminal `FAILED_OBJECTIVES`, apagón `FAILED_POWER` y flujo completo de `VICTORY`. |
| **Integración** | [tests/IntegrationTest.gd](../tests/IntegrationTest.gd) | Inicialización real de `MissionData` (15 piezas + 3 lanzadores), `PhysicsCalculator`, `GameState` y `AudioManager`; instanciación de `Main.tscn`; transición `MISSION_SELECT` $\rightarrow$ `ASSEMBLY` (`mars_orbit`) con selección de cohete (`set_launch_vehicle`) y antena $\rightarrow$ `FLIGHT_COCKPIT` y quemado activo con enlace en `kbps` dentro del `SceneTree`. |

## Diagnóstico rápido

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| Caracteres `[?]` o texto cortado | Se usó un glifo fuera del mapa `FONT_5X7` o cambió `.fnt` sin reimportar | Añadir el carácter en `FONT_5X7` dentro de [generate_assets.py](../tools/generate_assets.py), ejecutar el script y correr `godot --headless --import --quit`. |
| Escena oscura en el editor | Estás en la pestaña `Game` sin presionar Play (`F5`) | Presionar `F5` para ejecutar o cambiar a la pestaña `2D` para previsualizar `@tool`. |
| Error `Identifier not found: GameState` en `--script` | El modo `--script` de `SceneTree` no inicializa Autoloads del proyecto | Los tests de `TestRunner.gd` deben probar únicamente capas puras (`domain/` y `data/` sin Autoloads); las pruebas con Autoloads van en `IntegrationTest.tscn`. |

## Exportación (Linux / Windows / WebAssembly)

El proyecto usa `gl_compatibility` para permitir exportación directa tanto a ejecutables de escritorio como a **HTML5 (WebAssembly)**:

1. En el editor de Godot, abrir **Proyecto → Exportar...** (requiere tener instaladas las *Export Templates* de Godot 4.7).
2. Agregar los presets **Linux**, **Windows Desktop** y **Web**.
3. Al exportar para **Web**, usar servidor HTTP local con cabeceras COOP/COEP o la opción *Run in Browser* del editor para pruebas rápidas.
