extends Control

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const WATER_BODY := preload("res://scenes/game/misc/water_body.tscn")
const TEAM_ALLY := preload("res://core/resources/teams/team_left.tres")
const TEAM_FOE := preload("res://core/resources/teams/team_right.tres")
const VIEW := Vector2i(188, 88)
const WATER_Y: float = 368.0
const HULL_SINK: Dictionary = {"flak": 3.0, "destroyer": 3.0, "frigate": 3.0, "cruiser": 3.0}
const PLANE_LEASH_X: float = 100.0
const PLANE_LEASH_UP: float = 110.0
const PLANE_RETURN_TURN: float = 5.0
const PLANE_ALT_MIN: float = 100.0
const PLANE_ALT_MAX: float = 150.0
const PLANE_FLOOR: float = 70.0
const SUB_DEMO_DEPTH: float = 16.0
const FIELD_LEFT: float = -240.0
const FIELD_RIGHT: float = 660.0
const SPRING_GAP: int = 20
const START_X: float = 20.0
const DUMMY_X: float = 150.0
const RESET_DELAY: float = 1.6
const RUN_LIMIT: float = 22.0
const DUMMY_HEALTH: float = 1000000.0

var team_outlines: bool = true
var stats: EntityStats
var demo: StringName
var viewport: SubViewport
var camera: Camera2D
var sky_material: ShaderMaterial
var context: BattleContext
var bullets: BulletManager
var water: WaterBody
var unit: Entity
var dummies: Array[Entity] = []
var hittable: Array[bool] = []
var run_time: float
var end_timer: float
var water_screen_y: float = 55.0
var foe_still: TeamStats
var small_stats: BoatStats
var plane_stats: AirPlaneState
var sub_stats: BoatStats

const DIGITAL_OVERLAY := preload("res://shaders/digital_overlay.gdshader")

static func make_digital_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = DIGITAL_OVERLAY
	overlay_material.set_shader_parameter("dark_color", Color("#04131a"))
	overlay_material.set_shader_parameter("line_color", Color("#5fd9cf"))
	overlay.material = overlay_material
	overlay.resized.connect(func() -> void: overlay_material.set_shader_parameter("rect_size", overlay.size))
	return overlay

func _ready() -> void:
	small_stats = load("res://core/resources/boats/small_boat.tres") as BoatStats
	plane_stats = load("res://core/resources/boats/plane.tres") as AirPlaneState
	sub_stats = load("res://core/resources/boats/submarine.tres") as BoatStats
	foe_still = TEAM_FOE.duplicate() as TeamStats
	foe_still.direction = 0
	custom_minimum_size = Vector2(VIEW)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var shown := TextureRect.new()
	shown.texture = viewport.get_texture()
	shown.mouse_filter = MOUSE_FILTER_IGNORE
	shown.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(shown)
	shown.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	context = BattleContext.of(viewport)
	context.audio_enabled = false
	var backdrop := CanvasLayer.new()
	backdrop.layer = -10
	var sky := ColorRect.new()
	sky.size = Vector2(VIEW)
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("rect_size", Vector2(VIEW))
	sky.material = sky_material
	backdrop.add_child(sky)
	viewport.add_child(backdrop)
	water = WATER_BODY.instantiate() as WaterBody
	water.z_index = 200
	water.position = Vector2(FIELD_LEFT, WATER_Y)
	water.k = 0.01
	water.d = 0.08
	water.spread = 0.0001
	water.distance_between_springs = SPRING_GAP
	water.spring_number = int((FIELD_RIGHT - FIELD_LEFT) / SPRING_GAP) + 1
	water.depth = 100
	water.random_waves = false
	viewport.add_child(water)
	water.set_physics_process(false)
	bullets = BulletManager.new()
	viewport.add_child(bullets)
	camera = Camera2D.new()
	viewport.add_child(camera)
	camera.make_current()
	_aim_camera(Vector2(START_X + 60.0, WATER_Y))

func show_unit(value: EntityStats) -> void:
	stats = value
	_restart()

func set_demo(value: StringName) -> void:
	if demo != value:
		demo = value
		_restart()

func _reach(value: EntityStats) -> Dictionary:
	var result: Dictionary = {&"surface": false, &"air": false, &"sub": false}
	for slot_index: int in range(value.gun_slots.size()):
		var slot: GunSlot = value.gun_slots[slot_index]
		var gun_type: int = Global.gun_type_for(value.name, slot_index, slot)
		if gun_type < 0:
			continue
		var gun: Gun = (Enums.gun_scene(gun_type) as PackedScene).instantiate() as Gun
		result[&"surface"] = result[&"surface"] or gun.hits_surface
		result[&"air"] = result[&"air"] or gun.hits_air
		result[&"sub"] = result[&"sub"] or gun.hits_submerged
		gun.free()
	return result

func _clear() -> void:
	for node: Entity in context.entities.duplicate():
		if is_instance_valid(node):
			node.queue_free()
	for child: Node in bullets.get_children():
		child.queue_free()
	unit = null
	dummies.clear()
	hittable.clear()

func _restart() -> void:
	_clear()
	run_time = 0.0
	end_timer = 0.0
	if not stats:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var air: bool = stats is AirPlaneState
	water_screen_y = 78.0 if air else 56.0
	camera.zoom = Vector2.ONE * (0.5 if air else 1.0)
	var start_x: float = START_X if demo != &"weapons" else 70.0
	unit = UnitFactory.create(stats, TEAM_ALLY, bullets.handle_bullet_spawned, _on_destroy)
	unit.team_outline_enabled = team_outlines
	viewport.add_child(unit)
	unit.global_position = Vector2(start_x, _spawn_y(stats, false))
	var boat: BoatStats = stats as BoatStats
	if boat and boat.can_submerge:
		(unit as ShipEntity).dive_depth = SUB_DEMO_DEPTH
		(unit as ShipEntity).start_submerged(8.0)
	if demo == &"speed":
		return
	var reach: Dictionary = _reach(stats)
	var kinds: Array[StringName] = [&"surface"]
	if demo == &"targets":
		kinds = [&"surface", &"air", &"sub"]
	elif not reach[&"surface"]:
		var fallback: StringName = &"air" if reach[&"air"] else (&"sub" if reach[&"sub"] else &"surface")
		kinds = [fallback]
	for index: int in range(kinds.size()):
		_spawn_dummy(kinds[index], DUMMY_X + (-24.0 if kinds[index] == &"sub" else 0.0), bool(reach[kinds[index]]))

func _spawn_y(value: EntityStats, dummy: bool) -> float:
	if value is AirPlaneState:
		return WATER_Y - (46.0 if dummy else 90.0)
	var height: float = value.sprite.get_height() if value.sprite else 18.0
	return WATER_Y - height * 0.5 + 1.0 + float(HULL_SINK.get(value.name, 0.0))

func _keep_hull_in_water(entity: Entity) -> void:
	if not is_instance_valid(entity) or not entity is ShipEntity or entity.entity_stats == null:
		return
	var rest: float = _spawn_y(entity.entity_stats, false)
	if entity.global_position.y < rest:
		entity.global_position.y = rest
		if entity.linear_velocity.y < 0.0:
			entity.linear_velocity.y = 0.0

func _leash_plane(delta: float) -> void:
	if not stats is AirPlaneState or not is_instance_valid(unit) or dummies.is_empty():
		return
	var target: Vector2 = dummies[0].global_position
	var pos: Vector2 = unit.global_position
	var offset: Vector2 = pos - target
	var low: bool = pos.y > WATER_Y - PLANE_FLOOR
	if not low and absf(offset.x) <= PLANE_LEASH_X and offset.y >= -PLANE_LEASH_UP:
		return
	var wanted: float = -PI * 0.5
	if not low:
		var altitude: float = clampf(pos.y, WATER_Y - PLANE_ALT_MAX, WATER_Y - PLANE_ALT_MIN)
		wanted = (Vector2(target.x, altitude) - pos).angle()
	var step: float = PLANE_RETURN_TURN * delta
	unit.rotation += clampf(angle_difference(unit.rotation, wanted), -step, step)
	unit.angular_velocity = 0.0

func _dummy_stats(kind: StringName) -> BoatStats:
	var source: BoatStats = small_stats
	if kind == &"air":
		source = plane_stats
	elif kind == &"sub":
		source = sub_stats
	var copy: BoatStats = source.duplicate() as BoatStats
	copy.health = DUMMY_HEALTH
	if demo != &"damage" or kind != &"surface":
		var unarmed: Array[GunSlot] = []
		copy.gun_slots = unarmed
	return copy

func _spawn_dummy(kind: StringName, x: float, can_hit: bool) -> void:
	var dummy: Entity = UnitFactory.create(_dummy_stats(kind), foe_still, bullets.handle_bullet_spawned, _on_destroy)
	dummy.team_outline_enabled = team_outlines
	viewport.add_child(dummy)
	dummy.global_position = Vector2(x, _spawn_y(dummy.entity_stats, true))
	if kind == &"air":
		dummy.freeze = true
	elif kind == &"sub":
		(dummy as ShipEntity).start_submerged(22.0)
	dummies.append(dummy)
	hittable.append(can_hit)
	if demo == &"targets" and not can_hit:
		var mark := Label.new()
		mark.text = "X"
		mark.add_theme_color_override("font_color", Color("#ff5a52"))
		mark.add_theme_font_size_override("font_size", 8)
		mark.position = Vector2(-3, -34 if kind == &"air" else -22)
		mark.z_index = 300
		dummy.add_child(mark)

func _on_destroy(_pos: Vector2, _stats: EntityStats, _team: TeamStats) -> void:
	pass

func _alive(entity: Entity) -> bool:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return false
	var health: HealthComponent = entity.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.actual_health > 0.0

func _step_water(delta: float) -> void:
	water._physics_process(delta)
	var span: float = float(SPRING_GAP) * float(water.springs.size() - 1)
	var points := PackedVector2Array()
	var x: float = 0.0
	while x <= span:
		var local: float = x / float(SPRING_GAP)
		var index: int = mini(int(floorf(local)), water.springs.size() - 2)
		var smooth: float = (1.0 - cos((local - float(index)) * PI)) * 0.5
		points.append(Vector2(x, lerpf(water.springs[index].position.y, water.springs[index + 1].position.y, smooth)))
		x += 3.0
	points.append(Vector2(span, 400.0))
	points.append(Vector2(0.0, 400.0))
	water.water_polygon.polygon = points
	water.water_polygon.uv = points

func _physics_process(delta: float) -> void:
	_step_water(delta)
	if not stats or unit == null:
		return
	run_time += delta
	_keep_hull_in_water(unit)
	_leash_plane(delta)
	for dummy: Entity in dummies:
		_keep_hull_in_water(dummy)
		var health: HealthComponent = dummy.get_node_or_null("HealthComponent") as HealthComponent
		if is_instance_valid(dummy) and health:
			health.actual_health = health.default_health
	_follow_camera(delta)
	if _finished():
		end_timer += delta
		if end_timer >= RESET_DELAY:
			_restart()
	else:
		end_timer = 0.0

func _finished() -> bool:
	if run_time > RUN_LIMIT or not _alive(unit):
		return true
	if unit.global_position.x > FIELD_RIGHT - 80.0 or unit.global_position.x < FIELD_LEFT + 20.0 or unit.global_position.y > WATER_Y + 140.0:
		return true
	return false

func _follow_camera(_delta: float) -> void:
	var focus: Vector2 = unit.global_position if _alive(unit) else Vector2(float(VIEW.x) * 0.5, WATER_Y)
	for dummy: Entity in dummies:
		if _alive(dummy):
			focus = (focus + dummy.global_position) * 0.5
			break
	_aim_camera(focus)

func _aim_camera(focus: Vector2) -> void:
	var span: Vector2 = Vector2(VIEW) / camera.zoom.x
	var center_x: float = clampf(focus.x, FIELD_LEFT + span.x * 0.5, FIELD_RIGHT - span.x * 0.5)
	var lowest: float = WATER_Y - water_screen_y / camera.zoom.x + span.y * 0.5
	var center_y: float = lowest if not stats is AirPlaneState else minf(lowest, focus.y)
	camera.global_position = Vector2(roundf(center_x), roundf(center_y))
	sky_material.set_shader_parameter("horizon_y", (WATER_Y - (camera.global_position.y - span.y * 0.5)) * camera.zoom.x)
