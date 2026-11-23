@tool
class_name Entity
extends RigidBody2D

@export
var team_stats : TeamStats

@export
var entity_stats : EntityStats

@export
var guns: Array[Gun]

@onready
var state_machine : StateMachine = $StateMachine

var enabled : bool = true

signal bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float)

signal entity_destroy(pos : Vector2, ship_stats : EntityStats, team_stats : TeamStats)

func rotates_with_body() -> bool:
	return false

func get_guns() -> Array[Gun]:
	return guns

func is_submerged() -> bool:
	return false

func can_target(target : Node2D) -> bool:
	if (guns.is_empty()):
		return true
	for gun : Gun in guns:
		if (gun.can_target(target)):
			return true
	return false

var entry_x : float = NAN
var _entry_mask : int = 0
var _entry_gravity : float = 1.0
var _entry_y : float = 0.0
var _entry_hold_y : bool = false
var _entry_z_raised : bool = false
var _entry_z_saved : int = 0
var _entry_forced : bool = false
var _entry_z_until_x : float = NAN

func begin_entry(until_x : float, hold_y : bool, entry_z : int = 0, force_move : bool = false, z_until_x : float = NAN) -> void:
	_entry_z_until_x = z_until_x
	_entry_forced = force_move
	if (entry_z != 0):
		_entry_z_saved = z_index
		_entry_z_raised = true
		z_index = entry_z
	entry_x = until_x
	_entry_mask = collision_mask
	_entry_gravity = gravity_scale
	_entry_y = global_position.y
	_entry_hold_y = hold_y
	collision_mask = 0
	if (hold_y):
		gravity_scale = 0.0

func _update_entry() -> void:
	if (is_nan(entry_x)):
		return
	if (_entry_hold_y):
		global_position.y = _entry_y
		linear_velocity.y = 0.0
	if (_entry_z_raised and !is_nan(_entry_z_until_x)):
		var left_dock : bool = global_position.x >= _entry_z_until_x if team_stats.direction > 0 else global_position.x <= _entry_z_until_x
		if (left_dock):
			z_index = _entry_z_saved
			_entry_z_raised = false
	var passed : bool = global_position.x >= entry_x if team_stats.direction > 0 else global_position.x <= entry_x
	if (passed):
		if (_entry_z_raised):
			z_index = _entry_z_saved
			_entry_z_raised = false
		_entry_forced = false
		collision_mask = _entry_mask
		gravity_scale = _entry_gravity
		entry_x = NAN
	
var occupied_slots : Array[int]

func _exit_tree() -> void:
	if !Engine.is_editor_hint():
		var context : BattleContext = BattleContext.of(self)
		if context:
			context.remove_entity(self)

func _ready() -> void:
	if !Engine.is_editor_hint():
		BattleContext.of(self).add_entity(self)
	if state_machine:
		state_machine.init(self)
	for gun_slot_index in range(entity_stats.gun_slots.size()):
		var gun_slot : GunSlot = entity_stats.gun_slots[gun_slot_index]
		var gun_type : int = gun_slot.default_gun_type()
		if (team_stats.team_id == 1 and !Engine.is_editor_hint()):
			gun_type = Global.gun_type_for(entity_stats.name, gun_slot_index, gun_slot)
		if (gun_type < 0):
			push_warning("Slot %d de %s não tem arma compatível com seu tamanho" % [gun_slot_index, entity_stats.name])
			continue
		var gun_scene : PackedScene = Enums.gun_scene(gun_type)
		add_gun(gun_scene.instantiate(), gun_slot)
		

const OUTLINE_SHADER : Shader = preload("res://shaders/team_outline.gdshader")
const OUTLINE_ALLY : Color = Color(0.35, 0.65, 1.0, 0.55)
const OUTLINE_ENEMY : Color = Color(1.0, 0.3, 0.3, 0.55)
const OUTLINE_THICKNESS : int = 1

static var _padded_cache : Dictionary = {}

static func _padded_texture(tex : Texture2D) -> Texture2D:
	if (!tex):
		return null
	if (_padded_cache.has(tex)):
		return _padded_cache[tex]
	var img : Image = tex.get_image()
	if (!img):
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var t : int = OUTLINE_THICKNESS
	var padded : Image = Image.create_empty(img.get_width() + t * 2, img.get_height() + t * 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(t, t))
	var result : Texture2D = ImageTexture.create_from_image(padded)
	_padded_cache[tex] = result
	return result

static func _padded_frames(frames : SpriteFrames) -> SpriteFrames:
	var out : SpriteFrames = SpriteFrames.new()
	out.remove_animation(&"default")
	for anim : StringName in frames.get_animation_names():
		out.add_animation(anim)
		out.set_animation_speed(anim, frames.get_animation_speed(anim))
		out.set_animation_loop(anim, frames.get_animation_loop(anim))
		for i in range(frames.get_frame_count(anim)):
			out.add_frame(anim, _padded_texture(frames.get_frame_texture(anim, i)), frames.get_frame_duration(anim, i))
	return out

var _outlines : Array[Dictionary] = []
var team_outline_enabled : bool = true

func apply_team_outline(item : Node2D) -> void:
	if (Engine.is_editor_hint() or !item or !team_stats or !team_outline_enabled):
		return
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("thickness", OUTLINE_THICKNESS)
	mat.set_shader_parameter("outline_color", OUTLINE_ALLY if team_stats.team_id == 1 else OUTLINE_ENEMY)
	var node : Node2D = AnimatedSprite2D.new() if item is AnimatedSprite2D else Sprite2D.new()
	node.material = mat
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.show_behind_parent = true
	item.add_child(node)
	_outlines.append({"src": item, "node": node, "frames": null})
	_sync_outline()

func _sync_outline() -> void:
	for entry : Dictionary in _outlines:
		_sync_one_outline(entry)

func _sync_one_outline(entry : Dictionary) -> void:
	if (!is_instance_valid(entry["src"]) or !is_instance_valid(entry["node"])):
		return
	var src : Node2D = entry["src"]
	var node : Node2D = entry["node"]
	if (src is AnimatedSprite2D):
		var a : AnimatedSprite2D = src as AnimatedSprite2D
		var o : AnimatedSprite2D = node as AnimatedSprite2D
		if (entry["frames"] != a.sprite_frames):
			entry["frames"] = a.sprite_frames
			o.sprite_frames = _padded_frames(a.sprite_frames) if a.sprite_frames else null
		o.animation = a.animation
		o.frame = a.frame
		o.flip_h = a.flip_h
		o.flip_v = a.flip_v
		o.offset = a.offset
		o.centered = a.centered
	else:
		var s : Sprite2D = src as Sprite2D
		var so : Sprite2D = node as Sprite2D
		if (!so.has_meta(&"src") or so.get_meta(&"src") != s.texture):
			so.set_meta(&"src", s.texture)
			so.texture = _padded_texture(s.texture)
		so.flip_h = s.flip_h
		so.flip_v = s.flip_v
		so.offset = s.offset
		so.centered = s.centered

func add_new_gun(new_gun : Gun) -> void:
	if (guns.size() >= entity_stats.gun_slots.size()):
		push_error("Trying to add new weapong when is already full")
		return

	var selected_gun_slot : GunSlot = null
	for gun_slot_index in range(entity_stats.gun_slots.size()):
		var gun_slot : GunSlot = entity_stats.gun_slots[gun_slot_index]
		if (gun_slot.accepts(new_gun.gun_type) and !occupied_slots.has(gun_slot_index)):
			selected_gun_slot = gun_slot
			occupied_slots.append(gun_slot_index)
			break
		
	if (selected_gun_slot == null):
		push_error("Trying to add new weapong when is already full and dont have slots to add")
		return
		
	add_gun(new_gun, selected_gun_slot)
		
		
func add_gun(gun : Gun, gun_slot : GunSlot) -> void:
	gun.connect("fired_bullet", Callable(self, "handle_bullet_fired"))
	gun._set_show_base_texture(gun_slot.with_base)
	add_child(gun)
	gun.position = gun_slot.position
	apply_team_outline(gun.get("barrel_texture") as Node2D)
	apply_team_outline(gun.base)
	if (entity_stats is BoatStats and entity_stats.hide_guns):
		gun.visible = false
	
	if team_stats.direction < 0 and !rotates_with_body():
		gun.position.x = -gun_slot.position.x 
		gun.flip()
	if (team_stats.team_id == 1):
		gun.time_to_shoot = int(Global.modify(Enums.UpgradeTarget.GUN, &"shoot_interval", gun.time_to_shoot))
	gun.current_time_to_shoot = guns.size() * 5
	guns.append(gun)

func get_center_pos() -> Vector2:
	return global_position + entity_stats.center

func handle_bullet_fired(bullet : Bullet, direction : Vector2, position : Vector2, rotation : float) -> void:
	bullet.team = team_stats.team_id
	bullet.attacker_class = entity_stats.unit_class
	if (team_stats.team_id == 1 and bullet.damage):
		bullet.damage = bullet.damage.duplicate()
		bullet.damage.damage = Global.modify(Enums.UpgradeTarget.GUN, &"damage", bullet.damage.damage)
	bullet_fired.emit(bullet, direction, position, rotation)
	pass

func _unhandled_input(event: InputEvent) -> void:
	if state_machine:
		state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	if !Engine.is_editor_hint():
		_update_entry()
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_physics(delta)
	if (_entry_forced and !is_nan(entry_x) and !Engine.is_editor_hint()):
		# garante a saída da doca mesmo com inimigo no radar (estado attack para o movimento)
		var target_x : float = team_stats.direction * entity_stats.speed
		linear_velocity.x = lerp(linear_velocity.x, target_x, entity_stats.deceleration * delta)

func _process(delta: float) -> void:
	_sync_outline()
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_frame(delta)
