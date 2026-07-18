extends Node
## MailManager —— 邮件管家（MVP 简化版）
## 满包奖励自动入邮件 + 系统邮件 + 24h 过期

var _mails: Array = []

func _ready() -> void:
	pass

func add_system_mail(title: String, body: String, attachment: Dictionary = {}, expire_hours: int = 0) -> void:
	var mail: Dictionary = {
		"id": "mail_%d" % Time.get_ticks_msec(),
		"type": "system",
		"title": title,
		"body": body,
		"attachment": attachment,
		"received_time": Time.get_unix_time_from_system(),
		"expire_hours": expire_hours,
		"read": false
	}
	_mails.append(mail)

func get_mails() -> Array:
	return _mails

func take_attachment(mail_id: String) -> Dictionary:
	for mail in _mails:
		if mail.id == mail_id:
			mail.read = true
			return mail.attachment
	return {}

func clean_expired() -> void:
	var cur: int = Time.get_unix_time_from_system()
	var kept: Array = []
	for mail in _mails:
		if mail.expire_hours > 0:
			var elapsed_h: float = float(cur - mail.received_time) / 3600.0
			if elapsed_h >= float(mail.expire_hours) and not mail.read:
				continue
		kept.append(mail)
	if kept.size() != _mails.size():
		_mails = kept