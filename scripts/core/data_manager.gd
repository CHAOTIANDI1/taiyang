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
	var path: String = "res://data/%s.json" % file_name
	if not FileAccess.file_exists(path):
		push_warning("DataManager: 文件缺失 %s" % path)
		_cache[file_name] = {}
		return
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("DataManager: 解析失败 %s" % path)
		_cache[file_name] = {}
		return
	_cache[file_name] = parsed

func get_data(file_name: String) -> Dictionary:
	return _cache.get(file_name, {})

func get_monster(id: String) -> Dictionary:
	var data: Dictionary = _cache.get("monsters", {}).get("_data", {})
	return data.get(id, {})

func get_item(id: String) -> Dictionary:
	var all: Dictionary = _cache.get("items", {})
	for category in ["important", "usable", "material", "food", "sub_prof", "skill_book"]:
		var cat: Dictionary = all.get(category, {})
		if cat.has(id):
			return cat[id]
	return {}

func get_skill(id: String) -> Dictionary:
	var d: Dictionary = _cache.get("skills", {}).get("_data", {})
	return d.get(id, {})

func get_map(id: String) -> Dictionary:
	var d: Dictionary = _cache.get("maps", {})
	return d.get(id, {})