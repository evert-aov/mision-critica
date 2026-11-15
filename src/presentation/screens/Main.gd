@tool
extends Control
## Root application router that switches cleanly between Mission Select, Assembly, and Cockpit scenes.

const SCENE_MISSION_SELECT := preload("res://src/presentation/screens/MissionSelectScreen.tscn")
const SCENE_ASSEMBLY := preload("res://src/presentation/screens/AssemblyScreen.tscn")
const SCENE_COCKPIT := preload("res://src/presentation/screens/CockpitScreen.tscn")

var _current_view: Node
var _learning_overlay: LearningOverlay


func _ready() -> void:
	if Engine.is_editor_hint():
		_current_view = SCENE_MISSION_SELECT.instantiate()
		add_child(_current_view)
		return
	RenderingServer.set_default_clear_color(ThemeFactory.COL_BG)
	_learning_overlay = LearningOverlay.new()
	add_child(_learning_overlay)
	GameState.learning_requested.connect(_learning_overlay.open_guide)
	GameState.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(GameState.current_phase)


func _on_phase_changed(phase: GameState.Phase) -> void:
	if phase == GameState.Phase.MISSION_RESULT:
		return # CockpitScreen handles the result overlay in place

	if _current_view != null:
		remove_child(_current_view)
		_current_view.queue_free()
		_current_view = null

	match phase:
		GameState.Phase.MISSION_SELECT:
			_current_view = SCENE_MISSION_SELECT.instantiate()
		GameState.Phase.ASSEMBLY:
			_current_view = SCENE_ASSEMBLY.instantiate()
		GameState.Phase.FLIGHT_COCKPIT:
			_current_view = SCENE_COCKPIT.instantiate()

	if _current_view != null:
		add_child(_current_view)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		GameState.learning_requested.emit()
		get_viewport().set_input_as_handled()
