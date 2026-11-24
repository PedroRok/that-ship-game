class_name Gun
extends Node2D

@export
var gun_type : Enums.Guns

@export
var time_to_shoot : int = 50
@export
var damage_scale : float = 1.0
@export
var projectile_texture : Texture2D
@export
var projectile_scale : float = 1.0
@export
var hits_air : bool = true
@export
var hits_surface : bool = true
@export
var hits_submerged : bool = false
@export
var bullet_speed_scale : float = 1.0
@export 
var bullet : PackedScene
@export
var sfx_event : StringName = &""
@export
var end_barrel : Marker2D

var projectile_rotation_spawn : float = 0

var current_time_to_shoot : int = 0

signal fired_bullet(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)

var enemy : Node2D

signal gun_fired(bullet_instance : Bullet, global_position: Vector2, direction : Vector2, rotation : float)

@export
var base : Sprite2D
@export 
var show_base: bool = true : 
	set = _set_show_base_texture 
	
func _set_show_base_texture(_show_base : bool) -> void:
	if (!base):
		return
	if (_show_base):
		base.show()
	else:
		base.hide()
	pass

var _range_cache : float = -1.0

func effective_range() -> float:
	if (_range_cache >= 0.0):
		return _range_cache
	var reach : float = 400.0
	var inst : Node = bullet.instantiate() if bullet else null
	if (inst is Bullet):
		var b : Bullet = inst
		var spd : float = maxf(1.0, roundf(b.bullet_stats.speed * bullet_speed_scale))
		if (b is BulletMissile):
			reach = b.bullet_stats.speed * b.bullet_stats.killTime / 60.0
		elif (b is BulletBomb):
			reach = 60.0
		else:
			reach = spd * b.bullet_stats.killTime
	if (inst):
		inst.free()
	_range_cache = reach * 0.9
	return _range_cache

func target_distance(target : Node2D) -> float:
	if (target is Base):
		return (target as Base).distance_from(global_position)
	if (target.has_method("get_center_pos")):
		return global_position.distance_to(target.get_center_pos())
	return global_position.distance_to(target.global_position)

func can_target(target : Node2D) -> bool:
	var entity : Entity = target as Entity
	if (!entity):
		return hits_surface
	if (entity.is_submerged()):
		return hits_submerged
	if (entity.entity_stats is AirPlaneState):
		return hits_air
	return hits_surface

func shoot_gun(direction: Vector2) -> void:
	if (enemy and !can_target(enemy)):
		return
	if (enemy and target_distance(enemy) > effective_range()):
		return
	if !end_barrel:
		push_error("Trying to shoot without a gun barrel")
		return
	if current_time_to_shoot > 0:
		current_time_to_shoot -= 1
		return
	current_time_to_shoot = time_to_shoot
	if enemy:
		var bullet_instance : Bullet = bullet.instantiate()
		bullet_instance.target = enemy
		if bullet_instance.damage:
			bullet_instance.damage = bullet_instance.damage.duplicate()
			bullet_instance.damage.damage *= damage_scale
		bullet_instance.bullet_stats.speed = maxi(1, int(round(bullet_instance.bullet_stats.speed * bullet_speed_scale)))
		bullet_instance.hits_air = hits_air
		_apply_projectile_texture(bullet_instance)
		bullet_instance.hits_submerged = hits_submerged
		if direction.x > 0:
			direction = direction.rotated(projectile_rotation_spawn)
		else:
			direction = direction.rotated(-projectile_rotation_spawn)
		fired_bullet.emit(bullet_instance, end_barrel.global_position, direction, projectile_rotation_spawn)
		play_effects()
	else:
		push_error("Trying to shoot without enemy defined")
		
	
	
func _apply_projectile_texture(bullet_instance : Bullet) -> void:
	if (!projectile_texture):
		return
	var sprite : Sprite2D = bullet_instance.get_node_or_null("Sprite2D") as Sprite2D
	if (!sprite):
		return
	sprite.texture = projectile_texture
	sprite.self_modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	sprite.centered = false
	sprite.position = Vector2(0, -floorf(projectile_texture.get_height() * 0.5))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func play_effects() -> void:
	if (sfx_event != &""):
		BattleAudio.play_at(self, sfx_event, end_barrel.global_position, self)

func flip() -> void:
	rotate(PI)
	scale.y = -scale.y
