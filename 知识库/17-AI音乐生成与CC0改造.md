# 17 - AI 音乐生成与 CC0 音效改造

## 概念

用 AI 工具生成游戏 BGM/音效，以及把 CC0 免费音效改造为"自己的"，节省外包成本。

## 功能

- 用 AI 描述风格直接生成完整 BGM
- 用 AI 把现有 CC0 音效改造（变调、加混响、拼接）变成独特版本
- 避免版权纠纷（喂曲版权风险）

## 运作方式

### A. AI 生成 BGM（推荐 Suno）

工具：[Suno](https://suno.ai)
- 付费约 $10/月 → 500 首/月商用权
- 输入描述："温暖的乡村田园，原声吉他+班卓琴，循环友好，60BPM"
- Suno 出 2~4 首候选 → 选满意一首下载
- 格式可能是 .mp3 → 用 [Audacity](https://www.audacityteam.org)（免费）转 .ogg

#### 正例流程

```
1. Suno 输入> Generate 5 首候选
2. 下载满意的 1首 .mp3
3. Audacity 打开 → 调循环点 → 导出为 .ogg
4. 复制到 assets/audio/bgm/village.ogg
5. 在 data/sounds.json 加： "bgm_village": { "file": "bgm/village.ogg", "loop": true, "volume": 0.6 }
6. 重启 Godot → 可以播
```

#### 反例（会触发版权风险）

```
在 Suno 上传一首受版权保护流行曲做"风格参考"
→ Suno 服务条款明令禁止
→ 输出物可能被 Suno 收回
→ 即使你保存了也不能商用
```

### B. AI 生成音效

工具：[ElevenLabs Sound Effects](https://elevenlabs.io) / Adobe Podcast AI
- 付费约 $5/月 → 数百个音效
- 输入"金属剑击中木盾，尖锐脆响，0.3 秒"
- 下载 .wav 直接用

### C. 改造 CC0 音效为"自己的"

工具：[Audacity](https://www.audacityteam.org)（免费）

正例流程：
```
1. 从 freesound.org 下载一个 CC0 剑击音效（自由用无署名）
2. Audacity 打开 → 加混响、变调低 3 半音、拼接一段金属环
3. 导出为 sword_hit_v2.wav
4. 仍 CC0，可视为自己作品
```

### D. 改造 CC0 BGM 为"自己的变体"

正例流程：
```
1. 从 Pixabay Music 下载 CC0 田园 BGM
2. Audacity 剪掉前奏 → 改 BPM → 加一轨长笛
3. 导出为 village_v2.ogg
4. 仍 CC0，无版权问题
```

也可以把第 1 步下载的 CC0 曲**喂给 Suno 作为"风格参考"**——因为它是 CC0，所以不违反 Suno 的版权条款，Suno 生成的变体属于你自己。

## 原理

**版权分层**：
- CC0 = 公有领域，可商用可修改无署名
- CC-BY = 可商用可修改，**必须署名**
- CC-BY-NC = 不可商用
- 受版权保护 = 必须授权，AI 训练/参考都违规

我们只用 CC0 + 自有 + Suno 付费版（Suno 付费版生成物归你）。

## 优势

| 优势 | 说明 |
|------|------|
| 零外包成本 | 不用雇音乐人，AI 几块钱一首 |
| 风格统一 | Suno 风格描述锁定调性 |
| 快速迭代 | 一下午能出 10 首候选 |
| 合规避险 | 只用 CC0 + AI 付费版 |

## 使用场景

### 场景 1: MVP 阶段做 BGM

5 张地图各 1 首共 5 首 BGM → Suno 一天能出齐 → 选满意的入库。

### 场景 2: 战斗音效

挥砍、命中、受击、升级 → ElevenLabs 描述生成或 CC0 库改造 → 一周完成全部音效。

### 场景 3: 联机版 Boss 战主题曲

Suno 输入"史诗 Boss 战，金属敲击+合成器低沉，120BPM，紧张感" → 出曲 → 改加管弦乐层 → 入库。

## 风险点（地基规矩）

| 风险 | 防范 |
|------|------|
| Suno 喂版权曲 | 只喂 CC0/自有曲做风格参考 |
| 忘记 CC-BY 署名 | 在游戏内做"音乐致谢"页署名所有 CC-BY |
| MP3 入库 | 所有音乐强制转 .ogg，用 Audacity 转换 |
| Suno 付费到期生成物归 AI 公司 | 付费期持续续订，或下载后立刻备份 .ogg 永久保存 |

---

## 关联

- 音频系统设计真源：[[13-音效与音乐资源处理]]
- AGENTS 宪法怎么登记新数据：[[12-AGENTS宪法治理逻辑]] §1.4
- 新技术引用审计流程：[[12-AGENTS宪法治理逻辑]] §15