# 14 - coding-agents-setup 参考 + 多 AI 工具切换准备

## 概念

一个 GitHub 仓库（[NihilDigit/coding-agents-setup](https://github.com/NihilDigit/coding-agents-setup)），提供 **3 种 AI 编码助手（Codex/Claude/Pi）的本地工具链配置脚本**。

用户在 2026-07-17 追加：未来可能切换 Codex/Trae 等多种 AI 工具 —— 本笔记加一段"多 AI 工具切换准备"。

## 功能

给开发电脑装一套统一的 AI 编码环境：
- 全局规则文件（`~/.codex/AGENTS.md` 等）
- CLI 工具（rg/fd/eza/uv/bun）
- PowerShell 安全 rm 替代
- 写规则前自动备份旧版

## 运作方式（看它的结构）

```
仓库结构：
├── rules/
│   ├── AGENTS.shared.md     ← 所有 AI 共享规则
│   ├── AGENTS.windows.md    ← Windows 特定
│   ├── AGENTS.linux.md      ← Linux 特定
│   ├── AGENTS.codex.md      ← OpenAI Codex 特性
│   ├── CLAUDE.md            ← Claude Code 特性
│   └── AGENTS.pi.md         ← Pi 特性
└── scripts/
    ├── setup-windows.ps1
    └── setup-linux.sh
```

安装时按"共享 + 平台 + AI 特性"拼装出最终一个 AGENTS.md 到对应全局目录。

## 原理

把"规矩"做成**可拼装片段**而不是一个大文件——共享部分共享，平台部分分开，特性部分独立。一次写多次组装。

## 优势

| 优势 | 说明 |
|------|------|
| 跨 AI 统一规矩 | Claude/Codex/Pi 共享同一套共享规则 |
| 平台分开 | Windows/Linux 不互相干扰 |
| 备份兜底 | 改全局前先备份 |
| 一键安装 | 一行 PowerShell/Shell 完成全部配置 |

## 与我们项目的冲突分析

| 冲突点 | 说明 |
|--------|------|
| 全局 vs 项目 | 它写**全局** `~/.codex/AGENTS.md`；我们用**项目根** `D:\taiyang\AGENTS.md`。混用会让全局规则干扰项目专有规则 |
| 装错工具 | 它装 Python(uv) + JS(bun)，我们是 Godot/GDScript 不需要 |
| rm 替代不必要 | 我们基本不删文件，靠 git 兜底，不需要 trash |

**结论**：**不建议在我们项目装它**。但其中的**片段拼装思路**值得未来 AGENTS.md 长到失控时参考。

---

## 多 AI 工具切换准备（你新加的需求）

你说未来可能切 Codex / Trae。我们怎么做准备让切换无痛？

### 全局 vs 项目规则的分工

```
全局规则（~/.codex/AGENTS.md 等）：
  - AI 工具自己的行为标准（不动）
  - 比如 Codex 默认怎么处理大文件、Claude 怎么报关错

项目规则（D:\taiyang\AGENTS.md）：
  - 我们项目的所有规矩（地基三规矩/能力总目录/验收清单...）
  - 项目级规矩永远 > 全局规矩
```

### 切换 AI 工具的 3 步准备

**第 1 步：项目 AGENTS.md 永远是最高优先级**

不管用什么 AI 工具，第一句话永远让它读 `D:\taiyang\AGENTS.md`。全局规则让位于项目规则。

**第 2 步：保留全局规则目录干净**

```
~/.codex/AGENTS.md       ← 写 Codex 自己的工作习惯
~/.claude/CLAUDE.md      ← 写 Claude 自己的工作习惯
~/.trae/config.json      ← 写 Trae 自己的工作习惯
```
**不要在全局写项目规矩**——项目规矩都在 D:\taiyang\AGENTS.md。这样切换工具不丢规矩。

**第 3 步：每个工具的"入口命令"统一**

不管换哪个工具：
```
请读 D:\taiyang\AGENTS.md 和 D:\taiyang\docs\00-总览.md，
用 5 句话复述项目状态后等我下一步指示。
```

工具不同，读的项目宪法不变。**所有 AI 凭这份文档协作**。

### 工具的具体建议

| 工具 | 我们怎么用 | 注意 |
|------|----------|------|
| OpenCode | 当前主力，TUI 好用 | session 管理用 opencode -s |
| Codex | OpenAI 出的命令行 AI 编码工具 | 可装但不让它进项目规则；让它读项目 AGENTS.md 即可 |
| Claude Code | Anthropic 出的命令行 AI 编码工具 | 同上，可装，项目规则强制读 |
| Trae | 国产 AI 编程 IDE | 如果有 AI 聊天面板直接让它读 D:\taiyang\AGENTS.md 即可 |

### 切换 AI 工具的损失最小化

- ✅ 文档和代码全程在 git，工具切换 = 重新打开同一份文件
- ✅ AGENTS.md 是 .md，任何 AI 都能读
- ✅ 知识库也是 .md，你换主开发工具时人能继续查
- ⚠️ 会话历史（opencode session）只在 OpenCode，换工具就丢了。所以重要内容必须进 HANDOFF.md（git 留痕）

### 反例：什么会让切换变难

```
在 OpenCode 会话里说"我上次我们说了钓鱼的鱼有 5 个品质"
→ 这条信息存在 OpenCode 数据库里，Codex 看不到
→ 切到 Codex 时 Codex 不知道
→ 必须把它写进 docs/05-副职业系统.md 才能 Codex 也读到
```

**这就是"三项一致"原则的价值**——所有真值必须在 .md / .json，不在脑子也不在会话数据库。

---

## 使用场景

### 场景 1: 将来 AGENTS.md 太长了

参考它的"片段拼装"思路拆分（见 AGENTS.md §17 片段拼装协议）。

### 场景 2: 你同时跑 3 个 AI 工具

按上面"多 AI 工具切换准备"做——全局写工具习惯，项目写游戏规矩，永远让 AI 读项目 AGENTS.md。

### 场景 3: 参考"Issue-Driven Work Contract"

它提的"动手前先对齐需求"——我们 AGENTS.md §1.7 新增系统协议就是这个意思。

## 我对它的评价

| 维度 | 评价 |
|------|------|
| 设计思路 | ⭐⭐⭐⭐ 片段拼装聪明 |
| 实用性 | ⭐⭐⭐ 对我们用不到多数工具 |
| 冲突风险 | 中等（全局规则会干扰项目） |
| 学习价值 | ⭐⭐⭐⭐ 可学习的工程思路 |
| 推荐应用 | ❌ 不应用（与我们的项目宪法冲突） |
| 推荐参考 | ✅ 学思路不学脚本 |
| 切换工具时 | ✅ 它的"全局 vs 项目分层"思路是我们多 AI 协作的根本 |

---

## 关联

- 我们项目宪法怎么写的：[[12-AGENTS宪法治理逻辑]]
- AI 自检避免忘规矩：[[09-合规巡检机制]]
- 上下文与健康协作：[[10-上下文管理与换对话]]
- AGENTS.md 太长怎么拆：AGENTS.md §17 片段拼装协议 [[12-AGENTS宪法治理逻辑]]