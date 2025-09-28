extends Area2D

var player_in_range = false
var player: Node2D = null  # Declare player as a member variable
var game_completed_scene = preload("res://GameCompleted.tscn")  # Replace with your scene path

# Check for input every frame
func _process(delta):
	if Input.is_action_just_pressed("interact") and player_in_range:
		var detected_player: Node2D = null
		for body in get_overlapping_bodies():
			if body.name == "Player":  # Make sure this matches your Player node name
				detected_player = body
				break
		if detected_player and detected_player.skulls_collected >= 2:
			complete_game()

# Trigger the game completed scene
func complete_game():
	var scene_instance = game_completed_scene.instance()
	get_tree().root.add_child(scene_instance)
	get_tree().paused = true  # Optional: pause game when showing completion scene

# Detect when player enters the altar
func _on_Altar_body_entered(body: Node2D) -> void:
	if body.name == "Player":  # Make sure this matches your Player node name
		player_in_range = true
		player = body

# Detect when player exits the altar
func _on_Altar_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		player = null
