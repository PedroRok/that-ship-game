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

var constructors : Dictionary = {}
var docks : Dictionary = {}

var _base_sprites : Array[Sprite2D] = []
var _base_texture : Texture2D

var build_boost_mult : float = 1.0

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

func get_center_pos() -> Vector2:
	return base_center.global_position

func _death_event() -> void:
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
	spawn_ship_event.emit(constructor.spawn_position(), ship, team_stats)
	constructor.release_ship()
	if (dock):
		# tempo para o sub atravessar a doca inteira antes de fechar a porta
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
