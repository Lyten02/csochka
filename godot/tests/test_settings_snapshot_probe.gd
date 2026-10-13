extends SceneTree
## Invoked by run_knife_suite.py: deliberately mutate the real settings and test
## normal exit, explicit failure, and a coroutine aborted by assert.

func _initialize() -> void:
	if not preload("res://tests/settings_snapshot.gd").protect(self, 0.25):
		return
	call_deferred("run")

func run() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	root.get_node("SettingsManager").set_current_knife("knife_black")
	if mode == "assert":
		assert(false, "EXPECTED_SETTINGS_GUARD_ASSERT")
	elif mode == "failure":
		quit(1)
	else:
		quit(0)
