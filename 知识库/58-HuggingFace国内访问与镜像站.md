# 58 - HuggingFace 国内访问与镜像站

## 本实例段

**遇到的问题**：
v3.2 第 1 层语义索引构建时，跑 `python tools/kb_indexer.py` 报错 `[WinError 10054] 远程主机强迫关闭了一个现有的连接` + `Cannot send a request, as the client has been closed`。这是国内访问 HuggingFace（huggingface.co）时网络被掐断的常态问题，导致 BGE-M3 模型（~2GB）下载失败，第 1 层索引无法建立。修复后又遇到 sqlite-vec 查询返回二进制 blob 不能用 `json.loads` 解析的 bug（UnicodeDecodeError）。

**专业名词/知识点**：
- **HuggingFace**：全球最大的 AI 模型仓库（像"AI 模型的 GitHub"），sentence-transformers 默认从这里下载模型
- **WinError 10054**：Windows 网络错误码，意思是"远程主机强迫关闭了一个现有的连接"
- **hf-mirror.com**：HuggingFace 官方国内镜像站，由国内社区维护，下载速度快且稳定
- **HF_ENDPOINT 环境变量**：HuggingFace Python 库支持的环境变量，设置后会从指定镜像站下载模型
- **sqlite-vec 二进制 blob**：sqlite-vec 查询返回的是二进制数据（float 数组的二进制表示），不是 JSON 字符串
- **numpy.frombuffer**：把二进制数据解析成 numpy 数组的方法

**技术栈/代码/工具**：
- sentence-transformers 5.6.0（BGE-M3 加载与编码）
- huggingface_hub 1.24.0（模型下载）
- torch 2.6.0+cu124（CUDA 12.4 版本，GPU 加速）
- sqlite-vec 0.1.9（向量库）
- PowerShell（设置环境变量 `$env:HF_ENDPOINT`）
- BGE-M3 模型（~2GB，缓存到 `C:\Users\27192\.cache\huggingface\hub\`）

**应用过程**：
1. 第一次跑 kb_indexer.py 直接报 WinError 10054（国内访问 huggingface.co 被掐断）
2. 用 RunCommand 验证 hf-mirror.com 镜像可访问 BGE-M3 模型（30 个文件）
3. 在 PowerShell 里设置 `$env:HF_ENDPOINT="https://hf-mirror.com"`
4. 重新跑 kb_indexer.py，模型从镜像站下载成功（2.27GB，13 分钟）
5. 下载完后模型缓存到本地，下次跑不用下载，直接读缓存（秒加载）
6. 修复 sqlite-vec 二进制 blob 解析 bug（kb_recommender.py 的 load_vectors 函数从 `json.loads` 改为 `numpy.frombuffer`）

## 概念

HuggingFace 是个国外的 AI 模型仓库（像"AI 模型的淘宝"），你在国内访问它，网络经常被掐断。hf-mirror.com 是 HuggingFace 的国内镜像站（像"国外淘宝的国内分仓"），下载速度快且稳定。sqlite-vec 存向量时接受 JSON 字符串或二进制，但查询时永远返回二进制 blob（像存照片可以存描述文字或像素，但取出来永远是像素二进制）。

**本项目专属例子 1（生动形象）**：你想下载 BGE-M3 模型（2.27GB），直接访问 huggingface.co，下载到 64% 时网络被掐断（WinError 10054）。设置 `HF_ENDPOINT=https://hf-mirror.com` 后，从国内镜像下载，13 分钟下载完成，模型缓存到 `C:\Users\27192\.cache\huggingface\hub\`，下次跑秒加载。

**本项目专属例子 2（落地应用）**：kb_indexer.py 第 91 行 `model = SentenceTransformer(MODEL_NAME)` 会自动从 HuggingFace 下载 BGE-M3。设置 HF_ENDPOINT 后，sentence-transformers 自动从镜像站下载，代码不用改。kb_recommender.py 第 96 行 `vectors[rowid] = np.frombuffer(embedding_blob, dtype=np.float32).tolist()` 用 numpy 解析二进制 blob，而不是 `json.loads`。

## 功能

- **HuggingFace**：存储和分发 AI 模型（embedding 模型、LLM、vision 模型等）
- **hf-mirror.com**：HuggingFace 国内镜像，解决国内访问不稳定问题
- **HF_ENDPOINT**：环境变量，告诉 HuggingFace Python 库用哪个镜像站
- **sqlite-vec 二进制 blob**：sqlite-vec 向量库查询返回的数据格式
- **numpy.frombuffer**：把二进制 blob 解析成 float 列表的方法

## 运作方式

### 设置 HF_ENDPOINT（PowerShell 临时设置）

```powershell
# 临时设置（只对当前 PowerShell 窗口有效）
$env:HF_ENDPOINT="https://hf-mirror.com"

# 验证设置成功
echo $env:HF_ENDPOINT  # 应输出 https://hf-mirror.com
```

### 设置 HF_ENDPOINT（永久设置）

```powershell
# 永久设置（写入用户环境变量，每次开 PowerShell 都自动用镜像）
[System.Environment]::SetEnvironmentVariable("HF_ENDPOINT", "https://hf-mirror.com", "User")

# 设置完后需要重启 PowerShell 才生效
```

### torch CUDA 版本检查命令

```powershell
# 检查 torch 是否 CUDA 版本（GPU 可用）
python -c "import torch; print('torch版本:', torch.__version__); print('CUDA可用:', torch.cuda.is_available()); print('GPU名称:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '无GPU'); print('CUDA版本:', torch.version.cuda if torch.version.cuda else 'CPU版')"
```

预期输出（GPU 版本）：
```
torch版本: 2.6.0+cu124
CUDA可用: True
GPU名称: NVIDIA GeForce RTX 4060 Laptop GPU
CUDA版本: 12.4
```

如果是 CPU 版本（`CUDA可用: False`），需要重装 CUDA 版 torch：
```powershell
# 卸载 CPU 版
pip uninstall torch
# 安装 CUDA 12.4 版（从清华源装，速度快）
pip install torch --index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
```

### sqlite-vec 二进制 blob 解析（v3.2 修复 bug）

sqlite-vec 查询返回二进制 blob，不是 JSON 字符串。用 numpy.frombuffer 解析：

```python
import numpy as np

# 错误写法（kb_recommender.py v3.2 bug，报 UnicodeDecodeError）：
# vectors[rowid] = json.loads(embedding_json)

# 正确写法：
vectors[rowid] = np.frombuffer(embedding_blob, dtype=np.float32).tolist()
```

### sqlite-vec API 正确用法（v3.2 修复 bug）

```python
import sqlite3
import sqlite_vec

db = sqlite3.connect("vectors.db")
# 错误写法（kb_indexer.py v3.2 bug，报 AttributeError）：
# db.enable_extension("sqlite_vec")

# 正确写法：
db.enable_load_extension(True)
sqlite_vec.load(db)
```

## 原理

HuggingFace Python 库（huggingface_hub + sentence-transformers）在下载模型时，会读取 `HF_ENDPOINT` 环境变量。如果设置了，就从指定镜像站下载；如果没设置，默认从 huggingface.co 下载。

hf-mirror.com 是国内社区维护的 HuggingFace 镜像站，会实时同步 huggingface.co 的内容。国内访问 hf-mirror.com 速度快且稳定，不会出现 WinError 10054。

sqlite-vec 的 vec0 虚拟表存储 embedding 时接受两种格式（JSON 字符串或二进制），但查询时永远返回二进制 blob（float 数组的二进制表示，每个 float 4 字节）。所以查询时不能用 `json.loads`，要用 `numpy.frombuffer(blob, dtype=np.float32)` 把二进制解析回 float 列表。

## 优势

| 方案 | 速度 | 稳定性 | 是否需要改代码 |
|------|:----:|:------:|:------------:|
| 直接访问 huggingface.co | 慢 | 不稳定（WinError 10054） | 否 |
| 设置 HF_ENDPOINT=https://hf-mirror.com | 快 | 稳定 | 否 |
| 手动下载模型到本地缓存 | 中 | 稳定 | 需要手动操作 |

| sqlite-vec 查询方式 | 是否正确 | 说明 |
|-------------------|:------:|------|
| json.loads(blob) | ❌ | blob 是二进制，不是 JSON 字符串 |
| numpy.frombuffer(blob, dtype=np.float32) | ✅ | 正确解析二进制为 float 列表 |

## 使用场景

### 场景 1：跑 kb_indexer.py 下载 BGE-M3 模型

```powershell
cd D:\taiyang
$env:HF_ENDPOINT="https://hf-mirror.com"
python tools/kb_indexer.py
```

### 场景 2：跑 kb_recommender.py（模型已经在缓存里，不用设置 HF_ENDPOINT）

```powershell
cd D:\taiyang
python tools/kb_recommender.py
```

### 场景 3：永久设置 HF_ENDPOINT（推荐）

```powershell
[System.Environment]::SetEnvironmentVariable("HF_ENDPOINT", "https://hf-mirror.com", "User")
# 重启 PowerShell 后永久生效
```

### 场景 4：检查 torch GPU 状态

```powershell
python -c "import torch; print('CUDA可用:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else '无GPU')"
```

## 反例 vs 正例

### 反例 1：直接访问 huggingface.co

```powershell
python tools/kb_indexer.py
# 报错：[WinError 10054] 远程主机强迫关闭了一个现有的连接
```

### 正例 1：设置 HF_ENDPOINT 镜像

```powershell
$env:HF_ENDPOINT="https://hf-mirror.com"
python tools/kb_indexer.py
# 成功：模型从镜像站下载，13 分钟完成
```

### 反例 2：sqlite-vec 查询用 json.loads

```python
vectors[rowid] = json.loads(embedding_json)
# 报错：UnicodeDecodeError: 'utf-8' codec can't decode byte 0xbd in position 1: invalid start byte
```

### 正例 2：sqlite-vec 查询用 numpy.frombuffer

```python
vectors[rowid] = np.frombuffer(embedding_blob, dtype=np.float32).tolist()
# 成功：二进制 blob 解析为 float 列表
```

### 反例 3：sqlite-vec 加载扩展用 enable_extension

```python
db.enable_extension("sqlite_vec")
# 报错：AttributeError: 'sqlite3.Connection' object has no attribute 'enable_extension'
```

### 正例 3：sqlite-vec 加载扩展用 enable_load_extension + sqlite_vec.load

```python
db.enable_load_extension(True)
sqlite_vec.load(db)
# 成功：sqlite-vec 扩展加载完成
```

## 关联

- BGE-M3 模型选型理由：[[55-embedding模型与向量库（联机版预留）]]
- 知识库 AI-RAG 5 层升级方案：[[53-知识库AI-RAG5层升级方案]]
- Python 工具脚本基础：[[54-Python工具脚本基础（命令行运行）]]
- AI 滑坡识别（知识库决策不能挂钩游戏 MVP）：[[57-AI滑坡识别（游戏MVP与知识库独立性的边界混淆）]]
- 知识库 AI-RAG 使用指南（小白版）：[[59-知识库AI-RAG使用指南]]
