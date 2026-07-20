@tool
extends EditorScript
## SyncAdvisor —— 项目同步建议工具（第 5 层）
## 在 Godot 编辑器内运行：菜单 > 文件 > 运行 > 选 sync_advisor.gd
## 或在脚本编辑器里按 Ctrl+Shift+X 运行
##
## 功能（按 AGENTS.md §20.6）：
##   1. 扫描 scripts/ + data/ + docs/ 所有文件的最后修改时间
##   2. 扫描 知识库/ 所有笔记的最后修改时间
##   3. 找出"近期改动的代码"（7 天内）和"长期没动的笔记"（30 天以上）
##   4. 输出建议报告，提示 AI 复查哪些笔记可能需要回填
##
## 注意：本脚本不做精确的"代码 X 对应笔记 Y"映射（需 AI 介入）
##       只做数据收集 + 时间对比，AI 看完报告后做关联判断

const SCRIPTS_ROOT: String = "res://scripts/"
const DATA_ROOT: String = "res://data/"
const DOCS_ROOT: String = "res://docs/"
const KB_ROOT: String = "res://知识库/"
const REPORT_DIR: String = "res://知识库/.ai-reports/"
const RECENT_DAYS: int = 7
const OUTDATED_DAYS: int = 30


static func _run() -> void:
	var report: String = _build_report()
	_print_report(report)
	_save_report(report)


static func _build_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# 项目同步建议报告")
	lines.append("")
	lines.append("> 生成时间：%s" % Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), false))
	lines.append("> 依据：AGENTS.md §20.6 第 5 层项目同步")
	lines.append("> 范围：scripts/ + data/ + docs/ + 知识库/")
	lines.append("")

	var recent_code: Array = _scan_recent_files(SCRIPTS_ROOT, RECENT_DAYS)
	recent_code += _scan_recent_files(DATA_ROOT, RECENT_DAYS)
	recent_code += _scan_recent_files(DOCS_ROOT, RECENT_DAYS)

	var outdated_notes: Array = _scan_outdated_files(KB_ROOT, OUTDATED_DAYS)

	lines.append("## 1. 近期改动的代码/数据/文档（%d 天内）" % RECENT_DAYS)
	lines.append("")
	if recent_code.is_empty():
		lines.append("✅ 近期无改动")
	else:
		lines.append("| 文件 | 最后修改 |")
		lines.append("|------|---------|")
		for item in recent_code:
			lines.append("| `%s` | %s |" % [item.path, item.date])
	lines.append("")

	lines.append("## 2. 长期未更新的笔记（%d 天以上）" % OUTDATED_DAYS)
	lines.append("")
	if outdated_notes.is_empty():
		lines.append("✅ 无过时笔记")
	else:
		lines.append("| 笔记 | 最后修改 |")
		lines.append("|------|---------|")
		for item in outdated_notes:
			lines.append("| `%s` | %s |" % [item.path, item.date])
	lines.append("")

	lines.append("## 3. AI 复查建议")
	lines.append("")
	if recent_code.is_empty() and outdated_notes.is_empty():
		lines.append("✅ 无需复查")
	else:
		lines.append("⚠️ AI 需结合本报告做以下判断：")
		lines.append("")
		if not recent_code.is_empty():
			lines.append("### 3.1 近期改动的代码可能涉及的笔记")
			lines.append("AI 应对照下方代码列表，找出对应的知识库笔记，判断是否需要回填：")
			lines.append("")
			for item in recent_code:
				lines.append("- `%s`（%s 修改）" % [item.path, item.date])
			lines.append("")
		if not outdated_notes.is_empty():
			lines.append("### 3.2 长期未更新的笔记可能过时")
			lines.append("AI 应抽查下方笔记，确认内容是否仍与代码一致（走闸门 C 差异审计）：")
			lines.append("")
			for item in outdated_notes:
				lines.append("- `%s`（%s 修改）" % [item.path, item.date])
			lines.append("")

	lines.append("---")
	lines.append("")
	lines.append("**报告说明**：")
	lines.append("- 本报告由脚本自动生成，只做时间对比，不做语义关联")
	lines.append("- AI 应基于本报告做人工复查（结合代码内容 + 笔记内容判断是否需要回填）")
	lines.append("- 走闸门 C 差异审计后才能修改笔记")
	return "\n".join(lines)


static func _scan_recent_files(root: String, days: int) -> Array:
	var results: Array = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return results
	_scan_recent_recursive(dir, root, "", days, results)
	return results


static func _scan_recent_recursive(dir: DirAccess, root: String, current_path: String, days: int, results: Array) -> void:
	var full_path: String = root + current_path
	dir.list_dir_begin()
	var file: String = dir.get_next()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var threshold: int = days * 24 * 3600
	while file != "":
		if file.begins_with(".") or file == ".gitignore":
			file = dir.get_next()
			continue
		var file_path: String = full_path + file
		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(file_path + "/")
			if sub_dir != null:
				_scan_recent_recursive(sub_dir, root, current_path + file + "/", days, results)
		else:
			var modified_unix: int = int(FileAccess.get_modified_time(file_path))
			var age: int = now_unix - modified_unix
			if age < threshold:
				var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(modified_unix)
				var date_str: String = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
				results.append({"path": current_path + file, "date": date_str})
		file = dir.get_next()
	dir.list_dir_end()


static func _scan_outdated_files(root: String, days: int) -> Array:
	var results: Array = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return results
	var now_unix: int = int(Time.get_unix_time_from_system())
	var threshold: int = days * 24 * 3600
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".md") and file != "00-索引.md":
			var file_path: String = root + file
			var modified_unix: int = int(FileAccess.get_modified_time(file_path))
			var age: int = now_unix - modified_unix
			if age > threshold:
				var date_dict: Dictionary = Time.get_datetime_dict_from_unix_time(modified_unix)
				var date_str: String = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
				results.append({"path": file, "date": date_str})
		file = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a, b): return a.date < b.date)
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
	var path: String = REPORT_DIR + "同步-" + timestamp + ".md"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SyncAdvisor: 无法写入报告 %s" % path)
		return
	file.store_string(report)
	file.close()
	print("[SyncAdvisor] 同步报告已保存：%s" % path)
