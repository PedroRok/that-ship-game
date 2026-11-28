class_name SkillCatalog
extends RefCounted

const BOMB : StringName = &"bomb"
const REPAIR : StringName = &"repair"
const FLAK : StringName = &"flak"
const SUPPLY : StringName = &"supply"
const PREFIX : String = "skill_"
const BOMB_COST : int = 80
const REPAIR_COST : int = 40
const FLAK_COST : int = 60
const SUPPLY_COST : int = 35

static var _all : Array[SkillStats] = []

static func all() -> Array[SkillStats]:
	if (_all.is_empty()):
		_all.append(_make(REPAIR, REPAIR_COST, true, &"", preload("res://assets/ui/icons/skill_repair_24x24_v01.png")))
		_all.append(_make(SUPPLY, SUPPLY_COST, false, &"r_unlock_supply", preload("res://assets/ui/icons/skill_supply_24x24_v01.png")))
		_all.append(_make(FLAK, FLAK_COST, false, &"r_unlock_flak", preload("res://assets/ui/icons/skill_flak_24x24_v01.png")))
		_all.append(_make(BOMB, BOMB_COST, true, &"r_unlock_bomb", preload("res://assets/ui/icons/skill_bomb_24x24_v01.png")))
	return _all

static func _make(id : StringName, cost : int, targeted : bool, unlock_id : StringName, icon : Texture2D) -> SkillStats:
	var skill : SkillStats = SkillStats.new()
	skill.skill_id = id
	skill.name = PREFIX + String(id)
	skill.price = cost
	skill.targeted = targeted
	skill.unlock_id = unlock_id
	skill.sprite = icon
	skill.description = "skill.%s_desc" % String(id)
	return skill

static func find(unit_name : String) -> SkillStats:
	if (!unit_name.begins_with(PREFIX)):
		return null
	for skill : SkillStats in all():
		if (skill.name == unit_name):
			return skill
	return null
