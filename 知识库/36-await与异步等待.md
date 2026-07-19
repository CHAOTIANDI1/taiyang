# 36 - await 与异步等待

## 本游戏实例（v2.7 准则，v2.8 主动识别）

- **遇到的问题**：Phase 4.4.3 宠物蛋孵化器 `scripts/pet/pet_egg_hatcher.gd` 需要做 3 秒动画。如果用同步代码（一行行顺序执行），动画还没播完就会执行"实例化宠物"——宠物会在蛋图标还在屏幕上时就出现，逻辑混乱。需要一种"等动画播完再继续"的机制。
- **专业名词/知识点**：await 关键字、异步等待（Asynchronous Wait）、协程（Coroutine）、`Tween.finished` 信号、`await expression` 语法
- **技术栈/代码/美术**：`scripts/pet/pet_egg_hatcher.gd` 第 60 行 `await _play_hatch_animation(pet_id)`、第 73 行 `await t1.finished`
- **应用过程**：
  1. 把 3 秒动画拆成 3 个阶段（淡入 + 脉动 + 淡出），每个阶段一个 Tween
  2. 用 `await t1.finished` 等阶段 1 的 Tween 播完，才进入阶段 2
  3. 用 `await t2.finished` 等阶段 2 播完，才进入阶段 3
  4. 用 `await t3.finished` 等阶段 3 播完，才执行"实例化宠物"
  5. 整个 `_play_hatch_animation` 函数用 `await` 让调用方 `hatch()` 也能等动画结束才解锁 `_is_hatching`

---

## 概念

**await** = GDScript 的关键字，用来"暂停当前函数的执行，等某个异步操作完成后再继续"。

生活比喻：你在饭店点菜，菜单交给厨房后你不会站在厨房门口死等（同步阻塞），而是回座位刷手机（让出执行权），厨房叫号你再去取餐（异步等待完成）。await 就是"先让出执行权，等叫号再回来继续"。

**本游戏专属例子 1（生动形象）**：把 await 想象成《太阳之下》的"过场动画等待"。宠物蛋孵化时，主角不会在蛋还在屏幕上闪时就去摸宠物（同步执行会导致混乱），而是站在原地等孵化动画播完（await），动画结束才走过去摸新出现的宠物。这就是 `await _play_hatch_animation(pet_id)` 的作用——让 `hatch()` 函数暂停，等动画播完才解锁 `_is_hatching = false`。

**本游戏专属例子 2（本游戏应用）**：Phase 4.4.3 `pet_egg_hatcher.gd` 的 3 秒动画分段：
```gdscript
# 阶段 1：淡入 + 放大（1 秒）
var t1: Tween = create_tween()
t1.tween_property(_egg_icon, "modulate:a", 1.0, 1.0)
await t1.finished  # ← 等阶段 1 播完才继续

# 阶段 2：脉动 1 秒
var t2: Tween = create_tween()
t2.tween_property(_egg_icon, "scale", Vector2(1.10, 1.10), 0.25)
# ... 4 次缩放
await t2.finished  # ← 等阶段 2 播完才继续

# 阶段 3：放大 + 淡出（1 秒）
var t3: Tween = create_tween()
t3.tween_property(_egg_icon, "scale", Vector2(1.5, 1.5), 1.0)
await t3.finished  # ← 等阶段 3 播完才继续

# 实例化宠物
_spawn_pet(pet_id)
```
没有 await 的话，3 个 Tween 会同时启动，3 秒动画变成 1 秒（同步执行），蛋图标还没淡出宠物就出现了。

## 功能

- 暂停当前函数执行，等异步操作完成
- 不阻塞游戏主循环（其他节点继续运行）
- 让代码读起来像同步代码（顺序执行），实际是异步的

## 运作方式

### 基本语法

```gdscript
await <expression>
# expression 必须返回 Signal 或 SignalAwaiter
```

### 3 种常见用法

**用法 1：等信号触发**
```gdscript
await tween.finished  # 等 Tween 播完
await get_tree().create_timer(2.0).timeout  # 等 2 秒
await $AnimationPlayer.animation_finished  # 等动画播完
```

**用法 2：等异步函数返回**
```gdscript
await _play_hatch_animation(pet_id)  # 等另一个含 await 的函数返回
```

**用法 3：等一帧**
```gdscript
await get_tree().process_frame  # 等下一帧
await RenderingServer.frame_post_draw  # 等渲染完
```

### 4.4.3 实际代码流程

```gdscript
func hatch(egg_id: String) -> void:
    _is_hatching = true
    await _play_hatch_animation(pet_id)  # ← 这里暂停，等动画结束
    _is_hatching = false  # ← 动画结束后才执行

func _play_hatch_animation(pet_id: String) -> void:
    var t1: Tween = create_tween()
    t1.tween_property(...)
    await t1.finished  # ← 这里暂停，等 t1 播完
    # t1 播完后继续执行下面的代码
    var t2: Tween = create_tween()
    # ...
```

## 原理

GDScript 的 await 基于**协程**机制：
1. 编译器看到 `await` 关键字，把当前函数编译成"状态机"
2. 函数执行到 `await` 时，**返回一个 SignalAwaiter 对象给调用方**，函数本身"挂起"（保留局部变量）
3. 游戏主循环继续运行（60fps），其他节点的 `_physics_process` / `_process` 正常执行
4. 等 await 的信号触发（如 `tween.finished`），Godot 唤醒挂起的函数，从 `await` 下一行继续执行
5. 函数完全执行完，返回结果给调用方

**关键点**：
- await 不阻塞游戏主循环（不像 Python 的 `time.sleep(3)` 那样卡死整个游戏）
- await 只"暂停当前函数"，其他函数照常运行
- 含 await 的函数返回类型变成 `SignalAwaiter`，调用方也需要用 await 等它

## 优势

| 优势 | 说明 |
|------|------|
| 代码读起来像同步 | 不需要写回调函数，逻辑顺序清晰 |
| 不卡游戏 | 等待时游戏主循环继续运行 |
| 适合动画/网络/IO | 等动画、等网络请求、等文件读取都用同一个机制 |
| 链式调用 | await 函数可以再 await 另一个 await 函数，层层嵌套 |

## 使用场景

### 场景 1：动画分段播放（4.4.3 用法）
3 秒动画分 3 段，每段一个 Tween，用 await 串起来。

### 场景 2：等敌人死亡动画再掉物品
```gdscript
await $AnimationPlayer.animation_finished
_drop_loot()
```

### 场景 3：等网络请求返回（联机版）
```gdscript
var response = await _http_client.request(url)
_parse_response(response)
```

### 场景 4：等玩家确认对话再继续剧情
```gdscript
await DialogueBox.choice_selected
_advance_story()
```

## 常见错误

### 错误 1：调用方忘记 await
```gdscript
# ❌ 错误：调用方没 await
func _ready():
    hatch("pet_egg_01")  # 不会等动画结束
    print("宠物出现了吗？")  # 立即执行，动画还没播完

# ✅ 正确：调用方也 await
func _ready():
    await hatch("pet_egg_01")
    print("宠物出现了！")
```

### 错误 2：在 _ready 里 await 重型操作导致初始化推迟
```gdscript
# ⚠️ 注意：_ready 里的 await 不阻塞其他节点 _ready
func _ready():
    await get_tree().create_timer(2.0).timeout
    # 这 2 秒内，其他节点的 _ready 已经跑完
    # 但本节点的后续初始化被推迟
```

---

## 关联

- Tween 补间动画：[[28-Tween补间动画详解]]
- Signal 信号机制（await 的底层）：[[29-Signal信号机制]]
- 场景实例化（await 后调用）：[[34-场景实例化与子场景]]
- CanvasLayer UI 层（4.4.3 也用到）：[[37-CanvasLayer与UI层]]
