class_name ResourceCatalog
extends RefCounted
## Loads every ResourceTypeData from res://data/resources/ once and caches it.

const FILES := [
	"res://data/resources/fish.tres",
	"res://data/resources/fruit.tres",
	"res://data/resources/wood.tres",
	"res://data/resources/water.tres",
]

static var _types: Dictionary = {}
static var _order: Array[String] = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for path in FILES:
		var data := load(path) as ResourceTypeData
		if data == null:
			push_error("ResourceCatalog: cannot load " + path)
			continue
		_types[data.id] = data
		_order.append(data.id)


## Resource ids in display order.
static func ids() -> Array[String]:
	_ensure_loaded()
	return _order


static func get_type(id: String) -> ResourceTypeData:
	_ensure_loaded()
	return _types.get(id)
