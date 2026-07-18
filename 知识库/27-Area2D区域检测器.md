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
_hitbox_area.collision_mask = 4                # 只检测 layer 4（怪物），不检测玩家自己
var rect = RectangleShape2D.new()
rect.size = Vector2(50, 50)                    # 50x50 矩形
_hitbox_shape.shape = rect                      # 形状挂上去
_hitbox_area.add_child(_hitbox_shape)

# 在 _physics_process 里检测
var bodies = _hitbox_area.get_overlapping_bodies()  # 拿到当前重叠的所有物理体
for body in bodies:
    if body == self:                           # 三重保险：排除自己
        continue
    if body.has_method("take_damage"):
        body.take_damage(attack_damage)
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

**mask 过滤机制**：`get_overlapping_bodies()` 只返回 layer 和 Area2D 的 mask 匹配的物体。设 `collision_mask = 4` 就只返回 layer 4 的物体（怪物），不返回 layer 2 的玩家。详见 [[30-碰撞层与碰撞遮罩]]。

## 优势

| 优势 | 说明 |
|------|------|
| 不写碰撞算法 | 你只关心"谁进来了" |
| 灵活 | 矩形/圆形都行，多边形也行 |
| 不阻挡其他物体 | 做拾取区不会被它挡住 |
| 适合触发器 | 对话/任务/AOE 技能都适合 |
| mask 过滤 | 设 collision_mask 精确控制检测哪些层，不检测自己 |

## 碰撞层 vs 碰撞掩码（重要知识点）

Godot 有 32 个碰撞层（Layer 1~32），每个节点可以：
- 在哪些层（Layer）：我是谁
- 检测哪些层（Mask）：我关心谁

**本项目碰撞层规范**（详见 [[30-碰撞层与碰撞遮罩]]）：

| 层编号 | 十进制值 | 是谁 |
|--------|---------|------|
| 1 | 1 | 墙体、地面、障碍物 |
| 2 | 2 | 玩家 |
| 3 | 4 | 怪物、NPC |
| 4 | 8 | 道具、可交互物体（将来） |
| 5 | 16 | 宠物（将来） |

玩家 hitbox 的 mask=4（检测怪物层），不检测玩家自己。

> **历史教训**（2026-07-18）：Phase 4 早期未设 hitbox 的 mask，导致 hitbox 检测到玩家自己，按 J 攻击时自己打自己飘伤害数字。修复：`collision_mask = 4` + `if body == self: continue` 三重防护。

## 使用场景

- 攻击命中（当前的 player attack box）
- 怪物引诱范围（玩家进了怪就开始追）
- 对话触发（靠近 NPC 弹对话）
- 物品拾取
- 陷阱伤害
- 未来：Area2D 软推力（怪物推玩家，不靠物理碰撞靠代码施力）

---

## 关联

- 碰撞层与遮罩详解：[[30-碰撞层与碰撞遮罩]]
- Tween 让数字上飘淡出：[[28-Tween补间动画详解]]
- 信号让怪物死亡时通知别人：[[29-Signal信号机制]]
- 模板 vs 具体：[[06-单例模式与Autoload]]
