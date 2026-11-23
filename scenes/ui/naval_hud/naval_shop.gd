extends "res://scenes/ui/shop/scripts/shop_menu.gd"

const PROFILE := preload("res://scenes/ui/naval_hud/naval_profile.gd")

func loadout_limit() -> int:
	return PROFILE.HUD_LOADOUT_SIZE
