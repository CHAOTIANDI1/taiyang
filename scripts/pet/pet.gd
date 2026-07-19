extends CharacterBody2D
## 宠物脚本 - Phase 4.4.2（骨架版）
## 负责：从 pets.json 读数据 + 温和模式切换 + take_damage 接口
## 状态机骨架：idle / follow / attack（4.4.4-4.4.6 实现）

signal mode_toggled(is_gentle: bool)
signal died

@export var pet_id: String = ""
@export var move_speed: float = 150.0

var pet_name: String = ""
var species: String = ""
var max_hp: int = 50
var current_hp: int = 50
var damage: int = 8
var initial_level: int = 1
var skill_id: String = ""
var base_pet_id: String = ""

var _is_gentle_mode: bool = true
var _owner_player: Node = null
var _state: String = "idle"
var _is_dying: bool = false
var _color_rect: ColorRect = null

const FOLLOW_OFFSET: float = 80.0
const TELEPORT_DISTANCE: float = 300.0
const TELEPORT_TIMEOUT: float = 3.0


func _ready() -> void:
	_color_rect = get_node_or_null("ColorRect")
	if pet_id != "":
		_load_data_from_json()
	_apply_color()
	await get_tree().process_frame
	var p: Node = get_parent().get_node_or_null("Player")
	if p != null:
		set_owner_player(p)
		print("[Pet:%s] 就绪！名称=%s HP=%d/%d DMG=%d 温和模式=%s" % [pet_id, pet_name, current_hp, max_hp, damage, _is_gentle_mode])
	else:
		push_warning("[Pet:%s] 未找到 Player 节点" % pet_id)


func _apply_color() -> void:
	if _color_rect == null:
		return
	var data: Dictionary = DataManager.get_pet(pet_id)
	var color_str: String = String(data.get("color", "#FFA500"))
	_color_rect.color = Color(color_str)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if Input.is_action_just_pressed("pet_toggle_mode"):
		toggle_gentle_mode()

	match _state:
		"idle":
			_state_idle(delta)
		"follow":
			_state_follow(delta)
		"attack":
			_state_attack(delta)


func _state_idle(delta: float) -> void:
	pass


func _state_follow(delta: float) -> void:
	pass


func _state_attack(delta: float) -> void:
	pass


func toggle_gentle_mode() -> void:
	_is_gentle_mode = not _is_gentle_mode
	emit_signal("mode_toggled", _is_gentle_mode)
	print("[Pet:%s] 温和模式切换 → %s" % [pet_id, _is_gentle_mode])


func take_damage(amount: int) -> void:
	if _is_dying:
		return
	if _is_gentle_mode:
		print("[Pet:%s] 温和模式无敌，忽略伤害 %d" % [pet_id, amount])
		return
	current_hp -= amount
	print("[Pet:%s] 受击！扣 %d，剩余 %d/%d" % [pet_id, amount, current_hp, max_hp])
	if current_hp <= 0:
		current_hp = 0
		_start_dying()


func _start_dying() -> void:
	_is_dying = true
	emit_signal("died")
	print("[Pet:%s] 死亡（4.4.6 实现完整死亡淡出）" % pet_id)


func set_owner_player(player: Node) -> void:
	_owner_player = player


func set_state(new_state: String) -> void:
	_state = new_state


func is_gentle_mode() -> bool:
	return _is_gentle_mode


func _load_data_from_json() -> void:
	var data: Dictionary = DataManager.get_pet(pet_id)
	if data.is_empty():
		push_warning("Pet: 找不到 ID %s，用默认值" % pet_id)
		return
	pet_name = String(data.get("name", ""))
	species = String(data.get("species", ""))
	max_hp = int(data.get("hp", 50))
	damage = int(data.get("damage", 8))
	initial_level = int(data.get("initial_level", 1))
	skill_id = String(data.get("skill_id", ""))
	base_pet_id = String(data.get("base_pet_id", ""))
	current_hp = max_hp



