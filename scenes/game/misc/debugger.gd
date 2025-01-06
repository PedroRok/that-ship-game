extends Control

@export
var camera : GameCam

@export
var ship_spawner : ShipManager

@export
var bullet_manager : BulletManager

@onready
var debug_container: VBoxContainer = $LabelsContainer

var debug_info: Dictionary = {}

func _ready() -> void:
	add_debug_entry("FPS", "0")
	if camera:
		add_debug_entry("Camera Zoom", "0")
		add_debug_entry("Camera Pos", "0, 0")
		add_debug_entry("Camera Global Pos", "0, 0")
	if ship_spawner:
		add_debug_entry("Ships", "0")
	if bullet_manager:
		add_debug_entry("Bullets", "0")

func _process(_delta: float) -> void:
	update_debug("FPS", str(Engine.get_frames_per_second()))
	if camera:
		update_debug("Camera Zoom", str(camera.actual_zoom))
		update_debug("Camera Pos", str(camera.actual_h_pos))
		update_debug("Camera Global Pos", str(camera.global_position))
	if ship_spawner:
		update_debug("Ships", str(ship_spawner.get_children().size() - 1))
	if bullet_manager:
		update_debug("Bullets", str(bullet_manager.get_children().size()))

func add_debug_entry(key: String, initial_value: String) -> void:
	if debug_info.has(key):
		print("Debug key already exists: ", key)
		return
	var hbox : HBoxContainer = HBoxContainer.new()
	var key_label : Label = Label.new()
	key_label.text = key + ": "
	key_label.add_theme_color_override("font_color", Color(1, 1, 1))
	var value_label : Label = Label.new()
	value_label.text = initial_value
	value_label.add_theme_color_override("font_color", Color(1, 1, 0))
	
	hbox.add_child(key_label)
	hbox.add_child(value_label)
	
	debug_container.add_child(hbox)
	
	debug_info[key] = {"value": initial_value, "label": value_label}

func update_debug(key: String, new_value: String) -> void:
	if not debug_info.has(key):
		print("Debug key not found: ", key)
		return
	var debug_entry : Dictionary = debug_info[key]
	if debug_entry["value"] != new_value:
		debug_entry["value"] = new_value
		debug_entry["label"].text = new_value

func remove_debug_entry(key: String) -> void:
	if not debug_info.has(key):
		print("Debug key not found: ", key)
		return
	var debug_entry : Dictionary  = debug_info[key]
	var hbox : HBoxContainer = debug_entry["label"].get_parent()
	debug_container.remove_child(hbox)
	hbox.queue_free()
	debug_info.erase(key)
