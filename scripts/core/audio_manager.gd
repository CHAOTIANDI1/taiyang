extends Node
## AudioManager —— 音效/BGM 管家
## 从 data/sounds.json 读配置，分类调度 1 个 BGM 池 + N 个 SFX 池

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size := 8
var _sfx_index := 0
var _config: Dictionary = {}

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	add_child(_bgm_player)
	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		add_child(p)
		_sfx_players.append(p)
	_reload_config()

func _reload_config() -> void:
	_config = DataManager.get_data("sounds").get("_data", {})

func play_bgm(sound_id: String) -> void:
	var cfg := _config.get(sound_id, {})
	if cfg.is_empty():
		push_warning("AudioManager: 未知 BGM %s" % sound_id)
		return
	var stream := load("res://assets/audio/%s" % cfg.file)
	if stream == null:
		push_warning("AudioManager: 文件缺失 %s" % cfg.file)
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(float(cfg.get("volume", 0.6)))
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

func play_sfx(sound_id: String) -> void:
	var cfg := _config.get(sound_id, {})
	if cfg.is_empty():
		push_warning("AudioManager: 未知 SFX %s" % sound_id)
		return
	var stream := load("res://assets/audio/%s" % cfg.file)
	if stream == null:
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool_size
	player.stream = stream
	player.volume_db = linear_to_db(float(cfg.get("volume", 1.0)))
	player.play()