# 29 - Signal 信号机制

## 概念

**Signal** = Godot 的"广播系统"。一个节点发信号 → 任意多个其他节点能收到通知。

生活比喻：电视台发出《新闻联播》，所有开了电视的人都能看。发的人不知道有多少人看，也不需要知道。

## 功能

让节点之间**松散耦合**——怪物死亡 → 掉落系统听到就掉东西→任务系统听到就计入击杀数。三件事都可独立添加/移除，互不干扰。

## 运作方式

### 声明信号

```gdscript
# monster.gd
signal died       # 在脚本顶部声明一个信号
```

这一行告诉 Godot："这个节点能发一种叫 died 的信号"。

### 发送信号

```gdscript
func start_dying() -> void:
	_is_dying = true
	emit_signal("died")   # 发！
```

`emit_signal` 时，所有连了这个信号的人都会被通知。

### 接收信号

**方式 A：代码连接**

```gdscript
func _ready() -> void:
	monster.died.connect(_on_monster_died)

func _on_monster_died() -> void:
	print("怪死了")
	# 通知掉落系统洒装备
	# 通知任务系统计入击杀
```

**方式 B：还是代码连接（带参）**

```gdscript
# 声明带参信号
signal take_damage(amount: int)

func _ready() -> void:
	monster.take_damage.connect(_on_monster_take_damage)

func _on_monster_take_damage(amount: int) -> void:
	print("受到 %d 伤害" % amount)
```

**方式 C：在编辑器里连接**

暂时我们不用——纯文本建项目，全部用代码连接。

## 原理

每个信号在节点里维护一张"监听者列表"。`emit_signal` 时按列表逐个回调。本质是**观察者模式**（Observer Pattern）。

为什么叫信号不叫事件：Godot 的术语。本质是事件机制。

## 优势

| 优势 | 说明 |
|------|------|
| 节点之间松耦合 | 怪物不需知道谁在听它死亡 |
| 加功能不需要改原文件 | 新掉落系统？只要.connect 它自己监听 |
| 同时多个监听者 | 1 个信号能让 N 个系统反应 |
| 删监听不影响发布者 | 不监听就是没收到 |

## 不用信号的坏处

```gdscript
# ❌ 反例：怪物死时直接调每个系统
func on_died():
	InventoryManager.add_drop(self.drops)
	QuestManager.add_kill(self.id)
	AudioManager.play_sfx("monster_die")
	SceneManager.spawn_particles(self.position)
```

问题：怪物必须知道 InventoryManager、QuestManager、...。

```gdscript
# ✅ 正例：发信号，别人谁关心自己连接
signal died
func on_died():
	emit_signal("died")
```

将来想加一个"成就系统监听击杀"——不用改怪物，掉落/任务/音频代码也不动。

## 使用场景

### 我们已用

```gdscript
# monster.gd
signal died

# 同文件
emit_signal("died")
```

### 将来要用的

| 信号 | 发送者 | 谁监听 |
|------|--------|--------|
| monster.died | 怪物 | 掉落/任务/统计 |
| player.took_damage | 玩家 | UI 血条更新/低血音效 |
| inventory.item_added | 背包 | UI 刷新/任务计数 |
| ui.dialogue_finished | 对话 | 推进任务 |
| mail.received | 邮件 | 邮件红点提示 |

## 反例 vs 正例（常见错误）

| 错误 | 原因 |
|------|------|
| 监听者已销毁但还连着 | 触发时空对象报错——用 `is_instance_valid()` 判 |
| 多人连接同一信号 | 多人监听没问题，但要注意顺序 |
| emitsignal 时没监听者 | 不报错——安全 |

---

## 关联

- 怪物死亡通知：代码见 monster.gd start_dying
- Area2D 也有信号 body_entered：[[27-Area2D区域检测器]]
- Tween 节点销毁顺序问题：[[28-Tween补间动画详解]]