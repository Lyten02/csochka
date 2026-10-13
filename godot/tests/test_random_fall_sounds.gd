extends SceneTree

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	print("--- Running Random Fall Sound Test ---")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var player = main.get_node("Player")
	print("Loaded fall sounds count: ", player.fall_damage_sounds.size())
	assert(player.fall_damage_sounds.size() == 3, "Should have loaded exactly 3 fall damage sounds")

	var played_indices: Dictionary = {}
	for i in range(12):
		player._play_fall_sound()
		var stream = player.fall_damage_sound.stream
		var idx = player._last_fall_sound_index
		played_indices[idx] = played_indices.get(idx, 0) + 1
		print("Play %2d: selected sound index %d" % [i + 1, idx])

	print("Played indices distribution: ", played_indices)
	assert(played_indices.size() >= 2, "Should have played multiple different sounds randomly")
	print("[PASS] Random fall damage sounds verified successfully!")
	quit(0)
