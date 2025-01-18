class_name AutoBase
extends Base

@export
var ships : Array[BoatStats]

@export
var time_to_spawn : int = 5

@onready
var timer : Timer = $Timer

func _ready() -> void:
	super._ready()
	timer.wait_time = time_to_spawn
	timer.timeout.connect(Callable(self,"_on_timer_out"))
	_on_timer_out()
	
func _on_timer_out() -> void:
	var ship : BoatStats = ships[randi_range(0, ships.size()-1)]
	start_build_ship(ship)
	
