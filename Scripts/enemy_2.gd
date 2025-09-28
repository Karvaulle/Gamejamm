extends CharacterBody2D

# --- CONSTANTS ---
const GRAVITY: float = 800.0

# --- EXPORT VARIABLES ---
@export var patrol_points: Array[Vector2] = [Vector2.ZERO, Vector2(200, 0)]
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 160.0
@export var acceleration: float = 8.0
@export var detection_radius: float = 250.0
@export var attack_range: float = 32.0
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.15
@export var attack_duration: float = 0.25
@export var damage: int = 20
@export var max_hp: int = 100
@export var skull_scene: PackedScene = preload("res://Skull.tscn") # assign your skull scene

# --- INTERNAL STATE ---
var hp: int = max_hp
var current_patrol_index: int = 0
var velocity_vec: Vector2 = Vector2.ZERO
var target: Node = null
var can_attack: bool = true
var state: String = "patrol" # patrol, chase, attack, stagger
var facing_right: bool = true

# --- NODES ---
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- READY ---
func _ready():
	detection_area.connect("body_entered", Callable(self, "_on_detection_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_exited"))
	attack_area.monitoring = false
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	if patrol_points.is_empty():
		patrol_points.append(global_position)

# --- PHYSICS PROCESS ---
func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# State logic
	match state:
		"patrol":
			_state_patrol(delta)
		"chase":
			_state_chase(delta)
		"attack", "stagger":
			velocity_vec.x = 0

	# Apply horizontal velocity
	velocity.x = velocity_vec.x

	# Flip to face player and move attack hitbox
	if is_instance_valid(target):
		facing_right = target.global_position.x > global_position.x
		_update_attack_area_position()
		animated_sprite.flip_h = not facing_right

	move_and_slide()

# --- UPDATE ATTACK HITBOX POSITION ---
func _update_attack_area_position() -> void:
	var offset_x = 16 if facing_right else -16
	attack_area.position.x = offset_x
	attack_area.scale.x = 1 if facing_right else -1

# --- PATROL ---
func _state_patrol(delta: float) -> void:
	var dir_x = patrol_points[current_patrol_index].x - global_position.x
	var desired_vel_x = sign(dir_x) * patrol_speed
	velocity_vec.x = lerp(velocity_vec.x, desired_vel_x, acceleration * delta)

	if abs(dir_x) < 6:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

	if target:
		state = "chase"
		if anim_player:
			anim_player.play("run")

# --- CHASE ---
func _state_chase(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		state = "patrol"
		if anim_player:
			anim_player.play("walk")
		return

	var dir_x = target.global_position.x - global_position.x
	var dist = (target.global_position - global_position).length()

	if dist <= attack_range and can_attack:
		_start_attack()
		return

	var desired_vel_x = sign(dir_x) * chase_speed
	velocity_vec.x = lerp(velocity_vec.x, desired_vel_x, acceleration * delta)

	if abs(dir_x) > detection_radius * 1.2:
		target = null
		state = "patrol"
		if anim_player:
			anim_player.play("walk")

# --- DETECTION ---
func _on_detection_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body
		state = "chase"
		if anim_player:
			anim_player.play("run")

func _on_detection_exited(body: Node) -> void:
	if body == target:
		target = null
		state = "patrol"
		if anim_player:
			anim_player.play("walk")

# --- ATTACK ---
func _start_attack() -> void:
	state = "attack"
	velocity_vec.x = 0
	can_attack = false

	if anim_player:
		anim_player.play("attack")

	await get_tree().create_timer(attack_windup).timeout
	_enable_attack_hitbox(true)

	await get_tree().create_timer(attack_duration).timeout
	_enable_attack_hitbox(false)

	await get_tree().create_timer(0.05).timeout
	state = "chase" if is_instance_valid(target) else "patrol"

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _enable_attack_hitbox(enable: bool) -> void:
	attack_area.monitoring = enable
	attack_area.set_deferred("monitoring", enable)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Enemy dealt %d damage to player!" % damage)
		elif body.has_method("apply_damage"):
			body.apply_damage(damage)
			print("Enemy dealt %d damage to player via apply_damage!" % damage)

# --- HEALTH ---
func take_damage(amount: int) -> void:
	hp -= amount
	print("Enemy took %d damage! HP left: %d" % [amount, hp])
	if hp <= 0:
		die()

# --- DIE + SKULL DROP ---
func die() -> void:
	print("Enemy died!")
	# Drop skull
	if skull_scene:
		var skull_instance = skull_scene.instantiate()
		get_parent().add_child(skull_instance)
		skull_instance.global_position = global_position

	# Play death animation if exists
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")
		await anim_player.animation_finished

	# Remove enemy from scene
	queue_free()
