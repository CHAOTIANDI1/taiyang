# 06 - 单例模式与 Autoload（小白生动版）

## 概念

**单例 = 全游戏只存在一个的"管家"对象**，谁能访问它谁就能用它的功能。在 Godot 里叫 **Autoload**。

生活类比：城市邮局只有一个，全县都往那个邮局寄信。你不用自己骑自行车去北京送信，往邮筒一扔邮局自动处理。

再类比：你家里只有一个"电闸"。开灯关灯找电闸就行，不是每个房间装一个自己的电闸。

## 功能

让一个"管家"对象从一开始就存在，**所有脚本都能用它，不用每次新建**。

我们项目的 6 个管家：

| 管家名字 | 管什么 | 类比 |
|----------|--------|------|
| DataManager | 读所有 JSON 数据 | 档案管理员 |
| SaveManager | 存档读档 | 银行柜员 |
| GameTime | 太阳历时间 | 城市钟塔 |
| MailManager | 邮件系统 | 邮局局长 |
| IntroSequence | 过场播放 | 剧院放映员 |
| AudioManager | 播放音效 BGM | 电视台导播 |

## 运作方式（含例子）

### 反例：不用单例（每个脚本自己读数据）

```gdscript
# monster.gd
func _ready():
    var loader = DataManager.new()        # 每次新建
    var data = loader.load_json("...")
    loader.free()                          # 用完销毁
```

问题：每个怪物进场都新建一次 → 加载一次 JSON → 销毁。**100 只小怪 = 100 次读取**，浪费内存。

### 正例：用单例（DataManager 启动时建一次，永远在）

DataManager 在 Godot 启动时**自动建好**，之后整个游戏期间一直存在：

```gdscript
# scripts/core/data_manager.gd
extends Node

var monsters = {}    # 缓存

func _ready():
    monsters = load_json("data/monsters.json")  # 启动时只读一次
```

任何脚本想用：
```gdscript
# monster.gd
func get_hp():
    return DataManager.monsters["red_scorpion"]["hp"]  # 一行搞定
```

生活类比：邮局早上 8 点开门，全天服务。你随时想寄信，去邮局就行，不用每次写信先建一个新邮局再用完拆掉。

## 原理

**Autoload 是 Godot 的机制**：你把一个脚本登记在 `project.godot` 里，Godot 启动时**自动创建它的实例并放在场景树根节点**，整个游戏期间任何脚本都能通过名字访问。

类比：地方政府部门——社保局全县只有一个，所有要办社保的人去它一个窗口，不是每个小区开一个社保局。

### Autoload 怎么登记

打开 Godot 编辑器 → 项目设置 → Autoload → 添加脚本 → 给个名字。
**Godot 启动时自动实例化它**。其实就是 `project.godot` 文件加几行：

```
[autoload]
DataManager="*res://scripts/core/data_manager.gd"
SaveManager="*res://scripts/core/save_manager.gd"
GameTime="*res://scripts/core/game_time.gd"
MailManager="*res://scripts/core/mail_manager.gd"
IntroSequence="*res://scripts/core/intro_sequence.gd"
AudioManager="*res://scripts/core/audio_manager.gd"
```

`*` 表示自动实例化`*res://...` 是 Godot 的"资源路径"前缀。

## 优势

| 优势 | 大白话 |
|------|--------|
| 全局访问 | 任何脚本一行调用 |
| 资源共享 | JSON 只加载一次，内存中缓存——100 只怪共用一份数据 |
| 启动可用 | Godot 一启动就有，不用手动 init |
| 状态持久 | 一局游戏内它的数据一直在 |
| 利于联机 | 将来单例可以作为"服务器代理"，客户端调单例时走网络 |

## 使用场景

### 场景 1: DataManager 读数据

```gdscript
var info = DataManager.get_item_info("mark_solar_boss_01")
# 真DataManager.json 里查到太阳印记信息
```

### 场景 2: MailManager 满包入邮件

```gdscript
# 任务奖励发放
if player_inventory.is_full():
    MailManager.add_system_mail(
        title = "背包已满，奖励暂存",
        attachment = reward_item,
        expire_hours = 24
    )
```
MailManager 是单例，任何地方都能调，不怕找不到"发邮件的那个人"。

### 场景 3: GameTime 太阳历

```gdscript
# 任何脚本想现在几点
var date = GameTime.get_solar_date_string()   # "太阳历 426.03.18 06:30"
```
GameTime 启动时记录起点时间，永远从那算起。

### 场景 4: AudioManager 播音

```gdscript
AudioManager.play_bgm("bgm_village")     # 切 BGM
AudioManager.play_sfx("sfx_sword_hit")  # 一次性音效
```
不用关心 AudioManager 怎么实现，调接口就行。

## 为什么单例不直接改血条

**这跟地基规矩 1（逻辑与显示分离）一致**：

```gdscript
# ✅ 对：单例做逻辑，画面自己反应
DataManager.get_monster_hp("red_scorpion")  # 单例返数据
enemy_script.take_damage(12)               # 敌人脚本算扣血
emit_signal("damaged", 12)                 # 广播事件给画面
enemy_view.play_animation()                # 画面自己表演

# ❌ 错：单例直接动画面
AudioManager.stop()  # AudioManager 应该只管声音，不能去管血条和血量
```

每个单例只做自己擅长的事，**不越界**。

## MVP 阶段 6 个单例的代码量预估

| 单例 | 预估行数 | MVP 状态 |
|------|---------|---------|
| DataManager | ~80 行 | ✅ 实现 |
| SaveManager | ~150 行 | ✅ 实现 |
| GameTime | ~50 行 | ✅ 实现 |
| MailManager | ~100 行 | ✅ 实现 |
| IntroSequence | ~80 行 | ✅ 实现 |
| AudioManager | ~80 行 | ✅ 实现 |

**全部加起来约 540 行核心代码**。这些代码量大头在 MVP 编码阶段一次写完，后续无大改。

---

## 关联

- 数据怎么从 JSON 给到单例：[[03-数据驱动架构与JSON工作原理]]
- 单例只算账不管表演：[[04-逻辑与显示分离原理]]
- 存档单例的未来升级路线：[[05-存档统一接口原理]]
- 单例里怎么用 Tween 做动画：[[18-GSAP与Tween动画]]