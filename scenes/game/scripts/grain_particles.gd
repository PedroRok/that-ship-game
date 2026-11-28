class_name GrainParticles
extends GPUParticles2D

enum Kind { SMOKE, SPRAY, BUBBLES, DEBRIS, SUNK, FLAME, PLUME, BLAST, TRAIL, FOAM }

const SHADER : Shader = preload("res://shaders/grain.gdshader")
const AMOUNTS : Array[int] = [131072, 16384, 16384, 16384, 8192, 32768, 32768, 8192, 16384, 8192]
const LAYERS : Array[int] = [1900, 150, 149, 1960, 151, 1100, 1090, 1900, 1850, 150]
const SECONDS : float = 4.0
const NO_LIMIT : float = 100000.0
const TEXTURE_SIZE : int = 4

const FLASH_SECONDS : float = 0.15
const FLASH_GRAINS : int = 14
const FLASH_TONE : Color = Color(1.0, 0.72, 0.25)

const FLAK_FULL_RADIUS : float = 34.0
const FLAK_FULL_GRAINS : int = 520
const FLAK_TONES : Array[Color] = [Color(0.09, 0.1, 0.12), Color(0.15, 0.17, 0.2), Color(0.23, 0.25, 0.29)]
const FLAK_FADE_START : Vector2 = Vector2(0.55, 2.4)
const FLAK_FADE_LENGTH : Vector2 = Vector2(0.8, 1.8)

const SMOKE_TONES : Array[Color] = [Color(0.2, 0.19, 0.19), Color(0.3, 0.29, 0.29), Color(0.43, 0.42, 0.42)]
const FIRE_TONES : Array[Color] = [Color(0.8, 0.16, 0.05), Color(1.0, 0.42, 0.06), Color(1.0, 0.7, 0.14)]
const SMOKE_SHARE : float = 0.55
const FIRE_REACH : float = 0.75
const SMOKE_FADE_START : float = 0.5
const SMOKE_FADE_LENGTH : float = 0.6
const FIRE_FADE_START : Vector2 = Vector2(0.1, 0.45)
const FIRE_FADE_LENGTH : Vector2 = Vector2(0.15, 0.4)
const EXPLOSION_LIFT : float = 0.4

const WATER_TONES : Array[Color] = [Color(0.45, 0.68, 0.95), Color(0.72, 0.87, 1.0), Color(0.97, 0.99, 1.0)]

const METAL_TONES : Array[Color] = [Color(0.08, 0.09, 0.11), Color(0.23, 0.26, 0.3), Color(0.5, 0.55, 0.6)]
const SPARK_TONES : Array[Color] = [Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.35)]
const CHIP_GRAINS : int = 12
const CHIP_SPARKS : int = 5
const CHIP_SPREAD : float = 1.1
const DROP_GRAINS : int = 16
const DROP_RADIUS : float = 7.0
const WRECK_RADIUS : Vector2 = Vector2(16.0, 55.0)
const SHIP_WRECK_GRAINS : Vector2 = Vector2(600.0, 1500.0)
const AIR_WRECK_GRAINS : Vector2 = Vector2(300.0, 700.0)
const WRECK_DEBRIS : int = 40
const SUNK_FIRE_GRAINS : int = 220

const WATER_DENSITY : float = 2.2
const WATER_BIG_CHANCE : float = 0.3
const TRAIL_STEP : float = 4.0
const TRAIL_FLAMES : int = 1
const TRAIL_PUFFS : float = 0.7
const TRAIL_TONES : Array[Color] = [Color(0.62, 0.63, 0.66), Color(0.76, 0.77, 0.8), Color(0.9, 0.91, 0.93)]
const WAKE_GRAINS : int = 3
const FOAM_FALL : float = 0.25
const FOAM_LINGER : float = 1.7

const FLAME_SPREAD : Vector2 = Vector2(5.0, 2.0)
const FLAME_PIXELS : Vector2i = Vector2i(1, 2)
const FLAME_PLUME_PIXELS : Vector2i = Vector2i(2, 3)
const SMALL_FLAME_SPREAD : Vector2 = Vector2(2.0, 1.0)
const SMALL_FLAME_PIXELS : Vector2i = Vector2i(1, 1)
const SMALL_FLAME_LIFE : float = 0.7
const SMALL_PLUME_PIXELS : Vector2i = Vector2i(1, 2)
const SMALL_PLUME_LIFE : float = 0.6

const CORE_SHARE : float = 0.6
const CORE_PIXELS : Vector2i = Vector2i(3, 5)
const EDGE_PIXELS : Vector2i = Vector2i(1, 3)
const SMOKE_CORE_PIXELS : Vector2i = Vector2i(2, 3)
const SMOKE_EDGE_PIXELS : Vector2i = Vector2i(1, 2)
const FIRE_CORE_PIXELS : Vector2i = Vector2i(1, 2)
const FIRE_EDGE_PIXELS : Vector2i = Vector2i(1, 1)
const SMOKE_DENSITY : float = 1.4
const FIRE_DENSITY : float = 2.4
const SMALL_FLASH_PIXELS : int = 2
const HIT_SPARKS : int = 22
const HIT_SMOKE : int = 9
const BLAST_SMOKE_SHARE : float = 0.45
const LUMPS : int = 7
const OPEN_RATES : Array[float] = [14.0, 3.5, 2.5, 3.0, 2.0, 3.0, 1.2, 14.0, 6.0, 2.0]
const SWELL_SHARES : Array[float] = [0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45, 0.0, 0.0]
const CHURNS : Array[float] = [3.0, 0.0, 5.0, 0.0, 3.0, 10.0, 6.0, 3.0, 4.0, 2.0]
const GRAVITIES : Array[float] = [0.0, 55.0, -26.0, 55.0, 6.0, -45.0, -7.0, 0.0, -3.0, 3.0]

static var _dot : Texture2D

var kind : Kind = Kind.SMOKE
var emitted : int = 0
var idle : float = 0.0

static func flak(parent : Node, where : Vector2, radius : float) -> void:
	var system : GrainParticles = of(parent, Kind.SMOKE)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	system._cloud(at, radius, flak_grains(radius), FLAK_TONES, FLAK_FADE_START, FLAK_FADE_LENGTH, SECONDS)
	system._flash(at, radius)

static func explosion(parent : Node, where : Vector2, radius : float, grains : int, seconds : float) -> void:
	var system : GrainParticles = of(parent, Kind.SMOKE)
	if (system == null):
		return
	var highest : float = ShipEntity.WATER_LEVEL - AirPuff.WATER_MARGIN - radius * EXPLOSION_LIFT
	var at : Vector2 = system.to_local(Vector2(where.x, minf(where.y, highest)))
	system._burning(at, radius, scaled(grains), SMOKE_SHARE, Vector2(SMOKE_FADE_START, seconds * 0.55),
			Vector2(SMOKE_FADE_LENGTH, seconds * 0.45), seconds)
	system._flash(at, radius, SMALL_FLASH_PIXELS)

static func splash(parent : Node, where : Vector2, radius : float, grains : int) -> void:
	var system : GrainParticles = of(parent, Kind.SPRAY)
	if (system == null):
		return
	var at : Vector2 = system.to_local(Vector2(where.x, ShipEntity.WATER_LEVEL))
	for _index : int in scaled(roundi(float(grains) * WATER_DENSITY)):
		var side : float = randf_range(-1.0, 1.0)
		var height : float = radius * randf_range(0.2, 2.0) * (1.0 - 0.6 * absf(side))
		var offset : Vector2 = Vector2(side * radius * 0.3, randf_range(-2.0, 1.0))
		var tone : int = randi() % WATER_TONES.size()
		var linger : float = FOAM_LINGER if tone == WATER_TONES.size() - 1 else 1.0
		system._emit(at + offset, Vector2(side * radius * 0.6, -height), WATER_TONES[tone],
				_water_pixels(), randf_range(0.6, 1.1) * linger, randf_range(1.3, 1.9) * linger)

static func bubbles(parent : Node, where : Vector2, radius : float, grains : int) -> void:
	var system : GrainParticles = of(parent, Kind.BUBBLES)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	for _index : int in scaled(roundi(float(grains) * WATER_DENSITY)):
		var travel : Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		system._emit(at, travel, WATER_TONES[randi() % WATER_TONES.size()], _water_pixels(),
				randf_range(1.0, 2.0), randf_range(2.0, 2.8))

static func debris(parent : Node, where : Vector2, radius : float, grains : int) -> void:
	var system : GrainParticles = of(parent, Kind.DEBRIS)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	for index : int in scaled(grains):
		var travel : Vector2 = Vector2.from_angle(randf() * TAU) * radius * randf_range(0.5, 1.6) + Vector2(0.0, -radius * 0.6)
		var tone : Color = SPARK_TONES[index % 2] if index % 4 == 0 else METAL_TONES[index % 3]
		system._emit(at, travel, tone, randi_range(1, 2), randf_range(0.8, 1.6), randf_range(1.6, 2.6))

static func chips(parent : Node, where : Vector2, incoming : Vector2) -> void:
	var system : GrainParticles = of(parent, Kind.DEBRIS)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	var back : Vector2 = -incoming.normalized()
	for _index : int in scaled(CHIP_GRAINS):
		var travel : Vector2 = back.rotated(randf_range(-CHIP_SPREAD, CHIP_SPREAD)) * randf_range(5.0, 20.0) + Vector2(0.0, -randf_range(0.0, 8.0))
		system._emit(at, travel, METAL_TONES[randi() % METAL_TONES.size()], 1, randf_range(0.4, 0.7), randf_range(0.8, 1.1))
	for _index : int in scaled(CHIP_SPARKS):
		var travel : Vector2 = back.rotated(randf_range(-CHIP_SPREAD, CHIP_SPREAD)) * randf_range(10.0, 26.0)
		system._emit(at, travel, SPARK_TONES[randi() % SPARK_TONES.size()], 1, 0.05, randf_range(0.15, 0.3))

static func drops(parent : Node, where : Vector2) -> void:
	splash(parent, where, DROP_RADIUS, DROP_GRAINS)

static func wreck(parent : Node, where : Vector2, size : Vector2, flying : bool) -> void:
	var radius : float = clampf(size.x * 0.45, WRECK_RADIUS.x, WRECK_RADIUS.y)
	var range_of : Vector2 = AIR_WRECK_GRAINS if flying else SHIP_WRECK_GRAINS
	var grains : int = roundi(remap(radius, WRECK_RADIUS.x, WRECK_RADIUS.y, range_of.x, range_of.y))
	explosion(parent, where, radius, grains, SECONDS * 0.75 if flying else SECONDS)
	debris(parent, where, radius, WRECK_DEBRIS)

static func sunk_wreck(parent : Node, where : Vector2, size : Vector2) -> void:
	var radius : float = clampf(size.x * 0.45, WRECK_RADIUS.x, WRECK_RADIUS.y)
	bubbles(parent, where, radius, roundi(radius * 28.0))
	var system : GrainParticles = of(parent, Kind.SUNK)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	for index : int in scaled(SUNK_FIRE_GRAINS):
		var travel : Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		system._emit(at, travel, FIRE_TONES[index % FIRE_TONES.size()], randi_range(1, 2), randf_range(0.2, 0.5), randf_range(0.6, 1.1))
	for index : int in scaled(WRECK_DEBRIS * 3):
		var travel : Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		system._emit(at, travel, METAL_TONES[index % 2], randi_range(2, 3), randf_range(0.8, 2.0), randf_range(2.0, 3.2))

static func flame(parent : Node, where : Vector2, small : bool = false) -> void:
	var system : GrainParticles = of(parent, Kind.FLAME)
	if (system == null):
		return
	var spread : Vector2 = SMALL_FLAME_SPREAD if small else FLAME_SPREAD
	var offset : Vector2 = Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
	var tone : int = randi() % FIRE_TONES.size()
	var finish : float = randf_range(0.7, 1.0) if tone == 0 else (randf_range(0.5, 0.75) if tone == 1 else randf_range(0.25, 0.45))
	var pixels : Vector2i = SMALL_FLAME_PIXELS if small else FLAME_PIXELS
	if (small):
		finish *= SMALL_FLAME_LIFE
	system._emit(system.to_local(where) + offset, Vector2(-offset.x * 0.5 + randf_range(-2.0, 2.0), -randf_range(2.0, 10.0)),
			FIRE_TONES[tone], randi_range(pixels.x, pixels.y), finish * 0.4, finish)

static func plume(parent : Node, where : Vector2, small : bool = false) -> void:
	var system : GrainParticles = of(parent, Kind.PLUME)
	if (system == null):
		return
	var offset : Vector2 = Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, -6.0))
	var finish : float = randf_range(2.2, 3.8)
	var pixels : Vector2i = FLAME_PLUME_PIXELS
	if (small):
		offset *= 0.4
		finish *= SMALL_PLUME_LIFE
		pixels = SMALL_PLUME_PIXELS
	system._emit(system.to_local(where) + offset, Vector2(randf_range(-6.0, 6.0), -randf_range(6.0, 18.0)),
			SMOKE_TONES[randi() % SMOKE_TONES.size()], randi_range(pixels.x, pixels.y), finish * 0.3, finish)

static func hit(parent : Node, where : Vector2, width : float) -> void:
	var system : GrainParticles = of(parent, Kind.DEBRIS)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where) + Vector2(randf_range(-width, width) * 0.3, 0.0)
	for index : int in scaled(HIT_SPARKS):
		var travel : Vector2 = Vector2.from_angle(-PI * 0.5 + randf_range(-1.4, 1.4)) * randf_range(4.0, 18.0)
		system._emit(at, travel, SPARK_TONES[index % SPARK_TONES.size()], 1, randf_range(0.1, 0.25), randf_range(0.35, 0.6))
	for _index : int in scaled(HIT_SMOKE):
		var travel : Vector2 = Vector2.from_angle(-PI * 0.5 + randf_range(-1.2, 1.2)) * randf_range(3.0, 11.0)
		system._emit(at, travel, SMOKE_TONES[randi() % SMOKE_TONES.size()], randi_range(1, 2), randf_range(0.25, 0.45), randf_range(0.6, 0.9))

static func blast(parent : Node, where : Vector2, radius : float, grains : int, seconds : float) -> void:
	var system : GrainParticles = of(parent, Kind.BLAST)
	if (system == null):
		return
	system._burning(system.to_local(where), radius, scaled(grains), BLAST_SMOKE_SHARE, Vector2(0.3, seconds * 0.5),
			Vector2(0.3, seconds * 0.5), seconds)

static func missile_trail(parent : Node, from : Vector2, to : Vector2, thick : float) -> void:
	var system : GrainParticles = of(parent, Kind.TRAIL)
	if (system == null):
		return
	var back : Vector2 = (from - to).normalized()
	var steps : int = maxi(ceili(from.distance_to(to) / TRAIL_STEP), 1)
	for step : int in steps:
		var at : Vector2 = system.to_local(from.lerp(to, float(step) / float(steps)))
		for _index : int in scaled(TRAIL_FLAMES):
			system._emit(at + _jitter(thick), back * randf_range(2.0, 7.0), FIRE_TONES[randi() % FIRE_TONES.size()], 1, 0.04, randf_range(0.08, 0.16))
		for _index : int in scaled(roundi(TRAIL_PUFFS * thick)):
			system._emit(at + _jitter(thick), _jitter(thick * 2.0), TRAIL_TONES[randi() % TRAIL_TONES.size()],
					_water_pixels(), randf_range(0.2, 0.5), randf_range(0.6, 1.1))

static func torpedo_wake(parent : Node, where : Vector2, heading : Vector2) -> void:
	var system : GrainParticles = of(parent, Kind.FOAM)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	for _index : int in scaled(WAKE_GRAINS):
		var travel : Vector2 = -heading.rotated(randf_range(-0.5, 0.5)) * randf_range(3.0, 10.0)
		system._emit(at + _jitter(1.5), travel, WATER_TONES[randi() % WATER_TONES.size()], _water_pixels(), randf_range(0.4, 0.8), randf_range(0.9, 1.3))

static func ship_foam(parent : Node, where : Vector2, direction : float, grains : int) -> void:
	var system : GrainParticles = of(parent, Kind.FOAM)
	if (system == null):
		return
	var at : Vector2 = system.to_local(where)
	for _index : int in grains:
		var offset : Vector2 = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var travel : Vector2 = Vector2(-direction * randf_range(4.0, 18.0), -randf_range(0.0, 3.0))
		system._emit(at + offset, travel, WATER_TONES[1 + randi() % 2], _water_pixels(), randf_range(0.3, 0.8), randf_range(0.9, 1.5))

static func _jitter(reach : float) -> Vector2:
	return Vector2(randf_range(-reach, reach), randf_range(-reach, reach))

static func _water_pixels() -> int:
	return 2 if randf() < WATER_BIG_CHANCE else 1

static func scaled(grains : int) -> int:
	return roundi(float(grains) * GameSettings.effects_scale())

static func flak_grains(radius : float) -> int:
	return scaled(roundi(float(FLAK_FULL_GRAINS) * pow(radius / FLAK_FULL_RADIUS, 2.0)))

static func of(parent : Node, wanted : Kind) -> GrainParticles:
	var context : BattleContext = BattleContext.of(parent)
	if (context == null):
		return null
	var stored : Variant = context.grains.get(wanted)
	var system : GrainParticles = stored as GrainParticles if is_instance_valid(stored) else null
	if (system == null or system.is_queued_for_deletion()):
		system = GrainParticles.new()
		system.kind = wanted
		system.z_index = LAYERS[wanted]
		parent.add_child(system)
		context.grains[wanted] = system
	return system

func _ready() -> void:
	amount = AMOUNTS[kind]
	lifetime = SECONDS * 4.0
	emitting = false
	local_coords = true
	fixed_fps = 0
	interpolate = false
	visibility_rect = Rect2(-1000.0, -1000.0, 8000.0, 2000.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = dot()
	var surface : float = to_local(Vector2(0.0, ShipEntity.WATER_LEVEL)).y
	var underwater : bool = kind == Kind.BUBBLES or kind == Kind.SUNK
	var windy : bool = kind == Kind.SMOKE or kind == Kind.BLAST or kind == Kind.FLAME or kind == Kind.PLUME or kind == Kind.TRAIL
	var top : float = surface if underwater else -NO_LIMIT
	var bottom : float = NO_LIMIT
	if (kind == Kind.SPRAY):
		bottom = surface + AirPuff.WATER_MARGIN
	elif (!underwater and kind != Kind.FOAM):
		bottom = surface - AirPuff.WATER_MARGIN
	var motion : ShaderMaterial = ShaderMaterial.new()
	motion.shader = SHADER
	motion.set_shader_parameter("wind", AirPuff.WIND if windy else Vector2.ZERO)
	motion.set_shader_parameter("gravity", GRAVITIES[kind])
	motion.set_shader_parameter("open_rate", OPEN_RATES[kind])
	motion.set_shader_parameter("swell_share", SWELL_SHARES[kind])
	motion.set_shader_parameter("swell_seconds", SECONDS)
	motion.set_shader_parameter("churn", CHURNS[kind])
	motion.set_shader_parameter("foam_gravity", FOAM_FALL if kind == Kind.SPRAY else 1.0)
	motion.set_shader_parameter("top", top)
	motion.set_shader_parameter("bottom", bottom)
	process_material = motion

func _process(delta : float) -> void:
	idle += delta
	if (idle > SECONDS):
		queue_free()

func _burning(at : Vector2, radius : float, total : int, smoke_share : float, smoke_start : Vector2, smoke_length : Vector2, seconds : float) -> void:
	var smoke : int = roundi(float(total) * smoke_share)
	_cloud(at, radius, roundi(float(smoke) * SMOKE_DENSITY), SMOKE_TONES, smoke_start, smoke_length, seconds, SMOKE_CORE_PIXELS, SMOKE_EDGE_PIXELS)
	_cloud(at, radius * FIRE_REACH, roundi(float(total - smoke) * FIRE_DENSITY), FIRE_TONES, FIRE_FADE_START, FIRE_FADE_LENGTH,
			seconds, FIRE_CORE_PIXELS, FIRE_EDGE_PIXELS)

func _cloud(at : Vector2, radius : float, count : int, tones : Array[Color], fade_start : Vector2, fade_length : Vector2, seconds : float,
		core_pixels : Vector2i = CORE_PIXELS, edge_pixels : Vector2i = EDGE_PIXELS) -> void:
	var lumps : Array[Vector3] = [Vector3(0.0, 0.0, radius * 0.5)]
	for index : int in LUMPS - 1:
		var angle : float = TAU * float(index) / float(LUMPS - 1) + randf_range(-0.5, 0.5)
		var reach : Vector2 = Vector2.from_angle(angle) * radius * randf_range(0.35, 0.75)
		lumps.append(Vector3(reach.x, reach.y * 0.8, radius * randf_range(0.18, 0.38)))
	for index : int in count:
		var lump : Vector3 = lumps[0] if index % 3 == 0 else lumps[1 + index % (LUMPS - 1)]
		var core : bool = float(index) < float(count) * CORE_SHARE
		var spread : float = sqrt(randf()) * (0.8 if core else 1.1)
		var offset : Vector2 = Vector2.from_angle(randf() * TAU) * lump.z * spread
		var bounds : Vector2i = core_pixels if core else edge_pixels
		var pixels : int = randi_range(bounds.x, bounds.y)
		var light : float = offset.dot(Vector2(-0.5, -0.85)) / lump.z
		var start : float = randf_range(fade_start.x, fade_start.y)
		var finish : float = minf(start + randf_range(fade_length.x, fade_length.y), seconds)
		_emit(at, Vector2(lump.x, lump.y) + offset, tones[2 if light > 0.45 else (1 if light > 0.0 else 0)], pixels, start, finish)

func _flash(at : Vector2, radius : float, pixels : int = TEXTURE_SIZE) -> void:
	for _index : int in scaled(FLASH_GRAINS):
		_emit(at, Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 0.32), FLASH_TONE, pixels, 0.0, FLASH_SECONDS)

func _emit(at : Vector2, travel : Vector2, tone : Color, pixels : int, start : float, finish : float) -> void:
	var size : float = float(pixels) / float(TEXTURE_SIZE)
	emit_particle(Transform2D(0.0, Vector2(size, size), 0.0, at), travel, tone, Color(0.0, start, randf(), finish),
			EMIT_FLAG_POSITION | EMIT_FLAG_VELOCITY | EMIT_FLAG_COLOR | EMIT_FLAG_CUSTOM | EMIT_FLAG_ROTATION_SCALE)
	emitted += 1
	idle = 0.0

static func dot() -> Texture2D:
	if (_dot):
		return _dot
	var image : Image = Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_dot = ImageTexture.create_from_image(image)
	return _dot
