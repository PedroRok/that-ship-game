extends PlayerStats

const HUD_LOADOUT_SIZE: int = 10

func toggle_loadout(unit_name: String) -> bool:
	if loadout.has(unit_name):
		loadout.erase(unit_name)
		return true
	if loadout.size() >= HUD_LOADOUT_SIZE or not has_boat(unit_name):
		return false
	loadout.append(unit_name)
	return true

func sanitize_loadout() -> void:
	var cleaned: Array[String] = []
	for unit_name: String in loadout:
		if has_boat(unit_name) and not cleaned.has(unit_name) and cleaned.size() < HUD_LOADOUT_SIZE:
			cleaned.append(unit_name)
	if cleaned.is_empty():
		for stats: EntityStats in unlocked_entities:
			if not cleaned.has(stats.name) and cleaned.size() < HUD_LOADOUT_SIZE:
				cleaned.append(stats.name)
	loadout = cleaned

func add_entity(entity: EntityStats) -> void:
	unlocked_entities.append(entity)
	if loadout.size() < HUD_LOADOUT_SIZE and not loadout.has(entity.name):
		loadout.append(entity.name)
