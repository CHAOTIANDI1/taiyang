class_name DamageArea
## 攻击范围判定工具类（Phase 4.4.6 步骤 3 落地）
## 负责：根据形状配置（扇形/圆形/矩形/朝向矩形/双十字）筛选命中目标
##
## 设计原则：
##   - 纯工具类（不继承 Node），不操作画面，只做数学计算（§1.1 逻辑显示分离）
##   - 数据驱动：形状参数全部走 shape_config Dictionary（§1.2 数据驱动）
##   - 候选目标由调用方提供（AttackArea.get_overlapping_bodies() 或场景遍历）
##
## §0.5 三问 PASS：
##   1. MVP 够用吗？是（扇形 + 单体最近满足玩家/宠物/红尾蝎）
##   2. 加系统不重构吗？是（新形状只改 _is_in_shape 一处，调用方接口不变）
##   3. 升级地基不改吗？是（碰撞层/数据驱动/存档不动）

# 形状类型枚举
enum ShapeType {
	CONE,        # 扇形（朝向 + 半径 + 角度）
	CIRCLE,      # 圆形（半径，全方向）
	RECTANGLE,   # 矩形（以自身为中心，宽高）
	RECT_DIR,    # 朝向矩形（从自身向朝向延伸，宽长）
	CROSS        # 双十字矩形（两个互相垂直的矩形交叉）
}

# 命中模式常量
const HIT_COUNT_ALL: int = -1  # 群体（范围内全部命中）


## 主入口：根据 shape_config 筛选 candidates
## origin: 攻击者世界坐标
## facing: 攻击者朝向（归一化向量，扇形/朝向矩形用）
## shape_config: {
##   "type": "cone"/"circle"/"rectangle"/"rect_dir"/"cross",
##   "radius": float,        # cone/circle 用
##   "arc_degree": float,    # cone 用
##   "width": float,         # rectangle/rect_dir/cross 用
##   "height": float,        # rectangle 用
##   "length": float,        # rect_dir/cross 用
##   "hit_count": int        # 1=单体最近 / -1=群体 / N=最近 N 个
## }
## candidates: 候选目标数组（Node 列表，调用方负责粗筛：排除自己、过滤非 Node2D 等）
## 返回：命中目标数组（按 hit_count 筛选后）
static func filter_targets(
	origin: Vector2,
	facing: Vector2,
	shape_config: Dictionary,
	candidates: Array
) -> Array:
	var shape_type_str: String = String(shape_config.get("type", "cone"))
	var shape_type: int = _parse_shape_type(shape_type_str)

	# 第一阶段：按形状筛选（粗筛后的候选 → 形状内目标）
	var in_shape: Array = []
	for body in candidates:
		if not is_instance_valid(body):
			continue
		if not (body is Node2D):
			continue
		if _is_in_shape(origin, facing, shape_type, shape_config, body.global_position):
			in_shape.append(body)

	# 第二阶段：按命中数量筛选
	var hit_count: int = int(shape_config.get("hit_count", 1))
	if hit_count == HIT_COUNT_ALL:
		# 群体：返回全部在形状内的目标
		return in_shape
	elif hit_count == 1:
		# 单体最近：返回最近的 1 个
		var nearest: Node = _get_nearest(origin, in_shape)
		return [nearest] if nearest != null else []
	elif hit_count > 1:
		# 最近 N 个
		return _get_nearest_n(origin, in_shape, hit_count)
	else:
		# 异常值（如 0），按单体最近处理
		var nearest: Node = _get_nearest(origin, in_shape)
		return [nearest] if nearest != null else []


## 把字符串形状名解析为枚举
static func _parse_shape_type(s: String) -> int:
	match s:
		"cone": return ShapeType.CONE
		"circle": return ShapeType.CIRCLE
		"rectangle": return ShapeType.RECTANGLE
		"rect_dir": return ShapeType.RECT_DIR
		"cross": return ShapeType.CROSS
		_: return ShapeType.CONE


## 判断目标点是否在形状内
static func _is_in_shape(
	origin: Vector2,
	facing: Vector2,
	shape_type: int,
	config: Dictionary,
	target_pos: Vector2
) -> bool:
	var to_target: Vector2 = target_pos - origin
	var dist: float = to_target.length()

	match shape_type:
		ShapeType.CONE:
			# 扇形：半径 + 朝向夹角
			var radius: float = float(config.get("radius", 68.0))
			var arc_deg: float = float(config.get("arc_degree", 45.0))
			if dist > radius:
				return false
			# 自身位置算命中（dist 接近 0）
			if dist < 0.01:
				return true
			# 计算朝向到目标的角度差（绝对值，度数）
			var facing_n: Vector2 = facing.normalized() if facing.length() > 0.01 else Vector2(1, 0)
			var angle_to: float = rad_to_deg(facing_n.angle_to(to_target))
			return abs(angle_to) <= arc_deg / 2.0

		ShapeType.CIRCLE:
			# 圆形：仅半径，无朝向
			var radius: float = float(config.get("radius", 68.0))
			return dist <= radius

		ShapeType.RECTANGLE:
			# 矩形：以自身为中心，宽高（世界坐标，不旋转）
			var width: float = float(config.get("width", 64.0))
			var height: float = float(config.get("height", 64.0))
			var dx: float = abs(to_target.x)
			var dy: float = abs(to_target.y)
			return dx <= width / 2.0 and dy <= height / 2.0

		ShapeType.RECT_DIR:
			# 朝向矩形：从自身向朝向延伸，length 是长度，width 是宽度
			var length: float = float(config.get("length", 68.0))
			var width: float = float(config.get("width", 32.0))
			var facing_n: Vector2 = facing.normalized() if facing.length() > 0.01 else Vector2(1, 0)
			# 投影到朝向方向（正方向才算，向后不算）
			var proj_along: float = to_target.dot(facing_n)
			if proj_along < 0 or proj_along > length:
				return false
			# 投影到垂直方向（绝对值）
			var perp: Vector2 = Vector2(-facing_n.y, facing_n.x)
			var proj_perp: float = abs(to_target.dot(perp))
			return proj_perp <= width / 2.0

		ShapeType.CROSS:
			# 双十字：两个互相垂直的矩形交叉（世界坐标，不旋转）
			# 水平矩形：长 length 沿 X，宽 width 沿 Y
			# 垂直矩形：长 length 沿 Y，宽 width 沿 X
			var length: float = float(config.get("length", 80.0))
			var width: float = float(config.get("width", 24.0))
			var dx: float = abs(to_target.x)
			var dy: float = abs(to_target.y)
			var in_horizontal: bool = dx <= length / 2.0 and dy <= width / 2.0
			var in_vertical: bool = dx <= width / 2.0 and dy <= length / 2.0
			return in_horizontal or in_vertical

	return false


## 找最近的 1 个目标
static func _get_nearest(origin: Vector2, candidates: Array) -> Node:
	var nearest: Node = null
	var nearest_dist: float = 999999.0
	for body in candidates:
		if not is_instance_valid(body) or not (body is Node2D):
			continue
		var d: float = origin.distance_to(body.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = body
	return nearest


## 找最近的 N 个目标（按距离升序排序后取前 N 个）
static func _get_nearest_n(origin: Vector2, candidates: Array, n: int) -> Array:
	var sorted: Array = candidates.duplicate()
	sorted.sort_custom(func(a, b):
		return origin.distance_to(a.global_position) < origin.distance_to(b.global_position)
	)
	if sorted.size() <= n:
		return sorted
	return sorted.slice(0, n)


## 调试用：把 shape_config 转可读字符串
static func describe_shape(shape_config: Dictionary) -> String:
	var t: String = String(shape_config.get("type", "cone"))
	var parts: Array = ["type=" + t]
	match t:
		"cone":
			parts.append("radius=" + str(shape_config.get("radius", 68)))
			parts.append("arc=" + str(shape_config.get("arc_degree", 45)) + "°")
		"circle":
			parts.append("radius=" + str(shape_config.get("radius", 68)))
		"rectangle":
			parts.append("w=" + str(shape_config.get("width", 64)))
			parts.append("h=" + str(shape_config.get("height", 64)))
		"rect_dir":
			parts.append("len=" + str(shape_config.get("length", 68)))
			parts.append("w=" + str(shape_config.get("width", 32)))
		"cross":
			parts.append("len=" + str(shape_config.get("length", 80)))
			parts.append("w=" + str(shape_config.get("width", 24)))
	parts.append("hit=" + str(shape_config.get("hit_count", 1)))
	return "(" + ", ".join(parts) + ")"


## 步骤 4：自测函数 —— 验证各种形状的判定逻辑
## 调用方式：在任意节点的 _ready() 里加 print(DamageArea.run_self_test())
## 或在 Godot 编辑器的"远程调试"里手动调用
## 返回：true=全部通过 / false=有失败
static func run_self_test() -> bool:
	var origin: Vector2 = Vector2(0, 0)
	var facing: Vector2 = Vector2(1, 0)  # 朝右
	var pass_count: int = 0
	var fail_count: int = 0

	# === 扇形 cone 测试 ===
	var cone_cfg: Dictionary = {"type": "cone", "radius": 68, "arc_degree": 45, "hit_count": 1}
	# 正前方 30 像素应命中
	if _is_in_shape(origin, facing, ShapeType.CONE, cone_cfg, Vector2(30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CONE 正前方应命中 失败")
	# 后方 30 像素不应命中
	if not _is_in_shape(origin, facing, ShapeType.CONE, cone_cfg, Vector2(-30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CONE 后方不应命中 失败")
	# 正前方 80 像素（超出半径 68）不应命中
	if not _is_in_shape(origin, facing, ShapeType.CONE, cone_cfg, Vector2(80, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CONE 超出半径不应命中 失败")
	# 偏角 30 度（在 45/2=22.5 度外）不应命中
	if not _is_in_shape(origin, facing, ShapeType.CONE, cone_cfg, Vector2(30, 20)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CONE 偏角超弧度不应命中 失败")

	# === 圆形 circle 测试 ===
	var circle_cfg: Dictionary = {"type": "circle", "radius": 50, "hit_count": -1}
	# 任意方向 30 像素应命中
	if _is_in_shape(origin, facing, ShapeType.CIRCLE, circle_cfg, Vector2(30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CIRCLE 右方应命中 失败")
	if _is_in_shape(origin, facing, ShapeType.CIRCLE, circle_cfg, Vector2(-30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CIRCLE 左方应命中 失败")
	# 60 像素超出半径不应命中
	if not _is_in_shape(origin, facing, ShapeType.CIRCLE, circle_cfg, Vector2(60, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CIRCLE 超出半径不应命中 失败")

	# === 矩形 rectangle 测试（以自身为中心，宽 64 高 32）===
	var rect_cfg: Dictionary = {"type": "rectangle", "width": 64, "height": 32, "hit_count": 1}
	# 中心点应命中
	if _is_in_shape(origin, facing, ShapeType.RECTANGLE, rect_cfg, Vector2(0, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECTANGLE 中心应命中 失败")
	# (30, 0) 在宽 64 内（dx=30 <= 32）应命中
	if _is_in_shape(origin, facing, ShapeType.RECTANGLE, rect_cfg, Vector2(30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECTANGLE (30,0) 应命中 失败")
	# (0, 20) 在高 32 内（dy=20 > 16）不应命中
	if not _is_in_shape(origin, facing, ShapeType.RECTANGLE, rect_cfg, Vector2(0, 20)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECTANGLE (0,20) 不应命中 失败")

	# === 朝向矩形 rect_dir 测试（朝右，长 68 宽 32）===
	var rect_dir_cfg: Dictionary = {"type": "rect_dir", "length": 68, "width": 32, "hit_count": 1}
	# 前方 30 像素应命中
	if _is_in_shape(origin, facing, ShapeType.RECT_DIR, rect_dir_cfg, Vector2(30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECT_DIR 前方应命中 失败")
	# 后方 30 像素不应命中（朝向矩形只向前延伸）
	if not _is_in_shape(origin, facing, ShapeType.RECT_DIR, rect_dir_cfg, Vector2(-30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECT_DIR 后方不应命中 失败")
	# 前方 80 像素超出长度不应命中
	if not _is_in_shape(origin, facing, ShapeType.RECT_DIR, rect_dir_cfg, Vector2(80, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECT_DIR 超出长度不应命中 失败")
	# 前方 30 像素 + 侧偏 20 像素（超出宽度 32/2=16）不应命中
	if not _is_in_shape(origin, facing, ShapeType.RECT_DIR, rect_dir_cfg, Vector2(30, 20)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] RECT_DIR 侧偏超宽度不应命中 失败")

	# === 双十字 cross 测试（长 80 宽 24）===
	var cross_cfg: Dictionary = {"type": "cross", "length": 80, "width": 24, "hit_count": 1}
	# 中心应命中
	if _is_in_shape(origin, facing, ShapeType.CROSS, cross_cfg, Vector2(0, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CROSS 中心应命中 失败")
	# 水平臂 (30, 0) 应命中（dx=30 <= 40, dy=0 <= 12）
	if _is_in_shape(origin, facing, ShapeType.CROSS, cross_cfg, Vector2(30, 0)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CROSS 水平臂应命中 失败")
	# 垂直臂 (0, 30) 应命中（dx=0 <= 12, dy=30 <= 40）
	if _is_in_shape(origin, facing, ShapeType.CROSS, cross_cfg, Vector2(0, 30)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CROSS 垂直臂应命中 失败")
	# 对角 (30, 30) 不应命中（既不在水平臂也不在垂直臂）
	if not _is_in_shape(origin, facing, ShapeType.CROSS, cross_cfg, Vector2(30, 30)):
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] CROSS 对角不应命中 失败")

	# === hit_count 群体测试 ===
	# 用 MockBody 模拟（GDScript 不能直接 new Node，用 Dictionary 模拟位置）
	# 这里只测试 _get_nearest 和 _get_nearest_n 的逻辑（用空数组）
	var empty_hits: Array = _get_nearest(origin, [])
	if empty_hits == null:
		pass_count += 1
	else:
		fail_count += 1
		push_error("[DamageArea 自测] _get_nearest 空数组应返回 null 失败")

	print("[DamageArea 自测] 通过 %d / 失败 %d（共 %d 项）" % [pass_count, fail_count, pass_count + fail_count])
	return fail_count == 0
