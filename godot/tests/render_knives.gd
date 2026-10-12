extends SceneTree
## Renders both knife viewmodels through CSKnife at fixed animation frames.
## Usage: godot --path godot --script res://tests/render_knives.gd -- <out_dir>

const CSKnifeScript = preload("res://scripts/weapons/cs_knife.gd")

const KNIVES := {
	"default": "res://models/knife.glb",
	"black": "res://models/knife_black.glb",
}
# [animation, fraction of length]
const SHOTS := [
	["idle", 0.0], ["idle", 0.5], ["draw", 0.5], ["draw", 1.0],
	["slash1", 0.5], ["midslash1", 0.35], ["midslash2", 0.35], ["stab", 0.3], ["stab_miss", 0.3],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://knife_shots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.33, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env_node.environment = env
	vp.add_child(env_node)

	var cam := Camera3D.new()
	cam.fov = 73.74
	cam.near = 0.02
	cam.far = 100.0
	cam.current = true
	vp.add_child(cam)

	for f in range(5):
		await process_frame
	for id in KNIVES:
		var knife: CSKnife = CSKnifeScript.new()
		knife.name = "Knife"
		cam.add_child(knife)
		knife.set_knife_model(KNIVES[id])
		knife.set_process(false)
		var anim: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
		for shot in SHOTS:
			var aname: String = shot[0]
			if not anim.has_animation(aname):
				push_error("missing animation %s in %s" % [aname, KNIVES[id]])
				continue
			anim.play(aname)
			anim.seek(anim.get_animation(aname).length * float(shot[1]), true)
			anim.pause()
			for f in range(3):
				await process_frame
			var path := "%s/%s_%s_%02d.png" % [out_dir, id, aname, int(float(shot[1]) * 100.0)]
			vp.get_texture().get_image().save_png(path)
			print("Saved: ", path)
		cam.remove_child(knife)
		knife.free()
	quit(0)
