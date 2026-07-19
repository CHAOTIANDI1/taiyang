extends Node
## LootHelper —— 掉落与发放辅助管家
## 统一封装"获得物品"逻辑：满包时自动入邮件（docs/10-UI与交互.md 奖励发放规则）
## 调用方不需关心背包是否有空位

func give_item(item_id: String, count: int = 1, source: String = "") -> bool:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		push_warning("LootHelper: 物品 ID 无效 %s" % item_id)
		return false
	# 重要物品越过容量检查（InventoryManager.add 对 important 类永远返回 true）
	if InventoryManager.add(item_id, count):
		print("[LootHelper] 获得 %s ×%d（来源：%s）" % [item.get("name", item_id), count, source])
		return true
	# 满包入邮件（24h 限领）
	var attachment: Dictionary = {"item_id": item_id, "count": count}
	var mail_title: String = "背包已满：%s" % item.get("name", item_id)
	var mail_body: String = "你获得了 %d 个%s，但背包已满。请在 24 小时内领取附件。" % [count, item.get("name", item_id)]
	if source != "":
		mail_body += "\n来源：%s" % source
	MailManager.add_system_mail(mail_title, mail_body, attachment, 24)
	print("[LootHelper] 背包已满，%s ×%d 入邮件（来源：%s）" % [item.get("name", item_id), count, source])
	return false


func drop_loot(monster_id: String, monster_name: String = "") -> void:
	var monster_data: Dictionary = DataManager.get_monster(monster_id)
	if monster_data.is_empty():
		return
	var drops: Array = monster_data.get("drops", [])
	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		var chance: float = float(drop.get("chance", 0.0))
		if item_id == "" or chance <= 0.0:
			continue
		var roll: float = randf()
		if roll < chance:
			var count: int = int(drop.get("count", 1))
			var source_name: String = monster_name if monster_name != "" else monster_id
			give_item(item_id, count, "击败 %s" % source_name)
