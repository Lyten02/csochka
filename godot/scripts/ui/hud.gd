class_name CSHud
extends CanvasLayer
## CS 1.6 2015 Newstyle HUD + Speedometer + Movement debug panel.

@export var player_path: NodePath

var _player: CSPlayer

# Digit textures from 640hud7.png (digits 0..9)
var _digit_rects := [
	Rect2(1, 0, 18, 25),    # 0
	Rect2(27, 0, 15, 25),   # 1
	Rect2(49, 0, 21, 25),   # 2
	Rect2(72, 0, 24, 25),   # 3
	Rect2(97, 0, 17, 25),   # 4
	Rect2(121, 0, 17, 25),  # 5
	Rect2(146, 0, 17, 25),  # 6
	Rect2(172, 0, 16, 25),  # 7
	Rect2(194, 0, 17, 25),  # 8
	Rect2(218, 0, 17, 25),  # 9
]

var _hud7_tex: Texture2D

# UI Nodes
var _health_box: HBoxContainer
var _armor_box: HBoxContainer
var _crosshair: Control

var _speed: Label
var _info: Label
var _help: Label

var _damage_flash: ColorRect
var _flash_tween: Tween

var _lj_panel: PanelContainer
var _lj_header: Label
var _lj_dist_label: Label
var _lj_details1: Label
var _lj_details2: Label
var _lj_tween: Tween

var _notify_label: Label
var _notify_tween: Tween

# Kreedz / Speedrun Timer UI
var _kz_panel: PanelContainer
var _kz_header: Label
var _kz_time_label: Label
var _kz_sub_label: Label
var _use_prompt: Label
var _use_prompt_tween: Tween
var _kz_finish_panel: PanelContainer
var _kz_finish_title: Label
var _kz_finish_time: Label
var _kz_finish_record: Label
var _kz_finish_tween: Tween


func _ready() -> void:
	_player = get_node(player_path)
	_load_textures()
	_create_damage_flash()
	_create_hud_elements()
	_create_crosshair()
	_create_debug_labels()
	_create_lj_stats_ui()
	_create_kz_timer_ui()
	if _player:
		_player.health_changed.connect(_on_player_health_changed)
		_player.lj_stats_toggled.connect(_on_lj_stats_toggled)
		_player.lj_stat_recorded.connect(_on_lj_stat_recorded)
		_player.bhop_block_timeout.connect(_on_bhop_block_timeout)
		_player.kz_timer_started.connect(_on_kz_timer_started)
		_player.kz_timer_stopped.connect(_on_kz_timer_stopped)
		_player.kz_timer_reset.connect(_on_kz_timer_reset)
		_player.kz_timer_invalid_stop.connect(_on_kz_timer_invalid_stop)
		_player.kz_aimed_button_changed.connect(_on_kz_aimed_button_changed)
		_set_number(_health_box, _player.health)
		_update_kz_display_state()


func _create_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.name = "DamageFlash"
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)


func _on_player_health_changed(hp: int, dmg: int) -> void:
	_set_number(_health_box, hp)
	if dmg > 0:
		flash_damage(dmg)


func flash_damage(dmg: int) -> void:
	if not _damage_flash:
		return
	if _flash_tween:
		_flash_tween.kill()
	var intensity := clampf(float(dmg) / 100.0 * 0.45 + 0.15, 0.15, 0.6)
	_damage_flash.color = Color(0.85, 0.05, 0.05, intensity)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _load_textures() -> void:
	if ResourceLoader.exists("res://sprites/hud/640hud7.png"):
		_hud7_tex = load("res://sprites/hud/640hud7.png")


func _create_hud_elements() -> void:
	# Bottom bar container
	var bottom_panel := Control.new()
	bottom_panel.name = "BottomHUD"
	bottom_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_panel)

	# --- 1. HEALTH & ARMOR (Bottom Left) ---
	var hp_ap_container := HBoxContainer.new()
	hp_ap_container.name = "HpApContainer"
	hp_ap_container.anchor_left = 0.0
	hp_ap_container.anchor_top = 1.0
	hp_ap_container.anchor_right = 0.0
	hp_ap_container.anchor_bottom = 1.0
	hp_ap_container.offset_left = 32.0
	hp_ap_container.offset_top = -60.0
	hp_ap_container.offset_right = 360.0
	hp_ap_container.offset_bottom = -20.0
	hp_ap_container.add_theme_constant_override("separation", 35)
	hp_ap_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_panel.add_child(hp_ap_container)

	# Health: Cross icon + Digits
	var hp_group := HBoxContainer.new()
	hp_group.add_theme_constant_override("separation", 8)
	hp_ap_container.add_child(hp_group)

	if _hud7_tex:
		var cross_icon := TextureRect.new()
		var cross_at := AtlasTexture.new()
		cross_at.atlas = _hud7_tex
		cross_at.region = Rect2(223, 26, 25, 24)
		cross_icon.texture = cross_at
		cross_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		cross_icon.custom_minimum_size = Vector2(25, 25)
		hp_group.add_child(cross_icon)

	_health_box = HBoxContainer.new()
	_health_box.add_theme_constant_override("separation", 2)
	hp_group.add_child(_health_box)
	_set_number(_health_box, 100)

	# Armor: Shield icon + Digits
	var ap_group := HBoxContainer.new()
	ap_group.add_theme_constant_override("separation", 8)
	hp_ap_container.add_child(ap_group)

	if _hud7_tex:
		var armor_icon := TextureRect.new()
		var armor_at := AtlasTexture.new()
		armor_at.atlas = _hud7_tex
		armor_at.region = Rect2(50, 26, 25, 25)
		armor_icon.texture = armor_at
		armor_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		armor_icon.custom_minimum_size = Vector2(25, 25)
		ap_group.add_child(armor_icon)

	_armor_box = HBoxContainer.new()
	_armor_box.add_theme_constant_override("separation", 2)
	ap_group.add_child(_armor_box)
	_set_number(_armor_box, 100)


func _create_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	# CS 1.6 classic dynamic/semi-transparent green crosshair lines
	var color := Color(0.2, 0.95, 0.4, 0.85)
	var length := 10.0
	var thickness := 2.0
	var gap := 5.0

	var top_line := ColorRect.new()
	top_line.color = color
	top_line.position = Vector2(-thickness * 0.5, -gap - length)
	top_line.size = Vector2(thickness, length)
	_crosshair.add_child(top_line)

	var bottom_line := ColorRect.new()
	bottom_line.color = color
	bottom_line.position = Vector2(-thickness * 0.5, gap)
	bottom_line.size = Vector2(thickness, length)
	_crosshair.add_child(bottom_line)

	var left_line := ColorRect.new()
	left_line.color = color
	left_line.position = Vector2(-gap - length, -thickness * 0.5)
	left_line.size = Vector2(length, thickness)
	_crosshair.add_child(left_line)

	var right_line := ColorRect.new()
	right_line.color = color
	right_line.position = Vector2(gap, -thickness * 0.5)
	right_line.size = Vector2(length, thickness)
	_crosshair.add_child(right_line)


func _create_debug_labels() -> void:
	_speed = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_speed.anchor_left = 0.5
	_speed.anchor_right = 0.5
	_speed.anchor_top = 0.72
	_speed.anchor_bottom = 0.72
	_speed.offset_left = -200
	_speed.offset_right = 200

	_info = _label(14, HORIZONTAL_ALIGNMENT_LEFT)
	_info.position = Vector2(12, 10)

	_help = _label(14, HORIZONTAL_ALIGNMENT_RIGHT)
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = -700
	_help.offset_right = -12
	_help.offset_top = 10
	_help.text = "\n".join([
		"WASD — движение, мышь — обзор, Shift — шаг",
		"Space / колесо мыши — прыжок, Ctrl — присесть, E — use (кнопки старта/финиша)",
		"ЛКМ — удар ножом (slash), ПКМ — сильный удар (stab), F — осмотр (если доступен)",
		"R — следующий спавн, V — noclip",
		"F2 — автобхоп, F3 — лимит скорости bhop, F4 — стамина",
		"F7 — LJ Stats (измерение прыжка от 240u), F1 — скрыть инфо",
	])


func _set_number(container: HBoxContainer, value: int) -> void:
	if not _hud7_tex:
		return
	# Clear old digit nodes
	for child in container.get_children():
		child.queue_free()

	var s := str(maxi(0, value))
	for ch in s:
		var d := ch.to_int()
		if d >= 0 and d < _digit_rects.size():
			var tr := TextureRect.new()
			var at := AtlasTexture.new()
			at.atlas = _hud7_tex
			at.region = _digit_rects[d]
			tr.texture = at
			tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tr.custom_minimum_size = Vector2(at.region.size.x, at.region.size.y)
			container.add_child(tr)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cs_toggle_hud"):
		_help.visible = not _help.visible
		_info.visible = _help.visible


func _process(_delta: float) -> void:
	if _player and _player.kz_timer_active:
		if _kz_time_label:
			_kz_time_label.text = format_kz_time(_player.kz_timer_elapsed)

	var pm := _player.pm
	if pm == null:
		return
	var hspeed := pm.horizontal_speed()
	_speed.text = "%d" % roundi(hspeed)
	_speed.modulate = Color(1, 0.35, 0.3) if hspeed > pm.maxspeed * CSPlayerMove.BUNNYJUMP_MAX_SPEED_FACTOR else Color.WHITE
	if not _info.visible:
		return
	var movetype_name: String = {CSPlayerMove.MoveType.WALK: "walk", CSPlayerMove.MoveType.FLY: "ladder",
		CSPlayerMove.MoveType.NOCLIP: "noclip"}.get(pm.movetype, "?")
	var info_lines := [
		"FPS %d  |  tick %d Гц (msec %d)" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second,
			roundi(1000.0 / Engine.physics_ticks_per_second)],
		"скорость XY %.1f  Z %.1f  макс %.1f u/s" % [hspeed, pm.velocity.z, _player.max_speed_seen],
		"прыжков %d, скорость на прыжке %.1f" % [_player.jump_count, _player.last_jump_speed],
		"на земле: %s  присед: %s  hull: %s  режим: %s" % ["да" if pm.onground != -1 else "нет",
			"да" if pm.is_ducking() else ("…" if pm.in_duck else "нет"), "duck" if pm.usehull == 1 else "stand", movetype_name],
		"стамина (fuser2) %.0f мс" % pm.fuser2,
		"позиция %.1f %.1f %.1f" % [pm.origin.x, pm.origin.y, pm.origin.z],
		"углы pitch %.1f yaw %.1f" % [_player.view_angles.x, _player.view_angles.y],
		"автобхоп: %s | лимит bhop: %s | стамина: %s" % [_on(_player.auto_bhop), _on(pm.bhop_speed_cap), _on(pm.jump_stamina)],
		"LJ Stats (F7): %s | телепортов: %d | спавн #%d" % [_on(_player.lj_stats_enabled), _player.teleport_count, _player.spawn_index],
	]
	if _player.block_stand_timer > 0.0:
		info_lines.append("таймер стояния на блоке: %.2f / %.2f с" % [_player.block_stand_timer, _player.BLOCK_MAX_STAND_TIME])
	if not _player.kz_buttons.is_empty():
		var timer_state := "ИДЕТ (%s)" % format_kz_time(_player.kz_timer_elapsed) if _player.kz_timer_active else "ОСТАНОВЛЕН"
		var best_str := format_kz_time(_player.kz_best_time) if _player.kz_best_time > 0.0 else "нет"
		info_lines.append("KZ таймер: %s | Рекорд: %s" % [timer_state, best_str])
	_info.text = "\n".join(info_lines)


static func _on(v: bool) -> String:
	return "вкл" if v else "выкл"


func _create_lj_stats_ui() -> void:
	_notify_label = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_notify_label.anchor_left = 0.5
	_notify_label.anchor_right = 0.5
	_notify_label.anchor_top = 0.18
	_notify_label.anchor_bottom = 0.18
	_notify_label.offset_left = -350
	_notify_label.offset_right = 350
	_notify_label.modulate.a = 0.0

	_lj_panel = PanelContainer.new()
	_lj_panel.name = "LJStatsPanel"
	_lj_panel.anchor_left = 0.5
	_lj_panel.anchor_right = 0.5
	_lj_panel.anchor_top = 0.28
	_lj_panel.anchor_bottom = 0.28
	_lj_panel.offset_left = -230
	_lj_panel.offset_right = 230
	_lj_panel.offset_top = -65
	_lj_panel.offset_bottom = 65
	_lj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lj_panel.modulate.a = 0.0
	add_child(_lj_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.06, 0.85)
	sb.border_color = Color(0.25, 0.85, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_lj_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lj_panel.add_child(vbox)

	_lj_header = Label.new()
	_lj_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lj_header.text = "[ LONGJUMP STATS ]"
	_lj_header.add_theme_font_size_override("font_size", 13)
	_lj_header.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	_lj_header.add_theme_color_override("font_outline_color", Color.BLACK)
	_lj_header.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_lj_header)

	_lj_dist_label = Label.new()
	_lj_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lj_dist_label.text = "240.000 units"
	_lj_dist_label.add_theme_font_size_override("font_size", 28)
	_lj_dist_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_lj_dist_label.add_theme_constant_override("outline_size", 5)
	vbox.add_child(_lj_dist_label)

	_lj_details1 = Label.new()
	_lj_details1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lj_details1.text = "Pre: 275.0  |  Max: 320.0"
	_lj_details1.add_theme_font_size_override("font_size", 15)
	_lj_details1.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	_lj_details1.add_theme_color_override("font_outline_color", Color.BLACK)
	_lj_details1.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_lj_details1)

	_lj_details2 = Label.new()
	_lj_details2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lj_details2.text = "Strafes: 5  |  Sync: 82.0%"
	_lj_details2.add_theme_font_size_override("font_size", 14)
	_lj_details2.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	_lj_details2.add_theme_color_override("font_outline_color", Color.BLACK)
	_lj_details2.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_lj_details2)


func _on_lj_stats_toggled(enabled: bool) -> void:
	if enabled:
		show_notification("[LJ Stats] ВКЛЮЧЕН (показ от 240 units | F7 для выключения)", Color(0.3, 0.95, 0.4))
	else:
		show_notification("[LJ Stats] ВЫКЛЮЧЕН (F7 для включения)", Color(0.9, 0.35, 0.35))
		if _lj_panel:
			_lj_panel.modulate.a = 0.0


func _on_bhop_block_timeout() -> void:
	show_notification("[Bhop] Слишком долго стоял на блоке! Телепортация...", Color(1.0, 0.6, 0.2))


func _on_lj_stat_recorded(data: Dictionary) -> void:
	var dist: float = data.get("distance", 0.0)
	if dist < 240.0:
		return

	var pre: float = data.get("prestrafe", 0.0)
	var mx: float = data.get("maxspeed", 0.0)
	var strafes: int = data.get("strafes", 0)
	var sync: float = data.get("sync", 0.0)
	var h_diff: float = data.get("height_diff", 0.0)

	_lj_dist_label.text = "%.3f units" % dist
	_lj_details1.text = "Prestrafe: %.1f u/s  |  Maxspeed: %.1f u/s" % [pre, mx]
	var h_sign := "+" if h_diff >= 0.0 else ""
	_lj_details2.text = "Strafes: %d  |  Sync: %.1f%%  |  Высота: %s%.1f" % [strafes, sync, h_sign, h_diff]

	var col := Color("#ffd740")  # Gold (240+)
	if dist >= 254.0:
		col = Color("#e040fb")  # Godlike (254+)
	elif dist >= 250.0:
		col = Color("#ff5252")  # Red / Extreme (250+)
	elif dist >= 245.0:
		col = Color("#ff9100")  # Orange / Pro (245+)

	_lj_dist_label.add_theme_color_override("font_color", col)

	if _lj_tween:
		_lj_tween.kill()
	_lj_tween = create_tween()
	_lj_panel.modulate.a = 1.0
	_lj_tween.tween_interval(4.5)
	_lj_tween.tween_property(_lj_panel, "modulate:a", 0.0, 0.6)


func show_notification(text: String, col: Color = Color.WHITE) -> void:
	if not _notify_label:
		return
	_notify_label.text = text
	_notify_label.add_theme_color_override("font_color", col)
	if _notify_tween:
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_label.modulate.a = 1.0
	_notify_tween.tween_interval(2.2)
	_notify_tween.tween_property(_notify_label, "modulate:a", 0.0, 0.5)


func _create_kz_timer_ui() -> void:
	# 1. KZ Timer Panel (Top Center)
	_kz_panel = PanelContainer.new()
	_kz_panel.name = "KZTimerPanel"
	_kz_panel.anchor_left = 0.5
	_kz_panel.anchor_right = 0.5
	_kz_panel.anchor_top = 0.02
	_kz_panel.anchor_bottom = 0.02
	_kz_panel.offset_left = -160.0
	_kz_panel.offset_right = 160.0
	_kz_panel.offset_top = 0.0
	_kz_panel.offset_bottom = 78.0
	_kz_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kz_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.05, 0.85)
	sb.border_color = Color(0.25, 0.85, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_kz_panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kz_panel.add_child(vbox)

	_kz_header = Label.new()
	_kz_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_header.text = "[ KREEDZ TIMER ]"
	_kz_header.add_theme_font_size_override("font_size", 12)
	_kz_header.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	_kz_header.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_header.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_kz_header)

	_kz_time_label = Label.new()
	_kz_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_time_label.text = "00:00.00"
	_kz_time_label.add_theme_font_size_override("font_size", 28)
	_kz_time_label.add_theme_color_override("font_color", Color("#e0e6ed"))
	_kz_time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_time_label.add_theme_constant_override("outline_size", 5)
	vbox.add_child(_kz_time_label)

	_kz_sub_label = Label.new()
	_kz_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_sub_label.text = "Нажмите [E] на стартовой кнопке"
	_kz_sub_label.add_theme_font_size_override("font_size", 12)
	_kz_sub_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	_kz_sub_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_sub_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_kz_sub_label)

	# 2. Use Prompt (Below Crosshair)
	_use_prompt = Label.new()
	_use_prompt.name = "UsePrompt"
	_use_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_use_prompt.anchor_left = 0.5
	_use_prompt.anchor_right = 0.5
	_use_prompt.anchor_top = 0.56
	_use_prompt.anchor_bottom = 0.56
	_use_prompt.offset_left = -250.0
	_use_prompt.offset_right = 250.0
	_use_prompt.offset_top = -15.0
	_use_prompt.offset_bottom = 15.0
	_use_prompt.add_theme_font_size_override("font_size", 16)
	_use_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_use_prompt.add_theme_constant_override("outline_size", 4)
	_use_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_prompt.modulate.a = 0.0
	add_child(_use_prompt)

	# 3. Finish Celebration Banner
	_kz_finish_panel = PanelContainer.new()
	_kz_finish_panel.name = "KZFinishPanel"
	_kz_finish_panel.anchor_left = 0.5
	_kz_finish_panel.anchor_right = 0.5
	_kz_finish_panel.anchor_top = 0.35
	_kz_finish_panel.anchor_bottom = 0.35
	_kz_finish_panel.offset_left = -240.0
	_kz_finish_panel.offset_right = 240.0
	_kz_finish_panel.offset_top = -65.0
	_kz_finish_panel.offset_bottom = 65.0
	_kz_finish_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kz_finish_panel.modulate.a = 0.0
	add_child(_kz_finish_panel)

	var finish_sb := StyleBoxFlat.new()
	finish_sb.bg_color = Color(0.05, 0.08, 0.06, 0.92)
	finish_sb.border_color = Color("#ffd740")
	finish_sb.set_border_width_all(3)
	finish_sb.set_corner_radius_all(8)
	finish_sb.content_margin_left = 20
	finish_sb.content_margin_right = 20
	finish_sb.content_margin_top = 12
	finish_sb.content_margin_bottom = 12
	_kz_finish_panel.add_theme_stylebox_override("panel", finish_sb)

	var f_vbox := VBoxContainer.new()
	f_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	f_vbox.add_theme_constant_override("separation", 4)
	f_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kz_finish_panel.add_child(f_vbox)

	_kz_finish_title = Label.new()
	_kz_finish_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_finish_title.text = "🏆 КАРТА ПРОЙДЕНА!"
	_kz_finish_title.add_theme_font_size_override("font_size", 20)
	_kz_finish_title.add_theme_color_override("font_color", Color("#ffd740"))
	_kz_finish_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_finish_title.add_theme_constant_override("outline_size", 4)
	f_vbox.add_child(_kz_finish_title)

	_kz_finish_time = Label.new()
	_kz_finish_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_finish_time.text = "00:00.00"
	_kz_finish_time.add_theme_font_size_override("font_size", 30)
	_kz_finish_time.add_theme_color_override("font_color", Color("#40ff70"))
	_kz_finish_time.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_finish_time.add_theme_constant_override("outline_size", 5)
	f_vbox.add_child(_kz_finish_time)

	_kz_finish_record = Label.new()
	_kz_finish_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kz_finish_record.text = "★ Новый личный рекорд! ★"
	_kz_finish_record.add_theme_font_size_override("font_size", 14)
	_kz_finish_record.add_theme_color_override("font_color", Color("#ffd740"))
	_kz_finish_record.add_theme_color_override("font_outline_color", Color.BLACK)
	_kz_finish_record.add_theme_constant_override("outline_size", 3)
	f_vbox.add_child(_kz_finish_record)


static func format_kz_time(t: float) -> String:
	var total_cs := int(round(maxf(0.0, t) * 100.0))
	var cs := total_cs % 100
	var total_sec := total_cs / 100
	var secs := total_sec % 60
	var mins := total_sec / 60
	return "%02d:%02d.%02d" % [mins, secs, cs]


func _update_kz_display_state() -> void:
	if not _player or not _kz_panel:
		return
	if _player.kz_buttons.is_empty():
		_kz_panel.visible = false
		return
	_kz_panel.visible = true
	var map_str := ""
	if _player.bsp and _player.bsp.map_name != "":
		map_str = " | " + _player.bsp.map_name
	_kz_header.text = "[ KREEDZ TIMER%s ]" % map_str

	if _player.kz_timer_active:
		_kz_time_label.text = format_kz_time(_player.kz_timer_elapsed)
		_kz_time_label.add_theme_color_override("font_color", Color("#40ff70"))
		if _player.kz_best_time > 0.0:
			_kz_sub_label.text = "Рекорд: %s" % format_kz_time(_player.kz_best_time)
		else:
			_kz_sub_label.text = "В пути к финишу..."
	else:
		if _player.kz_best_time > 0.0:
			_kz_sub_label.text = "Рекорд карты: %s" % format_kz_time(_player.kz_best_time)
		else:
			_kz_sub_label.text = "Нажмите [E] на стартовой кнопке"


func _on_kz_timer_started() -> void:
	_update_kz_display_state()
	_kz_time_label.text = "00:00.00"
	_kz_time_label.add_theme_color_override("font_color", Color("#40ff70"))
	show_notification("[Timer] Таймер запущен! Пройдите карту до финишной кнопки.", Color(0.3, 0.95, 0.4))
	if _kz_finish_panel:
		_kz_finish_panel.modulate.a = 0.0


func _on_kz_timer_stopped(final_time: float, is_new_record: bool) -> void:
	_update_kz_display_state()
	_kz_time_label.text = format_kz_time(final_time)
	_kz_time_label.add_theme_color_override("font_color", Color("#ffd740"))

	_kz_finish_time.text = format_kz_time(final_time)
	if is_new_record:
		_kz_finish_record.text = "★ НОВЫЙ ЛИЧНЫЙ РЕКОРД! ★"
		_kz_finish_record.add_theme_color_override("font_color", Color("#ffd740"))
		show_notification("[Timer] Поздравляем! Новый рекорд: %s" % format_kz_time(final_time), Color("#ffd740"))
	else:
		_kz_finish_record.text = "Рекорд карты: %s" % format_kz_time(_player.kz_best_time)
		_kz_finish_record.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		show_notification("[Timer] Финиш! Время прохождения: %s" % format_kz_time(final_time), Color(0.4, 0.9, 0.5))

	if _kz_finish_tween:
		_kz_finish_tween.kill()
	_kz_finish_tween = create_tween()
	_kz_finish_panel.modulate.a = 1.0
	_kz_finish_tween.tween_interval(5.0)
	_kz_finish_tween.tween_property(_kz_finish_panel, "modulate:a", 0.0, 0.8)


func _on_kz_timer_reset() -> void:
	_update_kz_display_state()
	_kz_time_label.text = "00:00.00"
	_kz_time_label.add_theme_color_override("font_color", Color("#e0e6ed"))
	if _kz_finish_panel and _kz_finish_panel.modulate.a > 0.0:
		_kz_finish_panel.modulate.a = 0.0


func _on_kz_timer_invalid_stop() -> void:
	show_notification("[Timer] Сначала активируйте кнопку старта на спавне!", Color(1.0, 0.4, 0.4))


func _on_kz_aimed_button_changed(btn: Dictionary) -> void:
	if not _use_prompt:
		return
	if _use_prompt_tween:
		_use_prompt_tween.kill()

	if btn.is_empty():
		_use_prompt_tween = create_tween()
		_use_prompt_tween.tween_property(_use_prompt, "modulate:a", 0.0, 0.15)
	else:
		if btn.get("type", "") == "start":
			_use_prompt.text = "[E] Нажмите, чтобы начать таймер"
			_use_prompt.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		else:
			_use_prompt.text = "[E] Нажмите, чтобы завершить карту"
			_use_prompt.add_theme_color_override("font_color", Color("#ffd740"))
		_use_prompt_tween = create_tween()
		_use_prompt_tween.tween_property(_use_prompt, "modulate:a", 1.0, 0.15)

