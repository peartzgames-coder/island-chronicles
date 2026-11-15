class_name EventLog
extends RefCounted
## Short rolling log of island events shown in the HUD.

signal changed

const MAX_ENTRIES := 4

var entries: Array[String] = []


func add(message: String) -> void:
	entries.push_front("• " + message)
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	changed.emit()


func as_text() -> String:
	return "\n".join(PackedStringArray(entries))
