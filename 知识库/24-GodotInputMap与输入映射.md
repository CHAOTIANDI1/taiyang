# 24 - Godot InputMap 与输入映射

## 概念

**InputMap** = Godot 里"按键名字 → 具体物理按键"的映射表。比如你定"move_up=W"——之后代码里写 `Input.is_action_pressed("move_up")`，Godot 自动查表，按 W 就触发。

生活类比：遥控器上的"开机键"按下其实触发的是"打开电视"信号——你不用记信号编号，只要按"开机键"。

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

| 动作名 | 键 | 用途 |
|--------|----|------|
| `move_left` | A | 向左移动 |
| `move_right` | D | 向右移动 |
| `move_up` | W | 向上移动 |
| `move_down` | S | 向下移动 |
| `attack` | J | 普通攻击（武器模组） |
| `skill_1` | K | 技能 1（基础，短 CD） |
| `skill_2` | L | 技能 2（核心，长 CD） |
| `skill_3` | U | 技能 3（爆发，长 CD） |
| `interact` | E | 与 NPC 对话/物品交互 |

## 例外条款说明

按 AGENTS v2.5 §1.4 末尾"例外条款"：**输入映射属于 Godot 引擎配置**，由 `project.godot` 的 `[input]` 段管理，**不写入 JSON 文件**。这是经过闸门 C 5 问审计后通过的例外。

---

## 关联

- 代码里怎么用输入映射：参见 player.gd
- 移动逻辑逻辑是哪个 phase：[[07-MVP与开发节奏理念]]
- 数据表驱动什么时候不适用：[[03-数据驱动架构与JSON工作原理]]