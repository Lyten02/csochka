extends SceneTree
## Phase-one contract tests use temporary synthetic clips, never production substitute animations.

const Settings = preload("res://scripts/utils/settings_manager.gd")
const Knife = preload("res://scripts/weapons/cs_knife.gd")
const Player = preload("res://scripts/player/cs_player.gd")
const Dialog = preload("res://scripts/ui/knife_select_dialog.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const ROLES := ["idle", "draw", "slash1", "slash2", "midslash1", "midslash2", "stab", "stab_miss"]
const CATALOG := "user://knife_inspect_test_catalog.json"
const MODEL := "user://knife_inspect_test_model.tscn"

class FixtureSettings extends Settings:
	func get_available_knives(catalog_path: String = CATALOG) -> Array[Dictionary]:
		return super.get_available_knives(catalog_path)

# Headless DisplayServer cannot capture a pointer. Simulate only in tests;
# production never bypasses the capture requirement.
class HeadlessPlayer extends Player:
	var pointer_captured := true

	func _knife_mouse_captured() -> bool:
		return pointer_captured

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func key(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = pressed
	event.echo = echo
	return event

func make_model() -> Dictionary:
	var roles := {}
	var model := Node3D.new()
	model.name = "Model"
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.owner = model
	var library := AnimationLibrary.new()
	for role in ROLES + ["inspect"]:
		var clip := Animation.new()
		clip.length = 0.5
		# Deliberately begin with looping clips; CSKnife must configure each role.
		clip.loop_mode = Animation.LOOP_LINEAR
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, NodePath(".:position"))
		clip.track_insert_key(track, 0.0, Vector3.ZERO)
		clip.track_insert_key(track, 0.5, Vector3(0.2, 0, 0))
		library.add_animation("mapped_" + role, clip)
		roles[role] = "mapped_" + role
	anim.add_animation_library("", library)
	var scene := PackedScene.new()
	check(scene.pack(model) == OK, "pack fixture model")
	check(ResourceSaver.save(scene, MODEL) == OK, "save fixture model")
	model.free()
	roles.erase("inspect")
	return roles

func run() -> void:
	print("=== Knife catalog / inspect / 1280x720 contract tests ===")
	var roles := make_model()
	var entries: Array = []
	for i in range(20):
		entries.append({
			"id": "cs16forge_fixture_%02d" % i, "source_slug": "fixture_%02d" % i,
			"name": "Тестовый нож %02d с длинным названием" % i,
			"model": "res://models/knife.glb", "icon": "res://models/knife_default_thumb.png",
			"desc": "Описание ножа. ".repeat(20), "details": "Детали ножа.\n".repeat(30),
			"category": "inspect" if i < 10 else "no_inspect",
			"inspect_anim": "mapped_inspect" if i < 10 else null, "anims": roles,
		})
	var file := FileAccess.open(CATALOG, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	await process_frame
	var settings := FixtureSettings.new()
	var catalog := settings.get_available_knives()
	check(catalog.size() == 22, "two built-ins + twenty JSON entries")
	var ids := {}
	var inspect_count := 0
	for entry in catalog:
		check(not ids.has(entry["id"]), "unique catalog id")
		ids[entry["id"]] = true
		if entry.get("inspect_anim") != null:
			inspect_count += 1
	check(inspect_count == 10, "ten inspect and twelve unsupported knives")
	check(catalog[0]["model"] == "res://models/knife.glb", "default unchanged")
	check(catalog[1]["model"] == "res://models/knife_black.glb", "black unchanged")
	settings.current_knife_id = "removed_knife"
	check(settings.get_current_knife_model() == "res://models/knife.glb", "unknown saved selection falls back")
	check(settings.current_knife_id == "knife_default", "fallback normalizes selected id")
	settings.current_knife_id = entries[0]["id"]
	check(settings.get_current_knife_info()["id"] == entries[0]["id"], "saved extra selection resolves")
	check(not settings._valid_knife_entry({}), "malformed entry rejected")
	var invalid: Dictionary = entries[0].duplicate(true)
	invalid["inspect_anim"] = null
	check(not settings._valid_knife_entry(invalid), "inspect category requires real clip name")
	var production := Settings.new()
	var actual := production.get_available_knives()
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://models/knives/catalog.json"))
	check(json is Array and actual.size() == json.size() + 2, "production catalog count matches JSON")
	production.free()

	var player := HeadlessPlayer.new()
	root.add_child(player)
	player.set_physics_process(false)
	var knife := Knife.new()
	player.add_child(knife)
	player.knife = knife
	knife.set_process(false)
	knife.set_knife_model(MODEL, entries[0])
	var anim: AnimationPlayer = knife._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for role in ROLES:
		check(knife.animation_for_role(role) == roles[role], "role mapping: " + role)
	check(anim.current_animation == "mapped_draw", "mapped draw")
	knife.inspect()
	check(not knife._is_inspecting, "inspect ignored during draw")
	anim.advance(0.6)
	check(anim.current_animation == "mapped_idle", "draw returns to mapped idle")
	check(anim.get_animation("mapped_idle").loop_mode == Animation.LOOP_LINEAR, "idle loops")
	check(anim.get_animation("mapped_inspect").loop_mode == Animation.LOOP_NONE, "inspect never loops")
	var bindings := InputMap.action_get_events("knife_inspect")
	check(bindings.size() == 1 and bindings[0] is InputEventKey and bindings[0].physical_keycode == KEY_F, "physical F binding")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player._unhandled_input(key())
	check(knife._is_inspecting and anim.current_animation == "mapped_inspect", "F starts inspect (state=%s, clip=%s, draw=%s, gate=%s)" % [knife._is_inspecting, anim.current_animation, knife._is_drawing, player._can_inspect_knife()])
	anim.advance(0.2)
	var position_before := anim.current_animation_position
	player._unhandled_input(key(true, true))
	check(is_equal_approx(anim.current_animation_position, position_before), "held F echo does not restart")
	player._unhandled_input(key(false))
	player._unhandled_input(key())
	check(is_equal_approx(anim.current_animation_position, position_before), "new press during inspect ignored")
	check((knife.get_node("Model") as Node3D).position.x > 0, "inspect advances actual animation tracks")
	anim.advance(0.4)
	check(not knife._is_inspecting and anim.current_animation == "mapped_idle", "inspect returns to idle")
	player._unhandled_input(key(true, true))
	check(not knife._is_inspecting, "held F does not restart after completion")
	for secondary in [false, true]:
		player._unhandled_input(key(false))
		player._unhandled_input(key())
		if secondary:
			knife.attack2()
		else:
			knife.attack()
		check(not knife._is_inspecting and knife._is_attacking, "attack interrupts inspect")
		check(anim.current_animation == ("mapped_stab_miss" if secondary else "mapped_midslash1"), "mapped attack")
		player._unhandled_input(key())
		check(not knife._is_inspecting, "F ignored during attack")
		anim.advance(0.6)
	knife.inspect()
	knife.play_draw()
	check(not knife._is_inspecting and anim.current_animation == "mapped_draw", "draw cancels inspect")
	anim.advance(0.6)
	knife.inspect()
	knife.set_knife_model(MODEL, entries[10])
	anim = knife._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.advance(0.6)
	player._unhandled_input(key())
	check(not knife._is_inspecting and anim.current_animation == "mapped_idle", "switch cancels; unsupported knife does not fake inspect")
	knife.set_knife_model(MODEL, entries[0])
	anim = knife._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.advance(0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.pointer_captured = false
	player._unhandled_input(key())
	check(not knife._is_inspecting, "free mouse blocks inspect")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.pointer_captured = true
	paused = true
	player._unhandled_input(key())
	check(not knife._is_inspecting, "tree pause blocks inspect")
	paused = false
	for text_class in [LineEdit, TextEdit]:
		var text: Control = text_class.new()
		root.add_child(text)
		text.grab_focus()
		player._unhandled_input(key())
		check(not knife._is_inspecting, "text focus blocks inspect")
		text.free()
	var menu := PauseMenu.new()
	root.add_child(menu)
	menu.open_menu()
	# Even accidental mouse recapture must not bypass a visible menu.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player._unhandled_input(key())
	check(not knife._is_inspecting, "visible pause menu blocks inspect")
	menu.free()

	root.size = Vector2i(1280, 720)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var dialog := Dialog.new()
	center.add_child(dialog)
	dialog._sm = settings
	dialog._refresh_knives()
	await process_frame
	await process_frame
	check(dialog._knife_list.item_count == 22, "dialog lists all 22 fixture knives")
	check(dialog._knife_list.get_v_scroll_bar().max_value > dialog._knife_list.get_v_scroll_bar().page, "list scrolls")
	check(dialog._knife_list.get_item_text(2).contains("Осмотр: F"), "inspect marker")
	check(dialog._knife_list.get_item_text(21).contains("без осмотра"), "unsupported marker")
	dialog._knife_list.select(21)
	dialog._knife_list.ensure_current_is_visible()
	dialog._on_knife_item_selected(21)
	await process_frame
	check(dialog._knife_list.get_v_scroll_bar().value > 0, "last item reachable by scrolling")
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	check(screen.encloses(dialog.get_global_rect()), "dialog fits 1280x720")
	check(screen.encloses(dialog._btn_select.get_global_rect()), "select button not clipped")
	check(screen.encloses(dialog._btn_cancel.get_global_rect()), "cancel button not clipped")
	check(dialog._lbl_knife_details.text.contains("Осмотр недоступен"), "unsupported selection clearly explained")
	player._unhandled_input(key())
	check(not knife._is_inspecting, "visible dialog blocks inspect")
	center.free()
	settings.free()
	player.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CATALOG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MODEL))
	print("KNIFE INSPECT TESTS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
