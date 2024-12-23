extends Node2D

@export_category("Constants")
@export var k : float = 0.015
@export var d : float = 0.03 

var springs = []
var passes = 100

@export_category("Wave Spring")
@export var spread = 1.5
@export var distance_between_springs =  20
@export var spring_number = 40

var water_lenght = distance_between_springs * spring_number

@onready var water_spring = preload("res://scenes/game/misc/water_spring.tscn")

@export_category("Ocean")
@export var depth = 1000
@export var border_thickness = 1
@export var random_waves = true


var target_height = global_position.y
var bottom = target_height + depth

@onready var water_polygon = $Water_Polygon
@onready var water_border = $Water_Border

func _ready():
	
	spread = spread / 10000
	water_border.width = border_thickness
	
	for i in range(spring_number):
		var x_position = distance_between_springs * i
		var w = water_spring.instantiate()
		add_child(w)
		springs.append(w)
		w.initialize(x_position, i)
		w.set_collision_width(distance_between_springs)
		w.connect("splash", Callable(self, "splash"))
	pass



func _physics_process(delta: float) -> void:
	for i in springs:
		i.water_update(k, d)
		
		
	var left_deltas = []
	var right_deltas = []
	for i in range (springs.size()):
		left_deltas.append(0)
		right_deltas.append(0)
		pass
		
	for j in range(passes):
		for i in range(springs.size()):
			if i > 0:
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
				
			if i < springs.size()-1:
				right_deltas[i] = spread * (springs[i].height - springs[i+1].height)
				springs[i+1].velocity += right_deltas[i]
		pass
	new_border()
	draw_water_body()
		
func splash(index, speed):
	if index>= 0 and index < springs.size():
		springs[index].velocity += speed
	pass
	
func draw_water_body():
	
	var curve = water_border.curve
	var points = Array(curve.get_baked_points())
		
	var water_polygon_points = points;
		
	var first_index = 0
	var last_index = water_polygon_points.size()-1
	
	water_polygon_points.append(Vector2(water_polygon_points[last_index].x, bottom))
	water_polygon_points.append(Vector2(water_polygon_points[first_index].x, bottom))
	
	water_polygon_points = PackedVector2Array(water_polygon_points)
	
	water_polygon.set_polygon(water_polygon_points)
	water_polygon.set_uv(water_polygon_points)
	
func new_border():
	var curve = Curve2D.new().duplicate()
	
	var surface_points = []
	
	for i in range(springs.size()):
		surface_points.append(springs[i].position)
		
	for i in range(surface_points.size()):
		curve.add_point(surface_points[i])
	
	water_border.curve = curve
	water_border.smooth(true)
	water_border.queue_redraw()


func _on_timer_timeout() -> void:
	if (random_waves):
		var rand_val = randi_range(15, springs.size() -15)
		splash(rand_val-2, -0.1)
		splash(rand_val-1, -0.3)
		splash(rand_val, -0.5)
		splash(rand_val+1, -0.3)
		splash(rand_val+2, -0.1)
		pass # Replace with function body.
