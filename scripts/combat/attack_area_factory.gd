## AttackAreaFactory - 攻击判定区域工厂（Phase 4.4.6 步骤 5 夯实地基用）
## 纯工具类（class_name + static func），不继承 Node，不需要 JSON
## 职责：统一封装 Area2D + CollisionShape2D + RectangleShape2D 的创建逻辑
## 解决问题：v2.9 闸门 B 第 10 问"架构地基夯实度审查"发现的"重复代码"不夯实点 D
##
## 调用方传参：
##   - name: 节点名（如 "AttackHitbox" / "AttackArea"）
##   - collision_mask: 碰撞层 mask（数据驱动，从 JSON 读）
##   - size: 矩形边长 Vector2
##   - offset: 偏移 Vector2（默认 Vector2.ZERO，以调用方为中心）
##
## 返回：Area2D 节点（已配置好 CollisionShape2D + RectangleShape2D，monitoring=false）
## 调用方按需把 monitoring 改成 true

class_name AttackAreaFactory


static func create(name: String, collision_mask: int, size: Vector2, offset: Vector2 = Vector2.ZERO) -> Area2D:
	# 创建 Area2D
	var area: Area2D = Area2D.new()
	area.name = name
	area.position = offset
	# 默认 monitoring=false，调用方按需开启
	# （玩家 hitbox 平时关、攻击时开；宠物 AttackArea 一直开用于侦测；
	#  怪物 AttackArea 平时关、攻击预警时开）
	area.monitoring = false
	# mask 数据驱动：调用方从 JSON 读 attack_target_mask 字段传入
	area.collision_mask = collision_mask

	# 创建 CollisionShape2D + RectangleShape2D
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	area.add_child(shape_node)

	return area
