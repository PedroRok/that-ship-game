class_name BulletMissile
extends Bullet

@export var initial_speed: float = 200 # Velocidade inicial para cima
@export var turn_speed: float = 5.0

func set_direction(new_direction: Vector2) -> void:
	self.direction = Vector2(0, -1) * initial_speed
	look_at(direction)

func _physics_process(delta: float) -> void:
	if target && target.enabled:
		var direction_to_target : Vector2 = (target.get_center_pos() - global_position).normalized()
		direction = direction.lerp(direction_to_target * bullet_stats.speed, turn_speed * delta)
		look_at(direction * bullet_stats.speed)
	else:
		direction = direction.normalized() * bullet_stats.speed
	
	global_position += direction * delta
	if (bullet_stats.killTime <= 0):
		remove_bullet()
	bullet_stats.killTime -= 1

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
