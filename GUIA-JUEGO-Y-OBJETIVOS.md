# Guía del Juego y Objetivos — Misión Crítica

**Misión Crítica** es un simulador de ingeniería espacial y operación de sondas con escena 2.5D pixel art (`1280x720` internos, ventana `1920x1080`). Exige analizar y equilibrar **las 9 exigencias contrapuestas del diseño espacial** desde el escritorio de integración hasta el control en cabina.

## Empezar y aprender con el piloto automático

1. Crea tu perfil de comandante **sin contraseña** (solo nombre y username) o elige un piloto guardado con **`U`**; tus avances, nivel `CML`, insignias NASA y último diseño victorioso se guardan automáticamente en `user://profiles.json`.
2. Elige Tierra, Luna o Marte (o pulsa **CARGAR** si ya tienes una sonda victoriosa guardada para esa misión).
3. Pulsa **BASE [B]** para cargar un diseño recomendado o ensambla el tuyo.
4. Pulsa **AUTOMÁTICO [F6]** para observar cómo se opera ese diseño. **MANUAL [F5]** permite pilotarlo desde el principio (y concede la insignia **`PILOTO MANUAL`** al vencer sin piloto automático).
5. La línea **AUTO** y la bitácora explican por qué se orienta la nave, se enciende el motor o se apagan buses. El piloto despliega paneles, corrige trayectoria, captura ciencia en su ventana, transmite e inserta en órbita.
6. Pulsa **AUTO: ON** o **M** para recuperar el control. El motor se detiene. Una orden manual de navegación, energía o ciencia también desactiva el piloto; puedes reactivarlo con el botón o **M**.

**AUTO opera los recursos de tu diseño:** no añade combustible, batería o instrumentos. Puedes perder si tu diseño no cubre las necesidades. **REINTENTAR** conserva el modo elegido y reinicia el vuelo.

**AYUDA**, disponible en las tres pantallas, pausa la partida y abre explicaciones para principiantes. Ciérrala con el botón o **Esc**. El informe final incluye **QUÉ APRENDER**, con sugerencias relacionadas con el resultado.

## Controles de teclado y mouse

Los botones indican sus atajos. **Tab** cambia el foco, el borde ámbar muestra el botón enfocado e **Intro** lo activa. **F1** abre la ayuda en cualquier pantalla; la ayuda admite rueda, flechas, RePág/AvPág e Inicio/Fin y se cierra con Esc o F1.

| Pantalla / acción | Teclado | Mouse |
| --- | --- | --- |
| Elegir misión / perfil sin contraseña | 1, 2 o 3 / U | Clic en DISEÑAR, CARGAR o PILOTO |
| Categoría de equipos | 1-6 o izquierda/derecha | Clic en pestaña |
| Seleccionar equipo | Arriba/abajo | Clic en tarjeta |
| Añadir/quitar | + / - | Botones +/-, doble clic añade, derecho quita; rueda sobre +/- cambia cantidad |
| Leer catálogo e informes | Flechas para elegir equipo; rueda o teclas de lectura en ayuda | Rueda desplaza el contenido |
| Diseño base / limpiar / volver | B / L / Esc | Botones de cabecera |
| Idioma ES / EN | F2 (en selección y ensamblaje) | Botón `ES / EN` |
| Informe NASA CML / Script GMAT | N (en ensamblaje) | Botón `NASA CML [N]` + EXPORTAR `.script` |
| Lanzar manual / automático | F5 / F6 | Botones MANUAL / AUTOMÁTICO |
| Inspeccionar plano | — | Rueda zoom, arrastrar mueve, clic central centra |
| Girar / orientar | A/D o izquierda/derecha; 1-5 orientaciones | Clic en escena apunta hacia el puntero; botones de orientación en cabina |
| Estabilizar | S | Derecho en escena o botón ESTAB |
| Empuje | W/Q o arriba/abajo: 10%; X: cero | Rueda en escena o palanca: 5%, Shift+rueda: 1%; clic/arrastre en palanca; derecho en palanca: cero |
| Tapa / motor | C / Espacio | Clic en tapa / ignición |
| Paneles / RCS | P / R | Botones de cabina |
| Buses maestro / radio / ciencia | F2 / F3 / F4 | Interruptores de cabina |
| Cámara / espectrómetro / radar | F7 / F8 / F9 | Botones de sensores |
| AUTO / ayudas visuales / vista interna | M / V / K | Botones `AUTO`, `AYUDAS`, `VISTA: EXT/INT`; clic central oculta ayudas |
| Resultado: repetir / diseño / menú | R / D / Esc | Botones del informe |

Las acciones manuales recuperan el control si AUTO está activo. La rueda actúa según el área señalada: sobre listas desplaza, sobre cantidades ajusta equipos y sobre la escena o palanca cambia empuje. No activa dos acciones simultáneas.

La interfaz conserva la proporción 16:9 para que redimensionar la ventana no estire ni descoloque los paneles. Los títulos y descripciones se distribuyen con contenedores y se ajustan por líneas; los listados largos usan desplazamiento.

## Vista espacial 2.5D y orientación visible

El vuelo reserva el **70% superior para la escena** y el **30% inferior para la cabina**. Energía, navegación y ciencia permanecen visibles en manual y automático. **`K`** (o botón **`VISTA: EXT/INT [K]`**) alterna entre la vista externa con pulsos animados de avance sobre la trayectoria y una **vista interna en primera persona** adaptada al modelo real de tu nave (*Cúpula Compacta* para CubeSat/Vega-C, *Bahía Exploradora* para Ariane-62 y *Puente Espacio Profundo* para Vulcan/XEN-9), donde ves asomar tus paneles solares, antena HGA (`Banda-X`/`Ka`) y sensores por el ventanal, separación de cofia al despegue, chorros blancos RCS al rotar, interferencia eléctrica en los monitores durante tormentas solares y sonido filtrado dentro de la cabina (además de avisos dedicados para tapa, ventana de inserción y separación), junto al flujo 3D radial de partículas, el paneo al girar y los arcos de trayectoria hacia el destino. **V**, **AYUDAS [V]** o clic central muestra/oculta las ayudas visuales sin modificar la proporción. El informe final sustituye los controles en la franja inferior.

Las partículas y objetos decorativos muestran avance por inercia aun con el motor apagado, con paralaje y menor movimiento al frenar. Desde la salida, la Tierra se reduce y queda atrás mientras el destino crece y cambia de posición de forma continua durante el crucero; el acercamiento se acentúa antes de la inserción. En LEO, también cambia el encuadre de la Tierra durante todo el arco. El Sol queda visible e ilumina las superficies; su tamaño responde a la distancia solar del escenario. Las escalas están comprimidas y los objetos ambientales no tienen colisiones ni consumen recursos.

La escena cambia según el progreso: separación de la etapa superior, tránsito, honda, aproximación, sobrevuelo científico, frenado e inserción. Tierra muestra océanos y nubes, Luna cráteres, Marte relieve rojizo y polos; Venus tiene su propio aspecto durante la asistencia marciana. Los planetas se iluminan como esferas y las órbitas tienen perspectiva y ocultación de la nave al pasar por detrás.

- **Flecha azul `v`:** dirección de movimiento; define progrado, `0°` en el marco local.
- **Flecha blanca:** orientación actual de la nave.
- **Flecha/arco ámbar:** giro solicitado o empuje del motor. `RET 180°` produce empuje opuesto a `v`, frenando para la captura.
- **Brújula local:** referencias PRO, RET, SOL, TIERRA y OBJ. Durante la aproximación, OBJ `-35°` se representa hacia el destino.
- **Predicción ámbar:** trayectoria aproximada de llegada, modificada por el frenado y desvío. El empuje incorrecto y las salidas fallidas se señalan en rojo.
- **POR FRENAR:** delta-v de inserción que falta; no representa una velocidad orbital absoluta.
- **Zona de observación:** resalta el área del planeta al apuntar los sensores; la captura queda destacada durante unos segundos.

Las direcciones Sol/radio son referencias locales esquemáticas del modelo, y la cámara comprime las distancias. Una rotación controlada aparece como precaución mientras se completa; no implica por sí sola pérdida de control.

Al terminar, el informe ocupa el 30% inferior y la escena permanece en el 70% superior. La nave sigue orbitando el destino si logró la captura; si falta ciencia la órbita se muestra en ámbar. Una aproximación fallida muestra salida o deriva, sin inventar una órbita. La animación final no continúa gastando combustible ni modifica el resultado.

## Unidades y simplificaciones

| Concepto | Cómo interpretarlo |
| --- | --- |
| kg | Masa de nave, equipos y propelente. Más masa exige más recursos para la misma maniobra. |
| Delta-v, m/s | Capacidad de cambiar velocidad; no es la velocidad actual de la sonda. |
| W y Wh | W es potencia instantánea; Wh es energía almacenada. 10 W durante una hora consumen 10 Wh. |
| Radio, kbps y MB | `1 MB = 8000 kilobits`; la tasa se comparte entre los paquetes pendientes. |
| Distancias en UA | La distancia al Sol controla los paneles; la distancia a Tierra controla el enlace. Son valores independientes y fijos del escenario. |
| Motor | Consume electricidad mientras dispara: R-4D 5 W, Aestus II 8 W, XEN-9 60 W, proporcionales al acelerador. |

El tiempo visible es **tiempo de juego** (`J+`). Las escalas son independientes: empuje `x45`, balance eléctrico `0.06 horas por segundo de juego` y descarga `x9200`. Por ejemplo, `32 MB / 18 kbps` requieren unos `14222 s` físicos y `1.55 s` de juego con enlace óptimo. El tooltip de comunicaciones muestra ambos tiempos, y el de energía compara consumo en crucero y con motor.

El catálogo y las maniobras están simplificados y balanceados para partidas cortas. Los nombres de vehículos no implican especificaciones reales; XEN-9 es un motor ficticio del juego.

---

## Las 9 exigencias contrapuestas (Fase de Ensamblaje)

En la pantalla de ensamblaje cada mejora tiene un costo en otro subsistema:

1. **Objetivos de la misión**: cada misión impone un mínimo científico obligatorio y sensores requeridos (marcados con `*`). Alcanzar la órbita sin capturar ni descargar los objetivos produce `OBJETIVOS NO LOGRADOS`.
2. **Diseño de la nave espacial**: la cofia del cohete limita cuántos módulos caben (`COF: X/Y`); el plano CAD central muestra el envolvente de la cofia en rojo si se excede.
3. **Instrumentos científicos**: la Cámara (`32 MB`, `14 W`, `150 pts`), el Espectrómetro IR (`54 MB`, `22 W`, `250 pts`) y el Radar SAR (`90 MB`, `32 W`, `350 pts`) aumentan ciencia pero también masa, consumo eléctrico y volumen de descarga.
4. **Vehículos de lanzamiento (`COH`)**:
   - **Vega-C Ligero** (`$18,000`): carga máx. `420 kg`, cofia `6` módulos, `+0 m/s` inyección, dispersión inicial `22 km`.
   - **Ariane-62 Medio** (`$36,000`): carga máx. `820 kg`, cofia `9` módulos, `+300 m/s` inyección, dispersión `14 km`.
   - **Vulcan-Centaur Pesado** (`$58,000`): carga máx. `1,500 kg`, cofia `13` módulos, `+650 m/s` etapa Centaur, dispersión `8 km`.
5. **Presupuestos**: cohete + bus base (`$15,000`) + propulsión + tanques + energía + antenas + sensores deben caber en el presupuesto de la misión.
6. **Energía**: la irradiancia solar cae con la distancia al Sol al cuadrado (a `1.52 UA` rinde el `43%`). Equilibra paneles y reserva en Wh con el consumo de buses, ruedas, antenas y motor durante eclipses y maniobras.
7. **Masa**: regula el $\Delta v$ según la ecuación de Tsiolkovski, el empuje-peso (`TWR`) y la compatibilidad estructural con el vehículo lanzador (`MASA <= máx. cohete`).
8. **Comunicaciones (`COMM`)**: el enlace usa la distancia a Tierra y una atenuación `min(1, 1/d²)` normalizada a 1 UA, limitada por la capacidad del transmisor al estar cerca. Las antenas **Banda-X (`+42 kbps`, `8 W`)** y **Banda-Ka (`+95 kbps`, `16 W`)** mejoran la descarga a cambio de masa, coste y energía. Orienta **TIERRA (+90°)** para enlace HGA óptimo.
9. **Limitaciones orbitales**: desvío inicial, ventanas de corrección **TCM**, tormentas solares, asistencias gravitatorias y ventana estrecha de **Inserción Orbital `180°`**.

---

## Mecánicas de la cabina virtual

### 1. Control de Orientación / Actitud (`RW` + `RCS`)
- **Ruedas de reacción (`RW`)**: rotan y estabilizan la sonda sin gastar combustible (consumen electricidad y se saturan durante tormentas solares).
- **Propulsores `RCS`**: activables con `RCS: ON/OFF` (`R`), multiplican el par de giro y **desaturan automáticamente las ruedas RW** usando micro-pulsos de propelente.
- **5 modos automáticos + control manual**:
  - `PRO 0°` (`1`): motor hacia atrás para corrección **TCM**.
  - `RET 180` (`2`): giro `180°` para frenar en **Inserción Orbital**.
  - `SOLAR -90°` (`3`): carga solar al `100%`.
  - `TIERRA +90°` (`4`): antena HGA al `100%` de velocidad (`kbps`) hacia Tierra.
  - `OBJET. -35°` (`5`): sensores apuntando al objetivo para capturar al `100%` en sobrevuelo.
  - `< IZQ` / `DER >` (`A`/`D` o `←`/`→`) y `ESTAB` (`S`).

### 2. Control de Trayectoria
- **Crucero inercial**: la sonda viaja con el motor apagado la mayor parte del tránsito sobre una trayectoria curva.
- **Maniobras TCM**: corrigen la desviación (`DESVÍO TCM` en km) con pulsos breves en `PRO 0°`.
- **Asistencia Gravitatoria (Honda)**: al pasar con desvío `<= 24 km`, el cuerpo intermedio suma `+150` a `+650 m/s` gratuitos sin gastar combustible.
- **Inserción Orbital (`180°`)**: al llegar al tramo final, gira `180°` (`RET 180`) y frena hasta la franja verde del CRT; de lo contrario la sonda sigue de largo y se pierde en el espacio.

### 3. Estados del Sistema (`ESTABLE` / `PRECAUCIÓN` / `CRÍTICO`)
Reflejados simultáneamente en la barra superior, el núcleo de aviónica de la sonda y el panel de energía según actitud, saturación `RW`, batería, desvío orbital y ventana de inserción.

---

## Misiones de la campaña

| # | Misión | Presupuesto | Cohete Rec. | Objetivo Científico Mínimo | $\Delta v$ Diseño | Honda Gravitatoria | Desafío principal |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **01** | **Órbita Baja Terrestre (LEO)** | `$115,000` | `Vega-C` (`420 kg`) | `*Cámara` (`>= 100 pts`) | `950 m/s` | Perigeo (`+150 m/s`) | Respetar límite de `420 kg` / `6` módulos, pulso TCM, descargar `32 MB` e insertar a `180°`. |
| **02** | **Honda y Captura Lunar** | `$185,000` | `Ariane-62` (`820 kg`) | `*Cámara + *Espectro` (`>= 220 pts`) | `2,200 m/s` | Cislunar (`+400 m/s`) | Equilibrar baterías para 2 eclipses, enlace para `86 MB`, honda cislunar y frenado selenocéntrico. |
| **03** | **Inserción en Marte (Ares-IV)** | `$260,000` | `Vulcan-H` (`1500 kg`) | `*Espectro + *Radar SAR` (`>= 400 pts`) | `3,500 m/s` | **Venus (`+650 m/s`)** | Sol a `1.52 UA` (43% de luz) y Tierra a `~1.50 UA` (44% de enlace); descargar `144 MB`, gestionar 60 W del XEN-9, tormenta y captura. |

---

## Marco NASA Integrado (CML, Segmentos SMD, CubeSat 101 y GMAT)

- **Niveles JPL `CML 1–5` y Márgenes Team X:** en ensamblaje la consola muestra en vivo `NASA CML X/5 | M | P | RF`. Team X sugiere margen `>=35%` en masa y potencia solar para `CML 4`, además de `>=6 dB` en proximidad (LEO) y `>=3 dB` en espacio profundo (Luna/Marte).
- **4 Segmentos de Misión NASA SMD:** `Lanzamiento`, `Espacio`, `Tierra (MOS/GDS)` y `Usuario (Ciencia)` auditables pulsando **`[N]`** (`NASA CML [N]`).
- **Compuertas CubeSat 101:** clasificación automática de factor de forma (`1U`, `3U`, `6U-12U`, `SmallSat / ESPA <300 kg`, `Bus Espacial Medio >=300 kg`) y verificación de `MEL`, `ODAR` (`>=3%` de reserva EOL), `DITL` e integridad térmica/estructural (`TVAC` / Vibración).
- **Misiones análogas NASA:** el catálogo e informe final conectan cada escenario con misiones reales (*PUNCH / BisonSat / Dellingr*, *CAPSTONE / Lunar Trailblazer*, *MAVEN / Mars Odyssey / Dawn*).
- **Exportador NASA GMAT R2026a:** desde la pestaña `SCRIPT GMAT` del modal **`[N]`** puedes inspeccionar y exportar a `user://gmat_<mision>.script` un modelo real para GMAT con `DryMass`, `FuelMass`, `ForceModel` (`JGM2.cof`, `LP165P.cof`, `Mars50c.cof`), `SRP.Flux` (`1367`/`1358 W/m²`), `Nominal_Sun = 149597870.691 km` y maniobras `ImpulsiveBurn` en marco `VNB` (además de 3 plantillas de referencia en `assets/nasa_gmat/`).
