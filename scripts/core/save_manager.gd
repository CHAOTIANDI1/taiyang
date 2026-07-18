extends Node
## SaveManager —— 统一存档管家
## 接口：save(slot, data) / load(slot) / delete(slot) / list_slots()
## 兼容 MVP 单机（JSON 文件）与联机版（PostgreSQL）切换

const SAVE_DIR := "res://data/save_slots/"
var _initialized := false

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_initialized = true

func save(slot: String, data: Dictionary) -> bool:
	if not _initialized:
		push_error("SaveManager: 未初始化")
		return false
	var path: String = SAVE_DIR + slot + ".json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 打不开 %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

func load(slot: String) -> Dictionary:
	var path: String = SAVE_DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text) if text else {}

func delete_slot(slot: String) -> bool:
	var path: String = SAVE_DIR + slot + ".json"
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false

func list_slots() -> Array:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return []
	var slots: Array = []
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			slots.append(name.substr(0, name.length() - 5))
		name = dir.get_next()
	return slots