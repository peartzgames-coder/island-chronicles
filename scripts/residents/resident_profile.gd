class_name ResidentProfile
extends Resource
## Starting values used when the stranded population is created.
## The instance lives in res://data/residents/resident_profile.tres.

@export var first_names: PackedStringArray = []
@export var age_range := Vector2i(18, 55)
@export var hunger_range := Vector2(8, 35)
@export var thirst_range := Vector2(5, 30)
@export var energy_range := Vector2(60, 100)
@export var social_range := Vector2(35, 85)
@export var trait_range := Vector2(0.2, 1.0)
@export var main_skill_range := Vector2(0.5, 0.85)
@export var other_skill_range := Vector2(0.05, 0.35)
