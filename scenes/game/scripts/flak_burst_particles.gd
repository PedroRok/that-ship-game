class_name FlakBurstParticles
extends GPUParticles2D

const SHADER : Shader = preload("res://shaders/flak_burst.gdshader")
const AMOUNT : int = 131072
const SECONDS : float = 4.0
const FLASH_SECONDS : float = 0.15
const FLASH_GRAINS : int = 14
const FULL_RADIUS : float = 34.0
const FULL_GRAINS : int = 520
const CORE_SHARE : float = 0.6
const LUMPS : int = 7
const OPEN_RATE : float = 14.0
const SWELL_SHARE : float = 0.45
const CHURN : float = 3.0
const FADE_START_MIN : float = 0.55
const FADE_START_MAX : float = 2.4
const TEXTURE_SIZE : int = 4
const TONES : Array[Color] = [Color(0.09, 0.1, 0.12), Color(0.15, 0.17, 0.2), Color(0.23, 0.25, 0.29)]
const FLASH_TONE : Color = Color(1.0, 0.72, 0.25)

static var _dot : Texture2D

var emitted : int = 0
var idle : float = 0.0

static func burst_at(parent : Node, where : Vector2, radius : float) -> void:
	var context : BattleContext = BattleContext.of(parent)
	if (context == null):
		return
	var system : FlakBurstParticles = context.flak_smoke as FlakBurstParticles if is_instance_valid(context.flak_smoke) else null
	if (system == null or system.is_queued_for_deletion()):
		system = FlakBurstParticles.new()
		system.z_index = 1900
		parent.add_child(system)
		context.flak_smoke = system
	system.burst(where, radius)

static func grains_for(radius : float) -> int:
	return roundi(float(FULL_GRAINS) * pow(radius / FULL_RADIUS, 2.0))

func _ready() -> void:
	amount = AMOUNT
	lifetime = SECONDS * 4.0
	emitting = false
	local_coords = true
	fixed_fps = 0
	interpolate = false
	visibility_rect = Rect2(-1000.0, -1000.0, 8000.0, 2000.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = dot()
	var motion : ShaderMaterial = ShaderMaterial.new()
	motion.shader = SHADER
	motion.set_shader_parameter("wind", AirPuff.WIND)
	motion.set_shader_parameter("open_rate", OPEN_RATE)
	motion.set_shader_parameter("swell_share", SWELL_SHARE)
	motion.set_shader_parameter("swell_seconds", SECONDS)
	motion.set_shader_parameter("churn", CHURN)
	process_material = motion

func _process(delta : float) -> void:
	idle += delta
	if (idle > SECONDS):
		queue_free()

func burst(where : Vector2, radius : float) -> void:
	var at : Vector2 = to_local(where)
	var lumps : Array[Vector3] = [Vector3(0.0, 0.0, radius * 0.5)]
	for index : int in LUMPS - 1:
		var angle : float = TAU * float(index) / float(LUMPS - 1) + randf_range(-0.5, 0.5)
		var reach : Vector2 = Vector2.from_angle(angle) * radius * randf_range(0.35, 0.75)
		lumps.append(Vector3(reach.x, reach.y * 0.8, radius * randf_range(0.18, 0.38)))
	var count : int = grains_for(radius)
	for index : int in count:
		var lump : Vector3 = lumps[0] if index % 3 == 0 else lumps[1 + index % (LUMPS - 1)]
		var core : bool = float(index) < float(count) * CORE_SHARE
		var spread : float = sqrt(randf()) * (0.8 if core else 1.1)
		var offset : Vector2 = Vector2.from_angle(randf() * TAU) * lump.z * spread
		var pixels : int = randi_range(3, 5) if core else randi_range(1, 3)
		var light : float = offset.dot(Vector2(-0.5, -0.85)) / lump.z
		var start : float = randf_range(FADE_START_MIN, FADE_START_MAX)
		var finish : float = minf(start + randf_range(0.8, 1.8), SECONDS)
		_emit(at, Vector2(lump.x, lump.y) + offset, TONES[2 if light > 0.45 else (1 if light > 0.0 else 0)], pixels, start, finish)
	for index : int in FLASH_GRAINS:
		_emit(at, Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 0.32), FLASH_TONE, TEXTURE_SIZE, 0.0, FLASH_SECONDS)
	idle = 0.0

func _emit(at : Vector2, travel : Vector2, tone : Color, pixels : int, start : float, finish : float) -> void:
	var size : float = float(pixels) / float(TEXTURE_SIZE)
	emit_particle(Transform2D(0.0, Vector2(size, size), 0.0, at), travel, tone, Color(0.0, start, randf(), finish),
			EMIT_FLAG_POSITION | EMIT_FLAG_VELOCITY | EMIT_FLAG_COLOR | EMIT_FLAG_CUSTOM | EMIT_FLAG_ROTATION_SCALE)
	emitted += 1

static func dot() -> Texture2D:
	if (_dot):
		return _dot
	var image : Image = Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_dot = ImageTexture.create_from_image(image)
	return _dot
