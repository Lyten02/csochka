extends SceneTree
## Headless movement checks against the real map hulls:
##   godot --headless --path godot --script res://tests/pmove_test.gd
## Exit code 0 = all passed.

const MSEC := 10  # 100 commands per second, like fps_max 100
const ARENA := Vector3(100, 900, -601)  # open arena floor (origin z; feet at -637)

var bsp: GoldSrcBsp
var player: CSPlayer
var pm: CSPlayerMove
var failures := 0


func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self):
		return
	bsp = GoldSrcBsp.load_file("res://maps/35hp_3.bsp")
	player = load("res://scripts/player/cs_player.gd").new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	player.add_child(cam)
	root.add_child(player)
	player.setup(bsp)
	pm = player.pm

	test_spawn_fall_and_teleport()
	test_ground_speed_and_friction()
	test_jump_height_and_stamina()
	test_wall_collision_and_slide()
	test_duck_and_unduck()
	test_bhop_vanilla_cap()
	test_bhop_uncapped()
	test_ladder_climb()

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func cmd(fwd: float, side: float, buttons: int) -> Dictionary:
	return {"forward": fwd, "side": side, "up": 0.0, "buttons": buttons}


## Runs one command and verifies the hull never ends up inside solid geometry.
func tick(c: Dictionary) -> void:
	player.run_command(c, MSEC)
	if bsp.test_player_position(pm.origin, pm.usehull) != -1:
		failures += 1
		print("  FAIL player inside solid at ", pm.origin)


func place(at: Vector3, yaw: float) -> void:
	pm.spawn(at, yaw)
	pm.bhop_speed_cap = true
	pm.jump_stamina = true
	player.view_angles = Vector3(0, yaw, 0)
	player.auto_bhop = false
	for i in 50:
		tick(cmd(0, 0, 0))


func test_spawn_fall_and_teleport() -> void:
	print("spawn -> fall shaft -> trigger_teleport")
	player.respawn(0)
	for i in 300:
		tick(cmd(0, 0, 0))
	check(player.teleport_count >= 1, "teleported from the spawn shaft (%d)" % player.teleport_count)
	check(pm.onground != -1, "landed after teleport at %s" % pm.origin)


func test_ground_speed_and_friction() -> void:
	print("ground acceleration / friction")
	place(ARENA, 0.0)
	check(pm.onground != -1, "standing on arena floor")
	var top := 0.0
	for i in 100:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD))
		top = maxf(top, pm.horizontal_speed())
	check(absf(top - 250.0) < 0.01, "knife run speed 250 (got %.3f)" % top)
	var diag := 0.0
	place(ARENA, 0.0)
	for i in 100:
		tick(cmd(400, 400, CSPlayerMove.IN_FORWARD | CSPlayerMove.IN_MOVERIGHT))
		diag = maxf(diag, pm.horizontal_speed())
	check(absf(diag - 250.0) < 0.01, "diagonal speed also 250 (got %.3f)" % diag)
	var stop_ticks := 0
	while pm.horizontal_speed() > 0.0 and stop_ticks < 200:
		tick(cmd(0, 0, 0))
		stop_ticks += 1
	# sv_friction 4, sv_stopspeed 75: 250 -> 75 exponentially, then linear 3 u/s per tick -> ~0.55 s.
	check(stop_ticks > 40 and stop_ticks < 70, "friction stops from 250 in %d ticks" % stop_ticks)


func test_jump_height_and_stamina() -> void:
	print("jump")
	place(ARENA, 0.0)
	var z0 := pm.origin.z
	var apex := z0
	tick(cmd(0, 0, CSPlayerMove.IN_JUMP))
	check(pm.jumped, "jump triggered from ground")
	var vz := pm.velocity.z
	# vz = sqrt(2*800*45) minus two half-gravity steps inside the jump tick (PM_Jump + end of move).
	check(absf(vz - (sqrt(2.0 * 800.0 * 45.0) - 8.0)) < 0.01, "take-off vz %.3f" % vz)
	var air_ticks := 1
	while pm.onground == -1 and air_ticks < 200:
		tick(cmd(0, 0, CSPlayerMove.IN_JUMP))  # holding jump must not re-jump (no pogo)
		apex = maxf(apex, pm.origin.z)
		air_ticks += 1
	check(absf((apex - z0) - 45.0) < 1.0, "jump apex %.2f units (CS: 45)" % (apex - z0))
	var held_jumps := 0
	for i in 60:
		tick(cmd(0, 0, CSPlayerMove.IN_JUMP))
		held_jumps += int(pm.jumped)
	check(held_jumps == 0, "holding jump does not bunny hop by itself")
	# Immediate re-jump while stamina (fuser2) is high jumps lower.
	tick(cmd(0, 0, 0))
	var z1 := pm.origin.z
	place(ARENA, 0.0)
	tick(cmd(0, 0, CSPlayerMove.IN_JUMP))
	while pm.onground == -1:
		tick(cmd(0, 0, 0))
	z1 = pm.origin.z
	var apex2 := z1
	tick(cmd(0, 0, CSPlayerMove.IN_JUMP))
	while pm.onground == -1:
		tick(cmd(0, 0, 0))
		apex2 = maxf(apex2, pm.origin.z)
	check(apex2 - z1 < 40.0, "second jump right after landing is lower (stamina): %.2f" % (apex2 - z1))


func test_wall_collision_and_slide() -> void:
	print("walls")
	place(ARENA, 0.0)  # facing +X towards the vertical east wall (x = 1264)
	for i in 600:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD))
	var wall_x := pm.origin.x
	check(pm.horizontal_speed() < 0.01, "stopped against wall (speed %.3f)" % pm.horizontal_speed())
	check(absf(pm.origin.z - ARENA.z) < 2.0, "stays on the floor at the wall (z %.2f)" % pm.origin.z)
	var tr := bsp.player_trace(pm.origin, pm.origin + Vector3(2, 0, 0), pm.usehull)
	check(tr.fraction < 1.0 and tr.plane_normal.x < -0.99, "hull rests against the wall plane (gap %.4f)" % (tr.fraction * 2.0))
	check(absf(wall_x + 16.0 - 1264.0) < 0.1, "hull face at the brush face x=1264 (%.3f)" % (wall_x + 16.0))
	var y0 := pm.origin.y
	player.view_angles.y = 30.0  # 60 deg into the wall -> slide along it
	for i in 100:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD))
	check(pm.origin.y - y0 > 100.0 and absf(pm.origin.x - wall_x) < 0.1, "slides along the wall (+%.1f y)" % (pm.origin.y - y0))
	check(pm.horizontal_speed() > 100.0 and absf(pm.velocity.x) < 0.001, "slide velocity is parallel to the wall (%.2f)" % pm.horizontal_speed())


func test_duck_and_unduck() -> void:
	print("duck")
	place(ARENA, 0.0)
	var z0 := pm.origin.z
	for i in 45:
		tick(cmd(0, 0, CSPlayerMove.IN_DUCK))
	check(pm.is_ducking() and pm.usehull == 1, "ducked after TIME_TO_DUCK")
	check(absf((z0 - pm.origin.z) - 18.0) < 0.01, "origin lowered 18 units (feet stay)")
	check(absf(pm.view_ofs.z - 12.0) < 0.001, "duck view height 12")
	var top := 0.0
	for i in 100:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD | CSPlayerMove.IN_DUCK))
		top = maxf(top, pm.horizontal_speed())
	check(absf(top - 250.0 * 0.333) < 0.01, "duck walk speed 83.25 (got %.3f)" % top)
	for i in 5:
		tick(cmd(0, 0, 0))
	check(not pm.is_ducking() and pm.usehull == 0 and absf(pm.origin.z - z0) < 0.01, "stood up")
	# Duck in air: hull switches immediately and the feet rise by 18 (duck-jump).
	tick(cmd(0, 0, CSPlayerMove.IN_JUMP))
	tick(cmd(0, 0, 0))
	var feet_before := pm.origin.z - 36.0
	tick(cmd(0, 0, CSPlayerMove.IN_DUCK))
	check(pm.is_ducking(), "instant duck in air")
	check(pm.origin.z - 18.0 > feet_before + 18.0 - 3.0, "feet raised by the duck hull")
	for i in 100:
		tick(cmd(0, 0, 0))


## Perfect air strafing to the right with a jump on every landing tick.
func strafe_bhop(jumps: int) -> Array[float]:
	var speeds_at_jump: Array[float] = []
	var accel := pm.sv_airaccelerate * 250.0 * (MSEC * 0.001)
	for i in 60:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD))  # run-up to 250 before the first hop
	var was_on_ground := true
	var guard := 0
	while speeds_at_jump.size() < jumps and guard < 5000:
		guard += 1
		var buttons := 0
		if was_on_ground:
			buttons |= CSPlayerMove.IN_JUMP
		var v := Vector2(pm.velocity.x, pm.velocity.y)
		if v.length() > 1.0:
			var alpha := atan2(v.y, v.x)
			var phi := acos(clampf((30.0 - accel) / v.length(), -1.0, 1.0))
			player.view_angles.y = rad_to_deg(alpha - phi) + 90.0
			tick(cmd(0, 400, buttons | CSPlayerMove.IN_MOVERIGHT))
		else:
			tick(cmd(400, 0, buttons | CSPlayerMove.IN_FORWARD))
		if pm.jumped:
			speeds_at_jump.append(pm.horizontal_speed())
		was_on_ground = pm.onground != -1
	return speeds_at_jump


func test_bhop_vanilla_cap() -> void:
	print("bunnyhop, vanilla CS 1.6 (speed cap + stamina)")
	place(ARENA, 0.0)
	var speeds := strafe_bhop(8)
	var max_after := 0.0
	for s in speeds:
		max_after = maxf(max_after, s)
	check(speeds.size() == 8, "8 consecutive hops")
	print("    horizontal speed after each hop: ", speeds.map(func(s): return snappedf(s, 0.1)))
	check(max_after <= 300.01, "no hop leaves the ground faster than 1.2 x 250 = 300 (max %.2f)" % max_after)
	# Crop leaves 0.8 * 300 = 240 (3D); the same command then air-accelerates by ~1.5 u/s.
	var cropped := speeds.any(func(s): return s <= 243.0 and s > 238.0)
	check(cropped, "PM_PreventMegaBunnyJumping cropped a hop to ~240")
	check(player.max_speed_seen > 280.0, "air strafing gains speed above 250 (%.1f)" % player.max_speed_seen)


func test_bhop_uncapped() -> void:
	print("bunnyhop without cap/stamina (bhop server settings)")
	place(ARENA, 0.0)
	pm.bhop_speed_cap = false
	pm.jump_stamina = false
	player.max_speed_seen = 0.0
	var speeds := strafe_bhop(10)
	check(speeds.size() == 10, "10 consecutive hops")
	check(speeds[-1] > 500.0, "speed keeps growing: %s" % str(speeds.map(func(s): return snappedf(s, 1.0))))
	pm.bhop_speed_cap = true
	pm.jump_stamina = true


func test_ladder_climb() -> void:
	print("ladder")
	var ladder: GoldSrcBsp.PhysEnt = null
	for pe in bsp.physents:
		if pe.skin == GoldSrcBsp.CONTENTS_LADDER:
			ladder = pe
			break
	check(ladder != null, "map has func_ladder")
	if ladder == null:
		return
	var center := (ladder.mins + ladder.maxs) * 0.5
	# Stand on the floor in front of the ladder, facing it.
	var normal_dir := Vector3(-1, 0, 0) if center.x > 0 else Vector3(1, 0, 0)
	var start := Vector3(center.x + normal_dir.x * 40.0, center.y, ARENA.z)
	var yaw := 0.0 if normal_dir.x < 0 else 180.0
	place(start, yaw)
	var z0 := pm.origin.z
	var saw_fly := false
	player.view_angles = Vector3(-45, yaw, 0)
	for i in 300:
		tick(cmd(400, 0, CSPlayerMove.IN_FORWARD))
		saw_fly = saw_fly or pm.movetype == CSPlayerMove.MoveType.FLY
	check(saw_fly, "entered ladder movement")
	check(pm.origin.z - z0 > 150.0, "climbed %.1f units" % (pm.origin.z - z0))
