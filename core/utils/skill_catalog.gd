class_name SkillCatalog
extends RefCounted

const BOMB : StringName = &"bomb"
const BOOST : StringName = &"boost"
const PREFIX : String = "skill_"

static var _all : Array[SkillStats] = []

static func all() -> Array[SkillStats]:
	if (_all.is_empty()):
		_all.append(_make(BOMB, SkillManager.BOMB_COST, true, preload("res://assets/ui/icons/skill_bomb_24x24_v01.png")))
		_all.append(_make(BOOST, SkillManager.BOOST_COST, false, preload("res://assets/ui/icons/skill_boost_24x24_v01.png")))
	return _all

static func _make(id : StringName, cost : int, targeted : bool, icon : Texture2D) -> SkillStats:
	var skill : SkillStats = SkillStats.new()
	skill.skill_id = id
	skill.name = PREFIX + String(id)
	skill.price = cost
	skill.targeted = targeted
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
