# 44 - DamageArea 抽象类落地

## 本游戏实例（v2.7 准则）

- **遇到的问题**：
  - **Phase 4.4.6 步骤 3**：4.4.6 时留了 DamageArea 接口未实现，玩家/宠物/怪物的攻击判定各自写一套（player 用 hitbox Area2D，pet 用 AttackArea Area2D，monster 用 distance 检查）
  - 未来加群体攻击/技能效果时，每个调用方都要改一遍，违反 §0.5 三问"加系统不重构"
  - 需要把"攻击范围判定"抽象成统一工具类，调用方只传 shape_config 切换形状
- **专业名词/知识点**：抽象类、纯工具类、`class_name`、`static func` 静态函数、shape_config 字典、候选目标粗筛 + 精筛、Vector2 数学（dot 投影、angle_to 夹角、normalized 归一化）
- **技术栈/代码/美术**：GDScript `class_name DamageArea`、`static func filter_targets()`、`scripts/combat/damage_area.gd`、player.gd/pet.gd/monster.gd 调用改造
- **应用过程**：
  1. §0.5 三问验证：MVP 够用（扇形 + 单体最近）/ 加系统不重构（新形状只改 _is_in_shape）/ 升级地基不改（碰撞层不动）
  2. 新建 `scripts/combat/damage_area.gd`（class_name + 不继承 Node 的纯工具类）
  3. 实现 `filter_targets(origin, facing, shape_config, candidates)` 静态方法
  4. 内部分两阶段：粗筛（调用方提供 candidates）→ 精筛（按形状判定）→ 数量筛选（hit_count）
  5. 改造 player.gd 的 `_check_hit()`：用 DamageArea 替代直接遍历
  6. 改造 pet.gd 的 `_check_pet_hit()`：用 DamageArea 替代遍历
  7. 改造 monster.gd 的 `_do_attack()` telegraph_then_check 分支：用 DamageArea 精确判定
  8. 加 `run_self_test()` 自测函数验证 5 种形状逻辑

---

## 概念

**DamageArea** 是"攻击范围判定"的抽象工具类——把"判断目标在不在攻击范围内"这件事独立出来，调用方只传形状配置（shape_config），不用关心怎么算。

**生活比喻 1（生动形象）**：蛋糕模具店——
- 模具店（DamageArea）提供各种形状的模具：圆形、方形、心形、星形
- 厨师（调用方）只说"我要圆形蛋糕"，模具店给圆形模具，厨师切蛋糕就行
- 加新形状（比如三角形）：模具店加一个模具（_is_in_shape 加分支），所有厨师都能用，厨师不需要学新技能

**生活比喻 2（本游戏应用）**：玩家、宠物、红尾蝎都"用扇形打 1 个最近目标"：
- 改前：player.gd 写一遍 Area2D + RectangleShape2D + 遍历 bodies，pet.gd 再写一遍，monster.gd 又写一遍
- 改后：三个都调 `DamageArea.filter_targets(origin, facing, {"type":"cone","radius":68,"arc_degree":45,"hit_count":1}, candidates)`
- 未来 Boss 用十字斩：JSON 改 `"attack_shape": "cross"`，代码不改

**反例 vs 正例**：
```
❌ 错误（每个调用方各写一套）：
# player.gd
for body in hitbox.get_overlapping_bodies():
    if body.has_method("take_damage"):
        body.take_damage(damage)

# pet.gd
for body in attack_area.get_overlapping_bodies():
    if body == _attack_target:
        body.take_damage(damage)

# monster.gd
if dist <= attack_range:
    _target.take_damage(damage)

✅ 正确（统一用 DamageArea 抽象类）：
var hits: Array = DamageArea.filter_targets(origin, facing, shape_config, candidates)
for body in hits:
    body.take_damage(damage)
# 调用方接口统一，形状/数量/朝向都在 shape_config 里
```

---

## 功能

- 统一"攻击范围判定"接口：`filter_targets(origin, facing, shape_config, candidates)`
- 支持 5 种形状：扇形 cone / 圆形 circle / 矩形 rectangle / 朝向矩形 rect_dir / 双十字 cross
- 支持 3 种命中模式：单体最近（hit_count=1）/ 群体（hit_count=-1）/ 最近 N 个（hit_count=N）
- 纯工具类（不继承 Node），不操作画面，只做数学计算（§1.1 逻辑显示分离）
- 数据驱动：形状参数全走 shape_config Dictionary（§1.2 数据驱动）
- 自测函数 `run_self_test()` 验证 5 种形状逻辑（步骤 4）

---

## 运作方式

### 文件结构

```
scripts/combat/
└── damage_area.gd   # class_name DamageArea（纯工具类，不继承 Node）
```

### 类签名

```gdscript
class_name DamageArea

enum ShapeType { CONE, CIRCLE, RECTANGLE, RECT_DIR, CROSS }
const HIT_COUNT_ALL: int = -1

static func filter_targets(
    origin: Vector2,           # 攻击者世界坐标
    facing: Vector2,           # 攻击者朝向（归一化向量）
    shape_config: Dictionary,  # 形状配置
    candidates: Array          # 候选目标（调用方粗筛后的 Node 列表）
) -> Array:                    # 返回命中目标数组
```

### shape_config 字段

```gdscript
{
    "type": "cone",           # 形状类型
    "radius": 68.0,           # cone/circle 用
    "arc_degree": 45.0,       # cone 用
    "width": 64.0,            # rectangle/rect_dir/cross 用
    "height": 64.0,           # rectangle 用
    "length": 68.0,           # rect_dir/cross 用
    "hit_count": 1            # 1=单体最近 / -1=群体 / N=最近 N 个
}
```

### 两阶段筛选流程

```
调用方提供 candidates（粗筛：AttackArea.get_overlapping_bodies() 或场景遍历）
    ↓
第一阶段：按形状精筛（_is_in_shape）
    遍历 candidates，对每个 body.global_position 判断是否在 shape 内
    在 → 加入 in_shape 数组
    ↓
第二阶段：按 hit_count 数量筛选
    hit_count = -1 → 返回全部 in_shape
    hit_count = 1 → 返回 [_get_nearest(in_shape)]
    hit_count = N → 返回 _get_nearest_n(in_shape, N)
```

### 调用方改造对照

**player.gd 的 _check_hit 改造**：
```gdscript
# 步骤 3 前（直接遍历）：
for body in bodies:
    if body == self: continue
    if body.has_method("take_damage"):
        body.take_damage(attack_damage, self)
        break

# 步骤 3 后（DamageArea 精筛）：
var candidates: Array = []
for body in bodies:
    if body == self: continue
    if body.has_method("take_damage") and not bool(body.get("_is_dying")):
        candidates.append(body)
var hits: Array = DamageArea.filter_targets(global_position, _facing, ATTACK_SHAPE_CONFIG, candidates)
for body in hits:
    body.take_damage(attack_damage, self)
    if int(ATTACK_SHAPE_CONFIG.get("hit_count", 1)) == 1:
        break
```

**pet.gd 的 _check_pet_hit 改造**：
```gdscript
var shape_config: Dictionary = {
    "type": _attack_shape_name,
    "radius": _attack_radius,
    "arc_degree": _attack_arc_degree,
    "hit_count": _hit_count
}
var facing: Vector2 = (_attack_target.global_position - global_position).normalized()
var hits: Array = DamageArea.filter_targets(global_position, facing, shape_config, candidates)
```

**monster.gd 的 _do_attack telegraph_then_check 分支改造**：
```gdscript
var shape_config: Dictionary = {
    "type": _attack_shape,
    "radius": _attack_radius,
    "arc_degree": _attack_arc_degree,
    "hit_count": _hit_count
}
var facing: Vector2 = (_target.global_position - global_position).normalized()
var hits: Array = DamageArea.filter_targets(global_position, facing, shape_config, [_target])
if hits.size() > 0:
    _apply_damage_to_target()
else:
    DamageNumberManager.show_damage_number(_target.global_position, 0, "miss")
```

### 自测函数（run_self_test）

```gdscript
# 在任意节点的 _ready() 加：print(DamageArea.run_self_test())
# 预期输出：
# [DamageArea 自测] 通过 16 / 失败 0（共 16 项）
# true
```

覆盖 5 种形状的边界用例：
- 扇形：正前方命中 / 后方不命中 / 超半径不命中 / 偏角超弧度不命中
- 圆形：右方命中 / 左方命中 / 超半径不命中
- 矩形：中心命中 / 边界命中 / 超高不命中
- 朝向矩形：前方命中 / 后方不命中 / 超长不命中 / 侧偏超宽不命中
- 双十字：中心命中 / 水平臂命中 / 垂直臂命中 / 对角不命中

---

## 原理

### 为什么 DamageArea 不继承 Node？

- DamageArea 是纯数学计算工具，不需要进场景树
- 继承 Node 会浪费内存（每个 Node 有 transform/signal/parent 等开销）
- GDScript 的 `class_name` + `static func` 可以当全局工具类用，不需要实例化
- 类似 Godot 内置的 `Mathf`、`JSON` 等工具类

### 为什么用静态函数（static func）？

- 静态函数不需要实例化对象就能调用：`DamageArea.filter_targets(...)`
- 静态函数内部不能用 `self`，但能用参数传入的所有数据
- 适合纯计算工具（无状态，输入 → 输出）
- 节省内存：不创建对象，不占堆内存

### 为什么要两阶段筛选（粗筛 + 精筛）？

- **粗筛**：调用方用 Area2D 的 `get_overlapping_bodies()` 拿到候选（物理引擎优化过的检测）
- **精筛**：DamageArea 按形状（扇形/圆形/矩形等）精确判定
- 粗筛省性能：Area2D 用碰撞引擎快速排除远处目标
- 精筛保准确：扇形/朝向矩形等形状 Area2D 不直接支持，需要数学计算

### 为什么粗筛用 Area2D 而不是遍历场景所有节点？

- Area2D 用 Godot 物理引擎（Box2D）优化，性能远高于遍历所有节点
- Area2D 的 collision_mask 可以过滤层（如 mask=4 只检测怪物层）
- 调用方已有 Area2D（player 的 hitbox、pet 的 AttackArea），复用现有节点

### shape_config 为什么用 Dictionary 而不是类？

- Dictionary 灵活：不同形状需要不同字段（cone 用 radius/arc_degree，rectangle 用 width/height）
- 数据驱动：shape_config 可以直接从 JSON 字段构造，无需中间类转换
- 缺点：类型不严格（运行时才检查字段名），但 MVP 阶段可接受

---

## 优势

| 优势 | 说明 |
|------|------|
| 统一接口 | 所有调用方都用 filter_targets，接口稳定 |
| 数据驱动 | 形状/数量/朝向全在 shape_config，加形状不改代码 |
| 性能优化 | 两阶段筛选（Area2D 粗筛 + 数学精筛）|
| 可测试 | run_self_test 自测函数验证逻辑 |
| §0.5 三问 PASS | MVP够用 / 加系统不重构 / 升级地基不改 |
| §1.1 逻辑分离 | 纯工具类不操作画面，只算数学 |

---

## 使用场景

### 场景 1：玩家普攻（cone + 单体最近）

```gdscript
const ATTACK_SHAPE_CONFIG: Dictionary = {
    "type": "cone", "radius": 68.0, "arc_degree": 45.0, "hit_count": 1
}
var hits: Array = DamageArea.filter_targets(global_position, _facing, ATTACK_SHAPE_CONFIG, candidates)
```

### 场景 2：群体技能（circle + 群体）

```gdscript
var aoe_cfg: Dictionary = {"type": "circle", "radius": 100, "hit_count": -1}
var hits: Array = DamageArea.filter_targets(global_position, Vector2.ZERO, aoe_cfg, candidates)
# 所有 100 像素内的敌人都命中
```

### 场景 3：直线冲刺（rect_dir + 单体）

```gdscript
var dash_cfg: Dictionary = {"type": "rect_dir", "length": 200, "width": 40, "hit_count": 1}
var hits: Array = DamageArea.filter_targets(global_position, _facing, dash_cfg, candidates)
# 朝向前方 200 像素、宽 40 像素的矩形内的最近 1 个敌人
```

### 场景 4：Boss 十字斩（cross + 群体）

```gdscript
var cross_cfg: Dictionary = {"type": "cross", "length": 150, "width": 30, "hit_count": -1}
var hits: Array = DamageArea.filter_targets(global_position, Vector2.ZERO, cross_cfg, candidates)
# 十字形范围内的所有敌人都命中
```

### 场景 5：加新形状（未来扩展）

```gdscript
# 1. 在 _parse_shape_type 加 match 分支
"hexagon": return ShapeType.HEXAGON

# 2. 在 _is_in_shape 加 match 分支
ShapeType.HEXAGON:
    # 六边形判定逻辑
    return _is_in_hexagon(origin, config, target_pos)

# 3. JSON 改 attack_shape="hexagon"
# 调用方代码完全不改
```

### 与其他系统对接

- **attack_pattern**：telegraph_then_check 分支用 DamageArea 精确判定
- **伤害飘字**：DamageArea 返回 hits 后，调用方对每个 hit 调 take_damage + show_damage_number
- **数据驱动**：shape_config 字段从 monsters.json/pets.json 读
- **Tween/动画系统**：未来加"攻击范围可视化"时，用 shape_config 画扇形/圆形预览
- **存档系统**：DamageArea 是无状态工具类，不影响存档

---

## 关联

- 攻击判定模式（attack_pattern 调用 DamageArea）：[[43-攻击判定模式]]
- 扇形攻击范围（cone 形状实现细节）：[[45-扇形攻击范围与多形状扩展]]
- 伤害飘字（DamageArea 返回 hits 后触发）：[[42-伤害飘字与Tween动画]]
- Area2D 粗筛原理（DamageArea 候选来源）：[[27-Area2D区域检测器]]
- 碰撞层（Area2D mask 过滤候选）：[[30-碰撞层与碰撞遮罩]]
- Vector2 数学（dot 投影 / angle_to 夹角 / normalized）：[[25-26-Vector2与Modulate闪白]]
- §0.5 三问论证（DamageArea 抽象类选型）：[[23-规则执行滑坡与3道防坡闸门]]
- 设计真值（DamageArea 接口/形状表）：见 docs/02-战斗系统.md "DamageArea 工具类段"
