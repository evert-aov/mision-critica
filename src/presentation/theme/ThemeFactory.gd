class_name ThemeFactory
extends RefCounted
## Builds and caches the pixel-art Theme, NinePatch styles, and SpriteFrames helpers.

const COL_BG := Color("0a0e16")
const COL_PANEL := Color("1c2230")
const COL_TEXT := Color("ecf2f8")
const COL_WHITE := Color("ecf2f8")
const COL_MUTED := Color("a8b4c6")
const COL_GREEN := Color("40e880")
const COL_AMBER := Color("f8b838")
const COL_RED := Color("e84444")
const COL_CYAN := Color("40c8f0")

static var _cached_theme: Theme


static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var theme := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/pixel_5x7.fnt"):
		var font: Font = load("res://assets/fonts/pixel_5x7.fnt")
		theme.default_font = font
	theme.default_font_size = 8

	var panel_sb := make_ninepatch_style("res://assets/sprites/ui/panel_metal.png", 6, 6, 6)
	var crt_sb := make_ninepatch_style("res://assets/sprites/ui/panel_crt.png", 6, 5, 5)
	var btn_norm := make_ninepatch_style("res://assets/sprites/ui/btn_normal.png", 4, 4, 2)
	var btn_hov := make_ninepatch_style("res://assets/sprites/ui/btn_hover.png", 4, 4, 2)
	var btn_pres := make_ninepatch_style("res://assets/sprites/ui/btn_pressed.png", 4, 4, 2)
	var btn_dis := make_ninepatch_style("res://assets/sprites/ui/btn_disabled.png", 4, 4, 2)

	theme.set_stylebox("panel", "PanelContainer", panel_sb)
	theme.set_stylebox("panel", "Panel", crt_sb)

	theme.set_stylebox("normal", "Button", btn_norm)
	theme.set_stylebox("hover", "Button", btn_hov)
	theme.set_stylebox("pressed", "Button", btn_pres)
	theme.set_stylebox("disabled", "Button", btn_dis)
	theme.set_stylebox("focus", "Button", btn_hov)

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_CYAN)
	theme.set_color("font_pressed_color", "Button", COL_AMBER)
	theme.set_color("font_disabled_color", "Button", Color("667080"))

	# ProgressBar styling
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("0c121c")
	bar_bg.border_color = Color("3a465c")
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COL_GREEN
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", COL_TEXT)

	_cached_theme = theme
	return _cached_theme


static func make_ninepatch_style(tex_path: String, margin: int, content_margin_h: int, content_margin_v: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if ResourceLoader.exists(tex_path):
		sb.texture = load(tex_path)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	var v_margin: int = content_margin_h if content_margin_v < 0 else content_margin_v
	sb.content_margin_left = content_margin_h
	sb.content_margin_top = v_margin
	sb.content_margin_right = content_margin_h
	sb.content_margin_bottom = v_margin
	return sb


static func make_ninepatch_rect(tex_path: String, margin: int = 6) -> NinePatchRect:
	var npr := NinePatchRect.new()
	if ResourceLoader.exists(tex_path):
		npr.texture = load(tex_path)
	npr.patch_margin_left = margin
	npr.patch_margin_top = margin
	npr.patch_margin_right = margin
	npr.patch_margin_bottom = margin
	npr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return npr


static func make_sprite_frames(sheet_path: String, frame_w: int, frame_h: int, fps: float, loop: bool = true) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.set_animation_speed("default", fps)
		frames.set_animation_loop("default", loop)
	if not ResourceLoader.exists(sheet_path):
		return frames
	var tex: Texture2D = load(sheet_path)
	var total_w: int = int(tex.get_width())
	var count: int = maxi(1, total_w / frame_w)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame("default", atlas)
	return frames
