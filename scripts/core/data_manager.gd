extends Node
## DataManager —— 统一数据加载管家
## 负责启动时加载所有 data/*.json 并缓存到内存

var _cache: Dictionary = {}

const _FILES := [
	"monsters", "items", "equipment", "skills", "levels", "recipes",
	"npcs", "quests", "timers", "maps", "pets", "characters",
	"dialogues", "mails", "sounds", "palettes"
]

func _ready() -> void:
	for f in _FILES:
		load_file(f)

func load_file(file_name: String) -> void:
	var path := "res://data/%s.json" % file_name
	if not FileAccess.file_exists(path):
		push_warning("DataManager: 文件缺失 %s" % path)
		_cache[file_name] = {}
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("DataManager: 解析失败 %s" % path)
		_cache[file_name] = {}
		return
	_cache[file_name] = parsed

func get_data(file_name: String) -> Dictionary:
	return _cache.get(file_name, {})

func get_monster(id: String) -> Dictionary:
	var data := _cache.get("monsters", {}).get("_data", {})
	return data.get(id, {})

func get_item(id: String) -> Dictionary:
	var all := _cache.get("items", {})
	for category in ["important", "usable", "material", "food", "sub_prof", "skill_book"]:
		if all.get(category, {}).has(id):
			return all[category][id]
	return {}

func get_skill(id: String) -> Dictionary:
	return _cache.get("skills", {}).get("_data", {}).get(id, {})

func get_map(id: String) -> Dictionary:
	return _cache.get("maps", {}).get(id, {})