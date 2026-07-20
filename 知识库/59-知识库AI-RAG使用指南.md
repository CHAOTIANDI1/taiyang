# 59 - 知识库 AI-RAG 使用指南（小白版）

## 本实例段

**遇到的问题**：
v3.2 第 1/4 层落地后，知识库 AI-RAG 5 层全部就绪。用户（零基础）需要一份"知识库怎么用"的小白指南，知道每个工具能做什么、什么时候跑、跑完看什么、跑错了怎么办。

**专业名词/知识点**：
- **AI-RAG**：Retrieval-Augmented Generation，检索增强生成。本项目的 5 层知识库管家系统
- **5 层架构**：第 1 层语义索引 / 第 2 层 AI 问答 / 第 3 层自动巡检 / 第 4 层跨笔记推荐 / 第 5 层项目同步
- **BGE-M3**：SOTA 中文语义 embedding 模型，把文字转成 1024 维向量
- **SQLite-vec**：轻量向量库，存向量 + 算相似度
- **余弦相似度**：两个向量的夹角余弦值，衡量语义相似度（0~1，越接近 1 越相似）

**技术栈/代码/工具**：
- 4 个 Python 工具脚本（tools/ 目录下）
- PowerShell 命令行运行
- 5 类报告归档（知识库/.ai-reports/）
- BGE-M3 + SQLite-vec + sentence-transformers + torch + numpy

**应用过程**：
本文是知识库 AI-RAG 5 层全部就绪后的使用指南。5 层各司其职：第 1 层建索引（向量化笔记）→ 第 2 层 AI 问答（结合知识库回答）→ 第 3 层自动巡检（扫描 5 类问题）→ 第 4 层跨笔记推荐（找隐含关联）→ 第 5 层项目同步（检查代码改动是否需要同步笔记）。

## 概念

知识库 AI-RAG 是 5 层系统，每层解决一个具体问题。你可以把它想象成"知识库的 5 个管家"：

**本项目专属例子 1（生动形象）**：知识库像你的笔记本，5 层 AI-RAG 像 5 个管家帮你管理笔记本：
- 第 1 层（索引管家）：把每页笔记拍照存档（向量化），方便日后搜
- 第 2 层（问答管家）：你问问题，管家翻笔记本找答案
- 第 3 层（巡检管家）：定期检查笔记本有没有断链/重复/过时/不达标
- 第 4 层（推荐管家）：发现笔记间隐含关联，建议加双链
- 第 5 层（同步管家）：代码改了，提醒你笔记要不要同步

**本项目专属例子 2（落地应用）**：你跑 `python tools/kb_inspector.py`，巡检管家会扫 56 篇笔记，告诉你哪些有断链、哪些缺"本游戏实例"段、哪些概念段例子不够。你跑 `python tools/kb_recommender.py`，推荐管家会告诉你"04-逻辑与显示分离原理"和"40-设计真值与数值推导"语义相似度 0.6487，建议加双链。

## 功能

| 层 | 工具脚本 | 做什么 | 什么时候跑 | 依赖 |
|----|---------|--------|-----------|------|
| 第 1 层 | kb_indexer.py | 给笔记建语义索引（向量化） | 新增/修改笔记后跑 | 无 |
| 第 2 层 | （无脚本，AI 问答时自动用） | AI 回答问题结合知识库 | 你问问题时 | 第 1 层索引 |
| 第 3 层 | kb_inspector.py | 扫描 5 类问题（断链/重复/过时/不达标/不一致） | 每次会话开始 / 完成里程碑 / 主动喊"巡检" | 无 |
| 第 4 层 | kb_recommender.py | 找笔记间隐含关联，推荐双链 | 第 1 层跑完后跑 | 第 1 层索引 |
| 第 5 层 | sync_advisor.py | 检查代码改动是否需要同步笔记 | git commit 后跑 | 无 |

## 运作方式

### 跑工具的通用步骤

```powershell
# 步骤 1：切到项目根目录（每次开新 PowerShell 窗口都要先 cd）
cd D:\taiyang

# 步骤 2：跑工具（以 kb_inspector.py 为例）
python tools/kb_inspector.py
```

### 第 1 层：建语义索引（kb_indexer.py）

```powershell
# 第一次跑需要设置镜像（详见 58 号笔记）
$env:HF_ENDPOINT="https://hf-mirror.com"
python tools/kb_indexer.py
```

**跑完看什么**：
- 控制台打印 `📊 成功索引 XX/XX 篇`
- 报告归档：`知识库/.ai-reports/索引-YYYYMMDD-HHMM.md`
- 索引文件：`知识库/.ai-index/vectors.db` + `index_meta.json`

**预期耗时**：
- 第一次：13~20 分钟（下载 BGE-M3 模型 ~2GB）+ 30 秒（56 篇笔记 GPU embedding）
- 之后：30 秒~1 分钟（模型已在缓存，直接 GPU embedding）

### 第 3 层：跑巡检（kb_inspector.py）

```powershell
python tools/kb_inspector.py
```

**跑完看什么**：
- 控制台打印 5 项巡检结果（断链/重复/过时/准则不达标/三项不一致）
- 报告归档：`知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md`
- 🔴 高严重度必须修（断链/重复/三项不一致）
- 🟡 中严重度下次自然触及时回填（过时/准则不达标）

**预期耗时**：5~10 秒

### 第 4 层：跑跨笔记推荐（kb_recommender.py）

```powershell
python tools/kb_recommender.py
```

**前置条件**：先跑第 1 层建索引（否则报 `❌ 索引未建立`）

**跑完看什么**：
- 控制台打印 `XX 篇笔记有推荐，共 XX 条推荐`
- 报告归档：`知识库/.ai-reports/推荐-YYYYMMDD-HHMM.md`
- 你确认推荐后，让 AI 走闸门 C 加双链（不自动写入）

**预期耗时**：5~10 秒

### 第 5 层：跑项目同步检查（sync_advisor.py）

```powershell
python tools/sync_advisor.py
```

**跑完看什么**：
- 控制台打印代码改动相关笔记
- 报告归档：`知识库/.ai-reports/同步-YYYYMMDD-HHMM.md`
- 提醒哪些笔记需要回填

### 第 2 层：AI 问答（无脚本，AI 回答时自动用）

你正常问 AI 问题，AI 会：
1. 用第 1 层索引找相关笔记
2. 结合笔记 + 代码 + docs 生成答案
3. 按 4 段格式输出（直接答案/出处标注/反例 vs 正例/关联推荐）

## 原理

5 层之间有依赖关系：

```
第 1 层（建索引）── 第 4 层（跨笔记推荐，复用第 1 层索引）
       │
       └── 第 2 层（AI 问答，复用第 1 层索引）
       
第 3 层（巡检）── 独立运行，不依赖第 1 层
第 5 层（同步）── 独立运行，不依赖第 1 层
```

**关键**：第 1 层是基础，新增/修改笔记后必须重跑第 1 层，否则第 2/4 层用的是旧索引。

**报告归档**：所有报告归档到 `知识库/.ai-reports/`，按时间戳命名（不覆盖），历史可追溯。.gitignore 排除，不进 git（派生数据，可重建）。

## 优势

| 优势 | 说明 |
|------|------|
| 5 层各司其职 | 每层解决一个具体问题，互不干扰 |
| 工具独立运行 | 不依赖 Godot，不依赖游戏代码，命令行直接跑 |
| 报告归档可追溯 | 每次跑生成报告，历史可查 |
| 知识库独立于游戏 | 跨项目复用，做别的项目时整个 tools/ 目录原样搬走 |
| GPU 加速 | torch CUDA 版本自动用 4060 GPU，56 篇笔记 embedding 30 秒 |

## 使用场景

### 场景 1：日常开发（写代码 + 改笔记）

```powershell
# 1. 改完笔记后重建索引
python tools/kb_indexer.py

# 2. 跑巡检看有没有问题
python tools/kb_inspector.py

# 3. 跑推荐看有没有新关联
python tools/kb_recommender.py
```

### 场景 2：完成里程碑后

```powershell
# 跑全套工具
python tools/kb_inspector.py      # 巡检
python tools/kb_indexer.py        # 重建索引
python tools/kb_recommender.py    # 跨笔记推荐
python tools/sync_advisor.py      # 项目同步检查
```

### 场景 3：会话开始时

```powershell
# 只跑巡检（看知识库现状）
python tools/kb_inspector.py
```

### 场景 4：你问 AI 问题时

直接问，不用跑任何工具。AI 会自动用第 1 层索引找相关笔记，按 4 段格式回答。

## 反例 vs 正例

### 反例 1：改了笔记不重建索引

```
你改了 50-InventoryManager容器逻辑.md，但没跑 kb_indexer.py
→ 第 4 层推荐用的是旧索引，可能推荐过时的关联
→ 第 2 层 AI 问答找不到新内容
```

### 正例 1：改笔记后重建索引

```powershell
python tools/kb_indexer.py        # 重建索引
python tools/kb_recommender.py    # 用新索引算推荐
```

### 反例 2：跑推荐前不跑索引

```powershell
python tools/kb_recommender.py
# 报错：❌ 索引未建立，请先运行：python tools/kb_indexer.py
```

### 正例 2：先索引后推荐

```powershell
python tools/kb_indexer.py      # 先建索引
python tools/kb_recommender.py  # 再跑推荐
```

### 反例 3：在 C:\Users\27192 下跑工具

```powershell
cd C:\Users\27192
python tools/kb_inspector.py
# 报错：can't open file 'C:\Users\27192\tools\kb_inspector.py': [Errno 2] No such file or directory
```

### 正例 3：先 cd 到项目根目录

```powershell
cd D:\taiyang
python tools/kb_inspector.py
# 成功：工具在 D:\taiyang\tools\ 下
```

## 关联

- 5 层升级方案：[[53-知识库AI-RAG5层升级方案]]
- HuggingFace 国内访问：[[58-HuggingFace国内访问与镜像站]]
- Python 工具脚本基础：[[54-Python工具脚本基础（命令行运行）]]
- 知识库独立于项目：[[56-知识库的定位（独立于项目的人生知识库）]]
- AI 滑坡识别（知识库决策不能挂钩游戏 MVP）：[[57-AI滑坡识别（游戏MVP与知识库独立性的边界混淆）]]
