class_name SkillManager
extends Node

signal bomb_dropped(position : Vector2)

const BOMB_COST : int = 12
const BOMB_COOLDOWN : float = 25.0
const BOMB_COUNT : int = 5
const BOMB_RADIUS : float = 70.0
const BOMB_SPREAD : float = 130.0
const BOMB_DAMAGE : float = 4.0

const BOOST_COST : int = 8
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
var targeting_bomb : bool = false
var enabled : bool = true

var bomb_button : Button
var boost_button : Button
var hint_label : Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var canvas : CanvasLayer = game_ui.get_parent() as CanvasLayer
	var box : HBoxContainer = HBoxContainer.new()
	box.position = Vector2(1280 - 2 * 200 - 24, 10)
	box.add_theme_constant_override("separation", 8)
	canvas.add_child(box)
	bomb_button = _make_button("battle.q_bomb", _on_bomb_pressed)
	boost_button = _make_button("battle.w_boost", _on_boost_pressed)
	box.add_child(bomb_button)
	box.add_child(boost_button)

	hint_label = Label.new()
	hint_label.position = Vector2(340, 40)
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.hide()
	canvas.add_child(hint_label)

func _make_button(text : String, handler : Callable) -> Button:
	var button : Button = Button.new()
	button.custom_minimum_size = Vector2(196, 40)
	button.add_theme_font_size_override("font_size", 8)
	button.text = Loc.t(text).to_upper()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	return button

func _process(delta : float) -> void:
	for key : StringName in cooldowns:
		cooldowns[key] = max(0.0, cooldowns[key] - delta)
	_update_button(bomb_button, "battle.q_bomb", &"bomb", BOMB_COST)
	_update_button(boost_button, "battle.w_boost", &"boost", BOOST_COST)

func _update_button(button : Button, label : String, key : StringName, cost : int) -> void:
	var cd : float = cooldowns[key]
	if (cd > 0.0):
		button.text = ("%s  %ds" % [Loc.t(label), ceili(cd)]).to_upper()
	else:
		button.text = (Loc.t("battle.scr") % [Loc.t(label), cost]).to_upper()
	button.disabled = !enabled or cd > 0.0 or game_ui.screw_label.total_value < cost

func _unhandled_input(event : InputEvent) -> void:
	if (!enabled):
		return
	if (event.is_action_pressed("game_skill_1")):
		_on_bomb_pressed()
	elif (event.is_action_pressed("game_skill_2")):
		_on_boost_pressed()

func _input(event : InputEvent) -> void:
	if (!enabled or !targeting_bomb):
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var mouse : Vector2 = get_viewport().get_mouse_position()
		if (bomb_button.get_global_rect().has_point(mouse) or boost_button.get_global_rect().has_point(mouse)):
			return
		_drop_bombs(ally_base.get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("game_pause")):
		_set_targeting(false)

func stop() -> void:
	enabled = false
	_set_targeting(false)

func _set_targeting(value : bool) -> void:
	targeting_bomb = value
	hint_label.visible = value
	hint_label.text = "battle.click_on_the_battlefield_to"

func _can_use(key : StringName, cost : int) -> bool:
	return enabled and cooldowns[key] <= 0.0 and game_ui.screw_label.total_value >= cost

func _on_bomb_pressed() -> void:
	if (targeting_bomb):
		_set_targeting(false)
	elif (_can_use(&"bomb", BOMB_COST)):
		_set_targeting(true)

func _on_boost_pressed() -> void:
	if (!_can_use(&"boost", BOOST_COST)):
		return
	game_ui.screw_label.change_value(-BOOST_COST)
	cooldowns[&"boost"] = BOOST_COOLDOWN
	var duration : float = Global.modify(Enums.UpgradeTarget.SKILL, &"boost_duration", BOOST_DURATION)
	ally_base.apply_build_boost(BOOST_BUILD_MULT, duration)

func _drop_bombs(center : Vector2) -> void:
	_set_targeting(false)
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
