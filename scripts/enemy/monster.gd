extends CharacterBody2D
## 怪物基类 - Phase 4.1（修复版）
## 负责：从 monsters.json 读数据、受击扣血、死亡淡出、攻击玩家
## 修复：加调试 print + 碰撞层分离适配

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

# === 内部状态 ===
var _attack_cd_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _is_telegraphing: bool = false
var _target: Node = null
var _is_dying: bool = false
var _die_timer: float = 0.0

const DIE_FADE_DURATION: float = 0.5

# === 调试开关 ===
# 设为 true 会在控制台打印 AI 状态，帮你看逻辑
# 验证通过后可以改成 false
var _debug: bool = true


func _ready() -> void:
	if monster_id != "":
		_load_data_from_json()
	# 找玩家节点
	await get_tree().process_frame
	var p: Node = get_parent().get_node_or_null("Player")
	if p != null:
		set_target(p)
		if _debug:
			print("[Monster:%s] 找到玩家目标！AI=%s HP=%d DMG=%d 速度=%f 攻击距离=%f" % [monster_id, ai_template, max_hp, damage, move_speed, attack_range])
	else:
		print("[Monster:%s] 警告：没找到 Player 节点！" % monster_id)


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

	match ai_template:
		"static":
			pass
		"melee_charger":
			_ai_melee_charger(delta)


func _ai_melee_charger(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
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
	else:
		modulate = Color(1, 1, 1, 1)

		if distance <= attack_range and _attack_cd_timer <= 0:
			# 进入攻击距离 + CD 好了 → 预警
			if _debug:
				print("[Monster:%s] 进入攻击距离(%.0f<=%.0f)，开始预警..." % [monster_id, distance, attack_range])
			_is_telegraphing = true
			_telegraph_timer = telegraph_duration
		elif distance > attack_range:
			# 不在攻击距离 → 走向玩家
			var direction: Vector2 = to_player.normalized()
			velocity = direction * move_speed
			move_and_slide()
		else:
			# 在攻击距离内但 CD 没好 → 等待
			velocity = Vector2.ZERO
			move_and_slide()


func _do_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		if _debug:
			print("[Monster:%s] 攻击失败：目标无效" % monster_id)
		return
	if _target.has_method("take_damage"):
		if _debug:
			print("[Monster:%s] 命中玩家！调用 take_damage(%d)" % [monster_id, damage])
		_target.take_damage(damage)
	else:
		if _debug:
			print("[Monster:%s] 目标没有 take_damage 方法" % monster_id)


func take_damage(amount: int) -> void:
	if _is_dying:
		return
	current_hp -= amount
	if _debug:
		print("[Monster:%s] 受击！扣 %d，剩余 %d/%d" % [monster_id, amount, current_hp, max_hp])
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)

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
	current_hp = max_hp


func set_target(target: Node) -> void:
	_target = target
