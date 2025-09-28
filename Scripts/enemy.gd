extends CharacterBody2D

# --- exported config ---
@export var patrol_points: Array[Vector2] = [Vector2.ZERO, Vector2(200, 0)]
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 160.0
@export var acceleration: float = 800.0
@export var detection_radius: float = 250.0
@export var attack_range: float = 32.0
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.15
@export var attack_duration: float = 0.25
@export var damage: int = 10

@export var max_hp: int = 60
var hp: int = max_hp

# --- internal state ---
var current_patrol_index: int = 0
var velocity_vec: Vector2 = Vector2.ZERO
var target: Node = null
var can_attack: bool = true
var state: String = "patrol"  # "patrol", "chase", "attack", "stagger"

# nodes
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready():
	detection_area.connect("body_entered", Callable(self, "_on_detection_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_exited"))
	attack_area.monitoring = false
	attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))

	if patrol_points.is_empty():
		patrol_points.append(global_position)

func _physics_process(delta: float) -> void:
	match state:
		"patrol":
			_state_patrol(delta)
		"chase":
			_state_chase(delta)
		"attack", "stagger":
			# during attack or stagger, don't move
			velocity_vec = Vector2.ZERO

	# Apply velocity with CharacterBody2D physics
	velocity = velocity_vec
	move_and_slide()

# -------------------
# States
# -------------------
func _state_patrol(delta: float) -> void:
	var target_pos: Vector2 = patrol_points[current_patrol_index]
	var desired = (target_pos - global_position).normalized() * patrol_speed
	velocity_vec = velocity_vec.move_toward(desired, acceleration * delta)

	if global_position.distance_to(target_pos) < 6.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

	if target:
		state = "chase"
		if anim_player:
			anim_player.play("run")

func _state_chase(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		state = "patrol"
		if anim_player:
			anim_player.play("walk")
		return

	var dir = target.global_position - global_position
	var dist = dir.length()

	if dist <= attack_range and can_attack:
		_start_attack()
		return

	var desired = dir.normalized() * chase_speed
	velocity_vec = velocity_vec.move_toward(desired, acceleration * delta)

	if global_position.distance_to(target.global_position) > detection_radius * 1.2:
		target = null
		state = "patrol"
		if anim_player:
			anim_player.play("walk")

# -------------------
# Detection callbacks
# -------------------
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

# -------------------
# Attack flow
# -------------------
func _start_attack() -> void:
	state = "attack"
	velocity_vec = Vector2.ZERO
	can_attack = false

	if anim_player:
		anim_player.play("attack")

	await get_tree().create_timer(attack_windup).timeout
	_enable_attack_hitbox(true)

	await get_tree().create_timer(attack_duration).timeout
	_enable_attack_hitbox(false)

	await get_tree().create_timer(0.05).timeout
	state = "chase" if is_instance_valid(target) else "patrol"

	var t = get_tree().create_timer(attack_cooldown)
	await t.timeout
	can_attack = true

func _enable_attack_hitbox(enable: bool) -> void:
	attack_area.monitoring = enable
	attack_area.set_deferred("monitoring", enable)

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("apply_damage"):
			body.apply_damage(damage)

# -------------------
# Health / Death
# -------------------
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	# You could play a death animation before freeing
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")
		await anim_player.animation_finished
	queue_free()
