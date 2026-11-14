extends PanelContainer
## Credits list, opened from the title screen. Cites every third-party asset in the game.
## To change the credits, edit CREDITS below (and keep CREDITS.md in the project folder in sync).

signal closed

## Each section: a heading and its entries. Each entry: [who / what, what it is used for, where it is from].
## Leave the 2nd or 3rd string empty to skip that line.
const CREDITS := [
	["MADE BY", [
		["Erkhem", "Game design and programming", ""],
		["Erdembileg", "Game design and programming", ""],
		["Enkhtuvshin", "Music", ""],
	]],
	["ART", [
		["0x72 - \"16x16 DungeonTileset II\" (CC0 1.0)",
			"Player, enemies, Ashen Tyrant boss, tiles, props, pickups and icons (adapted and recoloured)",
			"0x72.itch.io/dungeontileset-ii"],
		["Kronovi (DarkPixel) - \"Boss: Undead Executioner [FREE]\"",
			"Hollow Reaper boss and Lost Spirits (adapted)",
			"darkpixel-kronovi.itch.io/undead-executioner"],
		["CreativeKind - \"Necromancer (Free)\"",
			"Necromancer boss (mirrored and outlined)",
			"creativekind.itch.io/necromancer-free"],
		["Original",
			"Logo, bullets, crosshair, attack warnings and screen effects",
			""],
	]],
	["MUSIC", [
		["Original", "Menu, hall and boss themes composed by Enkhtuvshin", ""],
	]],
	["SOUND EFFECTS", [
		["Original", "Synthesized for this game", ""],
	]],
	["ENGINE", [
		["Godot Engine (MIT licence)",
			"Copyright (c) 2014-present Godot Engine contributors, (c) 2007-2014 Juan Linietsky, Ariel Manzur",
			"godotengine.org/license"],
	]],
]

const TEXT_WIDTH := 300
const LIST_HEIGHT := 150
const SCROLL_SPEED := 140.0

var _scroll: ScrollContainer
var _scroll_pos := 0.0


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(UIKit.label("Credits", 14, HORIZONTAL_ALIGNMENT_CENTER, UIKit.ACCENT))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(TEXT_WIDTH + 12, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	_scroll.add_child(list)

	for section: Array in CREDITS:
		if list.get_child_count() > 0:
			list.add_child(_spacer(5))
		list.add_child(_line(str(section[0]), 9, UIKit.ACCENT))
		for entry: Array in section[1]:
			list.add_child(_spacer(2))
			list.add_child(_line(str(entry[0]), 8, Color.WHITE))
			if str(entry[1]) != "":
				list.add_child(_line(str(entry[1]), 7, UIKit.TEXT_DIM))
			if str(entry[2]) != "":
				list.add_child(_line(str(entry[2]), 7, Color("#8fb8e3")))

	var back := UIKit.button("Back", _on_back)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _process(delta: float) -> void:
	# Arrow keys / stick scroll the list (the mouse wheel works on its own).
	var dir := Input.get_axis(&"ui_up", &"ui_down")
	if dir == 0.0:
		_scroll_pos = float(_scroll.scroll_vertical)
		return
	_scroll_pos += dir * SCROLL_SPEED * delta
	_scroll.scroll_vertical = int(_scroll_pos)
	_scroll_pos = clampf(_scroll_pos, 0.0, float(_scroll.scroll_vertical) + 1.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _line(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, HORIZONTAL_ALIGNMENT_LEFT, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	return l


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _on_back() -> void:
	closed.emit()
	queue_free()
