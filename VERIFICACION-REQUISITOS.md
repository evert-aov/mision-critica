# Verificación del reto Space Mission Design Game

Actualización: 14 de noviembre de 2026, con correcciones, ayuda educativa, modo automático, escena 2.5D y controles de teclado/mouse.

## Dictamen

El proyecto cumple el núcleo del reto como juego individual de diseño y operación de misiones. Permite elegir escenario, ensamblar una sonda y su lanzador, administrar recursos, operar el vuelo y analizar el resultado. El modo automático opera el diseño del jugador y explica sus decisiones; puede fallar por falta de recursos.

Se corrigió el caso de prueba que fallaba y se añadieron regresiones para unidades, distancias, energía y operación automática. Las simplificaciones físicas ahora se explican dentro del juego. La validación pedagógica con estudiantes sigue pendiente.

## Matriz de contraste

| Aspecto | Estado | Evidencia y alcance |
| --- | --- | --- |
| Juego interactivo de diseño y operación | Cumple | Selección, ensamblaje, cabina, resultado y reintento. |
| Participación individual | Cumple | Modos manual y automático. |
| Objetivos y evaluación | Cumple | Instrumentos y ciencia mínimos; se exige descargar los datos. |
| Objetivos propios | Parcial | Tres escenarios con requisitos preestablecidos. |
| Nave e instrumentos | Cumple | 15 componentes con masa, coste y consecuencias en consumo, ciencia y datos. |
| Lanzadores y compatibilidad | Parcial | Tres vehículos; validación de masa y cofia, inyección y delta-v. Sin selección orbital independiente ni capacidades por órbita. |
| Presupuesto y masa | Cumple | Suma de bus, lanzador y piezas; masa seca/húmeda y propelente. Sin costes operativos recurrentes. |
| Energía | Cumple en modelo simplificado | Paneles, batería, eclipses, orientación y consumo de buses, sensores, radio y motor según acelerador. |
| Datos y comunicaciones | Cumple en modelo simplificado | MB, kbps, distancia a Tierra, límite del transmisor, orientación y tasa compartida. Sin almacenamiento máximo. |
| Tiempo y vida útil | Parcial | Duración y ventanas fijas; sin planificación del desarrollo ni vida útil seleccionable. |
| Operación orbital | Cumple en modelo simplificado | TCM, asistencia gravitatoria e inserción; trayectoria por progreso temporal, sin integración orbital física. |
| Simulación y feedback | Cumple | Alertas, bitácora, puntuación, razones de fallo y recomendaciones educativas. |
| Experiencia visual de la misión | Implementada y revisada | Separación, tránsito, honda, aproximación, captura científica, inserción y órbita final con destino visible; escena 70% y cabina 30% permanentes, con Sol visible y ambiente animado. |
| Repetir y modificar | Cumple | Reensamblaje, reintento conservando el modo y selección de otra misión. |
| Escenarios/dificultad | Cumple | Tierra, Luna y Marte; dificultad ligada al escenario. |
| Aprendizaje dentro del juego | Implementado; efectividad por validar | AYUDA con pausa, unidades y escalas, tooltips de planificación, explicación de AUTO e informe QUÉ APRENDER. |
| Modo automático | Cumple | Opera comandos ordinarios, gasta recursos, respeta validación y fallos, y permite recuperar control manual. |
| Cooperación hasta cuatro participantes | No implementada; opcional | Sin sesiones, roles ni sincronización. |
| Eventos inesperados | Parcial; opcional | Eclipses y tormentas prefijados, simulación determinista. |
| Informe final | Cumple en pantalla | Métricas, causa de fallo, sugerencias y bitácora; sin exportación. |
| Guardar/compartir/comparar | No implementado; opcional | Récords de sesión en memoria. |
| Rankings, competición y sandbox | No implementados; opcionales | No existen modos específicos. |

El enunciado presenta cooperación y varias ampliaciones con “may consider”, “could” y “may (but are not required to)”. Su ausencia no invalida la propuesta individual.

## Correcciones verificadas

1. **Prueba de descarga:** el caso de transmisión exitosa incluye la batería necesaria para la secuencia de orientación y captura. La prueba de apagón conserva una nave sin esa batería, de modo que se verifican por separado éxito y agotamiento eléctrico.
2. **Unidades de datos:** `RocketMath.kbps_to_mb_per_second` divide entre 8000. La aceleración se declara con `DATA_SECONDS_PER_GAME_SECOND = 9200`; planificación expone tiempo físico y tiempo de juego. El flujo de descarga usa la misma conversión.
3. **Distancias independientes:** `MissionSpec.distance_au` representa distancia solar y `earth_distance_au` la distancia de radio. Esta última puede definirse en el escenario o derivarse del destino en km. El enlace se normaliza a 1 UA y queda limitado por el transmisor a distancias menores.
4. **Potencia de propulsión:** los motores añaden 5 W, 8 W o 60 W a plena potencia, proporcionales al acelerador y solo con motor activo. XEN-9 se identifica como un motor ficticio de juego. Se corrigió también la descripción de Banda-Ka para identificarla como radio.
5. **Ayuda educativa:** disponible en selección, ensamblaje y cabina. Explica kg, delta-v, TWR, W/Wh, MB/kbps, orientación y ventanas; pausa el vuelo y restaura la pausa previa al cerrarse.
6. **Resultado educativo:** ofrece recomendaciones diferentes para falta de energía, combustible, inserción y ciencia.
7. **Escena espacial 2.5D:** planetas procedurales con iluminación y relieve, paralaje, separación de la etapa superior, encuadres por progreso, ocultación detrás del planeta y órbita final animada. La composición por capas evita que los cuerpos queden ocultos detrás del fondo.
8. **Orientación visible:** brújula local, flecha v, dirección de la nave, giro pendiente, empuje y delta-v por frenar. En aproximación, la referencia de sensores apunta al planeta. Se explican las direcciones esquemáticas de Sol/radio. Un giro comandado con actuadores disponibles se muestra como precaución y no como pérdida crítica de control.
9. **Resultado visible:** informe inferior; una captura lograda conserva la nave orbitando al destino, y un fallo de captura muestra deriva o salida. La animación final no avanza la física ni consume recursos. V muestra/oculta ayudas sin alterar la proporción 70/30.
10. **Controles y ajuste de pantallas:** cabecera con acciones y título en filas separadas; columnas distribuidas por contenedores; nombres/descripciones ajustados; botones con atajos, estados de foco/hover/deshabilitado diferenciados. Proporción 16:9 y viewport y ventana mínima 1280×720, con ventana inicial 1920×1080 evitan deformación y descolocación al redimensionar. Selección, catálogo, vuelo, ayuda e informe admiten teclado y mouse.

## Operación automática

Desde ensamblaje: BASE [B] y AUTOMÁTICO [F6] para observar un diseño recomendado, o F6 sobre un diseño propio válido. MANUAL [F5] inicia control manual. Los botones conservan operación con clic.

Durante el vuelo: AUTO: ON/OFF o M permiten cambiar. Una orden manual de navegación, energía o ciencia recupera el control. Desactivar AUTO detiene el motor. REINTENTAR conserva el modo.

`MissionAutopilot` despliega paneles y opera orientación, buses, correcciones, capturas, descarga e inserción mediante comandos del simulador. No cambia el diseño ni concede combustible, batería o ciencia. Explica las fases en `automatic_action` y la bitácora. El simulador subdivide pasos automáticos a un máximo de 1/60 s.

## Comprobaciones ejecutadas

Motor: Godot 4.7.2 Mono.

| Verificación | Resultado |
| --- | --- |
| Suite de dominio, simulación y proyección visual | 300 correctas, 0 fallidas. |
| Integración | 89 correctas, 0 fallidas. |
| AUTO Tierra, pasos 1/60, 0.1 y 0.5 s | Victoria y 150 puntos en las tres ejecuciones. |
| AUTO Luna, pasos 1/60, 0.1 y 0.5 s | Victoria y 400 puntos en las tres ejecuciones. |
| AUTO Marte, pasos 1/60, 0.1 y 0.5 s | Victoria y 600 puntos en las tres ejecuciones. |
| AUTO sin energía suficiente | FAILED_POWER, sin victoria artificial. |
| Unidades, potencia y distancias | Conversión decimal, escala explícita, independencia solar/radio y consumo al disparar verificados. |
| Flujo de interfaz | Lanzamiento AUTO, validación, cambio manual, ayuda con pausa, victoria desde cabina, informe y reintento verificados. |
| Proyección y orientación | Destino visible, crecimiento y desplazamiento continuos del 5% al 65% del viaje en las tres misiones, Tierra alejándose, dirección de sensores, PRO/RET opuestos al cambiar el marco, captura suficiente frente a ausencia/sobrefrenado y resultados de misión verificados. |
| Escena e informe | Proporción 70/30 constante, controles visibles, ayudas opcionales y órbita final animada sin avanzar la simulación verificados en integración. |
| Teclado y mouse reales | Eventos completos mediante Viewport.push_input: atajos, cantidades, clics y ruedas contextuales, palanca, apuntado libre, ayuda pausada y reintento. Se verifica que una entrada no active también un botón enfocado ni deje giro sostenido tras abrir ayuda. |
| Ajuste de la interfaz | Cabecera y cuerpo sin intersección, título contenido y capturas a 960×540, 1280×720 y 1280×800. |
| Inspección visual renderizada | Tierra, Luna y Marte capturados en separación, crucero, ciencia, aproximación y resultado a 1920×1080; también ensamblaje, ayudas y fotogramas de ambiente en movimiento, con OpenGL de software. Sin errores de scripts ni shader. |

Logs locales: `/tmp/mision-critica-unit.log` y `/tmp/mision-critica-integration.log`. Las pruebas están incorporadas en `tests/`, sin depender del diagnóstico temporal de la revisión inicial.

Capturas de la última revisión: `/tmp/mision-leo_tutorial-100.png`, `/tmp/mision-lunar_flyby-100.png`, `/tmp/mision-mars_orbit-100.png`, `/tmp/mision-mars_orbit-82.png`, `/tmp/mision-cockpit-controls.png` y `/tmp/mision-failed-power.png`. El resto usa el patrón `/tmp/mision-<mission_id>-<porcentaje>.png`. La prueba gráfica produjo avisos del entorno sobre V-Sync y D-Bus, sin errores de scripts ni shader en su ejecución final.

Revisión posterior de controles/layout: `/tmp/ui-assembly-leo.png`, `/tmp/ui-assembly-mars.png`, `/tmp/ui-missions.png`, `/tmp/ui-catalog-3.png`, `/tmp/ui-cockpit.png`, `/tmp/ui-help.png`, `/tmp/ui-result.png`, `/tmp/ui-assembly-960x540.png` y `/tmp/ui-assembly-1280x800.png`.

## Límites del modelo

Las distancias son aproximaciones fijas por escenario. La trayectoria, asistencias y motores son modelos de juego. Las escalas son independientes: empuje x45, electricidad 0.06 horas por segundo de juego y datos x9200. No existe un único reloj físico consistente ni se usan especificaciones certificadas de lanzadores reales.

El 2.5D usa esferas sombreadas en canvas, perspectiva y composición de capas, conservando el motor 2D. La línea de predicción ilustra el frenado/desvío del modelo; no es una integración de cónicas orbitales. Los marcadores Sol/Tierra son referencias locales de operación, no coordenadas astronómicas. La presentación no modifica el estado físico para fabricar una victoria.

Las pruebas demuestran secuencias ganadoras para los diseños base y regresiones concretas; no prueban todos los diseños ni la comprensión de estudiantes. Las posibles ampliaciones de órbitas elegibles, vida útil, cooperación y persistencia quedan fuera de esta actualización.
