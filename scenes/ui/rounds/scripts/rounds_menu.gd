extends Control

@onready
var rounds : HBoxContainer = $NinePatchRect/MarginContainer2/Cards

const ROUND_CARD = preload("res://scenes/ui/rounds/round_card.tscn")

@onready
var status : Array[RoundCardStats] = [
	preload("res://core/resources/ui/rounds_cards/rounds_menu_clear.tres"),
	preload("res://core/resources/ui/rounds_cards/rounds_menu_next.tres"),
	preload("res://core/resources/ui/rounds_cards/rounds_menu_play.tres")
]

func _ready() -> void:
	var player_round : int = Global.player_stats.round_num
	for i : int in range(3):
		var round_card : RoundCard = ROUND_CARD.instantiate()
		if (player_round == i):
			round_card.card_stats = status[2]
		elif (player_round > i):
			round_card.card_stats = status[0]
		else:
			round_card.card_stats = status[1]
		rounds.call_deferred("add_child", round_card)
		round_card.connect("round_button_pressed", Callable(self, "change_to_game"))
		pass
	
		
func change_to_game() -> void:
	Global.change_to_scene.emit(Global.Menu.GAME)
