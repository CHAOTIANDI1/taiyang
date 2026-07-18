extends Node
## IntroSequence —— 过场控制管家
## MVP 实现 A：黑屏 + 文字独白
## 接口预留：可换为漫画分镜（B）/ 动画（C）

signal sequence_finished

enum PlayMode { TEXT_ONLY, COMIC, ANIMATION }
var _mode := PlayMode.TEXT_ONLY

func _ready() -> void:
	pass

func play_intro(intro_id: String, panels: Array) -> void:
	for panel in panels:
		await _play_panel(intro_id, panel)
	sequence_finished.emit()

func _play_panel(_intro_id: String, panel: Dictionary) -> void:
	var text: String = panel.get("text", "")
	var dur: float = float(panel.get("duration", 2.0))
	print("[IntroSequence] %s" % text)
	await get_tree().create_timer(dur).timeout

func boss_life_text(boss_name: String, story_lines: Array) -> void:
	var panels := []
	for line in story_lines:
		panels.append({
			"text": "「%s」— %s" % [boss_name, line],
			"duration": 3.0
		})
	await play_intro("boss_life_" + boss_name, panels)