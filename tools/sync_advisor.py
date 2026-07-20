"""
sync_advisor.py —— 知识库 AI-RAG 第 5 层项目同步脚本（v3.1 Python 版）

功能：
    扫描代码/数据/文档/笔记的修改时间，找出"代码改了但笔记没改"的情况，
    生成同步建议报告，供 AI 走闸门 C 决策。

运行方式：
    cd D:\\taiyang
    python tools/sync_advisor.py

报告输出：
    1. 控制台打印
    2. 归档到 知识库/.ai-reports/同步-YYYYMMDD-HHMM.md

设计原则（AGENTS.md §20.11）：
    - 知识库工具用 Python 写，独立于游戏 GDScript 技术栈
    - 只读 scripts/data/docs/ 等目录的文件信息，不引用任何代码
    - 跨项目复用：换项目时整个 tools/ 目录原样搬走
"""

import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Windows 控制台默认 GBK 编码，无法打印 emoji，强制改 UTF-8
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# 项目根目录
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"
REPORT_DIR = KB_ROOT / ".ai-reports"

# 扫描阈值
RECENT_DAYS = 7       # "最近改动"=7 天内
OUTDATED_DAYS = 30    # "长期没动"=30 天以上

# 扫描目录（相对项目根）
SCAN_DIRS = [
    ("scripts/", ".gd", "游戏代码"),
    ("data/", ".json", "数据文件"),
    ("docs/", ".md", "设计文档"),
]


def scan_recent_files(rel_dir, ext, label):
    """扫描某目录下 N 天内改动的文件"""
    abs_dir = PROJECT_ROOT / rel_dir
    if not abs_dir.exists():
        return []

    threshold = datetime.now() - timedelta(days=RECENT_DAYS)
    recent = []

    for f in abs_dir.rglob(f"*{ext}"):
        # 跳过 .godot/ 等隐藏目录
        if any(part.startswith(".") for part in f.relative_to(abs_dir).parts[:-1]):
            continue
        mtime = datetime.fromtimestamp(f.stat().st_mtime)
        if mtime > threshold:
            days_ago = (datetime.now() - mtime).days
            recent.append({
                "path": str(f.relative_to(PROJECT_ROOT)),
                "mtime": mtime.strftime("%Y-%m-%d"),
                "days": days_ago,
                "label": label
            })

    return sorted(recent, key=lambda x: -x["days"])


def scan_outdated_notes():
    """扫描 30 天以上没动的笔记"""
    if not KB_ROOT.exists():
        return []

    threshold = datetime.now() - timedelta(days=OUTDATED_DAYS)
    outdated = []

    for note in KB_ROOT.rglob("*.md"):
        # 跳过 00-索引.md（强制维护）和隐藏目录
        if note.name == "00-索引.md":
            continue
        if any(part.startswith(".") for part in note.relative_to(KB_ROOT).parts[:-1]):
            continue
        mtime = datetime.fromtimestamp(note.stat().st_mtime)
        if mtime < threshold:
            days = (datetime.now() - mtime).days
            outdated.append({
                "path": str(note.relative_to(PROJECT_ROOT)),
                "mtime": mtime.strftime("%Y-%m-%d"),
                "days": days,
                "label": "知识库笔记"
            })

    return sorted(outdated, key=lambda x: -x["days"])


def find_code_note_relations():
    """粗筛：找出最近改动的代码可能关联的笔记

    规则：扫描笔记中提到的 .gd/.json 文件名，
    如果该文件最近改动了，标记该笔记为"可能需要回填"。
    """
    if not KB_ROOT.exists():
        return []

    # 收集最近改动的代码文件名
    recent_code_names = set()
    for rel_dir, ext, _ in SCAN_DIRS:
        for f in (PROJECT_ROOT / rel_dir).rglob(f"*{ext}") if (PROJECT_ROOT / rel_dir).exists() else []:
            mtime = datetime.fromtimestamp(f.stat().st_mtime)
            if mtime > datetime.now() - timedelta(days=RECENT_DAYS):
                recent_code_names.add(f.name)

    if not recent_code_names:
        return []

    # 扫描每篇笔记，看是否引用了最近改动的代码文件
    relations = []
    file_pattern = re.compile(r"`([\w_]+\.(?:gd|json))`")

    for note in KB_ROOT.rglob("*.md"):
        if note.name == "00-索引.md":
            continue
        if any(part.startswith(".") for part in note.relative_to(KB_ROOT).parts[:-1]):
            continue
        try:
            content = note.read_text(encoding="utf-8")
        except Exception:
            continue

        referenced_recent = set()
        for match in file_pattern.finditer(content):
            fname = match.group(1)
            if fname in recent_code_names:
                referenced_recent.add(fname)

        if referenced_recent:
            note_mtime = datetime.fromtimestamp(note.stat().st_mtime)
            note_days = (datetime.now() - note_mtime).days
            # 如果笔记本身 7 天内没动 + 引用了 7 天内改动的代码，标记为待回填
            if note_days > RECENT_DAYS:
                relations.append({
                    "note": note.name,
                    "note_days": note_days,
                    "code_files": sorted(referenced_recent)
                })

    return relations


def build_report():
    """生成 markdown 报告"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    # 各目录最近改动
    recent_files = []
    for rel_dir, ext, label in SCAN_DIRS:
        recent_files.extend(scan_recent_files(rel_dir, ext, label))

    outdated_notes = scan_outdated_notes()
    relations = find_code_note_relations()

    report = []
    report.append(f"# 知识库同步建议报告")
    report.append(f"")
    report.append(f"> 生成时间：{timestamp}")
    report.append(f"> 同步脚本：tools/sync_advisor.py（v3.1 Python 版）")
    report.append(f"> 阈值：最近 {RECENT_DAYS} 天改动 / 笔记 {OUTDATED_DAYS} 天未动")
    report.append(f"")
    report.append(f"---")
    report.append(f"")
    report.append(f"## 汇总")
    report.append(f"")
    report.append(f"| 项 | 数量 |")
    report.append(f"|----|:----:|")
    report.append(f"| 最近 {RECENT_DAYS} 天改动的代码/数据/文档 | {len(recent_files)} |")
    report.append(f"| {OUTDATED_DAYS} 天以上未动的笔记 | {len(outdated_notes)} |")
    report.append(f"| 可能需要回填的笔记 | {len(relations)} |")
    report.append(f"")

    # 1. 最近改动
    if recent_files:
        report.append(f"## 1. 最近 {RECENT_DAYS} 天改动（需关注笔记是否同步）")
        report.append(f"")
        report.append(f"| 类型 | 路径 | 上次修改 | 距今（天） |")
        report.append(f"|------|------|----------|-----------:|")
        for f in recent_files:
            report.append(f"| {f['label']} | {f['path']} | {f['mtime']} | {f['days']} |")
        report.append(f"")

    # 2. 过时笔记
    if outdated_notes:
        report.append(f"## 2. {OUTDATED_DAYS} 天以上未动的笔记（建议抽查是否过时）")
        report.append(f"")
        report.append(f"| 笔记 | 上次修改 | 距今（天） |")
        report.append(f"|------|----------|-----------:|")
        for note in outdated_notes[:30]:  # 最多列 30 条
            report.append(f"| {note['path']} | {note['mtime']} | {note['days']} |")
        if len(outdated_notes) > 30:
            report.append(f"| ... 共 {len(outdated_notes)} 条，已省略 {len(outdated_notes) - 30} 条 | | |")
        report.append(f"")

    # 3. 代码-笔记关联建议
    if relations:
        report.append(f"## 3. 代码-笔记关联建议（🟡 待回填）")
        report.append(f"")
        report.append(f"> 以下笔记引用了最近改动的代码文件，但笔记本身 {RECENT_DAYS} 天内没动过，建议回填。")
        report.append(f">")
        report.append(f"> **修复流程**：走闸门 C 差异审计 → 用户确认 → AI 回填笔记 → 闸门 B 验收")
        report.append(f"")
        report.append(f"| 笔记 | 引用的最近改动代码 | 笔记未动（天） |")
        report.append(f"|------|---------------------|---------------:|")
        for r in relations:
            code_list = ", ".join(f"`{c}`" for c in r["code_files"])
            report.append(f"| {r['note']} | {code_list} | {r['note_days']} |")
        report.append(f"")

    if not (recent_files or outdated_notes or relations):
        report.append(f"## ✅ 全部通过")
        report.append(f"")
        report.append(f"没有发现需要同步的项目。")
        report.append(f"")

    report.append(f"---")
    report.append(f"")
    report.append(f"## 处理建议")
    report.append(f"")
    report.append(f"- 第 1 项：AI 抽查最近改动的代码，判断是否需要回填相关笔记")
    report.append(f"- 第 2 项：抽查过时笔记，判断是否仍准确（不一定要改）")
    report.append(f"- 第 3 项：🟡 必须走闸门 C 差异审计 + 用户确认后回填")
    report.append(f"")

    return "\n".join(report)


def print_report(report):
    """控制台打印报告"""
    print()
    print("=" * 60)
    print("  知识库同步建议报告（sync_advisor.py v3.1）")
    print("=" * 60)
    print()
    print(report)
    print("=" * 60)


def save_report(report):
    """保存报告到 知识库/.ai-reports/同步-YYYYMMDD-HHMM.md"""
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M")
    report_path = REPORT_DIR / f"同步-{timestamp}.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)
    return report_path


def main():
    """主入口"""
    if not KB_ROOT.exists():
        print(f"[错误] 知识库目录不存在：{KB_ROOT}")
        sys.exit(1)

    print(f"[信息] 扫描项目根目录：{PROJECT_ROOT}")
    print(f"[信息] 阈值：最近 {RECENT_DAYS} 天改动 / 笔记 {OUTDATED_DAYS} 天未动")
    print(f"[信息] 扫描中...")

    report = build_report()
    print_report(report)

    report_path = save_report(report)
    print(f"[信息] 报告已归档：{report_path}")
    print(f"[信息] 提示：该路径已在 .gitignore 排除，不会进 git")


if __name__ == "__main__":
    main()
