class_name CSKnifeSelectDialog
extends PanelContainer
## CS 1.6 "Инвентарь — Выбор ножа" Dialog
## Displays available knife models, preview thumbnails, details, and equips the chosen model.

signal knife_selected(knife_info: Dictionary)
signal closed

var _sm: Node
var _knife_list: ItemList
var _preview_rect: TextureRect
var _lbl_knife_name: Label
var _lbl_knife_desc: Label
var _lbl_knife_details: Label
var _lbl_knife_status: Label
var _btn_select: Button
var _btn_cancel: Button

var _available_knives: Array[Dictionary] = []
var _selected_index := 0

var _font_regular: Font
var _font_bold: Font


func _ready() -> void:
	add_to_group("knife_input_blockers")
	_sm = get_node_or_null("/root/SettingsManager")
	_load_fonts()
	_build_ui()
	_refresh_knives()
	visibility_changed.connect(func():
		if visible:
			_refresh_knives()
	)


func _load_fonts() -> void:
	if ResourceLoader.exists("res://ui/fonts/tahoma.ttf"):
		_font_regular = load("res://ui/fonts/tahoma.ttf")
	if ResourceLoader.exists("res://ui/fonts/tahomabd.ttf"):
		_font_bold = load("res://ui/fonts/tahomabd.ttf")


func _build_ui() -> void:
	custom_minimum_size = Vector2(900, 540)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.14, 0.98)
	style.border_color = Color(0.24, 0.32, 0.40)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
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
	title_style.set_content_margin_all(6)
	title_panel.add_theme_stylebox_override("panel", title_style)

	var title_inner := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "  Инвентарь — Выбор ножа"
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

	# Left Column: Knife List
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(400, 0)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	split_hbox.add_child(left_vbox)

	var list_header := Label.new()
	list_header.text = "Доступные модели ножей:"
	if _font_bold:
		list_header.add_theme_font_override("font", _font_bold)
	list_header.add_theme_font_size_override("font_size", 12)
	list_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	left_vbox.add_child(list_header)

	_knife_list = ItemList.new()
	_knife_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_knife_list.select_mode = ItemList.SELECT_SINGLE
	_knife_list.allow_reselect = true
	_knife_list.fixed_icon_size = Vector2i(54, 27)
	_knife_list.auto_height = false
	_knife_list.max_columns = 1
	if _font_regular:
		_knife_list.add_theme_font_override("font", _font_regular)
	_knife_list.add_theme_font_size_override("font_size", 12)
	_knife_list.item_selected.connect(_on_knife_item_selected)

	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.06, 0.08, 0.10, 0.9)
	list_style.border_color = Color(0.18, 0.24, 0.30)
	list_style.set_border_width_all(1)
	list_style.set_corner_radius_all(2)
	_knife_list.add_theme_stylebox_override("panel", list_style)
	left_vbox.add_child(_knife_list)

	# Right Column: Knife Preview & Description
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(detail_scroll)
	detail_scroll.add_child(right_vbox)

	# Preview Card Panel
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 140)
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = Color(0.05, 0.07, 0.09, 0.95)
	prev_style.border_color = Color(0.2, 0.3, 0.4)
	prev_style.set_border_width_all(1)
	prev_style.set_corner_radius_all(3)
	preview_panel.add_theme_stylebox_override("panel", prev_style)
	right_vbox.add_child(preview_panel)

	_preview_rect = TextureRect.new()
	_preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(_preview_rect)

	# Details
	_lbl_knife_name = Label.new()
	_lbl_knife_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_bold:
		_lbl_knife_name.add_theme_font_override("font", _font_bold)
	_lbl_knife_name.add_theme_font_size_override("font_size", 16)
	_lbl_knife_name.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	right_vbox.add_child(_lbl_knife_name)

	_lbl_knife_status = Label.new()
	_lbl_knife_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_bold:
		_lbl_knife_status.add_theme_font_override("font", _font_bold)
	_lbl_knife_status.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(_lbl_knife_status)

	_lbl_knife_desc = Label.new()
	_lbl_knife_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_regular:
		_lbl_knife_desc.add_theme_font_override("font", _font_regular)
	_lbl_knife_desc.add_theme_font_size_override("font_size", 12)
	_lbl_knife_desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	right_vbox.add_child(_lbl_knife_desc)

	_lbl_knife_details = Label.new()
	_lbl_knife_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_regular:
		_lbl_knife_details.add_theme_font_override("font", _font_regular)
	_lbl_knife_details.add_theme_font_size_override("font_size", 11)
	_lbl_knife_details.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
	right_vbox.add_child(_lbl_knife_details)

	# --- Bottom Button Bar ---
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(btn_hbox)

	_btn_select = Button.new()
	_btn_select.text = "  ЭКИПИРОВАТЬ НОЖ  "
	_btn_select.custom_minimum_size = Vector2(160, 28)
	_btn_select.pressed.connect(_on_select_pressed)
	_style_primary_button(_btn_select)
	btn_hbox.add_child(_btn_select)

	_btn_cancel = Button.new()
	_btn_cancel.text = "  ЗАКРЫТЬ  "
	_btn_cancel.custom_minimum_size = Vector2(90, 28)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_style_button(_btn_cancel)
	btn_hbox.add_child(_btn_cancel)


func _refresh_knives() -> void:
	if not _sm:
		_sm = get_node_or_null("/root/SettingsManager")
	if not _sm:
		return

	_available_knives = _sm.get_available_knives()
	_knife_list.clear()

	var cur_id: String = _sm.current_knife_id
	var select_idx := 0

	for i in range(_available_knives.size()):
		var k := _available_knives[i]
		var icon_tex: Texture2D = null
		if k.has("icon") and ResourceLoader.exists(k["icon"]):
			icon_tex = load(k["icon"])

		var inspect_hint := "Осмотр: F" if k.get("inspect_anim") != null else "без осмотра"
		_knife_list.add_item(" %s — %s" % [inspect_hint, k["name"]], icon_tex)
		_knife_list.set_item_tooltip(i, "%s\n%s" % [k["name"], inspect_hint])
		if k["id"] == cur_id:
			select_idx = i

	if _available_knives.size() > 0:
		_selected_index = select_idx
		_knife_list.select(_selected_index)
		_knife_list.ensure_current_is_visible()
		_display_knife(_selected_index)


func _on_knife_item_selected(index: int) -> void:
	_selected_index = index
	_display_knife(index)


func _display_knife(index: int) -> void:
	if index < 0 or index >= _available_knives.size():
		return
	var k: Dictionary = _available_knives[index]
	_lbl_knife_name.text = k.get("name", "")
	_lbl_knife_desc.text = k.get("desc", "")
	var inspect_hint := "Осмотр: F" if k.get("inspect_anim") != null else "Осмотр недоступен для этого ножа (без осмотра)"
	_lbl_knife_details.text = inspect_hint + "\n\n" + k.get("details", "")

	if k.has("icon") and ResourceLoader.exists(k["icon"]):
		_preview_rect.texture = load(k["icon"])
	else:
		_preview_rect.texture = null

	var is_current: bool = (_sm and _sm.current_knife_id == k["id"])
	if is_current:
		_lbl_knife_status.text = "● ЭКИПИРОВАНО В ИГРЕ"
		_lbl_knife_status.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
		_btn_select.text = "  УЖЕ ЭКИПИРОВАН  "
		_btn_select.disabled = true
	else:
		_lbl_knife_status.text = "○ В РЕЗЕРВЕ (НАЖМИТЕ ЭКИПИРОВАТЬ)"
		_lbl_knife_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		_btn_select.text = "  ЭКИПИРОВАТЬ НОЖ  "
		_btn_select.disabled = false


func _on_select_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _available_knives.size():
		return
	var chosen: Dictionary = _available_knives[_selected_index]
	if _sm:
		_sm.set_current_knife(chosen["id"])
	_display_knife(_selected_index)
	knife_selected.emit(chosen)


func _on_cancel_pressed() -> void:
	visible = false
	closed.emit()


func _style_button(btn: Button) -> void:
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.18, 0.23)
	normal.border_color = Color(0.25, 0.32, 0.40)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.24, 0.30)
	hover.border_color = Color(0.0, 0.85, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)


func _style_primary_button(btn: Button) -> void:
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.38, 0.22)
	normal.border_color = Color(0.20, 0.75, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.50, 0.28)
	hover.border_color = Color(0.30, 0.95, 0.55)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.12, 0.15, 0.18)
	disabled.border_color = Color(0.20, 0.25, 0.30)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
