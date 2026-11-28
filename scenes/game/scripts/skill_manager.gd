class_name SkillManager
extends Node

signal skill_used(skill_id : StringName, position : Vector2)

const COMMAND_MAX : float = 100.0
const COMMAND_PER_SECOND : float = 1.0
const COMMAND_PER_KILL_PRICE : float = 0.5

const BOMB_COUNT : int = 6
const BOMB_RADIUS : float = 60.0
const BOMB_SPREAD : float = 130.0
const BOMB_DAMAGE : float = 12.0
const BOMB_INTERVAL : float = 0.28
const BOMB_FLIGHT : float = 1.1
const SHELL_TRAIL_THICK : float = 1.4
const BOMB_GRAINS : int = 1100
const BOMB_SPLASH_GRAINS : int = 400
const BOMB_SMOKE_SECONDS : float = 3.5
const BOMB_ENTRY : Vector2 = Vector2(330.0, 430.0)

const REPAIR_RADIUS : float = 90.0

const FLAK_SECONDS : float = 5.0
const FLAK_DAMAGE : float = 4.0
const FLAK_RADIUS : float = 34.0
const FLAK_COLUMN_GAP : float = 55.0
const FLAK_BASE_GAP : float = 150.0
const FLAK_END_GAP : float = 200.0
const FLAK_TOP : float = 80.0
const FLAK_BOTTOM : float = 280.0
const FLAK_PER_COLUMN : int = 5
const FLAK_SCATTER : float = 75.0

const SUPPLY_AMOUNT : int = 20
const SUPPLY_DROPS : int = 10
const SUPPLY_COLLECT_SECONDS : float = 1.0

@export
var game_ui : GameUI
@export
var ally_base : Base
@export
var enemy_base : Base

var ships_manager : ShipManager
var camera : Camera2D

var command : float = 0.0
var targeting_id : StringName = &""
var enabled : bool = true

var hint_label : Label
var reticle : TargetReticle

func _ready() -> void:
	var canvas : CanvasLayer = game_ui.get_parent() as CanvasLayer
	hint_label = Label.new()
	hint_label.position = Vector2(340, 40)
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.hide()
	canvas.add_child(hint_label)
	reticle = TargetReticle.new()
	reticle.z_index = 2000
	reticle.hide()
	ally_base.get_parent().add_child.call_deferred(reticle)
	if (ships_manager):
		ships_manager.unit_destroyed.connect(_on_unit_destroyed)

func _process(delta : float) -> void:
	if (enabled):
		add_command(COMMAND_PER_SECOND * delta)

func add_command(amount : float) -> void:
	var before : float = command
	command = clampf(command + amount, 0.0, COMMAND_MAX)
	if (!enabled or floori(command) <= floori(before)):
		return
	if (command >= COMMAND_MAX):
		BattleAudio.play_ui(self, &"hud_command_ready")
		return
	for entry : String in Global.player_stats.loadout:
		var skill : SkillStats = SkillCatalog.find(entry)
		if (skill and Global.player_stats.is_skill_unlocked(skill)):
			var cost : int = cost_of(skill.skill_id)
			if (before < cost and command >= cost):
				BattleAudio.play_ui(self, &"hud_command_ready")
				return

func _on_unit_destroyed(stats : EntityStats, team : TeamStats) -> void:
	var boat : BoatStats = stats as BoatStats
	if (enabled and boat and team.team_id != ally_base.team_stats.team_id):
		add_command(float(boat.price) * COMMAND_PER_KILL_PRICE)

func cost_of(id : StringName) -> int:
	var skill : SkillStats = SkillCatalog.find(SkillCatalog.PREFIX + String(id))
	var cost : float = float(skill.price)
	if (id == SkillCatalog.BOMB):
		cost = Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_cooldown", cost)
	return roundi(cost)

func is_targeting(id : StringName = &"") -> bool:
	return targeting_id != &"" and (id == &"" or id == targeting_id)

func skill_reason(skill : SkillStats) -> String:
	if (!enabled):
		return "hud.unavailable"
	if (is_targeting(skill.skill_id)):
		return "hud.aiming"
	if (command < float(cost_of(skill.skill_id))):
		return "hud.low_command"
	return "hud.ready"

func activate(skill : SkillStats) -> bool:
	if (is_targeting(skill.skill_id)):
		_set_targeting(&"")
		return false
	if (skill_reason(skill) != "hud.ready"):
		return false
	_set_targeting(&"")
	if (skill.targeted):
		_set_targeting(skill.skill_id)
		return true
	return fire(skill.skill_id)

func fire(id : StringName, where : Vector2 = Vector2.ZERO) -> bool:
	if (!enabled or command < float(cost_of(id))):
		return false
	var cost : float = float(cost_of(id))
	match id:
		SkillCatalog.BOMB:
			_launch_bombs(where)
			BattleAudio.play_ui(self, &"skill_bomb_warning")
		SkillCatalog.REPAIR:
			if (!_repair(where)):
				return false
		SkillCatalog.FLAK:
			where = _launch_flak()
		SkillCatalog.SUPPLY:
			where = _drop_supply()
		_:
			return false
	add_command(-cost)
	skill_used.emit(id, where)
	return true

func _input(event : InputEvent) -> void:
	if (!enabled or targeting_id == &""):
		return
	var click : InputEventMouseButton = event as InputEventMouseButton
	if (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		var id : StringName = targeting_id
		_set_targeting(&"")
		fire(id, ally_base.get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif (click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT or event.is_action_pressed("game_pause")):
		_set_targeting(&"")
		get_viewport().set_input_as_handled()

func stop() -> void:
	enabled = false
	_set_targeting(&"")

func _set_targeting(id : StringName) -> void:
	targeting_id = id
	hint_label.visible = id != &""
	hint_label.text = "battle.aim_repair" if id == SkillCatalog.REPAIR else "battle.aim_bomb"
	if (reticle):
		reticle.repair = id == SkillCatalog.REPAIR
		reticle.visible = id != &""

func _world() -> Node:
	return ally_base.get_parent()

func _launch_bombs(center : Vector2) -> void:
	var count : int = int(Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_count", BOMB_COUNT))
	var damage : float = Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_damage", BOMB_DAMAGE)
	var side : float = 1.0 if ally_base.team_stats.direction > 0 else -1.0
	for index : int in count:
		var shell : SkillShell = SkillShell.new()
		shell.goal = Vector2(center.x + randf_range(-BOMB_SPREAD, BOMB_SPREAD), ShipEntity.WATER_LEVEL)
		shell.start = shell.goal + Vector2(-side * BOMB_ENTRY.x, -BOMB_ENTRY.y)
		shell.delay = BOMB_INTERVAL * float(index)
		shell.damage = damage
		shell.z_index = 2000
		_world().add_child(shell)

func _repair(center : Vector2) -> bool:
	var found : bool = false
	for entity : Entity in BattleContext.of(self).entities:
		if (!entity.enabled or entity.destroyed or entity.team_stats.team_id != ally_base.team_stats.team_id):
			continue
		if (absf(entity.global_position.x - center.x) > REPAIR_RADIUS):
			continue
		var health : HealthComponent = entity.get_node_or_null("HealthComponent") as HealthComponent
		if (health == null or health.actual_health <= 0.0 or health.actual_health >= health.default_health):
			continue
		RepairEffect.apply(entity, health)
		found = true
	return found

func _launch_flak() -> Vector2:
	var side : float = 1.0 if ally_base.team_stats.direction > 0 else -1.0
	var barrage : FlakBarrage = FlakBarrage.new()
	barrage.from_x = ally_base.global_position.x + side * FLAK_BASE_GAP
	barrage.to_x = enemy_base.global_position.x - side * FLAK_END_GAP
	_world().add_child(barrage)
	return Vector2(barrage.from_x, FLAK_TOP)

func _drop_supply() -> Vector2:
	var center : Vector2 = camera.get_screen_center_position() if camera else ally_base.global_position
	var items : ItemManager = ships_manager.item_manager
	var total : int = int(Global.modify(Enums.UpgradeTarget.SKILL, &"supply_amount", SUPPLY_AMOUNT))
	for index : int in SUPPLY_DROPS:
		var amount : int = total / SUPPLY_DROPS + (1 if index < total % SUPPLY_DROPS else 0)
		if (amount <= 0):
			continue
		var screw : GearEntity = items.spawn_screw_drop(center, amount)
		screw.collect_after(SUPPLY_COLLECT_SECONDS)
	return center

class SkillShell extends Node2D:
	var start : Vector2
	var goal : Vector2
	var delay : float = 0.0
	var damage : float = 0.0
	var t : float = 0.0

	func _ready() -> void:
		global_position = start
		rotation = (goal - start).angle()
		visible = false

	func _physics_process(delta : float) -> void:
		if (delay > 0.0):
			delay -= delta
			return
		if (!visible):
			BattleAudio.play_at(self, &"skill_bomb_whistle", global_position)
		visible = true
		t = minf(t + delta / SkillManager.BOMB_FLIGHT, 1.0)
		var before : Vector2 = global_position
		global_position = start.lerp(goal, pow(t, 1.5))
		GrainParticles.missile_trail(get_parent(), before, global_position, SkillManager.SHELL_TRAIL_THICK)
		if (t >= 1.0):
			_impact()

	func _impact() -> void:
		var hit : Damage = Damage.new()
		hit.damage = damage
		hit.knockback = 2
		var struck : bool = false
		for entity : Entity in BattleContext.of(self).entities.duplicate():
			if (!entity.enabled or entity.destroyed or entity.is_submerged()):
				continue
			var offset : Vector2 = entity.global_position - goal
			if (absf(offset.x) > SkillManager.BOMB_RADIUS or absf(offset.y) > SkillManager.BOMB_RADIUS * 1.5):
				continue
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(hit, 0.0)
				struck = true
		BattleAudio.play_at(self, &"skill_bomb_explosion", goal, self)
		if (struck):
			GrainParticles.explosion(get_parent(), goal, SkillManager.BOMB_RADIUS, SkillManager.BOMB_GRAINS, SkillManager.BOMB_SMOKE_SECONDS)
		else:
			GrainParticles.splash(get_parent(), goal, SkillManager.BOMB_RADIUS * 0.6, SkillManager.BOMB_SPLASH_GRAINS)
		queue_free()

	func _draw() -> void:
		draw_rect(Rect2(-4, -2, 7, 4), Color("14181d"))
		draw_rect(Rect2(3, -1, 1, 2), Color("14181d"))
		draw_rect(Rect2(-3, -1, 6, 1), Color("5c7480"))
		draw_rect(Rect2(-5, -3, 2, 6), Color("262f38"))

class FlakBarrage extends Node2D:
	var from_x : float = 0.0
	var to_x : float = 0.0
	var age : float = 0.0
	var fired : int = 0
	var columns : int = 1

	func _ready() -> void:
		columns = maxi(ceili(absf(to_x - from_x) / SkillManager.FLAK_COLUMN_GAP), 1)

	func _physics_process(delta : float) -> void:
		age += delta
		var due : int = mini(ceili(age / SkillManager.FLAK_SECONDS * float(columns)), columns)
		while (fired < due):
			_fire_column(lerpf(from_x, to_x, (float(fired) + 0.5) / float(columns)))
			fired += 1
		if (fired >= columns):
			queue_free()

	func _fire_column(x : float) -> void:
		var band : float = (SkillManager.FLAK_BOTTOM - SkillManager.FLAK_TOP) / float(SkillManager.FLAK_PER_COLUMN)
		for index : int in SkillManager.FLAK_PER_COLUMN:
			var where : Vector2 = Vector2(x + randf_range(-SkillManager.FLAK_SCATTER, SkillManager.FLAK_SCATTER), SkillManager.FLAK_TOP + band * (float(index) + randf()))
			_burst(where)
		BattleAudio.play_at(self, &"skill_flak_burst", Vector2(x, (SkillManager.FLAK_TOP + SkillManager.FLAK_BOTTOM) * 0.5), self)

	func _burst(where : Vector2) -> void:
		var hit : Damage = Damage.new()
		hit.damage = SkillManager.FLAK_DAMAGE
		hit.knockback = 0
		for entity : Entity in BattleContext.of(self).entities.duplicate():
			if (!entity.enabled or entity.destroyed or !(entity.entity_stats is AirPlaneState)):
				continue
			if (entity.global_position.distance_to(where) > SkillManager.FLAK_RADIUS):
				continue
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(hit, 0.0)
		GrainParticles.flak(get_parent(), where, SkillManager.FLAK_RADIUS)

class RepairEffect extends Node2D:
	const TEXTURE : Texture2D = preload("res://assets/game/misc/repair_wrench_17x17_v01.png")
	const NODE_NAME : String = "RepairEffect"
	const SECONDS : float = 3.0
	const SHARE : float = 0.5
	const SPIN : float = 5.0
	const HEIGHT : float = 28.0

	var unit : Entity
	var health : HealthComponent
	var left : float = SECONDS
	var sprite : Sprite2D

	static func apply(entity : Entity, component : HealthComponent) -> void:
		var existing : RepairEffect = entity.get_node_or_null(NODE_NAME) as RepairEffect
		if (existing):
			existing.left = SECONDS
			return
		var effect : RepairEffect = RepairEffect.new()
		effect.name = NODE_NAME
		effect.unit = entity
		effect.health = component
		entity.add_child(effect)

	func _ready() -> void:
		top_level = true
		z_index = 1850
		sprite = Sprite2D.new()
		sprite.texture = TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_follow()

	func _follow() -> void:
		var depth : Variant = unit.get("dive_offset")
		global_position = unit.global_position + Vector2(0.0, -HEIGHT + (float(depth) if depth != null else 0.0))
		global_rotation = 0.0

	func _process(delta : float) -> void:
		_follow()
		sprite.rotation += SPIN * delta

	func _physics_process(delta : float) -> void:
		if (unit.destroyed or health.actual_health <= 0.0 or left <= 0.0):
			queue_free()
			return
		var step : float = minf(delta, left)
		left -= step
		health.actual_health = minf(health.default_health, health.actual_health + health.default_health * SHARE * step / SECONDS)

class TargetReticle extends Node2D:
	const TEXTURE : Texture2D = preload("res://assets/game/misc/bomb_target_70x70_v01.png")
	var repair : bool = false
	var t : float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta : float) -> void:
		t += delta
		global_position = get_global_mouse_position()
		queue_redraw()

	func _draw() -> void:
		var pulse : float = 0.75 + 0.25 * sin(t * 6.0)
		if (repair):
			var top : float = 40.0 - global_position.y
			var area : Rect2 = Rect2(-SkillManager.REPAIR_RADIUS, top, SkillManager.REPAIR_RADIUS * 2.0, 420.0)
			draw_rect(area, Color(0.48, 0.91, 0.55, 0.12))
			draw_rect(area, Color(0.48, 0.91, 0.55, pulse), false, 2.0)
			return
		var radius : float = SkillManager.BOMB_RADIUS
		var tint : Color = Color("#c58ae8")
		tint.a = pulse
		draw_texture_rect(TEXTURE, Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), false, tint)
