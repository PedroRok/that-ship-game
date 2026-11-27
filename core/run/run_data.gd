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

const GEARS_PER_NODE : int = 12
const GEARS_PER_MISSION : int = 8
const GEARS_BASE_DESTROYED : int = 12
const ENEMY_SUPPLY_RATE : Array[float] = [1.0, 1.2, 1.4, 1.8]
const ENEMY_SUPPLY_BOSS : float = 1.6
const SUPPLY_START_SECONDS : float = 8.0
const SUPPLY_MAX_BANK : float = 60.0
const ALERT_SUPPLY_MULT : Array[float] = [1.0, 1.3, 1.7]
const ALERT_COUNTER_SHARE : Array[float] = [0.4, 0.5, 0.6]
const ALERT_MID_PROGRESS : float = 0.55
const ALERT_NEAR_PROGRESS : float = 0.72
const ALERT_MID_VALUE : float = 8.0
const ALERT_NEAR_VALUE : float = 8.0
const ALERT_BASE_FRACTION : float = 0.5
const ALERT_HOLD_SECONDS : float = 6.0
const ALERT_RESERVE : float = 20.0
const OPENING_STRIKE_CHANCE : float = 0.35
const OPENING_STRIKE_SECONDS : float = 30.0
const OPENING_SLOW_MULT : float = 0.5
const OPENING_SLOW_SECONDS : float = 44.0
const THREAT_MIN_WEIGHT : float = 0.15
const ROSTER_EXTRA_MAX : int = 2
const ROSTER_MAX : int = 10
const LOG_SAMPLE_SECONDS : float = 5.0
const PLAN_SECONDS : float = 8.0
const WAR_BONDS_NODE_MULT : float = 2.0
const GEARS_VICTORY_BONUS : int = 90
const BOSS_COINS_ON_VICTORY : int = 2

const ENEMY_SPAWN_INTERVAL : Array[float] = [7.5, 7.0, 6.5, 5.8, 5.0]
const ENEMY_HEALTH_MULT : Array[float] = [0.72, 0.78, 0.9, 1.15, 1.35]
const ELITE_HEALTH_MULT : float = 1.35
const DIRECTOR_W_UNITS : float = 0.50
const DIRECTOR_W_PROGRESS : float = 0.35
const DIRECTOR_W_BASE_HP : float = 0.15
const DIRECTOR_RANGE : float = 0.30
const DIRECTOR_MAX_SKIP : float = 0.25
const DIRECTOR_SMOOTH_SECONDS : float = 10.0
const DIRECTOR_SAMPLE_SECONDS : float = 0.5
const DIRECTOR_MIN_UNITS : int = 4
const WAVE_RAMP_HEALTH : float = 1.06
const WAVE_RAMP_INTERVAL : float = 0.96
const WAVE_DURATION : float = 40.0
const DEFEND_HOLD_SECONDS : float = 75.0
const DEFEND_LIMIT_SECONDS : float = 240.0
const DEFEND_RADIUS : float = 160.0
const DEFEND_PREP_SECONDS : float = 10.0
const PATROL_RADIUS : float = 130.0
const PATROL_SLACK : float = 50.0
const PATROL_ALTITUDE : float = 90.0
const PATROL_ALTITUDE_STEP : float = 25.0
const ENDLESS_LEVEL_SECONDS : float = 60.0
const ENDLESS_LEVEL_VALUE : float = 90.0
const ENDLESS_TIER_LEVELS : Array[int] = [1, 3, 5, 8]
const ENDLESS_COUNTER_REACH : int = 2
const ENDLESS_SUPPLY_START : float = 0.7
const ENDLESS_SUPPLY_STEP : float = 0.2
const ENDLESS_SUPPLY_MAX : float = 4.5
const ENDLESS_COUNTER_STEP : float = 0.04
const ENDLESS_COUNTER_BONUS_MAX : float = 0.35
const ENDLESS_LIVE_CAP_START : int = 8
const ENDLESS_LIVE_CAP_STEP : int = 2
const ENDLESS_LIVE_CAP_MAX : int = 26
const ESCORT_HEALTH : float = 150.0
const ESCORT_SPEED : float = 190.0
const ESCORT_GOAL : float = 0.75
const ESCORT_AIR_DAMAGE : float = 0.5
const ESCORT_ALLY_GAP : float = 150.0
const ESCORT_AIR_GAP : float = 300.0
const ESCORT_ENEMY_STANDOFF : float = 450.0
const ESCORT_RETREAT_SLACK : float = 40.0
const ESCORT_RETREAT_SPEED : float = 0.5
const ESCORT_RETREAT_FLOOR : float = 250.0
const BOMBER_BOSS_NAME : String = "boss_heavy_bomber"
const BOMBER_ARRIVAL_SECONDS : float = 45.0
const BOMBER_HEALTH_MULT : float = 4.5
const BOMBER_RETREAT_AT : Array[float] = [0.5, 0.3333]
const BOMBER_RETREAT_HEAL : Array[float] = [0.3333, 0.2]
const BOMBER_HOME_DISTANCE : float = 220.0
const BOMBER_HOME_ALTITUDE : float = 120.0
const BOMBER_LOITER_BASE_GAP : float = 300.0
const BOMBER_LOITER_ALTITUDE : float = 160.0
const SUB_STOP_SECONDS : float = 2.0
const SUB_PUSH_MIN_DISTANCE : float = 60.0
const FLAK_SPREAD_SPEEDS : Array[float] = [75.0, 105.0, 110.0, 140.0]
const FLAK_SPREAD_NEAR : Array[float] = [1.0, 3.0, 4.0, 5.0]
const FLAK_SPREAD_FAR : Array[float] = [3.0, 7.0, 8.0, 9.0]
const HUNTER_THREAT_RANGE : float = 220.0
const HUNTER_THREAT_CONE : float = 25.0
const HUNTER_EVADE_ANGLE : float = 45.0
const HUNTER_BREAK_DISTANCE : float = 90.0
const HUNTER_RETURN_DISTANCE : float = 200.0
const HUNTER_AIM_ANGLE : float = 15.0
const HUNTER_BREAK_CLIMB : float = 0.4
const HUNTER_BREAK_ALTITUDE : float = 130.0
const HUNTER_BOOST_MULT : float = 1.4
const HUNTER_BOOST_ACCEL : float = 0.8
const HUNTER_SMOKE_INTERVAL : float = 0.04
const FLARE_TRIGGER_DISTANCE : float = 90.0
const FLARE_REACH : float = 170.0
const FLARE_HIT_CHANCE : float = 0.1
const FLARE_COOLDOWN : float = 3.0
const HELI_EVADE_SECONDS : float = 0.8
const HELI_EVADE_SPEED_MULT : float = 2.0
const HELI_EVADE_ACCEL : float = 450.0
const DEPTH_LAUNCH_SPREAD : float = 55.0
const FLARE_DEFLECTION : float = 0.9
const HUNTER_BASE_GAP : float = 300.0
const HUNTER_MIN_SPAN : float = 150.0
const HUNTER_LEAD : float = 150.0
const HUNTER_AA_MARGIN : float = 40.0
const HUNTER_PATROL_SPAN : float = 400.0
const TARGET_PREFERENCE : int = 1000
const FLAK_SPREAD_MULT : float = 0.9
const FLAK_SPREAD_BOMBER_MULT : float = 0.7
const FLAK_SPREAD_BOMBERS : Array[String] = ["bomber", "twin_bomber"]
const NAVAL_GUNS : Array[int] = [Enums.Guns.SMALL_GUN, Enums.Guns.MEDIUM_GUN, Enums.Guns.LARGE_GUN]
const NAVAL_GUN_CEILING : float = 160.0
const DEPTH_LAUNCH_SECONDS : float = 1.0
const FLAK_RETREAT_SPEED : float = 0.5
const FLAK_RETREAT_HOLD : float = 1.0
const FLAK_RETREAT_FLOOR : float = 250.0
const HUNT_TARGET : int = 5
const ANTI_BOMBER_UNITS : Array[String] = ["flak", "frigate", "plane", "cruiser", "interceptor", "sub_sam", "missile_plane"]
const ENEMY_LIVE_CAP : Array[int] = [10, 14, 18, 22]
const HUNT_SUB_CAP : int = 3
const HUNT_ANTI_SUB_STEPS : Array[int] = [2, 3]
const HUNT_SUB_LEVELS : Array[Array] = [
	[["sub_hunter"], ["sub_hunter"]],
	[["submarine", "sub_hunter"], ["sub_hunter"]],
	[["submarine", "sub_hunter", "sub_sam"], ["sub_hunter", "sub_sam"]],
	[["submarine", "sub_hunter", "sub_sam"], ["sub_hunter", "sub_sam"]],
]
const BOSS_SPAWN_SKIP : float = 0.4
const TIME_LIMITS : Dictionary = {
	Objective.DESTROY_BASE: 360.0, Objective.HUNT_SUBMARINE: 240.0, Objective.ESCORT: 300.0,
	Objective.SHOOT_DOWN_BOMBER: 300.0, Objective.DEFEAT_BOSS: 420.0,
}

const BATTLE_DISTANCE : Dictionary = {
	Objective.DESTROY_BASE: [1800.0, 3000.0], Objective.DEFEND: [1600.0, 2400.0],
	Objective.ESCORT: [2000.0, 3200.0], Objective.HUNT_SUBMARINE: [1600.0, 2400.0],
	Objective.SHOOT_DOWN_BOMBER: [1600.0, 2400.0], Objective.DEFEAT_BOSS: [2400.0, 3600.0],
}
const BATTLE_DISTANCE_JITTER : float = 0.1
const CLASSIC_DISTANCE : float = 2000.0

const NODE_NAMES : Dictionary = {
	NodeType.BATTLE: "run.battle", NodeType.ELITE: "run.elite_battle", NodeType.SHIPYARD: "run.shipyard",
	NodeType.EVENT: "run.event", NodeType.BOSS: "run.boss",
}
const NODE_ICON_KEYS : Dictionary = {
	NodeType.BATTLE: "battle", NodeType.ELITE: "elite", NodeType.SHIPYARD: "shipyard",
	NodeType.EVENT: "event", NodeType.BOSS: "boss",
}

const OBJECTIVES : Dictionary = {
	Objective.DESTROY_BASE: {"name": "run.destroy_base", "text": "run.destroy_the_enemy_base", "icon": "destroy_base"},
	Objective.DEFEND: {"name": "run.defend", "text": "run.hold_the_beacon_until_the", "icon": "defend"},
	Objective.ESCORT: {"name": "run.escort", "text": "run.protect_the_cargo_ship_until", "icon": "escort"},
	Objective.HUNT_SUBMARINE: {"name": "run.submarine_hunt", "text": "run.sink_the_enemy_submarines", "icon": "hunt_submarine"},
	Objective.SHOOT_DOWN_BOMBER: {"name": "run.bomber_down", "text": "run.shoot_down_the_heavy_bomber", "icon": "shoot_down_bomber"},
	Objective.DEFEAT_BOSS: {"name": "run.defeat_the_boss", "text": "run.sink_the_sector_boss", "icon": "destroy_base"},
}
const BATTLE_OBJECTIVES : Array[int] = [
	Objective.DESTROY_BASE, Objective.DEFEND, Objective.ESCORT,
	Objective.HUNT_SUBMARINE, Objective.SHOOT_DOWN_BOMBER,
]

const WEATHER : Dictionary = {
	Weather.CLEAR: {"name": "run.clear_sky", "icon": "clear_sky", "text": "run.no_effect", "difficulty": 0,
		"effects": []},
	Weather.STORM: {"name": "run.storm", "icon": "storm", "text": "run.allied_units_move_15_slower", "difficulty": 1,
		"effects": [{"target": T_ENTITY, "stat": &"speed", "op": "mul", "value": 0.85}]},
	Weather.FOG: {"name": "run.fog", "icon": "fog", "text": "run.allied_radar_range_30", "difficulty": 1,
		"effects": [{"target": T_ENTITY, "stat": &"radar_distance", "op": "mul", "value": 0.7}]},
	Weather.LOW_TIDE: {"name": "run.low_tide", "icon": "low_tide", "text": "run.drained_docks_allied_ships_build", "difficulty": 0,
		"effects": [{"target": T_BASE, "stat": &"build_time", "op": "mul", "value": 0.85}]},
}
const WEATHER_WEIGHTS : Dictionary = {
	Weather.CLEAR: 4.0, Weather.STORM: 2.0, Weather.FOG: 2.0, Weather.LOW_TIDE: 2.0,
}

const RARITY_NAMES : Dictionary = {
	Rarity.COMMON: "run.common", Rarity.UNCOMMON: "run.uncommon", Rarity.RARE: "run.rare", Rarity.CURSED: "run.cursed",
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
	&"bomb": {"name": "run.heavy_ordnance", "rarity": Rarity.COMMON, "icon": "bomb",
		"text": "run.bomb_strikes_deal_more_damage", "tag": "run.30_bomb_damage",
		"effects": [{"target": T_SKILL, "stat": &"bomb_damage", "op": "mul", "value": 1.3}]},
	&"ammo": {"name": "run.spare_ammo", "rarity": Rarity.COMMON, "icon": "ammo",
		"text": "run.all_allied_guns_hit_a", "tag": "run.8_gun_damage",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.08}]},
	&"shield": {"name": "run.bow_plating", "rarity": Rarity.UNCOMMON, "icon": "shield",
		"text": "run.the_base_takes_less_damage", "tag": "run.15_base_damage_taken",
		"effects": [{"target": T_BASE, "stat": &"damage_taken", "op": "mul", "value": 0.85}]},
	&"gear": {"name": "run.salvage_gear", "rarity": Rarity.COMMON, "icon": "gear",
		"text": "run.destroyed_ships_drop_gears_more", "tag": "run.50_gear_drops",
		"effects": [{"target": T_BASE, "stat": &"gear_drop_chance", "op": "mul", "value": 1.5}]},
	&"repair": {"name": "run.field_repairs", "rarity": Rarity.COMMON, "icon": "repair",
		"text": "run.the_base_repairs_itself_after", "tag": "run.8_hp_after_battle",
		"effects": [{"target": T_RUN, "stat": &"heal_after_battle", "op": "add", "value": 8.0}]},
	&"radar": {"name": "run.long_range_radar", "rarity": Rarity.COMMON, "icon": "radar",
		"text": "run.allied_units_spot_enemies_from", "tag": "run.25_radar_range",
		"effects": [{"target": T_ENTITY, "stat": &"radar_distance", "op": "mul", "value": 1.25}]},
	&"hull": {"name": "run.reinforced_hull", "rarity": Rarity.UNCOMMON, "icon": "hull",
		"text": "run.allied_ships_are_tougher", "tag": "run.15_unit_health",
		"effects": [{"target": T_ENTITY, "stat": &"health", "op": "mul", "value": 1.15}]},
	&"fuel": {"name": "run.extra_fuel", "rarity": Rarity.UNCOMMON, "icon": "fuel",
		"text": "run.allied_ships_sail_faster", "tag": "run.12_unit_speed",
		"effects": [{"target": T_ENTITY, "stat": &"speed", "op": "mul", "value": 1.12}]},
	&"anchor": {"name": "run.heavy_anchor", "rarity": Rarity.UNCOMMON, "icon": "anchor",
		"text": "run.a_sturdier_base_for_the", "tag": "run.20_max_base_hp",
		"effects": [{"target": T_RUN, "stat": &"max_hp", "op": "add", "value": 20.0}]},
	&"compass": {"name": "run.glass_compass", "rarity": Rarity.RARE, "icon": "compass",
		"text": "run.better_routes_battles_pay_more", "tag": "run.15_node_screws",
		"effects": [{"target": T_RUN, "stat": &"reward_mult", "op": "mul", "value": 1.15}]},
	&"torpedo": {"name": "shop.quick_loaders", "rarity": Rarity.RARE, "icon": "torpedo",
		"text": "run.allied_guns_reload_faster", "tag": "run.10_reload_time",
		"effects": [{"target": T_GUN, "stat": &"shoot_interval", "op": "mul", "value": 0.9}]},
	&"engine": {"name": "run.tuned_engine", "rarity": Rarity.RARE, "icon": "engine",
		"text": "run.docks_produce_ships_faster", "tag": "run.15_build_time",
		"effects": [{"target": T_BASE, "stat": &"build_time", "op": "mul", "value": 0.85}]},
	&"cannon": {"name": "run.rifled_barrels", "rarity": Rarity.RARE, "icon": "cannon",
		"text": "run.allied_guns_deal_more_damage", "tag": "run.15_gun_damage",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.15}]},
	&"flare": {"name": "run.signal_flares", "rarity": Rarity.RARE, "icon": "flare",
		"text": "run.bomb_strikes_recharge_faster", "tag": "run.20_bomb_cooldown",
		"effects": [{"target": T_SKILL, "stat": &"bomb_cooldown", "op": "mul", "value": 0.8}]},
	&"supply_crate": {"name": "run.supply_crate", "rarity": Rarity.UNCOMMON, "icon": "supply_crate",
		"text": "run.start_every_battle_with_more", "tag": "run.25_starting_screws",
		"effects": [{"target": T_BASE, "stat": &"start_screw", "op": "mul", "value": 1.25}]},
	&"cursed_item": {"name": "run.salt_heart", "rarity": Rarity.CURSED, "icon": "cursed_item",
		"text": "run.allied_guns_deal_30_damage", "tag": "run.30_damage_10_max_hp",
		"effects": [{"target": T_GUN, "stat": &"damage", "op": "mul", "value": 1.3},
			{"target": T_RUN, "stat": &"max_hp", "op": "add", "value": -10.0}],
		"penalty": true},
}

const RISKS : Dictionary = {
	&"stronger_enemies": {"name": "run.armored_enemies", "text": "run.25_enemy_health", "icon": "stronger_enemies",
		"bonus": 0.15, "effects": [{"target": T_RUN, "stat": &"enemy_health", "op": "mul", "value": 1.25}]},
	&"fewer_screws": {"name": "run.short_supplies", "text": "run.20_starting_screws", "icon": "fewer_screws",
		"bonus": 0.10, "effects": [{"target": T_BASE, "stat": &"start_screw", "op": "mul", "value": 0.8}]},
	&"forced_storm": {"name": "run.forced_storm", "text": "run.weather_is_fixed_to_storm", "icon": "forced_storm",
		"bonus": 0.10, "effects": [{"target": T_RUN, "stat": &"force_weather", "op": "add", "value": float(Weather.STORM)}]},
	&"less_time": {"name": "run.less_time", "text": "run.20_time_available", "icon": "less_time",
		"bonus": 0.20, "effects": [{"target": T_RUN, "stat": &"time_mult", "op": "mul", "value": 0.8}]},
	&"fragile_base": {"name": "run.fragile_base", "text": "run.25_damage_taken_by_base", "icon": "fragile_base",
		"bonus": 0.15, "effects": [{"target": T_BASE, "stat": &"damage_taken", "op": "mul", "value": 1.25}]},
	&"more_bosses": {"name": "run.more_bosses", "text": "run.1_boss_in_the_battle", "icon": "more_bosses",
		"bonus": 0.25, "effects": [{"target": T_RUN, "stat": &"extra_boss", "op": "add", "value": 1.0}]},
}

const EVENTS : Array[Dictionary] = [
	{"id": &"drifting_signal", "title": "run.drifting_signal", "tag": "run.distress_beacon",
		"text": "run.an_old_beacon_blinks_among",
		"choices": [
			{"label": "run.take_the_crate", "text": "run.gain_80_screws_the_base", "icon": "cargo_box", "screws": 80, "hp": -8},
			{"label": "run.investigate_the_signal", "text": "run.receive_a_relic_offer_the", "icon": "beacon_signal", "relic_offer": true, "hp": -5},
			{"label": "run.sail_on", "text": "run.return_to_the_map", "icon": "continue_trip"},
		]},
	{"id": &"stranded_crew", "title": "run.stranded_crew", "tag": "run.distress_call",
		"text": "run.a_crew_waves_from_a",
		"choices": [
			{"label": "run.rescue_them", "text": "run.pay_40_screws_the_base", "icon": "repair", "screws": -40, "hp": 20},
			{"label": "run.salvage_the_wreck", "text": "run.gain_60_screws_the_base", "icon": "cargo_box", "screws": 60, "hp": -6},
			{"label": "run.sail_on", "text": "run.return_to_the_map", "icon": "continue_trip"},
		]},
	{"id": &"black_market", "title": "run.black_market", "tag": "run.merchant_vessel",
		"text": "run.a_rusted_merchant_flashes_its",
		"choices": [
			{"label": "run.buy_a_relic", "text": "run.pay_120_screws_receive_a", "icon": "cargo_box", "screws": -120, "relic_offer": true},
			{"label": "run.sell_supplies", "text": "run.gain_70_screws_the_base", "icon": "beacon_signal", "screws": 70, "hp": -10},
			{"label": "run.sail_on", "text": "run.return_to_the_map", "icon": "continue_trip"},
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
