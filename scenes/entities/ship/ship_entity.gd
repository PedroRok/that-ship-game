class_name ShipEntity
extends Ship

@export 
var sprite: Sprite2D

@export
var state_machine: StateMachine

func _ready() -> void:
	sprite.texture = boat_stats.sprite
	if (team_stats.direction > 0):
		sprite.flip_h = false
	else:
		sprite.flip_h = true
	state_machine.init(self)
	
func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)
