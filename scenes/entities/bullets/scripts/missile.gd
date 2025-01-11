class_name BulletMissile
extends Bullet

@export var initial_speed: float = 200 # Velocidade inicial para cima
@export var turn_speed: float = 5.0

func set_direction(new_direction: Vector2) -> void:
	self.direction = Vector2(0, -1) * initial_speed

func _physics_process(delta: float) -> void:
	if target:
		var direction_to_target : Vector2 = (target.global_position - global_position).normalized()
		direction = direction.lerp(direction_to_target * speed, turn_speed * delta)
		look_at(direction * speed)
	else:
		direction = direction.normalized() * speed
	
	global_position += direction * delta
	if (killTime <= 0):
		remove_bullet()
	killTime -= 1

func remove_bullet() -> void:
	var particle : CPUParticles2D = $CPUParticles2D
	if particle:
		particle.finished.connect(particle.queue_free)
		particle.spread = 180
		particle.scale_amount_min = 2
		particle.scale_amount_max = 2
		particle.one_shot = true
		particle.reparent(get_tree().root)
		
	queue_free()
