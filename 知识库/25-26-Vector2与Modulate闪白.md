# 25-26 - Vector2 向量与 Modulate 颜色调节

## 本游戏实例（v2.7 回填）

### 遇到的问题
- **4.1 玩家移动**：需要 WASD 四键合一方向，且斜走不能比直走快 → 用 Vector2 + get_vector 解决
- **4.4.4 宠物跟随 AI**：需要判断"宠物离玩家多远"决定 idle↔follow 状态切换 → 用 Vector2.distance_to() 解决
- **4.1 受击闪白**：怪物/玩家被打时需要"白光一闪"反馈 → 用 modulate = Color(8,8,8) 解决

### 专业名词/知识点
- Vector2（2D 向量）
- get_vector（四键合一读方向）
- distance_to（两点距离）
- length（向量长度）
- normalized（归一化）
- modulate（颜色调节器）
- Color（颜色对象）

### 技术栈/代码
- `scripts/player/player.gd`：`Input.get_vector("move_left", "move_right", "move_up", "move_down")` + `velocity = direction * speed`
- `scripts/pet/pet.gd`：`global_position.distance_to(_owner_player.global_position)` 判断 idle↔follow 切换
- `scripts/pet/pet.gd`：`to_player.normalized()` 把差向量归一化为方向单位向量
- `scripts/player/player.gd`：`modulate = Color(8.0, 8.0, 8.0, 1.0)` 受击闪白

### 应用过程
1. 玩家移动：get_vector 一次读 4 键 → 返回归一化方向向量 → 乘速度 → move_and_slide 移动
2. 宠物跟随：每帧用 distance_to 算宠物到玩家的距离 → 距离>100 切 follow / 距离<60 切 idle（中间滞区不切换避免抖动）
3. 宠物移动方向：`(_owner_player.global_position - global_position).normalized()` 得到"朝玩家的单位方向向量"→ 乘 move_speed → move_and_slide
4. 受击闪白：被打时 modulate=Color(8,8,8) 发白 → 0.15 秒 Tween 回到 Color(1,1,1)

---

# 25 - Vector2 向量与 get_vector 移动原理

## 概念

**Vector2** = 2D 向量，包含 (x, y) 两个 float 值。在 2D 游戏里表示"方向"或"位置"。

生活类比：GPS 坐标点是一个 Vector2（经度,纬度），罗盘指向也是一个 Vector2（东西，南北）。

**本项目专属例子 1（概念理解）**：玩家的位置 `position = Vector2(400, 400)` 是一个 Vector2，表示"站在地图坐标 x=400, y=400 这个点"；玩家按 D 键时 `direction = Vector2(1, 0)` 也是一个 Vector2，表示"朝右走一格"。

**本项目专属例子 2（实际应用）**：4.4.4 宠物跟随 AI 中，`global_position.distance_to(_owner_player.global_position)` 就是把"宠物位置"和"玩家位置"两个 Vector2 相减得到差向量，再用 length() 算长度——生活比喻是"宠物和玩家之间拉一根橡皮筋，橡皮筋的长度就是距离"。

## 功能

告诉我们"朝哪个方向走"和"站在哪"。

## 运作方式

```gdscript
var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

`get_vector` 一次读 4 个键：

| 按键情况 | 返回值 |
|---------|--------|
| 只按 D | (1, 0) |
| 只按 A | (-1, 0) |
| 只按 W | (0, -1)  ← 注意 Y 轴向下为正，所以"上"是 -1 |
| 只按 S | (0, 1) |
| W + D 同时按 | (0.707, -0.707)  ← 对角线，被自动归一化避免斜走快 1.41 倍 |
| 都不按 | (0, 0) |

### 怎么变成移动

```gdscript
velocity = direction * speed     # 1*250 = 250 像素/秒
move_and_slide()                  # Godot 用 velocity 移动 + 碰撞滑动
```

`velocity` 是 CharacterBody2D 内置变量，给它一个向量 = "我要这帧以这个向量移动"。`move_and_slide` 执行这个移动 + 检测碰撞。

### 距离计算（distance_to / length / normalized）

Vector2 不只能表示方向和位置，还能算"两个点之间的距离"和"朝某点的方向"。

```gdscript
# 4.4.4 宠物跟随 AI：算宠物到玩家的距离
var distance: float = global_position.distance_to(_owner_player.global_position)
# distance > 100 → idle 切 follow
# distance < 60  → follow 切 idle（双阈值滞后避免抖动）

# 4.4.4 宠物移动方向：朝玩家走
var to_player: Vector2 = _owner_player.global_position - global_position  # 差向量
var direction: Vector2 = to_player.normalized()                          # 归一化（只留方向，长度变1）
velocity = direction * move_speed                                         # 方向 × 速度 = 速度向量
move_and_slide()
```

**三个核心方法**：

| 方法 | 作用 | 生活比喻 |
|------|------|---------|
| `a.distance_to(b)` | 算 a 到 b 的距离（float） | 两点之间拉一根橡皮筋，橡皮筋长度 |
| `vector.length()` | 算向量长度（float） | 箭头有多长 |
| `vector.normalized()` | 把向量归一化（长度变 1，方向不变） | 箭头缩短为 1 厘米，但指向不变 |

**distance_to 和 length 的关系**：

```gdscript
# 这两行等价：
var d1: float = a.distance_to(b)
var d2: float = (b - a).length()  # 差向量的长度
```

**length() 的数学原理**（勾股定理）：

- `Vector2(3, 4).length()` = √(3² + 4²) = √25 = 5（3-4-5 直角三角形）
- `Vector2(1, 0).length()` = √(1² + 0²) = 1
- `Vector2(0, 0).length()` = 0

**normalized() 的作用**：把任意长度的向量缩为长度 1，方向不变。这样乘速度后得到的速度向量长度恒等于速度值，不会因为向量本身长度不同导致移动快慢不一。

## 原理

**向量数乘**：方向向量乘数字 = 长度变大方向不变。

- direction = (1, 0) → 长度 1，朝右
- direction * 250 = (250, 0) → 长度 250，仍朝右

## 优势

| 优势 | 说明 |
|------|------|
| 一个表达搞定 4 键移动 | 不用写 4 个 if 判断 |
| 自动归一化对角线 | 斜走不会比直走快 |
| 直接给速度向量 | 不用手算 dx/dy |

## 使用场景

- 2D 角色移动（我们的玩家）
- 怪物 AI 追玩家（朝玩家方向）
- 飞行物（弹道向量）
- 镜头平滑跟随

---

# 26 - Modulate 颜色调节与闪白特效

## 概念

**modulate** = 节点的"整体颜色调节器"。把节点绘制时的最终颜色乘上 modulate 值。

生活类比：节点本身是彩色照片，modulate 像彩色滤镜覆盖在上面。乘白（1,1,1）= 原色；乘红（2,0.2,0.2）= 发红。

## 功能

做受击闪白、死亡变灰、淡入淡出、染色特效。

## 运作方式

```gdscript
# 闪白：颜色超过 1.0 会发亮
modulate = Color(2, 2, 2, 1)   # R=2, G=2, B=2, A=1（发白）
# 恢复
modulate = Color(1, 1, 1, 1)   # 原色

# 淡出（受击死亡）
modulate = Color(1, 1, 1, 0.3)  # Alpha 0.3 = 半透明
```

Color 的 4 个参数：R、G、B、A。

- 数字 0~1 = 调暗
- 1 = 原色
- >1 = 发亮

Alpha（A）= 不透明度。1 不透明，0 全透明。

## 原理

GPU 像素着色时，每个像素 = `原图色 × modulate 值`。光线值 > 1 的部分会被"过度发光"看起来像被白光打中。这就是为什么 (2,2,2) 看起来是闪白。

## 优势

| 优势 | 说明 |
|------|------|
| 零素材做受击反馈 | 不用切换 sprite |
| 适合 MVP 占位 | 蓝色方块也能闪白 |
| 可做死亡淡出、染色 | 灵活 |
| 性能零成本 | GPU 单次运算 |

## 使用场景

- 角色/怪物受击闪白（0.1 秒 Color(2,2,2)）
- 死亡淡出（0.5 秒 Alpha 0→0）
- 中毒状态调制绿色
- Boss 进入阶段 2 调红色表示狂暴

---

## 关联

- InputMap → action → get_vector：[[24-GodotInputMap与输入映射]]
- 攻击触发后扣怪血：将来做战斗系统时补
- modulate 改色 + Tween 平滑过渡：[[18-GSAP与Tween动画]]