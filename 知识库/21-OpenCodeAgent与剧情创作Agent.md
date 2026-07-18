# 21 - OpenCode Agent 与剧情创作 Agent

## 概念

OpenCode 内置 6 个 agent，每个有不同职责。"agent" 是 AI 协作框架里**有特定职责和权限的 AI 角色**。

你想象换部门：技术部、客服部、市场部、计调部——每个部干不同活。OpenCode 的 agent 也一样。

## 6 个内置 Agent

我们调查发现 OpenCode v1.18.3 内置 6 个 agent：

| Agent 名 | 中文 | 职责 | 权限 | 我们用了吗 |
|----------|------|------|------|:---:|
| `build` | 主开发 | 全能开发：写代码 + 设计 + 文件操作 + bash | 全权限 | ✅ 主力 |
| `plan` | 规划 | 只读 / 创建计划，不改代码 | 无 edit | 偶尔 |
| `compaction` | 压缩 | 上下文满时自动压缩历史 | 自动 | 自动 |
| `summary` | 摘要 | 压缩对话成短摘要 | 自动 | 自动 |
| `title` | 起标题 | 给会话起名 | 自动 | 自动 |
| `explore` | 探索子 | 并行子任务探索代码库 | 只读 | 可调 |
| `general` | 通用子 | 并行子任务执行多步 | 完整 | 可调 |

## 运作方式

### 主 agent vs 子 agent

**主 agent**：你现在和我聊天的就是 `build` 主 agent。它单独运行，能干所有活。

**子 agent（subagent）**：主 agent 可以派生子 agent 去并行干活。比如：
- 主 agent 让 explore 子去搜 3 个文件
- 让 general 子去跑两条独立任务
- 主 agent 继续和你聊，子 agent 在后台跑，跑完回来汇报

### 切换 agent

在 OpenCode TUI 顶部菜单 `Agent` → 选切换，或启动时 `opencode --agent "build"`。

## 原理

每个 agent 有自己的"权限配置"——什么文件能读、什么能写、能不能调 bash、能不能问你问题。系统按配置运行。你不用记权限，AI 跑错了会自动告诉你"我作为 plan agent 没权限改代码"。

## 优势

| 优势 | 说明 |
|------|------|
| 分工 | 不同 agent 不同职责 |
| 并行 | 子 agent 干活的时主 agent 继续聊 |
| 权限隔离 | 防止"全能 AI 乱改" |
| 可扩展 | 第三方可加新 agent |

---

## 切换到 Codex 的局限

你问"未来换 Codex 会怎样"。诚实评估：

### ✅ Codex 完全能做的事

- 读 `D:\taiyang\AGENTS.md` 了解项目规矩
- 写 GDScript 代码并贴到 Godot
- 跑 bash 命令（git/编译）
- 改 .md / .json 文件
- 中文对话

### ⚠️ 切换的局限

1. **sliver-vibe-coding 治理 skill 用不了**——这是 Claude/OpenCode 专用。**但我们的规矩已经硬编码在 AGENTS.md 里**，Codex 读就行，不依赖 skill。

2. **会话历史独立**——OpenCode 的对话 Codex 看不到。**但 HANDOFF.md 解决了这个问题**，新会话读 HANDOFF + AGENTS 等于无缝接管。

3. **GitHub CLI 配置**——Codex 用 OpenAI API，跟你 GitHub 没关系，但**操作 git 是命令行通用的**，没影响。

4. **21 个 skill 用不了**（brainstorming / deep-interview 等）——这些是 Claude 共享的。Codex 自己另有扩展机制。但**剧情创作大模型通吃**，skill 只是"治理流程"，不直接生成剧情。

### 切换流程

```
1. 装 Codex：npm install -g @openai/codex
2. 登录 OpenAI：codex auth
3. 进项目：cd D:\taiyang
4. 启动：codex
5. 第一句：请读 D:\taiyang\AGENTS.md 和 D:\taiyang\docs\00-总览.md，
         用 5 句话复述项目状态后等我下一步指示。
```

完全无缝，因为地基靠的是 .md 文件，不是任何工具独占。

---

## "AI 剧情创作 agent"现实吗——完全现实

你说"想再有一个像 AI 写小说的 agent 给我丰富剧情"。**真相**：通用大模型（GPT-5 / Claude / GLM-5）的剧情创作能力**比专用小说 AI 强**。理由：

### 为什么不用专用 AI 小说工具

- **专用工具**（NovelAI / SillyTavern / AI Dungeon）= 套壳调用通用大模型，数据量小过拟合
- **通用大模型**训练数据包含海量小说+对话+剧本，泛化能力强
- **专用工具往往要订阅+学习**

### 我们已有的"剧情 agent"

你装了 21 个 skills，**其中三个就是剧情 agent 替代品**：

| Skill | 替代"故事 agent" 的什么 |
|-------|--------------------|
| `brainstorming` | 探讨剧情方向、头脑风暴章节走向 |
| `deep-interview` | 苏格拉底式挖你剧情意图和角色动机 |
| `ai-comic-studio` | 漫剧分镜提示词工程（适合你开场漫画） |

**怎么调用**：
```
加载 brainstorming skill，和我探讨第二章剧情方向
加载 deep-interview，问我关于主角失忆的 5 个深度问题
加载 ai-comic-studio，帮我把开场独白拆成 6 格漫画分镜
```

### 通用大模型已经能做的剧情活

| 剧情功能 | 大模型能干 |
|----------|:---:|
| 给第一章 NPC 写对话 | ✅ |
| 给 3 种不同风格的 Boss 临终遗言供选 | ✅ |
| 设计分支剧情走向 | ✅ |
| 写漫画分镜的文字描述 | ✅ |
| 生成 NPC 角色背景故事 | ✅ |
| 写主角内心独白 | ✅ |
| 章节命名 | ✅ |

**你想试？现在说"给我三种 Boss 临终台词"**，我立刻出 3 个版本让你选。

### 进一步增强剧情创作的方案

**方案 A：替代 agent（不推荐）**

GitHub 上的专用故事 AI（[NovelAI](https://novelai.net)、AI Dungeon）都要订阅且质量不如通用大模型。

**方案 B：调用更强模型（推荐进阶用）**

如果你想剧情质量再上一个台阶，可以：
- 用 Anthropic Claude 3.5 Opus（剧情创作强项）
- 用 OpenAI GPT-5（对话自然）

通过 OpenCode 调用不同模型：`opencode --model "anthropic/claude-3-5-opus"` 等。**不用换工具，换模型即可**。

## 优势总结

| 优势 | 说明 |
|------|------|
| 零工具切换 | 通用大模型就是剧情 agent |
| 21 skill 增益 | brainstorming/deep-interview 已装好 |
| 跨工具兼容 | 沟通用 .md，任何 AI 都能接垄 |
| 推理能力强 | 通用大模型泛化 > 专用小说 AI |

## 使用场景

### 场景 1：剧情卡住没灵感

"加载 brainstorming skill，给我 5 个第二章的可能走向"→ 你选一个继续。

### 场景 2：人物动机想深挖

"加载 deep-interview skill，问我 7 个关于主角为什么没印记的问题"→ AI 反问你，你答完发现自己的设计更深了。

### 场景 3：写一段 NPC 对话

"村长在村口迎接玩家，3 句话要点出老宅好久没人住、欢迎新人。给我 3 个风格版本：温暖 / 暗黑 / 普通"→ 你选一个改细节用。

### 场景 4：换模型要更强剧情

"重启 OpenCode 用 Claude 3.5 Opus 模型讨论剧情：opencode --model anthropic/claude-3-5-opus" → 剧情创作质量上一个台阶。

---

## 关联

- 工具清单全景：[[20-MVP完整工具清单]]
- skills 是什么怎么用：[[09-合规巡检机制]]
- 上下文超了换会话：[[10-上下文管理与换对话]]
- 多 AI 工具切换准备：[[14-coding-agents-setup参考]]