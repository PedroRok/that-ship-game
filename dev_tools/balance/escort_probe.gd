extends RefCounted

var damage_by : Dictionary = {}
var damage_at : Dictionary = {}
var covered : float = 0.0
var uncovered : float = 0.0
var from_behind : float = 0.0
var total : float = 0.0
var air_mult : float = 1.0
var health_scale : float = 1.0

const BUFFER : float = 100000.0

var _virtual : float = -1.0

var _bullets : Array[Bullet] = []
var _last : Array[Dictionary] = []
var _health : float = -1.0
var _tree : SceneTree

func start(tree : SceneTree) -> void:
	_tree = tree
	_tree.node_added.connect(_on_node)

func stop() -> void:
	_tree.node_added.disconnect(_on_node)

func _on_node(node : Node) -> void:
	if (node is Bullet):
		_bullets.append(node as Bullet)

func _snapshot() -> Array[Dictionary]:
	var result : Array[Dictionary] = []
	var alive : Array[Bullet] = []
	for index : int in _bullets.size():
		if (!is_instance_valid(_bullets[index])):
			continue
		var bullet : Bullet = _bullets[index]
		alive.append(bullet)
		if (bullet.is_inside_tree() and bullet.team != 1):
			result.append({"pos": bullet.global_position, "key": "%s/%s" % [bullet.scene_file_path.get_file().get_basename(),
					str(Enums.UnitClass.keys()[bullet.attacker_class])]})
	_bullets = alive
	return result

func tick(game : GameRound, escort : Entity, progress : float) -> void:
	var now : Array[Dictionary] = _snapshot()
	var component : HealthComponent = escort.get_node("HealthComponent") as HealthComponent
	var buffered : bool = air_mult != 1.0 or health_scale != 1.0
	if (buffered and _virtual < 0.0):
		_virtual = component.actual_health * health_scale
		component.default_health = BUFFER
		component.actual_health = BUFFER
	var health : float = component.actual_health
	var lost : float = _health - maxf(health, 0.0) if _health >= 0.0 else 0.0
	_health = maxf(health, 0.0)
	if (lost > 0.0):
		var best : String = "unknown"
		var best_distance : float = 200.0
		var source_x : float = escort.global_position.x
		for shot : Dictionary in _last + now:
			var distance : float = escort.global_position.distance_to(shot["pos"] as Vector2)
			if (distance < best_distance):
				best_distance = distance
				best = String(shot["key"])
				source_x = (shot["pos"] as Vector2).x
		if (buffered):
			if (best.ends_with("/AIR")):
				lost *= air_mult
			_virtual = maxf(_virtual - lost, 0.0)
			if (_virtual <= 0.0):
				component.actual_health = 0.0
		damage_by[best] = float(damage_by.get(best, 0.0)) + lost
		var bucket : String = str(clampi(int(progress * 4.0), 0, 3) * 25)
		damage_at[bucket] = float(damage_at.get(bucket, 0.0)) + lost
		total += lost
		var cover : bool = false
		var behind : bool = true
		for other : Entity in BattleContext.of(game).entities:
			if (other == escort or !other.enabled or other.destroyed):
				continue
			if (other.team_stats.team_id == 1):
				cover = cover or (!other.guns.is_empty() and other.global_position.x > escort.global_position.x)
			elif (other.global_position.x > escort.global_position.x):
				behind = false
		if (cover):
			covered += lost
		else:
			uncovered += lost
		if (behind):
			from_behind += lost
	_last = now

func report() -> Dictionary:
	return {"damage_by": damage_by, "damage_at": damage_at, "covered": covered, "uncovered": uncovered,
			"all_enemies_behind": from_behind, "total": total}
