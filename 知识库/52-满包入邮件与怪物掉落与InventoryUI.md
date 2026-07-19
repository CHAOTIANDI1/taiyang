# 52 - 满包入邮件与怪物掉落 + InventoryUI

> 本笔记解释 LootHelper 工具类 + InventoryUI 界面 + 怪物死亡掉落 + 满包入邮件四件套如何协作。
> 上接 [[51-EquipmentManager装备耐久]]，是 Phase 4.5 物品体系的最后一篇。

---

## 本游戏实例（v2.7 强制段）

**遇到的问题**：
Phase 4.5 子任务 4：玩家击败红尾蝎需要：
1. 40% 概率掉落 `material_leather_001`
2. 掉落物入背包，但背包满时要入邮件（24h 限领）
3. 玩家按 I 键打开背包界面看物品
4. 任务奖励无视背包容量（重要物品越过容量检查）
5. 不让每个调用方都自己写"满包入邮件"逻辑

**专业名词/知识点**：
- **LootHelper（掉落辅助管家）**：统一封装"获得物品"逻辑的 Autoload 单例
- **满包入邮件**：背包 30 格用完时，新奖励自动入邮件，24h 内领取
- **重要物品越过容量**：important 类永远返回 true，不走邮件
- **怪物掉落（Drop Loot）**：怪物死亡按 drops 数组随机发放物品
- **CanvasLayer/UI Control**：Godot UI 节点系统

**技术栈/代码**：
- `scripts/core/loot_helper.gd`（Autoload 单例）
- `scripts/ui/inventory_ui.gd`（背包 UI 脚本）
- `scenes/ui/inventory_ui.tscn`（背包 UI 场景）
- `scripts/enemy/monster.gd` 的 `start_dying()` 调 `LootHelper.drop_loot()`
- `project.godot` 加 `inventory_toggle` 输入映射（I 键）

**应用过程**：
1. 创建 LootHelper Autoload 单例，封装 `give_item(item_id, count, source)` 和 `drop_loot(monster_id)`
2. give_item 流程：调 InventoryManager.add → 成功返回 true / 失败入邮件返回 false
3. drop_loot 流程：读 monsters.json drops 数组 → 遍历每个 drop → randf() < chance 时调 give_item
4. 修改 monster.gd 的 `start_dying()` 调 `LootHelper.drop_loot(monster_id)`
5. 创建 InventoryUI 场景（Control + Panel + VBoxContainer + GridContainer）
6. UI 监听 inventory_changed + equipment_changed 信号自动刷新
7. `_unhandled_input` 监听 I 键调 `toggle()`
8. 在 world.tscn 实例化 InventoryUI 节点

---

## 概念

### 1. 生动形象例子（快递驿站）

把 LootHelper 想象成快递驿站：

```
你买了 1 件商品（获得物品）
  → 快递员先送到你家门口（背包）
  → 如果家门口堆满了（背包满）
  → 快递员把包裹暂存到驿站（邮件），24 小时内不取就退回
```

**重要物品越过容量**就像：
- 房产证（重要物品）必须送达，驿站不收
- 快递员翻墙也要塞进你家（无限容量）
- 普通商品（药水/材料）才走"满包入邮件"流程

### 2. 本游戏实际应用例子

玩家击败红尾蝎：

```
monster.gd.start_dying()
  → LootHelper.drop_loot("red_scorpion", "红尾蝎")
    → 读 monsters.json["red_scorpion"].drops
    → [{"item_id":"material_leather_001", "chance":0.4}]
    → randf() = 0.234 < 0.4 → 触发掉落
    → LootHelper.give_item("material_leather_001", 1, "击败 红尾蝎")
      → InventoryManager.add("material_leather_001", 1)
        → 重要物品？否（category="material"）
        → 普通槽堆叠 / 开新格
        → 成功 → 打印 "[LootHelper] 获得 普通皮革 ×1（来源：击败 红尾蝎）"
        → 返回 true
```

如果背包 30 格全满：

```
give_item("material_leather_001", 1, "击败 红尾蝎")
  → InventoryManager.add → 失败（满包）
  → MailManager.add_system_mail(
      "背包已满：普通皮革",
      "你获得了 1 个普通皮革，但背包已满。请在 24 小时内领取附件。\n来源：击败 红尾蝎",
      {"item_id":"material_leather_001", "count":1},
      24
    )
  → 打印 "[LootHelper] 背包已满，普通皮革 ×1 入邮件"
  → 返回 false
```

---

## 功能

### LootHelper（核心工具）

1. **give_item(item_id, count, source)** → bool
   - 重要物品直接入包（永远成功）
   - 普通物品入包，满包入邮件
   - 返回 true=入包成功，false=入邮件
2. **drop_loot(monster_id, monster_name)** → void
   - 读 monsters.json drops 数组
   - 按 chance 概率随机发放
   - 自动调 give_item

### InventoryUI（界面）

1. **I 键开关**：按 I 显示/隐藏背包
2. **3 个区域显示**：
   - 装备槽（weapon + armor 含耐久度）
   - 重要物品（无限容量列表）
   - 普通物品（30 格网格，空格显示 [空]）
3. **信号驱动刷新**：监听 inventory_changed + equipment_changed 信号

---

## 运作方式（含具体例子）

### LootHelper.give_item 完整流程

```gdscript
func give_item(item_id, count=1, source=""):
    var item = DataManager.get_item(item_id)
    if item.is_empty(): return false

    # 步骤 1: 尝试入包
    if InventoryManager.add(item_id, count):
        print("[LootHelper] 获得 %s ×%d（来源：%s）" % [item.name, count, source])
        return true

    # 步骤 2: 满包入邮件（重要物品永远走步骤 1 成功，不会到这里）
    var attachment = {"item_id": item_id, "count": count}
    var mail_title = "背包已满：%s" % item.name
    var mail_body = "你获得了 %d 个%s，但背包已满。请在 24 小时内领取附件。" % [count, item.name]
    if source != "":
        mail_body += "\n来源：%s" % source
    MailManager.add_system_mail(mail_title, mail_body, attachment, 24)
    print("[LootHelper] 背包已满，%s ×%d 入邮件" % [item.name, count])
    return false
```

### monster.gd 死亡掉落

```gdscript
func start_dying():
    _is_dying = true
    _die_timer = 0.0
    emit_signal("died")
    if _drops.size() > 0:
        var data = DataManager.get_monster(monster_id)
        var display_name = data.get("name", monster_id)
        LootHelper.drop_loot(monster_id, display_name)
```

### drop_loot 概率滚动

```gdscript
func drop_loot(monster_id, monster_name=""):
    var monster_data = DataManager.get_monster(monster_id)
    var drops = monster_data.get("drops", [])
    for drop in drops:
        var item_id = drop.get("item_id", "")
        var chance = float(drop.get("chance", 0.0))
        if item_id == "" or chance <= 0.0:
            continue
        var roll = randf()  # 0.0 ~ 1.0 随机数
        if roll < chance:
            var count = int(drop.get("count", 1))
            give_item(item_id, count, "击败 %s" % monster_name)
```

### InventoryUI 刷新流程

```
玩家按 I → inventory_toggle 输入触发
  → _unhandled_input 检测 → toggle()
  → visible = not visible
  → 如果 visible：调 _refresh()
    → 清空 _important_list 子节点 → 重新生成 Label
    → 清空 _normal_grid 子节点 → 生成 30 个格子（前 N 个有物品，后面 [空]）
    → 读 EquipmentManager.get_all_slots() → 显示武器/护甲耐久

背包有变化（add/remove）→ InventoryManager.emit_signal("inventory_changed")
  → InventoryUI._refresh() 自动触发（如果可见）
```

---

## 原理

### 1. 为什么用 LootHelper 而不是直接调 InventoryManager

| 方案 | 优点 | 缺点 |
|------|------|------|
| 直接调 InventoryManager.add | 简单 | 每个调用方都要写满包入邮件逻辑 |
| 统一 LootHelper.give_item | 复用一次写好 | 多一层间接 |

选了 LootHelper：
- 怪物掉落、任务奖励、邮件附件、NPC 商店购买 4 处都要写"满包入邮件"
- 4 处复用 → 节省 4 倍代码 → 复用价值高
- 符合 §1.1 逻辑显示分离：LootHelper 是逻辑层，UI 不操心

### 2. 重要物品越过的实现

InventoryManager.add 对 important 类永远返回 true（无限容量）。LootHelper.give_item 流程：

```
add() → InventoryManager 内部判断：
  if category == "important":
    _important[id] += count
    return true  ← 永远成功
  else:
    ... 走堆叠/开格逻辑 → 可能返回 false
```

所以 give_item 中"满包入邮件"分支只有普通物品会走到，重要物品绝不会入邮件。这是 docs/10-UI与交互.md "重要物品直接越过容量检查发放"规则的落地。

### 3. UI 信号驱动刷新

```gdscript
func _ready():
    InventoryManager.inventory_changed.connect(_refresh)
    EquipmentManager.equipment_changed.connect(_refresh)

# 数据变化时（add/remove/equip/unequip）：
emit_signal("inventory_changed")  # 自动触发 _refresh
```

观察者模式（[[29-Signal信号机制]]）：
- InventoryManager 不知道 UI 存在
- UI 监听信号自动响应
- 解耦彻底，符合 §1.1 逻辑与显示分离

### 4. UI 节点结构

```
InventoryUI (Control, anchors=FULL_RECT)
├── ColorRect (背景遮罩, 半透明黑色)
└── Panel (中心面板 700×500)
    └── VBoxContainer
        ├── Label "背包（I 键开关）"
        ├── VBoxContainer 装备槽区
        │   ├── Label 武器：xxx（耐久 N）
        │   └── Label 护甲：xxx（耐久 N）
        ├── Label "── 重要物品 ──"
        ├── VBoxContainer 重要物品列表
        ├── Label "── 普通物品 ──"
        └── GridContainer 5列网格（30 格）
```

### 5. _unhandled_input vs _input

```gdscript
func _unhandled_input(event):
    if Input.is_action_just_pressed("inventory_toggle"):
        toggle()
```

选 _unhandled_input 而非 _input：
- _input 会拦截所有输入（包括 UI 输入）
- _unhandled_input 只在没人处理时收到（UI 优先级更高）
- 背包打开时按其他键不会被背包脚本抢走

---

## 优势

1. **LootHelper 复用**：4 处调用方共用满包入邮件逻辑
2. **重要物品安全**：永远不会因满包丢失剧情道具
3. **UI 自动刷新**：信号驱动，无需手动调用 refresh
4. **数据驱动掉落**：drops 数组在 monsters.json，加新掉落只改 JSON
5. **I 键全局可用**：UI 挂在 World 上，所有场景通用

---

## 使用场景（含对接）

### 当前对接

| 调用方 | 接口 | 用途 |
|--------|------|------|
| monster.gd.start_dying | `LootHelper.drop_loot(monster_id, name)` | 怪物死亡掉落 |
| 任务系统（未来） | `LootHelper.give_item(item_id, count, "任务奖励")` | 任务奖励发放 |
| NPC 商店（未来） | `LootHelper.give_item(item_id, count, "商店购买")` | 商店购买 |
| 邮件附件领取（未来） | `LootHelper.give_item(item_id, count, "邮件附件")` | 邮件附件 |
| InventoryUI | 监听 inventory_changed / equipment_changed | 自动刷新 |
| 玩家按 I 键 | inventory_toggle 输入 | 开关背包界面 |

### 测试用例（F5 验证）

```
F5 启动 → 控制台显示:
  [InventoryManager] 已加载（Autoload 启动）
  [EquipmentManager] 已加载
  [LootHelper] 已加载

玩家按 P 孵化宠物 → 不影响背包
玩家按 J 攻击红尾蝎 → 命中后消耗 1 点武器耐久
  但玩家未装备武器 → consume_durability 检查 _weapon.is_empty() → 直接 return

玩家击败红尾蝎 → 40% 概率掉落:
  [LootHelper] 获得 普通皮革 ×1（来源：击败 红尾蝎）

玩家按 I 键 → 背包界面弹出:
  ── 装备槽 ──
  武器：[未装备]
  护甲：[未装备]
  ── 重要物品 ──
  宠物蛋（火腿狗） ×1
  ── 普通物品 ──
  普通皮革 ×1  [空] [空] ... (30 格)

按 I 关闭 → 背包隐藏
```

### 未来扩展

- UI 加按钮：右键物品弹出"使用/丢弃/装备"菜单
- 装备穿戴：点击 weapon 类物品 → 调 EquipmentManager.equip
- 食物食用：右键食物 → 调用食用逻辑（未来食物系统）
- NPC 商店接入：和 NPC 对话时打开商店 UI

---

## 反例 vs 正例对照

| 反例（违规） | 正例（合规） |
|------|------|
| 怪物死亡直接调 InventoryManager.add | 调 LootHelper.give_item（统一满包入邮件） |
| 重要物品满包时入邮件 | important 类永远返回 true，永不入邮件 |
| UI 直接读 InventoryManager._normal | 监听 signal + 调 get_normal_items() 接口 |
| UI 在 _input 抢所有按键 | 在 _unhandled_input 不影响其他 UI |
| 每个调用方自己写满包判断 | LootHelper 统一封装 |

---

## 关联

- 物品数据怎么查：[[49-物品体系与数据驱动]]
- 背包容器实现：[[50-InventoryManager容器逻辑]]
- 装备槽和耐久：[[51-EquipmentManager装备耐久]]
- 信号机制：[[29-Signal信号机制]]
- Autoload 单例：[[06-单例模式与Autoload]]
- 输入映射：[[24-GodotInputMap与输入映射]]
- 邮件系统：[[13-音效与音乐资源处理]]（待补邮件专题）
