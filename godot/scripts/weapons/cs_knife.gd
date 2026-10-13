class_name CSKnife
extends Node3D
## First-person CS 1.6 Knife viewmodel:
## Plays GoldSrc draw, idle, slash and stab animations, with authentic weapon sway & bobbing.

signal attack_hit(is_secondary: bool)

@export var sway_amount := 0.0006
@export var sway_max := 0.03
@export var sway_smooth := 8.0
## GoldSrc draws v_ models at the view origin with the view angles; the converter already
## maps model space to Godot axes and units, so no extra placement is needed.
@export var viewmodel_offset := Vector3.ZERO
@export var viewmodel_rotation := Vector3.ZERO
@export var viewmodel_scale := 1.0

var _anim: AnimationPlayer
var _is_attacking := false
var _slash_index := 0
var _is_inspecting := false
var _is_drawing := false
var _roles: Dictionary = {}
var _inspect_anim := ""

var _base_transform: Transform3D
var _sway_offset := Vector3.ZERO
var _bob_offset := Vector3.ZERO
var _target_sway := Vector3.ZERO


func _ready() -> void:
	rotation_degrees = viewmodel_rotation
	position = viewmodel_offset
	scale = Vector3.ONE * viewmodel_scale
	_base_transform = transform
	_setup_materials()
	_prepare_animations()


func set_knife_model(glb_path: String, info: Dictionary = {}) -> void:
	_anim = null
	_is_attacking = false
	_is_inspecting = false
	_is_drawing = false
	_slash_index = 0
	_roles = info.get("anims", {}).duplicate()
	_inspect_anim = str(info["inspect_anim"]) if info.get("inspect_anim") != null else ""
	for c in get_children():
		if c.name == "Model" or (c is Node3D and (c.find_child("AnimationPlayer", true, false) != null or c.find_child("v_knife_mesh", true, false) != null)):
			remove_child(c)
			c.queue_free()

	if ResourceLoader.exists(glb_path):
		var scn := load(glb_path) as PackedScene
		if scn:
			var inst := scn.instantiate()
			inst.name = "Model"
			add_child(inst)
			_setup_materials()
			_prepare_animations()


func animation_for_role(role: String) -> String:
	return _roles.get(role, role)


func _prepare_animations() -> void:
	_anim = find_child("AnimationPlayer", true, false)
	if not _anim:
		return
	for aname in _anim.get_animation_list():
		var a: Animation = _anim.get_animation(aname)
		a.loop_mode = Animation.LOOP_LINEAR if aname == animation_for_role("idle") and aname != _inspect_anim else Animation.LOOP_NONE
	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)
	play_draw()


func inspect() -> void:
	# No substitute clip for unsupported knives; repeated presses never restart.
	if not _anim or _is_attacking or _is_drawing or _is_inspecting:
		return
	if _inspect_anim.is_empty() or not _anim.has_animation(_inspect_anim):
		return
	_is_inspecting = true
	_anim.stop()
	_anim.play(_inspect_anim)


func _setup_materials() -> void:
	var meshes := find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat == null and mi.get_surface_override_material_count() > s:
				mat = mi.get_surface_override_material(s)
			if mat is BaseMaterial3D:
				# The converter already marks ordinary surfaces KHR_materials_unlit.
				# Avoid transient duplicate materials during same-frame model swaps.
				if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and not mat.resource_name.ends_with("__goldsrc_additive"):
					continue
				var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if mat.resource_name.ends_with("__goldsrc_additive"):
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					dup.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
					dup.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				mi.set_surface_override_material(s, dup)


func play_draw() -> void:
	_is_inspecting = false
	_is_attacking = false
	_is_drawing = false
	if not _anim:
		return
	if _anim.has_animation(animation_for_role("draw")):
		_is_drawing = true
		_anim.stop()
		_anim.play(animation_for_role("draw"))
	elif _anim.has_animation(animation_for_role("idle")):
		_anim.play(animation_for_role("idle"))


func attack() -> void:
	if not _anim or _is_attacking:
		return
	_is_attacking = true
	_is_inspecting = false
	_is_drawing = false
	# CKnife::Swing alternates KNIFE_MIDATTACK1HIT/2HIT; slash1/slash2 are 2-frame stubs in v_knife.mdl.
	var anim_name := animation_for_role("midslash1" if _slash_index % 2 == 0 else "midslash2")
	_slash_index += 1
	_anim.stop()
	_anim.play(anim_name)
	attack_hit.emit(false)


func attack2() -> void:
	if not _anim or _is_attacking:
		return
	_is_attacking = true
	_is_inspecting = false
	_is_drawing = false
	# No target to hit on knife-only maps, so CKnife::Stab plays KNIFE_STABMISS.
	var anim_name := animation_for_role("stab_miss")
	_anim.stop()
	_anim.play(anim_name)
	attack_hit.emit(true)


func update_sway(mouse_relative: Vector2) -> void:
	var target_x: float = clampf(-mouse_relative.x * sway_amount, -sway_max, sway_max)
	var target_y: float = clampf(mouse_relative.y * sway_amount, -sway_max, sway_max)
	_target_sway = Vector3(target_x, target_y, 0.0)


func update_bob(hspeed: float, cycle: float, on_ground: bool) -> void:
	if not on_ground or hspeed < 5.0:
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, 0.1)
		return
	var speed_ratio: float = clampf(hspeed / 250.0, 0.0, 1.5)
	var bob_x: float = cos(cycle * 0.5) * 0.008 * speed_ratio
	var bob_y: float = -absf(sin(cycle)) * 0.008 * speed_ratio
	_bob_offset = Vector3(bob_x, bob_y, 0.0)


func _process(delta: float) -> void:
	# Smooth sway back to neutral
	_sway_offset = _sway_offset.lerp(_target_sway, delta * sway_smooth)
	_target_sway = _target_sway.lerp(Vector3.ZERO, delta * 4.0)

	# Apply combined offsets to knife position
	transform.origin = _base_transform.origin + _sway_offset + _bob_offset

	# Subtle weapon sway rotation
	var sway_rot := Vector3(_sway_offset.y * 0.3, -_sway_offset.x * 0.4, _sway_offset.x * 0.2)
	transform.basis = _base_transform.basis * Basis.from_euler(sway_rot)


func _on_animation_finished(_anim_name: StringName) -> void:
	_is_attacking = false
	_is_inspecting = false
	_is_drawing = false
	if _anim and _anim.has_animation(animation_for_role("idle")):
		_anim.play(animation_for_role("idle"))
