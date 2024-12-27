class_name SmallBoat
extends Ship

@onready 
var sprite = $SmallBoat as Sprite2D

@onready 
var particle = $GPUParticles as GPUParticles2D
@onready 
var fire_particle = $FireParticle as GPUParticles2D
@onready
var hit_particle = $HitParticle as GPUParticles2D

@export
var boat_stats : BoatStats

@onready
var state_machine: Node = $StateMachine

@onready
var gun: Gun = $Gun

func _ready() -> void:
	if (direction > 0):
		sprite.flip_h = false
		particle.position.x = -particle.position.x
		particle.amount_ratio = 1
		var material = particle.process_material as ParticleProcessMaterial
		material.gravity.x = -direction * 90
	else:
		sprite.flip_h = true
		gun.position.x = -gun.position.x
		prints("flip-dir")
		particle.position.x = particle.position.x
	
	gun.team = team
		
	state_machine.init(self)
	prints("started", team)
	
func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

func get_gun() -> Gun:
	return gun
