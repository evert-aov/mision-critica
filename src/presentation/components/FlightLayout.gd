class_name FlightLayout
extends RefCounted
## Stable 70/30 split in virtual pixels; independent of HUD visibility and pilot mode.

static func calculate(view_size: Vector2) -> Dictionary:
	var margin: float = 8.0
	var gap: float = 6.0
	var width: float = maxf(view_size.x - margin * 2.0, 1.0)
	var available_height: float = maxf(view_size.y - margin * 2.0 - gap, 1.0)
	var scene_height: float = floorf(available_height * 0.70)
	return {
		"scene": Rect2(margin, margin, width, scene_height),
		"deck": Rect2(margin, margin + scene_height + gap, width, available_height - scene_height),
	}
