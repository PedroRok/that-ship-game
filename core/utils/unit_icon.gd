class_name UnitIcon
extends RefCounted

static var _cache : Dictionary = {}

static func of(stats : EntityStats, frame : int = 0) -> Texture2D:
	var air : AirPlaneState = stats as AirPlaneState
	if (!air or air.body_frames.is_empty()):
		return stats.sprite if stats else null
	var index : int = clampi(frame, 0, air.body_frames.size() - 1)
	var key : String = "%s:%d" % [stats.name, index]
	if (_cache.has(key)):
		return _cache[key]
	var img : Image = air.body_frames[index].get_image()
	img.convert(Image.FORMAT_RGBA8)
	if (air is HelicopterStats):
		var rotors : Array[Texture2D] = (air as HelicopterStats).rotor_frames
		if (!rotors.is_empty()):
			var rotor : Image = rotors[0].get_image()
			rotor.convert(Image.FORMAT_RGBA8)
			img.blend_rect(rotor, Rect2i(Vector2i.ZERO, rotor.get_size()), Vector2i.ZERO)
	elif (!air.blade_frames.is_empty()):
		var blade : Image = air.blade_frames[0].get_image()
		blade.convert(Image.FORMAT_RGBA8)
		var offsets : Array[Vector2] = []
		for list : Array[Vector2] in [air.prop_far, air.prop_near, air.prop_far_inner, air.prop_near_inner]:
			if (index < list.size()):
				offsets.append(list[index])
		for offset : Vector2 in offsets:
			var center : Vector2 = Vector2(img.get_size()) * 0.5 + offset
			var dest : Vector2i = Vector2i((center - Vector2(blade.get_size()) * 0.5).round())
			img.blend_rect(blade, Rect2i(Vector2i.ZERO, blade.get_size()), dest)
	var result : Texture2D = ImageTexture.create_from_image(img)
	_cache[key] = result
	return result

static func of_sprite(stats : EntityStats) -> Texture2D:
	var air : AirPlaneState = stats as AirPlaneState
	if (air and !air.body_frames.is_empty()):
		return of(stats, maxi(air.body_frames.find(air.sprite), 0))
	return stats.sprite if stats else null
