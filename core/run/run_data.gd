class_name RunData
extends RefCounted

enum NodeType { BATTLE, ELITE, SHIPYARD, EVENT, BOSS }
enum Objective { DESTROY_BASE, DEFEND, ESCORT, HUNT_SUBMARINE, SHOOT_DOWN_BOMBER, DEFEAT_BOSS }
enum Weather { CLEAR, STORM, FOG, LOW_TIDE }
enum Rarity { COMMON, UNCOMMON, RARE, CURSED }
enum Stage { MAP, BRIEFING, BATTLE, NODE_DONE, RELIC, EVENT, SHIPYARD, ENDED }
enum Result { NONE, WON, LOST }

const T_BASE : int = 0
const T_ENTITY : int = 1
const T_GUN : int = 2
const T_SKILL : int = 3
const T_RUN : int = -1

const COLUMNS : int = 4
const ROWS : int = 3
const BOSS_ID : int = COLUMNS * ROWS
const MAX_RISKS : int = 3

const BASE_MAX_HP : int = 100
const NODE_REWARD_BASE : int = 80
const NODE_REWARD_PER_FLOOR : int = 20
const ELITE_REWARD_MULT : float = 1.5
const RELIC_CHANCE_BATTLE : float = 0.3
const REPAIR_HP : int = 25
const REPAIR_COST : int = 60
const UPGRADE_COST : int = 90
const UPGRADE_HEALTH_MULT : float = 1.25
const FAIL_BASE_DAMAGE : int = 20
const RELIC_OFFER_SIZE : int = 3

const GEARS_PER_NODE : int = 6
const GEARS_VICTORY_BONUS : int = 60
const GEARS_PER_LEFTOVER_SCREWS : int = 10
const BOSS_COINS_ON_VICTORY : int = 2

const ENEMY_SPAWN_INTERVAL : Array[float] = [7.0, 6.0, 5.2, 4.5, 4.0]
const ENEMY_HEALTH_MULT : Array[float] = [0.8, 1.0, 1.2, 1.4, 1.6]
const ELITE_HEALTH_MULT : float = 1.35
const WAVE_RAMP_HEALTH : float = 1.06
const WAVE_RAMP_INTERVAL : float = 0.96
const WAVE_DURATION : float = 40.0
const DEFEND_SECONDS : float = 75.0
const DEFEND_RADIUS : float = 160.0
const ESCORT_GOAL : float = 0.85
const HUNT_TARGET : int = 3
const TIME_LIMITS : Dictionary = {
	Objective.DESTROY_BASE: 300.0, Objective.HUNT_SUBMARINE: 180.0, Objective.ESCORT: 150.0,
	Objective.SHOOT_DOWN_BOMBER: 150.0, Objective.DEFEAT_BOSS: 360.0,
}

const BATTLE_DISTANCE : Dictionary = {
	Objective.DESTROY_BASE: [1800.0, 3000.0], Objective.DEFEND: [1600.0, 2400.0],
	Objective.ESCORT: [2000.0, 3200.0], Objective.HUNT_SUBMARINE: [1600.0, 2400.0],
	Objective.SHOOT_DOWN_BOMBER: [1600.0, 2400.0], Objective.DEFEAT_BOSS: [2400.0, 3600.0],
}
const BATTLE_DISTANCE_JITTER : float = 0.1
const CLASSIC_DISTANCE : float = 2000.0

const NODE_NAMES : Dictionary = {
	NodeType.BATTLE: "Battle", NodeType.ELITE: "Elite Battle", NodeType.SHIPYARD: "Shipyard",
	NodeType.EVENT: "Event", NodeType.BOSS: "Boss",
}
const NODE_ICON_KEYS : Dictionary = {
	NodeType.BATTLE: "battle", NodeType.ELITE: "elite", NodeType.SHIPYARD: "shipyard",
	NodeType.EVENT: "event", NodeType.BOSS: "boss",
}

const OBJECTIVES : Dictionary = {
	Objective.DESTROY_BASE: {"name": "Destroy Base", "text": "Destroy the enemy base.", "icon": "destroy_base"},
	Objective.DEFEND: {"name": "Defend", "text": "Hold the beacon until the countdown ends.", "icon": "defend"},
	Objective.ESCORT: {"name": "Escort", "text": "Protect the cargo ship until it reaches the exit.", "icon": "escort"},
	Objective.HUNT_SUBMARINE: {"name": "Submarine Hunt", "text": "Sink the enemy submarines.", "icon": "hunt_submarine"},
	Objective.SHOOT_DOWN_BOMBER: {"name": "Bomber Down", "text": "Shoot down the heavy bomber.", "icon": "shoot_down_bomber"},
	Objective.DEFEAT_BOSS: {"name": "Defeat the Boss", "text": "Sink the sector boss.", "icon": "destroy_base"},
}
const BATTLE_OBJECTIVES : Array[int] = [
	Objective.DESTROY_BASE, Objective.DEFEND, Objective.ESCORT,
	Objective.HUNT_SUBMARINE, Objective.SHOOT_DOWN_BOMBER,
]

const WEATHER : Dictionary = {
	Weather.CLEAR: {"name": "Clear Sky", "icon": "clear_sky", "text": "No effect.", "difficulty": 0,
		"effects": []},
	Weather.STORM: {"name": "Storm", "icon": "storm", "text": "Allied units move 15% slower.", "difficulty": 1,
		"effects": [{"target": T_ENTITY, "stat": &"speed", "op": "mul", "value": 0.85}]},
	Weather.FOG: {"name": "Fog", "icon": "fog", "text": "Allied radar range -30%.", "difficulty": 1,
		"effects": [{"target": T_ENTITY, "stat": &"radar_distance", "op": "mul", "value": 0.7}]},
	Weather.LOW_TIDE: {"name": "Low Tide", "icon": "low_tide", "text": "Drained docks: allied ships build 15% faster.", "difficulty": 0,
		"effects": [{"target": T_BASE, "stat": &"build_time", "op": "mul", "value": 0.85}]},
}
const WEATHER_WEIGHTS : Dictionary = {
	Weather.CLEAR: 4.0, Weather.STORM: 2.0, Weather.FOG: 2.0, Weather.LOW_TIDE: 2.0,
}

const RARITY_NAMES : Dictionary = {
	Rarity.COMMON: "COMMON", Rarity.UNCOMMON: "UNCOMMON", Rarity.RARE: "RARE", Rarity.CURSED: "CURSED",
}
const RARITY_COLORS : Dictionary = {
	Rarity.COMMON: Color("#c5cdd0"), Rarity.UNCOMMON: Color("#a2d5ad"),
	Rarity.RARE: Color("#9bbeeb"), Rarity.CURSED: Color("#dfa0a2"),
}
const RARITY_WEIGHTS : Dictionary = {
	Rarity.COMMON: 55.0, Rarity.UNCOMMON: 28.0, Rarity.RARE: 12.0, Rarity.CURSED: 8.0,
}
const RARITY_FRAME_KEYS : Dictionary = {
	Rarity.COMMON: "common", Rarity.UNCOMMON: "uncommon", Rarity.RARE: "rare", Rarity.CURSED: "cursed",
}

const RELICS : Dictionary = {
	&"bomb": {"name": "Heavy Ordnance", "rarity": Rarity.COMMON, "icon": "bomb",
		"text": "Bomb strikes deal more damage.", "tag": "+30% BOMB DAMAGE",
		"effects": [{"target": T_SKILL, "stat": &"bomb_damage", "op": "mul", "value": 1.3}]},
	&"ammo": {"name": "Spare Ammo", "rarity": Rarity.COMMON, "icon": "ammo",
		"text": "All allied guns hit a little harder.", "tag": "+8% GUN DAMAGE",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.08}]},
	&"shield": {"name": "Bow Plating", "rarity": Rarity.UNCOMMON, "icon": "shield",
		"text": "The base takes less damage in the next battles.", "tag": "-15% BASE DAMAGE TAKEN",
		"effects": [{"target": T_BASE, "stat": &"damage_taken", "op": "mul", "value": 0.85}]},
	&"gear": {"name": "Salvage Gear", "rarity": Rarity.COMMON, "icon": "gear",
		"text": "Destroyed ships drop gears more often.", "tag": "+50% GEAR DROPS",
		"effects": [{"target": T_BASE, "stat": &"gear_drop_chance", "op": "mul", "value": 1.5}]},
	&"repair": {"name": "Field Repairs", "rarity": Rarity.COMMON, "icon": "repair",
		"text": "The base repairs itself after each battle.", "tag": "+8 HP AFTER BATTLE",
		"effects": [{"target": T_RUN, "stat": &"heal_after_battle", "op": "add", "value": 8.0}]},
	&"radar": {"name": "Long-Range Radar", "rarity": Rarity.COMMON, "icon": "radar",
		"text": "Allied units spot enemies from farther away.", "tag": "+25% RADAR RANGE",
		"effects": [{"target": T_ENTITY, "stat": &"radar_distance", "op": "mul", "value": 1.25}]},
	&"hull": {"name": "Reinforced Hull", "rarity": Rarity.UNCOMMON, "icon": "hull",
		"text": "Allied ships are tougher.", "tag": "+15% UNIT HEALTH",
		"effects": [{"target": T_ENTITY, "stat": &"health", "op": "mul", "value": 1.15}]},
	&"fuel": {"name": "Extra Fuel", "rarity": Rarity.UNCOMMON, "icon": "fuel",
		"text": "Allied ships sail faster.", "tag": "+12% UNIT SPEED",
		"effects": [{"target": T_ENTITY, "stat": &"speed", "op": "mul", "value": 1.12}]},
	&"anchor": {"name": "Heavy Anchor", "rarity": Rarity.UNCOMMON, "icon": "anchor",
		"text": "A sturdier base for the rest of the run.", "tag": "+20 MAX BASE HP",
		"effects": [{"target": T_RUN, "stat": &"max_hp", "op": "add", "value": 20.0}]},
	&"compass": {"name": "Glass Compass", "rarity": Rarity.RARE, "icon": "compass",
		"text": "Better routes: battles pay more screws.", "tag": "+15% NODE SCREWS",
		"effects": [{"target": T_RUN, "stat": &"reward_mult", "op": "mul", "value": 1.15}]},
	&"torpedo": {"name": "Quick Loaders", "rarity": Rarity.RARE, "icon": "torpedo",
		"text": "Allied guns reload faster.", "tag": "-10% RELOAD TIME",
		"effects": [{"target": T_GUN, "stat": &"shoot_interval", "op": "mul", "value": 0.9}]},
	&"engine": {"name": "Tuned Engine", "rarity": Rarity.RARE, "icon": "engine",
		"text": "Docks produce ships faster.", "tag": "-15% BUILD TIME",
		"effects": [{"target": T_BASE, "stat": &"build_time", "op": "mul", "value": 0.85}]},
	&"cannon": {"name": "Rifled Barrels", "rarity": Rarity.RARE, "icon": "cannon",
		"text": "Allied guns deal more damage.", "tag": "+15% GUN DAMAGE",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.15}]},
	&"flare": {"name": "Signal Flares", "rarity": Rarity.RARE, "icon": "flare",
		"text": "Bomb strikes recharge faster.", "tag": "-20% BOMB COOLDOWN",
		"effects": [{"target": T_SKILL, "stat": &"bomb_cooldown", "op": "mul", "value": 0.8}]},
	&"supply_crate": {"name": "Supply Crate", "rarity": Rarity.UNCOMMON, "icon": "supply_crate",
		"text": "Start every battle with more screws.", "tag": "+25% STARTING SCREWS",
		"effects": [{"target": T_BASE, "stat": &"start_screw", "op": "mul", "value": 1.25}]},
	&"cursed_item": {"name": "Salt Heart", "rarity": Rarity.CURSED, "icon": "cursed_item",
		"text": "Allied guns deal +30% damage. The base loses 10 max HP.", "tag": "+30% DAMAGE / -10 MAX HP",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.3},
			{"target": T_RUN, "stat": &"max_hp", "op": "add", "value": -10.0}],
		"penalty": true},
}

const RISKS : Dictionary = {
	&"stronger_enemies": {"name": "Armored Enemies", "text": "+25% enemy health", "icon": "stronger_enemies",
		"bonus": 0.15, "effects": [{"target": T_RUN, "stat": &"enemy_health", "op": "mul", "value": 1.25}]},
	&"fewer_screws": {"name": "Short Supplies", "text": "-20% starting screws", "icon": "fewer_screws",
		"bonus": 0.10, "effects": [{"target": T_BASE, "stat": &"start_screw", "op": "mul", "value": 0.8}]},
	&"forced_storm": {"name": "Forced Storm", "text": "Weather is fixed to Storm", "icon": "forced_storm",
		"bonus": 0.10, "effects": [{"target": T_RUN, "stat": &"force_weather", "op": "add", "value": float(Weather.STORM)}]},
	&"less_time": {"name": "Less Time", "text": "-20% time available", "icon": "less_time",
		"bonus": 0.20, "effects": [{"target": T_RUN, "stat": &"time_mult", "op": "mul", "value": 0.8}]},
	&"fragile_base": {"name": "Fragile Base", "text": "+25% damage taken by base", "icon": "fragile_base",
		"bonus": 0.15, "effects": [{"target": T_BASE, "stat": &"damage_taken", "op": "mul", "value": 1.25}]},
	&"more_bosses": {"name": "More Bosses", "text": "+1 boss in the battle", "icon": "more_bosses",
		"bonus": 0.25, "effects": [{"target": T_RUN, "stat": &"extra_boss", "op": "add", "value": 1.0}]},
}

const EVENTS : Array[Dictionary] = [
	{"id": &"drifting_signal", "title": "Drifting Signal", "tag": "DISTRESS BEACON",
		"text": "An old beacon blinks among the wreckage.\nThe signal points at a cargo crate.",
		"choices": [
			{"label": "Take the crate", "text": "Gain 80 screws. The base loses 8 HP.", "icon": "cargo_box", "screws": 80, "hp": -8},
			{"label": "Investigate the signal", "text": "Receive a relic offer. The base loses 5 HP.", "icon": "beacon_signal", "relic_offer": true, "hp": -5},
			{"label": "Sail on", "text": "Return to the map.", "icon": "continue_trip"},
		]},
	{"id": &"stranded_crew", "title": "Stranded Crew", "tag": "DISTRESS CALL",
		"text": "A crew waves from a sinking trawler.\nThey offer their help if you pick them up.",
		"choices": [
			{"label": "Rescue them", "text": "Pay 40 screws. The base repairs 20 HP.", "icon": "repair", "screws": -40, "hp": 20},
			{"label": "Salvage the wreck", "text": "Gain 60 screws. The base loses 6 HP.", "icon": "cargo_box", "screws": 60, "hp": -6},
			{"label": "Sail on", "text": "Return to the map.", "icon": "continue_trip"},
		]},
	{"id": &"black_market", "title": "Black Market", "tag": "MERCHANT VESSEL",
		"text": "A rusted merchant flashes its lamps.\nEverything has a price out here.",
		"choices": [
			{"label": "Buy a relic", "text": "Pay 120 screws. Receive a relic offer.", "icon": "cargo_box", "screws": -120, "relic_offer": true},
			{"label": "Sell supplies", "text": "Gain 70 screws. The base loses 10 HP.", "icon": "beacon_signal", "screws": 70, "hp": -10},
			{"label": "Sail on", "text": "Return to the map.", "icon": "continue_trip"},
		]},
]

const EVENT_BANNER : Dictionary = {
	&"drifting_signal": "res://assets/ui/run_map/event_banner_lost_signal_v01.png",
}

const MAP_DIR : String = "res://assets/ui/run_map/"
const ICON_DIR : String = "res://assets/ui/icons/"

static func node_glyph(node_type : int, state : String) -> Texture2D:
	return load("%snode_%s_%s_v01.png" % [MAP_DIR, NODE_ICON_KEYS[node_type], state]) as Texture2D

static func objective_overlay(objective : int) -> Texture2D:
	var key : String = OBJECTIVES[objective]["icon"]
	return load("%sobjective_%s_v01.png" % [MAP_DIR, key]) as Texture2D

static func objective_hud_icon(objective : int) -> Texture2D:
	var key : String = OBJECTIVES[objective]["icon"]
	return load("res://assets/ui/hud/objective_%s_v01.png" % key) as Texture2D

static func weather_icon(weather : int) -> Texture2D:
	return load("res://assets/ui/weather/%s_v01.png" % WEATHER[weather]["icon"]) as Texture2D

static func relic_icon(relic_id : StringName) -> Texture2D:
	return load("res://assets/ui/relics/%s_v01.png" % RELICS[relic_id]["icon"]) as Texture2D

static func risk_icon(risk_id : StringName) -> Texture2D:
	return load("res://assets/ui/modifiers/%s_v01.png" % RISKS[risk_id]["icon"]) as Texture2D

static func ui_icon(key : String, dim : bool = false) -> Texture2D:
	return load("%s%s%s_v01.png" % [ICON_DIR, key, "_dim" if dim else ""]) as Texture2D

static func event_by_id(event_id : StringName) -> Dictionary:
	for event : Dictionary in EVENTS:
		if (event["id"] == event_id):
			return event
	return EVENTS[0]
