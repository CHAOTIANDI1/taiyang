# 18 - GSAP 与 Godot 的 Tween 动画

## 概念

**GSAP = GreenSock Animation Platform**，一个知名的 JavaScript 动画库，主要用在前端网页。

你在 2026-07-17 提到它，误打为 "gasp"。它是**网页动画库**，**跟 Godot 没关系**，但其中的"补间动画"Easing 思想是通用的。

## 功能

GSAP 让你用 JavaScript 代码描述"从状态 A 缓动到状态 B"的动画过程。比如：
- "这个按钮 0.3 秒淡入"
- "这个盒子的宽从 100 缓动到 500"
- 编排多段动画序列

## 运作方式（GSAP 是怎么干活的）

### GSAP 长什么样

```javascript
// JavaScript 代码
gsap.to(".box", { 
  duration: 0.3, 
  x: 200,           // 移动到 X=200
  ease: "power2.out" // 缓动曲线，先快后慢
});
```

例子结果：网页上一个黄色盒子在 0.3 秒内从原位置滑到右边 200 像素，速度先快后慢。

### Easing 缓动是什么

| 缓动 | 效果 |
|------|------|
| linear | 匀速 —— 机械感 |
| power2.out | 先快后慢 —— 自然感 |
| bounce.out | 末尾弹一下 —— 弹性感 |
| elastic.out | 末尾左右晃 —— 橡皮筋感 |

调节缓动让物体运动像"有重量、有性格"，而不是机械滑动。

## 原理

**Tween = 补间动画**。你只要给"起点"和"终点"，AI（GSAP）在中间每帧算插值，把物体平缓过渡。

不管什么引擎，核心思想都是"插值"。GSAP 只是 JavaScript 网页的实现版本。

## 优势

| GSAP 优势 | 说明 |
|----------|------|
| 网页最成熟的动画库 | 久经考验，用得多 |
| 大量缓动曲线 | 弹、缓、弹回、各种 |
| 链式编排 | 多段动画串联易 |

---

## 与我们 Godot 项目的关系

**结论：不要装 GSAP**。

| 维度 | 评估 |
|------|------|
| 适用平台 | GSAP 是 JavaScript，我们用 GDScript |
| 是否需要它 | ❌ 不需要，Godot 自己有 Tween 类 |
| 可以学什么 | ✅ 缓动曲线 (Easing) 概念，应用到 Godot Tween |
| 推荐应用 | ❌ 不应用（语言不匹配） |
| 推荐学思路 | ✅ Tween 思想 |

## Godot 自己的 Tween（我们应该用的）

在 Godot 4 里用 Tween 同样能干 GSAP 的活：

```gdscript
# Godot 4 GDScript
var tween = create_tween()
tween.tween_property($Box, "position:x", 200, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
# 0.3 秒内 position.x 缓到 200，缓动类型 sine，缓动方向 out
```

把这段对照 GSAP 版对比：

| GSAP | Godot Tween |
|------|-------------|
| `gsap.to()` | `create_tween().tween_property()` |
| `duration: 0.3` | `0.3` 第三参数 |
| `x: 200` | `"position:x", 200` |
| `ease: "power2.out"` | `.set_trans(TRANS_SINE).set_ease(EASE_OUT)` |

**90% 概念是通用的**，只是语法不同。

## 使用场景

### 场景 1: 游戏里"弹伤害数字"

GSAP 思路：`gsap.to(text, {y: -50, duration: 0.5, ease:"power2.out"})` 数字上飘。

Godot 落地：
```gdscript
var tween = create_tween()
tween.tween_property(damage_label, "position:y", -50, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
tween.parallel().tween_property(damage_label, "modulate:a", 0, 0.5)
```
数字上飘 + 淡出。0.5 秒。同样的事。

### 场景 2: 开场画面淡入

GSAP：`gsap.to(title, {alpha: 1, duration: 1})`。
Godot：`create_tween().tween_property($Title, "modulate:a", 1.0, 1.0)`。

### 场景 3: UI 按钮按下手感

按钮按下 → 0.1 秒缩到 0.9 → 0.1 秒弹回 1.0 —— 用 Tween 连续两段播。

## 学了 GSAP 思路怎么用在 Godot

打开 Godot 写 Tween 时，遇到"我想让动画更自然、更弹"，可以搜"GSAP easing"看视觉效果——记住名字和感觉，到 Godot Tween 文档找对应 API。

| GSAP 缓动 | Godot 对应 |
|----------|------------|
| power1 / power2 / power3 | TRANS_QUAD/CUBIC/QUART |
| sine.in/out | TRANS_SINE + EASE_IN/OUT |
| back.out | TRANS_BACK + EASE_OUT |
| bounce.out | TRANS_BOUNCE + EASE_OUT |
| elastic.out | TRANS_ELASTIC + EASE_OUT |

理解了 GSAP 的缓动，写 Godot Tween 就知道怎么调"感觉"了。

---

## 关联

- Godot 自己实现动画：将来做战斗手感时会再展开笔记
- 单例节点怎么挂 Tween：[[06-单例模式与Autoload]]
- 战斗打击感的代码补偿：[[15-Godot碰撞与粒子体积]]