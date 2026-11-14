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

| Suite | Archivo | Cobertura |
| --- | --- | --- |
| **Unitaria** | [tests/TestRunner.gd](../tests/TestRunner.gd) | Masas seca/húmeda, Tsiolkovski simple y multimotor, TWR, irradiancia solar a `1.0 UA` y `1.52 UA`, consumo por buses, validación de presupuesto, viabilidad de las 3 misiones base, bloqueo de tapa de seguridad, conservación de $\Delta v$, captura científica `35%`/`100%`, apagón `FAILED_POWER` y flujo completo de `VICTORY`. |
| **Integración** | [tests/IntegrationTest.gd](../tests/IntegrationTest.gd) | Inicialización real de `MissionData`, `PhysicsCalculator`, `GameState` y `AudioManager`; instanciación de `Main.tscn`; transición `MISSION_SELECT` $\rightarrow$ `ASSEMBLY` (`mars_orbit`) $\rightarrow$ `FLIGHT_COCKPIT` y quemado activo en varios frames del `SceneTree`. |

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
