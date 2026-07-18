extends Node
## GameTime —— 太阳历时间管家
## 起点：太阳历 426 年 3 月 18 日 06:26
## MVP：本地系统时间换算；联机版：服务器统一时间取

const START_SOLAR_YEAR: int = 426
const START_SOLAR_MONTH: int = 3
const START_SOLAR_DAY: int = 18
const START_HOUR: int = 6
const START_MINUTE: int = 26

var _start_unix: int = 0

func _ready() -> void:
	_start_unix = Time.get_unix_time_from_system()

func get_elapsed_seconds() -> int:
	return int(Time.get_unix_time_from_system()) - _start_unix

func get_elapsed_time_dict() -> Dictionary:
	var sec: int = get_elapsed_seconds()
	var days: int = sec / 86400
	var rem: int = sec % 86400
	var hours: int = rem / 3600
	rem = rem % 3600
	var minutes: int = rem / 60
	var seconds: int = rem % 60
	return {"days": days, "hours": hours, "minutes": minutes, "seconds": seconds}

func get_solar_date_string() -> String:
	var t: Dictionary = get_elapsed_time_dict()
	var cur_month: int = START_SOLAR_MONTH
	var cur_day: int = START_SOLAR_DAY + int(t.get("days", 0))
	var cur_hour: int = START_HOUR + int(t.get("hours", 0))
	var cur_min: int = START_MINUTE + int(t.get("minutes", 0))
	cur_hour += int(cur_min / 60)
	cur_min = cur_min % 60
	var extra_days: int = int(cur_hour / 24)
	cur_hour = cur_hour % 24
	cur_day += extra_days
	while cur_day > 30:
		cur_day -= 30
		cur_month += 1
	while cur_month > 12:
		cur_month -= 12
	return "太阳历 %d年%d月%d日 %02d:%02d" % [START_SOLAR_YEAR, cur_month, cur_day, cur_hour, cur_min]