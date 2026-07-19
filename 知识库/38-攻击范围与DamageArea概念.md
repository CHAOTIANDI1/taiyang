# 38 - 攻击范围与 DamageArea 概念

## 本游戏实例（v2.7 准则）

- **遇到的问题**：
  - **Phase 4.4.6**：宠物进入战斗模式后需要主动攻击怪物。怎么判定"宠物打到怪物了"？最早玩家攻击用 `Area2D + RectangleShape2D` 做 hitbox，但宠物攻击参数（范围/CD/持续时间）每个宠物不同，硬编码会违反 §1.2 数据驱动。同时用户提出"未来有的武器/宠物/魔物/技能要判定一块区域的攻击"——需要预留群体攻击接口，但又不能 MVP 阶段就抽象过度。
  - **设计冲突**：是 4.4.6 直接做 DamageArea 抽象类（参数化），还是先复用玩家的 Area2D hitbox 模式？
- **专业名词/知识点**：攻击范围（Attack Range）、攻击判定（Hit Detection）、Area2D hitbox、DamageArea 抽象类、单体攻击 vs 群体攻击、collision_mask（碰撞遮罩）
- **技术栈/代码/美术**：Godot 4 的 `Area2D` + `RectangleShape2D` + `get_overlapping_bodies()`、GDScript 的 `has_method()` / `get()` 安全访问、`data/pets.json` 的 `attack_range`/`attack_cooldown`/`attack_duration` 字段、`scripts/pet/pet.gd` 的 `_create_attack_area()` / `_find_nearest_monster()` / `_state_attack()` / `_check_pet_hit()` 方法
- **应用过程**：
  1. 走 §0.5 三问判断"4.4.6 该用 Area2D hitbox 还是抽象 DamageArea 类"
  2. 走 §1.7 新增系统协议 4 问判断"DamageArea 是否新增系统"
  3. 结论：4.4.6 用 Area2D hitbox（最简方案），DamageArea 抽象类留给未来
  4. pets.json 加 3 个字段（attack_range/attack_cooldown/attack_duration）—— 数据驱动
  5. pet.gd 的 `_create_attack_area()` 用 Area2D + RectangleShape2D 创建判定区
  6. `_find_nearest_monster()` 用 `get_overlapping_bodies()` 找最近怪物
  7. `_state_attack()` 朝目标移动到 `attack_range * 0.8` 距离 → 启动攻击 → `_check_pet_hit()` 命中 → 调用 `monster.take_damage(damage, self)`
  8. docs/03 第 105-108 行记录"未来 DamageArea 抽象"设计意图，留接口不实现

---

## 概念

**攻击范围** = 一个角色或物体能"打到"的空间区域。在这个区域内的目标会受伤。

**生活比喻 1（生动形象）**：你拿一把扫帚扫地，扫帚能扫到的最大范围就是一个圆形区域（约 1.5 米半径）。这个圆里头的灰都能被扫到，圆外头的灰扫不到。扫帚的"攻击范围"就是这 1.5 米半径。

**生活比喻 2（本游戏应用）**：宠物 `pet_001_ham_dog`（火腿狗）的 `attack_range = 45` 像素，意思是火腿狗能咬到 45 像素半径内的怪物。在 `pets.json` 里这个值是数据驱动的——`pet_003_silver_seed`（银色种子）的 `attack_range = 50`，比火腿狗远 5 像素（藤蔓攻击距离长一点）。

**DamageArea（未来抽象类）** = 把"造成伤害的区域"抽象成一个独立的概念，统一管理所有"打一片"的逻辑。不只是单体攻击，还包括范围技能、AOE（Area of Effect）、爆炸、毒雾等。

**反例 vs 正例**：
```
❌ 错误（硬编码攻击范围）：
if name == "火腿狗":
    attack_range = 45
elif name == "铁拳":
    attack_range = 40
# 加新宠物要改代码，违反 §1.2 数据驱动

✅ 正确（数据驱动 + Area2D hitbox）：
# pets.json
"pet_001_ham_dog": { "attack_range": 45, ... }

# pet.gd
_attack_range = float(data.get("attack_range", 45.0))
# 创建 Area2D 用 _attack_range 作为尺寸
# 加新宠物只改 JSON，不改代码
```

---

## 功能

- **攻击范围**：定义"能打到多远"
- **攻击判定**：检测目标是否在范围内 + 是否命中
- **攻击冷却（CD）**：避免每帧都打一下
- **攻击持续时间**：攻击动作的动画时长（命中检测只在这段时间内有效）
- **DamageArea 未来抽象**：把"造成伤害的区域"独立成类，支持多种形状（圆形/矩形/扇形）+ 多次命中 + 击退等

---

## 运作方式

### Phase 4.4.6 实际实现（Area2D hitbox）

```gdscript
# pet.gd 第 67-83 行：创建攻击判定区
func _create_attack_area() -> void:
    _attack_area = Area2D.new()
    _attack_area.name = "AttackArea"
    add_child(_attack_area)
    _attack_shape = CollisionShape2D.new()
    var rect: RectangleShape2D = RectangleShape2D.new()
    # size 是边长，以宠物为中心
    # 侦测范围 = 攻击范围 * 1.5（留追击缓冲）
    var detect_size: float = _attack_range * 1.5 * 2.0
    rect.size = Vector2(detect_size, detect_size)
    _attack_shape.shape = rect
    _attack_area.add_child(_attack_shape)
    # mask=4 只检测怪物层（Layer 4）
    _attack_area.collision_mask = 4
    _attack_area.monitoring = true

# pet.gd 第 188-205 行：侦测附近怪物
func _find_nearest_monster() -> Node:
    if _attack_area == null:
        return null
    var bodies: Array = _attack_area.get_overlapping_bodies()
    var nearest: Node = null
    var nearest_dist: float = 999999.0
    for body in bodies:
        if body == self:
            continue
        if body.has_method("take_damage") and not bool(body.get("_is_dying", false)):
            var dist: float = global_position.distance_to(body.global_position)
            if dist < nearest_dist:
                nearest_dist = dist
                nearest = body
    return nearest

# pet.gd 第 223-261 行：攻击状态逻辑
func _state_attack(delta: float) -> void:
    # 1. CD 倒计时
    # 2. 攻击动画计时（_attack_timer > 0 → 检测命中 + 闪白）
    # 3. CD 好了 → 朝目标移动到 attack_range*0.8 → 启动攻击
    # 4. CD 中 → 原地等待
    ...

# pet.gd 第 273-285 行：命中检测
func _check_pet_hit() -> void:
    var bodies: Array = _attack_area.get_overlapping_bodies()
    for body in bodies:
        if body == _attack_target and body.has_method("take_damage"):
            body.take_damage(damage, self)  # 传 self 作为 attacker
            _attack_hit = true
            break
```

### 代码逐行执行流程

**场景：火腿狗进入战斗模式，附近有红尾蝎**

```
帧 1：玩家按 Z 切换战斗模式
  _is_gentle_mode = false
  _update_state() 检测 _is_gentle_mode = false → _find_nearest_monster()
  AttackArea 检测到 red_scorpion 在范围内
  _attack_target = red_scorpion
  set_state("attack")
  打印：[Pet:pet_001_ham_dog] 状态切换 follow → attack（发现怪物 red_scorpion 距离=80.0）

帧 2-N：_state_attack(delta) 执行
  _attack_cd_timer > 0 → 倒计时
  _attack_cd_timer = 0 → 朝目标移动到 attack_range*0.8 = 36 像素
  距离 < 36 → 启动攻击 _start_pet_attack()
  _attack_timer = 0.3, _attack_cd_timer = 1.2, _attack_hit = false

帧 N+1：_attack_timer > 0 → 检测命中
  _check_pet_hit() 用 AttackArea 检测 _attack_target 是否在范围内
  命中 → red_scorpion.take_damage(10, self)
  _attack_hit = true（避免同一秒打多次）
  打印：[Pet:pet_001_ham_dog] 命中 red_scorpion！造成 10 伤害
```

### 关键参数表

| 参数 | 含义 | 数据驱动来源 | 默认值 |
|------|------|------------|--------|
| `attack_range` | 攻击范围（像素）| `pets.json` | 45.0 |
| `attack_cooldown` | 攻击 CD（秒）| `pets.json` | 1.2 |
| `attack_duration` | 攻击持续时间（秒）| `pets.json` | 0.3 |
| `detect_size` | 侦测范围 = attack_range × 1.5 × 2 | 代码常量 | 计算 |
| `collision_mask` | 碰撞遮罩 = 4（只检测怪物层）| 代码常量 | 4 |
| `_attack_hit` | 一次性命中标志（防多次伤害）| 代码变量 | false |

---

## 原理

### 为什么用 Area2D 而不是 distance_to 直接判断？

`distance_to` 也能判断距离，但 Area2D 有 3 个优势：

1. **物理引擎原生支持**：Area2D 用 BVH（bounding volume hierarchy）树优化，比遍历所有节点快
2. **多目标检测**：`get_overlapping_bodies()` 一次返回所有在区域内的目标，distance_to 要遍历
3. **形状可变**：未来加扇形/圆形攻击范围，Area2D 换 Shape 就行，distance_to 要重写判定逻辑

### 为什么 4.4.6 不直接做 DamageArea 抽象类？

走 §0.5 三问 + §1.7 4 问评估：

| 评估项 | 4.4.6 用 Area2D hitbox | 4.4.6 抽象 DamageArea 类 |
|--------|----------------------|------------------------|
| MVP 够用 | ✅ 单体攻击足够 | ❌ 过度设计 |
| 加系统不重构 | ✅ 未来加 DamageArea 独立类，不改 hitbox | ✅ 同 |
| 升级地基不改 | ✅ 碰撞层/数据驱动/存档不动 | ✅ 同 |
| §1.7 在 docs 提过 | ✅ docs/03 已记录"未来 DamageArea 抽象" | ❌ 新概念未在 docs |
| 数据驱动 | ✅ pets.json 加字段 | ❌ 需要新 JSON（damage_areas.json）|
| §1.4 数据文件清单 | ✅ 复用 pets.json | ❌ 新增 JSON 要先登记 |

**结论**：4.4.6 用 Area2D hitbox 是最简方案。DamageArea 抽象类留给未来加群体技能时再做。

### DamageArea 未来抽象的设计意图

未来 DamageArea 类的参数（写在 docs/03 第 107 行）：

```gdscript
# 未来 DamageArea 类（V1 实现）
class_name DamageArea extends Area2D

@export var shape: Shape2D          # 形状（矩形/圆形/扇形）
@export var size: Vector2           # 尺寸
@export var target_layer: int = 4   # 目标碰撞层（默认怪物层）
@export var damage: int = 0         # 伤害值
@export var hit_count: int = 1      # 命中次数（1=单体，-1=无限）
@export var duration: float = 0.3   # 持续时间
@export var knockback: float = 0.0  # 击退力度（未来加）
```

**升级路径**：
- MVP（4.4.6）：Area2D hitbox（pet.gd 内联代码）
- V1：DamageArea 抽象类（独立脚本，pet.gd 调用）
- 联机版：DamageArea 同步逻辑（服务器判定）

每一步升级，pet.gd 的调用接口不变（`body.take_damage(damage, self)`），地基不动。

---

## 优势

| 优势 | 说明 |
|------|------|
| 数据驱动 | 加新宠物只改 pets.json，不改代码 |
| 单体/群体兼容 | Area2D 支持多目标，未来加群体攻击只需改 hit_count |
| 性能优化 | Area2D 用 BVH 树，比遍历快 |
| 升级平滑 | hitbox → DamageArea → 同步 DamageArea，渐进升级 |
| 地基稳定 | 碰撞层/数据驱动/存档接口全不动 |
| 调试容易 | `print(_attack_area.get_overlapping_bodies())` 直接看检测到啥 |

---

## 使用场景

### 场景 1：宠物攻击怪物（Phase 4.4.6 当前实现）

pet.gd 用 AttackArea 侦测附近怪物 + 命中判定。每个宠物的 attack_range 不同（数据驱动）。

### 场景 2：玩家攻击（player.gd 已实现）

player.gd 的 HitArea 也是 Area2D hitbox，mask=4（怪物层）。和宠物用同样的模式。

### 场景 3：未来群体技能（V1）

火球术打一片：DamageArea 类，shape=圆形，size=半径 80，hit_count=-1（无限），target_layer=4。一次施放打中范围内的所有怪物。

### 场景 4：未来 Boss AOE（V1）

Boss 旋风斩：DamageArea 类，shape=扇形，size=半径 120 + 角度 90°，hit_count=10（最多打 10 个目标），target_layer=2（玩家层）。

### 与其他系统对接

- **DataManager**：`get_pet(id)` 返回 pets.json 数据，含 attack_range 等字段
- **碰撞层（[[30-碰撞层与碰撞遮罩]]）**：AttackArea 的 collision_mask=4 检测 Layer 4（怪物层），不会误伤玩家（Layer 2）或宠物（Layer 16）
- **Area2D（[[27-Area2D区域检测器]]）**：AttackArea 本质是 Area2D 的应用
- **take_damage 接口**：DamageArea 命中后调用 `body.take_damage(damage, attacker)`，attacker 用于仇恨机制（[[39-仇恨机制与温和模式]]）

---

## 关联

- Area2D 检测原理：[[27-Area2D区域检测器]]
- 碰撞层 mask=4 检测怪物层：[[30-碰撞层与碰撞遮罩]]
- 怪物受击后仇恨转移：[[39-仇恨机制与温和模式]]
- 状态机 attack 状态：[[33-状态机骨架]]
- Vector2 距离计算：[[25-26-Vector2与Modulate闪白]]
- 三项一致原则（数据/代码/文档同步）：[[08-三项一致原则]]
- §0.5 架构地基三问论证（为什么 4.4.6 不抽象 DamageArea）：[[23-规则执行滑坡与3道防坡闸门]]
