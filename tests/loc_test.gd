extends Node

func _ready() -> void:
	var en : Dictionary = Loc.languages()[0]["entries"]
	for lang : Dictionary in Loc.languages():
		var missing : int = 0
		for key : String in en:
			if (!(lang["entries"] as Dictionary).has(key)):
				missing += 1
		print(lang["code"], " ", (lang["entries"] as Dictionary).size(), " missing vs en: ", missing)
	Loc.set_language("pt_BR")
	for key : String in ["menu.options", "run.back_to_map", "unit.tank", "weapon.small_gun", "nope.x"]:
		print(key, " => ", Loc.t(key))
	print(Loc.t("menu.best_wave") % 12, " | ", PixelText.fit("run.back_to_map", 8))
	Loc.set_language("en")
	print(Loc.t("menu.options"))
	get_tree().quit()
