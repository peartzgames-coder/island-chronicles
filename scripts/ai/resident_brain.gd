class_name ResidentBrain
extends RefCounted
## Utility AI: scores every possible action from the resident's needs,
## personality, the time of day and colony demand, then picks the best one.

const NOISE := 0.06              ## small randomness so residents don't act in lockstep
const COMMITMENT_BONUS := 0.15   ## favour the current action when re-evaluating mid-task


func score_actions(r: Resident, ctx: ResidentManager) -> Dictionary:
	var night := ctx.clock.is_night()
	var scores := {}

	var hunger := r.hunger / 100.0
	scores[Resident.Action.EAT] = hunger * hunger * 1.7 \
		+ (0.6 if r.hunger >= SimConfig.HUNGER_CRITICAL - 10.0 else 0.0)

	var thirst := r.thirst / 100.0
	scores[Resident.Action.DRINK] = thirst * thirst * 1.8 \
		+ (0.6 if r.thirst >= SimConfig.THIRST_CRITICAL - 10.0 else 0.0)

	var tired := 1.0 - r.energy / 100.0
	var sleep := tired * tired * 1.5
	if night and r.energy < 95.0:
		sleep += 0.55
	elif ctx.clock.hour >= SimConfig.NIGHT_START_HOUR - 1.0 and r.energy < 85.0:
		sleep += 0.3  # head to camp before it gets dark
	if r.energy < 15.0:
		sleep += 0.8
	scores[Resident.Action.SLEEP] = sleep

	var work := 0.5 * (0.6 + 0.8 * r.diligence) * JobDefinitions.demand(r.job, ctx.stockpile)
	if night:
		work *= 0.2
	elif not ctx.clock.is_work_hours():
		work *= 0.4
	work *= clampf(r.energy / 40.0, 0.2, 1.0)
	scores[Resident.Action.WORK] = work

	var lonely := 1.0 - r.social / 100.0
	scores[Resident.Action.SOCIALIZE] = pow(lonely, 1.5) * (0.4 + 0.8 * r.sociability) * (0.3 if night else 1.0)

	scores[Resident.Action.WANDER] = 0.08 + 0.12 * r.curiosity
	scores[Resident.Action.IDLE] = 0.05
	return scores


## Picks the highest scoring action. `current` (if >= 0) gets a commitment bonus.
func choose_action(r: Resident, ctx: ResidentManager, current: int = -1) -> int:
	var scores := score_actions(r, ctx)
	var best: int = Resident.Action.IDLE
	var best_score := -INF
	for key in scores:
		var value: float = scores[key] + ctx.rng.randf_range(-NOISE, NOISE)
		if key == current:
			value += COMMITMENT_BONUS
		if value > best_score:
			best_score = value
			best = key
	r.last_scores = scores
	return best


## True when the current task should be re-evaluated: a critical need, or
## nightfall while still walking to a job that has not started yet.
func should_interrupt(r: Resident, ctx: ResidentManager) -> bool:
	if r.phase == Resident.Phase.DELIVER and r.health > 30.0:
		return false  # finish carrying goods home first
	if r.hunger >= SimConfig.HUNGER_CRITICAL - 5.0 and r.action != Resident.Action.EAT:
		return true
	if r.thirst >= SimConfig.THIRST_CRITICAL - 5.0 and r.action != Resident.Action.DRINK:
		return true
	if r.energy <= SimConfig.ENERGY_CRITICAL and r.action != Resident.Action.SLEEP \
			and r.action != Resident.Action.EAT and r.action != Resident.Action.DRINK:
		return true
	if ctx.clock.is_night() and r.action == Resident.Action.WORK and r.phase == Resident.Phase.MOVE:
		return true
	return false
