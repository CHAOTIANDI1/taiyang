# 28 - Tween 补间动画详解

## 概念

**Tween** = "补间动画"——你只给"起点"和"终点"，Godot 自动计算中间每帧怎么过渡。

生活比喻：你跟出租车说"从这到那 0.6 秒内到"——中间走哪条路、什么时候快什么时候慢，司机自己决定。你不用每秒喊"现在到 50% 距离了"。

## 功能

- 让节点的属性（位置、颜色、缩放等）从一个值**平滑过渡**到另一个值
- 支持多种缓动曲线（先快后慢，弹一下等）
- 支持并行动画（同时改多个属性）
- 支持链式动画（一段跑完跑下一段）

## 运作方式

### 基础用法

```gdscript
# 0.6 秒内把 label 的 y 坐标从当前值飞到 -40
var t: SceneTreeTween = create_tween()
t.tween_property(label, "position:y", label.position.y - 40, 0.6)
```

`SceneTreeTween` 是返回类型，不要用 `:=` 推断（GDScript 4.7 严格模式）——用 `var t: SceneTreeTween`。

### 并行：同时两个动画

```gdscript
var t = create_tween()
# parallel() 后下一个 tween 和它同时跑
t.parallel().tween_property(label, "position:y", label.position.y - 40, 0.6)
t.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
# 6 秒内：数字上飘 40 像素 + 同时淡出
```

### 链式：一段接一段

```gdscript
var t = create_tween()
t.tween_property(box, "position:x", 100, 0.3)
t.chain().tween_callback(box.queue_free)  # 0.3 秒后销毁
```

### 缓动曲线

```gdscript
t.tween_property(box, "position", target, 0.5)
 .set_trans(Tween.TRANS_SINE)  # 正弦（绵软感）
 .set_ease(Tween.EASE_OUT)     # 先快后慢（自然感）
```

| 缓动 | 感觉 |
|------|------|
| EASE_OUT | 先快后慢——自然 |
| EASE_IN | 先慢后快——机械 |
| EASE_IN_OUT | 两端慢中间快 |
| TRANS_SINE | 圆滑 |
| TRANS_BOUNCE | 弹一下 |
| TRANS_ELASTIC | 橡皮筋 |

## 原理

**插值**：给起点 A 和终点 B，按时间百分比 t 算 `A + (B-A) * 缓动函数(t)`。

每帧 Godot 内部：
1. 更新 Tween 的进度
2. 用缓动函数算当前值
3. 写回节点属性
4. 渲染

不在物理帧（_physics_process）而在渲染帧跑。

## 优势

| 优势 | 说明 |
|------|------|
| 写一行做完整动画 | 不用每帧算坐标 |
| 自动跟随帧率 | 60fps 和 30fps 看起来一样 |
| 性能好 | 内部 C++ 实现 |
| 销毁节点方便 | `chain().tween_callback(queue_free)` |

## 使用场景

- 伤害数字上飘淡出（我们 player.gd 当前用法）
- 攻击受击闪白恢复（monster.gd 的 take_damage）
- 开场画面淡入
- 摄像机屏震回弹
- UI 弹窗出现/消失
- Boss 死亡淡出

## 我们代码中 3 处用 Tween

| 位置 | 用途 |
|------|------|
| player.gd `_shake_camera` | 摄像机偏移回 0 |
| player.gd `_spawn_damage_number` | Label 上飘+淡出+销毁 |
| monster.gd `take_damage` | 0.1 秒从白色恢复原色 |

## 常见错误

| 错误 | 原因 |
|------|------|
| `var t := create_tween()` 4.7 报错 | 返回 SceneTreeTween 是 Variant，要 `var t: SceneTreeTween = create_tween()` |
| Tween 跑了一半节点被销毁 | 错误发生——用 chain + tween_callback 顺序销毁 |
| Tween 让节点"闪现"到终点 | 没给起点直接给终点，Tween 会先瞬移再过渡 |

---

## 关联

- Area2D 检测命中：[[27-Area2D区域检测器]]
- 信号通知死亡：[[29-Signal信号机制]]
- GSAP 思路一致：[[18-GSAP与Tween动画]]