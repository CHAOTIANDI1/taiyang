# 06 - 单例模式与 Autoload

## 概念

**单例**（Singleton）= 全游戏**只存在一个实例**的全局对象。谁能访问它谁就能用它的功能。在 Godot 里叫 **Autoload**。

## 功能

让一个"管家"对象从一开始就存在，所有脚本都能用它，不用每次新建。

我们项目的管家清单：
- DataManager：读 JSON 数据
- SaveManager：存档读档
- GameTime：太阳历时间
- MailManager：邮件
- IntroSequence：过场播放
- InputManager：输入处理（未来封装）

## 运作方式（举例）

### 不用单例的反例

每次要读数据就新建一个：
```gdscript
# monster.gd
func _ready():
    var loader = DataManager.new()        # 新建
    var data = loader.load_json("...")
    loader.free()                          # 用完销毁
```

问题：每个怪物读一次就重新加载一次 JSON，浪费资源，且各读各的没法缓存。

### 用单例的正例

DataManager 在 Godot 启动时自动建一次，之后永远存在：
```gdscript
# scripts/core/data_manager.gd
extends Node

var monsters = {}    # 缓存

func _ready():
    monsters = load_json("data/monsters.json")  # 启动时读一次
```

任何脚本用：
```gdscript
# monster.gd
func get_hp():
    return DataManager.monsters["red_scorpion"]["hp"]  # 全局访问
```

## 原理

**Autoload** 是 Godot 的机制：你把一个脚本登记在 project.godot 里，Godot 启动时**自动创建它的实例并放在场景树根节点**，整个游戏任何脚本都能通过名字访问。

生活类比：城市邮政系统——你不用自己骑车去送信，往邮筒一扔邮局自动处理。邮局在北京上海各有一个局点，全国统一用"邮局"这个服务，你不需要操心怎么建邮局。

类比 2：地方政府部门——社保局全县只有一个，所有要办社保的人去它一个窗口，不是每个小区都开一个社保局。

## 优势

| 优势 | 说明 |
|------|------|
| 全局访问 | 任何脚本一行调用 |
| 资源共享 | JSON 只加载一次，内存中缓存 |
| 启动可用 | Godot 一启动就有，不用手动 init |
| 状态持久 | 一局游戏内它的数据一直在 |
| 利于联机 | 单例将来可以是"服务器代理"，客户端调单例的时候走网络 |

## 使用场景

### 场景 1：DataManager 读数据

```gdscript
extends Node

var items = {}
var monsters = {}

func _ready():
    items = load_json("data/items.json")
    monsters = load_json("data/monsters.json")

func get_item_info(item_id):
    return items.get(item_id, null)
```

只要有地方需要读物品信息：
```gdscript
var info = DataManager.get_item_info("mark_solar_boss_01")
```

### 场景 2：MailManager 满包入邮件

```gdscript
# 任务奖励发放
if player_inventory.is_full():
    MailManager.add_system_mail(
        title = "背包已满，奖励暂存",
        attachment = reward_item,
        expire_hours = 24
    )
```

`MailManager` 是单例，任何地方都能调，不怕找不到"发邮件的那个人"。

### 场景 3：GameTime 太阳历

```gdscript
# 任何脚本想现在几点
var date = GameTime.get_solar_date_string()   # "太阳历 426.03.18 06:30"
```

`GameTime` 启动时记录起点时间，永远从那算起。

## 在 Godot 里怎么注册单例

打开工程设置 → Autoload → 添加脚本 → 给个名字（如 `DataManager`）。
**Godot 启动时自动实例化它**。AI 我会操作 `project.godot` 文件加这一行：

```
[autoload]
DataManager="*res://scripts/core/data_manager.gd"
SaveManager="*res://scripts/core/save_manager.gd"
GameTime="*res://scripts/core/game_time.gd"
MailManager="*res://scripts/core/mail_manager.gd"
IntroSequence="*res://scripts/core/intro_sequence.gd"
```

---

## 关联

- 数据怎么从 JSON 给到单例：[[03-数据驱动架构与JSON工作原理]]
- 单例只算账不管表演：[[04-逻辑与显示分离原理]]
- 存档单例的未来升级路线：[[05-存档统一接口原理]]