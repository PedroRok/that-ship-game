class_name RelicChoiceScreen
extends RunScreen

var selected : StringName = &""
var cards : Dictionary = {}
var confirm_button : Button
var _busy : bool = false

func expected_stage() -> int:
	return RunData.Stage.RELIC

func screen_title() -> String:
	return "run.choose_a_relic"

func screen_subtitle() -> String:
	return "run.node_reward"

func _build() -> void:
	content.add_child(_label(Loc.t("run.choose_1_of_the_relics") % run.relic_offer.size(), 16, TEXT_SOFT))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(row)
	content.add_child(_spacer())
	for relic_id : StringName in run.relic_offer:
		var card : Button = _build_card(relic_id)
		row.add_child(card)
		cards[relic_id] = card
	content.add_child(_divider())
	var footer : HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	footer.add_child(_legend())
	footer.add_child(_spacer())
	var skip : Button = _button("run.skip", true)
	skip.custom_minimum_size.x = 140
	skip.pressed.connect(_on_skip)
	confirm_button = _button("run.confirm")
	confirm_button.custom_minimum_size.x = 246
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(skip)
	footer.add_child(confirm_button)
	content.add_child(footer)
	if (!run.relic_offer.is_empty()):
		_defer_focus(cards[run.relic_offer[0]] as Control)

func _legend() -> Control:
	var box : VBoxContainer = VBoxContainer.new()
	box.add_child(_label("run.rarities", 12, TEXT_SOFT, true))
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for rarity : int in RunData.RARITY_NAMES:
		var item : HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var swatch : ColorRect = ColorRect.new()
		swatch.color = RunData.RARITY_COLORS[rarity]
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		item.add_child(_label(Loc.t(str(RunData.RARITY_NAMES[rarity])).capitalize(), 12, TEXT_SOFT))
		row.add_child(item)
	box.add_child(row)
	return box

func _build_card(relic_id : StringName) -> Button:
	var data : Dictionary = RunData.RELICS[relic_id]
	var rarity : int = int(data["rarity"])
	var color : Color = RunData.RARITY_COLORS[rarity]
	var cursed : bool = rarity == RunData.Rarity.CURSED
	var key : String = RunData.RARITY_FRAME_KEYS[rarity]
	var card : Button = Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 392
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.focus_mode = Control.FOCUS_ALL
	card.toggle_mode = false
	var frame : StyleBoxTexture = _pause_box("panel_frame_v01.png", 16)
	var frame_hover : StyleBoxTexture = frame
	for state : String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, frame_hover if state != "focus" else StyleBoxEmpty.new())
	var inner : VBoxContainer = VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_right = -8
	inner.offset_top = 8
	inner.offset_bottom = -8
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var plate : PanelContainer = _plate(Loc.t(str(RunData.RARITY_NAMES[rarity])), color, 16, color)
	var check : TextureRect = _icon(RunData.ui_icon("check_ok"))
	check.name = "Check"
	check.visible = false
	var plate_row : Node = plate.get_child(0)
	plate_row.add_child(check)
	if (cursed):
		plate_row.add_child(_icon(load(PAUSE_DIR + "icon_alert_v01.png") as Texture2D))
	inner.add_child(plate)
	var niche : Control = Control.new()
	niche.custom_minimum_size = Vector2(120, 120)
	niche.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	niche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var niche_frame : TextureRect = _icon(load("res://assets/ui/relics/icon_frame_%s_v01.png" % key) as Texture2D)
	niche.add_child(niche_frame)
	var glyph : TextureRect = TextureRect.new()
	glyph.texture = RunData.relic_icon(relic_id)
	glyph.stretch_mode = TextureRect.STRETCH_SCALE
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.position = Vector2(12, 12)
	glyph.size = Vector2(96, 96)
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	niche.add_child(glyph)
	if (cursed):
		niche.add_child(_icon(load("res://assets/ui/relics/cursed_cracks_v01.png") as Texture2D))
	inner.add_child(niche)
	var title : Label = _label(Loc.t(str(data["name"])), 16, TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)
	inner.add_child(_divider())
	var description : Label = _wrapped(Loc.t(str(data["text"])), 14, TEXT)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(description)
	var band_key : String = "penalty" if cursed else key
	var band : PanelContainer = PanelContainer.new()
	band.add_theme_stylebox_override("panel", _box("res://assets/ui/relics/effect_band_%s_v01.png" % band_key, 4, 8))
	var tag : Label = _label(Loc.t(str(data["tag"])), 12, color, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(tag)
	inner.add_child(band)
	var focus : NinePatchRect = NinePatchRect.new()
	focus.name = "Focus"
	focus.texture = load("res://assets/ui/relics/card_focus_v01.png") as Texture2D
	for side : String in ["left", "right", "top", "bottom"]:
		focus.set("patch_margin_" + side, 16)
	focus.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus.visible = false
	card.add_child(focus)
	card.focus_entered.connect(_update_focus_visuals)
	card.focus_exited.connect(_update_focus_visuals)
	card.mouse_entered.connect(func() -> void: card.grab_focus())
	card.pressed.connect(_on_card_pressed.bind(relic_id))
	return card

func _update_focus_visuals() -> void:
	for relic_id : StringName in cards:
		var card : Button = cards[relic_id]
		(card.get_node("Focus") as CanvasItem).visible = card.has_focus() or relic_id == selected
		var check : CanvasItem = card.find_child("Check", true, false) as CanvasItem
		if (check):
			check.visible = relic_id == selected

func _on_card_pressed(relic_id : StringName) -> void:
	selected = relic_id
	confirm_button.disabled = false
	_update_focus_visuals()

func _on_confirm() -> void:
	if (_busy or selected == &""):
		return
	_busy = true
	if (run.claim_relic(selected)):
		_advance()
	else:
		_busy = false

func _on_skip() -> void:
	if (_busy):
		return
	_busy = true
	if (run.skip_relic()):
		_advance()
	else:
		_busy = false
