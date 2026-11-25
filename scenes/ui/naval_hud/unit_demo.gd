extends Control

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const WATER_BODY := preload("res://scenes/game/misc/water_body.tscn")
const VIEW := Vector2i(188, 88)
const WATER_Y: float = 55.0
const SPRING_GAP: float = 30.0
const START_X: float = 8.0
const DUMMY_X: float = 164.0
const SPEED_SCALE: float = 0.12
const FIGHT_MODES: Array[StringName] = [&"weapons", &"damage", &"targets"]

class Body:
	var sprite: Sprite2D
	var kind: StringName = &"surface"
	var x: float = 0.0
	var y: float = 0.0
	var hp: float = 1.0
	var max_hp: float = 1.0
	var alive: bool = true
	var sinking: float = 0.0
	var colpos_y: float = 0.0
	var half_w: float = 10.0
	var rot: float = 0.0
	var free_flight: bool = false

var SMALL: BoatStats
var PLANE: AirPlaneState
var SUBMARINE: BoatStats
var stats: EntityStats
var demo: StringName
var time: float
var viewport: SubViewport
var water: WaterBody
var overlay: Node2D
var unit: Body
var dummies: Array[Body] = []
var weapons: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var phase: StringName = &"approach"
var phase_timer: float
var retaliate_timer: float
var wake_timer: float
var ambient_timer: float
var engage_x: float = 100.0
var dummy_x: float = DUMMY_X
var plane_pass: float
var blade_sprites: Array[Sprite2D] = []
var move_speed: float = 30.0

func _ready() -> void:
	SMALL = load("res://core/resources/boats/small_boat.tres") as BoatStats
	PLANE = load("res://core/resources/boats/plane.tres") as AirPlaneState
	SUBMARINE = load("res://core/resources/boats/submarine.tres") as BoatStats
	custom_minimum_size = Vector2(VIEW)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var shown := TextureRect.new()
	shown.texture = viewport.get_texture()
	shown.mouse_filter = MOUSE_FILTER_IGNORE
	shown.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(shown)
	shown.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.size = Vector2(VIEW)
	sky.z_index = -1800
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("rect_size", Vector2(VIEW))
	sky_material.set_shader_parameter("horizon_y", WATER_Y)
	sky.material = sky_material
	viewport.add_child(sky)
	water = WATER_BODY.instantiate() as WaterBody
	water.z_index = 200
	water.position = Vector2(-10, WATER_Y)
	water.k = 0.01
	water.d = 0.08
	water.spread = 0.0001
	water.distance_between_springs = int(SPRING_GAP)
	water.spring_number = 8
	water.depth = 60
	water.random_waves = false
	viewport.add_child(water)
	water.set_physics_process(false)
	overlay = Node2D.new()
	overlay.z_index = 300
	overlay.draw.connect(_draw_overlay)
	viewport.add_child(overlay)
	unit = _make_body(null, false, Color.WHITE)

func _make_body(texture: Texture2D, flip: bool, tint: Color) -> Body:
	var body := Body.new()
	body.sprite = Sprite2D.new()
	body.sprite.texture = texture
	body.sprite.flip_h = flip
	body.sprite.modulate = tint
	body.sprite.z_index = 0
	viewport.add_child(body.sprite)
	if texture:
		body.half_w = texture.get_width() * 0.5
	return body

func _free_dummies() -> void:
	for dummy: Body in dummies:
		dummy.sprite.queue_free()
	dummies.clear()

func _sprite_of(value: EntityStats) -> Texture2D:
	if value is AirPlaneState and not (value as AirPlaneState).body_frames.is_empty():
		return UnitIcon.of(value as AirPlaneState)
	var boat: BoatStats = value as BoatStats
	if boat and boat.can_submerge and boat.submerged_sprite:
		return boat.submerged_sprite
	return value.sprite

func _weapons_of(value: EntityStats) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot_index: int in range(value.gun_slots.size()):
		var slot: GunSlot = value.gun_slots[slot_index]
		var gun_type: int = Global.gun_type_for(value.name, slot_index, slot)
		if gun_type < 0:
			continue
		var gun: Gun = (Enums.gun_scene(gun_type) as PackedScene).instantiate() as Gun
		var damage: float = 1.0
		var speed: float = 300.0
		var inst: Node = gun.bullet.instantiate() if gun.bullet else null
		if inst is Bullet:
			var bullet: Bullet = inst as Bullet
			if bullet.damage:
				damage = bullet.damage.damage * gun.damage_scale
			speed = maxf(1.0, bullet.bullet_stats.speed * gun.bullet_speed_scale) * 60.0
		if inst:
			inst.free()
		out.append({
			"range": gun.effective_range(),
			"interval": maxf(0.3, gun.time_to_shoot / 60.0),
			"damage": damage,
			"air": gun.hits_air,
			"surface": gun.hits_surface,
			"sub": gun.hits_submerged,
			"speed": clampf(speed * 0.35, 70.0, 200.0),
			"texture": gun.projectile_texture,
			"cd": randf() * 0.4,
		})
		gun.free()
	return out

func show_unit(value: EntityStats) -> void:
	stats = value
	for blade: Sprite2D in blade_sprites:
		blade.queue_free()
	blade_sprites.clear()
	unit.sprite.texture = _sprite_of(value) if value else null
	unit.free_flight = value is AirPlaneState
	unit.sprite.flip_v = false
	if value is AirPlaneState:
		var plane: AirPlaneState = value as AirPlaneState
		if plane.blade_frames.size() == 7 and plane.prop_far.size() == 5 and plane.prop_near.size() == 5:
			for i: int in range(2):
				var blade := Sprite2D.new()
				blade.texture = plane.blade_frames[0]
				unit.sprite.add_child(blade)
				blade_sprites.append(blade)
	if value:
		unit.half_w = unit.sprite.texture.get_width() * 0.5
		var boat: BoatStats = value as BoatStats
		unit.colpos_y = boat.water_colision_pos.y if boat else 0.0
		unit.kind = &"air" if value is AirPlaneState else (&"sub" if boat and boat.can_submerge else &"surface")
		weapons = _weapons_of(value)
		move_speed = clampf(value.speed * SPEED_SCALE, 14.0, 70.0)
	else:
		weapons.clear()
	_reset()

func set_demo(value: StringName) -> void:
	if demo != value:
		demo = value
		_reset()

func _max_range() -> float:
	var reach: float = 0.0
	for weapon: Dictionary in weapons:
		reach = maxf(reach, float(weapon["range"]))
	return reach

func _can_hit(weapon: Dictionary, dummy: Body) -> bool:
	return bool(weapon["air"]) if dummy.kind == &"air" else (bool(weapon["sub"]) if dummy.kind == &"sub" else bool(weapon["surface"]))

func _any_can_hit(dummy: Body) -> bool:
	for weapon: Dictionary in weapons:
		if _can_hit(weapon, dummy):
			return true
	return false

func _spawn_dummies() -> void:
	_free_dummies()
	if not stats:
		return
	var best: float = 1.0
	for weapon: Dictionary in weapons:
		best = maxf(best, float(weapon["damage"]))
	var kinds: Array[StringName] = [&"surface"]
	if demo == &"targets":
		kinds = [&"surface", &"air", &"sub"]
	else:
		var probe: Body = Body.new()
		probe.kind = &"surface"
		if not _any_can_hit(probe):
			probe.kind = &"air"
			kinds = [&"air"] if _any_can_hit(probe) else ([&"sub"] if _sub_hittable() else [&"surface"])
	var offsets: Dictionary = {&"surface": 0.0, &"air": -18.0, &"sub": -40.0}
	for kind: StringName in kinds:
		var texture: Texture2D = SMALL.sprite
		var colpos: float = SMALL.water_colision_pos.y
		if kind == &"air":
			texture = PLANE.body_frames[0] if not PLANE.body_frames.is_empty() else PLANE.sprite
			colpos = 0.0
		elif kind == &"sub":
			texture = SUBMARINE.submerged_sprite if SUBMARINE.submerged_sprite else SUBMARINE.sprite
			colpos = 0.0
		var dummy: Body = _make_body(texture, true, Color(1.0, 0.62, 0.6))
		dummy.kind = kind
		dummy.x = dummy_x + float(offsets[kind]) if demo == &"targets" else dummy_x
		dummy.colpos_y = colpos
		dummy.max_hp = best * 5.0
		dummy.hp = dummy.max_hp
		dummy.y = WATER_Y
		dummies.append(dummy)

func _sub_hittable() -> bool:
	for weapon: Dictionary in weapons:
		if bool(weapon["sub"]):
			return true
	return false

func _reset() -> void:
	projectiles.clear()
	flashes.clear()
	bubbles.clear()
	retaliate_timer = 1.2
	phase_timer = 0.0
	if not stats:
		_free_dummies()
		return
	unit.alive = true
	unit.sinking = 0.0
	unit.max_hp = maxf(1.0, stats.health)
	unit.hp = unit.max_hp
	unit.sprite.modulate = Color.WHITE
	var reach: float = _max_range()
	dummy_x = 120.0 if unit.free_flight else DUMMY_X
	engage_x = dummy_x - clampf(reach * 0.25, 46.0, 80.0)
	unit.rot = 0.0
	plane_pass = 0.0
	if demo == &"speed":
		_free_dummies()
		phase = &"sail"
		unit.x = START_X + unit.half_w
	else:
		_spawn_dummies()
		phase = &"fight" if (demo in FIGHT_MODES or unit.free_flight) else &"approach"
		unit.x = engage_x if (phase == &"fight" and not unit.free_flight) else START_X + unit.half_w + (6.0 if unit.free_flight else 0.0)
	unit.y = _unit_rest_y()
	if unit.free_flight:
		unit.y = WATER_Y - 34.0
	_place(unit, 1.0)

func _unit_rest_y() -> float:
	if unit.kind == &"air":
		return WATER_Y - 26.0
	if unit.kind == &"sub":
		return WATER_Y + 12.0
	return _surface(unit.x) - unit.sprite.texture.get_height() * 0.5 + 1.0

func _surface(x: float) -> float:
	var local: float = (x - water.position.x) / SPRING_GAP
	var index: int = clampi(int(floorf(local)), 0, water.springs.size() - 2)
	var frac: float = clampf(local - float(index), 0.0, 1.0)
	var a: float = water.springs[index].position.y
	var b: float = water.springs[index + 1].position.y
	return water.position.y + lerpf(a, b, frac)

func _splash(x: float, power: float) -> void:
	var index: int = clampi(roundi((x - water.position.x) / SPRING_GAP), 1, water.springs.size() - 2)
	water.splash(index, -absf(power))

func _place(body: Body, follow: float) -> void:
	if not body.sprite.texture:
		return
	var target_y: float = WATER_Y
	if body.free_flight:
		body.sprite.position = Vector2(roundf(body.x), roundf(body.y))
		body.sprite.rotation = body.rot
		if body.sinking > 0.0:
			body.y += body.sinking
			body.sinking += 0.35
			body.sprite.modulate.a = maxf(0.0, 1.0 - body.sinking / 24.0)
		return
	if body.kind == &"air":
		target_y = WATER_Y - 26.0 + sin(time * 2.2 + body.x * 0.05) * 2.0
		body.rot = lerpf(body.rot, 0.0, 0.2)
	elif body.kind == &"sub":
		target_y = WATER_Y + 12.0 + sin(time * 1.3) * 1.0
		body.rot = 0.0
	else:
		target_y = _surface(body.x) - body.sprite.texture.get_height() * 0.5 + 1.0
		var slope: float = (_surface(body.x + 8.0) - _surface(body.x - 8.0)) / 16.0
		body.rot = lerpf(body.rot, clampf(atan(slope) * 1.5, -0.3, 0.3), 0.25)
	body.y = lerpf(body.y, target_y, follow if body.sinking == 0.0 else 0.0) + body.sinking
	if body.sinking > 0.0:
		body.sinking += 0.35
		body.sprite.modulate.a = maxf(0.0, 1.0 - body.sinking / 24.0)
	body.sprite.position = Vector2(roundf(body.x), roundf(body.y))
	body.sprite.rotation = body.rot

func _fire_from(origin: Vector2, target: Body, damage: float, speed: float, texture: Texture2D, from_unit: bool) -> void:
	var aim: Vector2 = Vector2(target.x, target.y)
	projectiles.append({"pos": origin, "dir": (aim - origin).normalized(), "speed": speed, "damage": damage, "target": target, "tex": texture, "mine": from_unit})
	flashes.append({"pos": origin, "life": 3})

func _step_water(delta: float) -> void:
	water._physics_process(delta)
	var points := PackedVector2Array()
	var span: float = SPRING_GAP * float(water.springs.size() - 1)
	var x: float = 0.0
	while x <= span:
		var local: float = x / SPRING_GAP
		var index: int = mini(int(floorf(local)), water.springs.size() - 2)
		var frac: float = local - float(index)
		var smooth: float = (1.0 - cos(frac * PI)) * 0.5
		points.append(Vector2(x, lerpf(water.springs[index].position.y, water.springs[index + 1].position.y, smooth)))
		x += 3.0
	points.append(Vector2(span, 200.0))
	points.append(Vector2(0.0, 200.0))
	water.water_polygon.polygon = points
	water.water_polygon.uv = points

func _physics_process(delta: float) -> void:
	_step_water(delta)
	time += delta
	ambient_timer -= delta
	if ambient_timer <= 0.0:
		ambient_timer = randf_range(0.7, 1.6)
		_splash(randf_range(10.0, 180.0), 0.12)
	if not stats or not unit.sprite.texture:
		unit.sprite.hide()
		overlay.queue_redraw()
		return
	unit.sprite.show()
	_update_unit(delta)
	for dummy: Body in dummies:
		_update_dummy(dummy)
	_update_projectiles(delta)
	_update_effects()
	overlay.queue_redraw()

func _update_unit(delta: float) -> void:
	var moving: bool = false
	if unit.alive and unit.free_flight and phase != &"sail":
		_update_plane(delta)
	elif unit.alive:
		if phase == &"approach" or phase == &"sail":
			unit.x += move_speed * delta
			moving = true
			if phase == &"approach" and unit.x >= engage_x:
				unit.x = engage_x
				phase = &"fight"
			elif phase == &"sail" and unit.x >= float(VIEW.x) - unit.half_w - 4.0:
				phase_timer += delta
				unit.x = START_X + unit.half_w
		elif phase == &"fight":
			_unit_fire(delta)
		if demo == &"damage":
			_dummy_retaliate(delta)
	elif phase_timer > 0.0:
		pass
	if moving and unit.kind == &"surface":
		wake_timer -= delta
		if wake_timer <= 0.0:
			wake_timer = 0.12
			_splash(unit.x - unit.half_w, 0.18)
			bubbles.append({"pos": Vector2(unit.x - unit.half_w, _surface(unit.x - unit.half_w) + 1.0), "life": 24})
	_place(unit, 0.35)
	if unit.free_flight:
		_plane_visuals()
	if unit.sinking > 24.0:
		_next_round()

func _update_plane(delta: float) -> void:
	var target: Body = null
	for dummy: Body in dummies:
		if dummy.alive and _any_can_hit(dummy):
			target = dummy
			break
	var heading: float = unit.rot
	var desired: float = 0.0 if unit.x < float(VIEW.x) * 0.5 else PI
	if target:
		var to_target: Vector2 = Vector2(target.x, target.y) - Vector2(unit.x, unit.y)
		desired = to_target.angle()
		var trigger: float = 34.0
		if to_target.length() < trigger and plane_pass <= 0.0:
			plane_pass = 1.5
		if plane_pass > 0.0:
			plane_pass -= delta
			desired = -0.5 if cos(heading) >= 0.0 else PI + 0.5
	if unit.y > WATER_Y - 14.0 and sin(heading) > -0.2:
		desired = -0.9 if cos(heading) >= 0.0 else PI + 0.9
	if unit.x > float(VIEW.x) - 18.0 and cos(heading) > 0.0:
		desired = PI - 0.4
	elif unit.x < 18.0 and cos(heading) < 0.0:
		desired = 0.4
	var turn: float = clampf(angle_difference(heading, desired), -2.2 * delta, 2.2 * delta)
	unit.rot = wrapf(heading + turn, -PI, PI)
	var velocity: float = clampf(stats.speed * 0.15, 28.0, 80.0)
	unit.x += cos(unit.rot) * velocity * delta
	unit.y += sin(unit.rot) * velocity * delta
	_unit_fire(delta)
	if demo == &"damage":
		_dummy_retaliate(delta)
	_plane_visuals()

func _plane_visuals() -> void:
	var plane: AirPlaneState = stats as AirPlaneState
	if not plane or plane.body_frames.size() != 5:
		return
	var degrees: float = fposmod(rad_to_deg(unit.rot), 360.0)
	var frame: int = clampi(int(5.0 * absf(sin(deg_to_rad(degrees)))), 0, 4)
	var down: bool = degrees > 90.0 and degrees < 270.0
	unit.sprite.texture = plane.body_frames[frame]
	unit.sprite.flip_v = down
	if blade_sprites.size() == 2:
		var flip: float = -1.0 if down else 1.0
		var blade_frame: int = int(time * 20.0) % 7
		var anchors: Array[Vector2] = [plane.prop_far[frame], plane.prop_near[frame]]
		for i: int in range(2):
			blade_sprites[i].texture = plane.blade_frames[blade_frame]
			blade_sprites[i].position = Vector2(anchors[i].x, anchors[i].y * flip)

func _unit_fire(delta: float) -> void:
	for weapon: Dictionary in weapons:
		weapon["cd"] = float(weapon["cd"]) - delta
		if float(weapon["cd"]) > 0.0:
			continue
		for dummy: Body in dummies:
			if dummy.alive and _can_hit(weapon, dummy) and _in_reach(weapon, dummy):
				weapon["cd"] = float(weapon["interval"])
				_fire_from(Vector2(unit.x, unit.y) + (Vector2.from_angle(unit.rot) * unit.half_w if unit.free_flight else Vector2(unit.half_w, -2.0)), dummy, float(weapon["damage"]), float(weapon["speed"]), weapon["texture"] as Texture2D, true)
				_splash(unit.x, 0.1)
				break

func _in_reach(weapon: Dictionary, dummy: Body) -> bool:
	if not unit.free_flight:
		return true
	var offset: Vector2 = Vector2(dummy.x - unit.x, dummy.y - unit.y)
	var short: bool = float(weapon["range"]) < 70.0
	var facing: bool = absf(angle_difference(unit.rot, offset.angle())) < 0.7
	return offset.length() < maxf(46.0, float(weapon["range"]) * 0.25) and (facing or short)

func _dummy_retaliate(delta: float) -> void:
	retaliate_timer -= delta
	if retaliate_timer > 0.0 or dummies.is_empty():
		return
	retaliate_timer = 1.3
	_fire_from(Vector2(dummies[0].x - dummies[0].half_w, dummies[0].y - 2.0), unit, unit.max_hp / 5.0, 110.0, null, false)

func _update_dummy(dummy: Body) -> void:
	if dummy.kind == &"air":
		dummy.x = dummy_x - 18.0 + sin(time * 0.8) * 10.0 if demo == &"targets" else dummy_x + sin(time * 0.8) * 8.0
	if demo == &"damage" and dummy.alive:
		dummy.hp = dummy.max_hp
	_place(dummy, 0.35)

func _update_projectiles(delta: float) -> void:
	var alive_projectiles: Array[Dictionary] = []
	for shot: Dictionary in projectiles:
		var target: Body = shot["target"] as Body
		var pos: Vector2 = shot["pos"]
		var aim: Vector2 = Vector2(target.x, target.y)
		var direction: Vector2 = (aim - pos).normalized()
		pos += direction * float(shot["speed"]) * delta
		shot["pos"] = pos
		shot["dir"] = direction
		if pos.distance_to(aim) <= 5.0:
			_hit(target, float(shot["damage"]), bool(shot["mine"]))
		else:
			alive_projectiles.append(shot)
	projectiles = alive_projectiles

func _hit(target: Body, damage: float, mine: bool) -> void:
	if not target.alive:
		return
	target.hp -= damage
	flashes.append({"pos": Vector2(target.x, target.y), "life": 4})
	if target.kind == &"surface":
		_splash(target.x, 0.25)
	if target.hp <= 0.0:
		target.alive = false
		target.sinking = 0.01
		_splash(target.x, 0.8)
		if mine:
			phase_timer = 0.0
	if target == unit and not unit.alive:
		phase = &"dead"

func _update_effects() -> void:
	for dummy: Body in dummies:
		if dummy.sinking > 24.0:
			dummy.sprite.hide()
	var all_dead: bool = not dummies.is_empty()
	for dummy: Body in dummies:
		if dummy.alive and _any_can_hit(dummy):
			all_dead = false
	if all_dead and phase != &"dead":
		phase_timer += 1.0 / 60.0
		if phase_timer > 1.2:
			_next_round()
	var kept: Array[Dictionary] = []
	for bubble: Dictionary in bubbles:
		bubble["life"] = int(bubble["life"]) - 1
		bubble["pos"] = (bubble["pos"] as Vector2) + Vector2(-0.4, -0.15)
		if int(bubble["life"]) > 0:
			kept.append(bubble)
	bubbles = kept
	var kept_flashes: Array[Dictionary] = []
	for flash: Dictionary in flashes:
		flash["life"] = int(flash["life"]) - 1
		if int(flash["life"]) > 0:
			kept_flashes.append(flash)
	flashes = kept_flashes

func _next_round() -> void:
	_reset()

func _draw_overlay() -> void:
	for bubble: Dictionary in bubbles:
		var p: Vector2 = bubble["pos"]
		overlay.draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(0.9, 0.97, 1.0, float(bubble["life"]) / 24.0))
	for shot: Dictionary in projectiles:
		var p: Vector2 = shot["pos"]
		var texture: Texture2D = shot["tex"] as Texture2D
		var direction: Vector2 = shot["dir"]
		if texture:
			overlay.draw_set_transform(p.round(), direction.angle(), Vector2.ONE)
			overlay.draw_texture(texture, Vector2(0, -floorf(texture.get_height() * 0.5)))
			overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			overlay.draw_rect(Rect2(p.round() - Vector2(2, 1), Vector2(4, 2)), Color("#ffca65"))
	for flash: Dictionary in flashes:
		var p: Vector2 = flash["pos"]
		overlay.draw_rect(Rect2(p.round() - Vector2(2, 2), Vector2(4, 4)), Color("#fff2b0"))
	for dummy: Body in dummies:
		if dummy.alive:
			_bar(dummy, Color("#eb6862"))
			if demo == &"targets" and not _any_can_hit(dummy):
				var c: Vector2 = Vector2(dummy.x, dummy.y - 8.0).round()
				overlay.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color("#ff5a52"), 1.0)
				overlay.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), Color("#ff5a52"), 1.0)
	if unit.alive and demo == &"damage":
		_bar(unit, Color("#a4d7d4"))

func _bar(body: Body, color: Color) -> void:
	var width: float = 16.0
	var origin: Vector2 = Vector2(roundf(body.x - width * 0.5), roundf(body.y - 14.0))
	overlay.draw_rect(Rect2(origin - Vector2.ONE, Vector2(width + 2.0, 4.0)), Color("#0a1014"))
	overlay.draw_rect(Rect2(origin, Vector2(width * clampf(body.hp / body.max_hp, 0.0, 1.0), 2.0)), color)
