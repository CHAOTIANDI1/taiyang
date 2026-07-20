# 54 - Python 工具脚本基础（命令行运行）

> 本笔记解释"为什么知识库工具用 Python 写，怎么运行"。上接 [[53-知识库AI-RAG5层升级方案]]，是 AI-RAG 第 3/5 层工具脚本的技术基础。
> 用户第一次见 Python 工具脚本是在 v3.1 升级时——推翻 v3.0 的 GDScript + @tool + EditorScript 方案，改用 Python 独立技术栈。
>
> **⚠️ v3.1 重写说明**：本笔记原 v3.0 版本是"@tool 与 EditorScript（Godot 编辑器扩展）"，因 v3.1 闸门 C 决策推翻 GDScript 方案，本笔记完全重写为 Python 工具脚本基础。原 @tool+EditorScript 内容作废，如需了解 Godot 编辑器扩展请查阅 Godot 官方文档。

---

## ⚠️ v3.1 知识库独立声明（凌驾性原则）

本笔记属于**知识库工具栈基础**，不属于游戏代码栈。技术栈独立性详见 [[56-知识库的定位（独立于项目的人生知识库）]] 和 AGENTS.md §20.11。

---

## 本实例（v3.1 扩展段）

**遇到的问题**：
Phase 4.5 完成 + 知识库 AI-RAG 5 层方案 v3.0 落地后，用户提出："升级知识库怎么能和 Godot 编辑器运行挂钩？"——这句质疑暴露了 v3.0 方案的根本问题：知识库工具锁死在 Godot 编辑器内，未来做别的项目（Web/App/AI）就不能复用。用户进一步明确："知识库应该独立于项目，是用户人生脑子，技术栈也应独立。"v3.1 走闸门 C 5 问推翻 v3.0 GDScript 方案，改用 Python 独立技术栈。本笔记解释"Python 工具脚本怎么写、怎么跑"。

**专业名词/知识点**：
- **Python 解释型语言**：代码逐行解释执行，不需要编译，跨平台运行
- **`.py` 文件**：Python 源代码文件，文本格式，任何文本编辑器都能打开
- **命令行运行**：在 PowerShell/Terminal 输入 `python xxx.py` 执行脚本
- **Python 标准库**：Python 自带的工具集（os/re/pathlib/datetime 等），不用额外安装
- **`if __name__ == "__main__":`**：Python 脚本的"主入口"约定，直接运行时才执行
- **`pathlib.Path`**：Python 处理文件路径的现代方式，跨平台（Windows/Mac/Linux 通用）

**技术栈/代码**：
- `tools/kb_inspector.py`（第 3 层巡检脚本）
- `tools/sync_advisor.py`（第 5 层同步脚本）
- Python 3.8+ 标准库（os + re + pathlib + datetime + sys）
- 关键代码片段：
  ```python
  if __name__ == "__main__":
      main()
  ```
- 命令行运行方式：
  ```powershell
  cd D:\taiyang
  python tools/kb_inspector.py
  ```

**应用过程**：
1. v3.0 用 GDScript + @tool + EditorScript 写在 `scripts/tools/kb_inspector.gd`
2. 用户提出知识库应独立于游戏项目，技术栈也应独立
3. 走闸门 C 5 问：实际做法（Python）vs 原定（GDScript）的差异审计
4. AGENTS.md v3.1 新增 §20.11 知识库技术栈独立性原则 + §20.12 Python 工具脚本说明
5. 新建 `tools/` 目录（与 `scripts/` 平级，专门放 Python 工具脚本）
6. 写 `tools/kb_inspector.py` + `tools/sync_advisor.py`（功能同原 .gd 版）
7. 删除 `scripts/tools/kb_inspector.gd` + `scripts/tools/sync_advisor.gd`
8. 命令行运行：`python tools/kb_inspector.py`（不依赖 Godot 编辑器）

---

## 概念

### 1. 生动形象例子（万能翻译官）

把 Python 想象成一位**万能翻译官**——任何电脑（Windows/Mac/Linux）只要装了他，他就能干活。他不挑行业，不挑项目，不挑老板。

| 角色 | 类比 | 实际 |
|------|------|------|
| 万能翻译官 | Python 解释器 | 装一次，能在任何电脑上跑 .py 文件 |
| 翻译官的工具箱 | Python 标准库 | os（文件操作）+ re（正则）+ pathlib（路径）等 |
| 给翻译官派的活 | .py 脚本 | kb_inspector.py / sync_advisor.py |
| 派活的方式 | 命令行运行 | `python tools/kb_inspector.py` |

**关键差异**：GDScript 是 Godot 的"私人翻译官"——离开 Godot 就失业。Python 是"自由职业翻译官"——任何项目都能雇他。

### 2. 本游戏实际应用例子

我们的 `tools/kb_inspector.py` 工作流程：

```
您打开 PowerShell 命令行
  ↓
输入：cd D:\taiyang
输入：python tools/kb_inspector.py
  ↓
Python 解释器加载 kb_inspector.py
  ↓
找到 if __name__ == "__main__": 入口
  ↓
调用 main() 函数
  ↓
main() 内部：
  - list_note_files() 列出所有 .md 文件
  - check_broken_links() 扫断链
  - check_duplicate_concepts() 找重复概念
  - check_outdated() 查 30 天没动的笔记
  - check_v27_compliance() 查 v2.7 准则符合度
  - check_three_way_consistency() 粗筛三项不一致
  ↓
build_report() 生成 markdown 报告
  ↓
print_report() 控制台打印 + save_report() 归档到 .ai-reports/
  ↓
您看报告 → 决定是否走闸门 C 修复
```

**关键点**：整个过程**不需要打开 Godot 编辑器**，**不需要启动游戏**。这就是 Python 独立技术栈的价值。

---

## 功能

### Python 工具脚本的 4 个核心功能

1. **跨平台运行**：Windows / Mac / Linux 都能跑，换电脑不用改代码
2. **标准库丰富**：os 文件操作 + re 正则 + pathlib 路径 + datetime 时间 + sys 系统，不用装第三方包
3. **命令行运行**：不必依赖任何 IDE 或编辑器，PowerShell/Terminal 直接跑
4. **跨项目复用**：未来做别的项目（Web/App/AI），整个 `tools/` 目录原样搬走

### Python 标准库在本项目的用法

| 模块 | 作用 | 在 kb_inspector.py 中的用法 |
|------|------|----------------------------|
| `os` | 操作系统接口 | 文件路径处理 |
| `re` | 正则表达式 | 扫描 `[[xxx]]` 链接、`## 概念` 段标题 |
| `pathlib` | 路径处理（现代方式） | `Path(__file__).resolve().parent.parent` 找项目根 |
| `datetime` | 时间处理 | 笔记 30 天没动判定 |
| `sys` | 系统参数 | 错误时 `sys.exit(1)` 退出 |

---

## 运作方式（含具体例子）

### 例子 1：Python 脚本的标准开头

```python
"""
kb_inspector.py —— 知识库 AI-RAG 第 3 层自动巡检脚本
...（文档字符串说明）
"""

import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

# 项目根目录（kb_inspector.py 在 tools/ 下，父目录就是项目根）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"

def main():
    """主入口"""
    print(f"[信息] 巡检知识库：{KB_ROOT}")
    # ... 巡检逻辑

if __name__ == "__main__":
    main()
```

逐段解释：

| 段 | 作用 |
|----|------|
| `"""..."""` | 文档字符串（docstring），说明脚本用途 |
| `import os` 等 | 导入标准库模块 |
| `Path(__file__).resolve().parent.parent` | 找项目根目录（不写死绝对路径） |
| `def main():` | 定义主函数 |
| `if __name__ == "__main__":` | 主入口约定：直接运行时才调用 main() |

### 例子 2：命令行运行

**步骤**：
1. 打开 PowerShell（Windows）或 Terminal（Mac/Linux）
2. 切换到项目根目录：`cd D:\taiyang`
3. 运行脚本：`python tools/kb_inspector.py`
4. 看控制台输出
5. 报告会保存到 `知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md`

**注意**：不需要打开 Godot 编辑器，不需要启动游戏。这是 Python 工具栈与 GDScript 工具栈最大的区别。

### 例子 3：为什么用 `Path(__file__)` 而不是写死路径

```python
# ❌ 反例：写死绝对路径
KB_ROOT = "D:/taiyang/知识库/"
# 换电脑就失效，换项目目录就失效

# ✅ 正例：用 Path(__file__) 推导
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"
# 任何电脑、任何路径都能跑
```

**`Path(__file__)` 的含义**：当前 .py 文件的路径。`.resolve()` 转绝对路径。`.parent.parent` 上溯两级（从 `tools/kb_inspector.py` 上到 `D:\taiyang\`）。

---

## 原理

### 1. Python 解释型 vs GDScript 引擎型

| 项 | Python | GDScript |
|----|--------|----------|
| 运行环境 | Python 解释器（独立安装） | Godot 引擎内置 |
| 是否需要 Godot | ❌ 不需要 | ✅ 必须 |
| 跨项目复用 | ✅ 任何项目都能用 | ❌ 只能在 Godot 项目内 |
| 跨平台 | ✅ Windows/Mac/Linux | ✅ 但要带 Godot |
| 学习曲线 | 平缓（像英语） | 平缓（像 Python） |

### 2. Python 标准库为什么能替代 Godot 编辑器功能

| 功能 | GDScript + EditorScript | Python 标准库 |
|------|--------------------------|---------------|
| 列出文件夹所有文件 | `DirAccess.open()` | `Path.rglob()` |
| 读文件内容 | `FileAccess.open()` | `open(path).read()` |
| 正则匹配 | `RegEx.new()` | `re.finditer()` |
| 路径拼接 | `res://知识库/` | `Path(PROJECT_ROOT) / "知识库"` |
| 时间判断 | `Time.get_datetime()` | `datetime.now() - timedelta(days=30)` |

**关键差异**：Python 标准库的功能不依赖 Godot 引擎，独立运行。

### 3. `if __name__ == "__main__":` 的本质

Python 文件有两种被加载的方式：

| 方式 | `__name__` 的值 | 是否调用 main() |
|------|----------------|-----------------|
| 直接运行 `python kb_inspector.py` | `"__main__"` | ✅ 是 |
| 被别的 .py 文件 `import` | `"kb_inspector"` | ❌ 否 |

**作用**：让脚本既能独立运行，又能被别的脚本当模块导入，互不干扰。

---

## 优势

### 1. 跨项目复用（核心优势）

未来做下一个项目（Web/App/AI/任何领域）：
- GDScript 方案：知识库工具必须重写（因为新项目不一定用 Godot）
- Python 方案：整个 `tools/` 目录原样搬走，一行代码不改

### 2. 技术栈分离

游戏代码（`scripts/`）和知识库工具（`tools/`）完全独立：
- 改游戏代码不会影响知识库工具
- 改知识库工具不会影响游戏代码
- 不互相引用、不互相依赖

### 3. 未来加 embedding 平滑过渡

联机版启动时第 1/4 层要引入 embedding 模型（BGE-M3）和向量库（SQLite-vec），都是 Python 生态。本期第 3/5 层已经用 Python，第 1/4 层引入时**同语言平滑过渡**，不分裂技术栈。

### 4. 符合 §0.5 架构地基三问

1. **MVP 够用吗？** ✅ Python 标准库够用（os/re/pathlib/datetime/sys）
2. **加新系统时要重构吗？** ✅ 加 embedding 时只 import 新包，不改现有代码
3. **升级时地基要改吗？** ✅ 地基（Python + tools/ 目录）不动，只加新脚本

### 5. Python 是 AI/数据科学通用语言

学了 Python 用一辈子：
- AI 开发（PyTorch / TensorFlow）
- 数据分析（pandas / numpy）
- Web 后端（Django / Flask）
- 自动化脚本（os / subprocess）
- 知识库工具（本项目）

---

## 使用场景（含对接）

### 场景 1：知识库 AI-RAG 第 3 层巡检

**对接**：`tools/kb_inspector.py` 扫描 `知识库/` 下所有 .md 文件，报告归档到 `知识库/.ai-reports/`。

**触发时机**（AGENTS.md §20.4）：
- 每次会话开始
- 用户主动喊"巡检"
- 里程碑完成

**运行命令**：
```powershell
cd D:\taiyang
python tools/kb_inspector.py
```

### 场景 2：知识库 AI-RAG 第 5 层同步检查

**对接**：`tools/sync_advisor.py` 扫描 `scripts/` + `data/` + `docs/` + `知识库/` 的文件修改时间，找出"代码改了但笔记没改"的情况。

**触发时机**（AGENTS.md §20.6）：
- 每次 git commit 后
- 用户主动喊"同步检查"

**运行命令**：
```powershell
cd D:\taiyang
python tools/sync_advisor.py
```

### 场景 3：未来扩展（非 MVP）

Python 工具栈未来可以做：
- **数据校验工具**：检查 data/*.json 字段是否齐全、类型是否正确
- **批量重命名工具**：把 50 个 .tscn 文件按规则重命名
- **资源统计工具**：统计 assets/ 下各类资源数量、大小
- **跨项目知识库迁移**：把知识库从一个项目搬到另一个项目

这些都是"知识库管家"的活儿，用 Python 都能轻松实现，且不依赖任何具体项目。

---

## 反例 vs 正例对照

| 反例（违规） | 正例（合规） |
|------|------|
| 知识库工具用 GDScript 写（锁死 Godot，v3.0 方案） | 用 Python 写在 `tools/`，跨项目通用（v3.1 改） |
| 硬编码绝对路径 `D:/taiyang/知识库/` | 用 `Path(__file__).resolve().parent.parent` 推导 |
| 把 `.py` 放 `scripts/` 目录混入游戏代码 | 放 `tools/` 目录与 `scripts/` 平级 |
| 知识库工具 `import` 游戏代码（如 `from scripts.player import ...`） | 知识库工具只读文件，不引用任何游戏代码 |
| 用 Python 但装一堆第三方包（增加迁移成本） | 只用 Python 3.8+ 标准库（零依赖） |
| 不写 `if __name__ == "__main__":` 直接顶层执行 | 用主入口约定，方便被 import 也不误执行 |
| 知识库工具引用 `data/*.json` 的具体字段 | 知识库工具只读文件元信息（路径/修改时间），不解析内容 |

---

## 关联

- [[53-知识库AI-RAG5层升级方案]] —— 本笔记的上级，讲 5 层方案总览
- [[55-embedding模型与向量库（联机版预留）]] —— 联机版第 1/4 层技术选型（Python 生态）
- [[56-知识库的定位（独立于项目的人生知识库）]] —— 为什么知识库独立于游戏项目
- [[02-技术栈与工具全景]] —— 项目整体技术栈，本笔记的 Python 是知识库工具栈
- [[01-文件格式名词]] —— .py 文件格式说明（待补 Python 段）
- [[03-数据驱动架构与JSON工作原理]] —— 数据驱动理念，巡检脚本也是数据驱动（读 .md 文件）
- [[49-物品体系与数据驱动]] —— 同一时期的 Phase 4.5 成果

---

> 最后更新：2026-07-20
> 写作触发：v3.1 升级，推翻 v3.0 GDScript 方案，改用 Python 独立技术栈
> 闸门 B 第 9 问"小白学习视角检查"：识别出 Python / .py / 命令行运行 / 标准库 / `if __name__ == "__main__":` / `pathlib.Path` 是用户第一次见的新概念，必须补知识库。
> v3.1 凌驾性原则：本笔记属于知识库工具栈，独立于游戏代码栈。
