class_name MenuBackground
extends Panel

const TEXTURE := preload("res://assets/ui/pause/panel_frame_v01.png")
const MARGIN : float = 16.0

static func make_box() -> StyleBoxTexture:
	var box : StyleBoxTexture = StyleBoxTexture.new()
	box.texture = TEXTURE
	box.texture_margin_left = MARGIN
	box.texture_margin_right = MARGIN
	box.texture_margin_top = MARGIN
	box.texture_margin_bottom = MARGIN
	return box

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", make_box())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
