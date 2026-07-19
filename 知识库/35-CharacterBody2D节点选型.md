# 35 - CharacterBody2D 节点选型（§0.5 架构地基三问实践）

## 本游戏实例（v2.7 准则）

- **遇到的问题**：Phase 4.4.2 宠物场景 `scenes/pet/pet.tscn` 的根节点选什么类型？Godot 2D 物理节点家族有四种：`CharacterBody2D` / `RigidBody2D` / `StaticBody2D` / `Area2D`。每种行为不同——选错类型会导致宠物要么被物理冲撞挤飞（RigidBody 受力）、要么无法移动（StaticBody 静止）、要么无法被墙挡住（Area2D 不阻挡）。需要按 AGENTS.md §0.5 架构地基三问选型并论证。
- **专业名词/知识点**：CharacterBody2D / RigidBody2D / StaticBody2D / Area2D / move_and_slide / 物理节点家族 / §0.5 架构地基三问
- **技术栈/代码/美术**：Godot 4 物理节点、`pet.tscn` 第 9 行 `[node name="Pet" type="CharacterBody2D"]`、`pet.gd` 第 1 行 `extends CharacterBody2D`、`docs/12-技术栈与架构.md` 碰撞层规范段
- **应用过程**：
  1. 列出 4 种候选节点（CharacterBody2D / RigidBody2D / StaticBody2D / Area2D）
  2. 对每种跑 §0.5 三问（MVP 够用 / 加系统不重构 / 升级地基不改）
  3. 排除 RigidBody（会被推力挤飞，宠物不应受物理冲撞）和 StaticBody（不能移动）
  4. 排除 Area2D（不阻挡墙，会穿墙）
  5. 选 CharacterBody2D（同 player.gd / monster.gd 一致，统一物理模型）
  6. 论证写入本笔记 + docs/12-技术栈与架构.md 第 91-114 行碰撞层规范

---

## 概念

**Godot 2D 物理节点家族** = Godot 提供的四种"能参与物理碰撞"的节点基类，每种行为不同，选错会导致游戏体验或性能问题。

| 节点类型 | 行为特点 | 典型用途 |
|---------|---------|---------|
| **CharacterBody2D** | 代码控制移动（`move_and_slide`），被墙挡住但不受推力 | 玩家、怪物、宠物、NPC |
| **RigidBody2D** | 物理引擎模拟（受重力、推力、碰撞反弹），代码不能直接控制位置 | 球、箱子、可推动物体 |
| **StaticBody2D** | 完全静止，不被推动也不主动移动 | 墙、地面、障碍物 |
| **Area2D** | 不阻挡任何东西，只检测"谁进入我的区域" | hitbox、触发器、拾取区 |

**生活比喻 1（生动形象）**：四种交通工具选哪个出门：
- **CharacterBody2D = 汽车**：你踩油门控制方向，撞墙会停但不会被弹飞
- **RigidBody2D = 弹力球**：你推一下它按物理规律弹来弹去，不能精确控制
- **StaticBody2D = 路障**：放那不动，谁撞它谁停
- **Area2D = 监控摄像头**：不挡路，只看谁经过

**生活比喻 2（本游戏应用）**：宠物 `pet_001_ham_dog`（火腿狗）该用哪种？
- 用 RigidBody2D → 玩家撞一下火腿狗，狗飞出屏幕（不符合"宠物温和跟随"设计）
- 用 StaticBody2D → 火腿狗卡在原地不能动（不能跟随玩家）
- 用 Area2D → 火腿狗穿墙走（不符合"被墙挡住"的物理规则）
- 用 CharacterBody2D → 火腿狗按代码移动，被墙挡住，玩家撞它不动（完美符合设计）

**反例 vs 正例**：
```
❌ 错误（选 RigidBody2D）：
宠物被玩家撞到 → 受物理推力飞出屏幕 → 玩家追不上 → 卡死
→ 宠物应该"主动跟随"，不应该"被动受力"

✅ 正确（选 CharacterBody2D）：
宠物按代码 move_and_slide 移动 → 玩家撞它不动 → 墙挡住它不穿墙
→ 完全符合"主动跟随玩家"的设计意图
```

---

## 功能

- CharacterBody2D 提供代码控制的物理移动（`move_and_slide()`）
- 自动处理墙体阻挡（碰到墙不会穿过去）
- 不受物理推力影响（不会被其他物体撞飞）
- 支持 layer/mask 碰撞层配置（见 [[30-碰撞层与碰撞遮罩]]）
- 适合所有"自主移动"的实体（玩家、怪物、宠物、NPC）

---

## 运作方式

### §0.5 架构地基三问对 4 种节点的判定

#### 候选 1：CharacterBody2D（最终选择）

| §0.5 三问 | 回答 |
|----------|------|
| ① MVP 够用吗？ | ✅ `move_and_slide` 跟随玩家，被墙挡住，零额外代码 |
| ② 加新系统不重构吗？ | ✅ 未来加捕捉/进化/技能只是脚本扩展，节点类型不变 |
| ③ 升级地基不改吗？ | ✅ 联机版宠物还是 CharacterBody2D，只是位置同步改服务器 |

#### 候选 2：RigidBody2D（排除）

| §0.5 三问 | 回答 |
|----------|------|
| ① MVP 够用吗？ | ❌ 玩家撞宠物会把它推飞，不符合"温和跟随"设计 |
| ② 加新系统不重构吗？ | ❌ 要写"冻结物理"代码抵消推力，每加一种交互都要调参 |
| ③ 升级地基不改吗？ | ❌ 联机版同步 RigidBody 位置很复杂（要同步速度+力），改地基 |

#### 候选 3：StaticBody2D（排除）

| §0.5 三问 | 回答 |
|----------|------|
| ① MVP 够用吗？ | ❌ StaticBody 不能移动，宠物卡在原地 |
| ② 加新系统不重构吗？ | ❌ 必须改成 CharacterBody2D 才能跟随，重构 |
| ③ 升级地基不改吗？ | ❌ 同上 |

#### 候选 4：Area2D（排除）

| §0.5 三问 | 回答 |
|----------|------|
| ① MVP 够用吗？ | ❌ Area2D 不阻挡墙，宠物会穿墙 |
| ② 加新系统不重构吗？ | ❌ 要手动写"墙检测+位置回退"代码，加新地图都要调 |
| ③ 升级地基不改吗？ | ❌ 不阻挡墙是 Area2D 本质，无法升级 |

### 最终选择：CharacterBody2D

理由：
1. **与 player.gd / monster.gd 一致**——三种"自主移动实体"用同一种物理节点，统一物理模型
2. **三问全 PASS**——MVP 够用、加系统不重构、升级地基不改
3. **未来升级路径清晰**——联机版只是位置同步改服务器，节点类型不变

### pet.tscn 实际配置（第 9-12 行）

```ini
[node name="Pet" type="CharacterBody2D"]
collision_layer = 16    ; 宠物专属层（Layer 5，值=16）
collision_mask = 1      ; 只碰墙（Layer 1，值=1）
script = ExtResource("1_pet")
```

`collision_layer = 16` 是宠物专属层（地基规范，见 [[30-碰撞层与碰撞遮罩]]）。
`collision_mask = 1` 表示宠物只被墙挡住，不被玩家/怪物/其他宠物阻挡（互不物理碰撞）。

---

## 原理

CharacterBody2D 是 Godot 为"角色类实体"设计的物理节点：
- **代码控制移动**：调用 `move_and_slide()` 时按 `velocity` 属性移动
- **自动墙体阻挡**：碰到 mask 包含的层（如墙 layer=1）会自动停止，不穿墙
- **不受推力**：其他物理体撞它不会推动它（与 RigidBody2D 的关键区别）
- **滑动处理**：碰到墙时沿墙滑动（如贴着墙走不会卡住）

**move_and_slide 的本质**：
```gdscript
velocity = direction * move_speed  # 代码设速度
move_and_slide()                   # 引擎按 velocity 移动 + 处理碰撞
```
引擎内部：
1. 按 `velocity` 移动一帧距离
2. 检测是否碰到 mask 包含的层
3. 碰到就停止 + 计算滑动方向（贴墙走）
4. 不碰到就正常移动

**为什么不受推力？**
CharacterBody2D 没有 `mass`（质量）属性，物理引擎不计算它受到的力。它的位置完全由代码 `velocity` 决定，其他物体的碰撞不会改变它的 `velocity`。

---

## 优势

| 优势 | 说明 |
|------|------|
| 代码完全控制移动 | `velocity` 直接设，不会被推力干扰 |
| 自动墙阻挡 | mask=1 碰到墙自动停，不穿墙 |
| 沿墙滑动 | 贴墙走不卡住，体验流畅 |
| 与 player/monster 统一 | 三种"自主移动实体"用同一种节点，学习成本低 |
| 联机版升级平滑 | 位置同步改服务器，节点类型不动 |
| §0.5 三问全 PASS | MVP 够用、加系统不重构、升级地基不改 |

---

## 使用场景

### 场景 1：宠物节点（Phase 4.4.2 当前实现）

`pet.tscn` 根节点选 CharacterBody2D，layer=16（宠物专属），mask=1（只碰墙）。pet.gd 用 `move_and_slide` 跟随玩家。

### 场景 2：玩家节点（Phase 4.1 已实现）

`world.tscn` 的 Player 节点是 CharacterBody2D，layer=2（玩家专属），mask=1（只碰墙）。player.gd 用 `Input.get_vector` 读输入 + `move_and_slide` 移动。

### 场景 3：怪物节点（Phase 4.1 已实现）

`world.tscn` 的 RedScorpion/TrainingDummy 节点是 CharacterBody2D，layer=4（怪物专属），mask=1（只碰墙）。monster.gd 的 `_ai_melee_charger` 用 `move_and_slide` 追玩家。

### 场景 4：未来 NPC（Phase 4.5+ 计划）

NPC 也用 CharacterBody2D，layer=4（与怪物同层，因为 NPC 和怪物都是"非玩家自主移动实体"）。

### 与其他系统对接

- **碰撞层**：CharacterBody2D 的 layer/mask 是 [[30-碰撞层与碰撞遮罩]] 落地的载体
- **状态机**：CharacterBody2D 提供移动能力，状态机决定何时移动（见 [[33-状态机骨架]]）
- **DataManager**：pet.gd 启动时 `DataManager.get_pet(pet_id)` 加载数据
- **InputManager**：player.gd 用 `Input.get_vector` 读输入，pet.gd 用 `Input.is_action_just_pressed` 切换温和模式

---

## §0.5 架构地基三问的实践意义

本笔记是 §0.5 架构地基优先原则的**实践案例**。AGENTS.md §0.5 要求"任何技术选型必须先答三问，三问全 PASS 才可选"。本次宠物节点选型完整走了一遍三问流程：

1. **列出候选**：4 种物理节点
2. **对每种跑三问**：每种节点都答 MVP 够用/加系统不重构/升级地基不改
3. **排除不达标**：RigidBody/StaticBody/Area2D 都至少一项 ❌
4. **选择全 PASS 的**：CharacterBody2D 三问全 ✅
5. **论证写入文档**：本笔记 + docs/12-技术栈与架构.md 碰撞层规范段

这是"地基优先于代码"的体现——选 CharacterBody2D 是地基决策（一次定下、长期不变），不是策略决策（可随阶段升级）。未来加捕捉/进化/技能系统，宠物节点类型不变，这就是地基的稳定性。

---

## 关联

- 宠物脚本骨架（基于 CharacterBody2D）：[[33-状态机骨架]]
- 宠物场景实例化：[[34-场景实例化与子场景]]
- 碰撞层规范（layer=16 落地）：[[30-碰撞层与碰撞遮罩]]
- §0.5 架构地基三问：[[23-规则执行滑坡与3道防坡闸门]]
- 三项一致原则（节点类型要 docs/代码/场景一致）：[[08-三项一致原则]]
- MVP 节奏（先选最简单节点跑通，未来按需升级）：[[07-MVP与开发节奏理念]]
