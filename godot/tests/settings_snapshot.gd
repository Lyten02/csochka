extends Node
## Test-only guard, installed before any test code mutates settings.
## Survives scene changes; restores bytes (or absence) during SceneTree teardown.
## A failed GDScript assert aborts its coroutine, not the engine: the watchdog
## makes that path exit with failure too, instead of leaving a mutated save behind.

const SETTINGS_PATH: String = preload("res://scripts/utils/settings_manager.gd").CONFIG_PATH
const GUARD_NAME := "TestSettingsSnapshot"
var _existed := false
var _bytes := PackedByteArray()
var _restored := false
var _timeout_seconds := 120.0

static func protect(tree: SceneTree, timeout_seconds: float = 120.0) -> bool:
	if tree.root.has_node(GUARD_NAME):
		return true
	var guard = load("res://tests/settings_snapshot.gd").new()
	guard.name = GUARD_NAME
	guard._existed = FileAccess.file_exists(SETTINGS_PATH)
	if guard._existed:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file == null:
			push_error("Cannot snapshot settings; refusing to run test")
			guard.free()
			tree.quit(1)
			return false
		guard._bytes = file.get_buffer(file.get_length())
		if file.get_error() != OK:
			push_error("Cannot read complete settings snapshot")
			guard.free()
			tree.quit(1)
			return false
		file.close()
	guard._timeout_seconds = timeout_seconds
	tree.root.add_child(guard)
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(_timeout_seconds, true).timeout.connect(_on_timeout)

func _on_timeout() -> void:
	push_error("Test timed out (including possible aborted assertion); restoring settings")
	_restore()
	get_tree().quit(1)

func _exit_tree() -> void:
	_restore()

func _restore() -> void:
	if _restored:
		return
	_restored = true
	if _existed:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if file == null:
			push_error("Failed to restore settings snapshot")
			get_tree().quit(1)
			return
		file.store_buffer(_bytes)
		file.flush()
		if file.get_error() != OK:
			push_error("Failed to write complete settings snapshot")
			get_tree().quit(1)
		file.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
		if error != OK:
			push_error("Failed to restore settings file absence")
			get_tree().quit(1)
