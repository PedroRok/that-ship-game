class_name GearEntity
extends RigidBody2D

@onready
var sprite : Sprite2D = $Sprite2D
@export_range(1,20)
var catch_threshold : float = 10

signal pickup_gear(plus : int)

var target_control : Control
var amount : int = 1
var _flying : bool = false

const AUTO_COLLECT_DELAY : float = 0.5
var _auto_left : float = -1.0

func _start_flight() -> void:
	_flying = true
	desapier = true
	gravity_scale = 0
	linear_velocity = Vector2.ZERO
	sleeping = true
	sprite.hide()
	var from_screen : Vector2 = get_viewport().get_canvas_transform() * global_position
	var zoom : float = get_viewport().get_canvas_transform().get_scale().x
	GearFlyer.launch(self, sprite.texture, from_screen, target_control, zoom * scale.x, _arrived)

func _ready() -> void:
	add_to_group(&"collectible")
	if (Global.modify(Enums.UpgradeTarget.BASE, &"auto_collect", 0.0) > 0.0):
		_auto_left = AUTO_COLLECT_DELAY

func collect_after(seconds : float) -> void:
	_auto_left = seconds

func collect_instantly() -> void:
	if (desapier):
		return
	desapier = true
	pickup_gear.emit(amount)
	queue_free()

static func collect_visible(tree : SceneTree) -> void:
	var viewport : Viewport = tree.root
	var screen : Rect2 = Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	var to_screen : Transform2D = viewport.get_canvas_transform()
	for node : Node in tree.get_nodes_in_group(&"collectible"):
		var item : GearEntity = node as GearEntity
		if (item and is_instance_valid(item) and screen.has_point(to_screen * item.global_position)):
			item.collect_instantly()

func _arrived() -> void:
	pickup_gear.emit(amount)
	queue_free()

func explode() -> void:
	linear_velocity.y = randf_range(-200, -400)
	linear_velocity.x = randf_range(-200, 200)
	angular_velocity = randf_range(100, -100)
	

var time_to_change : int = 30
var is_glowing : bool = false

var time_to_desapier : int = 60
var desapier : bool = false

func _physics_process(delta: float) -> void:
	if (_auto_left > 0.0 and !desapier):
		_auto_left -= delta
		if (_auto_left <= 0.0):
			if (is_instance_valid(target_control)):
				_start_flight()
			else:
				collect_instantly()
			return
	time_to_change -= 1
	if (time_to_change <= 0):
		time_to_change = 30
		glow(!is_glowing)
		is_glowing = !is_glowing
	
	if (get_global_mouse_position().distance_to(global_position) < catch_threshold && !desapier):
		if (is_instance_valid(target_control)):
			_start_flight()
			return
		desapier = true
		pickup_gear.emit(amount)
		if randi_range(0,1) == 0:
			angular_velocity = -80
		else:
			angular_velocity = 80
		
		gravity_scale = 0
		linear_velocity = Vector2.ZERO
		
		pass
	
	if (desapier):
		if (time_to_desapier < 0):
			queue_free()
		scale = scale * 1.5
		var shader : ShaderMaterial = sprite.material
		shader.set_shader_parameter("opacity", (100 / 60) * time_to_desapier)
		time_to_desapier -= 1
		
		pass
	
	pass
	
func glow(active : bool) -> void:
	var shader : ShaderMaterial = sprite.material
	shader.set_shader_parameter("enable", active)
