class_name GameSettings
extends RefCounted

const PATH : String = "user://settings.cfg"

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum ScaleMode { FIT, PIXEL, EXPAND }

const RESOLUTIONS : Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]

static var window_mode : int = WindowMode.WINDOWED
static var resolution_index : int = 0
static var scale_mode : int = ScaleMode.FIT
static var vsync : bool = true
static var language : String = "en"
static var volumes : Dictionary = {"Master": 100, "WorldSFX": 100, "UI": 100}

static func load_settings() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	if (cfg.load(PATH) != OK):
		return
	window_mode = int(cfg.get_value("display", "window_mode", window_mode))
	resolution_index = clampi(int(cfg.get_value("display", "resolution_index", 0)), 0, RESOLUTIONS.size() - 1)
	scale_mode = int(cfg.get_value("display", "scale_mode", scale_mode))
	vsync = bool(cfg.get_value("display", "vsync", true))
	language = str(cfg.get_value("general", "language", language))
	for bus : String in volumes:
		volumes[bus] = clampi(int(cfg.get_value("audio", bus, 100)), 0, 100)

static func save_settings() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "scale_mode", scale_mode)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("general", "language", language)
	for bus : String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.save(PATH)

static func apply_volume(bus : String) -> void:
	var index : int = AudioServer.get_bus_index(bus)
	if (index < 0):
		return
	var percent : int = int(volumes.get(bus, 100))
	AudioServer.set_bus_mute(index, percent <= 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent / 100.0, 0.0001)))

static func apply_audio() -> void:
	for bus : String in volumes:
		apply_volume(bus)

static func apply(window : Window, apply_size : bool = true) -> void:
	window.unresizable = false
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = Vector2i(1280, 720)
	match scale_mode:
		ScaleMode.FIT:
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
			window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		ScaleMode.PIXEL:
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
			window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		_:
			window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	apply_audio()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		WindowMode.FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		WindowMode.BORDERLESS:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			window.mode = Window.MODE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			if (apply_size):
				var size : Vector2i = RESOLUTIONS[resolution_index]
				window.size = size
				var screen : Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
				window.position = screen.position + (screen.size - window.size) / 2
