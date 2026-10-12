class_name CSPlayerMove
extends RefCounted
## Counter-Strike 1.6 player movement (pm_shared.cpp, as reproduced by ReGameDLL_CS) running on the
## map's real GoldSrc clip hulls. Units are GoldSrc units (1 unit = 1 inch), Z-up, degrees.
## One call to player_move() == one usercmd (the engine runs one per client frame; msec is integer).

const IN_ATTACK := 1 << 0
const IN_JUMP := 1 << 1
const IN_DUCK := 1 << 2
const IN_FORWARD := 1 << 3
const IN_BACK := 1 << 4
const IN_USE := 1 << 5
const IN_MOVELEFT := 1 << 9
const IN_MOVERIGHT := 1 << 10

const FL_ONGROUND := 1 << 9
const FL_DUCKING := 1 << 14

enum MoveType { WALK = 3, FLY = 5, NOCLIP = 8 }

const MAX_CLIP_PLANES := 5
const STOP_EPSILON := 0.1
const PM_VEC_VIEW := 17.0
const PM_VEC_DUCK_VIEW := 12.0
const PM_VEC_HULL_MIN := -36.0
const PM_VEC_DUCK_HULL_MIN := -18.0
const TIME_TO_DUCK := 0.4
const PLAYER_DUCKING_MULTIPLIER := 0.333
const BUNNYJUMP_MAX_SPEED_FACTOR := 1.2
const MAX_CLIMB_SPEED := 200.0
const PLAYER_FALL_PUNCH_THRESHHOLD := 350.0
const PLAYER_MAX_SAFE_FALL_SPEED := 580.0
const PLAYER_FATAL_FALL_SPEED := 1024.0
const DAMAGE_FOR_FALL_SPEED := 100.0 / (PLAYER_FATAL_FALL_SPEED - PLAYER_MAX_SAFE_FALL_SPEED) # ~0.225225
const JUMP_STAMINA := 1315.789429
const STUCK_MOVEUP := 1.0

var fall_damage_enabled := true
var last_fall_damage := 0.0

## Server / movevars defaults of a stock CS 1.6 server.
var sv_gravity := 800.0
var sv_stopspeed := 75.0
var sv_maxspeed := 320.0
var sv_accelerate := 5.0
var sv_airaccelerate := 10.0
var sv_friction := 4.0
var edgefriction := 2.0
var stepsize := 18.0
var sv_maxvelocity := 2000.0
var sv_bounce := 1.0
## pev->maxspeed set by the held weapon: knife = 250 (35hp maps are knife-only).
var client_maxspeed := 250.0

## Optional deviations used by bhop servers. Defaults reproduce vanilla CS 1.6.
var bhop_speed_cap := true  ## PM_PreventMegaBunnyJumping (1.2 x maxspeed)
var jump_stamina := true  ## fuser2 landing slowdown and reduced jump height

var bsp: GoldSrcBsp

# --- pmove state (persistent between commands) ---
var origin := Vector3.ZERO
var velocity := Vector3.ZERO
var basevelocity := Vector3.ZERO
var angles := Vector3.ZERO  ## pitch, yaw, roll
var view_ofs := Vector3(0, 0, PM_VEC_VIEW)
var punchangle := Vector3.ZERO
var usehull := 0
var flags := 0
var in_duck := false
var duck_time := 0.0  ## ms
var fuser2 := 0.0  ## jump stamina, ms
var onground := -1
var oldbuttons := 0
var movetype: MoveType = MoveType.WALK
var waterlevel := 0
var waterjumptime := 0.0
var fall_velocity := 0.0
var friction := 1.0
var gravity := 1.0
var dead := false

# --- per command ---
var frametime := 0.0
var maxspeed := 0.0
var forwardmove := 0.0
var sidemove := 0.0
var upmove := 0.0
var buttons := 0
var forward := Vector3.ZERO
var right := Vector3.ZERO
var up := Vector3.ZERO

## Diagnostics for the HUD / tests.
var jumped := false
var last_trace_allsolid := false

var _stuck_table: Array[Vector3] = []


func _init(map: GoldSrcBsp) -> void:
	bsp = map
	_init_stuck_table()


func spawn(at: Vector3, yaw: float) -> void:
	origin = at
	velocity = Vector3.ZERO
	angles = Vector3(0, yaw, 0)
	punchangle = Vector3.ZERO
	view_ofs = Vector3(0, 0, PM_VEC_VIEW)
	usehull = 0
	flags = 0
	in_duck = false
	duck_time = 0.0
	fuser2 = 0.0
	onground = -1
	oldbuttons = 0
	movetype = MoveType.WALK
	fall_velocity = 0.0


func player_move(cmd_forward: float, cmd_side: float, cmd_up: float, cmd_buttons: int, view_angles: Vector3, msec: int) -> void:
	forwardmove = cmd_forward
	sidemove = cmd_side
	upmove = cmd_up
	buttons = cmd_buttons
	frametime = msec * 0.001
	jumped = false

	_check_parameters(view_angles)
	_reduce_timers(msec)
	_angle_vectors(angles)

	if movetype != MoveType.NOCLIP:
		if _check_stuck():
			return

	_categorize_position()

	if onground == -1:
		fall_velocity = -velocity.z

	var ladder: GoldSrcBsp.PhysEnt = null
	if not dead:
		ladder = _find_ladder()

	_duck()

	if not dead:
		if ladder != null:
			_ladder_move(ladder)
		elif movetype != MoveType.WALK and movetype != MoveType.NOCLIP:
			movetype = MoveType.WALK

	if onground != -1 and (buttons & IN_USE):
		velocity *= 0.3

	match movetype:
		MoveType.NOCLIP:
			_noclip()
		MoveType.FLY:
			if buttons & IN_JUMP:
				if ladder == null:
					_jump()
			else:
				oldbuttons &= ~IN_JUMP
			velocity += basevelocity
			_fly_move()
			velocity -= basevelocity
		MoveType.WALK:
			_add_correct_gravity()
			if buttons & IN_JUMP:
				if ladder == null:
					_jump()
			else:
				oldbuttons &= ~IN_JUMP

			# Friction is handled before base velocity is added.
			if onground != -1:
				velocity.z = 0.0
				_friction()

			_check_velocity()

			if onground != -1:
				_walk_move()
			else:
				_air_move()

			_categorize_position()
			velocity -= basevelocity
			_check_velocity()
			_fixup_gravity_velocity()

			if onground != -1:
				velocity.z = 0.0

			_check_falling()


# ----------------------------------------------------------------------------- setup

func _check_parameters(view_angles: Vector3) -> void:
	maxspeed = sv_maxspeed
	if client_maxspeed != 0.0:
		maxspeed = minf(client_maxspeed, maxspeed)

	var spd := sqrt(forwardmove * forwardmove + sidemove * sidemove + upmove * upmove)
	if spd != 0.0 and spd > maxspeed:
		var ratio := maxspeed / spd
		forwardmove *= ratio
		sidemove *= ratio
		upmove *= ratio

	if dead:
		forwardmove = 0.0
		sidemove = 0.0
		upmove = 0.0

	_drop_punch_angle()

	if not dead:
		var v_angle := view_angles + punchangle
		angles = Vector3(v_angle.x, v_angle.y, 0.0)  # sv_rollangle is 0 in CS 1.6
	if angles.y > 180.0:
		angles.y -= 360.0


func _reduce_timers(msec: int) -> void:
	if duck_time > 0.0:
		duck_time = maxf(duck_time - msec, 0.0)
	if fuser2 > 0.0:
		fuser2 = maxf(fuser2 - msec, 0.0)


func _drop_punch_angle() -> void:
	var length := punchangle.length()
	if length == 0.0:
		return
	var dir := punchangle / length
	length = maxf(length - (10.0 + length * 0.5) * frametime, 0.0)
	punchangle = dir * length


func _angle_vectors(a: Vector3) -> void:
	var yaw := deg_to_rad(a.y)
	var pitch := deg_to_rad(a.x)
	var roll := deg_to_rad(a.z)
	var sy := sin(yaw)
	var cy := cos(yaw)
	var sp := sin(pitch)
	var cp := cos(pitch)
	var sr := sin(roll)
	var cr := cos(roll)
	forward = Vector3(cp * cy, cp * sy, -sp)
	right = Vector3(-sr * sp * cy + cr * sy, -sr * sp * sy - cr * cy, -sr * cp)
	up = Vector3(cr * sp * cy + sr * sy, cr * sp * sy - sr * cy, cr * cp)


# ----------------------------------------------------------------------------- traces

func _trace(start: Vector3, end: Vector3) -> GoldSrcBsp.PmTrace:
	return bsp.player_trace(start, end, usehull)


func _init_stuck_table() -> void:
	var zi := [0.0, 1.0, 6.0]
	for z in [-0.125, 0.0, 0.125]:
		_stuck_table.append(Vector3(0, 0, z))
	for y in [-0.125, 0.0, 0.125]:
		_stuck_table.append(Vector3(0, y, 0))
	for x in [-0.125, 0.0, 0.125]:
		_stuck_table.append(Vector3(x, 0, 0))
	for x in [-0.125, 0.125]:
		for y in [-0.125, 0.125]:
			for z in [-0.125, 0.125]:
				_stuck_table.append(Vector3(x, y, z))
	for z in zi:
		_stuck_table.append(Vector3(0, 0, z))
	for y in [-2.0, 0.0, 2.0]:
		_stuck_table.append(Vector3(0, y, 0))
	for x in [-2.0, 0.0, 2.0]:
		_stuck_table.append(Vector3(x, 0, 0))
	for z in zi:
		for x in [-2.0, 0.0, 2.0]:
			for y in [-2.0, 0.0, 2.0]:
				_stuck_table.append(Vector3(x, y, z))


## PM_CheckStuck (client path): nudge out of solids using the engine's stuck-offset table.
func _check_stuck() -> bool:
	if bsp.test_player_position(origin, usehull) == -1:
		return false
	var base := origin
	for offset in _stuck_table:
		var test := base + offset
		if bsp.test_player_position(test, usehull) == -1:
			origin = test
			return false
	return true


func _categorize_position() -> void:
	var point := Vector3(origin.x, origin.y, origin.z - 2.0)
	if velocity.z > 180.0:
		onground = -1
		return
	var tr := _trace(origin, point)
	if tr.plane_normal.z < 0.7:
		onground = -1
	else:
		onground = tr.ent
	if onground != -1:
		waterjumptime = 0.0
		if waterlevel < 2 and not tr.startsolid and not tr.allsolid:
			origin = tr.endpos


# ----------------------------------------------------------------------------- velocity helpers

func _check_velocity() -> void:
	for i in 3:
		if is_nan(velocity[i]):
			velocity[i] = 0.0
		if is_nan(origin[i]):
			origin[i] = 0.0
		velocity[i] = clampf(velocity[i], -sv_maxvelocity, sv_maxvelocity)


func _add_correct_gravity() -> void:
	if waterjumptime != 0.0:
		return
	var ent_gravity := gravity if gravity != 0.0 else 1.0
	# Yes, this 0.5 looks wrong, but it's not: the other half is applied after the move.
	velocity.z -= ent_gravity * sv_gravity * 0.5 * frametime
	velocity.z += basevelocity.z * frametime
	basevelocity.z = 0.0
	_check_velocity()


func _fixup_gravity_velocity() -> void:
	if waterjumptime != 0.0:
		return
	var ent_gravity := gravity if gravity != 0.0 else 1.0
	velocity.z -= ent_gravity * sv_gravity * frametime * 0.5
	_check_velocity()


static func clip_velocity(inv: Vector3, normal: Vector3, overbounce: float) -> Vector3:
	var backoff := inv.dot(normal) * overbounce
	var out := Vector3.ZERO
	for i in 3:
		var v: float = inv[i] - normal[i] * backoff
		out[i] = 0.0 if (v > -STOP_EPSILON and v < STOP_EPSILON) else v
	return out


func _accelerate(wishdir: Vector3, wishspeed: float, accel: float) -> void:
	if dead or waterjumptime != 0.0:
		return
	var addspeed := wishspeed - velocity.dot(wishdir)
	if addspeed <= 0.0:
		return
	var accelspeed := minf(accel * frametime * wishspeed * friction, addspeed)
	velocity += wishdir * accelspeed


func _air_accelerate(wishdir: Vector3, wishspeed: float, accel: float) -> void:
	if dead or waterjumptime != 0.0:
		return
	var wishspd := minf(wishspeed, 30.0)
	var addspeed := wishspd - velocity.dot(wishdir)
	if addspeed <= 0.0:
		return
	var accelspeed := minf(accel * wishspeed * frametime * friction, addspeed)
	velocity += wishdir * accelspeed


func _friction() -> void:
	if waterjumptime != 0.0:
		return
	var speed := velocity.length()
	if speed < 0.1:
		return
	var drop := 0.0
	if onground != -1:
		var start := Vector3(origin.x + velocity.x / speed * 16.0, origin.y + velocity.y / speed * 16.0,
			origin.z + GoldSrcBsp.PLAYER_MINS[usehull].z)
		var stop := Vector3(start.x, start.y, start.z - 34.0)
		var tr := _trace(start, stop)
		var fric := sv_friction * edgefriction if tr.fraction == 1.0 else sv_friction
		fric *= friction
		var control := sv_stopspeed if speed < sv_stopspeed else speed
		drop += control * fric * frametime
	var newspeed := maxf(speed - drop, 0.0) / speed
	velocity *= newspeed


func _wish(flatten: bool) -> Array:
	var f := forward
	var r := right
	if flatten:
		f.z = 0.0
		r.z = 0.0
		f = f.normalized()
		r = r.normalized()
	var wishvel := Vector3(f.x * forwardmove + r.x * sidemove, f.y * forwardmove + r.y * sidemove, 0.0)
	var wishspeed := wishvel.length()
	var wishdir := wishvel / wishspeed if wishspeed > 0.0 else Vector3.ZERO
	if wishspeed > maxspeed:
		wishvel *= maxspeed / wishspeed
		wishspeed = maxspeed
	return [wishdir, wishspeed]


# ----------------------------------------------------------------------------- movement

func _fly_move() -> int:
	var numbumps := 4
	var blocked := 0
	var numplanes := 0
	var planes: Array[Vector3] = []
	planes.resize(MAX_CLIP_PLANES)
	var original_velocity := velocity
	var primal_velocity := velocity
	var new_velocity := Vector3.ZERO
	var all_fraction := 0.0
	var time_left := frametime

	for bumpcount in numbumps:
		if velocity == Vector3.ZERO:
			break
		var end := origin + velocity * time_left
		var tr := _trace(origin, end)
		all_fraction += tr.fraction

		if tr.allsolid:
			velocity = Vector3.ZERO
			last_trace_allsolid = true
			return 4

		if tr.fraction > 0.0:
			origin = tr.endpos
			original_velocity = velocity
			numplanes = 0

		if tr.fraction == 1.0:
			break

		if tr.plane_normal.z > 0.7:
			blocked |= 1
		if tr.plane_normal.z == 0.0:
			blocked |= 2

		time_left -= time_left * tr.fraction

		if numplanes >= MAX_CLIP_PLANES:
			velocity = Vector3.ZERO
			break

		planes[numplanes] = tr.plane_normal
		numplanes += 1

		if movetype == MoveType.WALK and (onground == -1 or friction != 1.0):
			# Airborne: reflect off every plane (this is what makes surfing and ramp slides work).
			for i in numplanes:
				if planes[i].z > 0.7:
					new_velocity = clip_velocity(original_velocity, planes[i], 1.0)
					original_velocity = new_velocity
				else:
					new_velocity = clip_velocity(original_velocity, planes[i], 1.0 + sv_bounce * (1.0 - friction))
			velocity = new_velocity
			original_velocity = new_velocity
		else:
			var i := 0
			while i < numplanes:
				velocity = clip_velocity(original_velocity, planes[i], 1.0)
				var j := 0
				while j < numplanes:
					if j != i and velocity.dot(planes[j]) < 0.0:
						break
					j += 1
				if j == numplanes:
					break
				i += 1

			if i == numplanes:
				# Go along the crease.
				if numplanes != 2:
					velocity = Vector3.ZERO
					break
				var dir := planes[0].cross(planes[1])
				velocity = dir * dir.dot(velocity)

			if velocity.dot(primal_velocity) <= 0.0:
				velocity = Vector3.ZERO
				break

	if all_fraction == 0.0:
		velocity = Vector3.ZERO
	return blocked


func _walk_move() -> void:
	if jump_stamina and fuser2 > 0.0:
		var ratio := (100.0 - fuser2 * 0.001 * 19.0) * 0.01
		velocity.x *= ratio
		velocity.y *= ratio

	var wish := _wish(true)
	var wishdir: Vector3 = wish[0]
	var wishspeed: float = wish[1]

	velocity.z = 0.0
	_accelerate(wishdir, wishspeed, sv_accelerate)
	velocity.z = 0.0

	velocity += basevelocity
	if velocity.length() < 1.0:
		velocity = Vector3.ZERO
		return

	var oldonground := onground
	var dest := Vector3(origin.x + velocity.x * frametime, origin.y + velocity.y * frametime, origin.z)
	var tr := _trace(origin, dest)
	if tr.fraction == 1.0:
		origin = tr.endpos
		return

	if oldonground == -1 and waterlevel == 0:
		return
	if waterjumptime != 0.0:
		return

	# Try sliding forward both on ground and up 16 pixels; take the move that goes farthest.
	var original := origin
	var originalvel := velocity

	_fly_move()
	var down := origin
	var downvel := velocity

	origin = original
	velocity = originalvel

	dest = origin
	dest.z += stepsize
	tr = _trace(origin, dest)
	if not tr.startsolid and not tr.allsolid:
		origin = tr.endpos

	_fly_move()

	dest = origin
	dest.z -= stepsize
	tr = _trace(origin, dest)

	if tr.plane_normal.z < 0.7:
		origin = down
		velocity = downvel
		return

	if not tr.startsolid and not tr.allsolid:
		origin = tr.endpos
	var up_pos := origin

	var downdist := (down.x - original.x) * (down.x - original.x) + (down.y - original.y) * (down.y - original.y)
	var updist := (up_pos.x - original.x) * (up_pos.x - original.x) + (up_pos.y - original.y) * (up_pos.y - original.y)
	if downdist > updist:
		origin = down
		velocity = downvel
	else:
		velocity.z = downvel.z


func _air_move() -> void:
	var wish := _wish(true)
	_air_accelerate(wish[0], wish[1], sv_airaccelerate)
	velocity += basevelocity
	_fly_move()


func _prevent_mega_bunny_jumping() -> void:
	var maxscaledspeed := BUNNYJUMP_MAX_SPEED_FACTOR * maxspeed
	if maxscaledspeed <= 0.0:
		return
	var spd := velocity.length()
	if spd <= maxscaledspeed:
		return
	velocity *= (maxscaledspeed / spd) * 0.8


func _jump() -> void:
	if dead:
		oldbuttons |= IN_JUMP
		return
	if waterjumptime != 0.0:
		waterjumptime = maxf(waterjumptime - frametime * 1000.0, 0.0)
		return
	if onground == -1:
		oldbuttons |= IN_JUMP
		return
	if oldbuttons & IN_JUMP:
		return  # don't pogo stick

	onground = -1
	if bhop_speed_cap:
		_prevent_mega_bunny_jumping()

	velocity.z = sqrt(2.0 * 800.0 * 45.0)
	if jump_stamina and fuser2 > 0.0:
		velocity.z *= (100.0 - fuser2 * 0.001 * 19.0) * 0.01
	fuser2 = JUMP_STAMINA

	_fixup_gravity_velocity()
	oldbuttons |= IN_JUMP
	jumped = true


func _check_falling() -> void:
	if onground != -1 and not dead:
		if fall_velocity >= PLAYER_FALL_PUNCH_THRESHHOLD:
			punchangle.z = fall_velocity * 0.013
			punchangle.x = minf(punchangle.x + 8.0, 8.0)
		if fall_damage_enabled and fall_velocity > PLAYER_MAX_SAFE_FALL_SPEED:
			var dmg := (fall_velocity - PLAYER_MAX_SAFE_FALL_SPEED) * DAMAGE_FOR_FALL_SPEED
			last_fall_damage = dmg
	if onground != -1:
		fall_velocity = 0.0


func _noclip() -> void:
	var f := forward.normalized()
	var r := right.normalized()
	var wishvel := f * forwardmove + r * sidemove
	wishvel.z += upmove
	origin += wishvel * frametime
	velocity = Vector3.ZERO


# ----------------------------------------------------------------------------- duck

static func _spline_fraction(value: float, scale: float) -> float:
	value = scale * value
	var sq := value * value
	return 3.0 * sq - 2.0 * sq * value


func _fix_player_crouch_stuck(direction: float) -> void:
	if bsp.test_player_position(origin, usehull) == -1:
		return
	var test := origin
	for i in 36:
		origin.z += direction
		if bsp.test_player_position(origin, usehull) == -1:
			return
	origin = test


func _unduck() -> void:
	var new_origin := origin
	if onground != -1:
		new_origin.z += GoldSrcBsp.PLAYER_MINS[1].z - GoldSrcBsp.PLAYER_MINS[0].z
	var tr := bsp.player_trace(new_origin, new_origin, usehull)
	if tr.startsolid:
		return
	usehull = 0
	tr = bsp.player_trace(new_origin, new_origin, usehull)
	if tr.startsolid:
		usehull = 1  # stay ducked until there is room
		return
	flags &= ~FL_DUCKING
	in_duck = false
	view_ofs.z = PM_VEC_VIEW
	duck_time = 0.0
	origin = new_origin
	_categorize_position()


func _duck() -> void:
	var buttons_changed := oldbuttons ^ buttons
	var pressed := buttons_changed & buttons

	if buttons & IN_DUCK:
		oldbuttons |= IN_DUCK
	else:
		oldbuttons &= ~IN_DUCK

	if dead:
		return

	if flags & FL_DUCKING:
		forwardmove *= PLAYER_DUCKING_MULTIPLIER
		sidemove *= PLAYER_DUCKING_MULTIPLIER
		upmove *= PLAYER_DUCKING_MULTIPLIER

	if (buttons & IN_DUCK) or in_duck or (flags & FL_DUCKING):
		if buttons & IN_DUCK:
			if (pressed & IN_DUCK) and not (flags & FL_DUCKING):
				duck_time = 1000.0  # 1 second so super long jump would work
				in_duck = true
			var time := maxf(0.0, 1.0 - duck_time / 1000.0)
			if in_duck:
				if (duck_time / 1000.0 <= 1.0 - TIME_TO_DUCK) or onground == -1:
					usehull = 1
					view_ofs.z = PM_VEC_DUCK_VIEW
					flags |= FL_DUCKING
					in_duck = false
					# HACKHACK from the SDK: keep feet on the floor when ducking on ground.
					if onground != -1:
						origin.z -= GoldSrcBsp.PLAYER_MINS[1].z - GoldSrcBsp.PLAYER_MINS[0].z
						_fix_player_crouch_stuck(STUCK_MOVEUP)
						_categorize_position()
				else:
					var more := PM_VEC_DUCK_HULL_MIN - PM_VEC_HULL_MIN
					var duck_fraction := _spline_fraction(time, 1.0 / TIME_TO_DUCK)
					view_ofs.z = (PM_VEC_DUCK_VIEW - more) * duck_fraction + PM_VEC_VIEW * (1.0 - duck_fraction)
		else:
			_unduck()


# ----------------------------------------------------------------------------- ladders

func _find_ladder() -> GoldSrcBsp.PhysEnt:
	for pe in bsp.physents:
		if pe.skin != GoldSrcBsp.CONTENTS_LADDER:
			continue
		var hull := bsp.hull_for(pe, usehull)
		var test := origin - bsp.hull_offset(pe, usehull)
		if bsp.hull_point_contents(hull, hull.first, test) == GoldSrcBsp.CONTENTS_EMPTY:
			continue
		return pe
	return null


func _ladder_move(ladder: GoldSrcBsp.PhysEnt) -> void:
	if movetype == MoveType.NOCLIP:
		return
	var ladder_center := (bsp.model_mins[ladder.model] + bsp.model_maxs[ladder.model]) * 0.5 + ladder.origin
	movetype = MoveType.FLY

	var floor_point := origin
	floor_point.z += GoldSrcBsp.PLAYER_MINS[usehull].z - 1.0
	var on_floor := bsp.point_contents(floor_point) == GoldSrcBsp.CONTENTS_SOLID

	gravity = 0.0
	var tr := bsp.trace_model(ladder, origin, ladder_center)
	if tr.fraction == 1.0:
		return

	var fwd := 0.0
	var rgt := 0.0
	var speed := minf(MAX_CLIMB_SPEED, maxspeed)
	var vpn := forward
	var v_right := right
	if flags & FL_DUCKING:
		speed *= PLAYER_DUCKING_MULTIPLIER
	if buttons & IN_BACK:
		fwd -= speed
	if buttons & IN_FORWARD:
		fwd += speed
	if buttons & IN_MOVELEFT:
		rgt -= speed
	if buttons & IN_MOVERIGHT:
		rgt += speed

	if buttons & IN_JUMP:
		movetype = MoveType.WALK
		velocity = tr.plane_normal * 270.0
	elif fwd != 0.0 or rgt != 0.0:
		var vel := vpn * fwd + v_right * rgt
		var perp := Vector3(0, 0, 1).cross(tr.plane_normal).normalized()
		var normal := vel.dot(tr.plane_normal)
		var cross := tr.plane_normal * normal
		var lateral := vel - cross
		var tmp := tr.plane_normal.cross(perp)
		velocity = lateral - tmp * normal
		if on_floor and normal > 0.0:
			velocity += tr.plane_normal * MAX_CLIMB_SPEED
	else:
		velocity = Vector3.ZERO


func is_ducking() -> bool:
	return (flags & FL_DUCKING) != 0


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.y).length()
