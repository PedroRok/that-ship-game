extends Timer

@export
var manager : ShipManager
@onready
var team_right : TeamStats = preload("res://core/resources/teams/team_right.tres")

func _ready() -> void:
	_on_spawner_timeout()

func _on_spawner_timeout() -> void:
	manager.handle_ship_spawn(position, manager.ShipsTypes.SMALL, team_right)
	pass # Replace with function body.
