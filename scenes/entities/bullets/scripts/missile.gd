class_name BulletMissile
extends Bullet

@export var initial_speed: float = 200
@export var turn_speed: float = 5.0

var launch_forward : bool = false

const LIFETIME_MULT : float = 2.0
const GROUP : StringName = &"missiles"

func decoy(angle : float) -> void:
	target = null
	hits_air = false
	direction = direction.rotated(angle)
	rotation = direction.angle()

func _ready() -> void:
	add_to_group(GROUP)
	bullet_stats.killTime = int(bullet_stats.killTime * LIFETIME_MULT)

func set_direction(new_direction: Vector2) -> void:
	if (launch_forward and new_direction != Vector2.ZERO):
		self.direction = new_direction.normalized() * initial_speed
		rotation = direction.angle()
		return
	self.direction = Vector2(0, -1) * initial_speed
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if target && target.enabled:
		var direction_to_target : Vector2 = (target.get_center_pos() - global_position).normalized()
		direction = direction.lerp(direction_to_target * bullet_stats.speed, turn_speed * delta)
		rotation = direction.angle()
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
		particle.reparent(get_parent())
	queue_free()
