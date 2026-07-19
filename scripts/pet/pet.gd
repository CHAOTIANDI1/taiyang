extends CharacterBody2D
## 宠物脚本 - Phase 4.4.6（战斗模式版）
## 负责：从 pets.json 读数据 + 温和模式切换 + take_damage 接口 + 跟随 AI + 传送兜底 + 攻击怪物
## 状态机：idle / follow / attack（4.4.4-4.4.6 实现）

signal mode_toggled(is_gentle: bool)
signal died

@export var pet_id: String = ""
@export var move_speed: float = 150.0

var pet_name: String = ""
var species: String = ""
var max_hp: int = 50
var current_hp: int = 50
var damage: int = 8
var initial_level: int = 1
var skill_id: String = ""
var base_pet_id: String = ""

var _is_gentle_mode: bool = true
var _owner_player: Node = null
var _state: String = "idle"
var _is_dying: bool = false
var _color_rect: ColorRect = null

const FOLLOW_OFFSET: float = 80.0
# 4.4.5 传送兜底常量（防卡死，符合 docs/03 设计：15 身位 × 32 像素 = 480）
const TELEPORT_DISTANCE: float = 480.0  # 15 身位，距离超过此值启动计时器
const TELEPORT_TIMEOUT: float = 3.0     # 3 秒内距离未缩短就传送

# 4.4.4 跟随 AI 距离阈值（滞后避免抖动）
const FOLLOW_START_DISTANCE: float = 100.0  # idle → follow 触发距离
const FOLLOW_STOP_DISTANCE: float = 60.0    # follow → idle 触发距离

# 4.4.5 传送兜底计时器
var _teleport_timer: float = 0.0

# 4.4.6 攻击状态变量
var _attack_range: float = 45.0       # 攻击范围（从 pets.json 读）
var _attack_cooldown: float = 1.2     # 攻击 CD（从 pets.json 读）
var _attack_duration: float = 0.3     # 攻击持续时间（从 pets.json 读）
var _attack_timer: float = 0.0        # 攻击动画计时
var _attack_cd_timer: float = 0.0     # 攻击 CD 计时
var _attack_hit: bool = false         # 本次攻击是否已命中
var _attack_target: Node = null       # 当前攻击目标（怪物节点）
var _attack_area: Area2D = null       # 攻击判定区域（侦测+命中共用）

# 步骤 2：攻击模式字段（从 pets.json 读，与 monsters.json 一致）
# instant_check：宠物攻击模式（攻击动画期间用 AttackArea 检测，没有预警）
# 步骤 3 会用 DamageArea + attack_shape 做精确判定
# v2.9 夯实地基：attack_target_mask 数据驱动（默认 4=怪物层，联机版加 PvP 改 JSON）
var _attack_pattern: String = "instant_check"
var _attack_shape_name: String = "cone"
var _attack_radius: float = 68.0
var _attack_arc_degree: float = 45.0
var _hit_count: int = 1
var _attack_target_mask: int = 4  # 默认怪物层(4)


func _ready() -> void:
	_color_rect = get_node_or_null("ColorRect")
	if pet_id != "":
		_load_data_from_json()
	_apply_color()
	# 4.4.6 创建攻击判定区域（侦测附近怪物 + 攻击命中）
	_create_attack_area()
	await get_tree().process_frame
	var p: Node = get_parent().get_node_or_null("Player")
	if p != null:
		set_owner_player(p)
		print("[Pet:%s] 就绪！名称=%s HP=%d/%d DMG=%d 温和模式=%s 攻击距离=%d CD=%.1f" % [pet_id, pet_name, current_hp, max_hp, damage, _is_gentle_mode, int(_attack_range), _attack_cooldown])
	else:
		push_warning("[Pet:%s] 未找到 Player 节点" % pet_id)


func _create_attack_area() -> void:
	# v2.9 夯实地基：用 AttackAreaFactory 创建 AttackArea（统一三处调用方逻辑）
	# 解决不夯实点 D（重复代码）+ C（mask 数据驱动）
	# 用于：1) 侦测附近怪物（_find_nearest_monster）2) 攻击命中判定（_check_pet_hit）
	# 侦测范围 = 攻击范围 × 1.5 × 2（左右各 1.5 倍攻击距离，留追击缓冲）
	var detect_size: float = _attack_range * 1.5 * 2.0
	_attack_area = AttackAreaFactory.create(
		"AttackArea",                         # 节点名
		_attack_target_mask,                  # mask 数据驱动（默认 4=怪物层）
		Vector2(detect_size, detect_size),    # 矩形边长
		Vector2.ZERO                          # 以宠物为中心，不偏移
	)
	add_child(_attack_area)
	# monitoring 一直开着，用于侦测附近怪物
	_attack_area.monitoring = true


func _apply_color() -> void:
	if _color_rect == null:
		return
	var data: Dictionary = DataManager.get_pet(pet_id)
	var color_str: String = String(data.get("color", "#FFA500"))
	_color_rect.color = Color(color_str)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if Input.is_action_just_pressed("pet_toggle_mode"):
		toggle_gentle_mode()

	# 4.4.4 状态切换（滞后避免抖动）
	_update_state()

	# 4.4.5 传送兜底（防卡死：距离 > 15 身位且 3 秒未缩短就传送）
	_update_teleport_fallback(delta)

	match _state:
		"idle":
			_state_idle(delta)
		"follow":
			_state_follow(delta)
		"attack":
			_state_attack(delta)


func _update_teleport_fallback(delta: float) -> void:
	# 4.4.5 传送兜底：宠物卡远时 3 秒后传送回玩家身边
	if _owner_player == null:
		return

	var distance: float = global_position.distance_to(_owner_player.global_position)

	if distance > TELEPORT_DISTANCE:
		_teleport_timer += delta
		if _teleport_timer >= TELEPORT_TIMEOUT:
			# 传送到玩家右侧 80 像素（与初始孵化位置一致）
			global_position = _owner_player.global_position + Vector2(FOLLOW_OFFSET, 0)
			var old_distance: float = distance
			_teleport_timer = 0.0
			print("[Pet:%s] 传送兜底！距离=%.1f > %d 像素（15 身位），3 秒未缩短，传送到玩家身边" % [pet_id, old_distance, int(TELEPORT_DISTANCE)])
	else:
		# 距离恢复正常，重置计时器
		if _teleport_timer > 0.0:
			_teleport_timer = 0.0


func _update_state() -> void:
	# 4.4.4 + 4.4.6 状态切换逻辑（idle ↔ follow ↔ attack）
	if _owner_player == null:
		return

	# 4.4.6 attack 状态优先级最高：检查退出条件
	if _state == "attack":
		# 目标无效（死亡/被释放）→ 切 follow
		# 4.4.6 修复：Godot 4 的 Object.get() 只接受 1 个参数，去掉默认值参数
		# 属性不存在时 get() 返回 null，bool(null) = false，行为与原"default false"一致
		var target_invalid: bool = _attack_target == null or not is_instance_valid(_attack_target) or bool(_attack_target.get("_is_dying"))
		if target_invalid:
			_attack_target = null
			_attack_timer = 0.0
			_attack_cd_timer = 0.0
			modulate = Color(1, 1, 1, 1)
			set_state("follow")
			print("[Pet:%s] 状态切换 attack → follow（目标无效）" % pet_id)
			return
		# 目标远离（距离 > 攻击范围 * 2）→ 切 follow
		var dist_to_target: float = global_position.distance_to(_attack_target.global_position)
		if dist_to_target > _attack_range * 2.0:
			_attack_target = null
			_attack_timer = 0.0
			modulate = Color(1, 1, 1, 1)
			set_state("follow")
			print("[Pet:%s] 状态切换 attack → follow（目标远离 距离=%.1f）" % [pet_id, dist_to_target])
			return
		# attack 状态中不切换其他状态
		return

	# 4.4.4 idle ↔ follow 切换（滞后避免抖动）
	var distance: float = global_position.distance_to(_owner_player.global_position)
	if _state == "idle" and distance > FOLLOW_START_DISTANCE:
		set_state("follow")
		print("[Pet:%s] 状态切换 idle → follow（距离=%.1f）" % [pet_id, distance])
	elif _state == "follow" and distance < FOLLOW_STOP_DISTANCE:
		set_state("idle")
		velocity = Vector2.ZERO
		move_and_slide()
		print("[Pet:%s] 状态切换 follow → idle（距离=%.1f）" % [pet_id, distance])

	# 4.4.6 战斗模式 + 附近有怪物 → 切 attack
	if not _is_gentle_mode:
		var nearest_monster: Node = _find_nearest_monster()
		if nearest_monster != null:
			var old_state: String = _state
			_attack_target = nearest_monster
			set_state("attack")
			# 4.4.6 修复：Object.get() 单参数版，属性不存在返回 null，String(null) 是 "null" 字符串需特殊处理
			var monster_id_str: String = String(nearest_monster.monster_id) if "monster_id" in nearest_monster else ""
			print("[Pet:%s] 状态切换 %s → attack（发现怪物 %s 距离=%.1f）" % [pet_id, old_state, monster_id_str, global_position.distance_to(nearest_monster.global_position)])


func _find_nearest_monster() -> Node:
	# 4.4.6 用 AttackArea 检测附近怪物，返回最近的非死亡怪物
	# Area2D mask=4 已过滤 Layer 4（怪物），不会检测到玩家（Layer 2）或宠物（Layer 16）
	if _attack_area == null:
		return null
	var bodies: Array = _attack_area.get_overlapping_bodies()
	var nearest: Node = null
	var nearest_dist: float = 999999.0
	for body in bodies:
		if body == self:
			continue
		# 检查有 take_damage 方法 + 没在死亡淡出中
		# 4.4.6 修复：Object.get() 单参数版（Godot 4 不支持默认值参数）
		if body.has_method("take_damage") and not bool(body.get("_is_dying")):
			var dist: float = global_position.distance_to(body.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = body
	return nearest


func _state_idle(delta: float) -> void:
	pass


func _state_follow(delta: float) -> void:
	# 4.4.4 跟随 AI：朝玩家方向移动
	if _owner_player == null:
		return

	var to_player: Vector2 = _owner_player.global_position - global_position
	var direction: Vector2 = to_player.normalized()
	velocity = direction * move_speed
	move_and_slide()


func _state_attack(delta: float) -> void:
	# 4.4.6 攻击状态：朝目标移动到攻击距离 + 攻击 + CD
	if _attack_target == null or not is_instance_valid(_attack_target):
		return

	# CD 倒计时
	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta

	# 攻击动画计时
	if _attack_timer > 0:
		# 攻击中：检测命中（一次性）
		_attack_timer -= delta
		if not _attack_hit:
			_check_pet_hit()
		# 攻击中闪白
		modulate = Color(3.0, 3.0, 3.0, 1.0)
		# 攻击中不动
		velocity = Vector2.ZERO
		move_and_slide()
	else:
		# 非攻击中：恢复正常颜色
		modulate = Color(1, 1, 1, 1)
		# CD 好了 → 朝目标移动到攻击距离 → 启动攻击
		if _attack_cd_timer <= 0:
			var to_target: Vector2 = _attack_target.global_position - global_position
			var dist: float = to_target.length()
			if dist > _attack_range * 0.8:
				# 还没到攻击距离，朝目标移动
				var direction: Vector2 = to_target.normalized()
				velocity = direction * move_speed
				move_and_slide()
			else:
				# 到攻击距离，启动攻击
				_start_pet_attack()
		else:
			# CD 中，原地等待
			velocity = Vector2.ZERO
			move_and_slide()


func _start_pet_attack() -> void:
	# 4.4.6 启动宠物攻击
	_attack_timer = _attack_duration
	_attack_cd_timer = _attack_cooldown
	_attack_hit = false
	# 4.4.6 修复：Object.get() 单参数版，属性不存在时用 in 检查 + 直接访问
	var monster_id_str: String = String(_attack_target.monster_id) if "monster_id" in _attack_target else ""
	print("[Pet:%s] 开始攻击！目标=%s 伤害=%d" % [pet_id, monster_id_str, damage])


func _check_pet_hit() -> void:
	# 步骤 3：用 DamageArea 工具类筛选命中目标（扇形 + 单体最近）
	# _attack_area 提供粗筛候选（mask=4 怪物层），DamageArea 按形状精筛
	if _attack_area == null or _attack_target == null:
		return
	var bodies: Array = _attack_area.get_overlapping_bodies()
	# 粗筛：排除自己 + 排除死亡目标 + 必须有 take_damage
	var candidates: Array = []
	for body in bodies:
		if body == self:
			continue
		if body.has_method("take_damage") and not bool(body.get("_is_dying")):
			candidates.append(body)
	# 构造 shape_config（数据驱动，从 pets.json 读的字段）
	var shape_config: Dictionary = {
		"type": _attack_shape_name,
		"radius": _attack_radius,
		"arc_degree": _attack_arc_degree,
		"hit_count": _hit_count
	}
	# 朝向：朝当前攻击目标
	var facing: Vector2 = (_attack_target.global_position - global_position).normalized()
	# 精筛
	var hits: Array = DamageArea.filter_targets(global_position, facing, shape_config, candidates)
	for body in hits:
		if body == null or not is_instance_valid(body):
			continue
		# 传 self 作为 attacker（宠物打不触发仇恨，但保持接口一致）
		body.take_damage(damage, self)
		_attack_hit = true
		# 步骤 1：宠物命中怪物时显示伤害飘字
		DamageNumberManager.show_damage_number(body.global_position, damage, "damage")
		# 4.4.6 修复：Object.get() 单参数版，用 in 操作符检查属性
		var monster_id_str: String = String(body.monster_id) if "monster_id" in body else ""
		print("[Pet:%s] 命中 %s！造成 %d 伤害（形状=%s）" % [pet_id, monster_id_str, damage, DamageArea.describe_shape(shape_config)])
		# hit_count=1 时只打 1 个，hit_count=-1 时打全部
		if _hit_count == 1:
			break


func toggle_gentle_mode() -> void:
	_is_gentle_mode = not _is_gentle_mode
	emit_signal("mode_toggled", _is_gentle_mode)
	print("[Pet:%s] 温和模式切换 → %s" % [pet_id, _is_gentle_mode])


func take_damage(amount: int) -> void:
	if _is_dying:
		return
	if _is_gentle_mode:
		print("[Pet:%s] 温和模式无敌，忽略伤害 %d" % [pet_id, amount])
		return
	current_hp -= amount
	print("[Pet:%s] 受击！扣 %d，剩余 %d/%d" % [pet_id, amount, current_hp, max_hp])
	# 步骤 1：宠物受伤时显示伤害飘字
	DamageNumberManager.show_damage_number(global_position, amount, "damage")
	if current_hp <= 0:
		current_hp = 0
		_start_dying()


func _start_dying() -> void:
	_is_dying = true
	emit_signal("died")
	print("[Pet:%s] 死亡（4.4.6 实现完整死亡淡出）" % pet_id)


func set_owner_player(player: Node) -> void:
	_owner_player = player


func set_state(new_state: String) -> void:
	_state = new_state


func is_gentle_mode() -> bool:
	return _is_gentle_mode


func _load_data_from_json() -> void:
	var data: Dictionary = DataManager.get_pet(pet_id)
	if data.is_empty():
		push_warning("Pet: 找不到 ID %s，用默认值" % pet_id)
		return
	pet_name = String(data.get("name", ""))
	species = String(data.get("species", ""))
	max_hp = int(data.get("hp", 50))
	damage = int(data.get("damage", 8))
	initial_level = int(data.get("initial_level", 1))
	skill_id = String(data.get("skill_id", ""))
	base_pet_id = String(data.get("base_pet_id", ""))
	# 4.4.6 攻击参数（数据驱动，从 pets.json 读）
	_attack_range = float(data.get("attack_range", 45.0))
	_attack_cooldown = float(data.get("attack_cooldown", 1.2))
	_attack_duration = float(data.get("attack_duration", 0.3))
	# 步骤 2：攻击模式字段（与 monsters.json 一致，步骤 3 DamageArea 用）
	_attack_pattern = String(data.get("attack_pattern", "instant_check"))
	_attack_shape_name = String(data.get("attack_shape", "cone"))
	_attack_radius = float(data.get("attack_radius", 68.0))
	_attack_arc_degree = float(data.get("attack_arc_degree", 45.0))
	_hit_count = int(data.get("hit_count", 1))
	# v2.9 夯实地基：mask 数据驱动（默认 4=怪物层，联机版加 PvP 改 JSON）
	_attack_target_mask = int(data.get("attack_target_mask", 4))
	current_hp = max_hp



