class_name Stockpile
extends RefCounted
## Shared camp storage. Residents deposit what they gather and consume from it.

signal changed(resource: String, amount: float)

const FISH := "fish"
const FRUIT := "fruit"
const WOOD := "wood"
const WATER := "water"
const ORDER := [FISH, FRUIT, WOOD, WATER]
const LABELS := {FISH: "Ikan", FRUIT: "Buah", WOOD: "Kayu", WATER: "Air"}

var amounts := {FISH: 120.0, FRUIT: 160.0, WOOD: 80.0, WATER: 180.0}
var caps := {FISH: 300.0, FRUIT: 300.0, WOOD: 250.0, WATER: 300.0}


func get_amount(resource: String) -> float:
	return float(amounts.get(resource, 0.0))


func get_cap(resource: String) -> float:
	return float(caps.get(resource, 0.0))


func has(resource: String, amount: float) -> bool:
	return get_amount(resource) >= amount


## Adds up to the storage cap. Returns the amount actually stored.
func add(resource: String, amount: float) -> float:
	var current := get_amount(resource)
	var stored := clampf(amount, 0.0, maxf(0.0, get_cap(resource) - current))
	amounts[resource] = current + stored
	changed.emit(resource, amounts[resource])
	return stored


## Removes up to `amount`. Returns the amount actually taken.
func take(resource: String, amount: float) -> float:
	var current := get_amount(resource)
	var taken := clampf(amount, 0.0, current)
	amounts[resource] = current - taken
	changed.emit(resource, amounts[resource])
	return taken


## Perishable food slowly spoils so the colony must keep working.
func apply_spoilage(delta: float) -> void:
	for resource in SimConfig.SPOILAGE:
		var rate: float = SimConfig.SPOILAGE[resource]
		amounts[resource] = maxf(0.0, get_amount(resource) * (1.0 - rate * delta))


func food_total() -> float:
	return get_amount(FISH) + get_amount(FRUIT)


## Takes one portion from whichever food is more plentiful.
## Returns the resource eaten, or "" when no food is left.
func take_food(portion: float = 1.0) -> String:
	var kind := FISH if get_amount(FISH) >= get_amount(FRUIT) else FRUIT
	if take(kind, portion) >= portion * 0.5:
		return kind
	return ""


## How badly the colony needs more of a resource (0.25 = full, 1.6 = empty).
func demand(resource: String) -> float:
	var cap := get_cap(resource)
	if cap <= 0.0:
		return 0.0
	return clampf(1.6 - 1.6 * get_amount(resource) / cap, 0.25, 1.6)


static func label(resource: String) -> String:
	return str(LABELS.get(resource, resource))
