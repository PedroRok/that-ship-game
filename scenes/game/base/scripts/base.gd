class_name Base
extends Node2D

@export
var team_stats : TeamStats

@onready
var base_center : Node2D = $BaseCenter

@onready
var art : Node2D

@export
var health_component : BaseHealthComponent

@export
var ship_constructor : ShipConstructor

var enabled : bool = true

const QUEUE_BASE_SIZE : int = 3
const QUEUE_STATS : Dictionary = {
	BaseDock.Type.NAVAL: &"queue_naval",
	BaseDock.Type.SUB: &"queue_sub",
	BaseDock.Type.AIR: &"queue_air",
}

var constructors : Dictionary = {}
var docks : Dictionary = {}
var queues : Dictionary = {}

var _base_sprites : Array[Sprite2D] = []
var _base_texture : Texture2D

var build_boost_mult : float = 1.0
var _destroyed : bool = false
var _max_health : float = 1.0
var _damage_material : ShaderMaterial

const DAMAGE_SHADER : Shader = preload("res://shaders/damage.tres")
const DAMAGE_MIN_DISSOLVE : float = 0.93
const DAMAGE_NOISE_SIZE : int = 128
const DAMAGE_NOISE_FREQUENCY : float = 0.22
const FIRE_MAX_AMOUNT : int = 90
const FIRE_MIN_RATIO : float = 0.3

var _fire : GPUParticles2D

signal death_event(team_stats : TeamStats)

signal spawn_ship_event(spawn_pos : Vector2, boat_stats : BoatStats, team_stats : TeamStats)

func _exit_tree() -> void:
	var context : BattleContext = BattleContext.of(self)
	if (context):
		context.remove_base(self)

func _ready() -> void:
	BattleContext.of(self).add_base(self)
	if (team_stats.team_id == 1):
		health_component.health = Global.modify(Enums.UpgradeTarget.BASE, &"base_health", health_component.health)
		if (health_component.label):
			health_component.label.text = str(health_component.health)
	health_component.death_event.connect(Callable(self, "_death_event"))
	_base_sprites = [$BaseSprite/BaseBackground as Sprite2D, $BaseSprite/base as Sprite2D]
	_base_texture = _base_sprites[0].texture
	_max_health = maxf(health_component.health, 1.0)
	_setup_damage_visual()
	constructors[BaseDock.Type.NAVAL] = ship_constructor
	for dock_type : BaseDock.Type in [BaseDock.Type.AIR, BaseDock.Type.SUB]:
		var dock : BaseDock = BaseDock.new()
		add_child(dock)
		dock.setup(dock_type, team_stats.direction < 0)
		docks[dock_type] = dock
		constructors[dock_type] = dock.constructor
	for dock_type : int in constructors:
		var constructor : ShipConstructor = constructors[dock_type]
		constructor.ship_build_finish.connect(_ship_build_finish.bind(constructor))
		queues[dock_type] = []

func _process(_delta : float) -> void:
	for dock_type : int in queues:
		var waiting : Array = queues[dock_type]
		if (waiting.is_empty() or _destroyed):
			continue
		if (dock_type != BaseDock.Type.NAVAL and !(docks[dock_type] as BaseDock).active):
			continue
		if (start_build_ship(waiting[0] as BoatStats)):
			waiting.pop_front()

func queue_capacity(dock_type : BaseDock.Type) -> int:
	return QUEUE_BASE_SIZE + int(Global.modify(Enums.UpgradeTarget.BASE, QUEUE_STATS[dock_type], 0.0))

func queue_used(dock_type : BaseDock.Type) -> int:
	var busy_slot : int = 1 if (constructors[dock_type] as ShipConstructor).is_building() else 0
	return busy_slot + (queues[dock_type] as Array).size()

func queue_has_room(dock_type : BaseDock.Type) -> bool:
	return queue_used(dock_type) < queue_capacity(dock_type)

func enqueue_ship(ship : BoatStats) -> bool:
	var dock_type : BaseDock.Type = dock_type_of(ship)
	if (_destroyed or !queue_has_room(dock_type)):
		return false
	if (dock_type != BaseDock.Type.NAVAL and !(docks[dock_type] as BaseDock).active):
		return false
	(queues[dock_type] as Array).append(ship)
	return true

func cancel_slot(dock_type : BaseDock.Type, slot : int) -> BoatStats:
	var constructor : ShipConstructor = constructors[dock_type]
	if (slot == 0 and constructor.is_building()):
		return constructor.cancel_build()
	var waiting : Array = queues[dock_type]
	var index : int = slot - 1
	if (index < 0 or index >= waiting.size()):
		return null
	var ship : BoatStats = waiting[index]
	waiting.remove_at(index)
	return ship

func distance_from(point : Vector2) -> float:
	var shape_node : CollisionShape2D = get_node_or_null("BaseHitboxComponent/CollisionShape2D") as CollisionShape2D
	var rect : RectangleShape2D = shape_node.shape as RectangleShape2D if shape_node else null
	if (!rect):
		return base_center.global_position.distance_to(point)
	var xf : Transform2D = shape_node.global_transform
	var local : Vector2 = xf.affine_inverse() * point
	var outside : Vector2 = (local.abs() - rect.size * 0.5).max(Vector2.ZERO)
	return (outside * xf.get_scale()).length()

func get_center_pos() -> Vector2:
	return base_center.global_position

func _setup_damage_visual() -> void:
	var noise : FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = DAMAGE_NOISE_FREQUENCY
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var texture : NoiseTexture2D = NoiseTexture2D.new()
	texture.width = DAMAGE_NOISE_SIZE
	texture.height = DAMAGE_NOISE_SIZE
	texture.as_normal_map = true
	texture.bump_strength = 32.0
	texture.noise = noise
	_damage_material = ShaderMaterial.new()
	_damage_material.shader = DAMAGE_SHADER
	_damage_material.set_shader_parameter("Noise", texture)
	_damage_material.set_shader_parameter("dissolve", 1.0)
	for sprite : Sprite2D in _base_sprites:
		sprite.material = _damage_material
	_setup_fire()

func _setup_fire() -> void:
	var shape_node : CollisionShape2D = get_node_or_null("BaseHitboxComponent/CollisionShape2D") as CollisionShape2D
	var rect : RectangleShape2D = shape_node.shape as RectangleShape2D if shape_node else null
	if (rect == null):
		return
	var ramp : Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.82, 0.25, 1.0), Color(0.95, 0.35, 0.08, 0.9), Color(0.15, 0.1, 0.1, 0.0)])
	var ramp_texture : GradientTexture1D = GradientTexture1D.new()
	ramp_texture.gradient = ramp
	var process : ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(rect.size.x * 0.5, rect.size.y * 0.5, 1.0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 25.0
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 28.0
	process.gravity = Vector3(0, -18, 0)
	process.scale_min = 1.8
	process.scale_max = 3.8
	process.color_ramp = ramp_texture
	_fire = GPUParticles2D.new()
	_fire.process_material = process
	_fire.amount = FIRE_MAX_AMOUNT
	_fire.amount_ratio = 0.0
	_fire.lifetime = 1.1
	_fire.z_index = 1100
	_fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fire.position = shape_node.position
	_fire.visibility_rect = Rect2(-200, -200, 400, 400)
	add_child(_fire)

func update_damage_visual() -> void:
	if (_damage_material == null):
		return
	var ratio : float = clampf(health_component.health / _max_health, 0.0, 1.0)
	_damage_material.set_shader_parameter("dissolve", lerpf(1.0, DAMAGE_MIN_DISSOLVE, 1.0 - ratio))
	if (_fire):
		var damaged : bool = ratio < 1.0
		_fire.emitting = damaged
		_fire.amount_ratio = lerpf(FIRE_MIN_RATIO, 1.0, 1.0 - ratio) if damaged else 0.0

func _death_event() -> void:
	if (!_destroyed):
		_destroyed = true
		var audio : BattleAudio = BattleAudio.of(self)
		if (audio):
			audio.stop_all_builds_for(self)
			audio.play(&"base_break", get_center_pos(), self)
	death_event.emit(team_stats)
	
static func dock_type_of(stats : EntityStats) -> BaseDock.Type:
	if (stats is AirPlaneState):
		return BaseDock.Type.AIR
	var boat : BoatStats = stats as BoatStats
	if (boat and boat.can_submerge):
		return BaseDock.Type.SUB
	return BaseDock.Type.NAVAL

func start_build_ship(ship : BoatStats) -> bool:
	var dock_type : BaseDock.Type = dock_type_of(ship)
	var constructor : ShipConstructor = constructors[dock_type]
	if (constructor.is_building()): return false
	if (docks.has(dock_type) and (docks[dock_type] as BaseDock).busy): return false
	var time_mult : float = 1.0
	if (team_stats.team_id == 1):
		time_mult = Global.modify(Enums.UpgradeTarget.BASE, &"build_time", 1.0)
	var duration_mult : float = time_mult * build_boost_mult
	constructor.build_ship(ship, duration_mult)
	if (docks.has(dock_type)):
		(docks[dock_type] as BaseDock).begin_build()
	return true

func _ship_build_finish(ship : BoatStats, constructor : ShipConstructor) -> void:
	var dock : BaseDock = null
	for candidate : BaseDock in docks.values():
		if (candidate.constructor == constructor):
			dock = candidate
	if (dock and dock.has_door()):
		await dock.open_for_exit()
	var launch_at : Vector2 = constructor.spawn_position()
	spawn_ship_event.emit(launch_at, ship, team_stats)
	var launch : StringName = SfxCatalog.launch_event(ship)
	if (launch != &""):
		BattleAudio.play_at(self, launch, launch_at, constructor)
	constructor.release_ship()
	if (dock):
		var travel : float = (BaseDock.EXIT_DISTANCE / maxf(ship.speed, 1.0) * 1.8) if ship else BaseDock.EXIT_WAIT
		dock.close_after_exit(clampf(travel, BaseDock.EXIT_WAIT, 8.0))

func apply_build_boost(mult : float, duration : float) -> void:
	build_boost_mult = mult
	get_tree().create_timer(duration).timeout.connect(func() -> void: build_boost_mult = 1.0)

func get_spawn_point() -> Vector2:
	return ship_constructor.global_position

func show_docks_for(units : Array) -> void:
	var air : bool = false
	var sub : bool = false
	for unit : Variant in units:
		var stats : EntityStats = unit as EntityStats
		if (!stats or stats.is_boss):
			continue
		match dock_type_of(stats):
			BaseDock.Type.AIR: air = true
			BaseDock.Type.SUB: sub = true
	var changed : bool = (docks[BaseDock.Type.AIR] as BaseDock).active != air 			or (docks[BaseDock.Type.SUB] as BaseDock).active != sub
	(docks[BaseDock.Type.AIR] as BaseDock).set_active(air)
	(docks[BaseDock.Type.SUB] as BaseDock).set_active(sub)
	if (changed):
		refresh_base_art()

func set_base_texture(texture : Texture2D) -> void:
	_base_texture = texture
	refresh_base_art()

func refresh_base_art() -> void:
	var active_docks : Array[BaseDock] = []
	for dock : BaseDock in docks.values():
		if (dock.active):
			active_docks.append(dock)
	if (active_docks.is_empty()):
		for sprite : Sprite2D in _base_sprites:
			sprite.texture = _base_texture
		return
	var silhouette : Image = _base_texture.get_image()
	if (silhouette.is_compressed()):
		silhouette.decompress()
	silhouette.convert(Image.FORMAT_RGBA8)
	var img : Image = silhouette.duplicate()
	for dock : BaseDock in active_docks:
		dock.cut_into(img, silhouette, _base_sprites[0].position, _base_sprites[0].flip_h)
	var cut_texture : ImageTexture = ImageTexture.create_from_image(img)
	for sprite : Sprite2D in _base_sprites:
		sprite.texture = cut_texture
