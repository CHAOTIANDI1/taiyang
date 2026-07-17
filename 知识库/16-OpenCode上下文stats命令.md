# 16 - OpenCode 上下文查看与 stats 命令 + 底部状态栏解读

## 概念

OpenCode 内置了让你查看上下文/token 使用情况的方式：① 命令行 `opencode stats` ② TUI 屏幕底部状态栏。**不用装任何插件**。

## 功能

- `opencode stats` → 查看 token 使用总量和成本统计
- `opencode session list` → 查看所有会话
- TUI 界面底部状态栏 → **实时显示当前会话 token 用量**（最常用）
- `opencode export <sessionID>` → 导出会话为 JSON 备份

## 运作方式

### 命令 1: 看总用量

```powershell
opencode stats
```
返回类似：
```
Total tokens used: 1,230,000
Session count: 6
Estimated cost: $1.20
```

### 命令 2: 看会话列表

```powershell
opencode session list
```

### 命令 3: 实时查看（最常用）

**直接打开 `opencode` 进入 TUI**，屏幕**底部状态栏**就会一直显示当前会话已用 token 数和百分比。你不用打命令，眼睛看就行。

### 命令 4: 导出会话备份

```powershell
opencode export ses_0969d65baffevD7MA8n8Ba0vkl
```
导出当前会话完整历史到一个 JSON 文件，可作为终极备份。

---

## 底部状态栏解读（你 2026-07-17 看到的具体内容）

你看到的：
```
246.2K(25%)Context
246,222 tokens
25% used
$15.76 spent
LSP
LSPs are disabled
```

### 逐行翻译

| 显示 | 含义 | 大白话 |
|------|------|--------|
| `246.2K(25%)Context` | 上下文总容量被用了 25%，用掉 246.2K tokens | 你脑子已经装了 1/4，还能再聊一段 |
| `246,222 tokens` | 同上的精确数字 | 已经说了 246222 个"词" |
| `25% used` | 已用 25% | 剩 75% 可用 |
| `$15.76 spent` | 这一段会话花了多少钱（按当前模型价） | 你已经花了 15 美元啦 |
| `LSP` / `LSPs are disabled` | Language Server Protocol（语言服务器协议），现在没启用 | AI 暂时不帮你做代码补全/语法检查 |

### 25% 是什么意思？

OpenCode 把上下文容量按模型上下文窗口算（比如 1M tokens）：
- 25% = 用了 25 万 token —— **还很轻松，可以继续聊**
- 60% = 快一半了 —— **可以提示自己换对话了**
- 80% = 紧张了，**马上写交接**

### LSP 是什么？

**LSP = Language Server Protocol**，语言服务器协议。

生活类比：你写代码时旁边坐个"语法助手"，你打字他实时检查错别字、补全单词、提示可能的错误。LSP 就是这个助手的协议。

LSPs disabled = OpenCode 暂时没启用代码补全功能。**对我们 MVP 这种"AI 写代码你粘贴"模式影响不大**，可以暂时不用管。

---

## 原理

OpenCode 自己知道每次和 AI 通信用了多少 token——它把这个数据存进本地 SQLite 数据库。`opencode stats` 就是查这个库。底部状态栏是实时显示的同一份数据。

类比：你和 AI 聊天，AI 内部记账每条消息用多少 token。OpenCode 是"导出账本"的窗口。

## 优势

| 优势 | 说明 |
|------|------|
| 零插件 | 内置命令，开箱即用 |
| 实时显示 | TUI 底部一直显示 |
| 跨会话统计 | stats 显示总用量、成本估算 |
| 可导出备份 | 会话可 JSON 备份，断电也不丢 |

## 使用场景

### 场景 1: 每天开工时

打开 opencode 进入 TUI → 看底部 token 数字 → 心里有个数还剩多少预算。

### 场景 2: 感觉 AI 开始忘事

新开终端打个 `opencode stats` 看总量 → 看 session list 看是否有重复用的同一会话 → 决定换新会话。

### 场景 3: 一段任务完成要换会话

`opencode stats` 看当前会话用了多少 → 和 AGENTS.md §13"上下文预算协议"对照 → 决定是否触发交接文档。

### 场景 4: 看花了多少钱

每月底 `opencode stats` 看 token 用了多少美元 → 决定下月节奏。

### 场景 5: 你想问每段对话前都看到上下文用量

OpenCode TUI 中底部状态栏**每条对话结束都会刷新数字**。你眼睛看就行，不用打任何命令。

```
你发一条消息 → AI 回一条 → 底部数字涨 → 你看一眼
你发一条消息 → AI 回一条 → 底部数字涨 → 你看一眼
...
不用任何额外操作
```

## MVP 特别建议

你刚开始做 MVP 编码后会非常频繁使用 opencode。建议：
- 每轮对话后瞄一眼底部状态栏
- 上下文达 60% 提示自己准备换会话
- 上下文达 80% 立即让 AI 写 HANDOFF（走 AGENTS §13/§14）

---

## 关联

- 上下文超了怎么办：[[10-上下文管理与换对话]]
- 交接文档规则：[[11-会话交接文档规则]]
- AI 上下文预算协议：[[12-AGENTS宪法治理逻辑]] §13