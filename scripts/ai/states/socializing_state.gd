class_name SocializingState
extends ResidentState
## SOCIALIZING: walk up to a nearby resident (friends preferred) and chat.
## An idle partner joins the conversation; both gain social and affinity.

const SOCIAL_DISTANCE := 16.0


## params.partner (optional): join a conversation someone else started.
func enter(r: Resident, ctx: ResidentManager, params: Dictionary) -> void:
	if params.has("partner"):
		var host := ctx.get_resident(int(params["partner"]))
		r.partner_id = host.id
		_start_chat(r, host)
		return
	var partner := ctx.find_social_partner(r)
	if partner == null:
		redirect(r, Resident.State.IDLE, "Mencari teman mengobrol")
		return
	r.partner_id = partner.id
	r.step = Resident.Step.MOVE
	r.target = partner.pos
	r.timer = SimConfig.SOCIAL_CHASE_TIME
	r.status_text = "Menghampiri " + partner.short_name()


func update(r: Resident, delta: float, ctx: ResidentManager) -> int:
	var partner := ctx.get_resident(r.partner_id)
	if partner == null or not partner.alive or partner.is_sleeping():
		return DECIDE
	r.timer -= delta
	if r.step == Resident.Step.MOVE:
		r.target = partner.pos
		if r.timer <= 0.0:
			r.status_text = partner.short_name() + " terlalu sibuk"
			return DECIDE
		if ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r), SOCIAL_DISTANCE):
			_start_chat(r, partner)
			if partner.is_available():
				ctx.state_machine.change_state(partner, Resident.State.SOCIALIZING, ctx, {"partner": r.id})
		return STAY
	var engaged := partner.state == Resident.State.SOCIALIZING and partner.partner_id == r.id
	var factor := 1.0 if engaged else 0.4
	r.social = minf(100.0, r.social + SimConfig.SOCIAL_RATE * factor * delta)
	ctx.change_affinity(r, partner, SimConfig.AFFINITY_RATE * factor * delta)
	return DECIDE if r.timer <= 0.0 or r.social >= 100.0 else STAY


func _start_chat(r: Resident, partner: Resident) -> void:
	r.step = Resident.Step.PERFORM
	r.timer = SimConfig.SOCIAL_DURATION
	r.status_text = "Mengobrol dengan " + partner.short_name()
