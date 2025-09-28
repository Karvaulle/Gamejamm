extends Node

# Make sure the path here points to the actual Label node
@onready var skull_label = $SkullLabel
var skull_count = 0

func _ready():
	update_skull_label()

func collect_skull():
	skull_count += 1
	update_skull_label()

func update_skull_label():
	if skull_label:
		skull_label.text = "You have collected %d skull%s" % [skull_count, "" if skull_count == 1 else "s"]
