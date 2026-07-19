extends CharacterBody2D
## 怪物基类 - Phase 4.4.6（仇恨机制版）
## 负责：从 monsters.json 读数据、受击扣血、死亡淡出、攻击玩家或战斗模式宠物
## 4.4.6 新增：仇恨 5 秒转移 + 判定战斗模式宠物为目标

signal died

# === 怪物属性 ===
var monster_id: String = ""
var max_hp: int = 50
var current_hp: int = 50
var damage: int = 8
var move_speed: float = 120.0
var ai_template: String = ""
var attack_range: float = 40.0
var attack_cooldown: float = 1.5
var telegraph_duration: float = 0.5

# 步骤 2：攻击模式字段（从 monsters.json 读，数据驱动）
# attack_pattern: guaranteed_hit（必中，Boss 用）/ telegraph_then_check（前摇后范围检查，红尾蝎用）
# attack_shape: cone（扇形）/ circle（圆形）/ rectangle（矩形）/ rect_dir（朝向矩形）/ cross（双十字）
# attack_radius: 攻击半径（像素）—— 32×√2×1.5 ≈ 68
# attack_arc_degree: 扇形弧度（度）—— 45 度
# hit_count: 命中数量 —— 1=单体最近 / -1=群体
# attack_target_mask: 碰撞层 mask（数据驱动，v2.9 夯实地基用）
#   - 玩家层=2 / 怪物层=4 / 宠物层=16
#   - 怪物默认 mask=18（2|16，攻击玩家+战斗模式宠物）
#   - 联机版加 PvP 时改 JSON 即可，不改代码
var _attack_pattern: String = "telegraph_then_check"
var _attack_shape: String = "cone"
var _attack_radius: float = 68.0
var _attack_arc_degree: float = 45.0
var _hit_count: int = 1
var _attack_target_mask: int = 18  # 默认玩家(2)|宠物(16)

# v2.9 夯实地基：怪物 AttackArea（类似玩家 hitbox + 宠物 AttackArea）
# 用于 telegraph_then_check 区域性选择单体：攻击预警时开启 monitoring，
# 预警结束时 get_overlapping_bodies() 拿所有候选 → DamageArea 精筛 → hit_count 选数量
var _attack_area: Area2D = null
const ATTACK_AREA_SIZE: float = 136.0  # 矩形边长 = 扇形半径×2 = 68×2，确保粗筛覆盖精筛

# === 内部状态 ===
var _attack_cd_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _is_telegraphing: bool = false
var _target: Node = null
var _is_dying: bool = false
var _die_timer: float = 0.0

# 4.4.6 仇恨机制
var _aggro_timer: float = 0.0        # 仇恨计时器（> 0 时强制打玩家）
const AGGRO_DURATION: float = 5.0    # 仇恨锁定时长（docs/03 设计：5 秒）

const DIE_FADE_DURATION: float = 0.5

# === 调试开关 ===
# 设为 true 会在控制台打印 AI 状态，帮你看逻辑
# 验证通过后可以改成 false
var _debug: bool = true


func _ready() -> void:
	if monster_id != "":
		_load_data_from_json()
	# v2.9 夯实地基：用 AttackAreaFactory 创建攻击判定区域（mask 数据驱动）
	_create_attack_area()
	# 找玩家节点
	await get_tree().process_frame
	var p: Node = get_parent().get_node_or_null("Player")
	if p != null:
		set_target(p)
		if _debug:
			print("[Monster:%s] 找到玩家目标！AI=%s HP=%d DMG=%d 速度=%f 攻击距离=%f" % [monster_id, ai_template, max_hp, damage, move_speed, attack_range])
	else:
		print("[Monster:%s] 警告：没找到 Player 节点！" % monster_id)


func _create_attack_area() -> void:
	# v2.9 夯实地基：用工厂函数统一创建 Area2D + CollisionShape2D + RectangleShape2D
	# 解决不夯实点 D（重复代码）+ C（mask 数据驱动）
	_attack_area = AttackAreaFactory.create(
		"AttackArea",                       # 节点名
		_attack_target_mask,                # mask 数据驱动（默认 18=玩家|宠物）
		Vector2(ATTACK_AREA_SIZE, ATTACK_AREA_SIZE),  # 矩形边长 136×136
		Vector2.ZERO                        # 以怪物为中心，不偏移
	)
	add_child(_attack_area)
	# 怪物 AttackArea 平时关闭，攻击预警时开启（避免一直触发碰撞检测）
	_attack_area.monitoring = false


func _physics_process(delta: float) -> void:
	# 死亡淡出
	if _is_dying:
		_die_timer += delta
		var progress: float = _die_timer / DIE_FADE_DURATION
		modulate.a = 1.0 - progress
		if progress >= 1.0:
			queue_free()
		return

	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta

	# 4.4.6 仇恨计时器倒计时
	if _aggro_timer > 0:
		_aggro_timer -= delta
		if _aggro_timer <= 0 and _debug:
			print("[Monster:%s] 仇恨过期，回到最近目标规则" % monster_id)

	match ai_template:
		"static":
			pass
		"melee_charger":
			_ai_melee_charger(delta)


func _ai_melee_charger(delta: float) -> void:
	# 4.4.6 动态选择目标：
	# - 仇恨锁定（_aggro_timer > 0）→ 强制打玩家
	# - 否则 → 选最近目标（玩家 or 战斗模式宠物）
	if _aggro_timer <= 0:
		var new_target: Node = _find_nearest_target()
		if new_target != null and new_target != _target:
			if _debug:
				var target_name: String = "玩家" if new_target.name == "Player" else "宠物"
				print("[Monster:%s] 切换目标 → %s（最近目标规则）" % [monster_id, target_name])
			_target = new_target

	if _target == null or not is_instance_valid(_target):
		return

	# 4.4.6 温和模式宠物不能被攻击，跳过
	# 4.4.6 修复：用 has_method + is_gentle_mode() 方法替代 Object.get(prop, default)
	if _target.name != "Player" and _target.has_method("is_gentle_mode") and _target.is_gentle_mode():
		_target = null
		return

	var to_player: Vector2 = _target.global_position - global_position
	var distance: float = to_player.length()

	if _is_telegraphing:
		# 预警中
		_telegraph_timer -= delta
		modulate = Color(2.0, 0.5, 0.5, 1.0)
		if _telegraph_timer <= 0:
			if _debug:
				print("[Monster:%s] 预警结束，执行攻击！伤害=%d" % [monster_id, damage])
			_do_attack()
			_is_telegraphing = false
			_attack_cd_timer = attack_cooldown
			modulate = Color(1, 1, 1, 1)
			# v2.9 夯实地基：预警结束后关闭 AttackArea monitoring
			if _attack_area != null:
				_attack_area.monitoring = false
	else:
		modulate = Color(1, 1, 1, 1)

		if distance <= attack_range and _attack_cd_timer <= 0:
			# 进入攻击距离 + CD 好了 → 预警
			if _debug:
				var target_name2: String = "玩家" if _target.name == "Player" else "宠物"
				print("[Monster:%s] 进入攻击距离(%.0f<=%.0f) 目标=%s，开始预警..." % [monster_id, distance, attack_range, target_name2])
			_is_telegraphing = true
			_telegraph_timer = telegraph_duration
			# v2.9 夯实地基：预警开始时开启 AttackArea monitoring（粗筛所有目标）
			if _attack_area != null:
				_attack_area.monitoring = true
		elif distance > attack_range:
			# 不在攻击距离 → 走向目标
			var direction: Vector2 = to_player.normalized()
			velocity = direction * move_speed
			move_and_slide()
		else:
			# 在攻击距离内但 CD 没好 → 等待
			velocity = Vector2.ZERO
			move_and_slide()


func _find_nearest_target() -> Node:
	# 4.4.6 找最近目标：玩家 or 战斗模式宠物（非温和模式）
	# 返回最近的合法目标，没有则返回 null
	var player: Node = get_parent().get_node_or_null("Player")
	var best_target: Node = null
	var best_dist: float = 999999.0

	# 检查玩家
	# 4.4.6 修复：Godot 4 的 Object.get() 只接受 1 个参数，去掉默认值参数
	if player != null and is_instance_valid(player) and not bool(player.get("_is_dying")):
		best_target = player
		best_dist = global_position.distance_to(player.global_position)

	# 检查所有战斗模式宠物（遍历场景中的 Pet 节点）
	var pets: Array = get_parent().get_children()
	for child in pets:
		if child == self:
			continue
		# 判断是否是宠物节点（有 is_gentle_mode 方法）
		if child.name != "Player" and child.has_method("take_damage") and child.has_method("is_gentle_mode"):
			# 4.4.6 修复：直接调用 is_gentle_mode() 方法（前面 has_method 已确认存在）
			# _is_dying 用 Object.get() 单参数版，属性不存在返回 null，bool(null) = false
			if not child.is_gentle_mode() and not bool(child.get("_is_dying")):
				var dist: float = global_position.distance_to(child.global_position)
				if dist < best_dist:
					best_dist = dist
					best_target = child

	return best_target


func _do_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		if _debug:
			print("[Monster:%s] 攻击失败：目标无效" % monster_id)
		return
	# 4.4.6 再次检查目标是否合法（温和模式宠物不能被攻击）
	# 4.4.6 修复：用 has_method + is_gentle_mode() 方法替代 Object.get(prop, default)
	# 原因：Godot 4 的 Object.get() 只接受 1 个参数；has_method 已确认是宠物，可直接调用方法
	if _target.name != "Player" and _target.has_method("is_gentle_mode") and _target.is_gentle_mode():
		if _debug:
			print("[Monster:%s] 目标进入温和模式，攻击取消" % monster_id)
		return

	# 步骤 2：attack_pattern 分支
	# - guaranteed_hit：必中（Boss 用，保留原行为）
	# - telegraph_then_check：预警结束后用 DamageArea 精确判定目标是否在攻击形状内
	#   v2.9 夯实地基：从 AttackArea 拿所有重叠目标作为候选（区域性选择单体）
	#   - 玩家跑开但战斗模式宠物在扇形内 → 自动命中宠物（符合 hit_count=1 设计真值）
	#   - 玩家+宠物都不在扇形内 → 显示 miss 飘字
	match _attack_pattern:
		"guaranteed_hit":
			_apply_damage_to_target()
		"telegraph_then_check":
			# v2.9 夯实地基：从 AttackArea 粗筛所有重叠目标（区域性候选）
			var candidates: Array = []
			if _attack_area != null:
				var bodies: Array = _attack_area.get_overlapping_bodies()
				for body in bodies:
					if body == self:
						continue
					# 必须有 take_damage 方法 + 没在死亡淡出中
					if body.has_method("take_damage") and not bool(body.get("_is_dying")):
						# 温和模式宠物不能被攻击（与 _find_nearest_target 规则一致）
						if body.name != "Player" and body.has_method("is_gentle_mode") and body.is_gentle_mode():
							continue
						candidates.append(body)
			# 步骤 3：用 DamageArea 精确判定（cone 扇形 + 朝向当前 _target）
			var shape_config: Dictionary = {
				"type": _attack_shape,
				"radius": _attack_radius,
				"arc_degree": _attack_arc_degree,
				"hit_count": _hit_count
			}
			var facing: Vector2 = (_target.global_position - global_position).normalized()
			var hits: Array = DamageArea.filter_targets(global_position, facing, shape_config, candidates)
			if hits.size() > 0:
				# 命中扇形内最近的目标（hit_count=1 时 DamageArea 已自动选最近）
				# 注意：命中的目标可能是 _target 之外的另一个目标（如玩家跑开但宠物在扇形内）
				_apply_damage_to_specific_target(hits[0])
			else:
				if _debug:
					var dist: float = global_position.distance_to(_target.global_position)
					print("[Monster:%s] 攻击落空！目标距离 %.1f 不在 %s 内" % [monster_id, dist, DamageArea.describe_shape(shape_config)])
				# 步骤 1 飘字系统：miss 用灰色字
				DamageNumberManager.show_damage_number(_target.global_position, 0, "miss")
		_:
			_apply_damage_to_target()


func _apply_damage_to_target() -> void:
	# 步骤 2：抽出"实际命中并扣血"逻辑，供 _do_attack 各分支复用
	# 默认打 _target（guaranteed_hit / 默认分支用）
	_apply_damage_to_specific_target(_target)


func _apply_damage_to_specific_target(target: Node) -> void:
	# v2.9 夯实地基：支持区域性选择单体——命中的目标可能是 _target 之外的另一个目标
	# telegraph_then_check 分支用 DamageArea.filter_targets 选最近的，传给本函数
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		var target_name: String = "玩家" if target.name == "Player" else "宠物"
		if _debug:
			print("[Monster:%s] 命中%s！调用 take_damage(%d)" % [monster_id, target_name, damage])
		# 4.4.6 传 self 作为 attacker，让玩家被攻击时不会触发仇恨（仇恨只在玩家主动攻击怪物时触发）
		# 怪物攻击不需要传 attacker，因为 take_damage(amount, attacker) 默认 attacker=null
		target.take_damage(damage)
		# 步骤 1：怪物命中目标时显示伤害飘字
		DamageNumberManager.show_damage_number(target.global_position, damage, "damage")
	else:
		if _debug:
			print("[Monster:%s] 目标没有 take_damage 方法" % monster_id)


func take_damage(amount: int, attacker: Node = null) -> void:
	if _is_dying:
		return
	current_hp -= amount
	if _debug:
		var attacker_name: String = "未知" if attacker == null else attacker.name
		print("[Monster:%s] 受击！扣 %d（来自 %s），剩余 %d/%d" % [monster_id, amount, attacker_name, current_hp, max_hp])
	# 步骤 1：怪物受伤时显示伤害飘字
	DamageNumberManager.show_damage_number(global_position, amount, "damage")
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)

	# 4.4.6 仇恨机制：被玩家打时锁定玩家 5 秒（docs/03 设计）
	if attacker != null and attacker.name == "Player":
		_aggro_timer = AGGRO_DURATION
		if _target != attacker:
			_target = attacker
			if _debug:
				print("[Monster:%s] 仇恨转移！锁定玩家 5 秒" % monster_id)

	if current_hp <= 0:
		start_dying()


func start_dying() -> void:
	_is_dying = true
	_die_timer = 0.0
	emit_signal("died")
	if _debug:
		print("[Monster:%s] 死亡！" % monster_id)


func _load_data_from_json() -> void:
	var data: Dictionary = DataManager.get_monster(monster_id)
	if data.is_empty():
		push_warning("Monster: 找不到 ID %s" % monster_id)
		return
	max_hp = int(data.get("hp", 50))
	damage = int(data.get("damage", 8))
	move_speed = float(data.get("speed", 120.0))
	ai_template = String(data.get("ai_template", "static"))
	attack_range = float(data.get("attack_range", 40.0))
	attack_cooldown = float(data.get("attack_cooldown", 1.5))
	telegraph_duration = float(data.get("telegraph_duration", 0.5))
	# 步骤 2：攻击模式字段（数据驱动）
	_attack_pattern = String(data.get("attack_pattern", "telegraph_then_check"))
	_attack_shape = String(data.get("attack_shape", "cone"))
	_attack_radius = float(data.get("attack_radius", 68.0))
	_attack_arc_degree = float(data.get("attack_arc_degree", 45.0))
	_hit_count = int(data.get("hit_count", 1))
	# v2.9 夯实地基：mask 数据驱动（默认 18=玩家|宠物，联机版加 PvP 改 JSON）
	_attack_target_mask = int(data.get("attack_target_mask", 18))
	current_hp = max_hp


func set_target(target: Node) -> void:
	_target = target
