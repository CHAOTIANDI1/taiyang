"""
kb_indexer.py —— 知识库 AI-RAG 第 1 层语义索引脚本（v3.2 新增）

功能：
    扫描 知识库/ 下所有 .md 笔记，用 BGE-M3 模型做 embedding，
    存储到 SQLite-vec 向量库，支持语义搜索。

运行方式：
    cd D:\\taiyang
    python tools/kb_indexer.py

输出：
    1. 知识库/.ai-index/vectors.db       —— SQLite-vec 向量库
    2. 知识库/.ai-index/index_meta.json  —— 索引元数据（笔记路径 ↔ rowid 映射）
    3. 知识库/.ai-index/last_build.txt   —— 上次建索引时间
    4. 知识库/.ai-reports/索引-YYYYMMDD-HHMM.md —— 建索引报告
    5. 控制台打印进度和摘要

设计原则（AGENTS.md §20.11）：
    - 知识库工具用 Python 写，独立于游戏 GDScript 技术栈
    - 不引用 scripts/ 下任何游戏代码
    - 跨项目复用：换项目时整个 tools/ 目录原样搬走

依赖（tools/requirements.txt）：
    - sentence-transformers（BGE-M3 加载与编码）
    - torch（后端）
    - sqlite-vec（向量库）
    - numpy（向量计算）

v3.2 凌驾性原则落地：
    本脚本用 BGE-M3（SOTA 中文语义 embedding，~2GB）而非轻量版，
    理由是知识库是用户人生脑子，独立于游戏项目，用"一辈子最优"标准判断。
    详见知识库 57-AI滑坡识别（游戏MVP与知识库独立性的边界混淆）.md
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Windows 控制台默认 GBK 编码，无法打印 emoji，强制改 UTF-8
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# 项目根目录（kb_indexer.py 在 tools/ 下，父目录就是项目根）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"
INDEX_DIR = KB_ROOT / ".ai-index"
REPORT_DIR = KB_ROOT / ".ai-reports"

# BGE-M3 模型名称（HuggingFace Hub 上的标识）
MODEL_NAME = "BAAI/bge-m3"

# 向量维度（BGE-M3 输出 1024 维）
VECTOR_DIM = 1024


def list_note_files():
    """列出知识库下所有 .md 文件（除 00-索引.md）"""
    notes = []
    for md_file in KB_ROOT.rglob("*.md"):
        if md_file.name == "00-索引.md":
            continue
        # 跳过 .ai-reports/ 和 .obsidian/ 等隐藏目录
        if any(part.startswith(".") for part in md_file.relative_to(KB_ROOT).parts[:-1]):
            continue
        notes.append(md_file)
    return notes


def read_note_content(path):
    """读取笔记内容，返回纯文本（去掉 markdown 标记以便 embedding）"""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        print(f"  ⚠️ 读取失败 {path.name}: {e}")
        return ""


def load_model():
    """加载 BGE-M3 模型（第一次会下载 ~2GB）"""
    print(f"📦 加载模型 {MODEL_NAME} ...")
    print("   （第一次运行会下载 ~2GB 模型，请耐心等待）")
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer(MODEL_NAME)
        print("   ✅ 模型加载完成")
        return model
    except ImportError as e:
        print("❌ 依赖未装：sentence-transformers")
        print("   请先运行：pip install -r tools/requirements.txt")
        print(f"   错误详情：{e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 模型加载失败：{e}")
        print("   可能原因：网络问题导致模型下载失败")
        print("   解决方法：检查网络后重试，或手动下载模型到本地缓存")
        sys.exit(1)


def ensure_index_dir():
    """确保索引目录存在"""
    INDEX_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def build_index(notes, model):
    """对每篇笔记做 embedding，返回 (vectors, metadata)"""
    vectors = []
    metadata = []
    total = len(notes)

    print(f"\n📚 开始建索引，共 {total} 篇笔记")
    print("=" * 60)

    for i, note_path in enumerate(notes, 1):
        rel_path = note_path.relative_to(KB_ROOT).as_posix()
        content = read_note_content(note_path)

        if not content.strip():
            print(f"  [{i}/{total}] ⚠️ 跳过空文件：{rel_path}")
            continue

        try:
            # BGE-M3 编码（返回 numpy 数组）
            vec = model.encode(content, normalize_embeddings=True)
            vectors.append(vec.tolist())
            metadata.append({
                "rowid": len(vectors),  # 1-based
                "path": rel_path,
                "name": note_path.stem,
                "size": len(content),
                "mtime": datetime.fromtimestamp(note_path.stat().st_mtime).isoformat(),
            })
            print(f"  [{i}/{total}] ✅ {rel_path}（{len(content)} 字）")
        except Exception as e:
            print(f"  [{i}/{total}] ❌ 编码失败 {rel_path}: {e}")

    print("=" * 60)
    print(f"📊 成功索引 {len(vectors)}/{total} 篇")
    return vectors, metadata


def save_index(vectors, metadata):
    """存储向量到 SQLite-vec，元数据到 JSON"""
    db_path = INDEX_DIR / "vectors.db"
    meta_path = INDEX_DIR / "index_meta.json"
    last_build_path = INDEX_DIR / "last_build.txt"

    try:
        import sqlite3
        import sqlite_vec
    except ImportError as e:
        print("❌ 依赖未装：sqlite-vec")
        print("   请先运行：pip install -r tools/requirements.txt")
        print(f"   错误详情：{e}")
        sys.exit(1)

    # 删除旧索引
    if db_path.exists():
        db_path.unlink()

    print(f"\n💾 存储向量到 {db_path} ...")
    db = sqlite3.connect(str(db_path))
    db.enable_load_extension(True)
    sqlite_vec.load(db)

    # 建表
    db.execute(f"""
        CREATE VIRTUAL TABLE notes_vec
        USING vec0(embedding float[{VECTOR_DIM}])
    """)

    # 批量插入
    for i, (vec, meta) in enumerate(zip(vectors, metadata), 1):
        db.execute(
            "INSERT INTO notes_vec(embedding) VALUES (?)",
            [json.dumps(vec)]
        )
        if i % 10 == 0:
            print(f"  已插入 {i}/{len(vectors)}")
    db.commit()

    # 存元数据
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump({
            "model": MODEL_NAME,
            "vector_dim": VECTOR_DIM,
            "built_at": datetime.now().isoformat(),
            "note_count": len(metadata),
            "notes": metadata,
        }, f, ensure_ascii=False, indent=2)

    # 存最后建索引时间
    with open(last_build_path, "w", encoding="utf-8") as f:
        f.write(datetime.now().isoformat())

    db.close()
    print(f"   ✅ 索引存储完成（{len(vectors)} 篇笔记，{VECTOR_DIM} 维向量）")


def build_report(notes, vectors, metadata):
    """生成建索引报告"""
    report = {
        "built_at": datetime.now().isoformat(),
        "model": MODEL_NAME,
        "vector_dim": VECTOR_DIM,
        "total_notes": len(notes),
        "indexed_notes": len(vectors),
        "skipped_notes": len(notes) - len(vectors),
        "index_dir": str(INDEX_DIR.relative_to(PROJECT_ROOT)),
        "notes_detail": metadata,
    }
    return report


def print_report(report):
    """控制台打印报告"""
    print("\n" + "=" * 60)
    print("📋 建索引报告")
    print("=" * 60)
    print(f"建索引时间：{report['built_at']}")
    print(f"模型：{report['model']}")
    print(f"向量维度：{report['vector_dim']}")
    print(f"总笔记数：{report['total_notes']}")
    print(f"成功索引：{report['indexed_notes']}")
    print(f"跳过笔记：{report['skipped_notes']}")
    print(f"索引目录：{report['index_dir']}")
    print("=" * 60)


def save_report(report):
    """归档报告到 .ai-reports/"""
    report_path = REPORT_DIR / f"索引-{datetime.now().strftime('%Y%m%d-%H%M')}.md"

    lines = [
        f"# 知识库 AI-RAG 第 1 层建索引报告",
        "",
        f"- 建索引时间：{report['built_at']}",
        f"- 模型：{report['model']}",
        f"- 向量维度：{report['vector_dim']}",
        f"- 总笔记数：{report['total_notes']}",
        f"- 成功索引：{report['indexed_notes']}",
        f"- 跳过笔记：{report['skipped_notes']}",
        f"- 索引目录：`{report['index_dir']}`",
        "",
        "## 已索引笔记清单",
        "",
        "| # | 笔记路径 | 字数 | 最后修改 |",
        "|---|---------|------|---------|",
    ]
    for i, note in enumerate(report["notes_detail"], 1):
        lines.append(f"| {i} | {note['path']} | {note['size']} | {note['mtime'][:19]} |")

    lines.extend([
        "",
        "---",
        "",
        f"> 报告生成：kb_indexer.py（v3.2）",
        f"> 派生数据，可重建（删除 {report['index_dir']}/ 后重跑本脚本）",
    ])

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"\n📁 报告已归档：{report_path.relative_to(PROJECT_ROOT)}")


def main():
    print("=" * 60)
    print("🔧 kb_indexer.py —— 知识库 AI-RAG 第 1 层语义索引")
    print("=" * 60)
    print(f"项目根目录：{PROJECT_ROOT}")
    print(f"知识库目录：{KB_ROOT}")
    print(f"索引目录：{INDEX_DIR}")
    print()

    ensure_index_dir()

    # 列笔记
    notes = list_note_files()
    if not notes:
        print("❌ 知识库下没有 .md 笔记，退出")
        sys.exit(1)
    print(f"📚 发现 {len(notes)} 篇笔记")

    # 加载模型
    model = load_model()

    # 建索引
    vectors, metadata = build_index(notes, model)

    if not vectors:
        print("❌ 没有成功索引任何笔记，退出")
        sys.exit(1)

    # 存储
    save_index(vectors, metadata)

    # 生成报告
    report = build_report(notes, vectors, metadata)
    print_report(report)
    save_report(report)

    print("\n✅ 建索引完成！")
    print("   下次可以运行 python tools/kb_recommender.py 跑跨笔记推荐")


if __name__ == "__main__":
    main()
