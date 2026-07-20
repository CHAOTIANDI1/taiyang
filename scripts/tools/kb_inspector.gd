@tool
extends EditorScript
## KbInspector —— 知识库自动巡检工具（第 3 层）
## 在 Godot 编辑器内运行：菜单 > 文件 > 运行 > 选 kb_inspector.gd
## 或在脚本编辑器里按 Ctrl+Shift+X 运行
##
## 巡检 5 项（按 AGENTS.md §20.4）：
##   1. 断链检测：[[文件名]] 目标不存在 → 🔴 高
##   2. 重复定义：多篇笔记概念段标题重复 → 🔴 高
##   3. 过时检测：笔记 30 天没动 + 相关代码近期改过 → 🟡 中（脚本提示，AI 复查）
##   4. 准则不达标：缺"本游戏实例"段 / 概念段少于 2 个例子 → 🟡 中
##   5. 三项不一致：笔记描述与实际代码不符 → 🔴 高（AI 介入，脚本不自动判）
##
## 输出：控制台打印 + 写入 知识库/.ai-reports/巡检-YYYYMMDD-HHMM.md

const KB_ROOT: String = "res://知识库/"
const REPORT_DIR: String = "res://知识库/.ai-reports/"
const OUTDATED_DAYS: int = 30


static func _run() -> void:
	var report: String = _build_report()
	_print_report(report)
	_save_report(report)


static func _build_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# 知识库巡检报告")
	lines.append("")
	lines.append("> 生成时间：%s" % Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), false))
	lines.append("> 巡检依据：AGENTS.md §20.4 第 3 层自动巡检")
	lines.append("> 巡检范围：%s" % KB_ROOT)
	lines.append("")
	var files: PackedStringArray = _list_note_files()
	lines.append("## 巡检概览")
	lines.append("")
	lines.append("| 项 | 数量 |")
	lines.append("|---|------|")
	lines.append("| 笔记总数 | %d |" % files.size())
	lines.append("")

	lines.append("## 1. 断链检测（🔴 高优先级）")
	lines.append("")
	var broken_links: Array = _check_broken_links(files)
	if broken_links.is_empty():
		lines.append("✅ 无断链")
	else:
		for link in broken_links:
			lines.append("- 🔴 `%s` 引用了不存在的 `[[%s]]`" % [link.source, link.target])
	lines.append("")

	lines.append("## 2. 重复定义检测（🔴 高优先级）")
	lines.append("")
	var duplicates: Array = _check_duplicate_concepts(files)
	if duplicates.is_empty():
		lines.append("✅ 无重复定义")
	else:
		for dup in duplicates:
			var file_list: String = ""
			for f in dup.files:
				file_list += f + ", "
			file_list = file_list.trim_suffix(", ")
			lines.append("- 🔴 概念 `%s` 在多篇笔记出现：%s" % [dup.concept, file_list])
	lines.append("")

	lines.append("## 3. 过时检测（🟡 中优先级）")
	lines.append("")
	var outdated: Array = _check_outdated(files)
	if outdated.is_empty():
		lines.append("✅ 无过时笔记")
	else:
		for item in outdated:
			lines.append("- 🟡 `%s` 最后更新 %s（超过 %d 天）" % [item.file, item.last_update, OUTDATED_DAYS])
	lines.append("")

	lines.append("## 4. 准则不达标检测（🟡 中优先级）")
	lines.append("")
	var non_compliant: Array = _check_v27_compliance(files)
	if non_compliant.is_empty():
		lines.append("✅ 全部笔记符合 v2.7 准则")
	else:
		for item in non_compliant:
			lines.append("- 🟡 `%s`：%s" % [item.file, item.issue])
	lines.append("")

	lines.append("## 5. 三项不一致检测（🔴 高优先级，需 AI 介入）")
	lines.append("")
	lines.append("⚠️ 本项需 AI 人工复查：对照笔记描述的代码与实际 scripts/ 代码是否一致。")
	lines.append("建议：完成里程碑时由 AI 走闸门 C 差异审计。")
	lines.append("")

	lines.append("---")
	lines.append("")
	lines.append("**巡检结论**：")
	var total_issues: int = broken_links.size() + duplicates.size() + outdated.size() + non_compliant.size()
	if total_issues == 0:
		lines.append("✅ PASS：自动巡检 4 项全过（第 5 项需 AI 人工复查）")
	else:
		lines.append("⚠️ FAIL：发现 %d 个问题（详见上文）" % total_issues)
	lines.append("")
	lines.append("**下一步建议**：")
	lines.append("1. 🔴 高优先级问题立即走闸门 C 修复")
	lines.append("2. 🟡 中优先级问题下次自然触及时回填")
	lines.append("3. 第 5 项三项不一致由 AI 在下次会话开始时复查")
	return "\n".join(lines)


static func _list_note_files() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(KB_ROOT)
	if dir == null:
		push_error("KbInspector: 无法打开知识库目录 %s" % KB_ROOT)
		return PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".md") and file != "00-索引.md":
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	return files


static func _read_note(file_name: String) -> String:
	var path: String = KB_ROOT + file_name
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func _check_broken_links(files: PackedStringArray) -> Array:
	var results: Array = []
	var regex: RegEx = RegEx.new()
	regex.compile("\\[\\[([^\\]]+)\\]\\]")
	for source_file in files:
		var content: String = _read_note(source_file)
		if content.is_empty():
			continue
		var matches: Array = regex.search_all(content)
		for m in matches:
			var target: String = m.get_string(1)
			if target.begins_with("待写"):
				continue
			var target_file: String = target if target.ends_with(".md") else target + ".md"
			if not files.has(target_file):
				results.append({"source": source_file, "target": target})
	return results


static func _check_duplicate_concepts(files: PackedStringArray) -> Array:
	var concept_map: Dictionary = {}
	for file_name in files:
		var content: String = _read_note(file_name)
		if content.is_empty():
			continue
		var title_line: String = ""
		for line in content.split("\n"):
			if line.begins_with("# ") and title_line == "":
				title_line = line.substr(2).strip_edges()
				break
		if title_line != "":
			if not concept_map.has(title_line):
				concept_map[title_line] = []
			concept_map[title_line].append(file_name)
	var results: Array = []
	for concept in concept_map.keys():
		if concept_map[concept].size() > 1:
			results.append({"concept": concept, "files": concept_map[concept]})
	return results


static func _check_outdated(files: PackedStringArray) -> Array:
	var results: Array = []
	var now_unix: int = int(Time.get_unix_time_from_system())
	var threshold: int = OUTDATED_DAYS * 24 * 3600
	for file_name in files:
		var path: String = KB_ROOT + file_name
		var modified_unix: int = int(FileAccess.get_modified_time(path))
		var age: int = now_unix - modified_unix
		if age > threshold:
			var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(modified_unix)
			var date_str: String = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
			results.append({"file": file_name, "last_update": date_str})
	return results


static func _check_v27_compliance(files: PackedStringArray) -> Array:
	var results: Array = []
	for file_name in files:
		var content: String = _read_note(file_name)
		if content.is_empty():
			continue
		if not content.find("## 本游戏实例") > 0:
			results.append({"file": file_name, "issue": "缺'本游戏实例'段（v2.7 准则）"})
			continue
		var concept_section_start: int = content.find("## 概念")
		if concept_section_start < 0:
			results.append({"file": file_name, "issue": "缺'概念'段（v2.7 准则）"})
			continue
		var concept_section_end: int = content.find("\n## ", concept_section_start + 8)
		if concept_section_end < 0:
			concept_section_end = content.length()
		var concept_content: String = content.substr(concept_section_start, concept_section_end - concept_section_start)
		var example_count: int = concept_content.count("### ")
		if example_count < 2:
			results.append({"file": file_name, "issue": "概念段例子不足 2 个（实际 %d，v2.7 准则要求 2 个本项目专属例子）" % example_count})
	return results


static func _print_report(report: String) -> void:
	print("\n" + report + "\n")


static func _save_report(report: String) -> void:
	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		return
	if not dir.dir_exists(REPORT_DIR.substr("res://".length())):
		dir.make_dir_recursive(REPORT_DIR.substr("res://".length()))
	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d%02d%02d-%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	var path: String = REPORT_DIR + "巡检-" + timestamp + ".md"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("KbInspector: 无法写入报告 %s" % path)
		return
	file.store_string(report)
	file.close()
	print("[KbInspector] 巡检报告已保存：%s" % path)
