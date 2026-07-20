"""
kb_recommender.py —— 知识库 AI-RAG 第 4 层跨笔记推理脚本（v3.2 新增）

功能：
    复用第 1 层建的索引（vectors.db + index_meta.json），
    计算笔记间的余弦相似度，对每篇笔记推荐 Top-K 最相似但无双链的笔记。

运行方式：
    cd D:\\taiyang
    python tools/kb_recommender.py

前置条件：
    先运行 python tools/kb_indexer.py 建索引

输出：
    1. 知识库/.ai-reports/推荐-YYYYMMDD-HHMM.md —— 推荐报告
    2. 控制台打印进度和摘要

设计原则（AGENTS.md §20.11）：
    - 知识库工具用 Python 写，独立于游戏 GDScript 技术栈
    - 不引用 scripts/ 下任何游戏代码
    - 跨项目复用：换项目时整个 tools/ 目录原样搬走

v3.2 凌驾性原则落地：
    本脚本复用第 1 层 BGE-M3 索引，用余弦相似度计算笔记间语义相似度，
    是知识库独立视角下的最优方案（非轻量版）。
    详见知识库 57-AI滑坡识别（游戏MVP与知识库独立性的边界混淆）.md
"""

import json
import re
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

# 项目根目录（kb_recommender.py 在 tools/ 下，父目录就是项目根）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"
INDEX_DIR = KB_ROOT / ".ai-index"
REPORT_DIR = KB_ROOT / ".ai-reports"

# 推荐参数
TOP_K = 5              # 每篇笔记推荐最相似的 K 篇
MIN_SIMILARITY = 0.5   # 最低相似度阈值（低于此值不推荐）

# 索引文件路径
DB_PATH = INDEX_DIR / "vectors.db"
META_PATH = INDEX_DIR / "index_meta.json"


def check_index_exists():
    """检查索引是否已建立"""
    if not INDEX_DIR.exists() or not DB_PATH.exists() or not META_PATH.exists():
        print("❌ 索引未建立，请先运行：python tools/kb_indexer.py")
        sys.exit(1)


def load_metadata():
    """加载索引元数据"""
    with open(META_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def load_vectors(meta):
    """从 SQLite-vec 加载所有向量

    v3.2 修复：sqlite-vec 查询返回二进制 blob，不是 JSON 字符串。
    用 numpy.frombuffer 解析二进制为 float 列表。
    """
    try:
        import sqlite3
        import sqlite_vec
        import numpy as np
    except ImportError as e:
        print("❌ 依赖未装：sqlite-vec 或 numpy")
        print("   请先运行：pip install -r tools/requirements.txt")
        print(f"   错误详情：{e}")
        sys.exit(1)

    db = sqlite3.connect(str(DB_PATH))
    db.enable_load_extension(True)
    sqlite_vec.load(db)

    # 查询所有向量（sqlite-vec 返回二进制 blob，用 numpy 解析）
    cursor = db.execute("SELECT rowid, embedding FROM notes_vec ORDER BY rowid")
    vectors = {}
    for rowid, embedding_blob in cursor:
        vectors[rowid] = np.frombuffer(embedding_blob, dtype=np.float32).tolist()
    db.close()

    return vectors


def compute_similarity_matrix(vectors):
    """计算所有笔记间的余弦相似度矩阵"""
    try:
        import numpy as np
    except ImportError as e:
        print("❌ 依赖未装：numpy")
        print("   请先运行：pip install -r tools/requirements.txt")
        print(f"   错误详情：{e}")
        sys.exit(1)

    # rowid 列表（1-based）
    rowids = sorted(vectors.keys())
    n = len(rowids)

    # 构建向量矩阵（n × dim）
    dim = len(vectors[rowids[0]])
    matrix = np.zeros((n, dim))
    for i, rid in enumerate(rowids):
        matrix[i] = vectors[rid]

    # BGE-M3 已经 normalize_embeddings=True，所以余弦相似度 = 点积
    sim_matrix = np.dot(matrix, matrix.T)

    return rowids, sim_matrix


def find_existing_links(notes_meta):
    """扫描所有笔记，找出已有的 [[文件名]] 双链关系"""
    # 建立 笔记名 → rowid 映射
    name_to_rowid = {m["name"]: m["rowid"] for m in notes_meta}

    # 扫描每篇笔记的双链
    link_pattern = re.compile(r"\[\[([^\]]+)\]\]")
    existing_links = {}  # rowid → set of linked rowids

    for meta in notes_meta:
        note_path = KB_ROOT / meta["path"]
        existing_links[meta["rowid"]] = set()

        if not note_path.exists():
            continue

        try:
            with open(note_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue

        # 找出所有 [[xxx]] 链接
        for match in link_pattern.finditer(content):
            link_name = match.group(1).strip()
            # 链接可能是 "文件名" 或 "文件名|显示文本"
            if "|" in link_name:
                link_name = link_name.split("|")[0].strip()
            # 去掉可能的扩展名
            if link_name.endswith(".md"):
                link_name = link_name[:-3]

            if link_name in name_to_rowid:
                existing_links[meta["rowid"]].add(name_to_rowid[link_name])

    return existing_links


def find_recommendations(rowids, sim_matrix, notes_meta, existing_links, top_k=TOP_K):
    """对每篇笔记，找出 Top-K 最相似但无双链的笔记"""
    # rowid → meta 映射
    rowid_to_meta = {m["rowid"]: m for m in notes_meta}

    recommendations = []
    for i, rid in enumerate(rowids):
        # 获取相似度排序（降序）
        sims = sim_matrix[i]
        # argsort 默认升序，[::-1] 翻转为降序
        sorted_indices = sims.argsort()[::-1]

        recs = []
        for idx in sorted_indices:
            other_rid = rowids[idx]

            # 跳过自己
            if other_rid == rid:
                continue

            # 跳过低相似度
            sim = float(sims[idx])
            if sim < MIN_SIMILARITY:
                continue

            # 跳过已有双链的
            if other_rid in existing_links.get(rid, set()):
                continue

            recs.append({
                "rowid": other_rid,
                "path": rowid_to_meta[other_rid]["path"],
                "name": rowid_to_meta[other_rid]["name"],
                "similarity": round(sim, 4),
            })

            if len(recs) >= top_k:
                break

        if recs:
            recommendations.append({
                "note": {
                    "rowid": rid,
                    "path": rowid_to_meta[rid]["path"],
                    "name": rowid_to_meta[rid]["name"],
                },
                "recommendations": recs,
            })

    return recommendations


def build_report(meta, recommendations):
    """生成推荐报告"""
    return {
        "generated_at": datetime.now().isoformat(),
        "model": meta["model"],
        "vector_dim": meta["vector_dim"],
        "total_notes": meta["note_count"],
        "notes_with_recs": len(recommendations),
        "total_recs": sum(len(r["recommendations"]) for r in recommendations),
        "top_k": TOP_K,
        "min_similarity": MIN_SIMILARITY,
        "recommendations": recommendations,
    }


def print_report(report):
    """控制台打印报告摘要"""
    print("\n" + "=" * 60)
    print("📋 跨笔记推荐报告")
    print("=" * 60)
    print(f"生成时间：{report['generated_at']}")
    print(f"模型：{report['model']}")
    print(f"总笔记数：{report['total_notes']}")
    print(f"有推荐的笔记数：{report['notes_with_recs']}")
    print(f"推荐总数：{report['total_recs']}")
    print(f"每篇 Top-K：{report['top_k']}")
    print(f"最低相似度阈值：{report['min_similarity']}")
    print("=" * 60)

    if report["recommendations"]:
        print("\n📊 推荐摘要（前 10 篇）：")
        for i, rec in enumerate(report["recommendations"][:10], 1):
            print(f"\n  [{i}] {rec['note']['name']}（{rec['note']['path']}）")
            for j, r in enumerate(rec["recommendations"], 1):
                print(f"      {j}. [[{r['name']}]] 相似度 {r['similarity']}")
                print(f"         路径：{r['path']}")


def save_report(report):
    """归档报告到 .ai-reports/"""
    report_path = REPORT_DIR / f"推荐-{datetime.now().strftime('%Y%m%d-%H%M')}.md"

    lines = [
        f"# 知识库 AI-RAG 第 4 层跨笔记推荐报告",
        "",
        f"- 生成时间：{report['generated_at']}",
        f"- 模型：{report['model']}",
        f"- 向量维度：{report['vector_dim']}",
        f"- 总笔记数：{report['total_notes']}",
        f"- 有推荐的笔记数：{report['notes_with_recs']}",
        f"- 推荐总数：{report['total_recs']}",
        f"- 每篇 Top-K：{report['top_k']}",
        f"- 最低相似度阈值：{report['min_similarity']}",
        "",
        "## 推荐详情",
        "",
    ]

    for i, rec in enumerate(report["recommendations"], 1):
        lines.append(f"### {i}. [[{rec['note']['name']}]]")
        lines.append("")
        lines.append(f"路径：`{rec['note']['path']}`")
        lines.append("")
        lines.append("| # | 推荐笔记 | 相似度 | 路径 |")
        lines.append("|---|---------|--------|------|")
        for j, r in enumerate(rec["recommendations"], 1):
            lines.append(f"| {j} | [[{r['name']}]] | {r['similarity']} | `{r['path']}` |")
        lines.append("")

    lines.extend([
        "---",
        "",
        "> 报告生成：kb_recommender.py（v3.2）",
        "> 推荐依据：BGE-M3 embedding + 余弦相似度 + 已有双链排除",
        "> 派生数据，可重建（重跑本脚本即可）",
        "> 处理流程：用户确认后，AI 走闸门 C 加双链（不自动写入）",
    ])

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"\n📁 报告已归档：{report_path.relative_to(PROJECT_ROOT)}")


def main():
    print("=" * 60)
    print("🔧 kb_recommender.py —— 知识库 AI-RAG 第 4 层跨笔记推荐")
    print("=" * 60)
    print(f"项目根目录：{PROJECT_ROOT}")
    print(f"知识库目录：{KB_ROOT}")
    print(f"索引目录：{INDEX_DIR}")
    print()

    # 检查索引
    check_index_exists()

    # 加载元数据
    print("📖 加载索引元数据 ...")
    meta = load_metadata()
    print(f"   ✅ 索引建立于 {meta['built_at'][:19]}，共 {meta['note_count']} 篇笔记")
    print(f"   模型：{meta['model']}，维度：{meta['vector_dim']}")

    # 加载向量
    print("\n📦 加载向量数据 ...")
    vectors = load_vectors(meta)
    print(f"   ✅ 加载 {len(vectors)} 个向量")

    # 计算相似度矩阵
    print("\n🧮 计算余弦相似度矩阵 ...")
    rowids, sim_matrix = compute_similarity_matrix(vectors)
    print(f"   ✅ 矩阵大小：{sim_matrix.shape}")

    # 找已有双链
    print("\n🔗 扫描已有双链关系 ...")
    existing_links = find_existing_links(meta["notes"])
    total_links = sum(len(v) for v in existing_links.values())
    print(f"   ✅ 共发现 {total_links} 条双链")

    # 找推荐
    print(f"\n🎯 找推荐（Top-{TOP_K}，最低相似度 {MIN_SIMILARITY}）...")
    recommendations = find_recommendations(rowids, sim_matrix, meta["notes"], existing_links)
    print(f"   ✅ {len(recommendations)} 篇笔记有推荐，共 {sum(len(r['recommendations']) for r in recommendations)} 条推荐")

    # 生成报告
    report = build_report(meta, recommendations)
    print_report(report)
    save_report(report)

    print("\n✅ 跨笔记推荐完成！")
    print("   下一步：用户确认推荐后，AI 走闸门 C 加双链（不自动写入）")


if __name__ == "__main__":
    main()
