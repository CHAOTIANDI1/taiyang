# 27 - Area2D 区域检测器与攻击判定

## 概念

**Area2D** = Godot 的"看不见的警戒区"节点。其他物理体进入或离开时，Area2D 会发信号让你知道。

生活比喻：博物馆入口的"红外线报警器"——人穿过就响铃。你不用每秒问"有人进入吗"，是报警器主动告诉你。

## 功能

- 检测谁进入这个区域（攻击命中判定、陷阱、拾取范围、对话触发等）
- 检测谁离开
- 不参与"撞墙"——纯检测不阻挡

## 运作方式

### 节点结构

```
Area2D（区域本身）
└── CollisionShape2D（区域的形状，可以是矩形/圆形/线段）
```

### 关键属性

| 属性 | 含义 |
|------|------|
| `monitoring` | 是否检测别人进入，true 时才会发信号 |
| `monitorable` | 是否能被别人检测到 |
| `collision_layer` | 这区域在哪个碰撞层 |
| `collision_mask` | 这区域关心哪些碰撞层 |

### 我们代码里的用法

```gdscript
# player.gd
_hitbox_area = Area2D.new()                    # 新建攻击 Box
_hitbox_area.monitoring = false                # 默认关闭（只在按 J 时开）
var rect = RectangleShape2D.new()
rect.size = Vector2(50, 50)                    # 50x50 矩形
_hitbox_shape.shape = rect                      # 形状挂上去
_hitbox_area.add_child(_hitbox_shape)

# 在 _physics_process 里检测
var bodies = _hitbox_area.get_overlapping_bodies()  # 拿到当前重叠的所有物理体
```

生命周期：
```
平时：monitoring=false，hitbox 不工作
按 J → monitoring=true，开始检测
检测到怪 → 调用怪.take_damage()
攻击结束 → monitoring=false
```

## 原理

Godot 每物理帧（60fps）检查每个 Area2D 的重叠。每帧 Area2D 维护一张"当前重叠的物体列表"，你可以用 `get_overlapping_bodies()` 查这张列表。物体进出时发 `body_entered` / `body_exited` 信号。

## 优势

| 优势 | 说明 |
|------|------|
| 不写碰撞算法 | 你只关心"谁进来了" |
| 灵活 | 矩形/圆形都行，多边形也行 |
| 不阻挡其他物体 | 做拾取区不会被它挡住 |
| 适合触发器 | 对话/任务/AOE 技能都适合 |

## 碰撞层 vs 碰撞掩码（重要知识点）

Godot 有 32 个碰撞层（Layer 0~31），每个节点可以：
- 在哪些层（Layer）：我是谁
- 检测哪些层（Mask）：我关心谁

我们 MVP 推荐：
| 层 | 是谁 |
|----|------|
| 0 | 玩家 |
| 1 | 怪物 |
| 2 | 墙/地面 |
| 3 | NPC |
| 4 | 道具 |
| 5 | 攻击 hitbox（玩家）|
| 6 | 攻击 hitbox（怪物）|

玩家 hitbox 的 Layer=5，Mask=1（关心怪物层）。怪物 hitbox 的 Layer=6，Mask=0（关心玩家层）。

**MVP 阶段我们简化**：没分层，反正现在所有怪都该被打。

## 使用场景

- 攻击命中（当前的 player attack box）
- 怪物引诱范围（玩家进了怪就开始追）
- 对话触发（靠近 NPC 弹对话）
- 物品拾取
- 陷阱伤害

---

## 关联

- Tween 让数字上飘淡出：[[28-Tween补间动画详解]]
- 信号让怪物死亡时通知别人：[[29-Signal信号机制]]
- 模板 vs 具体：[[06-单例模式与Autoload]]