extends Node3D
## Loads the collision side of the map (BSP clip hulls) and hands it to the player.
## The visual side is the imported GLB instanced in main.tscn.

@export_file("*.bsp") var bsp_path := "res://maps/35hp_3.bsp"

@onready var player: CSPlayer = $Player


func _ready() -> void:
	var target_bsp := bsp_path
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.current_map_bsp != "":
		target_bsp = sm.current_map_bsp
		if sm.current_map_glb != "" and sm.current_map_glb != "res://maps/35hp_3.glb":
			var cur_map = get_node_or_null("Map")
			if cur_map:
				remove_child(cur_map)
				cur_map.queue_free()
			if ResourceLoader.exists(sm.current_map_glb):
				var glb_res = load(sm.current_map_glb)
				if glb_res:
					var new_map = glb_res.instantiate()
					new_map.name = "Map"
					add_child(new_map)

	var bsp := GoldSrcBsp.load_file(target_bsp)
	if bsp == null:
		push_error("Map collision not loaded: %s" % target_bsp)
		return
	player.setup(bsp)
