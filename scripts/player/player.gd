extends CharacterBody2D
## 角色移动脚本
## Phase 1 用 ui_ 默认输入（方向键）；Phase 2 改为自定义 WASD

@export var speed: float = 250.0

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()