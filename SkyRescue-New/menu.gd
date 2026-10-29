extends Control

var music: AudioStreamPlayer
var starting := false

func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	return style

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var background := TextureRect.new()
	background.texture = preload("res://art/menu_action.svg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var area := CenterContainer.new()
	area.anchor_left = 0.055
	area.anchor_right = 0.43
	area.anchor_top = 0.12
	area.anchor_bottom = 0.9
	add_child(area)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	area.add_child(column)
	var badge := Label.new()
	badge.text = "عملیات هوایی"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color("72d8e3"))
	badge.add_theme_font_size_override("font_size", 18)
	column.add_child(badge)
	var title := Label.new()
	title.text = "نگهبان آسمان"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f0f4ee"))
	title.add_theme_color_override("font_shadow_color", Color("030d18"))
	title.add_theme_constant_override("shadow_offset_y", 4)
	column.add_child(title)
	var line := HSeparator.new()
	line.modulate = Color("5d949c")
	column.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	column.add_child(spacer)
	var start := Button.new()
	start.text = "شروع بازی"
	start.custom_minimum_size.y = 64
	start.add_theme_font_size_override("font_size", 26)
	start.add_theme_color_override("font_color", Color("081b27"))
	start.add_theme_color_override("font_hover_color", Color("081b27"))
	start.add_theme_stylebox_override("normal", button_style(Color("dfb67a"), Color("ffe0a6")))
	start.add_theme_stylebox_override("hover", button_style(Color("ffdda1"), Color("fff0d0")))
	start.add_theme_stylebox_override("pressed", button_style(Color("b88e54"), Color("dfb67a")))
	start.pressed.connect(start_game)
	column.add_child(start)
	var exit_button := Button.new()
	exit_button.text = "خروج"
	exit_button.custom_minimum_size.y = 56
	exit_button.add_theme_stylebox_override("normal", button_style(Color(0.03, 0.09, 0.14, 0.85), Color("456774")))
	exit_button.add_theme_stylebox_override("hover", button_style(Color("1c3947"), Color("91c3ce")))
	exit_button.pressed.connect(func(): get_tree().quit())
	column.add_child(exit_button)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://audio/awesomeness.wav")
	music.volume_db = -12
	add_child(music)
	music.finished.connect(func(): music.play())
	music.play()
	start.grab_focus()

func start_game() -> void:
	if starting:
		return
	starting = true
	music.stop()
	var error := get_tree().change_scene_to_file("res://game.tscn")
	if error != OK:
		starting = false
		music.play()
		push_error("بارگذاری بازی ناموفق بود: %s" % error)
