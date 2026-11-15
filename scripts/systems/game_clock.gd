class_name GameClock
extends RefCounted
## Day/night clock. Emits day_changed whenever midnight passes.

signal day_changed(day: int)

var day := 1
var hour := 7.0


func advance(delta: float) -> void:
	hour += delta * SimConfig.HOURS_PER_SECOND
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)


func is_night() -> bool:
	return hour >= SimConfig.NIGHT_START_HOUR or hour < SimConfig.NIGHT_END_HOUR


func is_work_hours() -> bool:
	return hour >= SimConfig.WORK_START_HOUR and hour < SimConfig.WORK_END_HOUR


## 0 = full daylight, 1 = darkest night. Used by the night overlay.
func darkness() -> float:
	if hour >= 20.0 or hour < 5.0:
		return 1.0
	if hour >= 18.0:
		return (hour - 18.0) / 2.0
	if hour < 7.0:
		return 1.0 - (hour - 5.0) / 2.0
	return 0.0


func time_string() -> String:
	return "HARI %02d  •  %02d:%02d" % [day, int(hour), int((hour - floorf(hour)) * 60.0)]
