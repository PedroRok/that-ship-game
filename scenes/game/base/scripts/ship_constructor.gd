class_name ShipConstructor
extends Sprite2D


signal ship_build_finish(boat_stats : BoatStats)

var boat_stats : BoatStats

func _ready() -> void:
	if (Engine.is_editor_hint()):
		return
	texture = null
	
func is_building() -> bool:
	return boat_stats != null

func build_ship(boat_stats : BoatStats) -> void:
	#TODO: Criar um tween que varia entre o valor do shader de build progress e emit um signal
	texture = boat_stats.sprite
	material.set_shader_parameter("build_progress", 0.0)
	var tween : Tween = create_tween()
	tween.tween_property(
			material,
			"shader_parameter/build_progress",
			1.0,
			boat_stats.produce_cd
		)
	tween.finished.connect(Callable(self, "_on_build_complete"))
	self.boat_stats = boat_stats
	pass

func _on_build_complete() -> void:
	ship_build_finish.emit(boat_stats)
	texture = null
	boat_stats = null
