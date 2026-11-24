extends HudSfx

const MANUAL_META : StringName = &"ui_sfx_manual"
const FOCUS_GRACE_MS : int = 250

var _born : Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node : Node) -> void:
	var button : BaseButton = node as BaseButton
	if (!button or button.has_meta(MANUAL_META)):
		return
	_born[button.get_instance_id()] = Time.get_ticks_msec()
	button.mouse_entered.connect(_on_hover.bind(button))
	button.focus_entered.connect(_on_focus.bind(button))
	button.pressed.connect(_on_pressed.bind(button))
	button.tree_exited.connect(func() -> void: _born.erase(button.get_instance_id()))

func _on_hover(button : BaseButton) -> void:
	if (!button.disabled):
		play(&"hover")

func _on_focus(button : BaseButton) -> void:
	if (button.disabled or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		return
	if (Time.get_ticks_msec() - int(_born.get(button.get_instance_id(), 0)) < FOCUS_GRACE_MS):
		return
	play(&"select")

func _on_pressed(button : BaseButton) -> void:
	if (!button.disabled):
		play(&"confirm")
