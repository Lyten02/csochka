extends Node
## Global settings manager for CS 1.6:
## Stores and persists gameplay (fall damage, bhop, stamina), mouse, video, audio, and keybindings.

signal settings_changed(key: String, value: Variant)

const CONFIG_PATH := "user://cs16_settings.cfg"

# --- Gameplay / Physics ---
var fall_damage_enabled: bool = true
var auto_bhop: bool = false
var bhop_speed_cap: bool = true
var jump_stamina: bool = true
var sv_gravity: float = 800.0

# --- Mouse ---
var sensitivity: float = 2.5
var m_pitch: float = 0.022
var m_yaw: float = 0.022
var invert_mouse: bool = false

# --- Video ---
var fullscreen: bool = false
var fov: float = 73.74  # Vertical FOV equivalent to 90 horizontal 4:3
var fps_max: int = 100

# --- Audio ---
var master_volume: float = 1.0

# --- Map State ---
var current_map_name: String = "35hp_3"
var current_map_bsp: String = "res://maps/35hp_3.bsp"
var current_map_glb: String = "res://maps/35hp_3.glb"

# --- Speedrun / Kreedz Records ---
var best_map_times: Dictionary = {}  # map_name (String) -> best_time_in_seconds (float)

# --- Weapon / Knife State ---
var current_knife_id: String = "knife_default"
var current_knife_model: String = "res://models/knife.glb"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()


func get_available_maps() -> Array[Dictionary]:
	var maps: Array[Dictionary] = []
	var dir := DirAccess.open("res://maps")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".bsp"):
				var base_name := file_name.trim_suffix(".bsp")
				var glb_path := "res://maps/%s.glb" % base_name
				var desc := "Классическая карта CS 1.6"
				var details := "• Физика: GoldSrc PMove\n• Коллизия: GoldSrc BSP Clip Hulls"
				var category := "bhop" if base_name.to_lower().contains("bhop") else ("kz" if (base_name.to_lower().begins_with("kz") or base_name.to_lower().begins_with("bkz")) else "other")
				if base_name == "35hp_3":
					category = "other"
					desc = "Классическая арена 35HP (бой на ножах, прыжки через мост)"
					details = "• Физика: GoldSrc PMove\n• Коллизия: GoldSrc BSP Clip Hulls\n• Спавны: CT / T команды\n• Триггеры: Телепорты в пропасти"
				elif base_name == "bkz_goldbhop":
					category = "kz"
					desc = "Легендарная Kreedz / Bhop карта (прыжки по золотым блокам)"
					details = "• Режим: Kreedz Climbing (KZ)\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Цель: Пройти полосу препятствий до вершины"
				elif base_name == "bkz_noob":
					category = "kz"
					desc = "Классическая обучающая KZ карта (bkz_noob)"
					details = "• Режим: Kreedz Climbing (KZ)\n• Физика: GoldSrc PMove\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении в пропасть"
				elif base_name == "kzy_juhxbhop":
					category = "kz"
					desc = "Динамичная Kreedz / Bhop карта (kzy_juhxbhop)"
					details = "• Режим: Kreedz / Bhop\n• Физика: GoldSrc PMove\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении и долгом стоянии"
				elif base_name == "kzru_airway":
					category = "kz"
					desc = "Легендарная высотная Kreedz карта (kzru_airway)"
					details = "• Режим: Kreedz Climbing (KZ)\n• Физика: GoldSrc PMove\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении в пропасть"
				elif base_name == "kzsca_toonbhop":
					category = "kz"
					desc = "Красочная мультяшная Kreedz / Bhop карта (kzsca_toonbhop)"
					details = "• Режим: Kreedz / Bhop\n• Физика: GoldSrc PMove\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении и долгом стоянии"
				elif base_name == "bhop_training_final":
					category = "bhop"
					desc = "Тренировочная Bhop карта (bhop_training_final)"
					details = "• Режим: Bunnyhop Training\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Блоки: Авто-телепорт при долгом стоянии"
				elif base_name == "bhop_dea":
					category = "bhop"
					desc = "Динамичная Bhop карта над водой (bhop_dea)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении в воду/на землю и долгом стоянии"
				elif base_name == "bhop_rabiga":
					category = "bhop"
					desc = "Классическая скоростная Bhop карта (bhop_rabiga)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_run_1":
					category = "bhop"
					desc = "Популярный длинный Bhop забег (bhop_run_1)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_squareblock":
					category = "bhop"
					desc = "Техничная карта с квадратными блоками (bhop_squareblock)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_tk_speedrun":
					category = "bhop"
					desc = "Скоростная Bhop карта для спидрана (bhop_tk_speedrun)"
					details = "• Режим: Bunnyhop Speedrun\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_ytt_neon_light":
					category = "bhop"
					desc = "Атмосферный Bhop ран в неоновом стиле (bhop_ytt_neon_light)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_train":
					category = "bhop"
					desc = "Bhop карта на железнодорожных путях (bhop_train)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				elif base_name == "bhop_blocks":
					category = "bhop"
					desc = "Классическая Bhop полоса с летающими блоками (bhop_blocks)"
					details = "• Режим: Bunnyhop\n• Физика: GoldSrc PMove (KZ / Bhop)\n• Таймер: Кнопки старта и финиша ('E')\n• Телепорт: Авто-возврат при падении на землю и долгом стоянии"
				maps.append({
					"id": base_name,
					"name": base_name,
					"category": category,
					"bsp": "res://maps/%s" % file_name,
					"glb": glb_path if ResourceLoader.exists(glb_path) else "",
					"desc": desc,
					"details": details,
				})
			file_name = dir.get_next()
	if maps.is_empty():
		maps.append({
			"id": "35hp_3",
			"name": "35hp_3",
			"bsp": "res://maps/35hp_3.bsp",
			"glb": "res://maps/35hp_3.glb",
			"desc": "Классическая арена 35HP (бой на ножах, прыжки через мост)",
			"details": "• Физика: GoldSrc PMove\n• Коллизия: GoldSrc BSP Clip Hulls\n• Спавны: CT / T команды\n• Триггеры: Телепорты в пропасти",
		})
	return maps


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		return

	fall_damage_enabled = cfg.get_value("gameplay", "fall_damage", true)
	auto_bhop = cfg.get_value("gameplay", "auto_bhop", false)
	bhop_speed_cap = cfg.get_value("gameplay", "bhop_speed_cap", true)
	jump_stamina = cfg.get_value("gameplay", "jump_stamina", true)
	sv_gravity = cfg.get_value("gameplay", "sv_gravity", 800.0)

	sensitivity = cfg.get_value("mouse", "sensitivity", 2.5)
	invert_mouse = cfg.get_value("mouse", "invert_mouse", false)
	m_pitch = cfg.get_value("mouse", "m_pitch", 0.022)
	m_yaw = cfg.get_value("mouse", "m_yaw", 0.022)

	fullscreen = cfg.get_value("video", "fullscreen", false)
	fov = cfg.get_value("video", "fov", 73.74)
	fps_max = cfg.get_value("video", "fps_max", 100)

	master_volume = cfg.get_value("audio", "volume", 1.0)
	current_map_name = cfg.get_value("map", "current_map", "35hp_3")
	current_map_bsp = cfg.get_value("map", "current_map_bsp", "res://maps/%s.bsp" % current_map_name)
	current_map_glb = cfg.get_value("map", "current_map_glb", "res://maps/%s.glb" % current_map_name)
	best_map_times = cfg.get_value("records", "best_map_times", {})
	current_knife_id = cfg.get_value("knife", "current_knife", "knife_default")
	current_knife_model = get_current_knife_model()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "fall_damage", fall_damage_enabled)
	cfg.set_value("gameplay", "auto_bhop", auto_bhop)
	cfg.set_value("gameplay", "bhop_speed_cap", bhop_speed_cap)
	cfg.set_value("gameplay", "jump_stamina", jump_stamina)
	cfg.set_value("gameplay", "sv_gravity", sv_gravity)

	cfg.set_value("mouse", "sensitivity", sensitivity)
	cfg.set_value("mouse", "invert_mouse", invert_mouse)
	cfg.set_value("mouse", "m_pitch", m_pitch)
	cfg.set_value("mouse", "m_yaw", m_yaw)

	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "fps_max", fps_max)

	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("map", "current_map", current_map_name)
	cfg.set_value("map", "current_map_bsp", current_map_bsp)
	cfg.set_value("map", "current_map_glb", current_map_glb)
	cfg.set_value("records", "best_map_times", best_map_times)
	cfg.set_value("knife", "current_knife", current_knife_id)

	cfg.save(CONFIG_PATH)


func get_available_knives(catalog_path: String = "res://models/knives/catalog.json") -> Array[Dictionary]:
	var knives: Array[Dictionary] = [
		{
			"id": "knife_default",
			"name": "Frozen Knife (Ледяной нож)",
			"model": "res://models/knife.glb",
			"desc": "Легендарный нож CS 1.6 с морозно-голубым свечением лезвия (Frozen Blue).",
			"details": "• Скин: Frozen / Ice Blue\n• Разрешение: 512x512 High-Res\n• Анимации: Полный набор GoldSrc (8 анимаций)\n• Перчатки: Классические перчатки спецназа",
			"icon": "res://models/knife_default_thumb.png",
		},
		{
			"id": "knife_black",
			"name": "Black Night (Тёмный нож)",
			"model": "res://models/knife_black.glb",
			"desc": "Стильный черный тактический нож с белыми акцентами и огненным узором лезвия.",
			"details": "• Скин: Black Night / Obsidian Flame\n• Разрешение: 512x512 High-Res\n• Анимации: Полный набор GoldSrc (8 анимаций)\n• Перчатки: Черная тактическая перфорированная кожа",
			"icon": "res://models/knife_black_thumb.png",
		},
	]
	for builtin in knives:
		builtin["category"] = "no_inspect"
		builtin["inspect_anim"] = null
		builtin["anims"] = {}
		builtin["source_slug"] = ""
	if FileAccess.file_exists(catalog_path):
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if entries is Array:
			var ids := {"knife_default": true, "knife_black": true}
			for entry in entries:
				if not _valid_knife_entry(entry) or ids.has(entry["id"]):
					push_warning("Ignoring invalid or duplicate knife catalog entry")
					continue
				ids[entry["id"]] = true
				knives.append(entry)
	return knives


func get_current_knife_info() -> Dictionary:
	var knives := get_available_knives()
	for k in knives:
		if k["id"] == current_knife_id:
			return k
	current_knife_id = "knife_default"
	return knives[0]


func get_current_knife_model() -> String:
	return get_current_knife_info()["model"]


func _valid_knife_entry(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	for field in ["id", "name", "model", "icon", "desc", "details", "category", "source_slug"]:
		if not entry.get(field) is String:
			return false
	if entry["source_slug"].is_empty() or entry["id"] != "cs16forge_" + entry["source_slug"]:
		return false
	if entry["name"].is_empty() or not entry["model"].begins_with("res://"):
		return false
	if not entry.has("inspect_anim") or not entry.get("anims") is Dictionary:
		return false
	if entry["category"] == "inspect":
		if not entry["inspect_anim"] is String or entry["inspect_anim"].is_empty():
			return false
	elif entry["category"] != "no_inspect" or entry["inspect_anim"] != null:
		return false
	for role in ["idle", "draw", "slash1", "slash2", "midslash1", "midslash2", "stab", "stab_miss"]:
		if not entry["anims"].get(role) is String or entry["anims"][role].is_empty():
			return false
	return true


func set_current_knife(knife_id: String) -> void:
	current_knife_id = knife_id
	current_knife_model = get_current_knife_model()
	save_settings()
	settings_changed.emit("knife", current_knife_id)


func get_best_time(map_name: String) -> float:
	return float(best_map_times.get(map_name, -1.0))


func set_best_time(map_name: String, time_sec: float) -> bool:
	var prev: float = float(best_map_times.get(map_name, -1.0))
	if prev <= 0.0 or time_sec < prev:
		best_map_times[map_name] = time_sec
		save_settings()
		settings_changed.emit("best_time", {map_name: time_sec})
		return true
	return false


func apply_all_settings() -> void:
	# Video window mode
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# FPS Max
	Engine.max_fps = fps_max if fps_max > 0 else 0

	# Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

	settings_changed.emit("all", null)


func reset_to_defaults() -> void:
	fall_damage_enabled = true
	auto_bhop = false
	bhop_speed_cap = true
	jump_stamina = true
	sv_gravity = 800.0
	sensitivity = 2.5
	invert_mouse = false
	m_pitch = 0.022
	m_yaw = 0.022
	fullscreen = false
	fov = 73.74
	fps_max = 100
	master_volume = 1.0
	apply_all_settings()
	save_settings()
