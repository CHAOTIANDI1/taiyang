extends Label
## 伤害飘字 - 显示伤害数字 + 浮动淡出动画
## 步骤 1：从 player.gd 的 _spawn_damage_number 抽出，全局可用
## 调用方式：DamageNumberManager.show_damage_number(world_pos, amount, "damage")

# 浮动距离（向上飘 40 像素）
const FLOAT_DISTANCE: float = 40.0
# 淡出时长（0.8 秒）
const FADE_DURATION: float = 0.8

# 伤害类型枚举
enum Type { DAMAGE, MISS, HEAL }

var _amount: int = 0
var _type: int = Type.DAMAGE


func _ready() -> void:
	# 设置文本和颜色（按类型区分）
	match _type:
		Type.DAMAGE:
			text = str(_amount)
			modulate = Color(1, 0.3, 0.3)  # 红色（受伤）
		Type.MISS:
			text = "miss"
			modulate = Color(0.7, 0.7, 0.7)  # 灰色（攻击落空）
		Type.HEAL:
			text = "+" + str(_amount)
			modulate = Color(0.3, 1, 0.3)  # 绿色（治疗）

	# 居中对齐
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 启动浮动 + 淡出动画
	_play_animation()


# 由 DamageNumberManager 调用，设置飘字数据
func set_data(amount: int, type: int = Type.DAMAGE) -> void:
	_amount = amount
	_type = type


func _play_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# 向上浮动
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, FADE_DURATION)
	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	# 完成后销毁
	tween.chain().tween_callback(queue_free)
