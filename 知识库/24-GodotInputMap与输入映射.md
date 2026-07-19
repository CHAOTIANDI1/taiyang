# 24 - Godot InputMap 与输入映射

## 本游戏实例（v2.7 准则，v2.8 回填）

- **遇到的问题**：Phase 4.4.2 宠物系统需要按 Z 键切换"温和模式"（宠物只跟随不战斗，无敌）。如果不走 InputMap，代码里要写死 `if event.keycode == 90:` 这种硬编码，玩家无法改键位。需要用 InputMap 注册一个动作名 `pet_toggle_mode`，代码里只写动作名，不写物理键编号。
- **专业名词/知识点**：InputMap、动作名（Action Name）、物理键（Physical Key）、keycode（键码）、`project.godot` 的 `[input]` 段
- **技术栈/代码/美术**：`project.godot` 第 82-86 行 `[input]` 段的 `pet_toggle_mode` 配置（keycode=90，即 Z 键）、`scripts/pet/pet.gd` 第 58 行 `Input.is_action_just_pressed("pet_toggle_mode")`
- **应用过程**：
  1. 在 `project.godot` 的 `[input]` 段加 `pet_toggle_mode` 配置，绑定 Z 键（keycode=90）
  2. 在 `pet.gd` 的 `_physics_process` 里写 `if Input.is_action_just_pressed("pet_toggle_mode"): toggle_gentle_mode()`
  3. 玩家按 Z 键 → Godot 查 InputMap 表 → 触发 `pet_toggle_mode` 动作 → pet.gd 收到信号 → 切换温和模式
  4. 未来玩家想改键位（如改成 X 键），只需在 Godot 项目设置里改 `pet_toggle_mode` 的物理键，代码不动

---

## 概念

**InputMap** = Godot 里"按键名字 → 具体物理按键"的映射表。比如你定"move_up=W"——之后代码里写 `Input.is_action_pressed("move_up")`，Godot 自动查表，按 W 就触发。

生活类比：遥控器上的"开机键"按下其实触发的是"打开电视"信号——你不用记信号编号，只要按"开机键"。

**本游戏专属例子 1（生动形象）**：把 InputMap 想象成《太阳之下》的"键位翻译官"。你跟翻译官说"我要攻击"（动作名 `attack`），翻译官查表发现玩家按了 J 键，于是帮你把"攻击"信号发给 player.gd。player.gd 只知道"攻击"信号来了，不关心是 J 键还是手柄 A 键。

**本游戏专属例子 2（本游戏应用）**：Phase 4.4.2 新增的 `pet_toggle_mode` 动作。在 `project.godot` 注册：
```ini
pet_toggle_mode={
"deadzone": 0.5,
"events": [Object(InputEventKey,...,"keycode":90,...)]
}
```
然后在 `pet.gd` 调用：
```gdscript
if Input.is_action_just_pressed("pet_toggle_mode"):
    toggle_gentle_mode()
```
玩家按 Z（keycode=90）→ Godot 查表触发动作 → pet.gd 收到信号切换温和模式。改键位时只改 `project.godot`，代码完全不动。

## 功能

- 让玩家改键位（在项目设置里）
- 代码不写具体键编号（87 是 W），写动作名（"move_up"）
- 一份键位配置适用于任何脚本

## 运作方式

### 在 project.godot 里注册（我们刚做的）

```ini
[input]

move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,...,"keycode":87,...)]
}
```

含义：
- 键名 `move_up`
- `keycode: 87` = W 键（ASCII 码）
- `deadzone: 0.5` = 摇杆灵敏度容差，键盘不用关心

### 代码里调用

```gdscript
# 一行就能读到 WASD 的方向向量
var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

`get_vector(负向,正向,负向,正向)` 返回一个 (-1, -1) 到 (1, 1) 之间的向量。

### 4 个常用 Input 函数

| 函数 | 触发 | 典型用途 |
|------|------|---------|
| `Input.is_action_pressed("X")` | 当前正按着 | 持续移动 |
| `Input.is_action_just_pressed("X")` | 这帧第一次按下 | 攻击触发 |
| `Input.is_action_just_released("X")` | 这帧第一次松开 | 蓄力释放 |
| `Input.get_vector("l","r","u","d")` | 任一按下混合 | 多键移动 |

## 原理

Godot 启动时读 `project.godot` 的 `[input]` 段，建一张"动作名→物理键"表存到内存。每次按物理键 Godot 对照表判断是否触发"动作"，触发就更新内部状态。

## 优势

| 优势 | 说明 |
|------|------|
| 代码不绑定具体键 | 改键盘不重新编译 |
| 玩家自定义 | 上线后可以加设置面板 |
| 多键同一动作 | 一个动作可绑 W 也绑方向键 |
| 屏蔽物理键编号 | 程序里只写动作名 |

## 使用场景

### 场景 1: 移动

按 WASD 上下左右移动，用 `get_vector` 一次取 4 个键合成方向向量。

### 场景 2: 攻击一次性触发

按 J 只触发一次攻击，按住不连发——用 `is_action_just_pressed`。

### 场景 3: 防御持续

按住 Shift 一直防御——用 `is_action_pressed`。

## 在我们项目用到的键映射

| 动作名 | 键 | 用途 | 加入版本 |
|--------|----|------|---------|
| `move_left` | A | 向左移动 | Phase 4.1 |
| `move_right` | D | 向右移动 | Phase 4.1 |
| `move_up` | W | 向上移动 | Phase 4.1 |
| `move_down` | S | 向下移动 | Phase 4.1 |
| `attack` | J | 普通攻击（武器模组） | Phase 4.1 |
| `skill_1` | K | 技能 1（基础，短 CD） | Phase 4.1 |
| `skill_2` | L | 技能 2（核心，长 CD） | Phase 4.1 |
| `skill_3` | U | 技能 3（爆发，长 CD） | Phase 4.1 |
| `interact` | E | 与 NPC 对话/物品交互 | Phase 4.1 |
| `pet_toggle_mode` | Z | 切换宠物温和模式（默认开启，无敌只跟随） | Phase 4.4.2 |

## 例外条款说明

按 AGENTS v2.5 §1.4 末尾"例外条款"：**输入映射属于 Godot 引擎配置**，由 `project.godot` 的 `[input]` 段管理，**不写入 JSON 文件**。这是经过闸门 C 5 问审计后通过的例外。

---

## 关联

- 代码里怎么用输入映射：参见 player.gd
- 移动逻辑逻辑是哪个 phase：[[07-MVP与开发节奏理念]]
- 数据表驱动什么时候不适用：[[03-数据驱动架构与JSON工作原理]]