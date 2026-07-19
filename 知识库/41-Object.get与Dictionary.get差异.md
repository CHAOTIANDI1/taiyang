# 41 - Object.get 与 Dictionary.get 差异

## 本游戏实例（v2.7 准则）

- **遇到的问题**：
  - **Phase 4.4.6**：4.4.5 + 4.4.6 代码写完后 F5 运行失败，控制台报错：
    ```
    Parser Error: Too many arguments for "get()" call. Expected at most 1 but received 2.
    第 142 行：Too many arguments for "get()" call. Expected at most 1 but received 2.
    第 169 行：Too many arguments for "get()" call. Expected at most 1 but received 2.
    ```
  - 报错位置：monster.gd 第 142 行 `bool(player.get("_is_dying", false))` 和第 169 行 `bool(_target.get("_is_gentle_mode", true))`
  - 我写代码时把 `body.get("_is_dying", false)` 当成 Dictionary 写法用了，但 body 是 Node（Object 子类），Godot 4 的 Object.get() 只接受 1 个参数
- **专业名词/知识点**：`Object.get()` 单参数、`Dictionary.get()` 双参数（带默认值）、Godot 3 → Godot 4 语法差异、属性不存在时的返回值（null）、`in` 操作符检查属性、`has_method()` 判断节点类型、`bool(null) = false` 自动转换
- **技术栈/代码/美术**：GDScript 4 的 `Object.get(property: StringName) -> Variant`、`Dictionary.get(key, default)` 、`in` 操作符、`has_method()` 方法、monster.gd/pet.gd 4.4.6 修复代码
- **应用过程**：
  1. 4.4.6 写代码时用 `body.get("_is_dying", false)` 想"属性不存在时返回 false"
  2. F5 报错"Too many arguments for get() call"
  3. 走 §1.4 第 9 项报错三步流程：解释根因 → 修复 → 补知识库
  4. 根因：Godot 4 的 Object.get() 只接受 1 个参数（属性名），不带默认值参数
  5. 修复策略：
     - 对 `_is_dying`（默认 false）：直接 `bool(body.get("_is_dying"))`，因为属性不存在时 get() 返回 null，bool(null) = false，行为与"default false"一致
     - 对 `_is_gentle_mode`（默认 true）：用 `has_method("is_gentle_mode") and is_gentle_mode()` 方法替代属性访问
     - 对 `monster_id`（默认 ""）：用 `"monster_id" in body` 检查 + 直接访问
  6. 补本文知识库，记录 Godot 3 → 4 的语法差异和修复套路

---

## 概念

**`get()` 是同名但不同类的两个方法**：
- `Object.get(property)` —— 只接受 1 个参数（属性名）
- `Dictionary.get(key, default)` —— 接受 2 个参数（key + 找不到时的默认值）

**生活比喻 1（生动形象）**：两个同名同姓的"老王"，但工作不同：
- 老王 A（开小卖部）：你说"拿可乐"，他就给你可乐。你说"拿可乐，没了给我雪碧"，他听不懂——他只会"拿一样东西"
- 老王 B（开便利店）：你说"拿可乐，没了给我雪碧"，他听懂了——他能处理"找不到给替代品"

`Object.get()` 是老王 A，`Dictionary.get()` 是老王 B。同名 `get()`，但能力不同。

**生活比喻 2（本游戏应用）**：4.4.6 我想让怪物检查"宠物是不是在温和模式"：
- 我以为写 `_target.get("_is_gentle_mode", true)` 能"找不到属性就返回 true（默认温和）"
- 但 `_target` 是 Node（Object 子类），它的 `get()` 是老王 A，只会"拿一个属性"，听不懂"找不到给默认值"
- Godot 编译时检测到"你给了 2 个参数但我只收 1 个"，报错 `Too many arguments for "get()" call`
- 修复：用 `_target.has_method("is_gentle_mode") and _target.is_gentle_mode()` 改成"问会不会这个方法 + 调用方法"两步走

**反例 vs 正例**：
```
❌ 错误（Node 用 2 参数 get）：
body.get("_is_dying", false)       # Node 是 Object，2 参数报错
body.get("_is_gentle_mode", true)  # 同上

✅ 正确（Node 用单参数 get 或 in 操作符）：
body.get("_is_dying")              # 属性不存在返回 null，bool(null)=false
"_is_dying" in body                # 检查属性是否存在
body.has_method("is_gentle_mode")  # 用方法替代属性访问

✅ 正确（Dictionary 仍然能用 2 参数）：
data.get("hp", 50)                 # data 是 Dictionary，2 参数合法
data.get("name", "")               # 找不到 name 返回 ""
```

---

## 功能

- 区分 `Object.get()` 和 `Dictionary.get()` 的参数差异
- Godot 3 → Godot 4 语法迁移指南
- 属性不存在时的安全访问模式
- 用方法替代属性访问的判断方式

---

## 运作方式

### Godot 4 的 get() 两种签名

```gdscript
# Object.get() - 单参数
var value: Variant = node.get("property_name")
# 属性不存在时返回 null（不报错）
# 但不能传第二个参数作为默认值

# Dictionary.get() - 双参数（带默认值）
var value: Variant = dict.get("key", default_value)
# key 不存在时返回 default_value
# 第二个参数可省略，省略时返回 null
```

### 4.4.6 修复代码对照

**修复 1：`_is_dying` 属性（默认 false）**

```gdscript
# 旧（报错）：
bool(body.get("_is_dying", false))

# 新（合法）：
bool(body.get("_is_dying"))
# 解释：属性存在 → 返回 true/false；属性不存在 → 返回 null → bool(null) = false
# 行为与"default false"完全一致
```

**修复 2：`_is_gentle_mode` 属性（默认 true）**

```gdscript
# 旧（报错）：
bool(_target.get("_is_gentle_mode", true))

# 新（合法）：
_target.has_method("is_gentle_mode") and _target.is_gentle_mode()
# 解释：先问"会不会 is_gentle_mode 方法"，再调用
# 如果 _target 是 Player（没这个方法）→ has_method 返回 false → 短路 false
# 如果 _target 是 Pet 温和模式 → has_method=true, is_gentle_mode()=true → 整体 true
# 如果 _target 是 Pet 战斗模式 → has_method=true, is_gentle_mode()=false → 整体 false
```

**修复 3：`monster_id` 属性（默认空字符串）**

```gdscript
# 旧（报错）：
String(body.get("monster_id", ""))

# 新（合法）：
String(body.monster_id) if "monster_id" in body else ""
# 解释：用 in 操作符检查属性是否存在，存在则直接访问，不存在则给 ""
# 为什么不直接 String(body.get("monster_id"))？
# 因为 String(null) = "null"（字符串），不是 "" 空字符串
```

### 代码逐行执行流程

**场景：怪物检查玩家是否死亡**

```
monster.gd 第 143 行：
if player != null and is_instance_valid(player) and not bool(player.get("_is_dying")):

执行：
1. player != null → true（玩家节点存在）
2. is_instance_valid(player) → true（玩家未被释放）
3. player.get("_is_dying")
   - player 是 Player 节点（Object 子类）
   - 调用 Object.get("_is_dying")（单参数版）
   - 如果 Player 有 _is_dying 属性 → 返回属性值
   - 如果 Player 没 _is_dying 属性 → 返回 null
4. bool(返回值)
   - true → bool(true) = true → not true = false → 不进入 if 块（玩家活着）
   - false → bool(false) = false → not false = true → 进入 if 块（玩家死了）
   - null → bool(null) = false → not false = true → 进入 if 块（属性不存在视为"死了"）
```

### 三种安全访问模式对比表

| 模式 | 写法 | 适用场景 | 默认值处理 |
|------|------|---------|----------|
| Object.get() 单参数 | `body.get("_is_dying")` | 默认值是 false/null/0 时 | 返回 null，bool/null 自动转 false |
| in 操作符 + 直接访问 | `"prop" in body and body.prop` | 默认值是 false 时 | `in` 返回 false，短路 false |
| has_method + 方法调用 | `body.has_method("m") and body.m()` | 默认值是 false 时 | has_method 返回 false，短路 false |
| in 操作符 + 条件表达式 | `"prop" in body ? body.prop : default` | 任意默认值 | 条件表达式显式给默认值 |

---

## 原理

### 为什么 Godot 4 改了 Object.get() 的签名？

Godot 3 的 `Object.get(property, default)` 设计有问题：
- 默认值参数让 API 看起来像 Dictionary，但实际行为不同
- Object.get 找不到属性时会触发 `_get()` 虚函数，可能有副作用
- 默认值参数让代码看起来"安全"，实际可能掩盖 bug（属性名拼错了不报错）

Godot 4 简化为 `Object.get(property)`：
- 找不到属性返回 null（不触发 `_get()` 虚函数）
- 强制开发者用 `in` 或 `has_method()` 显式检查
- API 更清晰：Object.get 只查属性，Dictionary.get 才有默认值

### 为什么 Dictionary.get() 还保留双参数？

Dictionary 是数据容器，"找不到 key 给默认值"是核心需求（数据驱动架构常用）。Object 是节点，属性是类定义的，不该有"找不到属性"的情况——如果有，说明代码有 bug（拼错属性名）。

### bool(null) 为什么等于 false？

GDScript 类型转换规则：
- `bool(null)` = false
- `bool(0)` = false
- `bool(0.0)` = false
- `bool("")` = false
- `bool([])` = false
- `bool({})` = false
- 其他都是 true

所以 `bool(body.get("_is_dying"))` 在属性不存在时返回 null，bool(null) = false，正好符合"默认 false"的需求。

### 为什么 String(null) 不是 ""？

GDScript 的 String() 转换规则把 null 转成字符串 `"null"`，不是空字符串。这与 bool() 的" falsy 转换"不同。所以 `String(body.get("monster_id"))` 在属性不存在时会得到 `"null"` 字符串，需要用 `in` 操作符显式处理。

---

## 优势

| 优势 | 说明 |
|------|------|
| API 清晰 | Object.get 查属性，Dictionary.get 有默认值，职责分明 |
| 防拼错 | 属性名拼错时强制报错（Godot 3 默认值掩盖 bug） |
| 类型安全 | 显式用 in/has_method 检查，意图更清晰 |
| 兼容性 | 修复后代码 Godot 3 和 4 都能跑（Godot 4 用单参数，Godot 3 也支持单参数） |

---

## 使用场景

### 场景 1：访问节点属性（默认 false/null/0 时）

```gdscript
# 推荐：单参数 get
if bool(body.get("_is_dying")):  # 属性存在且为 true → true；其他 → false
    return
```

### 场景 2：访问节点属性（默认 true 时）

```gdscript
# 推荐：has_method + 方法调用
if body.has_method("is_gentle_mode") and body.is_gentle_mode():
    # 是宠物且在温和模式
    pass
```

### 场景 3：访问节点属性（任意默认值时）

```gdscript
# 推荐：in 操作符 + 条件表达式
var monster_id: String = String(body.monster_id) if "monster_id" in body else ""
```

### 场景 4：访问 Dictionary 字段（任意默认值）

```gdscript
# 推荐：双参数 get（Dictionary 合法）
var hp: int = int(data.get("hp", 50))  # data 是 Dictionary
```

### 场景 5：判断节点类型

```gdscript
# 推荐：has_method 判断（不用 is 关键字，因为 Player/Pet/Monster 都是 CharacterBody2D）
if body.has_method("take_damage"):
    # 是 Player/Pet/Monster 之一
    pass
if body.has_method("is_gentle_mode"):
    # 是 Pet
    pass
```

### 与其他系统对接

- **DataManager**：`DataManager.get_monster(id)` 返回 Dictionary，可以用 `data.get("hp", 50)` 双参数
- **节点属性访问**：`player.get("_is_dying")` 单参数
- **方法判断**：`body.has_method("take_damage")` 区分玩家/宠物/怪物和其他节点

---

## 关联

- 报错三步流程（解释根因/修复/补知识库）：[[12-AGENTS宪法治理逻辑]]
- GDScript 类型系统（Variant/bool/null 转换）：[[22-GDScript类型推断与Variant报错]]
- has_method 判断节点类型：[[39-仇恨机制与温和模式]]
- Area2D 命中后调用 take_damage：[[38-攻击范围与DamageArea概念]]
- 三项一致原则（修复后 docs/数据/代码同步）：[[08-三项一致原则]]
- 闸门 B 第 9 问小白视角检查（本次报错触发的知识库补全）：[[23-规则执行滑坡与3道防坡闸门]]
