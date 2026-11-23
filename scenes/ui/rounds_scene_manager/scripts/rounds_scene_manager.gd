extends Node2D

@export
var start_scene : Global.Menu

var menu_scene : Node
@export
var player_stats : PlayerStats

func _ready() -> void:
	Global.player_stats = player_stats.duplicate()
	SaveManager.load_into(Global.player_stats, Global.CATALOG)
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))
	if (Global.test_grant_gears):
		Global.player_stats.gear = maxi(Global.player_stats.gear, 20000)
		Global.player_stats.boss_coin = maxi(Global.player_stats.boss_coin, 50)
	Global.change_to_scene.connect(Callable(self, "change_to_menu"))
	var node : Node = get_node_by_scene(start_scene)
	menu_scene = node
	pass

func change_to_menu(next_menu : Global.Menu) -> void:
	print("changing to "+ str(next_menu))
	var next_menu_node : Node = get_node_by_scene(next_menu)
	menu_scene.queue_free()
	menu_scene = next_menu_node
	pass

func get_node_by_scene(menu : Global.Menu) -> Node:
	var packed : PackedScene = Global.menus.get(menu)
	var next_level : Node = packed.instantiate()
	call_deferred("add_child", next_level)
	return next_level
