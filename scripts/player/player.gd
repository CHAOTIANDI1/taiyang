extends CharacterBody2D
## 角色脚本 - Phase 2
## 控制 WASD 移动 + J 攻击占位（攻出闪白特效）

@export var speed: float = 250.0
@export var attack_duration: float = 0.2

var _attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# 移动逻辑：读取 WASD 输入，按速度向量移动
	# Input.get_vector 返回一个 Vector2（2D 向量）
	# 左右上下四个方向键被按下了多少
	# 例如按 D 不按其他 → 返回 (1, 0)，移动方向就是右
	# 同时按 W+D → 返回 (1, -1)，移动右上方（会自动归一化避免对角线快 1.4 倍）
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# velocity 是 CharacterBody2D 内置变量，表示当前速度
	# direction * speed = 把方向向量乘以速度得到实际速度向量
	velocity = direction * speed

	# move_and_slide 是 CharacterBody2D 的内置函数
	# 它会用 velocity 移动角色，碰到墙就停（这就是"滑动"的意思）
	move_and_slide()

	# 攻击计时器倒计时
	if _attack_timer > 0:
		_attack_timer -= delta
		# 攻击时角色闪白（modulate 是颜色调节器，乘纯白 = 闪白）
		modulate = Color(2, 2, 2, 1)
	else:
		# 非攻击时恢复原色
		modulate = Color(1, 1, 1, 1)

	# 按下 J 键触发攻击
	# Input.is_action_just_pressed 表示只在这帧第一次按下了才触发
	# （按住不放不会每帧都触发）
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0:
		_attack_timer = attack_duration
		print("攻击触发！")  # 占位：将来在这里加攻击 Area2D + 命中判定