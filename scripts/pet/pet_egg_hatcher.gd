extends Node2D
## 宠物蛋孵化器 - Phase 4.4.3
## 负责：3 秒孵化动画 + 实例化 pet.tscn 出现宠物
## 调用方式：未来 inventory 系统拿到蛋后调用 hatch(egg_id)
## MVP 阶段：用 test_egg_id 字段 + P 键触发测试孵化（未来 inventory 接入后置空 test_egg_id）

const PET_SCENE: PackedScene = preload("res://scenes/pet/pet.tscn")
const HATCH_TOTAL_DURATION: float = 3.0  # 总时长 3 秒（设计真值 docs/03）

@export var test_egg_id: String = "pet_egg_01"  # MVP 测试用，未来 inventory 接入后置空

var _is_hatching: bool = false
var _already_hatched: bool = false  # 4.4.4 收尾修复：防止重复孵化（4.4.3 遗留 bug）
var _egg_icon: ColorRect = null


func _ready() -> void:
	_egg_icon = get_node_or_null("EggCanvasLayer/EggIcon")
	if _egg_icon != null:
		_egg_icon.visible = false
		_egg_icon.modulate.a = 0.0
		_egg_icon.scale = Vector2(0.5, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	# MVP 测试触发：按 P 键孵化 test_egg_id
	if test_egg_id != "" and event.is_action_pressed("pet_test_hatch"):
		hatch(test_egg_id)


func hatch(egg_id: String) -> void:
	if _is_hatching:
		push_warning("[PetEggHatcher] 已在孵化中，忽略重复触发")
		return
	if _already_hatched:
		push_warning("[PetEggHatcher] 已孵化过，每颗蛋只能孵化一次（4.4.4 修复）")
		return

	var egg_item: Dictionary = DataManager.get_item(egg_id)
	if egg_item.is_empty():
		push_warning("[PetEggHatcher] 找不到蛋物品 %s" % egg_id)
		return

	var pet_id: String = _find_pet_id_by_egg_id(egg_id)
	if pet_id == "":
		push_warning("[PetEggHatcher] 蛋 %s 没有对应宠物映射" % egg_id)
		return

	print("[PetEggHatcher] 开始孵化蛋 %s（%s）→ 宠物 %s" % [egg_id, egg_item.get("name", ""), pet_id])
	_is_hatching = true
	_already_hatched = true
	await _play_hatch_animation(pet_id)
	_is_hatching = false


func _find_pet_id_by_egg_id(egg_id: String) -> String:
	# 遍历 pets.json，找 base_pet_id == egg_id 的宠物
	var pets_data: Dictionary = DataManager.get_data("pets").get("_data", {})
	for pet_id in pets_data:
		var pet: Dictionary = pets_data[pet_id]
		if String(pet.get("base_pet_id", "")) == egg_id:
			return String(pet_id)
	return ""


func _play_hatch_animation(pet_id: String) -> void:
	if _egg_icon == null:
		push_warning("[PetEggHatcher] EggIcon 节点缺失，跳过动画直接生成宠物")
		_spawn_pet(pet_id)
		return

	_egg_icon.visible = true
	_egg_icon.modulate.a = 0.0
	_egg_icon.scale = Vector2(0.5, 0.5)

	# 阶段 1：淡入 + 放大（1 秒）
	var t1: Tween = create_tween()
	t1.tween_property(_egg_icon, "modulate:a", 1.0, 1.0)
	t1.parallel().tween_property(_egg_icon, "scale", Vector2(1.0, 1.0), 1.0)
	await t1.finished

	# 阶段 2：脉动 1 秒（4 次缩放，模拟孵化感）
	var t2: Tween = create_tween()
	t2.tween_property(_egg_icon, "scale", Vector2(1.10, 1.10), 0.25)
	t2.tween_property(_egg_icon, "scale", Vector2(1.00, 1.00), 0.25)
	t2.tween_property(_egg_icon, "scale", Vector2(1.15, 1.15), 0.25)
	t2.tween_property(_egg_icon, "scale", Vector2(1.00, 1.00), 0.25)
	await t2.finished

	# 阶段 3：放大 + 淡出（1 秒）
	var t3: Tween = create_tween()
	t3.tween_property(_egg_icon, "scale", Vector2(1.5, 1.5), 1.0)
	t3.parallel().tween_property(_egg_icon, "modulate:a", 0.0, 1.0)
	await t3.finished

	# 阶段 4：实例化宠物
	_egg_icon.visible = false
	_egg_icon.scale = Vector2(0.5, 0.5)
	_spawn_pet(pet_id)
	print("[PetEggHatcher] 孵化完成！宠物 %s 出现" % pet_id)


func _spawn_pet(pet_id: String) -> void:
	var pet_instance = PET_SCENE.instantiate()
	pet_instance.pet_id = pet_id

	# 宠物出现在玩家右侧 80 像素（FOLLOW_OFFSET 常量值）
	var player: Node = get_parent().get_node_or_null("Player")
	if player != null:
		pet_instance.position = player.position + Vector2(80, 0)
	else:
		pet_instance.position = Vector2(400, 400)

	get_parent().add_child(pet_instance)
