class_name DefensePoint
extends Node2D

const RING_FPS : float = 3.0
const RING_COLOR : Color = Color(1, 1, 1, 0.4)
const RING_ALLY : Color = Color(0.6, 0.8, 1.0, 0.55)
const RING_ENEMY : Color = Color(1.0, 0.6, 0.6, 0.55)
const RING_CONTESTED : Color = Color(1.0, 0.85, 0.45, 0.6)
const OUTLINE_CONTESTED : Color = Color(1.0, 0.75, 0.25, 0.55)
const BUOY_OFFSET : Vector2 = Vector2(0, -7)
const BOB_HEIGHT : float = 1.5
const BOB_SPEED : float = 2.1
const TILT : float = 0.1
const TILT_SPEED : float = 1.3

var water : WaterBody
var ring : AnimatedSprite2D
var buoy : Sprite2D
var outline : ShaderMaterial
var _clock : float = 0.0

func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring = AnimatedSprite2D.new()
	ring.sprite_frames = _ring_frames()
	ring.scale = Vector2.ONE * (RunData.DEFEND_RADIUS / 40.0)
	ring.modulate = RING_COLOR
	ring.play(&"ring")
	add_child(ring)
	buoy = Sprite2D.new()
	buoy.texture = load("res://assets/game/entities/defense_buoy_frame_01_v01.png") as Texture2D
	buoy.offset = BUOY_OFFSET
	add_child(buoy)
	_add_outline()

func _add_outline() -> void:
	outline = ShaderMaterial.new()
	outline.shader = Entity.OUTLINE_SHADER
	outline.set_shader_parameter("thickness", Entity.OUTLINE_THICKNESS)
	outline.set_shader_parameter("outline_color", Entity.OUTLINE_ALLY)
	var border : Sprite2D = Sprite2D.new()
	border.texture = Entity._padded_texture(buoy.texture)
	border.offset = BUOY_OFFSET
	border.material = outline
	border.show_behind_parent = true
	buoy.add_child(border)

func _exit_tree() -> void:
	var context : BattleContext = BattleContext.of(self)
	if (context):
		context.patrol_x = NAN

func _process(delta : float) -> void:
	_clock += delta
	var wave : float = water.surface_offset(global_position.x) if water else 0.0
	buoy.position.y = ShipEntity.WATER_LEVEL - global_position.y + wave + sin(_clock * BOB_SPEED) * BOB_HEIGHT
	buoy.rotation = sin(_clock * TILT_SPEED) * TILT

func _ring_frames() -> SpriteFrames:
	var frames : SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"ring")
	frames.set_animation_loop(&"ring", true)
	frames.set_animation_speed(&"ring", RING_FPS)
	for i : int in range(1, 5):
		frames.add_frame(&"ring", load("res://assets/ui/hud/defense_ring_frame_%02d_v01.png" % i) as Texture2D)
	return frames

func set_presence(ally : bool, enemy : bool) -> void:
	var ring_color : Color = RING_COLOR
	var outline_color : Color = Entity.OUTLINE_ALLY
	if (ally and enemy):
		ring_color = RING_CONTESTED
		outline_color = OUTLINE_CONTESTED
	elif (enemy):
		ring_color = RING_ENEMY
		outline_color = Entity.OUTLINE_ENEMY
	elif (ally):
		ring_color = RING_ALLY
	ring.modulate = ring_color
	outline.set_shader_parameter("outline_color", outline_color)
