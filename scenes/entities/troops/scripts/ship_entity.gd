@tool
class_name ShipEntity
extends Entity

@onready 
var sprite: Sprite2D = $BoatSprite

@onready
var state_machine : StateMachine = $StateMachine

func _ready() -> void:
	if (!entity_stats):
		return
	sprite.texture = entity_stats.sprite
	if (Engine.is_editor_hint()):
		return
	if (team_stats.direction > 0):
		sprite.flip_h = false
	else:
		sprite.flip_h = true
	state_machine.init(self)
	
func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_physics(delta)

func _process(delta: float) -> void:
	if state_machine && !Engine.is_editor_hint():
		state_machine.process_frame(delta)
