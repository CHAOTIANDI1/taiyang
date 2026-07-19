extends Node
## EquipmentManager —— 装备管家（MVP 简化版）
## 武器/护甲两槽 + 耐久度系统 + 封禁机制
## 耐久归零时属性封禁但普通攻击仍可用（docs/06-物品体系.md 装备耐久度规则）

signal equipment_changed

var _weapon: Dictionary = {}  # { item_id, durability } 或 {}
var _armor: Dictionary = {}   # { item_id, durability } 或 {}


func _ready() -> void:
	pass


func equip(item_id: String) -> bool:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		push_warning("EquipmentManager: 物品 ID 无效 %s" % item_id)
		return false
	var category: String = item.get("category", "")
	if category not in ["weapon", "armor"]:
		push_warning("EquipmentManager: 非装备类物品 %s" % item_id)
		return false
	if not InventoryManager.has(item_id, 1):
		push_warning("EquipmentManager: 背包无此物品 %s" % item_id)
		return false
	var equip_data: Dictionary = DataManager.get_equipment(item_id)
	if equip_data.is_empty():
		push_warning("EquipmentManager: 装备数据缺失 %s" % item_id)
		return false

	var slot: String = category  # "weapon" 或 "armor"
	# 步骤 1: 如果该槽已有装备，先卸下回背包
	if get_slot_data(slot).size() > 0:
		var old_id: String = get_slot_data(slot).item_id
		_clear_slot(slot)
		InventoryManager.add(old_id, 1)

	# 步骤 2: 从背包移除新装备
	InventoryManager.remove(item_id, 1)

	# 步骤 3: 装上并初始化耐久
	var durability_max: int = int(equip_data.get("durability_max", 100))
	_set_slot(slot, item_id, durability_max)
	emit_signal("equipment_changed")
	return true


func unequip(slot: String) -> bool:
	var slot_data: Dictionary = get_slot_data(slot)
	if slot_data.is_empty():
		return false
	if not InventoryManager.add(slot_data.item_id, 1):
		# 背包满，无法卸下
		return false
	_clear_slot(slot)
	emit_signal("equipment_changed")
	return true


func consume_durability(slot: String, amount: int = 1) -> void:
	var slot_data: Dictionary = get_slot_data(slot)
	if slot_data.is_empty():
		return
	slot_data.durability = max(0, int(slot_data.durability) - amount)
	var was_sealed: bool = int(slot_data.durability) == 0
	emit_signal("equipment_changed")
	if was_sealed:
		print("[EquipmentManager] %s 槽装备耐久归零，属性封禁（普通攻击仍可用）" % slot)


func repair(slot: String) -> bool:
	var slot_data: Dictionary = get_slot_data(slot)
	if slot_data.is_empty():
		return false
	var equip_data: Dictionary = DataManager.get_equipment(slot_data.item_id)
	if equip_data.is_empty():
		return false
	slot_data.durability = int(equip_data.get("durability_max", 100))
	emit_signal("equipment_changed")
	return true


func is_sealed(slot: String) -> bool:
	var slot_data: Dictionary = get_slot_data(slot)
	if slot_data.is_empty():
		return false
	return int(slot_data.durability) <= 0


func get_attack_bonus() -> int:
	if _weapon.is_empty():
		return 0
	if is_sealed("weapon"):
		return 0
	var equip: Dictionary = DataManager.get_equipment(_weapon.item_id)
	return int(equip.get("attack", 0))


func get_defense_bonus() -> int:
	if _armor.is_empty():
		return 0
	if is_sealed("armor"):
		return 0
	var equip: Dictionary = DataManager.get_equipment(_armor.item_id)
	return int(equip.get("defense", 0))


func get_slot_data(slot: String) -> Dictionary:
	if slot == "weapon":
		return _weapon
	if slot == "armor":
		return _armor
	return {}


func get_all_slots() -> Dictionary:
	return {
		"weapon": _weapon.duplicate(true),
		"armor": _armor.duplicate(true)
	}


func get_save_data() -> Dictionary:
	return {
		"weapon": _weapon.duplicate(true),
		"armor": _armor.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	_weapon = data.get("weapon", {}).duplicate(true)
	_armor = data.get("armor", {}).duplicate(true)
	emit_signal("equipment_changed")


func clear() -> void:
	_weapon.clear()
	_armor.clear()
	emit_signal("equipment_changed")


func _set_slot(slot: String, item_id: String, durability: int) -> void:
	var data: Dictionary = {"item_id": item_id, "durability": durability}
	if slot == "weapon":
		_weapon = data
	elif slot == "armor":
		_armor = data


func _clear_slot(slot: String) -> void:
	if slot == "weapon":
		_weapon = {}
	elif slot == "armor":
		_armor = {}
