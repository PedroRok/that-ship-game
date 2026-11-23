class_name GearFlyer
extends CanvasLayer

const TRAIL: int = 3
const TRAIL_LAG: float = 0.07

var start: Vector2
var target: Control
var duration: float = 0.7
var arc_height: float = 70.0
var spin: float = 9.0
var start_scale: float = 1.0
var elapsed: float = 0.0
var sprites: Array[Sprite2D] = []
var on_arrive: Callable

static func launch(host: Node, texture: Texture2D, from_screen: Vector2, to: Control, from_scale: float, arrive: Callable) -> GearFlyer:
	var flyer := GearFlyer.new()
	flyer.layer = 120
	flyer.start = from_screen
	flyer.target = to
	flyer.start_scale = from_scale
	flyer.on_arrive = arrive
	flyer.arc_height = randf_range(50.0, 90.0)
	flyer.spin = randf_range(7.0, 11.0) * (1.0 if randf() < 0.5 else -1.0)
	for index: int in range(TRAIL + 1):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate.a = 1.0 if index == 0 else 0.34 / float(index)
		flyer.add_child(sprite)
		flyer.sprites.append(sprite)
	host.get_tree().root.add_child(flyer)
	flyer._place(0.0)
	return flyer

func _goal() -> Vector2:
	return target.get_global_rect().get_center() if is_instance_valid(target) else start

func _curve(progress: float) -> Vector2:
	var goal: Vector2 = _goal()
	var control: Vector2 = (start + goal) * 0.5 + Vector2(0.0, -arc_height)
	var inverse: float = 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * goal

func _eased(time: float) -> float:
	var x: float = clampf(time / duration, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x) * 0.35 + x * x * x * 0.65

func _icon_scale() -> float:
	if not is_instance_valid(target) or sprites.is_empty():
		return start_scale
	var width: float = sprites[0].texture.get_width()
	return (target.size.x * 0.75) / maxf(1.0, width)

func _place(time: float) -> void:
	var final_scale: float = _icon_scale()
	for index: int in range(sprites.size()):
		var delayed: float = maxf(0.0, time - float(index) * TRAIL_LAG)
		var progress: float = _eased(delayed)
		var sprite: Sprite2D = sprites[index]
		sprite.position = _curve(progress).round()
		sprite.rotation = spin * delayed
		sprite.scale = Vector2.ONE * lerpf(start_scale, final_scale, progress)
		sprite.visible = index == 0 or time > float(index) * TRAIL_LAG

func _process(delta: float) -> void:
	elapsed += delta
	_place(elapsed)
	if elapsed >= duration:
		if on_arrive.is_valid():
			on_arrive.call()
		queue_free()
