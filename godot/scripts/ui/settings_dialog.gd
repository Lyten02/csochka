class_name CSSettingsDialog
extends PanelContainer
## CS 1.6 VGUI "Параметры" (Settings) Dialog
## Matches the classic GoldSrc CS 1.6 options window with tabs, dark blue/slate theme,
## and settings for Fall Damage, Auto-bhop, Speed cap, Stamina, Mouse, Video, Audio, and Keys.

signal closed

var _sm: Node

# Tabs
var _tab_container: TabContainer
var _tab_keyboard: Control
var _tab_mouse: Control
var _tab_gameplay: Control
var _tab_video: Control
var _tab_audio: Control
var _tab_multiplayer: Control

# Controls - Gameplay
var _chk_fall_damage: CheckBox
var _chk_auto_bhop: CheckBox
var _chk_speed_cap: CheckBox
var _chk_jump_stamina: CheckBox
var _spin_gravity: SpinBox

# Controls - Mouse
var _slider_sens: HSlider
var _lbl_sens_val: LineEdit
var _chk_invert_mouse: CheckBox

# Controls - Video
var _chk_fullscreen: CheckBox
var _slider_fov: HSlider
var _lbl_fov_val: Label
var _opt_fps: OptionButton

# Controls - Audio
var _slider_vol: HSlider
var _lbl_vol_val: Label

# Controls - Keyboard
var _key_tree: Tree
var _waiting_for_key := false
var _selected_action := ""
var _selected_col := 1
var _key_prompt_panel: PanelContainer

# Bottom buttons
var _btn_ok: Button
var _btn_cancel: Button
var _btn_apply: Button

var _font_regular: Font
var _font_bold: Font


func _ready() -> void:
	_sm = get_node_or_null("/root/SettingsManager")
	_load_fonts()
	_build_ui()
	_load_current_values()


func _load_fonts() -> void:
	if ResourceLoader.exists("res://ui/fonts/tahoma.ttf"):
		_font_regular = load("res://ui/fonts/tahoma.ttf")
	if ResourceLoader.exists("res://ui/fonts/tahomabd.ttf"):
		_font_bold = load("res://ui/fonts/tahomabd.ttf")


func _build_ui() -> void:
	custom_minimum_size = Vector2(680, 520)
	
	# Main dialog style (dark VGUI panel with classic border)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.14, 0.98)
	style.border_color = Color(0.24, 0.32, 0.40)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# --- Title Bar ---
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 28)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.13, 0.17, 0.22, 1.0)
	title_style.set_content_margin_all(4)
	
	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", title_style)
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title_inner := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "  Параметры"
	if _font_bold:
		title_lbl.add_theme_font_override("font", _font_bold)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_inner.add_child(title_lbl)

	var btn_close := Button.new()
	btn_close.text = " X "
	btn_close.custom_minimum_size = Vector2(24, 20)
	btn_close.pressed.connect(_on_cancel_pressed)
	_style_button(btn_close)
	title_inner.add_child(btn_close)

	title_panel.add_child(title_inner)
	main_vbox.add_child(title_panel)

	# --- Margin Container for Content ---
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	content_margin.add_child(inner_vbox)

	# --- Tab Container ---
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	_tab_container.clip_tabs = false
	_style_tab_container(_tab_container)
	inner_vbox.add_child(_tab_container)

	_create_tab_gameplay()
	_create_tab_keyboard()
	_create_tab_mouse()
	_create_tab_video()
	_create_tab_audio()

	# Select gameplay tab initially or keyboard
	_tab_container.current_tab = 0

	# --- Bottom Action Bar ---
	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 10)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END

	var btn_defaults := Button.new()
	btn_defaults.text = "Стандартно"
	btn_defaults.custom_minimum_size = Vector2(100, 26)
	btn_defaults.pressed.connect(_on_defaults_pressed)
	_style_button(btn_defaults)
	bottom_bar.add_child(btn_defaults)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	_btn_ok = Button.new()
	_btn_ok.text = "OK"
	_btn_ok.custom_minimum_size = Vector2(85, 26)
	_btn_ok.pressed.connect(_on_ok_pressed)
	_style_button(_btn_ok)
	bottom_bar.add_child(_btn_ok)

	_btn_cancel = Button.new()
	_btn_cancel.text = "Отмена"
	_btn_cancel.custom_minimum_size = Vector2(85, 26)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_style_button(_btn_cancel)
	bottom_bar.add_child(_btn_cancel)

	_btn_apply = Button.new()
	_btn_apply.text = "Применить"
	_btn_apply.custom_minimum_size = Vector2(95, 26)
	_btn_apply.pressed.connect(_on_apply_pressed)
	_style_button(_btn_apply)
	bottom_bar.add_child(_btn_apply)

	inner_vbox.add_child(bottom_bar)

	# Modal prompt when waiting for keypress
	_create_key_prompt()


# =============================================================================
# TABS CREATION
# =============================================================================

func _create_tab_gameplay() -> void:
	_tab_gameplay = MarginContainer.new()
	_tab_gameplay.name = "Разное"
	_tab_gameplay.add_theme_constant_override("margin_left", 16)
	_tab_gameplay.add_theme_constant_override("margin_top", 16)
	_tab_gameplay.add_theme_constant_override("margin_right", 16)
	_tab_gameplay.add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_tab_gameplay.add_child(vbox)

	var header := Label.new()
	header.text = "Параметры физики и геймплея GoldSrc:"
	if _font_bold:
		header.add_theme_font_override("font", _font_bold)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(header)

	# --- FALL DAMAGE CHECKBOX ---
	_chk_fall_damage = CheckBox.new()
	_chk_fall_damage.text = " Урон от падения (Fall Damage) — урон при падении с высоты > 580 u/s"
	_style_checkbox(_chk_fall_damage)
	vbox.add_child(_chk_fall_damage)

	# --- AUTO BHOP CHECKBOX ---
	_chk_auto_bhop = CheckBox.new()
	_chk_auto_bhop.text = " Автоматическая распрыжка (Auto-bhop) — зажим пробела"
	_style_checkbox(_chk_auto_bhop)
	vbox.add_child(_chk_auto_bhop)

	# --- SPEED CAP CHECKBOX ---
	_chk_speed_cap = CheckBox.new()
	_chk_speed_cap.text = " Ограничение скорости распрыжки (1.2x maxspeed cap, дефолт CS 1.6)"
	_style_checkbox(_chk_speed_cap)
	vbox.add_child(_chk_speed_cap)

	# --- JUMP STAMINA CHECKBOX ---
	_chk_jump_stamina = CheckBox.new()
	_chk_jump_stamina.text = " Стамина прыжков (fuser2 — замедление при частых приземлениях)"
	_style_checkbox(_chk_jump_stamina)
	vbox.add_child(_chk_jump_stamina)

	# --- GRAVITY SPINBOX ---
	var grav_row := HBoxContainer.new()
	grav_row.add_theme_constant_override("separation", 12)
	var grav_lbl := Label.new()
	grav_lbl.text = "Гравитация (sv_gravity):"
	_style_label(grav_lbl)
	grav_row.add_child(grav_lbl)

	_spin_gravity = SpinBox.new()
	_spin_gravity.min_value = 100.0
	_spin_gravity.max_value = 2000.0
	_spin_gravity.step = 25.0
	_spin_gravity.value = 800.0
	grav_row.add_child(_spin_gravity)
	vbox.add_child(grav_row)

	var note := Label.new()
	note.text = "Подсказка: на карте 35hp_3 падение с моста на нижний ярус наносит ~70 урона, а с большой высоты — летально."
	note.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	note.add_theme_font_size_override("font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)

	_tab_container.add_child(_tab_gameplay)


func _create_tab_keyboard() -> void:
	_tab_keyboard = MarginContainer.new()
	_tab_keyboard.name = "Клавиатура"
	_tab_keyboard.add_theme_constant_override("margin_left", 8)
	_tab_keyboard.add_theme_constant_override("margin_top", 8)
	_tab_keyboard.add_theme_constant_override("margin_right", 8)
	_tab_keyboard.add_theme_constant_override("margin_bottom", 8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_tab_keyboard.add_child(vbox)

	# Tree for keybinds
	_key_tree = Tree.new()
	_key_tree.columns = 3
	_key_tree.set_column_title(0, "ДЕЙСТВИЕ")
	_key_tree.set_column_title(1, "КЛАВИША")
	_key_tree.set_column_title(2, "ДОПОЛНИТЕЛЬНАЯ")
	_key_tree.set_column_titles_visible(true)
	_key_tree.set_column_expand(0, true)
	_key_tree.set_column_expand(1, true)
	_key_tree.set_column_expand(2, true)
	_key_tree.select_mode = Tree.SELECT_ROW
	_key_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tree(_key_tree)
	vbox.add_child(_key_tree)

	_populate_key_tree()

	# Action buttons below table
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_END

	var btn_edit := Button.new()
	btn_edit.text = "Изменить"
	btn_edit.custom_minimum_size = Vector2(90, 24)
	btn_edit.pressed.connect(_on_edit_key_pressed)
	_style_button(btn_edit)
	btn_row.add_child(btn_edit)

	var btn_clear := Button.new()
	btn_clear.text = "Очистить"
	btn_clear.custom_minimum_size = Vector2(90, 24)
	btn_clear.pressed.connect(_on_clear_key_pressed)
	_style_button(btn_clear)
	btn_row.add_child(btn_clear)

	vbox.add_child(btn_row)

	_tab_container.add_child(_tab_keyboard)


func _populate_key_tree() -> void:
	_key_tree.clear()
	var root := _key_tree.create_item()

	var actions := [
		{"name": "Вперед", "action": "cs_forward", "k1": "W", "k2": "UP"},
		{"name": "Назад", "action": "cs_back", "k1": "S", "k2": "DOWN"},
		{"name": "Шаг влево", "action": "cs_moveleft", "k1": "A", "k2": "LEFT"},
		{"name": "Шаг вправо", "action": "cs_moveright", "k1": "D", "k2": "RIGHT"},
		{"name": "Прыжок", "action": "cs_jump", "k1": "SPACE", "k2": "MWHEELUP"},
		{"name": "Пригнуться", "action": "cs_duck", "k1": "CTRL", "k2": "MWHEELDOWN"},
		{"name": "Идти (медленно)", "action": "cs_walk", "k1": "SHIFT", "k2": ""},
		{"name": "Использовать", "action": "cs_use", "k1": "E", "k2": ""},
		{"name": "Перезапуск / Спавн", "action": "cs_respawn", "k1": "R", "k2": ""},
		{"name": "Полет (Noclip)", "action": "cs_noclip", "k1": "V", "k2": ""},
	]

	for item in actions:
		var row := _key_tree.create_item(root)
		row.set_text(0, item["name"])
		row.set_metadata(0, item["action"])
		row.set_text(1, item["k1"])
		row.set_text(2, item["k2"])
		row.set_custom_color(0, Color(0.0, 0.8, 1.0))
		row.set_custom_color(1, Color(0.0, 0.7, 0.95))
		row.set_custom_color(2, Color(0.0, 0.7, 0.95))


func _create_tab_mouse() -> void:
	_tab_mouse = MarginContainer.new()
	_tab_mouse.name = "Мышь"
	_tab_mouse.add_theme_constant_override("margin_left", 16)
	_tab_mouse.add_theme_constant_override("margin_top", 16)
	_tab_mouse.add_theme_constant_override("margin_right", 16)
	_tab_mouse.add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_tab_mouse.add_child(vbox)

	var header := Label.new()
	header.text = "Параметры мыши:"
	if _font_bold:
		header.add_theme_font_override("font", _font_bold)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(header)

	# Sensitivity slider + line edit
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 12)
	var sens_lbl := Label.new()
	sens_lbl.text = "Чувствительность мыши (sensitivity):"
	_style_label(sens_lbl)
	sens_row.add_child(sens_lbl)

	_slider_sens = HSlider.new()
	_slider_sens.min_value = 0.2
	_slider_sens.max_value = 10.0
	_slider_sens.step = 0.1
	_slider_sens.value = 2.5
	_slider_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_sens.value_changed.connect(func(v: float): _lbl_sens_val.text = "%.1f" % v)
	sens_row.add_child(_slider_sens)

	_lbl_sens_val = LineEdit.new()
	_lbl_sens_val.text = "2.5"
	_lbl_sens_val.custom_minimum_size = Vector2(50, 24)
	_lbl_sens_val.text_submitted.connect(func(txt: String):
		var v := txt.to_float()
		if v > 0.0:
			_slider_sens.value = v
	)
	sens_row.add_child(_lbl_sens_val)
	vbox.add_child(sens_row)

	# Invert mouse
	_chk_invert_mouse = CheckBox.new()
	_chk_invert_mouse.text = " Инвертировать мышь по вертикали (m_pitch < 0)"
	_style_checkbox(_chk_invert_mouse)
	vbox.add_child(_chk_invert_mouse)

	_tab_container.add_child(_tab_mouse)


func _create_tab_video() -> void:
	_tab_video = MarginContainer.new()
	_tab_video.name = "Видео"
	_tab_video.add_theme_constant_override("margin_left", 16)
	_tab_video.add_theme_constant_override("margin_top", 16)
	_tab_video.add_theme_constant_override("margin_right", 16)
	_tab_video.add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_tab_video.add_child(vbox)

	var header := Label.new()
	header.text = "Параметры графики:"
	if _font_bold:
		header.add_theme_font_override("font", _font_bold)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(header)

	_chk_fullscreen = CheckBox.new()
	_chk_fullscreen.text = " Полноэкранный режим (Fullscreen)"
	_style_checkbox(_chk_fullscreen)
	vbox.add_child(_chk_fullscreen)

	# FOV slider
	var fov_row := HBoxContainer.new()
	fov_row.add_theme_constant_override("separation", 12)
	var fov_lbl := Label.new()
	fov_lbl.text = "Поле зрения (FOV):"
	_style_label(fov_lbl)
	fov_row.add_child(fov_lbl)

	_slider_fov = HSlider.new()
	_slider_fov.min_value = 60.0
	_slider_fov.max_value = 100.0
	_slider_fov.step = 1.0
	_slider_fov.value = 73.74
	_slider_fov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_fov.value_changed.connect(func(v: float): _lbl_fov_val.text = "%d°" % int(v))
	fov_row.add_child(_slider_fov)

	_lbl_fov_val = Label.new()
	_lbl_fov_val.text = "74°"
	_lbl_fov_val.custom_minimum_size = Vector2(40, 0)
	_style_label(_lbl_fov_val)
	fov_row.add_child(_lbl_fov_val)
	vbox.add_child(fov_row)

	# FPS Max
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 12)
	var fps_lbl := Label.new()
	fps_lbl.text = "Ограничение FPS (fps_max):"
	_style_label(fps_lbl)
	fps_row.add_child(fps_lbl)

	_opt_fps = OptionButton.new()
	_opt_fps.add_item("60 FPS", 60)
	_opt_fps.add_item("100 FPS (Classic GoldSrc)", 100)
	_opt_fps.add_item("144 FPS", 144)
	_opt_fps.add_item("240 FPS", 240)
	_opt_fps.add_item("Без ограничений (0)", 0)
	_opt_fps.select(1)
	fps_row.add_child(_opt_fps)
	vbox.add_child(fps_row)

	_tab_container.add_child(_tab_video)


func _create_tab_audio() -> void:
	_tab_audio = MarginContainer.new()
	_tab_audio.name = "Аудио"
	_tab_audio.add_theme_constant_override("margin_left", 16)
	_tab_audio.add_theme_constant_override("margin_top", 16)
	_tab_audio.add_theme_constant_override("margin_right", 16)
	_tab_audio.add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_tab_audio.add_child(vbox)

	var header := Label.new()
	header.text = "Параметры звука:"
	if _font_bold:
		header.add_theme_font_override("font", _font_bold)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(header)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	var vol_lbl := Label.new()
	vol_lbl.text = "Общая громкость:"
	_style_label(vol_lbl)
	vol_row.add_child(vol_lbl)

	_slider_vol = HSlider.new()
	_slider_vol.min_value = 0.0
	_slider_vol.max_value = 1.0
	_slider_vol.step = 0.05
	_slider_vol.value = 1.0
	_slider_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_vol.value_changed.connect(func(v: float): _lbl_vol_val.text = "%d%%" % int(v * 100))
	vol_row.add_child(_slider_vol)

	_lbl_vol_val = Label.new()
	_lbl_vol_val.text = "100%"
	_lbl_vol_val.custom_minimum_size = Vector2(45, 0)
	_style_label(_lbl_vol_val)
	vol_row.add_child(_lbl_vol_val)
	vbox.add_child(vol_row)

	_tab_container.add_child(_tab_audio)


# =============================================================================
# KEYBIND PROMPT MODAL
# =============================================================================

func _create_key_prompt() -> void:
	_key_prompt_panel = PanelContainer.new()
	_key_prompt_panel.visible = false
	_key_prompt_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dark_overlay := StyleBoxFlat.new()
	dark_overlay.bg_color = Color(0, 0, 0, 0.65)
	_key_prompt_panel.add_theme_stylebox_override("panel", dark_overlay)

	var center := CenterContainer.new()
	_key_prompt_panel.add_child(center)

	var box := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.12, 0.15, 0.19)
	box_style.border_color = Color(0.0, 0.8, 1.0)
	box_style.set_border_width_all(2)
	box_style.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", box_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "Нажмите любую клавишу для назначения...\n(Нажмите ESC для отмены)"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(prompt_lbl)
	vbox.add_child(prompt_lbl)

	center.add_child(box)
	add_child(_key_prompt_panel)


func _on_edit_key_pressed() -> void:
	var item := _key_tree.get_selected()
	if not item:
		return
	_selected_action = item.get_metadata(0)
	_waiting_for_key = true
	_key_prompt_panel.visible = true


func _on_clear_key_pressed() -> void:
	var item := _key_tree.get_selected()
	if not item:
		return
	item.set_text(1, "")
	item.set_text(2, "")


func _input(event: InputEvent) -> void:
	if not _waiting_for_key:
		return

	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_waiting_for_key = false
			_key_prompt_panel.visible = false
			return

		var key_str := OS.get_keycode_string(event.keycode).to_upper()
		var item := _key_tree.get_selected()
		if item:
			item.set_text(1, key_str)
		_waiting_for_key = false
		_key_prompt_panel.visible = false


# =============================================================================
# VALUES LOAD / SAVE / APPLY
# =============================================================================

func _load_current_values() -> void:
	if not _sm:
		return

	_chk_fall_damage.button_pressed = _sm.fall_damage_enabled
	_chk_auto_bhop.button_pressed = _sm.auto_bhop
	_chk_speed_cap.button_pressed = _sm.bhop_speed_cap
	_chk_jump_stamina.button_pressed = _sm.jump_stamina
	_spin_gravity.value = _sm.sv_gravity

	_slider_sens.value = _sm.sensitivity
	_lbl_sens_val.text = "%.1f" % _sm.sensitivity
	_chk_invert_mouse.button_pressed = _sm.invert_mouse

	_chk_fullscreen.button_pressed = _sm.fullscreen
	_slider_fov.value = _sm.fov
	_lbl_fov_val.text = "%d°" % int(_sm.fov)

	for i in range(_opt_fps.item_count):
		if _opt_fps.get_item_id(i) == _sm.fps_max:
			_opt_fps.select(i)
			break

	_slider_vol.value = _sm.master_volume
	_lbl_vol_val.text = "%d%%" % int(_sm.master_volume * 100)


func _apply_to_manager() -> void:
	if not _sm:
		return

	_sm.fall_damage_enabled = _chk_fall_damage.button_pressed
	_sm.auto_bhop = _chk_auto_bhop.button_pressed
	_sm.bhop_speed_cap = _chk_speed_cap.button_pressed
	_sm.jump_stamina = _chk_jump_stamina.button_pressed
	_sm.sv_gravity = _spin_gravity.value

	_sm.sensitivity = _slider_sens.value
	_sm.invert_mouse = _chk_invert_mouse.button_pressed

	_sm.fullscreen = _chk_fullscreen.button_pressed
	_sm.fov = _slider_fov.value
	_sm.fps_max = _opt_fps.get_selected_id()

	_sm.master_volume = _slider_vol.value

	_sm.apply_all_settings()
	_sm.save_settings()


func _on_ok_pressed() -> void:
	_play_click_sound()
	_apply_to_manager()
	closed.emit()
	visible = false


func _on_cancel_pressed() -> void:
	_play_click_sound()
	_load_current_values()
	closed.emit()
	visible = false


func _on_apply_pressed() -> void:
	_play_click_sound()
	_apply_to_manager()


func _on_defaults_pressed() -> void:
	_play_click_sound()
	if _sm:
		_sm.reset_to_defaults()
		_load_current_values()


func _play_click_sound() -> void:
	var ap := AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		ap.stream = load("res://audio/ui_click.wav")
	add_child(ap)
	ap.finished.connect(ap.queue_free)
	ap.play()


# =============================================================================
# STYLING HELPERS
# =============================================================================

func _style_button(btn: Button) -> void:
	if _font_regular:
		btn.add_theme_font_override("font", _font_regular)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.6, 0.8))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.18, 0.23)
	normal.border_color = Color(0.25, 0.35, 0.45)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.25, 0.32)
	hover.border_color = Color(0.0, 0.8, 1.0)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(4)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.12, 0.16)
	pressed.border_color = Color(0.0, 0.5, 0.8)
	pressed.set_border_width_all(1)
	pressed.set_content_margin_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_label(lbl: Label) -> void:
	if _font_regular:
		lbl.add_theme_font_override("font", _font_regular)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	lbl.add_theme_font_size_override("font_size", 12)


func _style_checkbox(chk: CheckBox) -> void:
	if _font_regular:
		chk.add_theme_font_override("font", _font_regular)
	chk.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	chk.add_theme_color_override("font_hover_color", Color(0.0, 0.85, 1.0))
	chk.add_theme_font_size_override("font_size", 12)


func _style_tab_container(tc: TabContainer) -> void:
	if _font_regular:
		tc.add_theme_font_override("font", _font_regular)
	tc.add_theme_font_size_override("font_size", 12)
	tc.add_theme_color_override("font_selected_color", Color(0.0, 0.85, 1.0))
	tc.add_theme_color_override("font_unselected_color", Color(0.55, 0.65, 0.75))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.13, 0.17)
	panel_style.border_color = Color(0.22, 0.30, 0.38)
	panel_style.set_border_width_all(1)
	tc.add_theme_stylebox_override("panel", panel_style)


func _style_tree(tree: Tree) -> void:
	if _font_regular:
		tree.add_theme_font_override("font", _font_regular)
	tree.add_theme_font_size_override("font_size", 12)
	tree.add_theme_font_size_override("title_button_font_size", 12)
	tree.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	tree.add_theme_color_override("title_button_color", Color(0.0, 0.85, 1.0))

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.09, 0.12)
	bg.border_color = Color(0.2, 0.28, 0.35)
	bg.set_border_width_all(1)
	tree.add_theme_stylebox_override("panel", bg)
