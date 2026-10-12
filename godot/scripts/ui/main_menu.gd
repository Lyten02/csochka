class_name CSMainMenu
extends Control
## CS 1.6 Classic Main Menu with background media_1790521077001.png,
## "Играть" (Play / Map select) and "Настройки" (Options dialog).

const CSMapSelectDialog = preload("res://scripts/ui/map_select_dialog.gd")
const CSSettingsDialog = preload("res://scripts/ui/settings_dialog.gd")
const CSKnifeSelectDialog = preload("res://scripts/ui/knife_select_dialog.gd")

var _map_dialog: CSMapSelectDialog
var _settings_dialog: CSSettingsDialog
var _knife_dialog: CSKnifeSelectDialog

var _btn_play: Button
var _btn_knives: Button
var _btn_settings: Button
var _btn_quit: Button

var _font_bold: Font
var _font_regular: Font


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_fonts()
	_build_ui()


func _load_fonts() -> void:
	if ResourceLoader.exists("res://ui/fonts/tahomabd.ttf"):
		_font_bold = load("res://ui/fonts/tahomabd.ttf")
	if ResourceLoader.exists("res://ui/fonts/tahoma.ttf"):
		_font_regular = load("res://ui/fonts/tahoma.ttf")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# --- 1. Background Image ---
	var bg_tex := TextureRect.new()
	bg_tex.name = "MenuBackground"
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if ResourceLoader.exists("res://ui/menu_bg.png"):
		bg_tex.texture = load("res://ui/menu_bg.png")
	add_child(bg_tex)

	# Subtle vignette / dark tint on left side so menu text is super readable
	var gradient_rect := TextureRect.new()
	gradient_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.colors = [Color(0.04, 0.05, 0.07, 0.75), Color(0.04, 0.05, 0.07, 0.15)]
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.5)
	grad_tex.fill_to = Vector2(0.65, 0.5)
	gradient_rect.texture = grad_tex
	gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gradient_rect)

	# --- 2. Menu Buttons Container ---
	var menu_margin := MarginContainer.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_margin.add_theme_constant_override("margin_left", 64)
	menu_margin.add_theme_constant_override("margin_bottom", 90)
	menu_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_margin)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_END
	menu_vbox.add_theme_constant_override("separation", 16)
	menu_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_margin.add_child(menu_vbox)

	# Buttons
	_btn_play = _create_menu_button("ИГРАТЬ", _on_play_pressed)
	menu_vbox.add_child(_btn_play)

	_btn_knives = _create_menu_button("ВЫБОР НОЖА", _on_knives_pressed)
	menu_vbox.add_child(_btn_knives)

	_btn_settings = _create_menu_button("НАСТРОЙКИ", _on_settings_pressed)
	menu_vbox.add_child(_btn_settings)

	_btn_quit = _create_menu_button("ВЫХОД", _on_quit_pressed)
	menu_vbox.add_child(_btn_quit)

	# Footer build info
	var footer := Label.new()
	footer.text = "CS 1.6 GoldSrc PMove Engine  •  35HP Bunnyhop Arena"
	if _font_regular:
		footer.add_theme_font_override("font", _font_regular)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -380.0
	footer.offset_top = -32.0
	footer.offset_right = -20.0
	footer.offset_bottom = -10.0
	add_child(footer)

	# --- 3. Dialogs (Centered Modals) ---
	var dialog_center := CenterContainer.new()
	dialog_center.name = "DialogLayer"
	dialog_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialog_center)

	_map_dialog = CSMapSelectDialog.new()
	_map_dialog.visible = false
	_map_dialog.map_selected.connect(_on_map_selected_launch)
	dialog_center.add_child(_map_dialog)

	_knife_dialog = CSKnifeSelectDialog.new()
	_knife_dialog.visible = false
	dialog_center.add_child(_knife_dialog)

	_settings_dialog = CSSettingsDialog.new()
	_settings_dialog.visible = false
	dialog_center.add_child(_settings_dialog)


func _create_menu_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(240, 42)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.flat = true

	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.65, 0.85))

	# Subtle hover and normal stylebox
	var empty_box := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_box)
	btn.add_theme_stylebox_override("pressed", empty_box)
	btn.add_theme_stylebox_override("focus", empty_box)

	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Color(0.0, 0.7, 1.0, 0.12)
	hover_box.border_color = Color(0.0, 0.85, 1.0)
	hover_box.set_border_width_all(0)
	hover_box.border_width_left = 3
	hover_box.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_box)

	btn.pressed.connect(callback)
	btn.mouse_entered.connect(_play_hover_sound)
	return btn


func _on_play_pressed() -> void:
	_play_click_sound()
	_settings_dialog.visible = false
	_knife_dialog.visible = false
	_map_dialog.visible = true


func _on_knives_pressed() -> void:
	_play_click_sound()
	_map_dialog.visible = false
	_settings_dialog.visible = false
	_knife_dialog.visible = true


func _on_settings_pressed() -> void:
	_play_click_sound()
	_map_dialog.visible = false
	_knife_dialog.visible = false
	_settings_dialog.visible = true


func _on_quit_pressed() -> void:
	_play_click_sound()
	get_tree().quit()


func _on_map_selected_launch(_map_info: Dictionary) -> void:
	_play_click_sound()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _play_hover_sound() -> void:
	# Subtle hover feedback
	pass


func _play_click_sound() -> void:
	var ap := AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		ap.stream = load("res://audio/ui_click.wav")
	add_child(ap)
	ap.finished.connect(ap.queue_free)
	ap.play()
