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
var _hitbox_area: Area2D
var _hitbox_shape: CollisionShape2D
var _hitbox_width: float = 50.0
var _hitbox_height: float = 50.0
var _hitbox_offset: float = 35.0

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

	# 创建攻击判定区域
	_hitbox_area = Area2D.new()
	_hitbox_area.name = "AttackHitbox"
	add_child(_hitbox_area)

	_hitbox_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(_hitbox_width, _hitbox_height)
	_hitbox_shape.shape = rect
	_hitbox_area.add_child(_hitbox_shape)

	# 默认关闭
	_hitbox_area.monitoring = false

	# === 修复 1：设置碰撞层 ===
	# 玩家自己在 layer 2，hitbox 的 mask 设为 layer 4（怪物专用检测层）
	# 这样 hitbox 只检测怪物，不检测玩家自己
	# layer 是"自己在哪层"，mask 是"自己检测哪层"
	# 玩家 collision_layer=2（在 world.tscn 设置）
	# 怪物 collision_layer=4（在 world.tscn 设置）
	# hitbox Area2D：mask=4（只检测 layer 4 的怪物）
	_hitbox_area.collision_mask = 4  # 只检测怪物层


# 从 data/characters.json 读角色初始属性
func _load_character_data() -> void:
	var data: Dictionary = DataManager.get_data("characters")
	if data.is_empty():
		push_warning("Player: characters.json 为空，用默认值")
		return
	var initial: Dictionary = data.get("initial", {})
	max_hp = int(initial.get("HP", 100))
	current_hp = max_hp


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
		_update_hitbox_position()
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


func _update_hitbox_position() -> void:
	_hitbox_area.position = _facing * _hitbox_offset


# 修复 2：检测命中时排除自己
# 步骤 3：用 DamageArea 工具类按扇形精筛（半径 68 + 45 度）
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
