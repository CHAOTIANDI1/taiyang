# 14 - coding-agents-setup 参考

## 概念

一个 GitHub 仓库（[NihilDigit/coding-agents-setup](https://github.com/NihilDigit/coding-agents-setup)），提供 **3 种 AI 编码助手（Codex/Claude/Pi）的本地工具链配置脚本**。

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
│   ├── AGENTS.linux-arch.md ← Arch 衍生
│   ├── AGENTS.codex.md      ← OpenAI Codex 特性
│   ├── CLAUDE.md            ← Claude Code 特性
│   └── AGENTS.pi.md         ← Pi 特性
└── scripts/
    ├── setup-windows.ps1
    └── setup-linux.sh
```

安装时按"共享 + 平台 + AI 特性"拼装出最终一个 AGENTS.md 到对应全局目录。

### 一个例子

比如 Claude 在 Windows 上装：
```
合并：
  rules/AGENTS.shared.md
+ rules/AGENTS.windows.md
+ rules/CLAUDE.md
= ~/.claude/CLAUDE.md
```

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

**结论**：**不建议在我们项目装它**。但其中的**片段拼装思路**值得未来 AGENTS.md 长到失控时参考（拆 AGENTS-shared.md + AGENTS-mvp.md + AGENTS-online.md）。

## 使用场景

### 场景 1：将来 AGENTS.md 5000 行了

参考它的"片段拼装"思路，把 AGENTS.md 拆成 shared（跨阶段共用）+ mvp（MVP 期）+ online（联机期）。

### 场景 2：你的电脑同时跑 3 个 AI 工具

Codex/Claude/Pi 都用，想让它们遵守同一套规矩。装它有好处。但我们是 OpenCode 单一环境，不需要。

### 场景 3：参考它的"Issue-Driven Work Contract"

它提的"动手前先对齐需求"——我们 AGENTS.md §1.7 新增系统协议的 4 问就是这个意思，可以参考它的措辞优化自己的。

## 我对它的评价

| 维度 | 评价 |
|------|------|
| 设计思路 | ⭐⭐⭐⭐ 片段拼装聪明 |
| 实用性 | ⭐⭐⭐ 对我们用不到多数工具 |
| 冲突风险 | 中等（全局规则会干扰项目） |
| 学习价值 | ⭐⭐⭐⭐ 可学习的工程思路 |
| 推荐应用 | ❌ 不应用（与我们的项目宪法冲突） |
| 推荐参考 | ✅ 学思路不学脚本 |

---

## 关联

- 我们项目宪法怎么写的：[[12-AGENTS宪法治理逻辑]]
- AI 自检避免忘规矩：[[09-合规巡检机制]]
- 上下文与健康协作：[[10-上下文管理与换对话]]