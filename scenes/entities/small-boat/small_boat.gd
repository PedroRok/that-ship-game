class_name SmallBoat
extends Ship

@onready 
var sprite = $SmallBoat as Sprite2D

@onready
var state_machine: Node = $StateMachine


func _ready() -> void:
	super._ready()
	if (team_stats.direction > 0):
		sprite.flip_h = false
	else:
		sprite.flip_h = true
		for gun in guns:
			gun.position.x = -gun.position.x
	
	for gun in guns:
		gun.team = team_stats.team_id
		
	state_machine.init(self)
	prints("started", team_stats.team_id)
	
func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)
