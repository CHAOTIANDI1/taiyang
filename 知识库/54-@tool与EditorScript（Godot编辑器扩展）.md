# 54 - @tool 与 EditorScript（Godot 编辑器扩展）

> 本笔记解释"为什么巡检脚本能挂在 Godot 编辑器上跑"。上接 [[53-知识库AI-RAG5层升级方案]]，是 AI-RAG 第 3/5 层工具脚本的技术基础。
> 用户第一次见到 @tool 和 EditorScript 这两个词，是在问"升级知识库怎么能和 Godot 编辑器挂钩"时。

---

## 本游戏实例（v2.7 强制段）

**遇到的问题**：
Phase 4.5 完成 + 知识库 AI-RAG 5 层方案落地后，用户问"升级知识库怎么能和 Godot 编辑器运行挂钩？这是什么原理？"——用户是零基础，第一次见 @tool 和 EditorScript 这两个 Godot 高级特性，无法理解"为什么巡检脚本要在 Godot 编辑器里跑"。这暴露出 53 号笔记只写了"工具脚本挂在 Godot 编辑器"但没解释"为什么能挂、怎么挂"。

**专业名词/知识点**：
- **@tool 注解**：写在 extends 行上方，告诉 Godot"这个脚本在编辑器开着时也能运行，不必等游戏启动"
- **EditorScript 类**：Godot 提供的基类，继承它的脚本可以挂在"文件 → 运行"菜单上，点一下就跑
- **编辑器扩展（Editor Extension）**：通过 GDScript 给 Godot 编辑器加新功能的统称，@tool 和 EditorScript 是其中两种最简单的方式
- **GDScript 两种运行模式**：①游戏运行时（按 F5 启动游戏后跑）②编辑器内（开着 Godot 编辑器就能跑，不必启动游戏）

**技术栈/代码**：
- `scripts/tools/kb_inspector.gd`（第 3 层巡检脚本，@tool + EditorScript）
- `scripts/tools/sync_advisor.gd`（第 5 层同步脚本，@tool + EditorScript）
- 关键代码片段：
  ```gdscript
  @tool
  extends EditorScript
  
  static func _run() -> void:
      # 这个函数会被 Godot 编辑器调用
      var report: String = _build_report()
      _print_report(report)
      _save_report(report)
  ```
- Godot 编辑器菜单：文件 → 运行（File → Run）或快捷键

**应用过程**：
1. 知识库 AI-RAG 5 层方案确定第 3/5 层要做"自动巡检"和"项目同步"
2. 设计选择：用什么语言写巡检脚本？
   - 方案 A：GDScript + @tool + EditorScript（和项目同语言）✅ 选这个
   - 方案 B：PowerShell（Windows 原生但字符串处理弱）
   - 方案 C：Python（要装 Python）
   - 方案 D：AI 现场读笔记（每次慢）
3. 选方案 A 的核心理由：项目栈就是 GDScript，不增加新依赖
4. 实现：在 kb_inspector.gd 顶部加 `@tool` + `extends EditorScript` + `_run()` 函数
5. 用户使用方式：打开 Godot 编辑器 → 文件菜单 → 运行 → 选 kb_inspector.gd → 看控制台输出

---

## 概念

### 1. 生动形象例子（工作台与机器人助手）

把 Godot 编辑器想象成您的**工作台**——您做游戏的地方。普通 GDScript 脚本（比如 player.gd）是"游戏里的演员"，只有按 F5 启动游戏后，演员才开始表演。

但有些活儿您不想为了做它就启动整个游戏——比如：
- 扫一遍知识库的 53 篇笔记，看有没有断链
- 看看哪些代码改了但笔记没跟着改

这些活儿是"工作台上的杂活"，不需要启动游戏。**@tool + EditorScript 就是让脚本变成"工作台上的机器人助手"**——您坐在工作台前（开着 Godot 编辑器），按一下菜单，机器人就开始干活，干完报告给您。

| 角色 | 类比 | 实际 |
|------|------|------|
| 工作台 | Godot 编辑器 | 您写代码的地方 |
| 演员 | 普通 .gd 脚本 | player.gd / monster.gd，启动游戏后跑 |
| 机器人助手 | @tool + EditorScript 脚本 | kb_inspector.gd，编辑器菜单点一下就跑 |
| 杂活 | 不需要启动游戏的工作 | 巡检笔记 / 检查同步 / 批量重命名 |

### 2. 本游戏实际应用例子

我们的 `kb_inspector.gd` 就是这样一个机器人助手。它的工作流程：

```
您打开 Godot 编辑器（不必启动游戏）
  ↓
点菜单：文件 → 运行 → 选 kb_inspector.gd
  ↓
Godot 看到 @tool + extends EditorScript
  ↓
Godot 找到 _run() 函数自动调用
  ↓
_run() 内部：
  - _list_note_files() 列出所有 .md 文件
  - _check_broken_links() 扫断链
  - _check_duplicate_concepts() 找重复概念
  - _check_outdated() 查 30 天没动的笔记
  - _check_v27_compliance() 查 v2.7 准则符合度
  ↓
生成报告 → 控制台打印 + 保存到 知识库/.ai-reports/巡检-时间戳.md
  ↓
您看报告 → 决定是否走闸门 C 修复
```

关键点：**整个过程 Godot 编辑器都不需要按 F5 启动游戏**。这就是 @tool 的作用。

---

## 功能

### @tool 的 3 个功能

1. **让脚本在编辑器内执行**：普通的 `extends Node` 脚本只在游戏运行时跑，加 `@tool` 后编辑器开着时也能跑
2. **让节点的属性实时反映在编辑器**：比如改一个变量值，编辑器界面立刻看到变化（不是 MVP 必须的，但高级用法）
3. **配合 EditorScript 实现菜单运行**：这是本项目用到的核心功能

### EditorScript 的 2 个功能

1. **提供 `_run()` 入口函数**：Godot 编辑器菜单点"运行"时，会自动调用这个函数
2. **挂在编辑器菜单上**：File → Run 菜单能看到所有继承 EditorScript 的脚本

### 两者配合的完整功能

```
@tool              ← 告诉 Godot"我能在编辑器内跑"
extends EditorScript  ← 告诉 Godot"我是编辑器脚本，挂菜单上"

static func _run() -> void:
    # 这里写要干的活儿
    pass
```

只需这 3 行声明，脚本就变成"Godot 编辑器菜单里点一下就运行"的工具。

---

## 运作方式（含具体例子）

### 例子 1：kb_inspector.gd 的开头

```gdscript
@tool
extends EditorScript

const KB_ROOT: String = "res://知识库/"
const REPORT_DIR: String = "res://知识库/.ai-reports/"
const OUTDATED_DAYS: int = 30

static func _run() -> void:
    var report: String = _build_report()
    _print_report(report)
    _save_report(report)
```

逐行解释：

| 行 | 作用 |
|----|------|
| `@tool` | 注解（annotation），以 @ 开头，给 Godot 一个额外指令"这个脚本编辑器内可跑" |
| `extends EditorScript` | 继承 Godot 内置类 EditorScript，让脚本获得"挂菜单"能力 |
| `const KB_ROOT` | 定义常量，知识库根目录。`res://` 是 Godot 资源协议，等于项目根目录 |
| `static func _run()` | 静态函数，Godot 编辑器点"运行"时自动找到并调用它 |

### 例子 2：如何在 Godot 编辑器内运行

**步骤**：
1. 打开 Godot 编辑器，加载项目
2. 在文件浏览器找到 `scripts/tools/kb_inspector.gd`
3. **方式 A**：右键脚本 → Run（运行）
4. **方式 B**：打开脚本 → 文件菜单 → Run
5. 看"输出"面板（底部 Output 标签）的打印内容
6. 报告会保存到 `知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md`

**注意**：不需要按 F5 启动游戏。这是 @tool + EditorScript 与普通脚本最大的区别。

### 例子 3：res:// 协议是什么

```gdscript
const KB_ROOT: String = "res://知识库/"
```

`res://` 是 Godot 的资源路径协议——指向项目根目录。

| 写法 | 含义 |
|------|------|
| `res://知识库/` | 项目根目录下的"知识库"文件夹（D:\taiyang\知识库\） |
| `res://scripts/` | 项目根目录下的"scripts"文件夹 |
| `D:\taiyang\知识库\` | 绝对路径，但换电脑就失效 |

**用 res:// 的好处**：换电脑、换系统（Windows → Mac），路径都不用改。

---

## 原理

### 1. GDScript 的两种运行模式

| 模式 | 触发方式 | 脚本要求 | 例子 |
|------|---------|---------|------|
| 游戏运行时 | 按 F5 启动游戏 | 普通 extends Node | player.gd / monster.gd |
| 编辑器内 | 编辑器菜单点运行 | @tool + extends EditorScript | kb_inspector.gd |

### 2. @tool 注解的作用机制

Godot 加载脚本时，会扫描文件顶部的注解：
- 看到 `@tool` → 把脚本标记为"编辑器可执行"
- 没看到 `@tool` → 只在游戏运行时加载

**安全限制**：@tool 脚本不能随意访问游戏节点（因为游戏还没启动），只能访问编辑器内的资源和文件系统。

### 3. EditorScript 的继承链

```
Object
  └─ RefCounted
       └─ EditorScript  ← 我们继承这个
            └─ kb_inspector.gd  ← 我们的脚本
```

EditorScript 是 Godot 内置类，专门为"编辑器一次性脚本"设计。继承它后：
- 自动获得 `_run()` 入口（Godot 编辑器调用）
- 自动出现在"文件 → 运行"菜单
- 不需要挂到场景节点上（不像普通 Node 脚本）

---

## 优势

### 1. 不增加新依赖（核心优势）

如果用 Python 写巡检脚本，需要：
- 装 Python 环境（一次性成本，但要装）
- 项目栈从"纯 GDScript"变成"GDScript + Python"
- 跨电脑迁移时要确认 Python 也装了

用 GDScript + @tool + EditorScript：
- Godot 编辑器本身就是 GDScript 运行环境，不用装任何东西
- 项目栈保持纯 GDScript
- 跨电脑迁移只要复制项目 + 装 Godot

### 2. 能读 res:// 资源协议

Godot 把所有资源都按 `res://` 协议管理，包括 .md 文件。用 GDScript 写脚本可以直接用 res:// 路径访问，不用关心绝对路径（D:\taiyang\...）。

### 3. 一次写多次用

写完 kb_inspector.gd 后，任何时候想巡检，打开 Godot → 点菜单 → 看报告。不用每次手动翻 53 篇笔记。

### 4. 和项目代码同语言

巡检脚本用 GDScript 写，您看代码不需要切换语言上下文。如果用 Python，您要看代码得切换到 Python 思维，看完再切回 GDScript——增加认知负担。

---

## 使用场景（含对接）

### 场景 1：知识库 AI-RAG 第 3 层巡检

**对接**：`kb_inspector.gd` 扫描 `res://知识库/` 下所有 .md 文件，报告归档到 `res://知识库/.ai-reports/`。

**触发时机**（AGENTS.md §20.4）：
- 每次会话开始
- 用户主动喊"巡检"
- 里程碑完成

### 场景 2：知识库 AI-RAG 第 5 层同步检查

**对接**：`sync_advisor.gd` 扫描 `res://scripts/` + `res://data/` + `res://docs/` + `res://知识库/` 的文件修改时间，找出"代码改了但笔记没改"的情况。

**触发时机**（AGENTS.md §20.6）：
- 每次 git commit 后
- 用户主动喊"同步检查"

### 场景 3：未来扩展（非 MVP）

@tool + EditorScript 的能力远不止巡检知识库，未来可以做：
- **数据校验工具**：检查 data/*.json 字段是否齐全、类型是否正确
- **批量重命名工具**：把 50 个 .tscn 文件按规则重命名
- **资源统计工具**：统计 assets/ 下各类资源数量、大小
- **场景依赖图**：自动生成场景之间的依赖关系图

这些都是"工作台上的杂活"，用 @tool + EditorScript 都能轻松实现。

---

## 反例 vs 正例

### 反例 1：用 Python 写巡检脚本

```python
# ❌ kb_inspector.py
import os
import re

KB_ROOT = "D:/taiyang/知识库/"
# 要装 Python 才能跑
# 跨电脑迁移要重新装 Python
# 路径写死，换电脑可能失效
```

**问题**：
- 项目栈从纯 GDScript 变成 GDScript + Python
- 用户要装 Python（零基础用户装环境是大门槛）
- 绝对路径在换电脑后失效

### 正例 1：用 GDScript + @tool + EditorScript

```gdscript
# ✅ kb_inspector.gd
@tool
extends EditorScript

const KB_ROOT: String = "res://知识库/"
# 不用装任何东西，Godot 编辑器就是运行环境
# res:// 协议跨电脑通用
# 和项目同语言
```

### 反例 2：用 AI 现场读笔记生成报告

```
❌ 用户喊"巡检" → AI 现场读 53 篇笔记 → AI 生成报告
```

**问题**：
- 每次 AI 都要重读 53 篇笔记，慢
- AI 上下文被笔记占满，影响后续对话
- 没有归档，下次巡检又得重来

### 正例 2：脚本巡检 + AI 看报告

```
✅ 用户喊"巡检" → 跑 kb_inspector.gd 生成报告
   → AI 只看报告（不用读全部笔记）
   → AI 根据报告决定走闸门 C 修复
```

**优势**：
- 脚本跑得快（几秒）
- AI 只看报告（节省上下文）
- 报告归档可追溯（下次能对比）

### 反例 3：硬编码 @tool 但不继承 EditorScript

```gdscript
# ❌ 只加 @tool 不继承 EditorScript
@tool
extends Node

func _ready() -> void:
    # 这个函数只在挂到场景节点 + 启动游戏后跑
    # 不能从编辑器菜单直接运行
    pass
```

**问题**：
- @tool 只是让脚本能在编辑器内执行，但不提供"菜单运行"入口
- 必须挂到场景节点上才能跑，不如 EditorScript 方便

### 正例 3：@tool + EditorScript 配合

```gdscript
# ✅ 两者配合
@tool
extends EditorScript

static func _run() -> void:
    # 编辑器菜单点"运行"就直接跑，不用挂节点
    pass
```

---

## 关联

- [[53-知识库AI-RAG5层升级方案]] —— 本笔记的上级，讲 5 层方案总览
- [[02-技术栈与工具全景]] —— 项目整体技术栈，本笔记的 GDScript 是其中之一
- [[01-文件格式名词]] —— .gd 文件格式说明
- [[03-数据驱动架构与JSON工作原理]] —— 数据驱动理念，巡检脚本也是数据驱动（读 .md 文件）
- [[49-物品体系与数据驱动]] —— 同一时期的 Phase 4.5 成果
- [[30-碰撞层与碰撞遮罩]] —— 另一个 Godot 高级特性（碰撞层）的笔记

---

> 最后更新：2026-07-20
> 写作触发：用户问"升级知识库怎么能和 Godot 编辑器运行挂钩？这是什么原理？"
> 闸门 B 第 9 问"小白学习视角检查"：识别出 @tool / EditorScript / 编辑器扩展 / res:// 协议是用户第一次见的新概念，必须补知识库。
