extends "res://scenes/ui/rounds_scene_manager/scripts/rounds_scene_manager.gd"

const NAVAL_ROUND := preload("res://scenes/ui/naval_hud/naval_round.tscn")
const NAVAL_SHOP := preload("res://scenes/ui/naval_hud/naval_shop.tscn")
const PROFILE := preload("res://scenes/ui/naval_hud/naval_profile.gd")

func _ready() -> void:
	var profile := PROFILE.new()
	profile.start_screw = player_stats.start_screw
	profile.gear = player_stats.gear
	profile.boss_coin = player_stats.boss_coin
	profile.unlocked_entities.assign(player_stats.unlocked_entities)
	profile.gun_upgrades.assign(player_stats.gun_upgrades)
	player_stats = profile
	super._ready()

func get_node_by_scene(menu: Global.Menu) -> Node:
	var packed: PackedScene
	match menu:
		Global.Menu.GAME:
			packed = NAVAL_ROUND
		Global.Menu.SHOP:
			packed = NAVAL_SHOP
		_:
			return super.get_node_by_scene(menu)
	var next_scene: Node = packed.instantiate()
	call_deferred("add_child", next_scene)
	return next_scene
