class_name BulletMissile
extends Bullet

@export var initial_speed: float = 200
@export var turn_speed: float = 5.0

var launch_forward : bool = false

const LIFETIME_MULT : float = 2.0
const GROUP : StringName = &"missiles"
const BLAST_RADIUS : float = 11.0
const BLAST_GRAINS : int = 120
const BLAST_SECONDS : float = 1.2
const BLAST_DEBRIS : int = 8
const BUBBLE_GRAINS : int = 30
const TRAIL_THICK : float = 1.0

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
	
	var before : Vector2 = global_position
	global_position += direction * delta
	if (global_position.y < ShipEntity.WATER_LEVEL):
		GrainParticles.missile_trail(get_parent(), before, global_position, TRAIL_THICK)
	if (bullet_stats.killTime <= 0):
		remove_bullet()
	bullet_stats.killTime -= 1

func remove_bullet() -> void:
	if (is_queued_for_deletion()):
		return
	BattleAudio.play_at(self, &"missile_explosion", global_position, self, global_position.y >= ShipEntity.WATER_LEVEL)
	_explode_particles()
	queue_free()

func _explode_particles() -> void:
	if (global_position.y >= ShipEntity.WATER_LEVEL):
		GrainParticles.bubbles(get_parent(), global_position, BLAST_RADIUS, BUBBLE_GRAINS)
		return
	GrainParticles.blast(get_parent(), global_position, BLAST_RADIUS, BLAST_GRAINS, BLAST_SECONDS)
	GrainParticles.debris(get_parent(), global_position, BLAST_RADIUS, BLAST_DEBRIS)

func _impact_particles(_underwater : bool) -> void:
	pass

func play_impact_sfx(_underwater : bool = false) -> void:
	pass
