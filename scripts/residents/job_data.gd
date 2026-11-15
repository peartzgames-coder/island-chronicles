class_name JobData
extends Resource
## Data for one job. Instances live in res://data/residents/.

@export var id := ""
@export_multiline var description := ""
@export var color := Color.WHITE
## Seconds of simulated time one work shift takes on site.
@export var work_duration := 5.0
