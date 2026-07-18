extends CharacterBody2D
## 角色脚本 - Phase 3
## WASD 移动 + J 攻击（带 hitbox 命中判定 + 屏震 + 飘字 + 闪白）

# export 让你在 Godot 编辑器右侧"检查器"里改这个值
# 不用动代码就能调速度
@export var speed: float = 250.0
@export var attack_duration: float = 0.2
@export var attack_damage: int = 10  # MVP 占位基础伤害，将来从 equipment.json 读

# 攻击状态计时
var _attack_timer: float = 0.0
var _attack_hit: bool = false   # 本次攻击是否已经命中过（防多帧重复扣）

# 当前面向方向（决定攻击 box 在角色哪一侧）
var _facing: Vector2 = Vector2(1, 0)   # 默认朝右

# 攻击判定区（Area2D + 碰撞形）
var _hitbox_area: Area2D
var _hitbox_shape: CollisionShape2D
# 默认 hitbox 配置
var _hitbox_width: float = 50.0
var _hitbox_height: float = 50.0
var _hitbox_offset: float = 35.0


func _ready() -> void:
	# 创建攻击判定区域（Area2D）
	# Area2D 是 Godot 的"区域检测器"，物体进入会发信号
	_hitbox_area = Area2D.new()
	_hitbox_area.name = "AttackHitbox"
	add_child(_hitbox_area)

	# 在 Area2D 里加一个矩形碰撞形
	_hitbox_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(_hitbox_width, _hitbox_height)
	_hitbox_shape.shape = rect
	_hitbox_area.add_child(_hitbox_shape)

	# 默认攻击范围关闭（只在按下 J 时短时间激活）
	_hitbox_area.monitoring = false


func _physics_process(delta: float) -> void:
	# === 移动 ===
	# get_vector 读多个动作名，一次返回标准化方向向量
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	# 记住面向方向（不动时保持上次方向）
	if direction != Vector2.ZERO:
		_facing = direction.normalized()

	# === 攻击状态倒计时 ===
	if _attack_timer > 0:
		_attack_timer -= delta
		# 攻击中角色闪白
		modulate = Color(2.0, 2.0, 2.0, 1.0)
		# 攻击期间 hitbox 激活
		_hitbox_area.monitoring = true
		# hitbox 跟随面向方向移动
		_update_hitbox_position()
		# 触发一次命中检测
		if not _attack_hit:
			_check_hit()
	else:
		modulate = Color(1, 1, 1, 1)
		_hitbox_area.monitoring = false
		_attack_hit = false

	# === 触发攻击 ===
	# is_action_just_pressed 只在这帧第一次按下了才触发
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0:
		_start_attack()


func _start_attack() -> void:
	_attack_timer = attack_duration
	_attack_hit = false
	# 攻击时屏震一下（调摄像机的偏移）
	_shake_camera(2.0, 0.1)


# 把 hitbox 摆到角色面向方向的前方
func _update_hitbox_position() -> void:
	# Area2D 位置 = 面向方向 × 偏移距离
	_hitbox_area.position = _facing * _hitbox_offset


# 检测当前攻击是否命中了怪物（防多帧重复扣）
func _check_hit() -> void:
	# get_overlapping_bodies 拿到所有跟 Area2D 重叠的物理体
	var bodies: Array = _hitbox_area.get_overlapping_bodies()
	for body in bodies:
		# 检查是不是 monster.gd 挂的节点
		# has_method("take_damage") 是个简单又不依赖具体类型的方法
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			_attack_hit = true  # 这次攻击命中过了
			# 飘出伤害数字
			_spawn_damage_number(attack_damage, body.global_position)
			# 命中时小屏震
			_shake_camera(3.0, 0.08)
			break  # MVP 一次攻击只命中一个怪


# 屏震：偏移摄像机再让它归位
func _shake_camera(intensity: float, duration: float) -> void:
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam == null:
		return
	# 用 Tween 让摄像机抖一下
	# Tween 在 Godot 4 是"补间动画"工具
	var t: SceneTreeTween = create_tween()
	# 第一段：从随机偏移 → 0，duration 秒
	var offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	cam.offset = offset
	t.tween_property(cam, "offset", Vector2.ZERO, duration)


# 飘伤害数字（用 Label 节点 + Tween）
func _spawn_damage_number(amount: int, position: Vector2) -> void:
	# 创一个 Label 节点（文字）
	var label: Label = Label.new()
	label.text = str(amount)
	label.position = position + Vector2(0, -20)   # 在怪头上偏上 20
	label.modulate = Color(1, 0.5, 0.5, 1)  # 红色
	# 必须加到场景树才能看见
	get_parent().add_child(label)

	# 用 Tween 让数字上飘 + 淡出
	var t: SceneTreeTween = create_tween()
	# parallel() 让两个 tween 并行（同时）执行
	t.parallel().tween_property(label, "position:y", label.position.y - 40, 0.6)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	# 0.6 秒后销毁 Label
	t.chain().tween_callback(label.queue_free)


func take_damage(amount: int) -> void:
	# Phase 5 实现玩家受伤逻辑
	pass