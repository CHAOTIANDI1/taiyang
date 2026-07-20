# 50 - InventoryManager 容器逻辑

> 本笔记解释背包容器的实现原理：双数据结构（Dict + Array）、堆叠机制、满包信号、存档对接。
> 上接 [[49-物品体系与数据驱动]]，下接 [[51-EquipmentManager装备耐久]]。

---

## 本游戏实例（v2.7 强制段）

**遇到的问题**：
Phase 4.5 子任务 2：玩家击败红尾蝎后获得材料、买药水、装备武器都需要一个"容器"装东西。设计要求（docs/06-物品体系.md + docs/10-UI与交互.md）：
- 重要物品（太阳印记/宠物蛋/凭证）无限容量，不可丢
- 普通物品（武器/护甲/药水/食物/材料）30 格
- 每格可堆叠（材料堆 99，食物堆 30）
- 满包时新奖励自动入邮件（24h 限领）
- 任务奖励和重要物品越过容量检查

**专业名词/知识点**：
- **容器（Container）**：游戏里"装物品的数据结构"，不是 Godot 节点
- **双数据结构**：Dict 装"无限制"物品 + Array 装"有格限制"物品
- **堆叠（Stack）**：同 ID 物品放一格，stack 字段决定上限
- **信号（Signal）**：背包变化时通知 UI 刷新
- **序列化（Serialize）**：把内存数据转成 JSON 存档

**技术栈/代码**：
- `scripts/core/inventory_manager.gd`（Autoload 单例）
- `DataManager.get_item()` 查物品分类和 stack 上限
- `SaveManager.save/load` 走存档（get_save_data/load_save_data 接口）
- `MailManager.add_system_mail()` 满包时入邮件

**应用过程**：
1. 设计数据结构：`_important: Dictionary` + `_normal: Array`
2. 实现 `add(id, count)`：先查物品分类（important 走 Dict，其他走 Array 堆叠）
3. 实现 `remove/has/get_count/is_full` 4 个查询接口
4. 加 `signal inventory_changed` 通知 UI
5. 加 `get_save_data/load_save_data` 对接 SaveManager
6. 注册为 Autoload（`project.godot` 加一行）

---

## 概念

### 1. 生动形象例子（双抽屉文件柜）

把背包想象成一个文件柜，有两个抽屉：

| 抽屉 | 装什么 | 容量限制 | 类比 |
|------|--------|---------|------|
| 上抽屉（_important） | 重要文件（房产证/身份证） | 无限 | 每份文件一个标签，按标签找 |
| 下抽屉（_normal） | 日常物品（笔/纸/橡皮） | 30 格 | 每格装一类，可堆叠 |

**重要抽屉**用 Dictionary 实现：`{ "mark_solar_boss_01": 1, "pet_egg_01": 1 }`，加新物品就加一个 key，永远不"满"。

**普通抽屉**用 Array of Dictionary 实现：`[{ item_id:"potion_hp_small", count:30 }, { item_id:"material_leather_001", count:5 }]`，每个 Array 元素就是一格，最多 30 格。同 ID 物品优先堆叠到已有格子（不超 stack 上限），满了再开新格。

### 2. 本游戏实际应用例子

玩家击败红尾蝎，40% 概率掉落 `material_leather_001`（普通皮革，stack=99）：

```
怪物死亡 → drop_item("material_leather_001", 1)
  → InventoryManager.add("material_leather_001", 1)
    → DataManager.get_item("material_leather_001") 查到 category="material"
    → 不走 important 分支，走 normal 分支
    → stack_max = 99
    → for slot in _normal:
        if slot.item_id == "material_leather_001" and slot.count < 99:
          slot.count += 1 → 堆叠成功
    → emit_signal("inventory_changed") → UI 刷新
    → 返回 true
```

如果玩家背包已有 99 个皮革（堆满一格），且普通槽 30 格已用完，玩家再杀一只红尾蝎掉皮革：

```
add("material_leather_001", 1)
  → 找已有 slot 都满了（count=99）
  → 想开新格 → _normal.size() >= 30 → 满包
  → 返回 false
  → 调用方走"满包入邮件"分支：
    MailManager.add_system_mail(
      "背包已满：普通皮革",
      "你获得了 1 个普通皮革，但背包已满。请在 24 小时内领取附件。",
      {"item_id": "material_leather_001", "count": 1},
      24
    )
```

---

## 功能

1. **双容器分离**：重要物品无限制 + 普通物品 30 格
2. **自动堆叠**：同 ID 物品优先堆到已有格子
3. **满包返回 false**：调用方决定如何处理（入邮件/丢弃/拒绝）
4. **5 个查询接口**：add/remove/has/get_count/is_full
5. **信号通知 UI**：inventory_changed 信号
6. **存档对接**：get_save_data/load_save_data 给 SaveManager 调用

---

## 运作方式

### add 完整流程

```gdscript
func add(item_id, count=1) -> bool:
    var item = DataManager.get_item(item_id)
    if item.is_empty(): return false  # ID 无效

    if item.category == "important":
        _important[item_id] = _important.get(item_id, 0) + count
        emit_signal("inventory_changed")
        return true

    # 普通物品流程
    var stack_max = item.get("stack", 1)
    var remaining = count

    # 步骤 1: 先尝试堆叠到已有格子
    for slot in _normal:
        if slot.item_id == item_id and slot.count < stack_max:
            var can_add = min(stack_max - slot.count, remaining)
            slot.count += can_add
            remaining -= can_add
            if remaining <= 0:
                emit_signal("inventory_changed")
                return true

    # 步骤 2: 堆不下就开新格
    while remaining > 0:
        if _normal.size() >= NORMAL_SLOT_MAX:  # 满包
            emit_signal("inventory_changed")
            return false
        var can_add = min(stack_max, remaining)
        _normal.append({"item_id": item_id, "count": can_add})
        remaining -= can_add

    emit_signal("inventory_changed")
    return true
```

### remove 流程

```gdscript
# 从后往前删，避免删除时索引错乱
var i = _normal.size() - 1
while i >= 0 and remaining > 0:
    var slot = _normal[i]
    if slot.item_id == item_id:
        var take = min(slot.count, remaining)
        slot.count -= take
        remaining -= take
        if slot.count <= 0:
            _normal.remove_at(i)  # 格子空了就删
    i -= 1
```

### 存档对接

```gdscript
# 存档时调用：
var data = {
    "player": {...},
    "inventory": InventoryManager.get_save_data()
}
SaveManager.save("slot_1", data)

# 读档时调用：
var data = SaveManager.load("slot_1")
InventoryManager.load_save_data(data.inventory)
```

---

## 原理

### 1. 为什么用两种数据结构

| 数据结构 | 适合装什么 | 为什么 |
|---------|----------|--------|
| Dictionary | 重要物品 | 无限容量，key 就是 item_id，O(1) 查找 |
| Array | 普通物品 | 有格限制，需要保持"槽位"概念，UI 显示格子顺序 |

如果都用 Array：
- 重要物品查询要遍历，性能差
- 重要物品"无限容量"和 Array 的"格"概念冲突

如果都用 Dictionary：
- 普通物品的"30 格"无法表达
- UI 显示时无法保持顺序

### 2. 堆叠机制原理

stack 字段决定每格最多放多少。例：
- 药水 stack=99 → 一格最多 99 个
- 食物 stack=30 → 一格最多 30 个
- 装备 stack=1（默认）→ 一格一个

加 100 个药水：
- 先堆到已有药水格（如果存在且 < 99）
- 堆满后开新格（99 个）
- 剩 1 个再开新格（1 个）
- 共占 2 格

### 3. 满包返回 false 而不是报错

设计选择：add 返回 bool 而非 push_error。理由：
- 满包是正常游戏状态（玩家该清理背包了），不是 bug
- 调用方需要知道是否成功，自行决定后续逻辑（入邮件/弹提示/拒绝发放）
- 符合 §1.1 逻辑与显示分离：InventoryManager 不弹 UI，只返回结果

### 4. signal 通知机制

```gdscript
signal inventory_changed

# 数据变化时：
emit_signal("inventory_changed")

# UI 监听：
func _ready():
    InventoryManager.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed():
    refresh_ui()  # 重新渲染背包格子
```

观察者模式：背包不直接调 UI，UI 自己监听。这是 §1.1 逻辑与显示分离的体现。

---

## 优势

1. **加新物品无需改 InventoryManager**：物品分类和 stack 在 JSON， DataManager 读取后自动适配
2. **存档简洁**：序列化只需 `_important.duplicate(true)` + `_normal.duplicate(true)`
3. **重要物品不丢**：用 Dict 存储，无限容量，玩家不会因满包而错失剧情道具
4. **满包机制灵活**：返回 false 让调用方决定处理方式（任务奖励无视 / 普通奖励入邮件）
5. **信号驱动 UI**：背包变化时自动刷新，不需要手动调用 refresh

---

## 使用场景

### 当前对接

| 调用方 | 接口 | 用途 |
|--------|------|------|
| 怪物掉落 | `add(item_id, count)` | 掉落物入包 |
| NPC 商店购买 | `add(item_id, count)` + `remove(coin_id, price)` | 交易 |
| 任务奖励 | `add(item_id, count)` 检查返回值 | 失败入邮件 |
| 烹饪产出 | `add(food_id, 1)` + `remove(material_id, n)` | 副职业 |
| 装备穿戴 | `has(item_id, 1)` 验证 → `remove(item_id, 1)` | EquipmentManager 调用 |
| UI 背包面板 | 监听 `inventory_changed` 信号 + 读 `get_normal_items()` | 显示 |
| SaveManager | `get_save_data()` / `load_save_data()` | 存读档 |

### 满包入邮件代码模板

```gdscript
func give_reward(item_id: String, count: int) -> void:
    if not InventoryManager.add(item_id, count):
        # 满包，入邮件
        MailManager.add_system_mail(
            "背包已满：%s" % DataManager.get_item(item_id).name,
            "你获得了 %d 个%s，但背包已满。请 24 小时内领取附件。" % [count, DataManager.get_item(item_id).name],
            {"item_id": item_id, "count": count},
            24
        )
    # 重要物品越过容量检查（已在 add 内部处理，永远返回 true）
```

### 未来扩展（联机版）

- 服务器权威：客户端调 add → 请求服务器 → 服务器验证后下发结果
- 接口不变（§0.5 第三问：升级地基不改）
- 加交易系统时复用 add/remove 接口

---

## 反例 vs 正例对照

| 反例（违规） | 正例（合规） |
|------|------|
| 所有物品塞一个 Array，无分类 | 重要物品 Dict + 普通物品 Array 双结构 |
| 加物品时直接改 UI 代码 | emit_signal 通知 UI，UI 自己监听 |
| 满包时 push_error 当 bug 处理 | 返回 false 让调用方决定处理方式 |
| 背包数据写死在脚本里 | 全部从 DataManager 查 |
| 存档时直接存 _important 字段 | 走 get_save_data 接口，封装内部结构 |

---

## 关联

- 物品数据怎么查：[[49-物品体系与数据驱动]]
- Autoload 单例原理：[[06-单例模式与Autoload]]
- 信号机制详解：[[29-Signal信号机制]]
- 存档统一接口：[[05-存档统一接口原理]]
- 满包入邮件：[[13-音效与音乐资源处理]]（待补邮件系统专题）
- 接下来 [[51-EquipmentManager装备耐久]] 会用本笔记的接口
