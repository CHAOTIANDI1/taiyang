# 22 - GDScript 类型推断与 Variant 报错（小白讲清楚版）

## 概念

**类型推断** = 你写代码时用 `:=` 让编译器自己猜类型。GDScript 4.7 严格——遇到从 Dictionary/Array 取出的值（Variant 万能类型）时**猜不出来就报错**，要你必须显式声明类型。

## 功能

防止"我以为它是字典其实它是字符串"这类 Bug。GDScript 4.7 启用了**严格类型检查**——好处是安全，代价是小白踩坑多。

## 运作方式（含报错例子）

### 报错原文

```
Parser Error: Cannot infer the type of "cur_day" variable because
the value doesn't have a set type.
```

翻译：`无法推断 cur_day 变量的类型，因为这个值没有设定类型`

### 出错代码

```gdscript
var t := get_elapsed_time_dict()        # t 是 Variant（Dictionary 但编译器看不懂）
var cur_day := START_SOLAR_DAY + t.days # t.days 是 Variant → 推断失败
```

生活类比：
- 你跟商家说"我要买 **那个东西**"——商家问"是哪个？苹果还是梨？"你答不上来，他就报错。
- `t.days` 在编译器眼里就像"那个东西"——它能是任何东西，编译器不敢猜。

### 修复代码

```gdscript
var t: Dictionary = get_elapsed_time_dict()                # 明确说 t 是 Dictionary
var cur_day: int = START_SOLAR_DAY + int(t.get("days", 0)) # 明确说 cur_day 是 int
```

生活类比：
- 你说"我要买 **红富士苹果 3 个**"——商家立刻懂。
- 跟 Dictionary 索取值时用 `int(...)` 或 `String(...)` 转换，等于跟"我要 X 类型的"明确指定。

## 原理

**`:=` 是"自动推断"语法糖**，编译器看到右边表达式后猜左边变量是什么类型。但是：
- **Dictionary.get(键, 默认值)** 返回的是 `Variant`——可以是任何类型
- 编译器从 Variant 推不出具体类型，就放弃推断，给你报错

### 4 种情况会触发同样报错

| 情况 | 报错示例 |
|-----|---------|
| 从 Dictionary 取值用 := | `var x := my_dict.get("key", 0)` ❌ |
| 从 Array 取值用 := | `var x := my_array[0]` ❌ |
| 从函数返回 Variant 用 := | `var x := some_func()`（当 func 没声明返回类型） |
| 用 % 或 / 混算 Variant | `var x := dict.a + 5` ❌ |

### 4 种解法

| 错误 | 修复 |
|------|------|
| `var x := dict.get(...)` | `var x: int = int(dict.get("k", 0))` |
| `var x := arr[0]` | `var x: String = arr[0]` |
| `var x := dict.value` | `var x: int = int(dict.value)` |
| `var x := func()` 无类型 | `var x: int = func()` 或函数声明 `-> int` |

## 优势

| 优势 | 说明 |
|------|------|
| 强类型防 Bug | 把"运行时炸"变成"编译时报错" |
| 自动补全更好 | 类型清楚后 IDE 能给建议 |
| 性能略好 | 引擎不用运行时猜类型 |

## 使用场景

### 场景 1: 你看到 "Cannot infer the type of X"

**立刻知道**：这是 `:=` 配合 Variant 了，找到那行，改成显式类型。

### 场景 2: 你写新脚本

**通用规矩**：
- 从 Dictionary 取值 → 用 `int(...)`/`String(...)`/`Dictionary(...)` 转换
- 从 Array 取值 → 显式声明类型 `var x: String = arr[0]`
- 从 varid 函数取值 → 显式声明

### 场景 3: 防御性写法（今后我会默认这么写）

```gdscript
# 安全写法
var d: Dictionary = {...}
var name: String = d.get("name", "")
var age: int = int(d.get("age", 0))
var arr: Array = d.get("items", [])

# 危险写法（4.7 会报错）
var d := {...}
var name := d.get("name")  # ❌
```

## 单例中常见应用

我们 6 个单例里大量用 `Dictionary.get()`，全部按这个规矩写：

```gdscript
# ✅ data_manager.gd
func get_monster(id: String) -> Dictionary:
	var data: Dictionary = _cache.get("monsters", {}).get("_data", {})
	return data.get(id, {})
```

注意 `get("_data", {})` 也返回 Variant，所以用 `var data: Dictionary` 显式声明。

---

## 关联

- 6 个单例长什么样：[[06-单例模式与Autoload]]
- 数据怎么从 JSON 给到代码：[[03-数据驱动架构与JSON工作原理]]
- 出错时为什么必须补知识库：[[09-合规巡检机制]]