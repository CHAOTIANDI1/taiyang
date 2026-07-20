# 48 —— GDScript 节点生命周期陷阱（add_child 触发 _ready 调用顺序）

---

## 本游戏实例

**遇到的问题**：Phase 4.4.6 步骤 1 伤害飘字系统刚做完时，F5 测试发现所有攻击造成的伤害飘字都显示同一个错误值（"0" 或乱码字符），不管玩家打怪、怪打玩家、宠物打怪，飘字数值都不对。日志里伤害计算明明正确（`[Monster:red_scorpion] 受击！扣 10（来自 Player），剩余 40/50`），但飘字显示的就是不对。

**专业名词/知识点**：
- 节点生命周期（Node Lifecycle）
- `_ready()` 虚函数
- `add_child()` 的副作用
- 调用顺序陷阱（Call Order Trap）

**技术栈/代码/美术**：
- Godot 4.7.1 + GDScript
- `damage_number_manager.gd`（Autoload 单例）
- `damage_number.gd`（Label 脚本）
- `damage_number.tscn`（Label 场景）

**应用过程**：
1. 排查日志发现伤害计算正确（amount=10 传入 DamageNumberManager）
2. 排查 `DamageNumberManager.show_damage_number` 发现调用顺序是 `add_child(instance)` → `instance.set_data(amount, type_enum)`
3. 意识到 `add_child()` 会**立即同步**触发 `_ready()`，此时 `_amount=0`（默认值）
4. 修复前 `_ready()` 设置 `text = str(_amount)` = "0"，`set_data()` 只更新变量没同步 text
5. 修复方案：抽出 `_apply_visual()` 函数，`_ready` 和 `set_data` 都调用它，保证视觉同步

---

## 概念

**节点生命周期**：Godot 节点从创建到销毁经历的一系列固定阶段，每个阶段有对应的虚函数（`_ready`/`_process`/`_physics_process`/`_exit_tree`）。Godot 引擎在特定时机自动调用这些函数，开发者重写它们来插入自己的逻辑。

### 本项目专属例子 1（生动比喻）

想象你开面包店，烤面包机有"放入面团→预热→烤制→出炉"4 个固定阶段。你只能在某个阶段插入动作（比如"预热时检查温度"），不能跳过或重排。

`_ready()` 就是"面包机首次启动时自动执行一次"的阶段——你不知道它什么时候被触发，但 Godot 会在"节点进入场景树后、第一帧渲染前"这个时机自动调用它。

### 本项目专属例子 2（本项目实际应用）

`DamageNumberManager.show_damage_number()` 里：
```gdscript
var instance: Label = DAMAGE_NUMBER_SCENE.instantiate()  # 创建 Label 节点
current_scene.add_child(instance)  # ← 这一行的副作用是立即触发 _ready()！
instance.global_position = world_position + Vector2(0, -20)  # 之后才设置位置
instance.set_data(amount, type_enum)  # 之后才设置真实数值
```

`add_child()` 不是"放进去等会儿处理"，而是**同步立即调用** `_ready()`。所以 `_ready()` 执行时 `_amount` 还是默认值 0，`set_data()` 还没机会执行。

---

## 功能

节点生命周期让 Godot 引擎管理节点状态变化，开发者只需要重写关键虚函数：

| 虚函数 | 触发时机 | 典型用途 |
|--------|---------|---------|
| `_ready()` | 节点进入场景树后第一帧前（只调一次）| 初始化变量、获取子节点引用、设置初始状态 |
| `_process(delta)` | 每渲染帧（约 60 次/秒）| 动画、输入响应、UI 更新 |
| `_physics_process(delta)` | 每物理帧（固定 60 次/秒）| 移动、碰撞、物理相关逻辑 |
| `_enter_tree()` | 节点加入场景树时 | 早于 `_ready`，少用 |
| `_exit_tree()` | 节点离开场景树时 | 清理资源、断开连接 |

---

## 运作方式

### `_ready()` 的触发链

```
instantiate()  → 创建节点对象（内存中，未进入场景树）
       ↓
add_child()    → 把节点加入父节点的子节点列表
       ↓
（同步立即）   → 触发 _ready()  ← 关键陷阱在这里
       ↓
（下一帧）     → 开始 _process / _physics_process 循环
```

### 陷阱复现（本项目 Bug 复盘）

```gdscript
# DamageNumberManager.show_damage_number 里：
var instance: Label = DAMAGE_NUMBER_SCENE.instantiate()
current_scene.add_child(instance)  # 立即触发 _ready，此时 _amount=0

# damage_number.gd 修复前的 _ready：
func _ready() -> void:
    text = str(_amount)  # _amount=0，text="0"，飘字显示 "0"
    _play_animation()    # 动画启动，0.8 秒后 queue_free

# damage_number.gd 修复前的 set_data：
func set_data(amount: int, type: int = Type.DAMAGE) -> void:
    _amount = amount  # 只更新变量，没同步 text！
    _type = type      # 只更新变量，没同步 modulate！
```

**结果**：`_ready()` 先把 text 设成 "0"，`set_data()` 后更新了 `_amount` 变量但没刷新 text，所以飘字永远显示 "0"。

### 修复方案（本项目实际采用）

```gdscript
func _ready() -> void:
    horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _apply_visual()  # _ready 时调用，_amount=0 → text="0"
    _play_animation()


func set_data(amount: int, type: int = Type.DAMAGE) -> void:
    _amount = amount
    _type = type
    _apply_visual()  # set_data 时再调用一次，覆盖 _ready 的设置 → text="10"


func _apply_visual() -> void:
    match _type:
        Type.DAMAGE:
            text = str(_amount)
            modulate = Color(1, 0.3, 0.3)
        Type.MISS:
            text = "miss"
            modulate = Color(0.7, 0.7, 0.7)
        Type.HEAL:
            text = "+" + str(_amount)
            modulate = Color(0.3, 1, 0.3)
```

**关键思想**：把"应用视觉"抽成独立函数，**任何时候数据变化都调用它**。这样不管 `_ready` 和 `set_data` 谁先谁后，最终视觉一定跟数据同步。

---

## 原理

### 为什么 `add_child()` 同步触发 `_ready()`？

Godot 的设计哲学：节点进入场景树就意味着"它要开始参与游戏逻辑"。引擎立即调用 `_ready()` 让节点完成初始化，这样后续帧的 `_process/_physics_process` 才能正常工作。

如果 `add_child()` 是异步的（比如等下一帧才调 `_ready`），开发者就没法在 `add_child` 之后立即访问节点的初始化状态，会引入更多竞态条件。

### 反例 vs 正例对照

**反例（修复前）**：
```gdscript
func _ready() -> void:
    text = str(_amount)  # ← 立即设 text，但 _amount 还是默认值
    _play_animation()


func set_data(amount: int, type: int = Type.DAMAGE) -> void:
    _amount = amount  # ← 只更变量，不刷新 text
    _type = type
```
结果：`_ready` 设置 text="0"，`set_data` 之后再改 `_amount`，text 永远是 "0"。

**正例（修复后）**：
```gdscript
func _ready() -> void:
    _apply_visual()  # 调用统一函数


func set_data(amount: int, type: int = Type.DAMAGE) -> void:
    _amount = amount
    _type = type
    _apply_visual()  # 调用同一个统一函数，保证视觉刷新
```
结果：`_ready` 设 text="0"，`set_data` 立刻覆盖成 text="10"，视觉跟数据同步。

---

## 优势

| 优势 | 说明 |
|------|------|
| 防御调用顺序陷阱 | 不管 `_ready` 和 `set_data` 谁先谁后，视觉都跟数据同步 |
| 单一职责 | `_apply_visual()` 只管"把数据应用到视觉"，可被任何地方调用 |
| 易于扩展 | 加新类型（如暴击金色）只需在 `_apply_visual` 加一个 match 分支 |
| 减少重复 | `_ready` 和 `set_data` 不再各自写一遍 `text = ...` |

---

## 使用场景

### 场景 1：本项目的伤害飘字（已应用）

`DamageNumberManager.show_damage_number` → `add_child` → `_ready` → 后续 `set_data` → 视觉刷新。`_apply_visual` 双调用保证同步。

### 场景 2：动态创建的 UI 节点

任何 `instantiate() + add_child() + 设置数据` 三段式调用都要小心 `_ready` 提前触发。修复套路一致：抽 `_apply_*` 函数，`_ready` 和设置函数都调用。

### 场景 3：场景树切换

`get_tree().change_scene_to_file()` 会触发新场景根节点 `_ready`。如果新场景依赖外部数据，必须在 `_ready` 里读，不能依赖"外部先设置再切场景"。

### 对接 AGENTS.md

- **§1.1 逻辑显示分离**：本笔记的 `_apply_visual` 函数正是"数据→显示"的应用层，逻辑（_amount/_type）跟显示（text/modulate）通过 `_apply_visual` 单向绑定。
- **§1.4 第 9 项报错三步流程**：本笔记是本次飘字 Bug 修复的强制补库产物。
- **闸门 B 第 9 问小白学习视角**：节点生命周期是零基础用户第一次遇到的"引擎自动调用"概念，必须有笔记。

---

## 关联

- 飘字系统整体：[[42-伤害飘字与Tween动画]]
- Autoload 单例：[[06-单例模式与Autoload]]
- 类型检查相关报错：[[46-变量声明类型与赋值类型匹配]]
- DamageArea 工具类：[[44-DamageArea抽象类落地]]
- 闸门 B 第 9 问：[[23-规则执行滑坡与3道防坡闸门]]
