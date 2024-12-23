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

## Velocidade de movimento do personagem
#@export var speed: float = 200.0
#
## Taxa de desaceleração
#@export var deceleration: float = 1.0
#
## Ângulo máximo de inclinação em radianos (ex.: 0.2 rad = ~11.5 graus)
#@export var max_tilt_angle: float = 0.2
#
#@onready var sprite = $SmallBoat
#@onready var particle = $GPUParticles2D as GPUParticles2D
#
#func _physics_process(delta: float) -> void:
#	var direction = Vector2.ZERO
#
#	# Detecta entradas do teclado
#	if Input.is_action_pressed("ui_right"):
#		direction.x += 1
#		sprite.flip_h = false
#	elif Input.is_action_pressed("ui_left"):
#		direction.x -= 1
#		sprite.flip_h = true
#
#	# Calcula a velocidade desejada
#	var target_velocity_x = direction.x * speed
#
#	# Suaviza a transição para a velocidade alvo usando `lerp`
#	linear_velocity.x = lerp(linear_velocity.x, target_velocity_x, deceleration * delta)
#	# Rotação com base na velocidade
#	rotation = -linear_velocity.x / speed * max_tilt_angle
#	
#	if (abs(linear_velocity.x) > 0.1):
#		particle.amount_ratio = 1
#		var material = particle.process_material as ParticleProcessMaterial
#		material.gravity.x = -direction.x * 90
#		if (direction.x > 0):
#			particle.transform.x.x = -13
#		else:
#			particle.transform.x.x = 13
#		pass
#	else:
#		particle.amount_ratio = 0
#
