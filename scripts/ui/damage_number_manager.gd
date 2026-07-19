extends Node
## 伤害飘字管理器 - Autoload 单例
## 步骤 1：统一管理伤害飘字的创建，所有单位（玩家/宠物/怪物）共用
## 调用方式：DamageNumberManager.show_damage_number(world_pos, amount, "damage")

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")


# 在指定世界坐标显示伤害飘字
# world_position: 受击单位的世界坐标（global_position）
# amount: 伤害数值（miss 时传 0）
# type: "damage"（红色伤害）/ "miss"（灰色 miss）/ "heal"（绿色治疗）
func show_damage_number(world_position: Vector2, amount: int, type: String = "damage") -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		push_warning("[DamageNumberManager] 当前场景为空，无法显示伤害飘字")
		return

	var instance: Label = DAMAGE_NUMBER_SCENE.instantiate()
	current_scene.add_child(instance)

	# 位置 = 受击位置 + 向上偏移 20 像素（避免覆盖单位本身）
	instance.global_position = world_position + Vector2(0, -20)

	# 转换 type 字符串为枚举
	var type_enum: int = 0  # 默认 DAMAGE
	match type:
		"damage": type_enum = 0
		"miss": type_enum = 1
		"heal": type_enum = 2

	instance.set_data(amount, type_enum)
