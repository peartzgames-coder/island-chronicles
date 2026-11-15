class_name JobDefinitions
extends RefCounted
## Static description of every job: what it produces, how long a shift takes
## and how strongly the colony currently needs it.

const FISHER := "Nelayan"
const GATHERER := "Pengumpul"
const WOODCUTTER := "Penebang"
const EXPLORER := "Penjelajah"
const ALL := [FISHER, GATHERER, WOODCUTTER, EXPLORER]

const WORK_DURATION := {FISHER: 6.0, GATHERER: 4.5, WOODCUTTER: 5.5, EXPLORER: 5.0}

## Base yield range per resource for one work shift, scaled by skill.
const YIELD := {
	Stockpile.FISH: Vector2(3, 6),
	Stockpile.FRUIT: Vector2(3, 6),
	Stockpile.WOOD: Vector2(3, 7),
	Stockpile.WATER: Vector2(5, 9),
}


static func color_for(job: String) -> Color:
	match job:
		FISHER:
			return Color("#e8b65d")
		GATHERER:
			return Color("#d77e65")
		WOODCUTTER:
			return Color("#7db2a1")
		_:
			return Color("#a68ac7")


static func work_duration(job: String) -> float:
	return float(WORK_DURATION.get(job, 5.0))


static func yield_range(resource: String) -> Vector2:
	return YIELD.get(resource, Vector2(2, 4))


## Gatherers fetch whichever of fruit or water the camp is shorter of.
static func gatherer_resource(stockpile: Stockpile) -> String:
	if stockpile.demand(Stockpile.WATER) > stockpile.demand(Stockpile.FRUIT):
		return Stockpile.WATER
	return Stockpile.FRUIT


## How urgently the colony needs this job done right now (~0.25..1.6).
static func demand(job: String, stockpile: Stockpile) -> float:
	match job:
		FISHER:
			# Fishers also respond when total food runs low.
			return maxf(stockpile.demand(Stockpile.FISH), 1.6 - stockpile.food_total() / 150.0)
		GATHERER:
			return maxf(stockpile.demand(Stockpile.FRUIT), stockpile.demand(Stockpile.WATER))
		WOODCUTTER:
			return stockpile.demand(Stockpile.WOOD)
		_:
			return 0.9


static func work_status(job: String, resource: String) -> String:
	match job:
		FISHER:
			return "Memancing ikan"
		GATHERER:
			return "Mengambil air" if resource == Stockpile.WATER else "Memetik buah"
		WOODCUTTER:
			return "Menebang kayu"
		_:
			return "Menjelajahi pulau"
