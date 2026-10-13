class_name CSPlayer
extends Node3D
## First-person CS 1.6 player: samples input like the GoldSrc client (CL_BaseMove), runs
## CSPlayerMove at a fixed command rate (physics tick = one usercmd, like fps_max 100) and renders
## an interpolated view with the client's view bob and stair smoothing.

const UNIT := 0.0254  ## metres per GoldSrc unit

## Client cvars (CS 1.6 defaults).
@export var sensitivity := 2.5
@export var m_yaw := 0.022
@export var m_pitch := 0.022
@export var cl_forwardspeed := 400.0
@export var cl_backspeed := 400.0
@export var cl_sidespeed := 400.0
@export var cl_upspeed := 320.0
@export var cl_movespeedkey := 0.52
@export var cl_bob := 0.01
@export var cl_bobcycle := 0.8
@export var cl_bobup := 0.5

## Enable "hold space to bhop" (server plugin behaviour, not vanilla).
var auto_bhop := false

var bsp: GoldSrcBsp
var pm: CSPlayerMove
var view_angles := Vector3.ZERO  ## pitch, yaw, roll (GoldSrc degrees)
var spawn_index := 0
var spawns: Array[Dictionary] = []

## Stats for the HUD.
var last_jump_speed := 0.0
var jump_count := 0
var max_speed_seen := 0.0
var teleport_count := 0

## Bhop Block Teleport & LJ Stats & Double Duck
signal bhop_block_timeout()
signal teleported(dest: Dictionary)
signal lj_stats_toggled(enabled: bool)
signal lj_stat_recorded(data: Dictionary)

## Kreedz / Speedrun Timer & Button Interaction
signal kz_timer_started()
signal kz_timer_stopped(final_time: float, is_new_record: bool)
signal kz_timer_reset()
signal kz_timer_invalid_stop()
signal kz_aimed_button_changed(btn_info: Dictionary)

var kz_timer_active: bool = false
var kz_timer_elapsed: float = 0.0
var kz_best_time: float = -1.0
var kz_buttons: Array[Dictionary] = []
var aimed_button: Dictionary = {}
var _prev_cmd_buttons: int = 0
var _last_button_use_msec: int = -1000
var button_sound_player: AudioStreamPlayer
var button_sound: AudioStream

var block_stand_timer := 0.0
const BLOCK_MAX_STAND_TIME := 0.35
var _last_stage_teleport_dest: Dictionary = {}
var _spawn_origins: Array[Vector3] = []
var _spawn_bounds_min := Vector3.ZERO
var _spawn_bounds_max := Vector3.ZERO
var _min_spawn_z := 0.0

var lj_stats_enabled := true
const LJ_MIN_DISTANCE := 240.0
var _lj_tracking := false
var _lj_takeoff_pos := Vector3.ZERO
var _lj_prestrafe := 0.0
var _lj_maxspeed := 0.0
var _lj_air_frames := 0
var _lj_sync_frames := 0
var _lj_strafes := 0
var _lj_last_strafe_dir := 0
var _prev_view_yaw := 0.0

## Health & Damage
signal health_changed(new_health: int, damage_taken: int)
signal player_died()

var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var fall_damage_sound: AudioStreamPlayer
var fall_damage_sounds: Array[AudioStream] = []
var _last_fall_sound_index: int = -1

var ladder_sound_player: AudioStreamPlayer
var ladder_sounds: Array[AudioStream] = []
var _last_ladder_sound_index: int = -1
var _ladder_step_dist: float = 0.0
const LADDER_STEP_DISTANCE := 45.0

var death_sound_player: AudioStreamPlayer
var death_sound: AudioStream

var footstep_sound_player: AudioStreamPlayer
var footstep_sounds: Array[AudioStream] = []
var _last_footstep_sound_index: int = -1
var _footstep_dist: float = 0.0
const FOOTSTEP_DISTANCE := 75.0

const CSKnife = preload("res://scripts/weapons/cs_knife.gd")
const CSKnifeScene = preload("res://scenes/weapons/knife.tscn")

@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var knife: CSKnife = get_node_or_null("Camera3D/Knife")

var _prev_origin := Vector3.ZERO
var _prev_view_z := 0.0
var _wheel_jump := false
var _bob_time := 0.0
var _bob := 0.0
var _step_old_z := 0.0
var _teleport_dest := {}
var _trigger_target_map := {}


func _ready() -> void:
	_ensure_input_actions()
	if camera:
		camera.top_level = true
		camera.fov = 73.74
		camera.near = 0.02
		camera.far = 400.0
	_ensure_knife()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	fall_damage_sound = AudioStreamPlayer.new()
	add_child(fall_damage_sound)

	for i in [1, 2, 3]:
		var path := "res://audio/fall_damage%d.wav" % i
		if ResourceLoader.exists(path):
			var snd := load(path) as AudioStream
			if snd:
				fall_damage_sounds.append(snd)

	ladder_sound_player = AudioStreamPlayer.new()
	ladder_sound_player.name = "LadderSound"
	add_child(ladder_sound_player)

	for i in range(1, 3):
		var path := "res://audio/ladder%d.wav" % i
		if ResourceLoader.exists(path):
			var snd := load(path) as AudioStream
			if snd:
				ladder_sounds.append(snd)

	death_sound_player = AudioStreamPlayer.new()
	death_sound_player.name = "DeathSound"
	add_child(death_sound_player)
	if ResourceLoader.exists("res://audio/death.wav"):
		death_sound = load("res://audio/death.wav") as AudioStream
		death_sound_player.stream = death_sound

	footstep_sound_player = AudioStreamPlayer.new()
	footstep_sound_player.name = "FootstepSound"
	add_child(footstep_sound_player)

	for i in range(1, 3):
		var path := "res://audio/step%d.wav" % i
		if ResourceLoader.exists(path):
			var snd := load(path) as AudioStream
			if snd:
				footstep_sounds.append(snd)

	button_sound_player = AudioStreamPlayer.new()
	button_sound_player.name = "ButtonSound"
	add_child(button_sound_player)
	if ResourceLoader.exists("res://audio/ui_click.wav"):
		button_sound = load("res://audio/ui_click.wav") as AudioStream
		button_sound_player.stream = button_sound

	if is_inside_tree() and has_node("/root/SettingsManager"):
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			sm.settings_changed.connect(_on_settings_changed)
			_apply_settings(sm)
			load_knife(sm.get_current_knife_model())


func _ensure_knife() -> void:
	if not camera:
		camera = get_node_or_null("Camera3D")
	if camera:
		if not knife:
			knife = camera.get_node_or_null("Knife") as CSKnife
		if not knife and CSKnifeScene:
			knife = CSKnifeScene.instantiate() as CSKnife
			knife.name = "Knife"
			camera.add_child(knife)


func load_knife(model_path: String = "") -> void:
	_ensure_knife()
	if model_path == "":
		var sm = get_node_or_null("/root/SettingsManager")
		if sm and sm.has_method("get_current_knife_model"):
			model_path = sm.get_current_knife_model()
		else:
			model_path = "res://models/knife.glb"
	if knife and model_path != "":
		var info: Dictionary = {}
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			for entry in sm.get_available_knives():
				if entry["model"] == model_path:
					info = entry
					break
		knife.set_knife_model(model_path, info)


func _on_settings_changed(key: String, _val: Variant) -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		_apply_settings(sm)
		if key == "knife" or key == "all":
			load_knife(sm.get_current_knife_model())


func _apply_settings(sm: Node) -> void:
	sensitivity = sm.sensitivity
	m_yaw = sm.m_yaw
	m_pitch = sm.m_pitch * (-1.0 if sm.invert_mouse else 1.0)
	auto_bhop = sm.auto_bhop
	if camera:
		camera.fov = sm.fov
	if pm:
		pm.fall_damage_enabled = sm.fall_damage_enabled
		pm.bhop_speed_cap = sm.bhop_speed_cap
		pm.jump_stamina = sm.jump_stamina
		pm.sv_gravity = sm.sv_gravity


func setup(map: GoldSrcBsp) -> void:
	bsp = map
	pm = CSPlayerMove.new(bsp)
	_ensure_knife()
	if is_inside_tree() and has_node("/root/SettingsManager"):
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			_apply_settings(sm)
			load_knife(sm.get_current_knife_model())
			var m_name: String = bsp.map_name if bsp.map_name != "" else str(sm.current_map_name)
			kz_best_time = sm.get_best_time(m_name)
	spawns = bsp.find_entities("classname", "info_player_start") + bsp.find_entities("classname", "info_player_deathmatch")
	_spawn_origins.clear()
	if not spawns.is_empty():
		var min_v := Vector3(INF, INF, INF)
		var max_v := Vector3(-INF, -INF, -INF)
		for s in spawns:
			var p := GoldSrcBsp.parse_vec(s["origin"])
			_spawn_origins.append(p)
			min_v = min_v.min(p)
			max_v = max_v.max(p)
		_spawn_bounds_min = min_v - Vector3(300.0, 300.0, 96.0)
		_spawn_bounds_max = max_v + Vector3(300.0, 300.0, 160.0)
		_min_spawn_z = min_v.z
	_teleport_dest.clear()
	_trigger_target_map.clear()
	for ent in bsp.entities:
		var tn: String = ent.get("targetname", "")
		if tn != "" and ent.has("origin"):
			var cls: String = ent.get("classname", "")
			if not _teleport_dest.has(tn) or cls == "info_teleport_destination" or cls == "info_target":
				_teleport_dest[tn] = ent
		var m: String = ent.get("model", "")
		if m.begins_with("*"):
			var mid: int = m.substr(1).to_int()
			var tgt: String = ent.get("target", "")
			if tgt != "":
				_trigger_target_map[mid] = tgt
	_init_kz_buttons()
	respawn(0)


func respawn(index: int) -> void:
	is_dead = false
	health = max_health
	health_changed.emit(health, 0)
	block_stand_timer = 0.0
	_lj_tracking = false
	_last_stage_teleport_dest.clear()
	kz_timer_active = false
	kz_timer_elapsed = 0.0
	kz_timer_reset.emit()
	if spawns.is_empty():
		pm.spawn(Vector3(0, 0, 64), 0.0)
	else:
		spawn_index = posmod(index, spawns.size())
		var ent := spawns[spawn_index]
		var yaw := GoldSrcBsp.parse_vec(ent.get("angles", "0 0 0")).y
		pm.spawn(GoldSrcBsp.parse_vec(ent["origin"]) + Vector3(0, 0, 1), yaw)
		view_angles = Vector3(0, yaw, 0)
	max_speed_seen = 0.0
	jump_count = 0
	_reset_interpolation()
	if knife:
		knife.play_draw()


func _reset_interpolation() -> void:
	_prev_origin = pm.origin
	_prev_view_z = pm.view_ofs.z
	_step_old_z = pm.origin.z


func _knife_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _can_inspect_knife() -> bool:
	if is_dead or get_tree().paused or not _knife_mouse_captured():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	if (focus is LineEdit or focus is TextEdit) and focus.is_visible_in_tree():
		return false
	for menu in get_tree().get_nodes_in_group("knife_input_blockers"):
		if menu is CanvasLayer and menu.visible:
			return false
		if menu is Control and menu.is_visible_in_tree():
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("knife_inspect"):
		if knife and _can_inspect_knife():
			knife.inspect()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		view_angles.y -= event.relative.x * sensitivity * m_yaw
		view_angles.x = clampf(view_angles.x + event.relative.y * sensitivity * m_pitch, -89.0, 89.0)
		view_angles.y = fposmod(view_angles.y + 180.0, 360.0) - 180.0
		if knife:
			knife.update_sway(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel_jump = true  # like `bind mwheeldown +jump`: pressed for exactly one command
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if knife:
				knife.attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if knife:
				knife.attack2()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("cs_respawn"):
		respawn(spawn_index + 1)
	elif event.is_action_pressed("cs_noclip"):
		pm.movetype = CSPlayerMove.MoveType.WALK if pm.movetype == CSPlayerMove.MoveType.NOCLIP else CSPlayerMove.MoveType.NOCLIP
	elif event.is_action_pressed("cs_toggle_autobhop"):
		auto_bhop = not auto_bhop
	elif event.is_action_pressed("cs_toggle_speedcap"):
		pm.bhop_speed_cap = not pm.bhop_speed_cap
	elif event.is_action_pressed("cs_toggle_stamina"):
		pm.jump_stamina = not pm.jump_stamina
	elif event.is_action_pressed("cs_toggle_ljstats"):
		lj_stats_enabled = not lj_stats_enabled
		lj_stats_toggled.emit(lj_stats_enabled)
	elif event.is_action_pressed("cs_use"):
		_try_use_button()


func _physics_process(_delta: float) -> void:
	if pm == null:
		return
	_prev_origin = pm.origin
	_prev_view_z = pm.view_ofs.z
	var msec := int(round(1000.0 / Engine.physics_ticks_per_second))
	run_command(_build_command(), msec)


## CL_BaseMove + CL_ButtonBits.
func _build_command() -> Dictionary:
	var buttons := 0
	var fwd := 0.0
	var side := 0.0
	var upm := 0.0
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if captured:
		if Input.is_action_pressed("cs_forward"):
			fwd += cl_forwardspeed
			buttons |= CSPlayerMove.IN_FORWARD
		if Input.is_action_pressed("cs_back"):
			fwd -= cl_backspeed
			buttons |= CSPlayerMove.IN_BACK
		if Input.is_action_pressed("cs_moveright"):
			side += cl_sidespeed
			buttons |= CSPlayerMove.IN_MOVERIGHT
		if Input.is_action_pressed("cs_moveleft"):
			side -= cl_sidespeed
			buttons |= CSPlayerMove.IN_MOVELEFT
		if Input.is_action_pressed("cs_jump") or _wheel_jump:
			buttons |= CSPlayerMove.IN_JUMP
		if Input.is_action_pressed("cs_duck"):
			buttons |= CSPlayerMove.IN_DUCK
		if Input.is_action_pressed("cs_use"):
			buttons |= CSPlayerMove.IN_USE
		if pm.movetype == CSPlayerMove.MoveType.NOCLIP:
			if buttons & CSPlayerMove.IN_JUMP:
				upm += cl_upspeed
			if buttons & CSPlayerMove.IN_DUCK:
				upm -= cl_upspeed
	_wheel_jump = false
	# Clip to the client max speed like the client DLL does.
	var spd := sqrt(fwd * fwd + side * side + upm * upm)
	if pm.client_maxspeed != 0.0 and spd > pm.client_maxspeed:
		var s := pm.client_maxspeed / spd
		fwd *= s
		side *= s
		upm *= s
	if captured and Input.is_action_pressed("cs_walk"):
		fwd *= cl_movespeedkey
		side *= cl_movespeedkey
		upm *= cl_movespeedkey
	return {"forward": fwd, "side": side, "up": upm, "buttons": buttons}


## One usercmd through pmove + the game-side trigger touch that follows it.
func run_command(cmd: Dictionary, msec: int) -> void:
	if auto_bhop and (cmd.buttons & CSPlayerMove.IN_JUMP):
		pm.oldbuttons &= ~CSPlayerMove.IN_JUMP
	var speed_before := pm.horizontal_speed()
	pm.player_move(cmd.forward, cmd.side, cmd.up, cmd.buttons, view_angles, msec)
	var teleported := false
	if pm.movetype != CSPlayerMove.MoveType.NOCLIP:
		teleported = _touch_triggers()
		_check_bhop_block_stand(msec)

	if teleported:
		pm.last_fall_damage = 0.0
	elif pm.last_fall_damage > 0.0:
		var dmg := int(round(pm.last_fall_damage))
		pm.last_fall_damage = 0.0
		take_damage(dmg)

	if pm.jumped:
		jump_count += 1
		last_jump_speed = speed_before
	max_speed_seen = maxf(max_speed_seen, pm.horizontal_speed())
	if pm.movetype == CSPlayerMove.MoveType.FLY:
		var climb_spd := pm.velocity.length()
		if climb_spd > 15.0:
			_ladder_step_dist += climb_spd * (msec * 0.001)
			if _ladder_step_dist >= LADDER_STEP_DISTANCE:
				_ladder_step_dist = fmod(_ladder_step_dist, LADDER_STEP_DISTANCE)
				_play_ladder_sound()
	else:
		_ladder_step_dist = 0.0

	if pm.movetype == CSPlayerMove.MoveType.WALK and pm.onground != -1:
		var horiz_spd := pm.horizontal_speed()
		var ducking: bool = (pm.flags & CSPlayerMove.FL_DUCKING) != 0 or pm.in_duck or (int(cmd.buttons) & CSPlayerMove.IN_DUCK) != 0
		if horiz_spd > 135.0 and not ducking:
			_footstep_dist += horiz_spd * (msec * 0.001)
			if _footstep_dist >= FOOTSTEP_DISTANCE:
				_footstep_dist = fmod(_footstep_dist, FOOTSTEP_DISTANCE)
				_play_footstep_sound()
		else:
			_footstep_dist = 0.0
	else:
		_footstep_dist = 0.0

	_track_lj_stats(cmd, speed_before)

	if (cmd.buttons & CSPlayerMove.IN_USE) != 0 and (_prev_cmd_buttons & CSPlayerMove.IN_USE) == 0:
		_try_use_button()
	_prev_cmd_buttons = cmd.buttons

	if kz_timer_active:
		kz_timer_elapsed += msec * 0.001


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(0, health - amount)
	health_changed.emit(health, amount)
	if health <= 0:
		_die()
	else:
		_play_fall_sound()


func _play_fall_sound() -> void:
	if fall_damage_sounds.is_empty():
		return
	var idx := randi() % fall_damage_sounds.size()
	if fall_damage_sounds.size() > 1 and idx == _last_fall_sound_index:
		idx = (idx + 1) % fall_damage_sounds.size()
	_last_fall_sound_index = idx

	fall_damage_sound.stream = fall_damage_sounds[idx]
	fall_damage_sound.play()


func _play_ladder_sound() -> void:
	if ladder_sounds.is_empty():
		return
	var idx := randi() % ladder_sounds.size()
	if ladder_sounds.size() > 1 and idx == _last_ladder_sound_index:
		idx = (idx + 1) % ladder_sounds.size()
	_last_ladder_sound_index = idx

	ladder_sound_player.stream = ladder_sounds[idx]
	ladder_sound_player.pitch_scale = randf_range(0.96, 1.04)
	ladder_sound_player.play()


func _play_footstep_sound() -> void:
	if footstep_sounds.is_empty():
		return
	var idx := randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1 and idx == _last_footstep_sound_index:
		idx = (idx + 1) % footstep_sounds.size()
	_last_footstep_sound_index = idx

	footstep_sound_player.stream = footstep_sounds[idx]
	footstep_sound_player.pitch_scale = randf_range(0.96, 1.04)
	footstep_sound_player.play()


func _die() -> void:
	is_dead = true
	kz_timer_active = false
	kz_timer_elapsed = 0.0
	kz_timer_reset.emit()
	player_died.emit()
	_play_death_sound()
	if pm:
		pm.punchangle.x = 22.0
	await get_tree().create_timer(1.2).timeout
	if is_dead:
		respawn(spawn_index)


func _play_death_sound() -> void:
	if death_sound_player and death_sound:
		death_sound_player.pitch_scale = randf_range(0.98, 1.02)
		death_sound_player.play()


func _touch_triggers() -> bool:
	if bsp == null or pm == null:
		return false

	# 1. Authentic GoldSrc trigger_teleport volumes
	for trig in bsp.triggers:
		if trig.classname != "trigger_teleport":
			continue
		if not bsp.touching_trigger(trig, pm.origin, pm.usehull):
			continue

		var target: String = _trigger_target(trig)
		if not _teleport_dest.has(target):
			continue
		var dest: Dictionary = _teleport_dest[target]
		_last_stage_teleport_dest = dest
		_teleport_to(dest)
		return true

	# 2. For maps without any trigger_teleport entities (e.g. kz_bhop)
	if bsp.triggers.is_empty() and not _is_in_spawn_area(pm.origin):
		var is_on_floor: bool = pm.onground == 0 or pm.waterlevel > 0
		if is_on_floor and _min_spawn_z > -900000.0 and pm.origin.z < _min_spawn_z - 150.0:
			var target_dest: Dictionary = spawns[spawn_index] if not spawns.is_empty() else {}
			if not target_dest.is_empty():
				_teleport_to(target_dest)
				return true

	# 3. Deep void safety fallback (if fallen completely out of map bounds)
	if pm.origin.z < -4000.0:
		var target_dest: Dictionary = _last_stage_teleport_dest if not _last_stage_teleport_dest.is_empty() else (spawns[spawn_index] if not spawns.is_empty() else {})
		if not target_dest.is_empty():
			_teleport_to(target_dest)
			return true

	return false


func _teleport_to(dest: Dictionary) -> void:
	# CTriggerTeleport::TeleportTouch: origin = dest - mins.z + 1, velocity cleared, angles from dest.
	var o := GoldSrcBsp.parse_vec(dest["origin"])
	if dest.get("classname", "") == "info_teleport_destination":
		o.z -= GoldSrcBsp.PLAYER_MINS[pm.usehull].z
		o.z += 1.0
	else:
		o.z += 1.0

	# Safety check: if player origin would be stuck in solid geometry, shift up
	if bsp != null and bsp.test_player_position(o, pm.usehull) != -1:
		o.z -= GoldSrcBsp.PLAYER_MINS[pm.usehull].z + 1.0

	pm.origin = o
	pm.velocity = Vector3.ZERO
	pm.onground = -1
	pm.fall_velocity = 0.0
	pm.last_fall_damage = 0.0
	var ang := GoldSrcBsp.parse_vec(dest.get("angles", "0 0 0"))
	view_angles = Vector3(ang.x, ang.y, 0)
	teleport_count += 1
	block_stand_timer = 0.0
	_lj_tracking = false
	if dest.get("classname", "") == "info_teleport_destination" or dest.get("classname", "") == "info_target":
		_last_stage_teleport_dest = dest
	_reset_interpolation()
	teleported.emit(dest)


func _is_in_spawn_area(pos: Vector3) -> bool:
	if _spawn_origins.is_empty():
		return false
	# If inside the overall spawn lobby box
	if (pos.x >= _spawn_bounds_min.x and pos.x <= _spawn_bounds_max.x and
		pos.y >= _spawn_bounds_min.y and pos.y <= _spawn_bounds_max.y and
		pos.z >= _spawn_bounds_min.z and pos.z <= _spawn_bounds_max.z):
		return true
	# Or within 350 units horizontally and 120 units vertically of any individual spawn
	for s_pos in _spawn_origins:
		if absf(pos.z - s_pos.z) <= 120.0:
			var d2 := Vector2(pos.x - s_pos.x, pos.y - s_pos.y).length_squared()
			if d2 <= 350.0 * 350.0:
				return true
	return false


func _check_bhop_block_stand(msec: int) -> void:
	# Only dynamic brush entities (pm.onground > 0) can ever be bhop blocks.
	# Worldspawn (pm.onground == 0) is map architecture (floor, walls, spawn) and NEVER a bhop block.
	if pm.movetype != CSPlayerMove.MoveType.NOCLIP and pm.onground > 0 and bsp != null:
		# Never timeout at spawn or in spawn area!
		if _is_in_spawn_area(pm.origin):
			block_stand_timer = 0.0
			return

		# Never timeout near start button
		for btn in kz_buttons:
			if btn.get("type") == "start" and btn.has("center"):
				var b_center: Vector3 = btn["center"]
				if Vector2(pm.origin.x - b_center.x, pm.origin.y - b_center.y).length() < 50.0 and absf(pm.origin.z - b_center.z) < 60.0:
					block_stand_timer = 0.0
					return

		var pe := bsp.physents[pm.onground]
		if pe.classname == "func_door" or pe.classname == "func_conveyor" or pe.classname == "func_wall_toggle":
			block_stand_timer += msec * 0.001
			if block_stand_timer >= BLOCK_MAX_STAND_TIME:
				_teleport_bhop_timeout()
			return

	block_stand_timer = 0.0


func _teleport_bhop_timeout() -> void:
	block_stand_timer = 0.0
	bhop_block_timeout.emit()
	var target_dest: Dictionary = {}
	# Look for trigger_teleport in pit below current horizontal coordinates
	for trig in bsp.triggers:
		if trig.classname != "trigger_teleport":
			continue
		if (pm.origin.x >= trig.mins.x - 64.0 and pm.origin.x <= trig.maxs.x + 64.0 and
			pm.origin.y >= trig.mins.y - 64.0 and pm.origin.y <= trig.maxs.y + 64.0 and
			pm.origin.z >= trig.mins.z - 400.0):
			var target := _trigger_target(trig)
			if _teleport_dest.has(target):
				target_dest = _teleport_dest[target]
				break

	if target_dest.is_empty() and not _last_stage_teleport_dest.is_empty():
		target_dest = _last_stage_teleport_dest

	if target_dest.is_empty():
		var closest_d := 1e9
		for trig in bsp.triggers:
			if trig.classname != "trigger_teleport":
				continue
			var center := (trig.mins + trig.maxs) * 0.5
			var d := Vector2(pm.origin.x - center.x, pm.origin.y - center.y).length_squared()
			if d < closest_d:
				var t_name := _trigger_target(trig)
				if _teleport_dest.has(t_name):
					closest_d = d
					target_dest = _teleport_dest[t_name]

	if target_dest.is_empty():
		if not spawns.is_empty():
			target_dest = spawns[spawn_index]
		else:
			return

	_teleport_to(target_dest)


func _track_lj_stats(cmd: Dictionary, speed_before: float) -> void:
	if not lj_stats_enabled:
		_lj_tracking = false
		return

	if pm.jumped:
		_lj_tracking = true
		_lj_takeoff_pos = pm.origin
		_lj_prestrafe = speed_before
		_lj_maxspeed = speed_before
		_lj_air_frames = 0
		_lj_sync_frames = 0
		_lj_strafes = 0
		_lj_last_strafe_dir = 0
		_prev_view_yaw = view_angles.y
		return

	if _lj_tracking:
		if pm.onground == -1:
			_lj_air_frames += 1
			var cur_spd := pm.horizontal_speed()
			_lj_maxspeed = maxf(_lj_maxspeed, cur_spd)

			var yaw_delta := view_angles.y - _prev_view_yaw
			if yaw_delta > 180.0:
				yaw_delta -= 360.0
			elif yaw_delta < -180.0:
				yaw_delta += 360.0
			_prev_view_yaw = view_angles.y

			var side_val := float(cmd.side)
			var turn_l := yaw_delta > 0.02
			var turn_r := yaw_delta < -0.02
			var press_l := side_val < -10.0 or (int(cmd.buttons) & CSPlayerMove.IN_MOVELEFT) != 0
			var press_r := side_val > 10.0 or (int(cmd.buttons) & CSPlayerMove.IN_MOVERIGHT) != 0

			if (turn_l and press_l) or (turn_r and press_r):
				_lj_sync_frames += 1

			if turn_l and press_l:
				if _lj_last_strafe_dir != -1:
					_lj_strafes += 1
					_lj_last_strafe_dir = -1
			elif turn_r and press_r:
				if _lj_last_strafe_dir != 1:
					_lj_strafes += 1
					_lj_last_strafe_dir = 1
		else:
			# Landed!
			_lj_tracking = false
			var h_disp := Vector2(pm.origin.x - _lj_takeoff_pos.x, pm.origin.y - _lj_takeoff_pos.y).length()
			var lj_dist := h_disp + 32.0  # CS 1.6 edge-to-edge calculation
			var height_diff := pm.origin.z - _lj_takeoff_pos.z
			var sync_pct := (float(_lj_sync_frames) / float(maxi(1, _lj_air_frames))) * 100.0

			# Filter: standard LJ plugin requires min 240 units distance and valid height drop
			if lj_dist >= LJ_MIN_DISTANCE and _lj_air_frames >= 8 and height_diff >= -44.0 and height_diff <= 32.0:
				var data := {
					"distance": lj_dist,
					"raw_distance": h_disp,
					"prestrafe": _lj_prestrafe,
					"maxspeed": _lj_maxspeed,
					"strafes": _lj_strafes,
					"sync": sync_pct,
					"height_diff": height_diff,
					"air_frames": _lj_air_frames,
				}
				lj_stat_recorded.emit(data)


func _trigger_target(trig: GoldSrcBsp.PhysEnt) -> String:
	if _trigger_target_map.has(trig.model):
		return _trigger_target_map[trig.model]
	for ent in bsp.entities:
		if ent.get("model", "") == "*%d" % trig.model:
			return ent.get("target", "")
	return ""


func _process(delta: float) -> void:
	if pm == null:
		return
	var frac := Engine.get_physics_interpolation_fraction()
	var sim_origin := _prev_origin.lerp(pm.origin, frac)
	var view_z := lerpf(_prev_view_z, pm.view_ofs.z, frac)

	# V_CalcBob
	if pm.onground != -1 and cl_bob > 0.0:
		_bob_time += delta
		var cycle := fmod(_bob_time, cl_bobcycle) / cl_bobcycle
		if cycle < cl_bobup:
			cycle = PI * cycle / cl_bobup
		else:
			cycle = PI + PI * (cycle - cl_bobup) / (1.0 - cl_bobup)
		_bob = pm.horizontal_speed() * cl_bob
		_bob = clampf(_bob * 0.3 + _bob * 0.7 * sin(cycle), -7.0, 4.0)

	if knife and pm:
		knife.update_bob(pm.horizontal_speed(), _bob_time / cl_bobcycle * TAU, pm.onground != -1)

	# V_CalcRefdef stair smoothing (only when walking up on ground).
	var eye := sim_origin + Vector3(0, 0, view_z + _bob)
	if pm.onground != -1 and sim_origin.z - _step_old_z > 0.0 and pm.movetype == CSPlayerMove.MoveType.WALK:
		_step_old_z = minf(_step_old_z + delta * 150.0, sim_origin.z)
		_step_old_z = maxf(_step_old_z, sim_origin.z - 18.0)
		eye.z += _step_old_z - sim_origin.z
	else:
		_step_old_z = sim_origin.z

	var ang := view_angles + pm.punchangle
	var yaw := deg_to_rad(ang.y)
	var pitch := deg_to_rad(ang.x)
	var roll := deg_to_rad(ang.z)
	var fwd := Vector3(cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), -sin(pitch))
	var up := Vector3(cos(roll) * sin(pitch) * cos(yaw) + sin(roll) * sin(yaw),
		cos(roll) * sin(pitch) * sin(yaw) - sin(roll) * cos(yaw), cos(roll) * cos(pitch))
	if camera:
		camera.global_transform = Transform3D(Basis.looking_at(to_godot_dir(fwd), to_godot_dir(up)), to_godot(eye))

	var cur_aim := get_aimed_button()
	var cur_model: String = cur_aim.get("model", "")
	var old_model: String = aimed_button.get("model", "")
	if cur_model != old_model:
		aimed_button = cur_aim
		kz_aimed_button_changed.emit(aimed_button)


func _init_kz_buttons() -> void:
	kz_buttons.clear()
	aimed_button.clear()
	if bsp == null:
		return
	for ent in bsp.entities:
		var cls: String = ent.get("classname", "")
		if cls != "func_button":
			continue
		var model_str: String = ent.get("model", "")
		if not model_str.begins_with("*"):
			continue
		var model_idx := model_str.substr(1).to_int()
		if model_idx <= 0 or model_idx >= bsp.model_mins.size():
			continue

		var b_mins: Vector3 = bsp.model_mins[model_idx]
		var b_maxs: Vector3 = bsp.model_maxs[model_idx]
		if ent.has("origin"):
			var org := GoldSrcBsp.parse_vec(ent["origin"])
			b_mins += org
			b_maxs += org

		var target: String = ent.get("target", "")
		var targetname: String = ent.get("targetname", "")
		var target_l := target.to_lower()
		var targetname_l := targetname.to_lower()
		var b_type := ""
		if target_l.contains("start") or targetname_l.contains("start") or target == "counter_start" or targetname == "counter_start" or target == "timer_start" or model_str == "*95" or model_str == "*48":
			b_type = "start"
		elif target_l.contains("stop") or target_l.contains("off") or targetname_l.contains("stop") or targetname == "but_stop" or target == "counter_off" or target == "counter_stop" or target == "timer_stop" or model_str == "*97" or model_str == "*121":
			b_type = "stop"
		else:
			b_type = "start" if _is_near_spawn((b_mins + b_maxs) * 0.5) else "stop"

		kz_buttons.append({
			"type": b_type,
			"model": model_str,
			"model_idx": model_idx,
			"mins": b_mins,
			"maxs": b_maxs,
			"center": (b_mins + b_maxs) * 0.5,
			"target": target,
			"targetname": targetname,
			"entity": ent,
		})


func _is_near_spawn(pos: Vector3) -> bool:
	for sp in spawns:
		var sp_pos := GoldSrcBsp.parse_vec(sp["origin"])
		if pos.distance_to(sp_pos) < 750.0:
			return true
	return false


func get_aimed_button() -> Dictionary:
	if bsp == null or kz_buttons.is_empty() or pm == null:
		return {}

	var eye := pm.origin + pm.view_ofs
	var ang := view_angles + pm.punchangle
	var pitch := deg_to_rad(ang.x)
	var yaw := deg_to_rad(ang.y)
	var fwd := Vector3(cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), -sin(pitch))

	var closest_btn: Dictionary = {}
	var closest_dist := 90.0

	for btn in kz_buttons:
		var b_mins: Vector3 = btn["mins"]
		var b_maxs: Vector3 = btn["maxs"]
		var center: Vector3 = btn["center"]

		if ray_intersects_aabb(eye, fwd, 90.0, b_mins, b_maxs):
			var d := eye.distance_to(center)
			if d < closest_dist:
				closest_dist = d
				closest_btn = btn
			continue

		var closest_pt := Vector3(
			clampf(eye.x, b_mins.x, b_maxs.x),
			clampf(eye.y, b_mins.y, b_maxs.y),
			clampf(eye.z, b_mins.z, b_maxs.z)
		)
		var d_pt := eye.distance_to(closest_pt)
		if d_pt <= 85.0:
			var to_btn := (center - eye).normalized()
			if fwd.dot(to_btn) > 0.2:
				if d_pt < closest_dist:
					closest_dist = d_pt
					closest_btn = btn

	return closest_btn


static func ray_intersects_aabb(origin: Vector3, dir: Vector3, max_dist: float, box_min: Vector3, box_max: Vector3) -> bool:
	var expanded_min := box_min - Vector3(6.0, 6.0, 6.0)
	var expanded_max := box_max + Vector3(6.0, 6.0, 6.0)
	var tmin := 0.0
	var tmax := max_dist

	for i in 3:
		var inv_d := 1.0 / dir[i] if absf(dir[i]) > 1e-6 else (1e7 if dir[i] >= 0.0 else -1e7)
		var t1 := (expanded_min[i] - origin[i]) * inv_d
		var t2 := (expanded_max[i] - origin[i]) * inv_d
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return false
	return tmax >= 0.0 and tmin <= max_dist


func _try_use_button() -> bool:
	var cur_msec := Time.get_ticks_msec()
	if _last_button_use_msec > 0 and cur_msec - _last_button_use_msec < 200:
		return false
	var btn := get_aimed_button()
	if btn.is_empty():
		return false

	_last_button_use_msec = cur_msec
	_play_button_sound()

	if btn["type"] == "start":
		kz_timer_active = true
		kz_timer_elapsed = 0.0
		kz_timer_started.emit()
		return true
	elif btn["type"] == "stop":
		if kz_timer_active:
			kz_timer_active = false
			var final_time := kz_timer_elapsed
			var is_best := false
			if kz_best_time <= 0.0 or final_time < kz_best_time:
				kz_best_time = final_time
				is_best = true
				_save_best_time(final_time)
			kz_timer_stopped.emit(final_time, is_best)
		else:
			kz_timer_invalid_stop.emit()
		return true
	return false


func _play_button_sound(pitch: float = 1.0) -> void:
	if button_sound_player and button_sound:
		button_sound_player.pitch_scale = pitch
		button_sound_player.play()


func _save_best_time(t: float) -> void:
	if is_inside_tree() and has_node("/root/SettingsManager"):
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			var m_name: String = bsp.map_name if (bsp and bsp.map_name != "") else str(sm.current_map_name)
			sm.set_best_time(m_name, t)


static func to_godot(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y) * UNIT


static func to_godot_dir(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


static func _ensure_input_actions() -> void:
	var keys := {
		"cs_forward": [KEY_W, KEY_UP], "cs_back": [KEY_S, KEY_DOWN], "cs_moveleft": [KEY_A], "cs_moveright": [KEY_D],
		"cs_jump": [KEY_SPACE], "cs_duck": [KEY_CTRL], "cs_walk": [KEY_SHIFT], "cs_use": [KEY_E],
		"cs_respawn": [KEY_R], "cs_noclip": [KEY_V], "cs_toggle_autobhop": [KEY_F2],
		"cs_toggle_speedcap": [KEY_F3], "cs_toggle_stamina": [KEY_F4], "cs_toggle_hud": [KEY_F1],
		"cs_toggle_ljstats": [KEY_F7],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
