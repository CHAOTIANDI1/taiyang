# 47 - AttackAreaFactory 工厂与 mask 数据驱动

## 本游戏实例（v2.7 准则）

- **遇到的问题**：
  - **Phase 4.4.6 步骤 5 验收时**：用户 F5 跑游戏，看控制台日志发现怪物攻击只命中当前 `_target`，玩家跑开后即使战斗模式宠物在扇形内也不被换目标命中
  - 走闸门 C 差异审计发现 4 个不夯实点：
    - A. 怪物 telegraph_then_check 只判 _target，未实现区域性选择单体
    - B. 玩家 hitbox 50×50 矩形对角线≈35 < 扇形精筛半径 68，会漏判扇形边缘目标
    - C. 三处 AttackArea collision_mask 全部硬编码，联机版加 PvP 要改代码
    - D. 三处 AttackArea 创建逻辑（Area2D + CollisionShape2D + RectangleShape2D）重复
  - 用户追问："这次修复把地基不夯实的问题解决完了么？"——促成 v2.9 闸门 B 升级 9→10 问
- **专业名词/知识点**：工厂模式（Factory Pattern）、纯工具类（class_name + static func）、碰撞层 mask 数据驱动、区域性选择单体、Area2D + CollisionShape2D + RectangleShape2D 三件套、闸门 B 第 10 问架构地基夯实度审查
- **技术栈/代码/美术**：GDScript 4.7 的 `class_name AttackAreaFactory` + `static func create()`、`Area2D.new()` + `CollisionShape2D.new()` + `RectangleShape2D.new()`、JSON 数据驱动（monsters.json / pets.json / characters.json 的 `attack_target_mask` 字段）
- **应用过程**：
  1. 用户 F5 发现怪物攻击只打 _target，没实现区域性选择单体
  2. 走闸门 C 5 问差异审计，确认是"实现没跟上设计真值"的滑坡
  3. 用户问"地基夯实了吗"——发现还有 B/C/D 三个不夯实点
  4. 升级 AGENTS.md v2.8 → v2.9，加闸门 B 第 10 问"架构地基夯实度审查"
  5. 完整夯实 4 个不夯实点：A 改 monster.gd / B 改 player.gd / C 加 JSON 字段 / D 抽 AttackAreaFactory
  6. 补本文知识库，记录工厂模式 + mask 数据驱动的落地经验

---

## 概念

**工厂模式（Factory Pattern）**：把"创建对象的复杂逻辑"封装到一个独立类里，调用方只传参数就拿到配置好的对象，不用关心创建细节。

**生活比喻 1（生动形象）**：面包店工厂
- 你（调用方）想要一个面包（Area2D 节点）
- 不用自己揉面 + 发酵 + 烤（new Area2D + new CollisionShape2D + new RectangleShape2D + 配置）
- 跟工厂说"我要一个红豆吐司面包"（传参数：name="AttackHitbox", mask=4, size=Vector2(136,136)）
- 工厂给你一个烤好的面包（返回配置好的 Area2D）
- 你只需把面包拿回家吃（add_child + monitoring=true）

**生活比喻 2（本游戏应用）**：4.4.6 三处创建 AttackArea
- 玩家 hitbox：`Area2D.new()` + `CollisionShape2D.new()` + `RectangleShape2D.new()` + `rect.size = Vector2(50, 50)` + `area.mask = 4`（8 行代码）
- 宠物 AttackArea：同样 8 行代码（改 size 和 mask）
- 怪物 AttackArea：同样 8 行代码（再改 size 和 mask）
- 三处代码 90% 重复，10% 不同（size/mask/name）
- 抽 AttackAreaFactory 后：每处调用 1 行 `AttackAreaFactory.create(...)`，工厂里只写 1 次创建逻辑

**反例 vs 正例**：
```gdscript
❌ 错误（三处重复代码）：
# player.gd
_hitbox_area = Area2D.new()
_hitbox_area.name = "AttackHitbox"
add_child(_hitbox_area)
_hitbox_shape = CollisionShape2D.new()
var rect: RectangleShape2D = RectangleShape2D.new()
rect.size = Vector2(50, 50)
_hitbox_shape.shape = rect
_hitbox_area.add_child(_hitbox_shape)
_hitbox_area.monitoring = false
_hitbox_area.collision_mask = 4  # 硬编码

# pet.gd（重复一遍）
# monster.gd（再重复一遍）

✅ 正确（工厂函数统一）：
# AttackAreaFactory.gd
static func create(name, collision_mask, size, offset) -> Area2D:
    var area = Area2D.new()
    area.name = name
    area.position = offset
    area.monitoring = false
    area.collision_mask = collision_mask
    var shape_node = CollisionShape2D.new()
    var rect = RectangleShape2D.new()
    rect.size = size
    shape_node.shape = rect
    area.add_child(shape_node)
    return area

# 三处调用方各 1 行：
_hitbox_area = AttackAreaFactory.create("AttackHitbox", _attack_target_mask, Vector2(136,136), Vector2.ZERO)
```

---

## 功能

- 统一封装 Area2D + CollisionShape2D + RectangleShape2D 的创建逻辑
- mask 数据驱动：从 JSON 读 `attack_target_mask` 字段，避免硬编码
- 解决"重复代码"不夯实点 D
- 解决"硬编码 mask"不夯实点 C
- 联机版加 PvP 时改 JSON 即可，不改代码

---

## 运作方式

### AttackAreaFactory 类结构

```gdscript
# scripts/combat/attack_area_factory.gd
class_name AttackAreaFactory

static func create(name: String, collision_mask: int, size: Vector2, offset: Vector2 = Vector2.ZERO) -> Area2D:
    var area: Area2D = Area2D.new()
    area.name = name
    area.position = offset
    area.monitoring = false  # 默认关闭，调用方按需开启
    area.collision_mask = collision_mask
    
    var shape_node: CollisionShape2D = CollisionShape2D.new()
    var rect: RectangleShape2D = RectangleShape2D.new()
    rect.size = size
    shape_node.shape = rect
    area.add_child(shape_node)
    
    return area
```

### 三处调用方对照

| 调用方 | name | mask 来源 | size | offset |
|--------|------|----------|------|--------|
| 玩家 hitbox（player.gd）| "AttackHitbox" | `characters.json` 的 `attack_target_mask`（默认 4）| 136×136（扇形半径×2）| Vector2.ZERO |
| 宠物 AttackArea（pet.gd）| "AttackArea" | `pets.json` 的 `attack_target_mask`（默认 4）| attack_range×1.5×2 | Vector2.ZERO |
| 怪物 AttackArea（monster.gd）| "AttackArea" | `monsters.json` 的 `attack_target_mask`（默认 18）| 136×136 | Vector2.ZERO |

### mask 数据驱动流程

```
1. JSON 文件配置：
   data/monsters.json → "red_scorpion" → "attack_target_mask": 18
   data/pets.json → "pet_001_ham_dog" → "attack_target_mask": 4
   data/characters.json → "initial" → "attack_target_mask": 4

2. 代码读取：
   monster.gd _load_data_from_json():
       _attack_target_mask = int(data.get("attack_target_mask", 18))
   pet.gd _load_data_from_json():
       _attack_target_mask = int(data.get("attack_target_mask", 4))
   player.gd _load_character_data():
       _attack_target_mask = int(initial.get("attack_target_mask", 4))

3. 调用工厂函数：
   _attack_area = AttackAreaFactory.create("AttackArea", _attack_target_mask, ...)

4. 联机版扩展（不改代码，只改 JSON）：
   characters.json → "attack_target_mask": 22  # 2|4|16 = 玩家+怪物+宠物（PvP）
```

### 三处调用方 monitoring 策略

| 调用方 | 平时 | 攻击时 | 原因 |
|--------|------|--------|------|
| 玩家 hitbox | monitoring=false | attack_duration 期间 true | J 键才检测，避免一直耗性能 |
| 宠物 AttackArea | monitoring=true（一直开）| - | 需要持续侦测附近怪物（_find_nearest_monster 用）|
| 怪物 AttackArea | monitoring=false | telegraph_duration 期间 true | 预警时才检测，避免一直耗性能 |

### 区域性选择单体的运作流程（monster.gd telegraph_then_check）

```
1. 怪物进入攻击距离 → 开始预警
   - _is_telegraphing = true
   - _attack_area.monitoring = true  ← v2.9 新增：开启 AttackArea

2. 预警中（telegraph_duration 倒计时）
   - AttackArea 持续检测重叠物体

3. 预警结束 → _do_attack()
   - 从 _attack_area.get_overlapping_bodies() 拿所有重叠物体
   - 粗筛：排除自己 + 排除死亡 + 排除温和模式宠物
   - 精筛：DamageArea.filter_targets(global_position, facing, shape_config, candidates)
   - hit_count=1 → DamageArea 自动返回扇形内最近的目标
   - 命中 → _apply_damage_to_specific_target(hits[0])  ← 可能是 _target 之外的另一个目标
   - 未命中 → 显示 miss 飘字

4. 预警结束关闭 monitoring
   - _attack_area.monitoring = false
```

---

## 原理

### 为什么用工厂模式？

工厂模式的核心价值是**封装变化**：
- 不变的部分（Area2D + CollisionShape2D + RectangleShape2D 的创建顺序）放工厂里
- 变化的部分（name/mask/size/offset）作为参数传入
- 调用方只关心"我要什么"，不关心"怎么造"

**类比**：你买车不用关心发动机怎么造的，只跟销售说"我要红色轿车 1.5T"。

### 为什么 AttackAreaFactory 不需要 JSON？

§1.4 数据文件清单例外条款：
- AttackAreaFactory 是**纯工具类**（class_name + static func，不继承 Node）
- 参数由调用方传入（name/mask/size/offset）
- 调用方传入的 mask 已经走 JSON（characters.json / pets.json / monsters.json 的 attack_target_mask 字段）
- 工厂本身没有"可变的数字"，不需要单独 JSON

**判断标准**：若该数据是"代码复用工具"→ 不需要 JSON；若是"游戏可变数值" → 进 JSON。

### 为什么 mask 用数据驱动？

**硬编码 mask 的问题**：
- 联机版加 PvP 时，玩家攻击应该能打其他玩家
- 当前玩家 hitbox mask=4（只检测怪物层）
- 联机版要改成 2|4|16（玩家+怪物+宠物）= 22
- 硬编码 → 改代码（player.gd 第 79 行）→ 每个攻击单位都要改一遍

**数据驱动 mask 的优势**：
- 改 JSON 即可（characters.json 的 attack_target_mask 字段从 4 改成 22）
- 代码不动，三处调用方统一从 JSON 读
- 符合 §1.2 数据驱动规矩

### 为什么区域性选择单体很重要？

**非区域性（只判 _target）的问题**：
- 怪物想打玩家，玩家跑开了
- 即使战斗模式宠物就在扇形内，怪物也 miss
- 不符合 hit_count=1 设计真值"范围内只打最近的 1 个"

**区域性选择单体（从 AttackArea 拿所有候选）**：
- 玩家跑开但宠物在扇形内 → 自动命中宠物
- 符合设计真值
- 联机版加组队/多宠物时，怪物能智能选择最近目标

### §0.5 三问论证

| 问 | 答 |
|----|----|
| MVP 够用吗？ | ✅ 工厂函数封装三处重复逻辑，区域性选择单体符合设计真值 |
| 加系统不重构吗？ | ✅ 加新攻击单位时调工厂函数即可；mask 改 JSON 即可 |
| 升级地基要改吗？ | ✅ 工厂接口稳定，未来加圆形成 cone 形粗筛时扩展接口（加 shape_type 参数），不改调用方 |

---

## 优势

| 优势 | 说明 |
|------|------|
| 代码复用 | 三处调用方各 1 行工厂调用，替代各 8 行重复代码 |
| 数据驱动 | mask 从 JSON 读，联机版扩展不改代码 |
| 区域性选择 | 怪物攻击能智能换目标，符合设计真值 |
| 性能可控 | monitoring 策略合理（玩家/怪物按需开，宠物一直开） |
| 易扩展 | 加新攻击单位（如 NPC 守卫）只需调工厂函数 + 加 JSON 字段 |

---

## 使用场景

### 场景 1：新增攻击单位（如 NPC 守卫）

```gdscript
# npc_guard.gd
var _attack_target_mask: int = 18  # 默认玩家+宠物（NPC 守卫是和平单位）

func _ready():
    _attack_area = AttackAreaFactory.create("AttackArea", _attack_target_mask, Vector2(136, 136), Vector2.ZERO)
    add_child(_attack_area)
    _attack_area.monitoring = false
```

无需复制 Area2D + CollisionShape2D + RectangleShape2D 的创建逻辑。

### 场景 2：联机版加 PvP

```json
// characters.json
{
  "initial": {
    "HP": 100,
    ...
    "attack_target_mask": 22  // 2|4|16 = 玩家+怪物+宠物（PvP）
  }
}
```

代码不动，玩家攻击就能打其他玩家了。

### 场景 3：未来加圆形粗筛（升级实现策略）

```gdscript
# AttackAreaFactory.gd 升级版（v3.0 联机版可能用）
static func create(name: String, collision_mask: int, size: float, offset: Vector2 = Vector2.ZERO, shape_type: String = "rectangle") -> Area2D:
    var area = Area2D.new()
    area.name = name
    area.position = offset
    area.monitoring = false
    area.collision_mask = collision_mask
    
    var shape_node = CollisionShape2D.new()
    match shape_type:
        "rectangle":
            var rect = RectangleShape2D.new()
            rect.size = Vector2(size, size)
            shape_node.shape = rect
        "circle":
            var circle = CircleShape2D.new()
            circle.radius = size / 2.0
            shape_node.shape = circle
    area.add_child(shape_node)
    return area
```

调用方加一个 shape_type 参数即可，原有调用方不传该参数默认用 rectangle，向后兼容。

### 与其他系统对接

- **DataManager**：提供 `get_monster(id)` / `get_pet(id)` / `get_data("characters")` 读 JSON
- **DamageArea**：精筛阶段用，与 AttackAreaFactory 是兄弟工具类
- **碰撞层规范**：见 `知识库/30-碰撞层与碰撞遮罩.md`
- **三项一致原则**：JSON 加字段 → 代码读字段 → docs 同步说明

---

## 关联

- 闸门 B 第 10 问架构地基夯实度审查（本次任务的触发原因）：[[23-规则执行滑坡与3道防坡闸门]]
- 碰撞层与 mask 规范（Layer 2/4/16 分配）：[[30-碰撞层与碰撞遮罩]]
- DamageArea 工具类（兄弟工具类，精筛阶段用）：[[44-DamageArea抽象类落地]]
- 区域性选择单体（hit_count=1 设计真值）：[[45-扇形攻击范围与多形状扩展]]
- 数据驱动架构（JSON + 代码分离）：[[03-数据驱动架构与JSON工作原理]]
- 报错三步流程（v2.9 升级触发）：[[12-AGENTS宪法治理逻辑]]
- 三项一致原则（JSON/代码/docs 同步）：[[08-三项一致原则]]
- §0.5 架构地基三问（MVP够用/加系统不重构/升级地基不改）：[[23-规则执行滑坡与3道防坡闸门]]
