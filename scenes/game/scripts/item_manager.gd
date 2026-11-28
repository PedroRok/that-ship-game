class_name ItemManager
extends Node

@export
var game_ui : GameUI

@onready
var gear_entity : PackedScene = preload("res://scenes/entities/misc/gear_entity.tscn")
@onready
var screw_entity : PackedScene = preload("res://scenes/entities/misc/screw_entity.tscn")

const KILL_SCREW_RATIO : float = 1.0 / 3.0

@export
var chance_to_spawn : float = 0.5

@export
var amout_to_spawn : int = 1

func _ready() -> void:
	auto_gear()

func auto_gear() -> void:
	var tween : Tween = get_tree().create_tween()
	game_ui.screw_label.progress_bar = 0.0
	tween.tween_property(game_ui.screw_label, "progress_bar", 1.0, Global.modify(Enums.UpgradeTarget.BASE, &"screw_income_time", 1.0))
	tween.finished.connect(Callable(self, "auto_gear"))
	game_ui.screw_label.change_value(1)
	
	
func handle_random_spawn(pos : Vector2, explode : bool) -> void:
	if (Global.modify(Enums.UpgradeTarget.BASE, &"gear_drop_chance", chance_to_spawn) > randf()):
		var amount : int = int(Global.modify(Enums.UpgradeTarget.BASE, &"gear_drop_amount", float(amout_to_spawn)))
		for i in amount:
			handle_gear_spawn(pos, explode)

func spawn_screw_drop(pos : Vector2, amount : int) -> GearEntity:
	var screw : GearEntity = screw_entity.instantiate()
	screw.amount = amount
	add_child(screw)
	screw.global_position = pos
	screw.connect("pickup_gear", Callable(game_ui, "collect_screw"))
	screw.target_control = game_ui.screw_label.texture
	screw.explode()
	return screw

func handle_gear_spawn(pos : Vector2, explode : bool) -> void:
	var gear : GearEntity = gear_entity.instantiate()
	if gear:
		add_child(gear)
		gear.global_position = pos
		gear.connect("pickup_gear", Callable(game_ui, "collect_gear"))
		gear.target_control = game_ui.gear_label.texture
		if explode:
			gear.explode()
	pass

func award_kill_screws(stats : EntityStats, pos : Vector2 = Vector2.INF) -> int:
	var amount : int = kill_screw_amount(stats)
	if (amount > 0 and pos != Vector2.INF):
		spawn_screw_drop(pos, amount)
	return amount

func kill_screw_amount(stats : EntityStats) -> int:
	if (stats.is_boss):
		return 0
	var raw : float = Global.modify(Enums.UpgradeTarget.BASE, &"kill_screw", float(stats.price) * KILL_SCREW_RATIO)
	return int(floor(raw * kill_screw_slack()))

func kill_screw_slack() -> float:
	var reference : int = 0
	for unit : EntityStats in Global.player_stats.loadout_entities():
		reference = maxi(reference, unit.price)
	var screw_factor : float = 1.0
	if (reference > 0):
		screw_factor = clampf(1.0 - float(game_ui.screw_label.total_value) / float(reference), 0.0, 1.0)
	var used : int = 0
	var capacity : int = 0
	var base : Base = game_ui.base
	for dock_type : int in base.queues:
		if (dock_type != BaseDock.Type.NAVAL and !(base.docks[dock_type] as BaseDock).active):
			continue
		used += base.queue_used(dock_type)
		capacity += base.queue_capacity(dock_type)
	var queue_factor : float = 1.0 - float(used) / float(maxi(capacity, 1))
	return minf(screw_factor, queue_factor)
