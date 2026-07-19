extends Node
## InventoryManager —— 背包管家（MVP 简化版）
## 重要物品无限容量 + 普通物品 30 格 + 堆叠机制
## 满包时 add 返回 false，调用方应入邮件（见 docs/10-UI与交互.md 奖励发放规则）

signal inventory_changed

const NORMAL_SLOT_MAX: int = 30

var _important: Dictionary = {}  # { item_id: count }
var _normal: Array = []          # [{ item_id, count }, ...]


func _ready() -> void:
	pass


func add(item_id: String, count: int = 1) -> bool:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		push_warning("InventoryManager: 物品 ID 无效 %s" % item_id)
		return false
	var category: String = item.get("category", "")
	if category == "important":
		_important[item_id] = _important.get(item_id, 0) + count
		emit_signal("inventory_changed")
		return true
	else:
		var stack_max: int = int(item.get("stack", 1))
		var remaining: int = count
		for slot in _normal:
			if slot.item_id == item_id and slot.count < stack_max:
				var can_add: int = min(stack_max - slot.count, remaining)
				slot.count += can_add
				remaining -= can_add
				if remaining <= 0:
					emit_signal("inventory_changed")
					return true
		while remaining > 0:
			if _normal.size() >= NORMAL_SLOT_MAX:
				emit_signal("inventory_changed")
				return false
			var can_add: int = min(stack_max, remaining)
			_normal.append({"item_id": item_id, "count": can_add})
			remaining -= can_add
		emit_signal("inventory_changed")
		return true


func remove(item_id: String, count: int = 1) -> bool:
	if get_count(item_id) < count:
		return false
	var item: Dictionary = DataManager.get_item(item_id)
	var category: String = item.get("category", "")
	if category == "important":
		_important[item_id] = _important.get(item_id, 0) - count
		if _important[item_id] <= 0:
			_important.erase(item_id)
	else:
		var remaining: int = count
		var i: int = _normal.size() - 1
		while i >= 0 and remaining > 0:
			var slot: Dictionary = _normal[i]
			if slot.item_id == item_id:
				var take: int = min(slot.count, remaining)
				slot.count -= take
				remaining -= take
				if slot.count <= 0:
					_normal.remove_at(i)
			i -= 1
	emit_signal("inventory_changed")
	return true


func has(item_id: String, count: int = 1) -> bool:
	return get_count(item_id) >= count


func get_count(item_id: String) -> int:
	if _important.has(item_id):
		return int(_important[item_id])
	for slot in _normal:
		if slot.item_id == item_id:
			return int(slot.count)
	return 0


func is_full() -> bool:
	return _normal.size() >= NORMAL_SLOT_MAX


func get_important_items() -> Dictionary:
	return _important


func get_normal_items() -> Array:
	return _normal


func get_save_data() -> Dictionary:
	return {
		"important": _important.duplicate(true),
		"normal": _normal.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	_important = data.get("important", {}).duplicate(true)
	_normal = data.get("normal", []).duplicate(true)
	emit_signal("inventory_changed")


func clear() -> void:
	_important.clear()
	_normal.clear()
	emit_signal("inventory_changed")
