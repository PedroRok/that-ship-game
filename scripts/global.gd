extends Node

var center_camera_pos : Vector2

var camera_zoom : float

signal change_to_scene(name : Menu)

var player_stats : PlayerStats = preload("res://core/resources/player/player_stats_full.tres")

enum Menu {
	SHOP,
	SELECT,
	GAME
}

const menus : Dictionary = {
	Menu.SHOP : preload("res://scenes/ui/shop/shop_menu.tscn"),
	Menu.SELECT : preload("res://scenes/ui/rounds/rounds_menu.tscn"),
	Menu.GAME : preload("res://scenes/game/game.tscn")
}

func change_scene(name : Menu) -> void:
	change_to_scene.emit(name)
