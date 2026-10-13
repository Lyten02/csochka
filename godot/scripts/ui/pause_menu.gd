class_name CSPauseMenu
extends CanvasLayer
## In-game CS 1.6 Pause Menu (opened with ESC).
## Allows opening "Параметры" (Settings), "Выбор карты" (Map select), resuming, or returning to main menu.

const CSSettingsDialog = preload("res://scripts/ui/settings_dialog.gd")
const CSMapSelectDialog = preload("res://scripts/ui/map_select_dialog.gd")
const CSKnifeSelectDialog = preload("res://scripts/ui/knife_select_dialog.gd")

var _overlay: ColorRect
var _menu_box: VBoxContainer
var _settings_dialog: CSSettingsDialog
var _map_dialog: CSMapSelectDialog
var _knife_dialog: CSKnifeSelectDialog

var _btn_resume: Button
var _btn_knives: Button
var _btn_map: Button
var _btn_settings: Button
var _btn_main_menu: Button
var _btn_quit: Button

var _font_bold: Font
var _font_regular: Font


func _ready() -> void:
	add_to_group("knife_input_blockers")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_load_fonts()
	_build_ui()


func _load_fonts() -> void:
	if ResourceLoader.exists("res://ui/fonts/tahomabd.ttf"):
		_font_bold = load("res://ui/fonts/tahomabd.ttf")
	if ResourceLoader.exists("res://ui/fonts/tahoma.ttf"):
		_font_regular = load("res://ui/fonts/tahoma.ttf")


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.04, 0.06, 0.08, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var menu_margin := MarginContainer.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_margin.add_theme_constant_override("margin_left", 64)
	menu_margin.add_theme_constant_override("margin_bottom", 120)
	menu_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(menu_margin)

	_menu_box = VBoxContainer.new()
	_menu_box.alignment = BoxContainer.ALIGNMENT_END
	_menu_box.add_theme_constant_override("separation", 14)
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_margin.add_child(_menu_box)

	var title := Label.new()
	title.text = "COUNTER-STRIKE 1.6"
	if _font_bold:
		title.add_theme_font_override("font", _font_bold)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	_menu_box.add_child(title)

	_btn_resume = _create_menu_button("ПРОДОЛЖИТЬ", _on_resume_pressed)
	_menu_box.add_child(_btn_resume)

	_btn_knives = _create_menu_button("ВЫБОР НОЖА", _on_knives_pressed)
	_menu_box.add_child(_btn_knives)

	_btn_map = _create_menu_button("ВЫБОР КАРТЫ", _on_map_pressed)
	_menu_box.add_child(_btn_map)

	_btn_settings = _create_menu_button("НАСТРОЙКИ", _on_settings_pressed)
	_menu_box.add_child(_btn_settings)

	_btn_main_menu = _create_menu_button("В ГЛАВНОЕ МЕНЮ", _on_main_menu_pressed)
	_menu_box.add_child(_btn_main_menu)

	_btn_quit = _create_menu_button("ВЫХОД ИЗ ИГРЫ", _on_quit_pressed)
	_menu_box.add_child(_btn_quit)

	# Dialogs layer
	var dialog_center := CenterContainer.new()
	dialog_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dialog_center)

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
	btn.custom_minimum_size = Vector2(240, 38)
	btn.flat = true

	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.88, 1.0))

	var empty_box := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_box)
	btn.add_theme_stylebox_override("pressed", empty_box)
	btn.add_theme_stylebox_override("focus", empty_box)

	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Color(0.0, 0.7, 1.0, 0.12)
	hover_box.border_color = Color(0.0, 0.85, 1.0)
	hover_box.border_width_left = 3
	hover_box.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover_box)

	btn.pressed.connect(callback)
	return btn


func toggle_menu() -> void:
	if visible:
		if _settings_dialog.visible:
			_settings_dialog.visible = false
			return
		if _map_dialog.visible:
			_map_dialog.visible = false
			return
		if _knife_dialog.visible:
			_knife_dialog.visible = false
			return
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	_settings_dialog.visible = false
	_map_dialog.visible = false
	if _knife_dialog:
		_knife_dialog.visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle_menu()


func _on_resume_pressed() -> void:
	_play_click_sound()
	close_menu()


func _on_knives_pressed() -> void:
	_play_click_sound()
	_settings_dialog.visible = false
	_map_dialog.visible = false
	_knife_dialog.visible = true


func _on_map_pressed() -> void:
	_play_click_sound()
	_settings_dialog.visible = false
	_knife_dialog.visible = false
	_map_dialog.visible = true


func _on_settings_pressed() -> void:
	_play_click_sound()
	_map_dialog.visible = false
	_knife_dialog.visible = false
	_settings_dialog.visible = true


func _on_main_menu_pressed() -> void:
	_play_click_sound()
	close_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit_pressed() -> void:
	_play_click_sound()
	get_tree().quit()


func _on_map_selected_launch(_map_info: Dictionary) -> void:
	_play_click_sound()
	close_menu()
	get_tree().reload_current_scene()


func _play_click_sound() -> void:
	var ap := AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		ap.stream = load("res://audio/ui_click.wav")
	add_child(ap)
	ap.finished.connect(ap.queue_free)
	ap.play()
