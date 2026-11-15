class_name ResourceTypeData
extends Resource
## Data for one stockpile resource (fish, fruit, wood, water).
## Instances live in res://data/resources/ and can be edited in the Inspector.

@export var id := ""
@export var label := ""
@export var initial_amount := 0.0
@export var capacity := 300.0
## Fraction of the stored amount lost per simulated second (0 = never spoils).
@export var spoilage := 0.0
## Base yield range of one work shift, before the skill multiplier.
@export var yield_min := 2.0
@export var yield_max := 4.0
## Colour of the bundle drawn above a resident carrying this resource.
@export var carry_color := Color.WHITE
