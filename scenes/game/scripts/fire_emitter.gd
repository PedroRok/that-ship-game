class_name FireEmitter
extends Node2D

const MIN_SPOTS : int = 2
const MAX_SPOTS : int = 16
const SPOT_GAP : float = 24.0
const FLAMES_PER_SPOT : float = 130.0
const PLUMES_PER_SPOT : float = 12.0
const UNIT_MIN_SPOTS : int = 1
const UNIT_MAX_SPOTS : int = 4
const UNIT_SPOT_GAP : float = 8.0
const UNIT_FLAMES_PER_SPOT : float = 34.0
const UNIT_PLUMES_PER_SPOT : float = 6.0
const UNIT_CANDIDATES : int = 40

var small : bool = false
var min_spots : int = MIN_SPOTS
var max_spots : int = MAX_SPOTS
var spot_gap : float = SPOT_GAP
var flames_per_spot : float = FLAMES_PER_SPOT
var plumes_per_spot : float = PLUMES_PER_SPOT
var spots : PackedVector2Array = PackedVector2Array()
var intensity : float = 0.0

var _flames : float = 0.0
var _plumes : float = 0.0

static func for_unit(size : Vector2) -> FireEmitter:
	var emitter : FireEmitter = FireEmitter.new()
	emitter.small = true
	emitter.min_spots = UNIT_MIN_SPOTS
	emitter.max_spots = UNIT_MAX_SPOTS
	emitter.spot_gap = UNIT_SPOT_GAP
	emitter.flames_per_spot = UNIT_FLAMES_PER_SPOT
	emitter.plumes_per_spot = UNIT_PLUMES_PER_SPOT
	var points : PackedVector2Array = PackedVector2Array()
	for _index : int in UNIT_CANDIDATES:
		points.append(Vector2(randf_range(-0.4, 0.4) * size.x, randf_range(-0.4, 0.1) * size.y))
	emitter.set_area(points)
	return emitter

func set_area(points : PackedVector2Array) -> void:
	var order : Array = Array(points)
	order.shuffle()
	spots.clear()
	for item : Variant in order:
		var point : Vector2 = item
		var crowded : bool = false
		for spot : Vector2 in spots:
			crowded = crowded or spot.distance_to(point) < spot_gap
		if (!crowded):
			spots.append(point)
		if (spots.size() >= max_spots):
			return

func active_spots() -> int:
	if (intensity <= 0.0):
		return 0
	return mini(roundi(lerpf(min_spots, max_spots, intensity)), spots.size())

func _process(delta : float) -> void:
	var active : int = active_spots()
	if (active == 0 or !is_visible_in_tree()):
		return
	var rate : float = delta * float(active) * GameSettings.effects_scale()
	_flames += rate * flames_per_spot
	_plumes += rate * plumes_per_spot
	var world : Node = _world()
	while (_flames >= 1.0):
		_flames -= 1.0
		GrainParticles.flame(world, to_global(spots[randi() % active]), small)
	while (_plumes >= 1.0):
		_plumes -= 1.0
		GrainParticles.plume(world, to_global(spots[randi() % active]), small)

func _world() -> Node:
	var node : Node = self
	while (node is FireEmitter or node is ParticlesComponent or node is Entity or node is Base):
		node = node.get_parent()
	return node
