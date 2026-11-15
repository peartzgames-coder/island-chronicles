class_name ResidentBrain
extends RefCounted
## Decides which state a resident enters next.
##
## 1. Every need gets an urgency (0 = fine, 1+ = desperate).
## 2. The MOST URGENT need whose urgency reaches its threshold
##    (SimConfig.NEED_THRESHOLDS) decides the state:
##      hunger -> SEARCHING_FOOD   thirst -> SEARCHING_WATER
##      energy -> SLEEPING         health -> SLEEPING (rest heals)
##      social -> SOCIALIZING
## 3. With no pressing need the resident WORKS when the colony needs their job
##    and it is a good time to work, otherwise stays IDLE.

const NOISE := 0.04             ## tiny randomness so residents don't act in lockstep
const COMMITMENT_BONUS := 0.1   ## favour the need already being handled
const NEED_STATES := {
	"hunger": Resident.State.SEARCHING_FOOD,
	"thirst": Resident.State.SEARCHING_WATER,
	"energy": Resident.State.SLEEPING,
	"health": Resident.State.SLEEPING,
	"social": Resident.State.SOCIALIZING,
}


## Urgency of every need for this resident right now.
func need_urgencies(r: Resident, ctx: ResidentManager) -> Dictionary:
	var urgencies := {}

	var hunger := r.hunger / 100.0
	if r.hunger >= SimConfig.HUNGER_CRITICAL - 10.0:
		hunger += 0.4
	urgencies["hunger"] = hunger

	var thirst := r.thirst / 100.0 * 1.05  # thirst kills faster than hunger
	if r.thirst >= SimConfig.THIRST_CRITICAL - 10.0:
		thirst += 0.4
	urgencies["thirst"] = thirst

	var tired := 1.0 - r.energy / 100.0
	if ctx.clock.is_night() and r.energy < 95.0:
		tired = maxf(tired, 0.85)
	elif ctx.clock.hour >= SimConfig.NIGHT_START_HOUR - 1.0 and r.energy < 85.0:
		tired = maxf(tired, 0.62)  # head to camp before it gets dark
	if r.energy < 15.0:
		tired += 0.4
	urgencies["energy"] = tired

	urgencies["health"] = 1.0 - r.health / 100.0

	var lonely := (1.0 - r.social / 100.0) * (0.6 + 0.6 * r.sociability)
	if ctx.clock.is_night():
		lonely *= 0.4
	urgencies["social"] = lonely
	return urgencies


## The most urgent need at or above its threshold, or "" if none is pressing.
func highest_need(r: Resident, ctx: ResidentManager, current: int = -1) -> String:
	var urgencies := need_urgencies(r, ctx)
	r.last_needs = urgencies
	var best_need := ""
	var best_value := -INF
	for need in urgencies:
		var value: float = urgencies[need] + ctx.rng.randf_range(-NOISE, NOISE)
		if current >= 0 and handles_need(current, need):
			value += COMMITMENT_BONUS
		if value >= float(SimConfig.NEED_THRESHOLDS[need]) and value > best_value:
			best_value = value
			best_need = need
	return best_need


func choose_state(r: Resident, ctx: ResidentManager, current: int = -1) -> int:
	var need := highest_need(r, ctx, current)
	if need != "":
		r.decision_reason = "Kebutuhan tertinggi: " + str(Resident.NEED_NAMES[need])
		return NEED_STATES[need]
	if work_score(r, ctx) > idle_score(r, ctx):
		r.decision_reason = "Kamp membutuhkan " + r.job.to_lower()
		return Resident.State.WORKING
	r.decision_reason = "Tidak ada kebutuhan mendesak"
	return Resident.State.IDLE


func work_score(r: Resident, ctx: ResidentManager) -> float:
	var score := (0.6 + 0.8 * r.diligence) * JobDefinitions.demand(r.job, ctx.stockpile)
	if ctx.clock.is_night():
		score *= 0.2
	elif not ctx.clock.is_work_hours():
		score *= 0.4
	return score * clampf(r.energy / 40.0, 0.2, 1.0)


func idle_score(r: Resident, ctx: ResidentManager) -> float:
	return 0.2 + 0.2 * r.curiosity + ctx.rng.randf_range(-NOISE, NOISE)


## True if being in `state` takes care of `need`.
static func handles_need(state: int, need: String) -> bool:
	match need:
		"hunger":
			return state == Resident.State.SEARCHING_FOOD or state == Resident.State.EATING
		"thirst":
			return state == Resident.State.SEARCHING_WATER or state == Resident.State.DRINKING
		"energy", "health":
			return state == Resident.State.SLEEPING
		"social":
			return state == Resident.State.SOCIALIZING
	return false


## Checked about once per second: should the current state be abandoned?
func should_interrupt(r: Resident, ctx: ResidentManager) -> bool:
	if r.state == Resident.State.WORKING and r.step == Resident.Step.DELIVER and r.health > 30.0:
		return false  # finish carrying goods home first
	var eating := handles_need(r.state, "hunger")
	var drinking := handles_need(r.state, "thirst")
	if r.hunger >= SimConfig.HUNGER_CRITICAL - 5.0 and not eating:
		return true
	if r.thirst >= SimConfig.THIRST_CRITICAL - 5.0 and not drinking:
		return true
	if r.energy <= SimConfig.ENERGY_CRITICAL and r.state != Resident.State.SLEEPING and not eating and not drinking:
		return true
	if ctx.clock.is_night() and r.state == Resident.State.WORKING and r.step == Resident.Step.MOVE:
		return true
	return false
