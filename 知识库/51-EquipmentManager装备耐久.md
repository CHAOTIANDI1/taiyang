# 51 - EquipmentManager 装备耐久

> 本笔记解释装备槽位管理、耐久度系统、封禁机制、跨系统协作（InventoryManager + DataManager + 玩家攻击）。
> 上接 [[50-InventoryManager容器逻辑]]，下接 [[52-满包入邮件与怪物掉落与InventoryUI]]。

---

## 本游戏实例（v2.7 强制段）

**遇到的问题**：
Phase 4.5 子任务 3：玩家装备武器后需要：
- 武器/护甲各有独立槽位
- 每次攻击消耗 1 点武器耐久
- 耐久归零时属性封禁（attack=0）但普通攻击仍可用（docs/06-物品体系.md 规则）
- 装备永不永久损坏（耐久归零不消失，NPC 铁匠可修复）
- 装备和卸下要和 InventoryManager 联动（从包里取出/放回）

**专业名词/知识点**：
- **装备槽（Equipment Slot）**：固定位置的容器，玩家有 weapon 和 armor 两个槽
- **耐久度（Durability）**：装备的使用寿命，每次攻击/受击消耗
- **封禁（Sealed）**：耐久归零时装备属性失效但装备本身不消失
- **跨系统协作**：EquipmentManager + InventoryManager + DataManager 三方联动
- **修复（Repair）**：把耐久恢复到 durability_max

**技术栈/代码**：
- `scripts/core/equipment_manager.gd`（Autoload 单例）
- `data/equipment.json`（`durability_max` / `attack` / `defense` / `repair_cost_base`）
- `scripts/player/player.gd` 命中后调 `EquipmentManager.consume_durability("weapon", 1)`
- `InventoryManager.add/remove` 装备穿戴卸下时调用

**应用过程**：
1. 设计数据结构：`_weapon` + `_armor` 两个 Dictionary，存 `{item_id, durability}`
2. 实现 `equip(item_id)`：查物品分类 → 槽位已有装备先卸下 → 从背包移除 → 装上并初始化耐久
3. 实现 `unequip(slot)`：装备回背包（满包则失败）
4. 实现 `consume_durability(slot, amount)`：减耐久，归零时打印封禁日志
5. 实现 `repair(slot)`：恢复到 durability_max（NPC 铁匠调用）
6. 实现 `is_sealed/get_attack_bonus/get_defense_bonus` 查询接口
7. 在 player.gd `_check_hit()` 命中后调用 `consume_durability("weapon", 1)`

---

## 概念

### 1. 生动形象例子（工具箱的两个挂钩）

把装备管家想象成一个工具箱，内壁有两个挂钩：

| 挂钩 | 挂什么 | 类比 |
|------|--------|------|
| 武器钩 | 一把剑/斧/弓 | 你手里现在拿的 |
| 护甲钩 | 一件衣服/皮甲/板甲 | 你身上现在穿的 |

挂钩只能挂一件，换装备时：
1. 把旧装备取下放回背包
2. 从背包拿新装备挂上

每件装备有"耐久度"——就像菜刀的锋利度：
- 砍 1 次消耗 1 点锋利度
- 锋利度归零时菜刀变钝（attack=0）但还能用来砍（普通攻击仍可用）
- 找磨刀师傅磨一下（NPC 铁匠修复）→ 锋利度恢复
- 菜刀永远不会断掉消失（永不永久损坏）

### 2. 本游戏实际应用例子

玩家在新手村买了一把 `sword_basic`（新手铁剑，durability_max=100），装备后开始打怪：

```
玩家点装备 → EquipmentManager.equip("sword_basic")
  → DataManager.get_item 查到 category="weapon"
  → InventoryManager.has("sword_basic", 1) → true
  → InventoryManager.remove("sword_basic", 1) → 从背包移除
  → 查 equipment.json → durability_max=100
  → _weapon = { item_id:"sword_basic", durability:100 }
  → emit_signal("equipment_changed")

玩家按 J 攻击红尾蝎命中 →
  player.gd._check_hit() 命中后调:
    EquipmentManager.consume_durability("weapon", 1)
      → _weapon.durability = 100 - 1 = 99
      → emit_signal("equipment_changed")

打了 100 次后（durability=0）：
  → _weapon.durability = 0
  → was_sealed = true
  → 打印 "[EquipmentManager] weapon 槽装备耐久归零，属性封禁"
  → 玩家继续按 J 仍能攻击（attack_damage=10 是 player.gd 自己的基础值）
  → 但 get_attack_bonus() 返回 0（装备加成失效）

找 NPC 铁匠修复（消耗金币）：
  → EquipmentManager.repair("weapon")
    → 查 equipment.json → durability_max=100
    → _weapon.durability = 100
    → emit_signal("equipment_changed")
    → 属性恢复
```

---

## 功能

1. **两槽位管理**：weapon + armor 各装一件
2. **装备穿戴联动**：equip 时从背包取，unequip 时回背包
3. **耐久度系统**：每次攻击消耗 1 点，归零时封禁
4. **封禁机制**：耐久==0 时 get_attack_bonus/get_defense_bonus 返回 0
5. **修复接口**：NPC 铁匠调用 repair(slot) 恢复耐久
6. **属性加成查询**：get_attack_bonus() / get_defense_bonus()
7. **存档对接**：get_save_data / load_save_data

---

## 运作方式

### equip 完整流程

```gdscript
func equip(item_id) -> bool:
    var item = DataManager.get_item(item_id)        # 查物品分类
    if item.is_empty(): return false
    if item.category not in ["weapon", "armor"]: return false
    if not InventoryManager.has(item_id, 1): return false  # 背包无此物
    var equip_data = DataManager.get_equipment(item_id)    # 查装备属性
    if equip_data.is_empty(): return false

    var slot = item.category  # "weapon" 或 "armor"

    # 步骤 1: 该槽已有装备先卸下回背包
    if get_slot_data(slot).size() > 0:
        var old_id = get_slot_data(slot).item_id
        _clear_slot(slot)
        InventoryManager.add(old_id, 1)

    # 步骤 2: 从背包移除新装备
    InventoryManager.remove(item_id, 1)

    # 步骤 3: 装上并初始化耐久
    var durability_max = equip_data.get("durability_max", 100)
    _set_slot(slot, item_id, durability_max)
    emit_signal("equipment_changed")
    return true
```

### 耐久消耗流程

```gdscript
# player.gd._check_hit() 命中后：
EquipmentManager.consume_durability("weapon", 1)

# EquipmentManager 内部：
func consume_durability(slot, amount=1):
    var slot_data = get_slot_data(slot)
    if slot_data.is_empty(): return
    slot_data.durability = max(0, slot_data.durability - amount)
    var was_sealed = slot_data.durability == 0
    emit_signal("equipment_changed")
    if was_sealed:
        print("[EquipmentManager] %s 槽装备耐久归零，属性封禁" % slot)
```

### 属性加成查询

```gdscript
func get_attack_bonus() -> int:
    if _weapon.is_empty(): return 0          # 没装武器
    if is_sealed("weapon"): return 0         # 武器封禁
    var equip = DataManager.get_equipment(_weapon.item_id)
    return equip.get("attack", 0)

# player.gd 计算总攻击力时：
var total_attack = attack_damage + EquipmentManager.get_attack_bonus()
```

---

## 原理

### 1. 为什么装备槽用独立 Dictionary 而不是 Array

| 方案 | 优点 | 缺点 |
|------|------|------|
| 两个 Dict（_weapon + _armor） | 类型固定，O(1) 查找 | 加新槽位要改代码 |
| 一个 Array of Dict | 加槽位灵活 | 查找要遍历 |

选了两个 Dict：
- §0.5 三问：MVP 阶段就 weapon/armor 两槽（够用）；加新槽（如戒指/项链）只需加一个变量（地基可扩展）；升级地基不改（接口不变）
- 性能更好：get_attack_bonus 直接读 _weapon.item_id，无需遍历

### 2. 封禁机制的设计权衡

docs/06 规定"耐久归零时普通攻击仍可用，但装备属性和附带技能全部封禁失效"。

实现方式：
- attack_damage（玩家基础攻击）= 10，写在 player.gd
- get_attack_bonus()（装备加成）= 10（sword_basic.attack），写在 equipment.json
- 总攻击 = 基础 + 加成 = 20
- 耐久归零时：get_attack_bonus() 返回 0，总攻击 = 10
- 玩家仍能打怪，只是伤害降级

**为什么不直接禁用攻击**：
- 违反 docs/06 设计规则
- 玩家陷入"卡死"状态（无法打怪赚修装备的钱）
- 设计意图：装备是"加成"不是"必需"

### 3. 跨系统协作（equip 流程）

```
玩家点击装备 → UI 调 EquipmentManager.equip(id)
  ↓
EquipmentManager 调 InventoryManager.has(id, 1)  ← 跨管家验证
  ↓
EquipmentManager 调 InventoryManager.remove(id, 1)  ← 跨管家扣物品
  ↓
EquipmentManager 调 DataManager.get_equipment(id)  ← 跨管家查数据
  ↓
EquipmentManager 写入 _weapon 槽  ← 自身状态
  ↓
EquipmentManager emit equipment_changed  ← 通知 UI
```

四个 Autoload 单例协作完成"装备穿戴"动作，每个管家只管自己的事，符合 §1.1 逻辑与显示分离。

### 4. 装备槽位是状态机

```
空槽 ──equip──> 已装备(durability=max)
                  │
                  ├──consume──> 已装备(durability--)
                  │                │
                  │                └──durability==0──> 已封禁(durability=0)
                  │                                      │
                  │                                      └──repair──> 已装备(durability=max)
                  │
                  └──unequip──> 空槽
```

repair 不改变装备 ID，只重置 durability。

---

## 优势

1. **数据驱动耐久**：durability_max 在 equipment.json，加新装备自动有耐久
2. **跨系统协作清晰**：equip 时 Inventory 扣物品，unequip 时 Inventory 加物品
3. **封禁机制安全**：玩家不会因装备坏掉卡死
4. **修复接口可扩展**：未来联机版加锻造师副职业时，repair_cost_base 字段已就位
5. **存档简洁**：只存两个 Dictionary，结构稳定

---

## 使用场景

### 当前对接（MVP）

| 调用方 | 接口 | 用途 |
|--------|------|------|
| 装备 UI | `equip(item_id)` | 点击装备按钮 |
| 装备 UI | `unequip(slot)` | 点击卸下按钮 |
| player.gd | `consume_durability("weapon", 1)` | 攻击命中后 |
| monster.gd | `consume_durability("armor", 1)` | 玩家受击后（可选）|
| NPC 铁匠 | `repair(slot)` | 修复服务 |
| 战斗系统 | `get_attack_bonus()` | 计算总攻击力 |
| 战斗系统 | `get_defense_bonus()` | 计算总防御力 |
| 装备 UI | 监听 `equipment_changed` | 刷新装备栏 |
| SaveManager | `get_save_data()` / `load_save_data()` | 存读档 |

### 未来扩展（联机版）

- 服务器权威：装备穿戴请求由服务器验证（避免客户端作弊改耐久）
- 接口不变（§0.5 第三问：升级地基不改）
- 加锻造师副职业时：
  - 玩家自己 repair 消耗材料（未来在 recipes.json 加修复配方）
  - repair_cost_base 字段已就位，做经济平衡

### 经济系统对接预留

equipment.json 每件装备有 `repair_cost_base` 字段：
- sword_basic: repair_cost_base=10
- armor_cloth: repair_cost_base=8

NPC 铁匠修复价 = repair_cost_base × (1 - durability / durability_max)
- 全坏修复：10 × 1 = 10 金币
- 半坏修复：10 × 0.5 = 5 金币

未来经济系统接入时直接读这个字段。

---

## 反例 vs 正例对照

| 反例（违规） | 正例（合规） |
|------|------|
| 耐久写死在 .gd：`if id=="sword": dur=100` | 走 equipment.json 的 durability_max |
| 装备归零直接 queue_free 装备 | 装备永不消失，只封禁属性 |
| equip 时不和 InventoryManager 联动 | equip 时 InventoryManager.remove，unequip 时 InventoryManager.add |
| 玩家攻击力直接写 player.gd | 基础值 + EquipmentManager.get_attack_bonus() |
| 耐久消耗在 UI 代码里调 | 在 player.gd 逻辑层 _check_hit 里调 |

---

## 关联

- 物品数据怎么查：[[49-物品体系与数据驱动]]
- 背包容器怎么实现：[[50-InventoryManager容器逻辑]]
- Autoload 单例原理：[[06-单例模式与Autoload]]
- 信号机制详解：[[29-Signal信号机制]]
- 跨系统协作类似：[[47-AttackAreaFactory与mask数据驱动]]（多管家协作）
- 接下来 [[52-满包入邮件与怪物掉落与InventoryUI]] 会在 UI 层调用本笔记的接口
