extends Node2D

var velocity : float = 0;

var force : float = 0;

var height : float = 0;

var target_height : float = 0;

@onready var collision : CollisionShape2D = $Area2D/CollisionShape2D

var index : int = 0

var motion_factor : float = 0.02

signal splash(index : int, speed : float)


func water_update(spring_constant : float, dampening : float) -> void:
	height = position.y
	
	var x : int = height - target_height
	
	var loss : float = - dampening * velocity
	
	# lei de Hooke
	force = -spring_constant * x + loss
	
	velocity += force
	
	position.y  += velocity
	pass
	
func initialize(x_position : int, id : int) -> void:
	height = position.y
	target_height = position.y
	velocity = 0
	position.x = x_position
	index = id 
	
func set_collision_width(value : int) -> void:
	var extents : Vector2 = collision.shape.size
	var new_extents : Vector2 = Vector2(value, extents.y)
	collision.shape.size = new_extents


func _on_area_2d_body_entered(body: Node2D) -> void:
	if (is_instance_of(body, RigidBody2D)):
		var bd : RigidBody2D = body as RigidBody2D
		if (bd.linear_velocity.x > 0.2 || bd.linear_velocity.x < -0.2 ): 
			var speed : float = 10 * motion_factor
			emit_signal("splash", index, -speed)
		pass # Replace with function body.
