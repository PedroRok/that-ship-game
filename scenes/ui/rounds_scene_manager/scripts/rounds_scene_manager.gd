extends Node2D

@export
var start_scene_name : String

var menu_scene : Node
@export
var player_stats : PlayerStats

const menus : Dictionary = {
	"SHOP" : "res://scenes/ui/shop/shop_menu.tscn",
	"SELECT" : "res://scenes/ui/rounds/rounds_menu.tscn",
	"GAME" : "res://scenes/game/game.tscn"
}

func _ready() -> void:
	var node : Node = get_node_by_scene("SHOP")
	node.connect("change_to_menu", Callable(self, "change_to_menu"))
	menu_scene = node
	pass

func change_to_menu(next_menu : String) -> void:
	print("changing to "+ next_menu)
	var next_menu_node : Node = get_node_by_scene(next_menu)
	next_menu_node.connect("change_to_menu", Callable(self, "change_to_menu"))
	menu_scene.queue_free()
	menu_scene = next_menu_node
	pass

func get_node_by_scene(menu : String) -> Node:
	var packed : PackedScene = load(menus.get(menu))
	var next_level : Node = packed.instantiate()
	call_deferred("add_child", next_level)
	return next_level
