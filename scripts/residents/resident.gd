class_name Resident
extends RefCounted
## Data for one islander: identity, needs, personality, skills, relationships
## and the current AI state. Behaviour lives in scripts/ai/ (brain + states).

## The eight Resident AI states (see scripts/ai/states/).
enum State { IDLE, WORKING, SEARCHING_FOOD, SEARCHING_WATER, EATING, DRINKING, SLEEPING, SOCIALIZING }
## Sub-steps used inside a state: walk there, do it, carry the result home.
enum Step { MOVE, PERFORM, DELIVER }

const STATE_NAMES := {
	State.IDLE: "Santai",
	State.WORKING: "Bekerja",
	State.SEARCHING_FOOD: "Mencari Makanan",
	State.SEARCHING_WATER: "Mencari Air",
	State.EATING: "Makan",
	State.DRINKING: "Minum",
	State.SLEEPING: "Tidur",
	State.SOCIALIZING: "Bersosialisasi",
}

const NEED_NAMES := {
	"hunger": "Lapar",
	"thirst": "Haus",
	"energy": "Lelah",
	"health": "Kesehatan",
	"social": "Kesepian",
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

# State machine data. Reset by ResidentStateMachine.change_state().
var state: int = State.IDLE
var step: int = Step.PERFORM
var target := Vector2.ZERO
var timer := 0.0
var site_kind := ""
var site_index := -1
var partner_id := -1
var attempts := 0          ## how many sources were tried while searching
var redirect_state := -1   ## set by a state's enter() to hand over to another state

# Kept across state changes.
var carry_type := ""
var carry_amount := 0.0
var consumed_label := ""   ## what the resident found to eat/drink (for Eating/Drinking text)
var think_cooldown := 0.0
var status_text := "Baru terdampar"
var decision_reason := ""  ## the need (or job) that drove the last decision
var last_needs := {}       ## need -> urgency from the last decision


func short_name() -> String:
	return full_name.split(" ")[0]


func state_name() -> String:
	return str(STATE_NAMES.get(state, "?"))


func is_sleeping() -> bool:
	return state == State.SLEEPING and step == Step.PERFORM


func is_working() -> bool:
	return state == State.WORKING and step != Step.MOVE


func is_chatting() -> bool:
	return state == State.SOCIALIZING and step == Step.PERFORM


## True for states in which the resident can be invited to chat.
func is_available() -> bool:
	return alive and state == State.IDLE


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
