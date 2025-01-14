extends Node

var center_camera_pos : Vector2

var camera_zoom : float

signal change_to_scene(name : Menu)

var player_stats : PlayerStats

enum Menu {
	SHOP,
	SELECT,
	GAME
}

const menus : Dictionary = {
	Menu.SHOP : "res://scenes/ui/shop/shop_menu.tscn",
	Menu.SELECT : "res://scenes/ui/rounds/rounds_menu.tscn",
	Menu.GAME : "res://scenes/game/game.tscn"
}
