extends CharacterBody2D
## 角色脚本 - Phase 4.1（修复版）
## WASD 移动 + J 攻击（带 hitbox 命中判定 + 屏震 + 飘字 + 闪白）
## 受伤 + 死亡 + 重生（无惩罚，回安全点）
## 修复：hitbox 排除自己 + 攻击冷却 + 闪白更明显 + 调试 print

# export 让你在 Godot 编辑器右侧"检查器"里改这个值
@export var speed: float = 250.0
@export var attack_duration: float = 0.2
@export var attack_damage: int = 10  # MVP 占位基础伤害
@export var attack_cooldown: float = 0.5  # 攻击冷却（秒），和动画时长分开

# === 血量 ===
var max_hp: int = 100
var current_hp: int = 100

# === 重生安全点 ===
var _safe_position: Vector2 = Vector2(400, 400)

# === 受伤无敌帧 ===
var _invincible_timer: float = 0.0
const INVINCIBLE_DURATION: float = 0.5

# === 死亡状态 ===
var _is_dying: bool = false
var _die_timer: float = 0.0
const DIE_FADE_DURATION: float = 0.8

# === 攻击状态 ===
var _attack_timer: float = 0.0        # 攻击动画计时
var _attack_cd_timer: float = 0.0     # 攻击冷却计时
var _attack_hit: bool = false         # 本次攻击是否已命中

# 当前面向方向
var _facing: Vector2 = Vector2(1, 0)

# 攻击判定区
# v2.9 夯实地基：hitbox 范围从 50×50 扩大到 136×136（扇形半径×2）
# 原因：原 50×50 矩形对角线≈35 < 扇形半径 68，会漏判扇形边缘目标
# 现在矩形覆盖范围 ≥ 扇形精筛范围，确保粗筛不漏判
var _hitbox_area: Area2D
const HITBOX_SIZE: float = 136.0  # 矩形边长 = 扇形半径×2 = 68×2
# v2.9 夯实地基：mask 数据驱动（从 characters.json 读 attack_target_mask）
var _attack_target_mask: int = 4  # 默认怪物层(4)，联机版加 PvP 改 JSON

# 步骤 3：玩家攻击形状配置（暂时硬编码常量，未来数据驱动到 characters.json）
# 数值推导：32×√2×1.5 ≈ 68 像素（详见 docs/02-战斗系统.md 攻击判定模式段）
const ATTACK_SHAPE_CONFIG: Dictionary = {
	"type": "cone",
	"radius": 68.0,
	"arc_degree": 45.0,
	"hit_count": 1
}


func _ready() -> void:
	_load_character_data()
	_safe_position = global_position

	# v2.9 夯实地基：用 AttackAreaFactory 创建 hitbox（统一三处调用方逻辑）
	# 解决不夯实点 D（重复代码）+ C（mask 数据驱动）
	# hitbox 中心在玩家位置（不偏移），范围 136×136 覆盖扇形精筛范围
	_hitbox_area = AttackAreaFactory.create(
		"AttackHitbox",                    # 节点名
		_attack_target_mask,               # mask 数据驱动（默认 4=怪物层）
		Vector2(HITBOX_SIZE, HITBOX_SIZE), # 矩形边长 136×136
		Vector2.ZERO                       # 以玩家为中心，不偏移（v2.9 修正：原来偏移 35 像素会导致朝身后攻击漏判）
	)
	add_child(_hitbox_area)
	# hitbox 平时关闭，按 J 攻击时开启（_physics_process 里控制）
	_hitbox_area.monitoring = false


# 从 data/characters.json 读角色初始属性
func _load_character_data() -> void:
	var data: Dictionary = DataManager.get_data("characters")
	if data.is_empty():
		push_warning("Player: characters.json 为空，用默认值")
		return
	var initial: Dictionary = data.get("initial", {})
	max_hp = int(initial.get("HP", 100))
	current_hp = max_hp
	# v2.9 夯实地基：mask 数据驱动（默认 4=怪物层，联机版加 PvP 改 JSON）
	_attack_target_mask = int(initial.get("attack_target_mask", 4))


func _physics_process(delta: float) -> void:
	# === 死亡淡出 ===
	if _is_dying:
		_die_timer += delta
		var progress: float = _die_timer / DIE_FADE_DURATION
		modulate.a = 1.0 - progress
		if progress >= 1.0:
			_respawn()
		return

	# === 无敌帧倒计时 ===
	if _invincible_timer > 0:
		_invincible_timer -= delta

	# === 攻击冷却倒计时 ===
	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta

	# === 移动 ===
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		_facing = direction.normalized()

	# === 攻击动画计时 ===
	if _attack_timer > 0:
		_attack_timer -= delta
		# 攻击中闪白
		modulate = Color(3.0, 3.0, 3.0, 1.0)
		_hitbox_area.monitoring = true
		# v2.9 夯实地基：hitbox 以玩家为中心不偏移，朝向由 _facing 控制（DamageArea 用）
		# 不再需要 _update_hitbox_position()，朝向在 _check_hit() 里通过 _facing 传给 DamageArea
		if not _attack_hit:
			_check_hit()
	else:
		if _invincible_timer <= 0:
			modulate = Color(1, 1, 1, 1)
		_hitbox_area.monitoring = false
		_attack_hit = false

	# === 触发攻击（检查冷却）===
	if Input.is_action_just_pressed("attack") and _attack_cd_timer <= 0:
		_start_attack()


func _start_attack() -> void:
	_attack_timer = attack_duration
	_attack_cd_timer = attack_cooldown  # 进入冷却
	_attack_hit = false
	_shake_camera(2.0, 0.1)


# 修复 2：检测命中时排除自己
# 步骤 3：用 DamageArea 工具类按扇形精筛（半径 68 + 45 度）
# v2.9 夯实地基：hitbox 以玩家为中心 136×136，扇形朝向由 _facing 控制
func _check_hit() -> void:
	var bodies: Array = _hitbox_area.get_overlapping_bodies()
	# 粗筛：排除玩家自己 + 排除死亡目标 + 必须有 take_damage
	var candidates: Array = []
	for body in bodies:
		# === 关键修复：排除玩家自己 ===
		# Phase 4 新增 take_damage 后，hitbox 会检测到自己
		# 必须跳过自己，否则按 J 就自己打自己
		if body == self:
			continue
		if body.has_method("take_damage") and not bool(body.get("_is_dying")):
			candidates.append(body)
	# 精筛：用 DamageArea 按扇形判定
	var hits: Array = DamageArea.filter_targets(global_position, _facing, ATTACK_SHAPE_CONFIG, candidates)
	# Phase 4.5：本次攻击若命中至少 1 个目标，消耗 1 点武器耐久（一次攻击只消耗 1 点）
	var has_hit: bool = hits.size() > 0
	for body in hits:
		if body == null or not is_instance_valid(body):
			continue
		# 4.4.6 传 self 作为 attacker，让怪物仇恨机制知道是玩家打的
		body.take_damage(attack_damage, self)
		_attack_hit = true
		_spawn_damage_number(attack_damage, body.global_position)
		_shake_camera(4.5, 0.12)
		# hit_count=1 时只打 1 个
		if int(ATTACK_SHAPE_CONFIG.get("hit_count", 1)) == 1:
			break
	if has_hit:
		EquipmentManager.consume_durability("weapon", 1)


func _shake_camera(intensity: float, duration: float) -> void:
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam == null:
		return
	var t: Tween = create_tween()
	var offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	cam.offset = offset
	t.tween_property(cam, "offset", Vector2.ZERO, duration)


func _spawn_damage_number(amount: int, pos: Vector2) -> void:
	# 步骤 1：改为调用全局 DamageNumberManager（统一伤害飘字入口）
	DamageNumberManager.show_damage_number(pos, amount, "damage")


# === 玩家受伤 ===
func take_damage(amount: int) -> void:
	if _is_dying:
		return
	if _invincible_timer > 0:
		print("[Player] 无敌帧内，忽略伤害 %d" % amount)
		return

	current_hp -= amount
	print("[Player] 受伤！扣 %d，剩余 %d/%d" % [amount, current_hp, max_hp])

	# 修复 3：闪白更明显（0.15 秒 + 更极端的颜色）
	modulate = Color(8.0, 8.0, 8.0, 1.0)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)

	_spawn_damage_number(amount, global_position)
	_shake_camera(5.0, 0.15)  # 屏震也加强

	_invincible_timer = INVINCIBLE_DURATION

	if current_hp <= 0:
		current_hp = 0
		_start_dying()


func _start_dying() -> void:
	_is_dying = true
	_die_timer = 0.0
	velocity = Vector2.ZERO
	_hitbox_area.monitoring = false
	print("[Player] 死亡！开始淡出...")


func _respawn() -> void:
	_is_dying = false
	_die_timer = 0.0
	current_hp = max_hp
	modulate.a = 1.0
	modulate = Color(1, 1, 1, 1)
	global_position = _safe_position
	print("[Player] 重生！血量恢复 %d/%d" % [current_hp, max_hp])
