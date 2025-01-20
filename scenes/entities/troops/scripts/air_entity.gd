extends RigidBody2D


@export
var animated_sprite : AnimatedSprite2D

@export
var animated_blades : AnimatedSprite2D

func _ready() -> void:
	rotation_degrees = 20
	animated_blades.play()
func _physics_process(delta: float) -> void:
	
	var rotation_speed : float = 3.0  # Ajuste este valor para controlar a velocidade de rotação
	
	if Input.is_action_pressed("ui_left"):
		angular_velocity = -rotation_speed
	elif Input.is_action_pressed("ui_right"):
		angular_velocity = rotation_speed
	else:
		angular_velocity = 0
	print(map_rotation_to_value())
	animated_sprite.frame = map_rotation_to_value()
	check_direction_and_flip()
	
	var direction : Vector2 = Vector2(cos(rotation), sin(rotation))
	linear_velocity = direction * 100
	pass

func map_rotation_to_value() -> int:
	# Obtém a rotação em graus e normaliza para 0-360
	var rotation_dgr : float = fmod(rotation_degrees + 360, 360)
	# Converte a rotação para um valor entre 0 e 5
	var value : int = 5 * abs(sin(deg_to_rad(rotation_dgr)))
	return value
	
func check_direction_and_flip() -> void:
	# Obtém a rotação em graus e normaliza para 0-360
	var rotation_dgr : float = fmod(rotation_degrees + 360, 360)
	
	# Verifica se está apontando para baixo (entre 90 e 270 graus)
	var is_facing_down : int = rotation_dgr > 90 and rotation_dgr < 270
	
	#print (rotation_dgr)
	# Aplica o flip ao sprite
	animated_sprite.flip_v = is_facing_down  # Troque Sprite2D pelo nome do seu node
