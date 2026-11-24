class_name PixelText
extends RefCounted

static func snap(size : int) -> int:
	return maxi(1, roundi((size - 1) / 8.0)) * 8

static func fit(text : String, size : int) -> String:
	return text.to_upper() if snap(size) <= 8 else text
