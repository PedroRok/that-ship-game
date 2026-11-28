extends Control

const OUT_DIR : String = "res://extras/art_preview/ui_gallery/"
const HUD := preload("res://scenes/ui/naval_hud/naval_hud.gd")
const DISPLAY_SHADER : Shader = preload("res://shaders/digital_panel.gdshader")
const FONT_DIR : String = "res://extras/art_preview/ui_gallery/fonts/"
const FONTS : Array[Array] = [
	["Pixel Operator", "PixelOperator.ttf", 16],
	["Pixel Operator 8", "PixelOperator8.ttf", 8],
	["Pixelify Sans", "PixelifySans.ttf", 16],
	["Silkscreen", "Silkscreen.ttf", 8],
	["VT323", "VT323.ttf", 16],
]
const PREVIEWS : Array[String] = ["reliquias", "estaleiro", "frota", "batalha"]
const ACCENTS : String = "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ"
const SAMPLE_TITLE : String = "Relíquia: Coração de Sal"
const SAMPLE_BODY : String = "Armas aliadas causam +30% de dano. A base perde 10 de vida máxima. Não é possível desfazer após a confirmação."
const SAMPLE_LINES : Array[String] = [
	"Relatório, estaleiro, munição, canhões, próximo nó.",
	"ÁÀÂÃ ÉÊ Í ÓÔÕ Ú Ç  áàâã éê í óôõ ú ç",
	"0123456789  66/100 HP  +35%  2:14  [Q] x12",
	"Il1 O0 rn m  BASE EM MANUTENÇÃO",
]

var screen_kit : RunScreen
var shop_kit : ShopMenu
var pause_kit : PauseMenu
var hud_kit : HUD
var shown : Control
var page_index : int
var unit_names : Dictionary = {}
var operator_font : FontFile
var operator_bold : FontFile

func _ready() -> void:
	SaveManager.use_test_directory()
	get_window().size = Vector2i(1280, 720)
	texture_filter = TEXTURE_FILTER_NEAREST
	Loc.apply("pt_BR")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	screen_kit = RunScreen.new()
	shop_kit = ShopMenu.new()
	pause_kit = PauseMenu.new()
	hud_kit = HUD.new()
	_prepare_preview()
	if (OS.get_cmdline_user_args().has("shots")):
		for index : int in _page_count():
			await _shoot(_build_page(index), "%02d_%s.png" % [index + 1, _page_name(index).to_snake_case().replace(" ", "_")])
		get_tree().quit()
		return
	_show_page(0)

func _page_count() -> int:
	return ALERTS.size() + 1 + RESEARCH_TIPS.size() + PREVIEWS.size() * 2 + 3 + FONTS.size()

func _page_name(number : int) -> String:
	if (number < ALERTS.size()):
		return "alerta " + ALERTS[number]
	var page_number : int = number - ALERTS.size()
	if (page_number == 0):
		return "tooltips"
	if (page_number <= RESEARCH_TIPS.size()):
		return "pesquisa " + RESEARCH_TIPS[page_number - 1]
	var index : int = page_number - 1 - RESEARCH_TIPS.size()
	if (index < PREVIEWS.size() * 2):
		return "%s %s" % [PREVIEWS[index / 2], "antes" if index % 2 == 0 else "depois"]
	var other : int = index - PREVIEWS.size() * 2
	var names : Array[String] = ["screen and modal", "dense menu", "battle hud"]
	if (other < names.size()):
		return names[other]
	return "font " + str(FONTS[other - names.size()][0])

func _build_page(number : int) -> Control:
	if (number < ALERTS.size()):
		return _alert_page(number)
	var page_number : int = number - ALERTS.size()
	if (page_number == 0):
		return _tooltip_page()
	if (page_number <= RESEARCH_TIPS.size()):
		return _research_page(page_number - 1)
	var index : int = page_number - 1 - RESEARCH_TIPS.size()
	if (index < PREVIEWS.size() * 2):
		return _preview_page(PREVIEWS[index / 2], index % 2 == 1)
	var other : int = index - PREVIEWS.size() * 2
	match other:
		0:
			return _screen_page()
		1:
			return _dense_page()
		2:
			return _battle_page()
	return _font_page(FONTS[other - 3])

func _exit_tree() -> void:
	screen_kit.free()
	shop_kit.free()
	pause_kit.free()
	hud_kit.free()

func _show_page(index : int) -> void:
	page_index = posmod(index, _page_count())
	if (shown != null):
		shown.queue_free()
	shown = _build_page(page_index)
	add_child(shown)
	get_window().title = "UI Gallery %d/%d  %s  -  Left/Right: page, Esc: close" % [page_index + 1, _page_count(), _page_name(page_index)]

func _input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if (key != null):
		get_viewport().set_input_as_handled()
	if (key == null or !key.pressed or key.echo or shown == null):
		return
	if (key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT):
		_show_page(page_index + (1 if key.keycode == KEY_RIGHT else -1))
	elif (key.keycode == KEY_ESCAPE):
		get_tree().quit()

func _shoot(page : Control, file_name : String) -> void:
	add_child(page)
	for i : int in 8:
		await get_tree().process_frame
	var image : Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
	page.queue_free()
	await get_tree().process_frame

func _page(font : Font) -> Control:
	var page : Control = Control.new()
	page.size = Vector2(1280, 720)
	var ui_theme : Theme = Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 8
	PixelControls.apply_theme(ui_theme)
	page.theme = ui_theme
	return page

func _column(parent : Node, gap : int) -> VBoxContainer:
	var column : VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _row(parent : Node, gap : int) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row

func _screen_page() -> Control:
	var page : Control = _page(RunScreen.PIXEL_FONT)
	page.add_child(MenuBackground.new())
	var margin : MarginContainer = screen_kit._margin_box(page, 0)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", RunScreen.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", RunScreen.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", RunScreen.HEADER_TOP)
	margin.add_theme_constant_override("margin_bottom", 14)
	var content : VBoxContainer = _column(margin, 10)
	content.add_child(screen_kit._header("Relatório de batalha", "ANDAR 02 / VITÓRIA"))
	var columns : HBoxContainer = _row(content, 14)
	columns.add_child(screen_kit._stat_panel("BASE", "74 / 100", "Vida restante da base.", RunScreen.CYAN))
	columns.add_child(screen_kit._stat_panel("RECOMPENSA", "+135", "Parafusos ganhos nesta batalha.", RunScreen.AMBER, screen_kit._screw_icon()))
	columns.add_child(screen_kit._stat_panel("PERDAS", "3", "Unidades destruídas em combate.", RunScreen.DANGER))
	var detail : PanelContainer = screen_kit._panel(12)
	content.add_child(detail)
	var detail_col : VBoxContainer = _column(detail, 10)
	detail_col.add_child(screen_kit._plate("INTEGRIDADE DA BASE", RunScreen.TEXT, 16, RunScreen.CYAN))
	detail_col.add_child(screen_kit._hp_bar(74, 100, 24))
	detail_col.add_child(screen_kit._divider())
	detail_col.add_child(screen_kit._label("Próximo nó: estaleiro, elite ou evento.", 16, RunScreen.TEXT_SOFT))
	content.add_child(screen_kit._spacer())
	content.add_child(screen_kit._divider())
	var back : Button = screen_kit._button("VOLTAR AO MAPA")
	back.custom_minimum_size.x = 270
	var next : Button = screen_kit._button("CONTINUAR")
	next.custom_minimum_size.x = 270
	content.add_child(screen_kit._footer(back, next))
	_add_modal(page)
	next.grab_focus.call_deferred()
	return page

func _add_modal(page : Control) -> void:
	var holder : PanelContainer = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", pause_kit._box("panel_frame_v01.png", 16))
	holder.position = Vector2(480, 440)
	holder.custom_minimum_size = Vector2(320, 170)
	page.add_child(holder)
	var box : VBoxContainer = _column(holder, 8)
	box.add_child(pause_kit._header("VENDER RELÍQUIA", "icon_alert_v01.png"))
	var message : Label = screen_kit._wrapped("Esta ação não pode ser desfeita.", 8)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size.y = 24
	box.add_child(message)
	box.add_child(pause_kit._inset(pause_kit._button("pause.cancel", false)))
	box.add_child(pause_kit._inset(pause_kit._divider(), 0))
	box.add_child(pause_kit._inset(pause_kit._button("VENDER", true)))

func _unit(unit_name : String) -> BoatStats:
	return Global.CATALOG.find_unit(unit_name) as BoatStats

func _dense_page() -> Control:
	var page : Control = _page(ShopMenu.FONT)
	page.add_child(MenuBackground.new())
	var outer : MarginContainer = shop_kit._margin(page, 18)
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var column : VBoxContainer = _column(outer, 12)
	var header : PanelContainer = shop_kit._framed_panel()
	column.add_child(header)
	var header_row : HBoxContainer = _row(shop_kit._margin(header, 10), 14)
	var title : Label = shop_kit._label("OFICINA", ShopMenu.TEXT, 32)
	title.add_theme_font_override("font", ShopMenu.PIXEL_FONT)
	header_row.add_child(title)
	header_row.add_child(VSeparator.new())
	var money : VBoxContainer = _column(header_row, 4)
	money.add_child(shop_kit._label("run.gears", ShopMenu.DIM))
	var amount : Label = shop_kit._label("128", Color("#ffe3a8"), 16)
	money.add_child(shop_kit._currency_display(ShopMenu.GEAR_ICON, 2, ShopMenu.AMBER, amount))
	header_row.add_child(shop_kit._spacer())
	var back : Button = Button.new()
	back.text = "run.back_to_map"
	back.custom_minimum_size = Vector2(150, 34)
	back.size_flags_vertical = SIZE_SHRINK_CENTER
	shop_kit._skin(back)
	header_row.add_child(back)
	var main : HBoxContainer = _row(column, 14)
	main.size_flags_vertical = SIZE_EXPAND_FILL
	var list : VBoxContainer = shop_kit._module("MÓDULOS DE ARMA", true)
	var list_panel : PanelContainer = list.get_meta("panel")
	list_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_child(list_panel)
	var grid : GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 11)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	var names : Array[String] = ["mini", "small", "medium", "tank", "torpedo", "flak", "destroyer", "submarine"]
	for index : int in names.size():
		var unit : BoatStats = _unit(names[index])
		if (unit == null):
			continue
		var available : bool = index < 5
		var card : Button = Button.new()
		card.custom_minimum_size = Vector2(0, 112)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		var edge : Color = ShopMenu.CYAN if index == 1 else (Color("#72838d") if available else Color("#3a464c"))
		shop_kit._skin(card, edge, Color("#293740") if available else Color("#141b1f"))
		grid.add_child(card)
		var inner : VBoxContainer = _column(shop_kit._margin(card, 5), 3)
		(card.get_child(0) as Control).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		inner.add_child(shop_kit._label(Loc.named("unit", unit.name).to_upper()))
		inner.add_child(shop_kit._make_portrait(unit, available, 60, 2, "", true, true, "shop.owned" if available else "BLOQUEADO", ShopMenu.CYAN if available else ShopMenu.AMBER))
	var side : VBoxContainer = shop_kit._module("DETALHES", true)
	var side_panel : PanelContainer = side.get_meta("panel")
	side_panel.custom_minimum_size.x = 412
	main.add_child(side_panel)
	side.add_child(shop_kit._make_portrait(_unit("small"), true, 188, 4, "VISUALIZAÇÃO", false))
	for entry : Array in [["HP", "6.0"], ["shop.speed", "480.0"], ["shop.gun_slots", "2"]]:
		var row_panel : PanelContainer = shop_kit._panel(ShopMenu.ROW, ShopMenu.ROW)
		var row : HBoxContainer = _row(shop_kit._margin(row_panel, 5), 8)
		row.add_child(shop_kit._label(entry[0], ShopMenu.DIM))
		row.add_child(shop_kit._spacer())
		row.add_child(shop_kit._label(entry[1]))
		side.add_child(row_panel)
	side.add_child(shop_kit._spacer())
	for entry : Array in [["MELHORAR - 40", ShopMenu.AMBER, Color("#3a3220")], ["shop.add_to_loadout", ShopMenu.CYAN, Color("#1f4448")]]:
		var action : Button = Button.new()
		action.text = entry[0]
		action.custom_minimum_size = Vector2(0, 30)
		shop_kit._skin(action, entry[1], entry[2])
		side.add_child(action)
	return page

func _battle_page() -> Control:
	var page : Control = _page(HUD.FONT)
	var sky : ColorRect = ColorRect.new()
	sky.color = Color("#6f9fd8")
	sky.size = page.size
	page.add_child(sky)
	var console : PanelContainer = PanelContainer.new()
	var frame : StyleBoxTexture = MenuBackground.make_box()
	for side : String in ["left", "right", "top", "bottom"]:
		frame.set("content_margin_" + side, 10.0)
	console.add_theme_stylebox_override("panel", frame)
	console.position = Vector2(0, 520)
	console.size = Vector2(1280, 200)
	page.add_child(console)
	var row : HBoxContainer = _row(hud_kit._margin(console, 4), 4)
	var support : VBoxContainer = hud_kit._module(row, "APOIO AÉREO", 300, 1.0)
	_add_cards(support, ["plane", "bomber"])
	_add_cards(support, ["bomber", "plane"])
	var states : VBoxContainer = hud_kit._module(row, "hud.unit_catalog", 520, 2.0)
	_add_cards(states, ["mini", "small", "submarine", "plane"])
	_add_cards(states, ["medium", "tank", "destroyer", "flak"])
	var status : VBoxContainer = hud_kit._module(row, "STATUS DA FROTA", 300, 1.0)
	for entry : Array in [["EM COMBATE", "7", HUD.CYAN], ["NA FILA", "2", HUD.AMBER], ["PERDIDAS", "3", HUD.PINK]]:
		var line : PanelContainer = hud_kit._panel(Color("#202b31"), HUD.EDGE)
		status.add_child(line)
		var line_row : HBoxContainer = _row(hud_kit._margin(line, 4), 4)
		var name_label : Label = hud_kit._label(entry[0])
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		line_row.add_child(name_label)
		var value : Label = hud_kit._label(entry[1])
		value.add_theme_color_override("font_color", entry[2])
		line_row.add_child(value)
	var alert : PanelContainer = screen_kit._panel(6)
	alert.position = Vector2(12, 50)
	alert.custom_minimum_size = Vector2(390, 0)
	page.add_child(alert)
	var alert_col : VBoxContainer = _column(alert, 8)
	alert_col.add_child(screen_kit._label("Reforço inimigo", 16, RunScreen.AMBER, true))
	alert_col.add_child(screen_kit._hp_bar(5, 12, 22))
	alert_col.add_child(screen_kit._label("Submarinos chegando em 00:20.", 8, RunScreen.TEXT_SOFT))
	return page

func _add_cards(module : VBoxContainer, names : Array) -> void:
	var cards : HBoxContainer = _row(module, 3)
	for index : int in names.size():
		var unit : BoatStats = _unit(names[index])
		if (unit == null):
			continue
		var lit : bool = index != 2
		var card : Button = Button.new()
		card.custom_minimum_size = Vector2(100, 72)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		hud_kit._skin_card(card, lit, index == 1)
		cards.add_child(card)
		var inner : VBoxContainer = hud_kit._column(hud_kit._margin(card, 4), 1)
		var title : Label = hud_kit._label(Loc.named("unit", unit.name))
		title.add_theme_font_override("font", HUD.PIXEL_FONT)
		inner.add_child(title)
		var pal : DisplayPalette = DisplayPalette.of_unit(unit)
		var well : PanelContainer = hud_kit._panel(Color("#4d6069") if lit else Color("#2f3c43"), Color("#172127"))
		well.mouse_filter = MOUSE_FILTER_IGNORE
		well.size_flags_vertical = SIZE_EXPAND_FILL
		inner.add_child(well)
		var screen : ColorRect = ColorRect.new()
		screen.mouse_filter = MOUSE_FILTER_IGNORE
		var material : ShaderMaterial = ShaderMaterial.new()
		material.shader = DISPLAY_SHADER
		pal.apply_screen(material)
		material.set_shader_parameter("band_strength", 1.0 if lit else 0.0)
		screen.material = material
		screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
		well.add_child(screen)
		var art : TextureRect = hud_kit._tinted_icon(UnitIcon.of(unit), Vector2.ZERO, pal.rest if lit else pal.unloaded)
		art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		well.add_child(art)
		var state : Label = hud_kit._label("hud.ready" if lit else "hud.dock_offline")
		state.add_theme_color_override("font_color", pal.text if lit else HUD.DIM)
		inner.add_child(state)
		if (!lit):
			well.modulate = Color(0.72, 0.74, 0.78)

func _load_font(file_name : String) -> FontFile:
	var font : FontFile = FontFile.new()
	font.load_dynamic_font(FONT_DIR + file_name)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = false
	return font

func _missing(font : Font) -> String:
	var missing : String = ""
	for i : int in ACCENTS.length():
		if (!font.has_char(ACCENTS.unicode_at(i))):
			missing += ACCENTS[i]
	return missing

func _text(parent : Node, value : String, font : Font, size : int, color : Color = RunScreen.TEXT) -> Label:
	var label : Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _sample(parent : Node, font_name : String, font : Font, body : int, uppercase : bool) -> void:
	var panel : PanelContainer = screen_kit._panel(12)
	panel.custom_minimum_size.x = 601
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column : VBoxContainer = _column(panel, 10)
	_text(column, "%s  -  %d px" % [font_name, body], font, body * 2 if body == 8 else body, RunScreen.CYAN)
	_text(column, SAMPLE_TITLE, font, body * 2, RunScreen.AMBER)
	column.add_child(screen_kit._divider())
	_text(column, SAMPLE_BODY.to_upper() if uppercase else SAMPLE_BODY, font, body)
	column.add_child(screen_kit._divider())
	for line : String in SAMPLE_LINES:
		_text(column, line, font, body, RunScreen.TEXT_SOFT)
	column.add_child(screen_kit._divider())
	var tip : PanelContainer = shop_kit._panel(Color("#0b1419"), ShopMenu.CYAN)
	tip.custom_minimum_size.x = 260
	tip.size_flags_horizontal = SIZE_SHRINK_BEGIN
	column.add_child(tip)
	var tip_col : VBoxContainer = _column(shop_kit._margin(tip, 10), 6)
	_text(tip_col, "Canhão Antiaéreo", font, body, ShopMenu.CYAN)
	_text(tip_col, "Atira em aviões e mísseis. Não atinge submarinos.", font, body)
	_text(tip_col, "Munição: 40  Recarga: 1.5s", font, body, ShopMenu.AMBER)
	var button : Button = screen_kit._button("Confirmar missão")
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", body * 2 if body == 8 else body)
	column.add_child(button)

func _font_page(entry : Array) -> Control:
	var font_name : String = entry[0]
	var font : FontFile = _load_font(entry[1])
	var body : int = entry[2]
	var page : Control = _page(RunScreen.PIXEL_FONT)
	page.add_child(MenuBackground.new())
	var outer : MarginContainer = shop_kit._margin(page, 18)
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var content : VBoxContainer = _column(outer, 10)
	var plate : PanelContainer = screen_kit._plate("", RunScreen.TEXT, 16, RunScreen.CYAN)
	content.add_child(plate)
	var title : Label = plate.get_child(0).get_child(1).get_child(0)
	title.text = "FONTE: " + font_name
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 32)
	var missing : String = _missing(font)
	_text(content, "Acentos ausentes: " + (missing if missing != "" else "nenhum"), RunScreen.PIXEL_FONT, 8, RunScreen.DANGER if missing != "" else RunScreen.TEXT_SOFT)
	var columns : HBoxContainer = _row(content, 14)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	_sample(columns, font_name, font, body, false)
	_sample(columns, "Dogica Pixel (atual)", RunScreen.PIXEL_FONT, 8, true)
	return page

func _prepare_preview() -> void:
	operator_font = _load_font("PixelOperator8-NoDigits.ttf")
	operator_bold = _load_font("PixelOperator8-Bold-NoDigits.ttf")
	operator_font.fallbacks = [RunScreen.PIXEL_FONT] as Array[Font]
	operator_bold.fallbacks = [RunScreen.FONT] as Array[Font]
	var source : JSON = load("res://assets/localization/pt_BR.json") as JSON
	var entries : Dictionary = (source.data as Dictionary).get("entries", {})
	for key : Variant in entries:
		if (str(key).begins_with("unit.")):
			unit_names[str(entries[key]).to_upper()] = true
	Global.player_stats = Global.player_stats.duplicate()
	for starter : String in ["mini", "small"]:
		if (!Global.player_stats.has_boat(starter)):
			Global.player_stats.add_entity(Global.CATALOG.find_unit(starter))

func _stage_run(kind : String) -> void:
	var run : RunState = RunState.create(7)
	Global.run = run
	if (kind == "reliquias"):
		run.stage = RunData.Stage.RELIC
		run.relic_offer = [&"shield", &"compass", &"cursed_item"] as Array[StringName]
		return
	for entry : Dictionary in run.map.nodes:
		if (int(entry["type"]) == RunData.NodeType.SHIPYARD):
			run.pending_node = int(entry["id"])
			break
	run.stage = RunData.Stage.SHIPYARD
	run.screws = 162
	run.base_hp = 66

func _preview_page(kind : String, replaced : bool) -> Control:
	var holder : Control = Control.new()
	holder.size = Vector2(1280, 720)
	var screen : Control
	match kind:
		"reliquias":
			_stage_run(kind)
			screen = Global.menus[Global.Menu.RUN_RELIC].instantiate() as Control
		"estaleiro":
			_stage_run(kind)
			screen = Global.menus[Global.Menu.RUN_SHIPYARD].instantiate() as Control
		"frota":
			Global.run = null
			screen = Global.menus[Global.Menu.SHOP].instantiate() as Control
		_:
			screen = _battle_page()
	holder.add_child(screen)
	var blocker : Control = Control.new()
	blocker.size = holder.size
	holder.add_child(blocker)
	var badge : Label = Label.new()
	badge.text = "DEPOIS: Pixel Operator 8" if replaced else "ANTES: Dogica"
	badge.add_theme_font_override("font", operator_bold if replaced else RunScreen.FONT)
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", RunScreen.AMBER)
	badge.add_theme_color_override("font_outline_color", Color("#090f15"))
	badge.add_theme_constant_override("outline_size", 4)
	badge.position = Vector2(560, 6)
	holder.add_child(badge)
	if (replaced):
		holder.ready.connect(_replace_fonts.bind(screen), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return holder

func _replace_fonts(node : Node) -> void:
	for child : Node in node.get_children():
		_replace_fonts(child)
	if (!(node is Label or node is Button)):
		return
	var control : Control = node as Control
	var text : String = Loc.t(str(control.get("text")))
	var current : Font = control.get_theme_font("font")
	var bold : bool = current != null and current.resource_path.contains("bold")
	if (unit_names.has(text.to_upper())):
		control.add_theme_font_override("font", RunScreen.FONT)
		return
	if (bold):
		return
	control.add_theme_font_override("font", operator_font)

const TIP_WIDTH : float = 260.0
const TIP_TITLE : String = "CRUZADOR"
const TIP_BODY : String = "Navio pesado. Atira em navios e aviões, mas não atinge submarinos."
const TIP_REASON : String = "Parafusos insuficientes."

func _tip_text(parent : Node, value : String, color : Color, bold : bool, lowercase : bool = false) -> Label:
	var label : Label = screen_kit._label(value, 8, color, bold)
	if (lowercase):
		label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _tip_body(parent : Node, accent : Color, lowercase : bool) -> void:
	PixelText.describe(_tip_text(parent, TIP_BODY, RunScreen.TEXT, false, lowercase))
	var stats : HBoxContainer = _row(parent, 12)
	for entry : Array in [["HP 24", RunScreen.TEXT_SOFT], ["VEL 220", RunScreen.TEXT_SOFT], ["36 PARAFUSOS", accent]]:
		stats.add_child(screen_kit._label(entry[0], 8, entry[1]))
	PixelText.describe(_tip_text(parent, TIP_REASON, Color("#d7a4a0"), false, lowercase))

func _tip_frame(lowercase : bool) -> Control:
	var panel : PanelContainer = screen_kit._panel(8)
	var column : VBoxContainer = _column(panel, 6)
	column.add_child(screen_kit._plate(TIP_TITLE, RunScreen.TEXT, 8, RunScreen.CYAN))
	_tip_body(column, RunScreen.AMBER, lowercase)
	return panel

func _tip_flat(lowercase : bool) -> Control:
	var panel : PanelContainer = shop_kit._panel(Color("#0b1419"), ShopMenu.CYAN)
	var column : VBoxContainer = _column(shop_kit._margin(panel, 10), 6)
	_tip_text(column, TIP_TITLE, ShopMenu.CYAN, true)
	column.add_child(screen_kit._divider())
	_tip_body(column, ShopMenu.AMBER, lowercase)
	return panel

func _tip_display(lowercase : bool) -> Control:
	var panel : PanelContainer = shop_kit._panel(Color("#4d6069"), Color("#172127"))
	var screen : ColorRect = ColorRect.new()
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	DisplayPalette.of_dock(BaseDock.Type.NAVAL).apply_screen(material)
	screen.material = material
	screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
	panel.add_child(screen)
	var column : VBoxContainer = _column(shop_kit._margin(panel, 12), 6)
	_tip_text(column, TIP_TITLE, DisplayPalette.of_dock(BaseDock.Type.NAVAL).light, true)
	_tip_body(column, ShopMenu.AMBER, lowercase)
	return panel

func _tip_strip(lowercase : bool) -> Control:
	var panel : PanelContainer = shop_kit._panel(Color("#0b1419"), Color("#596a73"))
	var row : HBoxContainer = _row(shop_kit._margin(panel, 6), 0)
	var strip : ColorRect = ColorRect.new()
	strip.color = ShopMenu.CYAN
	strip.custom_minimum_size.x = 3
	row.add_child(strip)
	var column : VBoxContainer = _column(shop_kit._margin(row, 6), 6)
	column.get_parent().size_flags_horizontal = SIZE_EXPAND_FILL
	_tip_text(column, TIP_TITLE, RunScreen.TEXT, true)
	_tip_body(column, ShopMenu.AMBER, lowercase)
	return panel

func _tooltip_page() -> Control:
	var page : Control = _page(RunScreen.PIXEL_FONT)
	page.add_child(MenuBackground.new())
	var variants : Array[Array] = [["A  MOLDURA", _tip_frame], ["B  PLANO", _tip_flat],
			["C  DISPLAY", _tip_display], ["D  FAIXA", _tip_strip]]
	for index : int in variants.size():
		var left : float = 40.0 + index * 308.0
		var title : Label = screen_kit._label(variants[index][0], 16, RunScreen.AMBER, true)
		title.position = Vector2(left, 40)
		page.add_child(title)
		for lowercase : bool in [false, true]:
			var top : float = 300.0 if lowercase else 90.0
			var note : Label = screen_kit._label("descrição em minúsculas" if lowercase else "descrição em maiúsculas", 8, RunScreen.TEXT_DIM)
			note.position = Vector2(left, top)
			page.add_child(note)
			var builder : Callable = variants[index][1]
			var tip : Control = builder.call(lowercase)
			tip.position = Vector2(left, top + 18.0)
			tip.custom_minimum_size.x = TIP_WIDTH
			tip.size.x = TIP_WIDTH
			page.add_child(tip)
			tip.resized.connect(tip.reset_size, CONNECT_DEFERRED)
			tip.reset_size.call_deferred()
	return page

const RESEARCH_TIPS : Array[String] = ["atual", "a moldura", "b plano", "c display", "d faixa"]

func _research_page(variant : int) -> Control:
	var holder : Control = Control.new()
	holder.size = Vector2(1280, 720)
	Global.run = null
	var menu : ResearchMenu = Global.menus[Global.Menu.RESEARCH].instantiate() as ResearchMenu
	holder.add_child(menu)
	var blocker : Control = Control.new()
	blocker.size = holder.size
	holder.add_child(blocker)
	holder.ready.connect(_place_research_tip.bind(holder, menu, variant), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return holder

func _research_upgrade(menu : ResearchMenu) -> UpgradeStats:
	var chosen : UpgradeStats = null
	var longest : int = 0
	for item : Variant in Global.CATALOG.research:
		var upgrade : UpgradeStats = item
		var length : int = Loc.t(upgrade.description_key).length()
		if (menu._state_of(upgrade) != ResearchMenu.NodeState.LOCKED and length > longest):
			chosen = upgrade
			longest = length
	return chosen

func _find_node_button(node : Node, local : Vector2) -> Button:
	var button : Button = node as Button
	if (button != null and button.size == ResearchMenu.NODE_SIZE and button.position == local):
		return button
	for child : Node in node.get_children():
		var found : Button = _find_node_button(child, local)
		if (found != null):
			return found
	return null

func _place_research_tip(holder : Control, menu : ResearchMenu, variant : int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if (!is_instance_valid(menu)):
		return
	var upgrade : UpgradeStats = _research_upgrade(menu)
	var button : Button = _find_node_button(menu, menu._node_position(upgrade))
	var tip : Control = menu._build_tooltip(upgrade)
	if (variant > 0):
		tip = _restyle_tip(tip, upgrade, menu._branch_color(upgrade), variant)
	holder.add_child(tip)
	var badge : Label = screen_kit._label("TOOLTIP: " + RESEARCH_TIPS[variant].to_upper(), 8, RunScreen.AMBER, true)
	badge.position = Vector2(560, 4)
	holder.add_child(badge)
	await get_tree().process_frame
	if (!is_instance_valid(tip)):
		return
	tip.reset_size()
	var anchor : Rect2 = button.get_global_rect() if button != null else Rect2(500, 300, 120, 112)
	var target : Vector2 = anchor.position + Vector2(anchor.size.x - 24.0, 40.0)
	if (target.x + tip.size.x > 1272.0):
		target.x = anchor.position.x - tip.size.x + 24.0
	target.y = minf(target.y, 712.0 - tip.size.y)
	tip.position = target.floor()

func _restyle_tip(original : Control, upgrade : UpgradeStats, tint : Color, variant : int) -> Control:
	var column : VBoxContainer = original.get_child(0) as VBoxContainer
	original.remove_child(column)
	original.free()
	var head : Control = column.get_child(0)
	var rule : Control = column.get_child(1)
	var body : Label = column.get_child(2)
	body.text = Loc.t(upgrade.description_key)
	var panel : PanelContainer
	match variant:
		1:
			panel = screen_kit._panel(8)
			column.remove_child(head)
			head.free()
			column.remove_child(rule)
			rule.free()
			var plate : PanelContainer = screen_kit._plate(Loc.t(upgrade.name_key).to_upper(), RunScreen.TEXT, 8, tint)
			column.add_child(plate)
			column.move_child(plate, 0)
			panel.add_child(column)
		2:
			panel = shop_kit._panel(Color("#0b1419"), tint)
			shop_kit._margin(panel, 10).add_child(column)
		3:
			panel = shop_kit._panel(Color("#4d6069"), Color("#172127"))
			var screen : ColorRect = ColorRect.new()
			var material : ShaderMaterial = ShaderMaterial.new()
			material.shader = DISPLAY_SHADER
			DisplayPalette.of_dock(BaseDock.Type.NAVAL).apply_screen(material)
			screen.material = material
			screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
			panel.add_child(screen)
			shop_kit._margin(panel, 12).add_child(column)
		_:
			panel = shop_kit._panel(Color("#0b1419"), Color("#596a73"))
			var row : HBoxContainer = _row(shop_kit._margin(panel, 6), 0)
			var strip : ColorRect = ColorRect.new()
			strip.color = tint
			strip.custom_minimum_size.x = 3
			row.add_child(strip)
			shop_kit._margin(row, 6).add_child(column)
	var source : Control = _page(ShopMenu.FONT)
	panel.theme = source.theme
	source.free()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return panel

const ALERTS : Array[String] = ["no jogo", "a moldura", "b display", "c faixa", "d producao"]
const MARKS : Array[Dictionary] = [
	{"label": "CHEFE", "color": Color("#dfa0a2"), "objective": RunData.Objective.DEFEAT_BOSS, "at": Vector2(1248, 270), "dir": Vector2i(1, 0)},
	{"label": "BOMBARDEIRO", "color": Color("#ecc078"), "objective": RunData.Objective.SHOOT_DOWN_BOMBER, "at": Vector2(1248, 76), "dir": Vector2i(1, -1)},
	{"label": "ESCOLTA", "color": Color("#78dddd"), "objective": RunData.Objective.ESCORT, "at": Vector2(32, 390), "dir": Vector2i(-1, 0)},
]

func _backdrop(page : Control) -> void:
	for band : Array in [[0, 360, Color("#6f9fd8")], [250, 110, Color("#b7d6f2")], [360, 160, Color("#1f6fd0")]]:
		var area : ColorRect = ColorRect.new()
		area.position = Vector2(0, band[0])
		area.size = Vector2(1280, band[1])
		area.color = band[2]
		page.add_child(area)
	for bar : Array in [[0.0, 44.0], [520.0, 200.0]]:
		var panel : Panel = Panel.new()
		panel.add_theme_stylebox_override("panel", MenuBackground.make_box())
		panel.position = Vector2(0, bar[0])
		panel.size = Vector2(1280, bar[1])
		page.add_child(panel)
	var minimap : PanelContainer = shop_kit._panel(Color("#151f25"), Color("#596a73"))
	minimap.position = Vector2((1280.0 - BattleMinimap.SIZE.x) * 0.5, BattleMinimap.TOP)
	minimap.size = BattleMinimap.SIZE
	page.add_child(minimap)

func _arrow(direction : Vector2i, color : Color) -> TextureRect:
	var image : Image = Image.create_empty(14, 14, false, Image.FORMAT_RGBA8)
	var way : Vector2 = Vector2(direction).normalized()
	for y : int in 14:
		for x : int in 14:
			var point : Vector2 = Vector2(x + 0.5, y + 0.5) - Vector2(7, 7)
			var along : float = point.dot(way)
			var across : float = absf(point.cross(way))
			if (along >= -4.0 and along <= 6.0 and across <= (6.0 - along) * 0.7):
				image.set_pixel(x, y, color)
			elif (along >= -5.0 and along <= 7.0 and across <= (7.5 - along) * 0.7):
				image.set_pixel(x, y, Color("#090f15"))
	var rect : TextureRect = TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.custom_minimum_size = Vector2(28, 28)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size_flags_vertical = SIZE_SHRINK_CENTER
	return rect

func _crt(panel : PanelContainer) -> void:
	var screen : ColorRect = ColorRect.new()
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	DisplayPalette.of_dock(BaseDock.Type.NAVAL).apply_screen(material)
	screen.material = material
	screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
	panel.add_child(screen)

func _icon_of(mark : Dictionary) -> TextureRect:
	var icon : TextureRect = screen_kit._icon(RunData.objective_hud_icon(mark["objective"]))
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	return icon

func _marker(mark : Dictionary, variant : int) -> Control:
	var color : Color = mark["color"]
	var direction : Vector2i = mark["dir"]
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var tag : PanelContainer
	if (variant == 1):
		tag = screen_kit._panel(4)
	elif (variant == 2):
		tag = shop_kit._panel(Color("#4d6069"), color)
		_crt(tag)
	else:
		tag = shop_kit._panel(Color("#0b1419"), color)
	var inner : HBoxContainer = _row(shop_kit._margin(tag, 2 if variant == 1 else 10), 6)
	if (variant != 3):
		inner.add_child(_icon_of(mark))
	var name_label : Label = screen_kit._label(mark["label"], 8, color, true)
	name_label.size_flags_vertical = SIZE_SHRINK_CENTER
	inner.add_child(name_label)
	if (direction.x > 0):
		row.add_child(tag)
		row.add_child(_arrow(direction, color))
	else:
		row.add_child(_arrow(direction, color))
		row.add_child(tag)
	return row

func _alert(variant : int) -> Control:
	var mark : Dictionary = MARKS[1]
	var color : Color = mark["color"]
	var panel : PanelContainer
	var holder : MarginContainer
	if (variant == 1):
		panel = screen_kit._panel(12)
		holder = shop_kit._margin(panel, 0)
	elif (variant == 2):
		panel = shop_kit._panel(Color("#4d6069"), color)
		_crt(panel)
		holder = shop_kit._margin(panel, 18)
	else:
		panel = shop_kit._panel(Color(0.035, 0.06, 0.08, 0.85), color)
		holder = shop_kit._margin(panel, 14)
	var row : HBoxContainer = _row(holder, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if (variant == 1):
		var strip : ColorRect = ColorRect.new()
		strip.color = color
		strip.custom_minimum_size.x = 4
		row.add_child(strip)
	row.add_child(_icon_of(mark))
	var texts : BoxContainer = HBoxContainer.new() if variant == 3 else VBoxContainer.new()
	texts.add_theme_constant_override("separation", 16 if variant == 3 else 8)
	texts.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(texts)
	texts.add_child(screen_kit._label("BOMBARDEIRO A CAMINHO", 16, color, true))
	var body : Label = screen_kit._label("Abata antes que ele fuja.", 8, RunScreen.TEXT)
	body.text = "Abata antes que ele fuja."
	body.size_flags_vertical = SIZE_SHRINK_CENTER
	PixelText.describe(body)
	texts.add_child(body)
	panel.custom_minimum_size.x = 1280 if variant == 3 else 440
	panel.position = Vector2(0 if variant == 3 else 420, 120)
	return panel

func _current_alert(page : Control) -> void:
	var markers : ObjectiveMarkers = ObjectiveMarkers.new()
	var boss : EntityStats = _marked_unit(0)
	var bomber : EntityStats = _marked_unit(1)
	var escort : EntityStats = _marked_unit(2)
	markers.provider = func() -> Array:
		return [{"pos": Vector2(3000, 300), "kind": "enemy", "label": "battle.boss_caps", "unit": boss},
				{"pos": Vector2(2200, -600), "kind": "enemy", "label": "battle.bomber", "unit": bomber},
				{"pos": Vector2(-2000, 420), "kind": "ally", "label": "battle.escort_caps", "unit": escort}]
	page.add_child(markers)
	BattleAlert.show_on(page, Loc.t("battle.bomber_incoming"), Loc.t("battle.bomber_incoming_desc"), bomber)

func _place_marker(marker : Control, at : Vector2, leftward : bool) -> void:
	marker.reset_size()
	marker.position = Vector2(at.x if leftward else at.x - marker.size.x, at.y).floor()

func _alert_page(variant : int) -> Control:
	var page : Control = _page(RunScreen.FONT)
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop(page)
	if (variant == 0):
		_current_alert(page)
	else:
		page.add_child(_queue_alert() if variant == 4 else _alert(variant))
		for index : int in MARKS.size():
			var mark : Dictionary = MARKS[index]
			var marker : Control = _queue_marker(index) if variant == 4 else _marker(mark, variant)
			page.add_child(marker)
			var place : Callable = _place_marker.bind(marker, mark["at"], (mark["dir"] as Vector2i).x < 0)
			marker.resized.connect(place, CONNECT_DEFERRED)
			place.call_deferred()
	var badge : Label = screen_kit._label("ALERTA E MARCADOR: " + ALERTS[variant].to_upper(), 16, RunScreen.AMBER, true)
	badge.position = Vector2(40, 480)
	badge.add_theme_color_override("font_outline_color", Color("#090f15"))
	badge.add_theme_constant_override("outline_size", 4)
	page.add_child(badge)
	return page

const QUEUE_WELL : Vector2 = Vector2(128, 48)

func _marked_unit(index : int) -> EntityStats:
	match index:
		0:
			return load("res://core/resources/boats/boss_dreadnought.tres") as EntityStats
		1:
			return load("res://core/resources/boats/boss_heavy_bomber.tres") as EntityStats
	return RunBattleConfig.escort_stats()

func _queue_well(stats : EntityStats, size : Vector2) -> PanelContainer:
	var pal : DisplayPalette = DisplayPalette.of_unit(stats)
	var well : PanelContainer = hud_kit._panel(Color("#4d6069"), Color("#172127"))
	well.custom_minimum_size = size
	var screen : ColorRect = ColorRect.new()
	var material : ShaderMaterial = ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	pal.apply_screen(material)
	screen.material = material
	screen.resized.connect(func() -> void: material.set_shader_parameter("rect_size", screen.size))
	well.add_child(screen)
	var art : TextureRect = hud_kit._tinted_icon(UnitIcon.of(stats), Vector2.ZERO, pal.rest)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.size_flags_vertical = SIZE_FILL
	art.clip_contents = true
	well.add_child(art)
	return well

func _queue_module(edge : Color) -> PanelContainer:
	return hud_kit._panel(Color("#202b31"), edge)

func _queue_marker(index : int) -> Control:
	var mark : Dictionary = MARKS[index]
	var color : Color = mark["color"]
	var direction : Vector2i = mark["dir"]
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var module : PanelContainer = _queue_module(color)
	var column : VBoxContainer = _column(shop_kit._margin(module, 6), 4)
	column.add_child(screen_kit._label(mark["label"], 8, color, true))
	column.add_child(_queue_well(_marked_unit(index), QUEUE_WELL))
	if (direction.x > 0):
		row.add_child(module)
		row.add_child(_arrow(direction, color))
	else:
		row.add_child(_arrow(direction, color))
		row.add_child(module)
	return row

func _queue_alert() -> Control:
	var color : Color = MARKS[1]["color"]
	var module : PanelContainer = _queue_module(color)
	var row : HBoxContainer = _row(shop_kit._margin(module, 12), 14)
	row.add_child(_queue_well(_marked_unit(1), Vector2(128, 64)))
	var texts : VBoxContainer = _column(row, 8)
	texts.size_flags_vertical = SIZE_SHRINK_CENTER
	texts.add_child(screen_kit._label("BOMBARDEIRO A CAMINHO", 16, color, true))
	var body : Label = screen_kit._label("Abata antes que ele fuja.", 8, RunScreen.TEXT)
	body.text = "Abata antes que ele fuja."
	PixelText.describe(body)
	texts.add_child(body)
	module.custom_minimum_size.x = 540
	module.position = Vector2(370, 120)
	return module
