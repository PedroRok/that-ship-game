class_name HelicopterStats
extends AirPlaneState

@export_group("Helicopter")
@export
var rotor_frames : Array[Texture2D]
@export
var rotor_fps : float = 30.0
@export
var cruise_height : float = 120.0
@export
var hover_offset : float = 50.0
@export
var strafe : float = 0.25
