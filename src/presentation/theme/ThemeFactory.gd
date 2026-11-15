class_name ThemeFactory
extends RefCounted
## Builds and caches the pixel-art Theme, NinePatch styles, procedural fallback icons, and SpriteFrames helpers.

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
static var _cached_icons: Dictionary = {}


static func has_ui_font() -> bool:
	return ResourceLoader.exists("res://assets/fonts/pixel_ui.fnt")


static func get_ui_font() -> Font:
	if has_ui_font():
		return load("res://assets/fonts/pixel_ui.fnt")
	if ResourceLoader.exists("res://assets/fonts/pixel_5x7.fnt"):
		return load("res://assets/fonts/pixel_5x7.fnt")
	return null


static func get_ui_font_size() -> int:
	# 1:1 native 14px when pixel_ui.fnt exists, or exact 2x integer 16px fallback on 8px pixel_5x7.fnt.
	return 14 if has_ui_font() else 16


static func get_compact_font() -> Font:
	if ResourceLoader.exists("res://assets/fonts/pixel_5x7.fnt"):
		return load("res://assets/fonts/pixel_5x7.fnt")
	return get_ui_font()


static func get_compact_font_size() -> int:
	# Exact 1:1 integer scale of pixel_5x7.fnt (eliminates 9/8 blurry rounding distortion).
	return 8 if ResourceLoader.exists("res://assets/fonts/pixel_5x7.fnt") else get_ui_font_size()


static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var theme := Theme.new()
	var font: Font = get_ui_font()
	var ui_size: int = get_ui_font_size()
	if font != null:
		theme.default_font = font
	theme.default_font_size = ui_size
	for control_type in ["Label", "Button", "PopupMenu", "TooltipLabel"]:
		theme.set_font_size("font_size", control_type, ui_size)

	# Crisp 1px drop shadow and breathing room on labels for high CRT contrast
	theme.set_color("font_shadow_color", "Label", Color(0.02, 0.04, 0.08, 0.90))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_constant("shadow_outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", 3)

	var panel_sb := make_ninepatch_style("res://assets/sprites/ui/panel_metal.png", 6, 6, 6)
	var crt_sb := make_ninepatch_style("res://assets/sprites/ui/panel_crt.png", 6, 5, 5)

	theme.set_stylebox("panel", "PanelContainer", panel_sb)
	theme.set_stylebox("panel", "Panel", crt_sb)

	theme.set_stylebox("normal", "Button", control_style(Color("172536"), Color("40556d")))
	theme.set_stylebox("hover", "Button", control_style(Color("203b4c"), COL_CYAN))
	theme.set_stylebox("pressed", "Button", control_style(Color("164239"), COL_GREEN))
	theme.set_stylebox("disabled", "Button", control_style(Color("111b27"), Color("293b4c")))
	var focus_style := control_style(Color(0, 0, 0, 0), COL_AMBER)
	focus_style.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus_style)

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

	# Slim Pixel-Art VScrollBar (6px wide) for CRT terminals & catalogs
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color("070c12")
	sb_track.border_color = Color("243446")
	sb_track.set_border_width_all(1)
	sb_track.content_margin_left = 6
	sb_track.content_margin_right = 0

	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color("2e7d5b")
	var sb_grab_hi := StyleBoxFlat.new()
	sb_grab_hi.bg_color = COL_GREEN
	var sb_grab_pr := StyleBoxFlat.new()
	sb_grab_pr.bg_color = COL_AMBER

	theme.set_stylebox("scroll", "VScrollBar", sb_track)
	theme.set_stylebox("grabber", "VScrollBar", sb_grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb_grab_hi)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb_grab_pr)

	_cached_theme = theme
	return _cached_theme


static func control_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func bind_shortcut(button: BaseButton, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	var shortcut := Shortcut.new()
	shortcut.events = [key]
	button.shortcut = shortcut
	button.shortcut_feedback = true


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


static func get_catalog_icon(key: String) -> Texture2D:
	if _cached_icons.has(key):
		return _cached_icons[key]

	var tex_path := "res://assets/sprites/parts/%s.png" % key
	if ResourceLoader.exists(tex_path):
		var loaded: Texture2D = load(tex_path)
		_cached_icons[key] = loaded
		return loaded

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color("080a10")
	var silver := Color("a8b4c6")
	var steel := Color("606e84")
	var gold := Color("ecb236")

	match key:
		"part_comm_xband":
			_img_rect(img, 6, 11, 4, 4, steel)
			_img_rect(img, 2, 7, 12, 3, silver)
			_img_rect(img, 4, 9, 8, 2, steel)
			_img_rect(img, 7, 3, 2, 5, COL_WHITE)
			_img_rect(img, 6, 2, 4, 2, COL_CYAN)
			img.set_pixel(3, 3, COL_CYAN)
			img.set_pixel(12, 3, COL_CYAN)
		"part_comm_kaband":
			_img_rect(img, 5, 11, 6, 4, gold)
			_img_rect(img, 1, 6, 14, 4, gold)
			_img_rect(img, 2, 7, 12, 2, COL_WHITE)
			_img_rect(img, 7, 2, 2, 6, COL_WHITE)
			_img_rect(img, 5, 1, 6, 2, COL_GREEN)
			img.set_pixel(2, 2, COL_CYAN)
			img.set_pixel(13, 2, COL_CYAN)
		"lv_light":
			_img_rect(img, 7, 1, 2, 2, COL_AMBER)
			_img_rect(img, 6, 3, 4, 10, COL_WHITE)
			_img_box(img, 6, 3, 4, 10, border)
			_img_rect(img, 7, 6, 2, 2, COL_AMBER)
			_img_rect(img, 5, 11, 6, 2, steel)
			_img_rect(img, 7, 13, 2, 3, COL_AMBER)
		"lv_medium":
			_img_rect(img, 6, 1, 4, 2, COL_CYAN)
			_img_rect(img, 5, 3, 6, 10, COL_WHITE)
			_img_box(img, 5, 3, 6, 10, border)
			_img_rect(img, 3, 6, 2, 7, silver)
			_img_rect(img, 11, 6, 2, 7, silver)
			_img_rect(img, 6, 6, 4, 2, COL_CYAN)
			_img_rect(img, 6, 13, 4, 3, COL_AMBER)
		"lv_heavy":
			_img_rect(img, 6, 0, 4, 3, gold)
			_img_rect(img, 5, 3, 6, 10, COL_WHITE)
			_img_box(img, 5, 3, 6, 10, border)
			_img_rect(img, 2, 5, 3, 8, silver)
			_img_rect(img, 11, 5, 3, 8, silver)
			_img_box(img, 2, 5, 3, 8, border)
			_img_box(img, 11, 5, 3, 8, border)
			_img_rect(img, 6, 5, 4, 3, COL_RED)
			_img_rect(img, 3, 13, 10, 3, COL_AMBER)
		_:
			_img_rect(img, 3, 3, 10, 10, silver)
			_img_box(img, 3, 3, 10, 10, border)

	var tex := ImageTexture.create_from_image(img)
	_cached_icons[key] = tex
	return tex


static func _img_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(maxi(0, y), mini(16, y + h)):
		for xx in range(maxi(0, x), mini(16, x + w)):
			img.set_pixel(xx, yy, col)


static func _img_box(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for xx in range(maxi(0, x), mini(16, x + w)):
		if y >= 0 and y < 16:
			img.set_pixel(xx, y, col)
		if y + h - 1 >= 0 and y + h - 1 < 16:
			img.set_pixel(xx, y + h - 1, col)
	for yy in range(maxi(0, y), mini(16, y + h)):
		if x >= 0 and x < 16:
			img.set_pixel(x, yy, col)
		if x + w - 1 >= 0 and x + w - 1 < 16:
			img.set_pixel(x + w - 1, yy, col)
