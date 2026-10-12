extends SceneTree

func _initialize() -> void:
	print("--- Running Death Sound Test ---")
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.current_map_name = "35hp_3"
		sm.current_map_bsp = "res://maps/35hp_3.bsp"
		sm.current_map_glb = "res://maps/35hp_3.glb"

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var player = main.get_node("Player")
	assert(player.death_sound != null, "Death sound stream should be loaded")
	assert(player.death_sound_player != null, "Death sound AudioStreamPlayer should exist")
	print("Loaded death sound: ", player.death_sound.resource_path)

	# Test 1: Non-lethal damage (should play fall hurt sound, NOT death sound)
	player.take_damage(20)
	assert(player.health == 80, "Player health should be 80 after 20 dmg")
	assert(not player.is_dead, "Player should not be dead")
	print("[PASS] Test 1: Non-lethal damage does not trigger death")

	# Test 2: Lethal damage triggers death and plays death sound
	var died_tracker := [false]
	player.player_died.connect(func(): died_tracker[0] = true)

	player.take_damage(80)
	assert(player.health == 0, "Player health should be 0 after lethal dmg")
	assert(player.is_dead, "Player should be marked is_dead")
	assert(died_tracker[0], "player_died signal should have fired")
	print("[PASS] Test 2: Lethal damage triggers player_died and plays death sound!")

	# Test 3: Standalone _play_death_sound call works
	player._play_death_sound()
	assert(player.death_sound_player.stream == player.death_sound, "Death sound player has correct stream")
	print("[PASS] Test 3: _play_death_sound() works as expected!")

	print("\nALL DEATH SOUND TESTS PASSED SUCCESSFULLY!")
	quit(0)
