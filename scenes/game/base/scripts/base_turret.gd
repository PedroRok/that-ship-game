class_name BaseTurret
extends Node2D

var gun : Gun
var team_stats : TeamStats
var range_px : float = 450.0
var _target : Node2D
var _next_check_frame : int = 0

func setup(team : TeamStats, gun_scene : PackedScene) -> void:
	team_stats = team
	gun = gun_scene.instantiate()
	gun.fired_bullet.connect(_on_gun_fired)
	add_child(gun)
	if (team_stats.direction < 0):
		gun.flip()

func _physics_process(_delta : float) -> void:
	if (!gun or !team_stats):
		return
	var frame : int = Engine.get_physics_frames()
	var target : Node2D = _target
	if (frame >= _next_check_frame or !is_instance_valid(_target) or _target.is_queued_for_deletion()):
		_next_check_frame = frame + 5 + int(get_instance_id() % 3)
		target = _nearest_enemy()
		_target = target
	gun.enemy = target
	if (target):
		gun.shoot_gun(Vector2(team_stats.direction, 0))

func _nearest_enemy() -> Node2D:
	var best : Node2D = null
	var best_dist : float = range_px
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or entity.is_queued_for_deletion() or !entity.enabled):
			continue
		if (entity.team_stats.team_id == team_stats.team_id):
			continue
		var dist : float = entity.global_position.distance_to(global_position)
		if (dist < best_dist):
			best_dist = dist
			best = entity
	return best

func _on_gun_fired(bullet : Bullet, position : Vector2, direction : Vector2, rot : float) -> void:
	var manager : BulletManager = BattleContext.of(self).bullets
	if (!manager):
		return
	bullet.team = team_stats.team_id
	manager.handle_bullet_spawned(bullet, position, direction, rot)
