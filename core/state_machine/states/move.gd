extends State

@export
var movable_component : MovableComponent

@export
var health_component : HealthComponent

@export
var radar_component : RadarComponent

func enter() -> void:
	movable_component.direction = parent.direction
	pass
	
func process_input(event: InputEvent) -> void:
	return

func process_physics(delta: float) -> void:
	super(delta)
	
	if (health_component.get_health() <= 0):
		Transitioned.emit(self, "death")
		return
	
	var target_velocity_x = movable_component.get_movement_direction() * move_speed
	parent.linear_velocity.x = lerp(parent.linear_velocity.x, target_velocity_x, deceleration * delta)
	if (radar_component.check_radar(parent.team, movable_component.get_movement_direction())):
		Transitioned.emit(self, "attack")
		return
