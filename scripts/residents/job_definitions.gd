class_name JobDefinitions
extends RefCounted
## Job ids and job rules. Per-job values (colour, shift length, description)
## are loaded from the JobData files in res://data/residents/.

const FISHER := "Nelayan"
const GATHERER := "Pengumpul"
const WOODCUTTER := "Penebang"
const EXPLORER := "Penjelajah"
const ALL := [FISHER, GATHERER, WOODCUTTER, EXPLORER]

const FILES := {
	FISHER: "res://data/residents/job_fisher.tres",
	GATHERER: "res://data/residents/job_gatherer.tres",
	WOODCUTTER: "res://data/residents/job_woodcutter.tres",
	EXPLORER: "res://data/residents/job_explorer.tres",
}

static var _jobs: Dictionary = {}
static var _loaded := false


static func get_job(job: String) -> JobData:
	if not _loaded:
		_loaded = true
		for id in FILES:
			var data := load(FILES[id]) as JobData
			if data == null:
				push_error("JobDefinitions: cannot load " + str(FILES[id]))
				continue
			_jobs[id] = data
	return _jobs.get(job)


static func color_for(job: String) -> Color:
	var data := get_job(job)
	return data.color if data != null else Color.WHITE


static func work_duration(job: String) -> float:
	var data := get_job(job)
	return data.work_duration if data != null else 5.0


static func yield_range(resource: String) -> Vector2:
	var data := ResourceCatalog.get_type(resource)
	return Vector2(data.yield_min, data.yield_max) if data != null else Vector2(2, 4)


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
