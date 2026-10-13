class_name CSMapSelectDialog
extends PanelContainer
## CS 1.6 "Создать сервер / Выбор карты" Dialog
## Lists current and future maps from res://maps/ and starts the game.
## Supports submenus / tabs: KZ, Bhop, and All.

signal map_selected(map_info: Dictionary)
signal closed

var _sm: Node
var _map_list: ItemList
var _lbl_map_name: Label
var _lbl_map_desc: Label
var _lbl_map_details: Label
var _btn_start: Button
var _btn_cancel: Button

var _btn_tab_all: Button
var _btn_tab_kz: Button
var _btn_tab_bhop: Button

var _all_maps: Array[Dictionary] = []
var _displayed_maps: Array[Dictionary] = []
var _selected_index := 0
var _current_tab: String = "kz"

var _font_regular: Font
var _font_bold: Font


func _ready() -> void:
	add_to_group("knife_input_blockers")
	_sm = get_node_or_null("/root/SettingsManager")
	_load_fonts()
	_build_ui()
	_refresh_maps()
	visibility_changed.connect(func():
		if visible:
			_refresh_maps()
	)


func _load_fonts() -> void:
	if ResourceLoader.exists("res://ui/fonts/tahoma.ttf"):
		_font_regular = load("res://ui/fonts/tahoma.ttf")
	if ResourceLoader.exists("res://ui/fonts/tahomabd.ttf"):
		_font_bold = load("res://ui/fonts/tahomabd.ttf")


func _build_ui() -> void:
	custom_minimum_size = Vector2(620, 440)

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
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# --- Title Bar ---
	var title_panel := PanelContainer.new()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.13, 0.17, 0.22, 1.0)
	title_style.set_content_margin_all(5)
	title_panel.add_theme_stylebox_override("panel", title_style)

	var title_inner := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "  Создать сервер — Выбор карты"
	if _font_bold:
		title_lbl.add_theme_font_override("font", _font_bold)
	title_lbl.add_theme_font_size_override("font_size", 13)
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

	# --- Content ---
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	content_margin.add_child(content_vbox)

	var split_hbox := HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 16)
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(split_hbox)

	# Left: Tabs & Map List
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 6)

	# Tabs / Submenus Header
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 6)

	_btn_tab_kz = Button.new()
	_btn_tab_kz.text = " KZ Maps "
	_btn_tab_kz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_tab_kz.pressed.connect(func(): _set_category("kz"))
	tabs_hbox.add_child(_btn_tab_kz)

	_btn_tab_bhop = Button.new()
	_btn_tab_bhop.text = " Bhop Maps "
	_btn_tab_bhop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_tab_bhop.pressed.connect(func(): _set_category("bhop"))
	tabs_hbox.add_child(_btn_tab_bhop)

	_btn_tab_all = Button.new()
	_btn_tab_all.text = " Все карты "
	_btn_tab_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_tab_all.pressed.connect(func(): _set_category("all"))
	tabs_hbox.add_child(_btn_tab_all)

	left_vbox.add_child(tabs_hbox)

	_map_list = ItemList.new()
	_map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_list.item_selected.connect(_on_map_selected)
	_map_list.item_activated.connect(func(_idx: int): _on_start_pressed())
	_style_item_list(_map_list)
	left_vbox.add_child(_map_list)

	split_hbox.add_child(left_vbox)

	# Right: Map Info Panel
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.2
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.07, 0.09, 0.12)
	rp_style.border_color = Color(0.2, 0.28, 0.35)
	rp_style.set_border_width_all(1)
	rp_style.set_content_margin_all(12)
	right_panel.add_theme_stylebox_override("panel", rp_style)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	_lbl_map_name = Label.new()
	_lbl_map_name.text = "Карта: 35hp_3"
	if _font_bold:
		_lbl_map_name.add_theme_font_override("font", _font_bold)
	_lbl_map_name.add_theme_font_size_override("font_size", 16)
	_lbl_map_name.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	right_vbox.add_child(_lbl_map_name)

	_lbl_map_desc = Label.new()
	_lbl_map_desc.text = "Классическая CS 1.6 арена для дуэлей на ножах."
	_lbl_map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_lbl_map_desc)
	right_vbox.add_child(_lbl_map_desc)

	_lbl_map_details = Label.new()
	_lbl_map_details.text = "• Физика: GoldSrc PMove\n• Коллизия: GoldSrc BSP Clip Hulls\n• Спавны: CT / T команды\n• Триггеры: Телепорты в пропасти"
	_lbl_map_details.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	_lbl_map_details.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(_lbl_map_details)

	var add_hint := Label.new()
	add_hint.text = "Переключайтесь между вкладками KZ и Bhop, чтобы быстро находить нужные карты. Запуск карты по двойному клику или кнопке «Начать игру»."
	add_hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	add_hint.add_theme_font_size_override("font_size", 10)
	add_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(add_hint)

	split_hbox.add_child(right_panel)

	# --- Bottom Action Bar ---
	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 10)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END

	_btn_start = Button.new()
	_btn_start.text = "Начать игру"
	_btn_start.custom_minimum_size = Vector2(110, 28)
	_btn_start.pressed.connect(_on_start_pressed)
	_style_button(_btn_start)
	bottom_bar.add_child(_btn_start)

	_btn_cancel = Button.new()
	_btn_cancel.text = "Отмена"
	_btn_cancel.custom_minimum_size = Vector2(85, 28)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_style_button(_btn_cancel)
	bottom_bar.add_child(_btn_cancel)

	content_vbox.add_child(bottom_bar)


func _set_category(cat: String) -> void:
	_play_click_sound()
	_current_tab = cat
	_update_tab_buttons()
	_filter_and_populate_list()


func _update_tab_buttons() -> void:
	_style_tab_button(_btn_tab_kz, _current_tab == "kz")
	_style_tab_button(_btn_tab_bhop, _current_tab == "bhop")
	_style_tab_button(_btn_tab_all, _current_tab == "all")


func _style_tab_button(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	if _font_bold and is_active:
		btn.add_theme_font_override("font", _font_bold)
	elif _font_regular:
		btn.add_theme_font_override("font", _font_regular)
	btn.add_theme_font_size_override("font_size", 12)

	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	if is_active:
		sb.bg_color = Color(0.18, 0.25, 0.32)
		sb.border_color = Color(0.0, 0.85, 1.0)
		btn.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	else:
		sb.bg_color = Color(0.11, 0.14, 0.18)
		sb.border_color = Color(0.20, 0.26, 0.32)
		btn.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80))
	btn.add_theme_stylebox_override("normal", sb)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.set_border_width_all(1)
	hover_sb.set_content_margin_all(5)
	hover_sb.bg_color = Color(0.22, 0.28, 0.36)
	hover_sb.border_color = Color(0.0, 0.85, 1.0) if is_active else Color(0.35, 0.45, 0.55)
	btn.add_theme_stylebox_override("hover", hover_sb)


func _refresh_maps() -> void:
	_all_maps.clear()

	if _sm == null and is_inside_tree():
		_sm = get_node_or_null("/root/SettingsManager")

	if _sm:
		_all_maps = _sm.get_available_maps()
	else:
		_all_maps.append({
			"id": "35hp_3",
			"name": "35hp_3",
			"category": "other",
			"bsp": "res://maps/35hp_3.bsp",
			"glb": "res://maps/35hp_3.glb",
			"desc": "Классическая CS 1.6 арена для дуэлей на ножах."
		})

	# Pick initial tab based on current active map if possible
	if _sm:
		var cur_name: String = str(_sm.current_map_name).to_lower()
		if cur_name.begins_with("kz") or cur_name.begins_with("bkz"):
			_current_tab = "kz"
		elif cur_name.contains("bhop"):
			_current_tab = "bhop"

	_update_tab_buttons()
	_filter_and_populate_list()


func _filter_and_populate_list() -> void:
	_displayed_maps.clear()
	_map_list.clear()

	for m in _all_maps:
		var cat: String = m.get("category", "").to_lower()
		var mname: String = m.get("name", "").to_lower()
		var matches := false
		if _current_tab == "all":
			matches = true
		elif _current_tab == "kz":
			matches = cat == "kz" or mname.begins_with("kz") or mname.begins_with("bkz")
		elif _current_tab == "bhop":
			matches = cat == "bhop" or mname.contains("bhop")

		if matches:
			_displayed_maps.append(m)

	for m in _displayed_maps:
		var tag := ""
		var cat: String = m.get("category", "")
		if cat == "kz":
			tag = "[KZ] "
		elif cat == "bhop":
			tag = "[Bhop] "
		_map_list.add_item("  %s%s" % [tag, m["name"]])

	var target_index := 0
	if _sm:
		for i in range(_displayed_maps.size()):
			if _displayed_maps[i].get("name") == _sm.current_map_name:
				target_index = i
				break

	if _displayed_maps.size() > 0:
		_map_list.select(target_index)
		_on_map_selected(target_index)
	else:
		_selected_index = -1
		_lbl_map_name.text = "Нет карт"
		_lbl_map_desc.text = "В данной категории нет доступных карт."
		_lbl_map_details.text = ""


func _on_map_selected(index: int) -> void:
	_selected_index = index
	if index >= 0 and index < _displayed_maps.size():
		var info: Dictionary = _displayed_maps[index]
		_lbl_map_name.text = "Карта: %s" % info["name"]
		_lbl_map_desc.text = info.get("desc", "")
		if info.has("details") and _lbl_map_details:
			_lbl_map_details.text = info["details"]


func _on_start_pressed() -> void:
	_play_click_sound()
	if _sm == null and is_inside_tree():
		_sm = get_node_or_null("/root/SettingsManager")
	if _selected_index >= 0 and _selected_index < _displayed_maps.size():
		var info: Dictionary = _displayed_maps[_selected_index]
		if _sm:
			_sm.current_map_name = info["name"]
			_sm.current_map_bsp = info["bsp"]
			_sm.current_map_glb = info.get("glb", "")
			_sm.save_settings()
		map_selected.emit(info)
	visible = false


func _on_cancel_pressed() -> void:
	_play_click_sound()
	closed.emit()
	visible = false


func _play_click_sound() -> void:
	var ap := AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		ap.stream = load("res://audio/ui_click.wav")
	add_child(ap)
	ap.finished.connect(ap.queue_free)
	ap.play()


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

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)


func _style_label(lbl: Label) -> void:
	if _font_regular:
		lbl.add_theme_font_override("font", _font_regular)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	lbl.add_theme_font_size_override("font_size", 12)


func _style_item_list(list: ItemList) -> void:
	if _font_regular:
		list.add_theme_font_override("font", _font_regular)
	list.add_theme_font_size_override("font_size", 12)
	list.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.09, 0.12)
	bg.border_color = Color(0.2, 0.28, 0.35)
	bg.set_border_width_all(1)
	list.add_theme_stylebox_override("panel", bg)
