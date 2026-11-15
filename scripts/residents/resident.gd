class_name Resident
extends RefCounted
## Data for one islander: identity, needs, personality, skills, relationships
## and the current AI action. Behaviour lives in ResidentBrain / ResidentActions.

enum Action { IDLE, WANDER, EAT, DRINK, SLEEP, WORK, SOCIALIZE }
enum Phase { MOVE, PERFORM, DELIVER }

const ACTION_NAMES := {
	Action.IDLE: "Santai",
	Action.WANDER: "Jalan-jalan",
	Action.EAT: "Makan",
	Action.DRINK: "Minum",
	Action.SLEEP: "Tidur",
	Action.WORK: "Bekerja",
	Action.SOCIALIZE: "Bersosialisasi",
}

# Identity
var id := 0
var full_name := ""
var age := 18
var job := ""
var color := Color.WHITE
var pos := Vector2.ZERO
var alive := true
var cause_of_death := ""

# Needs. hunger/thirst: 0 = satisfied. energy/social/health: 100 = satisfied.
var health := 100.0
var hunger := 0.0
var thirst := 0.0
var energy := 100.0
var social := 50.0

# Personality traits, 0..1.
var diligence := 0.5   ## how eager they are to work
var sociability := 0.5 ## how much they seek company
var curiosity := 0.5   ## wandering and discovery chance

var skills := {}         ## job name -> 0..1
var relationships := {}  ## other resident id -> affinity (-100..100)

# Current AI state.
var action: int = Action.IDLE
var phase: int = Phase.PERFORM
var target := Vector2.ZERO
var timer := 0.0
var site_kind := ""
var site_index := -1
var partner_id := -1
var carry_type := ""
var carry_amount := 0.0
var think_cooldown := 0.0
var status_text := "Baru terdampar"
var last_scores := {}


func short_name() -> String:
	return full_name.split(" ")[0]


func action_name() -> String:
	return str(ACTION_NAMES.get(action, "?"))


func is_sleeping() -> bool:
	return action == Action.SLEEP and phase == Phase.PERFORM


func is_working() -> bool:
	return action == Action.WORK and phase != Phase.MOVE


func get_skill(job_name: String) -> float:
	return float(skills.get(job_name, 0.1))


func improve_skill(job_name: String, amount: float) -> void:
	skills[job_name] = minf(1.0, get_skill(job_name) + amount)


func get_affinity(other_id: int) -> float:
	return float(relationships.get(other_id, 0.0))


func change_affinity(other_id: int, amount: float) -> float:
	var value := clampf(get_affinity(other_id) + amount, -100.0, 100.0)
	relationships[other_id] = value
	return value


func best_friend_id() -> int:
	var best := -1
	var best_value := SimConfig.FRIEND_THRESHOLD - 0.001
	for other_id in relationships:
		var value: float = relationships[other_id]
		if value > best_value:
			best_value = value
			best = other_id
	return best


func clear_carry() -> void:
	carry_type = ""
	carry_amount = 0.0
