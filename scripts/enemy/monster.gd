extends CharacterBody2D
## 怪物基类 - Phase 4
## 负责：从 monsters.json 读数据、受击扣血、死亡淡出、攻击玩家

# === 信号（`signal` 是 Godot 让节点之间"喊话"的机制） ===
# 死亡时喊一声 "died"，谁监听了谁就知道
signal died

# === 怪物属性 ===
var monster_id: String = ""        # 怪物唯一 ID（如 red_scorpion）
var max_hp: int = 50              # 最大血量
var current_hp: int = 50          # 当前血量
var damage: int = 8               # 攻击力
var move_speed: float = 120.0     # 移动速度
var ai_template: String = ""      # AI 模板类型
var attack_range: float = 40.0    # 攻击距离
var attack_cooldown: float = 1.5  # 攻击冷却
var telegraph_duration: float = 0.5  # 前摇预警时长

# === 内部状态 ===
var _attack_cd_timer: float = 0.0  # 攻击冷却计时
var _telegraph_timer: float = 0.0  # 前摇计时
var _is_telegraphing: bool = false  # 正在预警吗
var _target: Node = null          # 攻击目标（玩家）
var _is_dying: bool = false       # 正在死亡淡出吗
var _die_timer: float = 0.0       # 死亡淡出计时

# === 死亡淡出时长 ===
const DIE_FADE_DURATION: float = 0.5


func _ready() -> void:
	# 准备阶段：从 JSON 读怪物数据
	if monster_id != "":
		_load_data_from_json()
	# 过渡做法：碰一下父级找玩家节点
	# 将来由正式的怪物管理器分配 target
	await get_tree().process_frame
	var p: Node = get_parent().get_node_or_null("Player")
	if p != null:
		set_target(p)

func _physics_process(delta: float) -> void:
	# 死亡淡出阶段：跳过所有 AI 逻辑
	if _is_dying:
		_die_timer += delta
		# 把当前淡出进度算出来：0 → 完全显示，1 → 完全透明
		var progress: float = _die_timer / DIE_FADE_DURATION
		# modulate A=0 时透明，所以用 1-progress 实现"从 1 淡到 0"
		modulate.a = 1.0 - progress
		# 0.5 秒后真正销毁
		if progress >= 1.0:
			queue_free()  # 从场景树移除并释放内存
		return

	# 冷却计时器倒计时
	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta

	# AI 模板分发
	match ai_template:
		"static":
			pass  # 训练木桩不动
		"melee_charger":
			_ai_melee_charger(delta)


# AI 模板：近战冲锋型
# 行为：走向玩家 → 进入攻击距离 → 闪红预警 0.5 秒 → 攻击
func _ai_melee_charger(delta: float) -> void:
	# _target 是玩家节点，必须有目标才能行动
	if _target == null or not is_instance_valid(_target):
		return

	# 算出到玩家的距离向量
	var to_player: Vector2 = _target.global_position - global_position
	# length() 返回向量长度（两点距离）
	var distance: float = to_player.length()

	# 状态切换：正在预警 vs 平时
	if _is_telegraphing:
		# 预警中：停止移动，倒计时
		_telegraph_timer -= delta
		# 预警时身体闪红（modulate 红色增强）
		modulate = Color(2.0, 0.5, 0.5, 1.0)
		if _telegraph_timer <= 0:
			# 预警结束，执行攻击
			_do_attack()
			_is_telegraphing = false
			_attack_cd_timer = attack_cooldown
			modulate = Color(1, 1, 1, 1)
	else:
		# 恢复原色
		modulate = Color(1, 1, 1, 1)

		# 还在攻击距离内且 CD 好了 → 启动预警
		if distance <= attack_range and _attack_cd_timer <= 0:
			_is_telegraphing = true
			_telegraph_timer = telegraph_duration
		elif distance > attack_range:
			# 不在攻击距离内 → 走向玩家
			# direction = 目标方向（单位向量，长度=1）
			var direction: Vector2 = to_player.normalized()
			velocity = direction * move_speed
			move_and_slide()
		else:
			# 在攻击距离内但 CD 没好 → 等待
			velocity = Vector2.ZERO
			move_and_slide()


# 执行攻击（Phase 4：接玩家受伤）
# docs/02-战斗系统.md：怪物预警结束后攻击，调用玩家 take_damage
func _do_attack() -> void:
	# 确认目标有效且能受伤
	if _target == null or not is_instance_valid(_target):
		return
	# 用 has_method 检测，不依赖具体类型（与 player.gd 命中检测一致）
	if _target.has_method("take_damage"):
		_target.take_damage(damage)


# 被攻击时调这个函数
# amount = 扣多少血
func take_damage(amount: int) -> void:
	if _is_dying:
		return
	current_hp -= amount
	# 受击闪白 0.1 秒
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	# 用 Tween 实现"0.1 秒内从白恢复到原色"
	# Godot 4 中类型叫 Tween（不是 Godot 3 的 SceneTreeTween）
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)

	# 血量到 0 → 死亡
	if current_hp <= 0:
		start_dying()


# 开始死亡淡出
func start_dying() -> void:
	_is_dying = true
	_die_timer = 0.0
	emit_signal("died")


# 从 JSON 加载怪物数据
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
	current_hp = max_hp


# 供 AI 初始化时设玩家目标
func set_target(target: Node) -> void:
	_target = target
