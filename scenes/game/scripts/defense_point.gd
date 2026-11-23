class_name DefensePoint
extends Node2D

const RING_SCALE : float = 4.0

var ring : AnimatedSprite2D
var buoy : AnimatedSprite2D

func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring = AnimatedSprite2D.new()
	ring.sprite_frames = _frames("res://assets/ui/hud/defense_ring_frame_%02d_v01.png", "ring")
	ring.scale = Vector2.ONE * (RunData.DEFEND_RADIUS / 40.0)
	ring.modulate = Color(1, 1, 1, 0.8)
	ring.play(&"ring")
	add_child(ring)
	buoy = AnimatedSprite2D.new()
	buoy.sprite_frames = _frames("res://assets/game/entities/defense_buoy_frame_%02d_v01.png", "buoy")
	buoy.offset = Vector2(0, -9)
	buoy.play(&"buoy")
	add_child(buoy)

func _frames(pattern : String, animation : StringName) -> SpriteFrames:
	var frames : SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(animation)
	frames.set_animation_loop(animation, true)
	frames.set_animation_speed(animation, 8.0)
	for i : int in range(1, 5):
		frames.add_frame(animation, load(pattern % i) as Texture2D)
	return frames

func set_contested(contested : bool) -> void:
	ring.modulate = Color(1.0, 0.6, 0.6, 0.9) if contested else Color(1, 1, 1, 0.8)
