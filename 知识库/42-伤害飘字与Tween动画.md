# 42 - 伤害飘字与 Tween 动画

## 本游戏实例（v2.7 准则）

- **遇到的问题**：
  - **Phase 4.4.6 步骤 1**：玩家攻击红尾蝎、红尾蝎攻击宠物时，伤害数值只能在控制台 print 看到，游戏画面里没有任何反馈
  - 玩家无法判断"我打了多少血"、"宠物挨了多少打"、"是不是 miss 了"
  - 需要一个在战斗中弹出伤害数字的 UI 系统，所有受击事件都触发
- **专业名词/知识点**：伤害飘字（Damage Number）、Tween 补间动画、Autoload 单例、Label 节点、`set_parallel(true)` 并行动画、`queue_free()` 自动销毁
- **技术栈/代码/美术**：Godot 4 Label 节点、Tween 动画、`project.godot` 的 `[autoload]` 段、`scripts/ui/damage_number.gd`、`scripts/ui/damage_number_manager.gd`、`scenes/ui/damage_number.tscn`
- **应用过程**：
  1. 设计目标：所有受击事件（玩家/宠物/怪物）都弹出伤害数值
  2. 创建 `damage_number.tscn`（Label 节点）+ `damage_number.gd`（脚本：根据类型染色 + Tween 浮动淡出）
  3. 创建 `damage_number_manager.gd`（Autoload 单例，全局入口 `show_damage_number(world_pos, amount, type)`）
  4. 在 `project.godot` 注册 `DamageNumberManager` Autoload
  5. 改造 6 个触发点：玩家攻击命中 / 玩家受伤 / 宠物攻击命中 / 宠物受伤 / 怪物攻击命中 / 怪物受伤
  6. F5 验证：宠物打红尾蝎 → 红尾蝎头上飘红色"10" → 红尾蝎打宠物 → 宠物头上飘红色"8"

---

## 概念

**伤害飘字**是战斗中弹出的伤害数字，告诉玩家"打多少血 / 挨多少打 / 是不是 miss"。**Tween 补间动画**是 Godot 的动画系统，让数字"向上飘 + 淡出"看起来自然。

**生活比喻 1（生动形象）**：漫画里的拟声词——主角一拳打过去，旁边"啪！"的大字弹出来，读者立刻知道"打中了 + 多重"。伤害飘字就是游戏版的拟声词，让玩家有"打中了"的反馈感。

**生活比喻 2（本游戏应用）**：你按 J 攻击红尾蝎，红尾蝎头上立刻飘出红色的"10"——你瞬间知道"我打了 10 血"。如果红尾蝎跑开了，会飘出灰色的"miss"——你知道"没打中"。没有这个系统的话，你只能盯着红尾蝎的血条看，反馈不直接。

**反例 vs 正例**：
```
❌ 错误（直接 print 到控制台）：
print("玩家打了 10 伤害")  # 只有开发者能看到，玩家看不见

✅ 正确（伤害飘字 + Tween 动画）：
DamageNumberManager.show_damage_number(pos, 10, "damage")
# 在 world_pos 弹出红色"10"，向上飘 40 像素 + 0.8 秒淡出
```

---

## 功能

- 战斗中所有受击事件弹出伤害数值（玩家/宠物/怪物共用）
- 3 种飘字类型：`damage`（红色数值）/ `miss`（灰色"miss"）/ `heal`（绿色"+数值"）
- 浮动 + 淡出动画（向上 40 像素 + 0.8 秒淡出）
- 全局单例入口，任何脚本都能调用

---

## 运作方式

### 文件结构

```
scripts/ui/
├── damage_number.gd           # Label 脚本（染色 + 动画 + 自动销毁）
└── damage_number_manager.gd   # Autoload 单例（全局入口）

scenes/ui/
└── damage_number.tscn         # Label 场景（被实例化的"模板"）

project.godot [autoload] 段：
DamageNumberManager="*res://scripts/ui/damage_number_manager.gd"
```

### DamageNumber 脚本核心（damage_number.gd）

```gdscript
extends Label
const FLOAT_DISTANCE: float = 40.0   # 向上飘 40 像素
const FADE_DURATION: float = 0.8     # 0.8 秒淡出
enum Type { DAMAGE, MISS, HEAL }

func _ready() -> void:
    match _type:
        Type.DAMAGE:
            text = str(_amount)
            modulate = Color(1, 0.3, 0.3)  # 红色
        Type.MISS:
            text = "miss"
            modulate = Color(0.7, 0.7, 0.7)  # 灰色
    _play_animation()

func _play_animation() -> void:
    var tween: Tween = create_tween()
    tween.set_parallel(true)  # 并行：同时浮动 + 淡出
    tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, FADE_DURATION)
    tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
    tween.chain().tween_callback(queue_free)  # 完成后销毁自己
```

### DamageNumberManager 单例（damage_number_manager.gd）

```gdscript
extends Node
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")

func show_damage_number(world_position: Vector2, amount: int, type: String = "damage") -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    var instance: Label = DAMAGE_NUMBER_SCENE.instantiate()
    current_scene.add_child(instance)
    instance.global_position = world_position + Vector2(0, -20)  # 向上偏移 20 像素
    instance.set_data(amount, _parse_type(type))
```

### 6 个触发点（调用方）

| 单位 | 触发位置 | 说明 |
|------|---------|------|
| 玩家攻击怪物命中 | `player.gd._check_hit()` → `_spawn_damage_number()` | 玩家看到自己打多少 |
| 玩家受伤 | `player.gd.take_damage()` → `_spawn_damage_number()` | 玩家看到自己挨多少 |
| 宠物攻击怪物命中 | `pet.gd._check_pet_hit()` → `DamageNumberManager.show_damage_number()` | 玩家看到宠物打多少 |
| 宠物受伤 | `pet.gd.take_damage()` → `DamageNumberManager.show_damage_number()` | 玩家看到宠物挨多少 |
| 怪物攻击命中 | `monster.gd._do_attack()` → `DamageNumberManager.show_damage_number()` | 玩家看到怪物打多少 |
| 怪物受伤 | `monster.gd.take_damage()` → `DamageNumberManager.show_damage_number()` | 玩家看到怪物挨多少 |
| 怪物攻击落空（步骤 2）| `monster.gd._do_attack()` telegraph_then_check miss 分支 | 玩家看到"miss"灰色字 |

### 代码执行流程

```
玩家按 J → player._start_attack()
→ 攻击动画期间 _check_hit() 检测命中
→ 命中 monster → monster.take_damage(10, player)
→ player._spawn_damage_number(10, monster.global_position)
→ DamageNumberManager.show_damage_number(pos, 10, "damage")
→ 实例化 damage_number.tscn → 加到 current_scene
→ 设置 global_position = pos + Vector2(0, -20)
→ Label._ready() 触发：染红色 + 显示"10"
→ Tween 启动：position.y 减 40（向上飘）+ modulate.a 减到 0（淡出）
→ 0.8 秒后 chain().tween_callback(queue_free) 销毁自己
```

---

## 原理

### 为什么用 Autoload 单例而不是每个场景自己创建？

- **统一入口**：所有脚本都调 `DamageNumberManager.show_damage_number()`，不用每个场景重复创建
- **生命周期独立**：Autoload 在游戏启动时就存在，场景切换不销毁
- **避免重复代码**：6 个触发点共用一个入口，符合 §1.1 逻辑显示分离（飘字是显示层，不混入战斗逻辑）

### Tween 的 set_parallel(true) 是什么？

Tween 默认是串行的（一个动画做完才做下一个），`set_parallel(true)` 让多个动画同时进行：
- 浮动（position.y 减 40）和淡出（modulate.a 减到 0）同时进行
- 0.8 秒内同时完成"向上飘 + 慢慢消失"
- `chain()` 切回串行，下一个 `tween_callback(queue_free)` 等前面都做完才执行

### 为什么用 queue_free() 而不是 hide()？

- `queue_free()` 是销毁节点（释放内存），下次再创建新的
- `hide()` 是隐藏节点（内存还在），需要管理对象池
- MVP 阶段战斗频率不高，直接 queue_free 简单，未来频率高了再优化为对象池

### 为什么 position 用 global_position 而不是 position？

- `global_position` 是世界坐标，跟随场景滚动
- `position` 是相对父节点的坐标
- 飘字加到 `current_scene`（场景根节点），用 `global_position` 确保飘字在世界正确位置

---

## 优势

| 优势 | 说明 |
|------|------|
| 统一入口 | DamageNumberManager 单例，6 个触发点共用 |
| 类型可扩展 | damage/miss/heal 三种已实现，未来加暴击（黄色大字）只改 enum |
| 动画自然 | Tween 并行浮动 + 淡出，看起来像真实飘字 |
| 自动销毁 | queue_free 不会内存泄漏 |
| 数据驱动 | 飘字数值来自 take_damage(amount) 的 amount，不需要新 JSON |

---

## 使用场景

### 场景 1：受击飘字（最常用）

```gdscript
# 任何 take_damage 实现里加一行：
DamageNumberManager.show_damage_number(global_position, amount, "damage")
```

### 场景 2：攻击落空 miss

```gdscript
# monster.gd telegraph_then_check 模式下，目标跑开了：
DamageNumberManager.show_damage_number(_target.global_position, 0, "miss")
# 弹出灰色"miss"
```

### 场景 3：治疗（未来扩展）

```gdscript
# 食物回血：
DamageNumberManager.show_damage_number(global_position, heal_amount, "heal")
# 弹出绿色"+15"
```

### 场景 4：暴击（未来扩展）

```gdscript
# 加 enum Type.CRIT，黄色大字 + 字号放大
# damage_number.gd _ready() 加分支：
# Type.CRIT:
#     text = str(_amount)
#     modulate = Color(1, 0.85, 0)  # 金黄色
#     scale = Vector2(1.5, 1.5)     # 放大 1.5 倍
```

### 与其他系统对接

- **战斗系统**：所有 take_damage 调用方都加飘字触发
- **Tween 系统**：复用 Godot 原生 Tween，不引入第三方库
- **Autoload 系统**：DamageNumberManager 与 GameTime/SaveManager 同级
- **未来 V1 暴击/多段伤害**：只需扩展 enum Type + 加 _ready 分支，不改架构

---

## 关联

- Tween 补间动画原理（parallel/chain/缓动）：[[28-Tween补间动画详解]]
- Autoload 单例模式原理：[[06-单例模式与Autoload]]
- modulate 颜色调节（染红/灰/绿）：[[25-26-Vector2与Modulate闪白]]
- 攻击落空 miss 飘字触发：[[43-攻击判定模式]]
- DamageArea 抽象类（命中后调 take_damage 触发飘字）：[[44-DamageArea抽象类落地]]
- 逻辑显示分离（飘字是显示层，不混战斗逻辑）：[[04-逻辑与显示分离原理]]
- UI 设计真值（飘字类型表/触发点表）：见 docs/10-UI与交互.md "伤害飘字段"
