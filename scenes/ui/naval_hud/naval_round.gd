extends GameRound

const HUD := preload("res://scenes/ui/naval_hud/naval_hud.gd")
var hud: HUD
var ally_max_hp: float
var enemy_max_hp: float
var boss_notice_until: int

func _ready() -> void:
	ally_max_hp = ally_base.health_component.health
	enemy_max_hp = enemy_base.health_component.health
	super._ready()
	var legacy: GameUI = $CanvasLayer/GameUI
	legacy.hide()
	$CanvasLayer/Debugger.hide()
	if wave_label:
		wave_label.hide()
	ally_base.health_component.label.hide()
	enemy_base.health_component.label.hide()
	hud = HUD.new()
	hud.round_scene = self
	hud.legacy = legacy
	hud.open_menu.connect(open_pause)
	canvas_layer.add_child(hud)
	if campaign:
		ally_max_hp = float(Global.run.base_max_hp)
		enemy_max_hp = campaign.enemy_hp_max
	elif wave_manager.current_wave_number() == 1:
		ally_max_hp = ally_base.health_component.health

	skill_manager.hint_label.position.y = 106.0
	skill_manager.set_process_input(false)
	camera.set_process_input(false)

func _on_wave_started(number: int, wave: WaveData) -> void:
	super._on_wave_started(number, wave)
	if wave.base_tier:
		enemy_max_hp = maxf(wave.base_tier.base_health, AutoBase.MIN_BASE_HEALTH)
	if wave.boss:
		boss_notice_until = Time.get_ticks_msec() + 4500

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_pause"):
		open_pause()
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo or key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if hud and key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_9:
		get_viewport().set_input_as_handled()
		hud.quick_build(9 if key.physical_keycode == KEY_0 else key.physical_keycode - KEY_1)

func open_pause() -> void:
	if get_tree().paused or game_ended:
		return
	var pause: PauseMenu = PauseMenu.new()
	pause.name = "PauseMenu"
	get_tree().root.add_child(pause)

func _input(event: InputEvent) -> void:
	if not hud or game_ended:
		return
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse and hud.covers_point(mouse.position):
		return
	skill_manager._input(event)
	camera._input(event)

