extends SceneTree

func _initialize() -> void:
	print("--- Running Fall Damage Test ---")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame
	await process_frame

	var player: CSPlayer = main.get_node("Player")
	var hud: CSHud = main.get_node("HUD")

	print("Initial player health: ", player.health)
	assert(player.health == 100, "Health should start at 100")

	# Test 1: Fall with velocity 500 u/s (below 580 threshold)
	# Should take 0 damage
	player.pm.onground = -1
	player.pm.fall_velocity = 500.0
	player.pm.onground = 0  # Land on ground
	player.pm._check_falling()
	assert(player.pm.last_fall_damage == 0.0, "Velocity 500 u/s should take 0 damage")
	print("[PASS] Test 1: Sub-threshold fall (500 u/s) = 0 damage")

	# Test 2: Fall with velocity 800 u/s (between 580 and 1024)
	# Expected dmg = (800 - 580) * (100 / 444) = 220 * 0.2252 = ~49.5 dmg
	player.pm.onground = -1
	player.pm.fall_velocity = 800.0
	player.pm.onground = 0  # Land on ground
	player.pm._check_falling()
	var expected_dmg := (800.0 - 580.0) * (100.0 / 444.0)
	print("Calculated damage for 800 u/s: ", player.pm.last_fall_damage, " (expected: ~%.1f)" % expected_dmg)
	assert(abs(player.pm.last_fall_damage - expected_dmg) < 1.0, "Damage should match GoldSrc formula")

	# Simulate player applying damage
	var dmg_int := int(round(player.pm.last_fall_damage))
	player.pm.last_fall_damage = 0.0
	player.take_damage(dmg_int)
	print("Player health after 800 u/s fall: ", player.health, " (took %d dmg)" % dmg_int)
	assert(player.health == 100 - dmg_int, "Health should decrease by damage amount")
	print("[PASS] Test 2: Safe fall (800 u/s) = %d damage taken, health is %d" % [dmg_int, player.health])

	# Test 3: Disable fall damage in SettingsManager / pm
	player.pm.fall_damage_enabled = false
	player.pm.onground = -1
	player.pm.fall_velocity = 950.0
	player.pm.onground = 0
	player.pm._check_falling()
	assert(player.pm.last_fall_damage == 0.0, "When fall_damage_enabled is false, damage should be 0")
	print("[PASS] Test 3: Fall damage disabled = 0 damage taken")
	player.pm.fall_damage_enabled = true

	# Test 4: Fatal fall (1100 u/s >= 1024 u/s)
	# Should inflict fatal damage (> 100 dmg)
	player.pm.onground = -1
	player.pm.fall_velocity = 1100.0
	player.pm.onground = 0
	player.pm._check_falling()
	print("Calculated damage for 1100 u/s (fatal): ", player.pm.last_fall_damage)
	assert(player.pm.last_fall_damage >= 100.0, "1100 u/s fall should be fatal (>= 100 dmg)")
	var fatal_dmg := int(round(player.pm.last_fall_damage))
	player.take_damage(fatal_dmg)
	assert(player.health == 0, "Player health should be 0 after fatal damage")
	assert(player.is_dead == true, "Player should be dead after fatal damage")
	print("[PASS] Test 4: Fatal fall (>1024 u/s) kills player")

	print("\nALL FALL DAMAGE TESTS PASSED SUCCESSFULLY!")
	quit(0)
