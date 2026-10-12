class_name GoldSrcBsp
extends RefCounted
## Collision side of a GoldSrc (BSP v30) map: clip hulls, brush entities and the
## engine's hull tracing (PM_RecursiveHullCheck / PM_HullPointContents / PM_PlayerTrace).
## All coordinates are GoldSrc units, Z-up, exactly as pmove sees them.

const CONTENTS_EMPTY := -1
const CONTENTS_SOLID := -2
const CONTENTS_WATER := -3
const CONTENTS_LADDER := -16
const DIST_EPSILON := 0.03125

## Hull index as stored in the BSP: 0 point, 1 standing (32x32x72), 2 large (64x64x64), 3 ducked (32x32x36).
const HULL_CLIP_MINS := [Vector3.ZERO, Vector3(-16, -16, -36), Vector3(-32, -32, -32), Vector3(-16, -16, -18)]
const HULL_CLIP_MAXS := [Vector3.ZERO, Vector3(16, 16, 36), Vector3(32, 32, 32), Vector3(16, 16, 18)]
## pmove->usehull -> hull index (pm_shared PM_HullForBsp): 0 standing, 1 ducked, 2 point, 3 large.
const USEHULL_TO_HULL := [1, 3, 0, 2]
## pmove->player_mins / player_maxs indexed by usehull.
const PLAYER_MINS := [Vector3(-16, -16, -36), Vector3(-16, -16, -18), Vector3.ZERO, Vector3(-32, -32, -32)]
const PLAYER_MAXS := [Vector3(16, 16, 36), Vector3(16, 16, 18), Vector3.ZERO, Vector3(32, 32, 32)]

const LUMP_ENTITIES := 0
const LUMP_PLANES := 1
const LUMP_NODES := 5
const LUMP_CLIPNODES := 9
const LUMP_LEAVES := 10
const LUMP_MODELS := 14


class Hull:
	## Plane index / children of every node of this tree. Negative child = contents.
	var planes: PackedInt32Array
	var child0: PackedInt32Array
	var child1: PackedInt32Array
	var first: int
	var clip_mins: Vector3


class PhysEnt:
	var index: int
	var model: int
	var origin := Vector3.ZERO
	var solid := true
	## Brush contents for non-solid special volumes (ladders): pe->skin in the engine.
	var skin := 0
	var classname := ""
	var mins := Vector3.ZERO
	var maxs := Vector3.ZERO


class PmTrace:
	var allsolid := true
	var startsolid := false
	var inopen := false
	var inwater := false
	var fraction := 1.0
	var endpos := Vector3.ZERO
	var plane_normal := Vector3.ZERO
	var plane_dist := 0.0
	var ent := -1


var plane_normals := PackedVector3Array()
var plane_dists := PackedFloat64Array()
var plane_types := PackedInt32Array()
var map_name := ""
## Per model: Array[Hull] of 4 hulls.
var model_hulls: Array = []
var model_mins: Array[Vector3] = []
var model_maxs: Array[Vector3] = []
var entities: Array[Dictionary] = []
## Physics entities in pmove order: world first, then solid brush models and ladders.
var physents: Array[PhysEnt] = []
## Brush triggers (trigger_teleport ...) that pmove ignores but the game touches.
var triggers: Array[PhysEnt] = []


static func load_file(path: String) -> GoldSrcBsp:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		push_error("GoldSrcBsp: cannot read %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var bsp := GoldSrcBsp.new()
	bsp.map_name = path.replace("\\", "/").get_file().get_basename()
	if not bsp._parse(data):
		return null
	return bsp


func _lump(data: PackedByteArray, index: int) -> Vector2i:
	return Vector2i(data.decode_s32(4 + index * 8), data.decode_s32(8 + index * 8))


func _parse(data: PackedByteArray) -> bool:
	if data.decode_s32(0) != 30:
		push_error("GoldSrcBsp: unsupported BSP version %d" % data.decode_s32(0))
		return false

	var lump := _lump(data, LUMP_PLANES)
	for i in lump.y / 20:
		var o := lump.x + i * 20
		plane_normals.append(Vector3(data.decode_float(o), data.decode_float(o + 4), data.decode_float(o + 8)))
		plane_dists.append(data.decode_float(o + 12))
		plane_types.append(data.decode_s32(o + 16))

	# Clip hulls 1..3 share the CLIPNODES lump.
	var clip_planes := PackedInt32Array()
	var clip_c0 := PackedInt32Array()
	var clip_c1 := PackedInt32Array()
	lump = _lump(data, LUMP_CLIPNODES)
	for i in lump.y / 8:
		var o := lump.x + i * 8
		clip_planes.append(data.decode_s32(o))
		clip_c0.append(data.decode_s16(o + 4))
		clip_c1.append(data.decode_s16(o + 6))

	# Hull 0 is built from the render BSP: node children < 0 point at leaves -> leaf contents.
	var leaf_lump := _lump(data, LUMP_LEAVES)
	var leaf_contents := PackedInt32Array()
	for i in leaf_lump.y / 28:
		leaf_contents.append(data.decode_s32(leaf_lump.x + i * 28))
	var node_planes := PackedInt32Array()
	var node_c0 := PackedInt32Array()
	var node_c1 := PackedInt32Array()
	lump = _lump(data, LUMP_NODES)
	for i in lump.y / 24:
		var o := lump.x + i * 24
		node_planes.append(data.decode_s32(o))
		var a := data.decode_s16(o + 4)
		var b := data.decode_s16(o + 6)
		node_c0.append(a if a >= 0 else leaf_contents[-1 - a])
		node_c1.append(b if b >= 0 else leaf_contents[-1 - b])

	lump = _lump(data, LUMP_MODELS)
	for i in lump.y / 64:
		var o := lump.x + i * 64
		model_mins.append(Vector3(data.decode_float(o), data.decode_float(o + 4), data.decode_float(o + 8)))
		model_maxs.append(Vector3(data.decode_float(o + 12), data.decode_float(o + 16), data.decode_float(o + 20)))
		var hulls: Array[Hull] = []
		for h in 4:
			var hull := Hull.new()
			hull.first = data.decode_s32(o + 36 + h * 4)
			hull.clip_mins = HULL_CLIP_MINS[h]
			if h == 0:
				hull.planes = node_planes
				hull.child0 = node_c0
				hull.child1 = node_c1
			else:
				hull.planes = clip_planes
				hull.child0 = clip_c0
				hull.child1 = clip_c1
			hulls.append(hull)
		model_hulls.append(hulls)

	lump = _lump(data, LUMP_ENTITIES)
	entities = _parse_entities(data.slice(lump.x, lump.x + lump.y).get_string_from_ascii())
	_build_physents()
	return true


static func _parse_entities(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var block_re := RegEx.create_from_string("\\{([^{}]*)\\}")
	var kv_re := RegEx.create_from_string("\"([^\"]*)\"\\s+\"([^\"]*)\"")
	for block in block_re.search_all(text):
		var ent := {}
		for kv in kv_re.search_all(block.get_string(1)):
			ent[kv.get_string(1)] = kv.get_string(2)
		out.append(ent)
	return out


static func parse_vec(value: String) -> Vector3:
	var parts := value.split(" ", false)
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())


func _make_physent(model: int, ent: Dictionary) -> PhysEnt:
	var pe := PhysEnt.new()
	pe.model = model
	pe.classname = ent.get("classname", "")
	pe.origin = parse_vec(ent["origin"]) if ent.has("origin") else Vector3.ZERO
	pe.mins = model_mins[model] + pe.origin
	pe.maxs = model_maxs[model] + pe.origin
	return pe


## Mirrors what the game DLL links into pmove: world + SOLID_BSP brush entities, plus
## non-solid brush volumes with special contents (func_ladder -> CONTENTS_LADDER).
func _build_physents() -> void:
	var world := PhysEnt.new()
	world.model = 0
	world.classname = "worldspawn"
	world.mins = model_mins[0]
	world.maxs = model_maxs[0]
	physents.append(world)
	const SOLID_CLASSES := ["func_wall", "func_breakable", "func_door", "func_door_rotating", "func_button",
		"func_pushable", "func_plat", "func_train", "func_tracktrain", "func_wall_toggle", "func_rotating",
		"func_conveyor", "func_vehicle", "func_guntarget", "momentary_door"]
	for ent in entities:
		var model_key: String = ent.get("model", "")
		if not model_key.begins_with("*"):
			continue
		var model := model_key.substr(1).to_int()
		if model <= 0 or model >= model_hulls.size():
			continue
		var cls: String = ent.get("classname", "")
		if cls in SOLID_CLASSES:
			physents.append(_make_physent(model, ent))
		elif cls == "func_ladder":
			var pe := _make_physent(model, ent)
			pe.solid = false
			pe.skin = CONTENTS_LADDER
			physents.append(pe)
		elif cls.begins_with("trigger_"):
			var trig := _make_physent(model, ent)
			trig.solid = false
			triggers.append(trig)
	for i in physents.size():
		physents[i].index = i


func hull_for(pe: PhysEnt, usehull: int) -> Hull:
	return model_hulls[pe.model][USEHULL_TO_HULL[usehull]]


## PM_HullForBsp offset: hull->clip_mins - player_mins[usehull] + pe->origin.
func hull_offset(pe: PhysEnt, usehull: int) -> Vector3:
	return hull_for(pe, usehull).clip_mins - PLAYER_MINS[usehull] + pe.origin


func hull_point_contents(hull: Hull, num: int, p: Vector3) -> int:
	while num >= 0:
		var pi := hull.planes[num]
		var t := plane_types[pi]
		var d: float
		if t < 3:
			d = p[t] - plane_dists[pi]
		else:
			d = plane_normals[pi].dot(p) - plane_dists[pi]
		num = hull.child1[num] if d < 0.0 else hull.child0[num]
	return num


func recursive_hull_check(hull: Hull, num: int, p1f: float, p2f: float, p1: Vector3, p2: Vector3, trace: PmTrace) -> bool:
	if num < 0:
		if num != CONTENTS_SOLID:
			trace.allsolid = false
			if num == CONTENTS_EMPTY:
				trace.inopen = true
			else:
				trace.inwater = true
		else:
			trace.startsolid = true
		return true

	var pi := hull.planes[num]
	var t := plane_types[pi]
	var normal := plane_normals[pi]
	var dist := plane_dists[pi]
	var t1: float
	var t2: float
	if t < 3:
		t1 = p1[t] - dist
		t2 = p2[t] - dist
	else:
		t1 = normal.dot(p1) - dist
		t2 = normal.dot(p2) - dist

	if t1 >= 0.0 and t2 >= 0.0:
		return recursive_hull_check(hull, hull.child0[num], p1f, p2f, p1, p2, trace)
	if t1 < 0.0 and t2 < 0.0:
		return recursive_hull_check(hull, hull.child1[num], p1f, p2f, p1, p2, trace)

	# Put the crosspoint DIST_EPSILON units on the near side.
	var frac: float
	if t1 < 0.0:
		frac = (t1 + DIST_EPSILON) / (t1 - t2)
	else:
		frac = (t1 - DIST_EPSILON) / (t1 - t2)
	frac = clampf(frac, 0.0, 1.0)

	var midf := p1f + (p2f - p1f) * frac
	var mid := p1 + (p2 - p1) * frac
	var side := 1 if t1 < 0.0 else 0
	var near_child := hull.child1[num] if side == 1 else hull.child0[num]
	var far_child := hull.child0[num] if side == 1 else hull.child1[num]

	if not recursive_hull_check(hull, near_child, p1f, midf, p1, mid, trace):
		return false

	if hull_point_contents(hull, far_child, mid) != CONTENTS_SOLID:
		return recursive_hull_check(hull, far_child, midf, p2f, mid, p2, trace)

	if trace.allsolid:
		return false

	# The other side of the node is solid: this is the impact point.
	if side == 0:
		trace.plane_normal = normal
		trace.plane_dist = dist
	else:
		trace.plane_normal = -normal
		trace.plane_dist = -dist

	while hull_point_contents(hull, hull.first, mid) == CONTENTS_SOLID:
		# Shouldn't really happen, but does occasionally.
		frac -= 0.1
		if frac < 0.0:
			trace.fraction = midf
			trace.endpos = mid
			return false
		midf = p1f + (p2f - p1f) * frac
		mid = p1 + (p2 - p1) * frac

	trace.fraction = midf
	trace.endpos = mid
	return false


## pmovetst.c _PM_PlayerTrace: sweep the player hull against every solid physent, keep the closest hit.
func player_trace(start: Vector3, end: Vector3, usehull: int) -> PmTrace:
	var total := PmTrace.new()
	total.allsolid = false
	total.endpos = end
	for pe in physents:
		if not pe.solid:
			continue  # ladders / water volumes do not block
		var hull := hull_for(pe, usehull)
		var offset := hull_offset(pe, usehull)
		var trace := PmTrace.new()
		trace.endpos = end
		recursive_hull_check(hull, hull.first, 0.0, 1.0, start - offset, end - offset, trace)
		if trace.allsolid:
			trace.startsolid = true
		if trace.startsolid:
			trace.fraction = 0.0
		if trace.fraction < total.fraction:
			trace.endpos = trace.endpos + offset if trace.fraction < 1.0 else end
			trace.ent = pe.index
			total = trace
	return total


## PM_TestPlayerPosition: index of the first solid physent the hull overlaps at `pos`, or -1.
func test_player_position(pos: Vector3, usehull: int) -> int:
	for pe in physents:
		if not pe.solid:
			continue
		var hull := hull_for(pe, usehull)
		if hull_point_contents(hull, hull.first, pos - hull_offset(pe, usehull)) == CONTENTS_SOLID:
			return pe.index
	return -1


## PM_PointContents: world hull 0, then special-contents volumes.
func point_contents(p: Vector3) -> int:
	var world_hull: Hull = model_hulls[0][0]
	var contents := hull_point_contents(world_hull, world_hull.first, p)
	if contents == CONTENTS_SOLID:
		return contents
	for pe in physents:
		if pe.solid or pe.skin == 0:
			continue
		var hull: Hull = model_hulls[pe.model][0]
		if hull_point_contents(hull, hull.first, p - pe.origin) != CONTENTS_EMPTY:
			return pe.skin
	return contents


## PM_TraceModel: point (hull 0) trace against a single brush model.
func trace_model(pe: PhysEnt, start: Vector3, end: Vector3) -> PmTrace:
	var hull: Hull = model_hulls[pe.model][0]
	var trace := PmTrace.new()
	trace.endpos = end
	recursive_hull_check(hull, hull.first, 0.0, 1.0, start - pe.origin, end - pe.origin, trace)
	trace.endpos += pe.origin
	return trace


## SV_TouchLinks accuracy test for brush triggers: player's absbox overlaps and origin is inside the
## trigger's clip hull for the current player size.
func touching_trigger(trig: PhysEnt, origin: Vector3, usehull: int) -> bool:
	var absmin: Vector3 = origin + PLAYER_MINS[usehull]
	var absmax: Vector3 = origin + PLAYER_MAXS[usehull]
	if absmin.x > trig.maxs.x or absmin.y > trig.maxs.y or absmin.z > trig.maxs.z:
		return false
	if absmax.x < trig.mins.x or absmax.y < trig.mins.y or absmax.z < trig.mins.z:
		return false
	var hull := hull_for(trig, usehull)
	return hull_point_contents(hull, hull.first, origin - hull_offset(trig, usehull)) == CONTENTS_SOLID


func find_entities(key: String, value: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ent in entities:
		if ent.get(key, "") == value:
			out.append(ent)
	return out
