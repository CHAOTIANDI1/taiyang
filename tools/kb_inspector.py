"""
kb_inspector.py —— 知识库 AI-RAG 第 3 层自动巡检脚本（v3.1 Python 版）

功能：
    扫描 知识库/ 下所有 .md 笔记，输出 5 项巡检报告：
    1. 断链检测：[[文件名]] 目标不存在
    2. 重复定义：多篇笔记概念段标题重复
    3. 过时检测：笔记 30 天没动
    4. 准则不达标：缺"本游戏实例"/"本实例"段 / 概念段少于 2 个例子
    5. 三项不一致：笔记描述与实际代码不符（仅警告，需 AI 人工介入）

运行方式：
    cd D:\\taiyang
    python tools/kb_inspector.py

报告输出：
    1. 控制台打印
    2. 归档到 知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md

设计原则（AGENTS.md §20.11）：
    - 知识库工具用 Python 写，独立于游戏 GDScript 技术栈
    - 不引用 scripts/ 下任何游戏代码
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

# 项目根目录（kb_inspector.py 在 tools/ 下，父目录就是项目根）
PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_ROOT = PROJECT_ROOT / "知识库"
REPORT_DIR = KB_ROOT / ".ai-reports"
INDEX_FILE = KB_ROOT / "00-索引.md"

# 巡检阈值
OUTDATED_DAYS = 30


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


def read_note(path):
    """读取笔记内容，返回文本"""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        return f"[读取失败：{e}]"


def check_broken_links(notes):
    """检查 1：断链检测——[[文件名]] 目标是否存在

    v3.2 修复：
    1. 把 00-索引.md 加入断链检测目标集（list_note_files 排除它，但断链检测应包含）
    2. 跳过反引号 `内的 [[xxx]]`（避免把示例文字误判为断链）
    """
    issues = []
    all_note_names = {p.stem for p in notes}  # 不含扩展名
    # 00-索引.md 被 list_note_files 排除（不做自身巡检），但其他笔记可以链接它
    all_note_names.add("00-索引")

    link_pattern = re.compile(r"\[\[([^\]]+)\]\]")
    # 匹配反引号内的内容（单行 `xxx` 或多行 ```xxx```），用于跳过示例文字
    inline_code_pattern = re.compile(r"`[^`]*`")

    for note in notes:
        content = read_note(note)
        # 移除反引号内的内容，避免把 `[[xxx]]` 示例文字误判为断链
        content_for_scan = inline_code_pattern.sub("", content)
        for match in link_pattern.finditer(content_for_scan):
            link_target = match.group(1).strip()
            # 处理 [[文件名#段落]] 这种带段落跳转
            base_name = link_target.split("#")[0].strip()
            if not base_name:
                continue
            # 检查是否存在（按 stem 匹配，不含 .md）
            if base_name not in all_note_names:
                issues.append({
                    "source": note.name,
                    "target": link_target,
                    "severity": "🔴 高",
                    "type": "断链"
                })
    return issues


def check_duplicate_concepts(notes):
    """检查 2：重复定义——多篇笔记 ## 概念 段标题重复

    v3.2 修复：
    1. 跳过"反例"开头的标题（v2.7 准则"反例 vs 正例"段的衍生标题，如"反例 vs 正例（常见错误）"）
    2. 跳过"⚠️"开头的标题（声明段，非概念段，如"⚠️ v3.1 知识库独立声明"）
    """
    issues = []
    concept_titles = {}  # {标题: [笔记名列表]}

    for note in notes:
        content = read_note(note)
        # 找 ## 开头但不是固定 8 段的标题
        fixed_sections = {"## 本游戏实例", "## 本实例", "## 概念", "## 功能",
                          "## 运作方式", "## 原理", "## 优势",
                          "## 使用场景", "## 反例", "## 反例 vs 正例",
                          "## 反例 vs 正例对照", "## 关联"}
        for match in re.finditer(r"^##\s+(.+)$", content, re.MULTILINE):
            title = match.group(1).strip()
            # v3.2：跳过 v2.7 准则 8 段的衍生标题 + 声明段
            # v3.2 追加：跳过"使用场景"和"MVP"开头（"MVP 范围"是使用场景的衍生段）
            if title.startswith(("概念", "本游戏实例", "本实例", "反例", "⚠️", "使用场景", "MVP")):
                continue
            if f"## {title}" in fixed_sections:
                continue
            concept_titles.setdefault(title, []).append(note.name)

    for title, sources in concept_titles.items():
        if len(sources) > 1:
            issues.append({
                "title": title,
                "sources": sources,
                "severity": "🔴 高",
                "type": "重复定义"
            })
    return issues


def check_outdated(notes):
    """检查 3：过时检测——笔记 30 天没动"""
    issues = []
    threshold = datetime.now() - timedelta(days=OUTDATED_DAYS)

    for note in notes:
        mtime = datetime.fromtimestamp(note.stat().st_mtime)
        days_ago = (datetime.now() - mtime).days
        if mtime < threshold:
            issues.append({
                "file": note.name,
                "days": days_ago,
                "severity": "🟡 中",
                "type": "过时"
            })
    return issues


def check_v27_compliance(notes):
    """检查 4：准则不达标——缺'本游戏实例'/'本实例'段 / 概念段少于 2 个例子"""
    issues = []

    for note in notes:
        content = read_note(note)
        # 检查是否有"本游戏实例"或"本实例"段
        has_instance = ("## 本游戏实例" in content) or ("## 本实例" in content)
        if not has_instance:
            issues.append({
                "file": note.name,
                "issue": "缺'本游戏实例'/'本实例'段（v2.7 准则）",
                "severity": "🟡 中",
                "type": "准则不达标"
            })

        # 检查概念段例子数（### 开头的小标题）
        concept_section = re.search(
            r"## 概念\s*$(.*?)(?=^## )", content, re.MULTILINE | re.DOTALL
        )
        if concept_section:
            sub_examples = re.findall(r"^###\s+\d+\.", concept_section.group(1), re.MULTILINE)
            if len(sub_examples) < 2:
                issues.append({
                    "file": note.name,
                    "issue": f"概念段例子数 {len(sub_examples)}，应≥2（v2.7 准则）",
                    "severity": "🟡 中",
                    "type": "准则不达标"
                })

    return issues


def check_three_way_consistency(notes):
    """检查 5：三项不一致——笔记描述与实际代码不符（仅警告，需 AI 介入）

    本项只能做粗筛：检查笔记中提到的 .gd / .json 文件名是否实际存在。
    深度语义检查需要 AI 介入。
    """
    issues = []
    scripts_dir = PROJECT_ROOT / "scripts"
    data_dir = PROJECT_ROOT / "data"

    existing_files = set()
    if scripts_dir.exists():
        for f in scripts_dir.rglob("*.gd"):
            existing_files.add(f.name)
    if data_dir.exists():
        for f in data_dir.rglob("*.json"):
            existing_files.add(f.name)

    file_pattern = re.compile(r"`([\w_]+\.(?:gd|json))`")

    for note in notes:
        content = read_note(note)
        for match in file_pattern.finditer(content):
            fname = match.group(1)
            if fname not in existing_files:
                # 可能是未来要创建的文件，只标记为中风险
                issues.append({
                    "file": note.name,
                    "issue": f"引用了不存在的文件：{fname}",
                    "severity": "🟡 中",
                    "type": "三项不一致"
                })

    return issues


def build_report():
    """生成 markdown 报告"""
    notes = list_note_files()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    broken_links = check_broken_links(notes)
    duplicates = check_duplicate_concepts(notes)
    outdated = check_outdated(notes)
    v27_issues = check_v27_compliance(notes)
    consistency = check_three_way_consistency(notes)

    report = []
    report.append(f"# 知识库巡检报告")
    report.append(f"")
    report.append(f"> 生成时间：{timestamp}")
    report.append(f"> 巡检脚本：tools/kb_inspector.py（v3.1 Python 版）")
    report.append(f"> 笔记总数：{len(notes)}")
    report.append(f"")
    report.append(f"---")
    report.append(f"")
    report.append(f"## 巡检汇总")
    report.append(f"")
    report.append(f"| # | 巡检项 | 数量 | 严重度 |")
    report.append(f"|---|--------|:----:|:------:|")
    report.append(f"| 1 | 断链检测 | {len(broken_links)} | 🔴 高 |")
    report.append(f"| 2 | 重复定义 | {len(duplicates)} | 🔴 高 |")
    report.append(f"| 3 | 过时检测（>{OUTDATED_DAYS}天） | {len(outdated)} | 🟡 中 |")
    report.append(f"| 4 | 准则不达标 | {len(v27_issues)} | 🟡 中 |")
    report.append(f"| 5 | 三项不一致（粗筛） | {len(consistency)} | 🟡 中 |")
    report.append(f"")

    # 1. 断链
    if broken_links:
        report.append(f"## 1. 断链检测（🔴 高）")
        report.append(f"")
        report.append(f"| 来源笔记 | 断链目标 |")
        report.append(f"|----------|----------|")
        for issue in broken_links:
            report.append(f"| {issue['source']} | [[{issue['target']}]] |")
        report.append(f"")

    # 2. 重复定义
    if duplicates:
        report.append(f"## 2. 重复定义（🔴 高）")
        report.append(f"")
        report.append(f"| 重复标题 | 出现在 |")
        report.append(f"|----------|---------|")
        for issue in duplicates:
            report.append(f"| {issue['title']} | {', '.join(issue['sources'])} |")
        report.append(f"")

    # 3. 过时
    if outdated:
        report.append(f"## 3. 过时检测（🟡 中）")
        report.append(f"")
        report.append(f"| 笔记 | 距上次修改（天） |")
        report.append(f"|------|----------------:|")
        for issue in sorted(outdated, key=lambda x: -x["days"]):
            report.append(f"| {issue['file']} | {issue['days']} |")
        report.append(f"")

    # 4. 准则不达标
    if v27_issues:
        report.append(f"## 4. 准则不达标（🟡 中）")
        report.append(f"")
        report.append(f"| 笔记 | 问题 |")
        report.append(f"|------|------|")
        for issue in v27_issues:
            report.append(f"| {issue['file']} | {issue['issue']} |")
        report.append(f"")

    # 5. 三项不一致
    if consistency:
        report.append(f"## 5. 三项不一致粗筛（🟡 中）")
        report.append(f"")
        report.append(f"> 本项仅检查笔记引用的 .gd/.json 文件名是否存在。深度语义检查需 AI 介入。")
        report.append(f"")
        report.append(f"| 笔记 | 问题 |")
        report.append(f"|------|------|")
        for issue in consistency:
            report.append(f"| {issue['file']} | {issue['issue']} |")
        report.append(f"")

    if not (broken_links or duplicates or outdated or v27_issues or consistency):
        report.append(f"## ✅ 全部通过")
        report.append(f"")
        report.append(f"所有巡检项均无问题。")
        report.append(f"")

    report.append(f"---")
    report.append(f"")
    report.append(f"## 处理建议")
    report.append(f"")
    report.append(f"- 🔴 高严重度：必须走闸门 C 差异审计 + 用户确认后修复")
    report.append(f"- 🟡 中严重度：抽查确认后修复，可在下次自然触及时回填")
    report.append(f"- 三项不一致深度检查：建议跑 tools/sync_advisor.py 看代码改动同步建议")
    report.append(f"")

    return "\n".join(report)


def print_report(report):
    """控制台打印报告"""
    print()
    print("=" * 60)
    print("  知识库巡检报告（kb_inspector.py v3.1）")
    print("=" * 60)
    print()
    print(report)
    print("=" * 60)


def save_report(report):
    """保存报告到 知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md"""
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M")
    report_path = REPORT_DIR / f"巡检-{timestamp}.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)
    return report_path


def main():
    """主入口"""
    if not KB_ROOT.exists():
        print(f"[错误] 知识库目录不存在：{KB_ROOT}")
        sys.exit(1)

    print(f"[信息] 巡检知识库：{KB_ROOT}")
    print(f"[信息] 笔记目录扫描中...")

    report = build_report()
    print_report(report)

    report_path = save_report(report)
    print(f"[信息] 报告已归档：{report_path}")
    print(f"[信息] 提示：该路径已在 .gitignore 排除，不会进 git")


if __name__ == "__main__":
    main()
