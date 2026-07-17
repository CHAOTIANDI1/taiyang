# 16 - OpenCode 上下文查看与 stats 命令

## 概念

OpenCode 内置了一些命令让你查看上下文/token 使用情况，不用装任何插件。

## 功能

- `opencode stats` → 查看 token 使用量和成本统计
- `opencode session list` → 查看所有会话
- TUI 界面底部状态栏 → 实时显示当前会话 token 用量
- `opencode export <sessionID>` → 导出会话为 JSON 备份

## 运作方式（含具体命令）

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

**直接打开 `opencode` 进入 TUI**，屏幕底部状态栏就会显示当前会话已用 token 数。你不用打命令，眼睛看就行。

### 命令 4: 导出会话备份

```powershell
opencode export ses_0969d65baffevD7MA8n8Ba0vkl
```
导出当前会话完整历史到一个 JSON 文件，可作为终极备份。

## 原理

OpenCode 自己知道每次和 AI 通信用了多少 token——它把这个数据存进本地 SQLite 数据库。`opencode stats` 就是查这个库。

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

### 场景 4: 成本控制

每月底 `opencode stats` 看 token 用了多少美元 → 决定下月节奏。

## MVP 特别建议

你刚开始做 MVP 编码后会非常频繁使用 opencode。建议：
- 每小时瞄一次 TUI 底部 token 数
- 上下文达 60% 提示自己准备换会话
- 上下文达 80% 立即让 AI 写 HANDOFF

---

## 关联

- 上下文超了怎么办：[[10-上下文管理与换对话]]
- 交接文档规则：[[11-会话交接文档规则]]
- AI 上下文预算协议：[[12-AGENTS宪法治理逻辑]]