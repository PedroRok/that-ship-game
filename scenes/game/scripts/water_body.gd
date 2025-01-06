class_name WaterBody
extends Node2D

@export_category("Constants")
@export var k : float = 0.015
@export var d : float = 0.03 

var springs : Array = []
var passes : int = 100

@export_category("Wave Spring")
@export var spread : float = 1.5
@export var distance_between_springs : int =  20
@export var spring_number : int = 40

var water_lenght : int = distance_between_springs * spring_number

@onready var water_spring : PackedScene = preload("res://scenes/game/misc/water_spring.tscn")

@export_category("Ocean")
@export var depth : int = 1000
@export var border_thickness : float = 1
@export var random_waves : bool = true


var target_height : int = global_position.y
var bottom : int = target_height + depth

@onready var water_polygon : Polygon2D = $Water_Polygon
@onready var water_border : SmoothPath = $Water_Border

func _ready() -> void:
	
	spread = spread / 10000
	water_border.width = border_thickness
	
	for i in range(spring_number):
		var x_position : int = distance_between_springs * i
		var w : Node2D = water_spring.instantiate()
		add_child(w)
		springs.append(w)
		w.initialize(x_position, i)
		w.set_collision_width(distance_between_springs)
		w.connect("splash", Callable(self, "splash"))
	pass



func _physics_process(_delta: float) -> void:
	for i : Node2D in springs:
		i.water_update(k, d)
		
		
	var left_deltas : Array = []
	var right_deltas : Array = []
	for i in range (springs.size()):
		left_deltas.append(0)
		right_deltas.append(0)
		pass
		
	for j in range(passes):
		for i in range(springs.size()):
			if i > 5:
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
				
			if i < springs.size()-5:
				right_deltas[i] = spread * (springs[i].height - springs[i+1].height)
				springs[i+1].velocity += right_deltas[i]
				
			if i <= 5:
				left_deltas[i] = 0
				springs[i].velocity = -0.01
				springs[i-1].velocity = -0.01
		pass
	new_border()
	draw_water_body()
		
func splash(index : int, speed : float) -> void:
	if index>= 0 and index < springs.size():
		springs[index].velocity += speed
	pass
	
func draw_water_body() -> void:
	
	var curve : Curve2D = water_border.curve
	var points : Array = Array(curve.get_baked_points())
		
	var water_polygon_points : Array = points;
		
	var first_index : int = 0
	var last_index : int = water_polygon_points.size()-1
	
	water_polygon_points.append(Vector2(water_polygon_points[last_index].x, bottom))
	water_polygon_points.append(Vector2(water_polygon_points[first_index].x, bottom))
	
	water_polygon_points = PackedVector2Array(water_polygon_points)
	
	water_polygon.set_polygon(water_polygon_points)
	water_polygon.set_uv(water_polygon_points)
	
func new_border() -> void:
	var curve : Curve2D = Curve2D.new().duplicate()
	
	var surface_points : Array = []
	
	for i in range(springs.size()):
		surface_points.append(springs[i].position)
		
	for i in range(surface_points.size()):
		curve.add_point(surface_points[i])
	
	water_border.curve = curve
	water_border.smooth(true)
	water_border.queue_redraw()


func _on_timer_timeout() -> void:
	if (random_waves):
		var rand_val : int = randi_range(15, springs.size() -15)
		splash(rand_val-2, -0.1)
		splash(rand_val-1, -0.3)
		splash(rand_val, -0.5)
		splash(rand_val+1, -0.3)
		splash(rand_val+2, -0.1)
		pass # Replace with function body.
