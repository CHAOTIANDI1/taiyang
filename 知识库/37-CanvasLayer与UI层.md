# 37 - CanvasLayer 与 UI 层

## 本游戏实例（v2.7 准则，v2.8 主动识别）

- **遇到的问题**：Phase 4.4.3 宠物蛋孵化器需要在屏幕中央显示蛋图标 3 秒。如果用普通 Node2D + Sprite2D，蛋图标会跟随 Camera2D 移动——玩家走到地图右下角，蛋图标也跟到右下角，不在屏幕中央。需要一种"固定在屏幕上"的节点。
- **专业名词/知识点**：CanvasLayer（画布层）、UI 层、锚点系统（Anchors）、`anchors_preset`、`anchor_left/top/right/bottom`、`offset_left/top/right/bottom`、Control 节点家族
- **技术栈/代码/美术**：`scenes/pet/pet_egg_hatcher.tscn` 的 `EggCanvasLayer` 节点（layer=10）+ `EggIcon` ColorRect（anchors_preset=8 中心对齐）
- **应用过程**：
  1. 在 `pet_egg_hatcher.tscn` 加 `CanvasLayer` 子节点，设 `layer=10`（高于游戏世界的默认 layer=0）
  2. 在 CanvasLayer 下加 `ColorRect` 子节点作为蛋图标
  3. 设 ColorRect 的 `anchors_preset=8`（中心对齐）+ offset_left=-30, offset_top=-40, offset_right=30, offset_bottom=40（60×80 矩形居中）
  4. 这样蛋图标固定在屏幕中央，玩家移动时蛋不动，符合"屏幕中央蛋图标"的设计

---

## 概念

**CanvasLayer** = Godot 的"画布层"节点，让子节点脱离游戏世界的坐标系，固定在屏幕上。游戏世界的 Camera2D 移动时，CanvasLayer 里的内容不动。

生活比喻：游戏画面像"舞台 + 观众席摄像机"。Camera2D 是摄像机，会跟随主角移动；CanvasLayer 是"舞台前方的字幕屏"——不管摄像机怎么转，字幕永远在屏幕同一位置。

**本游戏专属例子 1（生动形象）**：把 CanvasLayer 想象成《太阳之下》的"游戏 UI 玻璃屏"。游戏世界（地图/玩家/怪物）在玻璃屏后面，玩家移动时玻璃屏后面的事物跟着移动；但是玻璃屏上的字（血条、对话、蛋图标）固定在玻璃屏上，不跟玩家移动。CanvasLayer 就是这块玻璃屏。

**本游戏专属例子 2（本游戏应用）**：Phase 4.4.3 宠物蛋孵化器的 `EggCanvasLayer`：
```ini
[node name="EggCanvasLayer" type="CanvasLayer" parent="."]
layer = 10

[node name="EggIcon" type="ColorRect" parent="EggCanvasLayer"]
anchors_preset = 8          # 中心对齐
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -30.0         # 60×80 矩形居中
offset_top = -40.0
offset_right = 30.0
offset_bottom = 40.0
color = Color(1, 0.9, 0.7, 1)
```
效果：蛋图标固定在屏幕中央（640, 360），玩家移动蛋不动，符合"屏幕中央蛋图标淡入"的设计真值。

## 功能

- 让子节点脱离游戏世界坐标系，固定在屏幕上
- 控制 UI 层级（layer 越大越靠前）
- 容纳 Control 节点家族（ColorRect / Label / Button / TextureRect 等）

## 运作方式

### CanvasLayer 的 layer 属性

```ini
[node name="EggCanvasLayer" type="CanvasLayer"]
layer = 10  # 默认 0，越大越靠前（覆盖在更小的 layer 上）
```

层级示例：

| layer | 装什么 | 例子 |
|-------|--------|------|
| -100 | 最底层（远景视差）| 远处山脉 |
| 0 | 游戏世界默认层 | 玩家/怪物/地图 |
| 10 | UI 层 | 蛋图标（4.4.3）|
| 20 | 弹窗层 | 背包/对话框 |
| 30 | 顶层 | 加载提示/警告 |

### 锚点系统（Anchors）

Control 节点（ColorRect / Label 等）用锚点定位。`anchors_preset` 是预设值：

| preset | 名字 | 含义 |
|--------|------|------|
| 0 | Top Left | 左上角 |
| 4 | Center Top | 顶部中央 |
| 8 | Center | 正中央 |
| 15 | Full Rect | 全屏（撑满父节点）|

### offset 与 anchor 的关系

```
节点位置 = 父节点尺寸 × anchor + offset
```

例：父节点 1280×720，anchor=0.5/0.5/0.5/0.5（中心），offset=-30/-40/30/40：
- 左边 = 1280 × 0.5 + (-30) = 610
- 上边 = 720 × 0.5 + (-40) = 320
- 右边 = 1280 × 0.5 + 30 = 670
- 下边 = 720 × 0.5 + 40 = 400

矩形位置：(610, 320) 到 (670, 400)，正好是 60×80 居中在 (640, 360)。

## 原理

Godot 的渲染分两套坐标系：
1. **世界坐标系（World2D）**：游戏世界，Camera2D 移动时世界里的节点跟着移动
2. **屏幕坐标系（Canvas）**：屏幕固定坐标，CanvasLayer 里的内容用这套坐标

CanvasLayer 不在世界坐标系里，它直接渲染到屏幕上，所以 Camera2D 怎么动它都不动。

## 优势

| 优势 | 说明 |
|------|------|
| UI 固定在屏幕 | 血条/对话框/蛋图标不受摄像机影响 |
| 层级清晰 | layer 属性控制谁覆盖谁 |
| 跨分辨率适配 | 锚点系统让 UI 在不同分辨率下自动居中 |
| 与游戏世界解耦 | UI 逻辑和游戏逻辑互不干扰 |

## 使用场景

### 场景 1：固定 UI（血条/小地图/任务提示）
血条永远在屏幕左上角，不管玩家走到哪。

### 场景 2：全屏弹窗（背包/设置/对话框）
按 I 打开背包，背包覆盖整个屏幕，按 Esc 关闭。

### 场景 3：过场动画 UI（4.4.3 蛋图标）
3 秒孵化动画期间，蛋图标固定在屏幕中央。

### 场景 4：伤害飘字
伤害数字飘出后消失，属于屏幕 UI（虽然位置基于世界坐标，但渲染在 CanvasLayer 上）。

## 反例 vs 正例（常见错误）

### 错误 1：UI 节点直接挂 Node2D 下导致跟随摄像机
```
❌ 错误：血条挂 Player 下
Player
└── HealthBar (ColorRect)  # 会跟随玩家移动，不在屏幕固定位置

✅ 正确：血条挂 CanvasLayer 下
World
├── Player (CharacterBody2D)
└── UICanvasLayer (CanvasLayer)
    └── HealthBar (ColorRect)  # 固定在屏幕左上角
```

### 错误 2：layer 设错导致 UI 被游戏世界覆盖
```ini
# ❌ 错误：UI 的 layer=0，和游戏世界同层，可能被怪物精灵覆盖
[CanvasLayer]
layer = 0

# ✅ 正确：UI 的 layer=10，高于游戏世界
[CanvasLayer]
layer = 10
```

---

## 关联

- await 异步等待（4.4.3 也用到）：[[36-await与异步等待]]
- 场景实例化（pet_egg_hatcher.tscn 被 world.tscn 实例化）：[[34-场景实例化与子场景]]
- Tween 动画（4.4.3 蛋图标淡入淡出）：[[28-Tween补间动画详解]]
- ColorRect 色块占位（4.4.2 宠物色块也用 ColorRect）：[[35-CharacterBody2D节点选型]]
