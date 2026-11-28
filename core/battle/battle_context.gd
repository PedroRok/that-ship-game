class_name BattleContext
extends RefCounted

const META: StringName = &"battle_context"

var entities: Array[Entity] = []
var bases: Array[Base] = []
var bullets: BulletManager
var flak_smoke : Node
var audio_enabled: bool = true
var audio: BattleAudio
var patrol_x: float = NAN

func has_patrol() -> bool:
	return not is_nan(patrol_x)

func outside_patrol(node: Node2D) -> bool:
	return has_patrol() and absf(node.global_position.x - patrol_x) > RunData.PATROL_RADIUS + RunData.PATROL_SLACK

static func of(node: Node) -> BattleContext:
	var viewport: Viewport = node.get_viewport()
	if viewport == null:
		return null
	if viewport.has_meta(META):
		return viewport.get_meta(META) as BattleContext
	var context := BattleContext.new()
	viewport.set_meta(META, context)
	return context

func add_entity(entity: Entity) -> void:
	if not entities.has(entity):
		entities.append(entity)

func remove_entity(entity: Entity) -> void:
	entities.erase(entity)

func add_base(base: Base) -> void:
	if not bases.has(base):
		bases.append(base)

func remove_base(base: Base) -> void:
	bases.erase(base)
