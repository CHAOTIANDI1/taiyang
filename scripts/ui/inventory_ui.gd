extends Control
## InventoryUI —— 背包界面（MVP 简化版）
## I 键开关 + 显示重要物品/普通物品/装备槽
## 监听 InventoryManager.inventory_changed + EquipmentManager.equipment_changed 信号自动刷新

const NORMAL_SLOT_MAX: int = 30

var _panel: Panel
var _important_list: VBoxContainer
var _normal_grid: GridContainer
var _weapon_label: Label
var _armor_label: Label
var _title_label: Label


func _ready() -> void:
	_build_ui()
	visible = false
	InventoryManager.inventory_changed.connect(_refresh)
	EquipmentManager.equipment_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.echo == false:
		if Input.is_action_just_pressed("inventory_toggle"):
			toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	if not visible:
		return
	# 重要物品
	for child in _important_list.get_children():
		child.queue_free()
	var important: Dictionary = InventoryManager.get_important_items()
	for item_id in important.keys():
		var item: Dictionary = DataManager.get_item(item_id)
		var label: Label = Label.new()
		label.text = "%s ×%d" % [item.get("name", item_id), int(important[item_id])]
		_important_list.add_child(label)
	# 普通物品
	for child in _normal_grid.get_children():
		child.queue_free()
	var normal: Array = InventoryManager.get_normal_items()
	for i in range(NORMAL_SLOT_MAX):
		var slot_label: Label = Label.new()
		slot_label.custom_minimum_size = Vector2(120, 32)
		if i < normal.size():
			var slot: Dictionary = normal[i]
			var item: Dictionary = DataManager.get_item(slot.item_id)
			slot_label.text = "%s ×%d" % [item.get("name", slot.item_id), int(slot.count)]
		else:
			slot_label.text = "[空]"
		_normal_grid.add_child(slot_label)
	# 装备槽
	var slots: Dictionary = EquipmentManager.get_all_slots()
	_weapon_label.text = _format_slot("武器", slots.get("weapon", {}))
	_armor_label.text = _format_slot("护甲", slots.get("armor", {}))


func _format_slot(slot_name: String, slot_data: Dictionary) -> String:
	if slot_data.is_empty():
		return "%s：[未装备]" % slot_name
	var item: Dictionary = DataManager.get_item(slot_data.item_id)
	var name: String = item.get("name", slot_data.item_id)
	var dur: int = int(slot_data.get("durability", 0))
	var sealed: String = " [封禁]" if dur <= 0 else ""
	return "%s：%s（耐久 %d）%s" % [slot_name, name, dur, sealed]


func _build_ui() -> void:
	# 半透明背景遮罩
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 中心面板
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 500)
	_panel.position = Vector2(-350, -250)
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "背包（I 键开关）"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 装备槽区
	var equip_box: VBoxContainer = VBoxContainer.new()
	equip_box.add_theme_constant_override("separation", 4)
	_weapon_label = Label.new()
	_armor_label = Label.new()
	equip_box.add_child(_weapon_label)
	equip_box.add_child(_armor_label)
	vbox.add_child(equip_box)

	# 重要物品区
	var imp_title: Label = Label.new()
	imp_title.text = "── 重要物品 ──"
	vbox.add_child(imp_title)
	_important_list = VBoxContainer.new()
	_important_list.add_theme_constant_override("separation", 2)
	vbox.add_child(_important_list)

	# 普通物品区
	var nor_title: Label = Label.new()
	nor_title.text = "── 普通物品 ──"
	vbox.add_child(nor_title)
	_normal_grid = GridContainer.new()
	_normal_grid.columns = 5
	_normal_grid.add_theme_constant_override("h_separation", 8)
	_normal_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_normal_grid)
