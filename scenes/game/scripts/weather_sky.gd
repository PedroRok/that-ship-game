class_name WeatherSky
extends RefCounted

static func _look(weather : int) -> Dictionary:
	match weather:
		RunData.Weather.STORM:
			return {
				"top": "#3a4452", "mid": "#566472", "bot": "#8f9ba5", "tint": "#8c94a3",
				"layers": 12, "height_base": 120.0, "height_range": 150.0, "height_jitter": 30.0,
				"water": Color(0.06, 0.30, 0.58, 0.8), "deep": 0.8, "surface": Color(0.55, 0.75, 0.90),
			}
		RunData.Weather.FOG:
			return {
				"top": "#9fb0ba", "mid": "#c0ccd2", "bot": "#e2e8eb", "tint": "#f2f7ff",
				"layers": 16, "height_base": 110.0, "height_range": 230.0, "height_jitter": 30.0,
				"fog_amount": 0.45, "fog_color": "#d5dde1",
				"mist": {"y": 356.0, "scale": 0.65, "bias": -0.03},
				"water": Color(0.22, 0.50, 0.74, 0.8), "deep": 0.6, "surface": Color(0.85, 0.95, 1.0),
			}
		RunData.Weather.LOW_TIDE:
			return {
				"top": "#3b3a6e", "mid": "#c26b7a", "bot": "#f4b36b", "tint": "#ffb89e",
				"layers": 12, "height_base": 120.0, "height_range": 150.0, "height_jitter": 30.0,
				"water": Color(0.30, 0.36, 0.86, 0.8), "deep": 0.7, "surface": Color(1.0, 0.78, 0.62),
			}
	return {"deep": 0.65}

static func apply(game_round : Node, weather : int) -> void:
	var far_layer : ColorRect = game_round.get_node("Environment/Background") as ColorRect
	var front_layer : ColorRect = game_round.get_node("Environment/CloudsFront") as ColorRect
	var far : ShaderMaterial = (far_layer.material as ShaderMaterial).duplicate() as ShaderMaterial
	var front : ShaderMaterial = (front_layer.material as ShaderMaterial).duplicate() as ShaderMaterial
	far_layer.material = far
	front_layer.material = front
	var look : Dictionary = _look(weather)
	AirPuff.tint = Color(str(look.get("tint", "#ffffff")))
	if (look.has("top")):
		_apply_sky(far, front, look)
	_apply_ocean(game_round, look)

static func _apply_sky(far : ShaderMaterial, front : ShaderMaterial, look : Dictionary) -> void:
	for mat : ShaderMaterial in [far, front]:
		mat.set_shader_parameter("cloud_tint", Color(str(look["tint"])))
	far.set_shader_parameter("sky_top", Color(str(look["top"])))
	far.set_shader_parameter("sky_mid", Color(str(look["mid"])))
	far.set_shader_parameter("sky_bottom", Color(str(look["bot"])))
	far.set_shader_parameter("layers", int(look["layers"]))
	far.set_shader_parameter("height_base", float(look["height_base"]))
	far.set_shader_parameter("height_range", float(look["height_range"]))
	far.set_shader_parameter("height_jitter", float(look["height_jitter"]))
	if (look.has("fog_amount")):
		far.set_shader_parameter("fog_amount", float(look["fog_amount"]))
		far.set_shader_parameter("fog_color", Color(str(look["fog_color"])))
	if (look.has("mist")):
		var mist : Dictionary = look["mist"]
		front.set_shader_parameter("mist_on", true)
		front.set_shader_parameter("mist_y", float(mist["y"]))
		front.set_shader_parameter("mist_scale", float(mist["scale"]))
		front.set_shader_parameter("mist_bias", float(mist["bias"]))

static func _apply_ocean(game_round : Node, look : Dictionary) -> void:
	var water : Polygon2D = game_round.get_node("Environment/Water_Body/Water_Polygon") as Polygon2D
	var water_material : ShaderMaterial = (water.material as ShaderMaterial).duplicate() as ShaderMaterial
	if (look.has("water")):
		water_material.set_shader_parameter("water_tint", look["water"] as Color)
	water_material.set_shader_parameter("deep_amount", float(look.get("deep", 0.0)))
	water.material = water_material
	if (look.has("surface")):
		var border : SmoothPath = game_round.get_node("Environment/Water_Body/Water_Border") as SmoothPath
		border.line_color = look["surface"] as Color
