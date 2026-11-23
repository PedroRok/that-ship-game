class_name WaterBody
extends Node2D

@export_category("Constants")
@export var k : float = 0.015
@export var d : float = 0.03 

var springs : Array = []
var passes : int = 100

var _y : PackedFloat64Array = PackedFloat64Array()
var _v : PackedFloat64Array = PackedFloat64Array()
var _target : PackedFloat64Array = PackedFloat64Array()
var _curve : Curve2D
const WRITE_EPSILON : float = 0.02
const MIN_CLOSED_FORM_SPRINGS : int = 12

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
	_y.resize(springs.size())
	_v.resize(springs.size())
	_target.resize(springs.size())
	for i in range(springs.size()):
		_y[i] = springs[i].position.y
		_v[i] = 0.0
		_target[i] = springs[i].target_height
	_curve = Curve2D.new()
	water_border.curve = _curve



func _physics_process(_delta: float) -> void:
	var count : int = springs.size()
	if count == 0:
		return
	var heights : PackedFloat64Array = _y.duplicate()
	for i in range(count):
		var offset : int = int(_y[i] - _target[i])
		_v[i] += -k * offset - d * _v[i]
		_y[i] += _v[i]
	if passes > 0:
		if count >= MIN_CLOSED_FORM_SPRINGS:
			_spread_closed_form(heights, count)
		else:
			_spread_exact(heights, count)
	_write_back(count)
	new_border()
	draw_water_body()

func _spread_exact(heights : PackedFloat64Array, count : int) -> void:
	for pass_index in range(passes):
		for i in range(count):
			if i > 5:
				_v[i - 1] += spread * (heights[i] - heights[i - 1])
			if i < count - 5:
				_v[i + 1] += spread * (heights[i] - heights[i + 1])
			if i <= 5:
				_v[i] = -0.01
				_v[i - 1] = -0.01

func _spread_closed_form(heights : PackedFloat64Array, count : int) -> void:
	var steps : float = float(passes)
	for j in range(6, count):
		var extra : float = 0.0
		if j <= count - 2:
			extra += spread * (heights[j + 1] - heights[j])
		if j <= count - 5:
			extra += spread * (heights[j - 1] - heights[j])
		_v[j] += steps * extra
	for j in range(0, 5):
		_v[j] = -0.01
	_v[count - 1] = -0.01
	_v[5] = -0.01 + spread * (heights[6] - heights[5])

func _write_back(count : int) -> void:
	for i in range(count):
		var node : Node2D = springs[i]
		if absf(_y[i] - node.position.y) >= WRITE_EPSILON:
			node.position.y = _y[i]

func splash(index : int, speed : float) -> void:
	if index>= 0 and index < springs.size():
		_v[index] += speed
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
	var surface_points : PackedVector2Array = PackedVector2Array()
	surface_points.resize(springs.size())
	for i in range(springs.size()):
		surface_points[i] = springs[i].position
	water_border.set_smooth_points(surface_points)
	water_border.queue_redraw()


func _on_timer_timeout() -> void:
	if (random_waves):
		var rand_val : int = randi_range(15, springs.size() -15)
		splash(rand_val-2, -0.1)
		splash(rand_val-1, -0.3)
		splash(rand_val, -0.5)
		splash(rand_val+1, -0.3)
		splash(rand_val+2, -0.1)
		pass
