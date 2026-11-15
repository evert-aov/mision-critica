class_name LearningOverlay
extends CanvasLayer
## In-game reference; opening it pauses the mission while the player reads.

var _was_paused: bool = false
var _title: Label
var _text: Label
var _close_button: Button
var _lang_button: Button
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(920.0, view_size.x - 40.0), minf(600.0, view_size.y - 40.0))
	panel.position = (view_size - panel.size) * 0.5
	panel.theme = ThemeFactory.get_theme()
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	box.add_child(top_bar)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", ThemeFactory.COL_CYAN)
	top_bar.add_child(_title)
	_lang_button = Button.new()
	_lang_button.custom_minimum_size = Vector2(90, 26)
	_lang_button.pressed.connect(func():
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			gs.call("toggle_language")
		else:
			Loc.set_lang("en" if not Loc.is_en() else "es")
		_refresh_texts()
	)
	top_bar.add_child(_lang_button)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_text = Label.new()
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_text)
	_close_button = Button.new()
	_close_button.custom_minimum_size.y = 26
	_close_button.pressed.connect(close_guide)
	box.add_child(_close_button)
	_refresh_texts()


func _refresh_texts() -> void:
	if _title == null:
		return
	_title.text = Loc.pick("APRENDER A DISEÑAR Y OPERAR UNA MISIÓN", "LEARN TO DESIGN & OPERATE A MISSION")
	_lang_button.text = Loc.pick("ES / EN", "EN / ES")
	_text.text = get_guide_text()
	_close_button.text = Loc.pick("VOLVER [ESC / F1]", "CLOSE [ESC / F1]")


func open_guide() -> void:
	if visible:
		return
	_refresh_texts()
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_close_button.grab_focus()


func close_guide() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE, KEY_F1:
			close_guide()
		KEY_DOWN:
			_scroll.scroll_vertical += 18
		KEY_UP:
			_scroll.scroll_vertical -= 18
		KEY_PAGEDOWN:
			_scroll.scroll_vertical += int(_scroll.size.y) - 18
		KEY_PAGEUP:
			_scroll.scroll_vertical -= int(_scroll.size.y) - 18
		KEY_HOME:
			_scroll.scroll_vertical = 0
		KEY_END:
			_scroll.scroll_vertical = 100000
		_:
			return
	get_viewport().set_input_as_handled()


static func get_guide_text() -> String:
	if Loc.is_en():
		return """FIRST FLIGHT
Pick a mission with 1-3 or click. In assembly, BASE [B] loads a viable design; AUTOPILOT [F6] lets you observe operations, and MANUAL [F5] lets you fly directly. F1 opens this reference and pauses flight.

KEYBOARD & MOUSE
In assembly: 1-6 switches category, Left/Right steps categories, Up/Down selects parts, and +/- changes count. Double-click equips and right-click removes; scroll wheel moves the list and adjusts count over +/-. In the blueprint, wheel zooms, drag pans, and middle click centers.
In flight: A/D rotates; 1-5 picks orientation; W/Q or Up/Down changes thrust; T triggers 100% turbo; C opens the safety cover and Space toggles engine ignition. P deploys solar arrays, R toggles RCS, S holds attitude, and X cuts thrust to zero. F2/F3/F4 toggle master/comms/science buses and F7/F8/F9 trigger camera/spectrometer/radar. M toggles AUTO and V shows/hides HUD guides.
On the space scene: left-click aims toward cursor, right-click holds attitude, middle-click toggles guides, and scroll wheel adjusts throttle in 5% steps (Shift: 1%). The thrust lever accepts click, drag, and wheel; right-click zeroes it. Wheel over logs/briefs scrolls only their text.
In debrief: R retries, D returns to design, and Esc returns to missions. Here: wheel, arrows, PgUp/PgDn, or Home/End scroll; Esc or F1 closes. Tab moves button focus and Enter activates it. Amber borders highlight keyboard focus.

2.5D SPACE VIEWPORT
The space scene takes the top 70% and the flight deck occupies the bottom 30%, with all instruments visible. V or GUIDES hides/shows compass & explanations without resizing the cockpit. You will see stage separation, cruise, approach, science flyby, and orbital insertion. Camera distances are compressed so probe and target stay visible on a 1280x720 viewport (scaled to 1920x1080).

READING ATTITUDE & ARROWS
Blue arrow v marks flight path and defines local PRO 0°. RET 180° points thrust opposite to v to brake. White arrow shows probe heading; amber arrow & arc show pending slew and active thrust. Use the local compass to compare SUN, EARTH, and TARGET. Controlled slews appear as Caution while aligning; uncontrolled spin can become Critical. Sun & radio markers are schematic pointing references, not an astronomical map.

DESTINATION & OUTCOME
Earth shows oceans & clouds; the Moon craters; Mars reddish terrain & ice caps. TO BRAKE shows remaining insertion delta-v. Trajectory prediction bends as you brake or drift. Only successful capture animates a stable final orbit. Missing science gives orbit with incomplete objectives; missed capture drifts away. Debrief replaces the bottom deck while keeping the target visible.

MOTION & DEPTH
The probe coasts by inertia when engines are off: nearby dust moves faster than distant stars. Braking slows that drift. Small rocks & satellites are visual depth cues without collision or fuel cost. After launch Earth recedes while the target grows across the transfer.

COMPETING TRADE-OFFS
Every instrument adds science points but also mass (kg), cost ($), power draw (W), and telemetry data (MB). Larger propellant tanks enable more burns yet raise mass: compare delta-v before and after. Heavier launch vehicles lift more payload but cost more.

MASS, DELTA-V & TWR
kg measures mass. Delta-v (m/s) is your velocity change budget, not current speed. Higher propellant fraction or Isp boosts delta-v. TWR compares thrust against Earth sea-level weight; in cruise TWR < 1 is normal.

POWER & BATTERY
W measures instantaneous power load or generation. Wh measures stored energy: 10 W over 1 hour consumes 10 Wh. Solar arrays produce 0 W during eclipses. Shut off Science or Radio buses when idle to save battery. Firing engines also draws power by throttle (XEN-9 takes 60 W at 100%).

SUN vs EARTH DISTANCES
AU is Astronomical Units. Solar distance scales panel output by 1/d². Earth distance scales radio bitrate by 1/d², capped by your antenna rate nearby. Mission scenarios treat Sun and Earth distances independently.

DATA & RADIO LINK
1 MB equals 8000 kilobits. At 18 kbps, sending 32 MB takes ~14222 physical seconds. The game accelerates data transfer x9200 (~1.55 game s on an optimal link). Pending instruments share total bitrate; better dishes add mass, cost, and W. Only downloaded packets score science.

ORIENTATION & WINDOWS
PRO 0° executes TCM course corrections. TARGET aims sensors during flyby. EARTH maximizes downlink speed. SOLAR peaks charging. RET 180° brakes into orbit. RCS spends tiny fuel puffs to slew faster and desaturate reaction wheels.

AUTOPILOT & GAME SCALES
AUTO operates your exact spacecraft using the same rules and limits. Orbits, engines, and rates are tuned for short playable sessions (thrust x45, electrical clock 0.06 h/game-s, comms data x9200). Use results to refine your engineering trade-offs!"""
	return """PRIMER VUELO
Elige una misión con 1-3 o clic. En ensamblaje, BASE [B] carga un diseño viable; AUTOMÁTICO [F6] observa su operación y MANUAL [F5] permite pilotar. F1 abre esta ayuda y pausa el vuelo.

TECLADO Y MOUSE
En ensamblaje: 1-6 cambia categoría, izquierda/derecha recorre categorías, arriba/abajo selecciona equipo y +/- cambia cantidad. Doble clic equipa y derecho quita; la rueda desplaza la lista y, sobre los botones +/-, cambia cantidad. En el plano, rueda amplía, arrastrar mueve y clic central centra.
En vuelo: A/D gira; 1-5 elige orientación; W/Q o arriba/abajo cambia empuje; T activa turbo 100%; C abre la tapa y Espacio enciende/apaga el motor. P despliega paneles, R activa RCS, S estabiliza y X pone empuje a cero. F2/F3/F4 controla buses maestro/radio/ciencia y F7/F8/F9 activa cámara/espectrómetro/radar. M cambia AUTO y V muestra/oculta ayudas visuales.
Sobre el espacio: clic izquierdo orienta hacia el puntero, derecho estabiliza, central muestra/oculta ayudas y rueda cambia empuje en pasos del 5% (Shift: 1%). La palanca admite clic, arrastre y rueda; derecho la lleva a cero. La rueda sobre informes solo desplaza su texto.
En resultado: R repite, D vuelve al diseño y Esc al menú. En la ayuda: rueda, flechas, RePág/AvPág o Inicio/Fin leen el texto; Esc o F1 vuelve al juego. Tab mueve el foco de los botones e Intro los activa. El borde ámbar identifica el foco de teclado.

VISTA ESPACIAL 2.5D
La escena ocupa el 70% y la cabina el 30% inferior, con todos sus controles visibles. V o AYUDAS oculta/muestra brújula y explicaciones sin mover la cabina. Verás separación del lanzador, tránsito, aproximación, ciencia e inserción. La cámara comprime distancias para mantener visibles la nave y el destino. La interfaz usa 1280x720 internos, preparada para 1920x1080.

CÓMO LEER LOS GIROS
La flecha azul v marca el movimiento y define PRO 0° en el marco local. RET 180° dirige el empuje al lado opuesto para frenar. La flecha blanca muestra la nave; la ámbar y el arco muestran el giro solicitado y el empuje. La brújula local permite comparar SOL, TIERRA y OBJETIVO. El giro controlado aparece como precaución mientras se alinea; una pérdida de control puede ser crítica. Sol y radio son referencias esquemáticas de orientación, no un mapa astronómico exacto.

DESTINO Y RESULTADO
La Tierra tiene océanos y nubes; la Luna, cráteres; Marte, superficie rojiza y polos. El indicador POR FRENAR muestra el delta-v de inserción pendiente. La línea de predicción cambia al frenar o desviarte. Solo una captura lograda deja una órbita final animada. Si falta ciencia puede haber órbita con objetivo incompleto; si falla la captura verás una trayectoria de salida o deriva. El informe sustituye la cabina inferior y deja visible el planeta.

MOVIMIENTO Y PROFUNDIDAD
La nave sigue avanzando por inercia con el motor apagado: partículas cercanas se desplazan más rápido que las estrellas lejanas. El frenado reduce ese movimiento. Pequeñas rocas y satélites son referencias decorativas, sin colisiones ni coste de recursos. Desde la salida, la Tierra queda atrás y el destino crece y se desplaza durante todo el crucero. También cambia el encuadre terrestre en LEO. El Sol permanece visible y su tamaño refleja la distancia solar del escenario; en el viaje lunar cambia poco. La escala y los encuadres son esquemáticos.

DECISIONES QUE COMPITEN
Cada instrumento aporta ciencia, pero añade kg, coste, consumo en W y datos en MB. Un tanque mayor permite más maniobras, pero aumenta la masa: compara el delta-v antes y después. Un cohete mayor admite más carga y cuesta más.

MASA, DELTA-V Y TWR
kg mide masa. Delta-v (m/s) es cuánto puede cambiar la velocidad de la nave; no es su velocidad actual. Más propelente o mayor Isp aumentan esa capacidad. TWR compara empuje con peso de referencia terrestre; en crucero no hace falta TWR mayor que uno.

POTENCIA Y BATERÍA
W mide consumo o generación por instante. Wh mide energía almacenada: 10 W durante una hora gastan 10 Wh. Durante eclipses no hay generación solar. Apagar ciencia o radio cuando no se usan ahorra batería. El motor también consume electricidad según el acelerador; XEN-9 exige 60 W a plena potencia.

SOL Y TIERRA SON DISTANCIAS DIFERENTES
UA es una unidad de distancia. La distancia al Sol determina la generación de paneles: duplicarla reduce la luz a un cuarto. La distancia a Tierra afecta el enlace de radio: su tasa disminuye con 1/d² y queda limitada por el transmisor cuando estás cerca. Las distancias son aproximaciones fijas de cada escenario.

DATOS Y RADIO
Un MB contiene 8000 kilobits. A 18 kbps, enviar 32 MB tarda unos 14222 segundos físicos. El juego acelera solo la transferencia x9200: tarda unos 1.55 segundos de juego con enlace óptimo. Más instrumentos comparten la misma tasa; mejor antena añade masa, coste y consumo. Solo los datos descargados puntúan.

ORIENTACIÓN Y VENTANAS
PRO 0° dirige correcciones TCM (ajustes de trayectoria). OBJETIVO apunta los sensores durante el sobrevuelo. TIERRA mejora la descarga. SOLAR maximiza generación. RET 180 gira para frenar y entrar en órbita. RCS usa pequeñas cantidades de propelente para girar y desaturar las ruedas de reacción.

PILOTO AUTOMÁTICO
AUTO opera tu diseño con los mismos recursos y condiciones de fallo. El texto AUTO explica cada acción y la bitácora la registra. Pulsa AUTO: ON para recuperar el control manual; el motor se detiene. Un diseño sin suficiente energía o propelente puede fallar aunque use AUTO.

MODELO DE JUEGO
Las órbitas, motores y cifras de catálogo están simplificados y balanceados para partidas cortas. No son especificaciones de vehículos reales. El empuje se acelera x45, el balance eléctrico usa 0.06 horas por segundo de juego y los datos x9200; son escalas independientes, no un reloj físico único. El cronómetro muestra segundos de juego.

APRENDER DEL RESULTADO
Sin batería: añade reserva, despliega paneles o apaga buses. Sin inserción: reserva propelente y frena en retrógrado durante la ventana. Sin ciencia: captura apuntando al objetivo y transmite antes de terminar. Reensambla y compara el resultado de tus decisiones."""
