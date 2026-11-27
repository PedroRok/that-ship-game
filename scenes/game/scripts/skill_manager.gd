class_name SkillManager
extends Node

signal bomb_dropped(position : Vector2)

const BOMB_COST : int = SkillCatalog.BOMB_COST
const BOMB_COOLDOWN : float = 25.0
const BOMB_COUNT : int = 5
const BOMB_RADIUS : float = 70.0
const BOMB_SPREAD : float = 130.0
const BOMB_DAMAGE : float = 4.0

const BOOST_COST : int = SkillCatalog.BOOST_COST
const BOOST_COOLDOWN : float = 30.0
const BOOST_DURATION : float = 8.0
const BOOST_BUILD_MULT : float = 0.5

@export
var game_ui : GameUI
@export
var ally_base : Base
@export
var enemy_base : Base

var cooldowns : Dictionary = {&"bomb": 0.0, &"boost": 0.0}
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
	reticle.radius = BOMB_RADIUS
	reticle.z_index = 2000
	reticle.hide()
	ally_base.get_parent().add_child.call_deferred(reticle)

func _process(delta : float) -> void:
	for key : StringName in cooldowns:
		cooldowns[key] = max(0.0, cooldowns[key] - delta)

func cost_of(id : StringName) -> int:
	return BOMB_COST if id == &"bomb" else BOOST_COST

func cooldown_left(id : StringName) -> float:
	return cooldowns.get(id, 0.0)

func is_targeting(id : StringName = &"") -> bool:
	return targeting_id != &"" and (id == &"" or id == targeting_id)

func skill_reason(skill : SkillStats) -> String:
	if (!enabled):
		return "hud.unavailable"
	if (is_targeting(skill.skill_id)):
		return "hud.aiming"
	if (cooldown_left(skill.skill_id) > 0.0):
		return "cd:%d" % ceili(cooldown_left(skill.skill_id))
	if (game_ui.screw_label.total_value < cost_of(skill.skill_id)):
		return "hud.low_screws"
	return "hud.ready"

func activate(skill : SkillStats) -> bool:
	if (is_targeting(skill.skill_id)):
		_set_targeting(&"")
		return false
	if (skill_reason(skill) != "hud.ready" and !is_targeting()):
		return false
	_set_targeting(&"")
	if (skill.targeted):
		_set_targeting(skill.skill_id)
		return true
	return _fire_boost()

func _input(event : InputEvent) -> void:
	if (!enabled or targeting_id == &""):
		return
	var click : InputEventMouseButton = event as InputEventMouseButton
	if (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		_drop_bombs(ally_base.get_global_mouse_position())
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
	hint_label.text = "battle.click_on_the_battlefield_to"
	if (reticle):
		reticle.visible = id != &""

func _can_use(key : StringName, cost : int) -> bool:
	return enabled and cooldowns[key] <= 0.0 and game_ui.screw_label.total_value >= cost

func _fire_boost() -> bool:
	if (!_can_use(&"boost", BOOST_COST)):
		return false
	game_ui.screw_label.change_value(-BOOST_COST)
	cooldowns[&"boost"] = BOOST_COOLDOWN
	var duration : float = Global.modify(Enums.UpgradeTarget.SKILL, &"boost_duration", BOOST_DURATION)
	ally_base.apply_build_boost(BOOST_BUILD_MULT, duration)
	return true

func _drop_bombs(center : Vector2) -> void:
	_set_targeting(&"")
	if (!_can_use(&"bomb", BOMB_COST)):
		return
	game_ui.screw_label.change_value(-BOMB_COST)
	cooldowns[&"bomb"] = Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_cooldown", BOMB_COOLDOWN)
	var count : int = int(Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_count", BOMB_COUNT))
	var damage : float = Global.modify(Enums.UpgradeTarget.SKILL, &"bomb_damage", BOMB_DAMAGE)
	bomb_dropped.emit(center)
	for i : int in count:
		var pos : Vector2 = Vector2(center.x + randf_range(-BOMB_SPREAD, BOMB_SPREAD), center.y)
		get_tree().create_timer(0.35 * i + 0.4).timeout.connect(_explode.bind(pos, damage))

func _explode(pos : Vector2, damage_value : float) -> void:
	var damage : Damage = Damage.new()
	damage.damage = damage_value
	damage.knockback = 2
	for node : Node in BattleContext.of(self).entities:
		var entity : Entity = node as Entity
		if (!entity or !entity.enabled or entity.team_stats.team_id == ally_base.team_stats.team_id):
			continue
		if (abs(entity.global_position.x - pos.x) <= BOMB_RADIUS and abs(entity.global_position.y - pos.y) <= BOMB_RADIUS * 2.0):
			var hitbox : HitboxComponent = entity.get_node_or_null("HitboxComponent") as HitboxComponent
			if (hitbox):
				hitbox.handle_hit(damage, 0.0)
	if (abs(enemy_base.get_center_pos().x - pos.x) <= BOMB_RADIUS):
		enemy_base.health_component.handle_hit(damage)
	_spawn_flash(pos)

func _spawn_flash(pos : Vector2) -> void:
	var flash : BombFlash = BombFlash.new()
	flash.radius = BOMB_RADIUS
	flash.global_position = pos
	flash.z_index = 2000
	ally_base.get_parent().add_child(flash)

class BombFlash extends Node2D:
	var radius : float = 70.0
	var t : float = 0.0

	func _process(delta : float) -> void:
		t += delta * 2.5
		if (t >= 1.0):
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r : float = radius * (0.3 + 0.7 * t)
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.7, 0.2, 0.6 * (1.0 - t)))
		draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.95, 0.7, 0.8 * (1.0 - t)))

class TargetReticle extends Node2D:
	const TEXTURE : Texture2D = preload("res://assets/game/misc/bomb_target_70x70_v01.png")
	var radius : float = 70.0
	var t : float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta : float) -> void:
		t += delta
		global_position = get_global_mouse_position()
		queue_redraw()

	func _draw() -> void:
		var tint : Color = Color("#c58ae8")
		tint.a = 0.75 + 0.25 * sin(t * 6.0)
		draw_texture_rect(TEXTURE, Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), false, tint)
