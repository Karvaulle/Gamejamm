extends CharacterBody2D

# --- CONSTANTS ---
const SPEED: float = 200.0
const JUMP_VELOCITY: float = -400.0
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.2
const GRAVITY: float = 800.0

# --- NODES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var skull_label: Label = get_node("/root/Game/UI/SkullLabel") # adjust path

# --- PLAYER STATE ---
var health: int = 100
var skulls: int = 0
var _is_attacking: bool = false
var _is_dashing: bool = false
var _dash_direction: float = 0.0
var _attack_timer: float = 0.0
var _dash_timer: float = 0.0
var _enemies_hit: Array = []

# --- EXPORT VARIABLES ---
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.7
@export var dash_cooldown: float = 1.0

# --- READY ---
func _ready() -> void:
	add_to_group("player")
	_update_skull_label()
	if animated_sprite and animated_sprite.sprite_frames.has_animation("Idle"):
		animated_sprite.play("Idle")
	if attack_area:
		attack_area.monitoring = false
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	print("Player ready! Health:", health)

# --- PHYSICS PROCESS ---
func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")

	# Cooldowns
	_attack_timer = max(_attack_timer - delta, 0)
	_dash_timer = max(_dash_timer - delta, 0)

	# Dash
	if _is_dashing:
		velocity.x = _dash_direction * DASH_SPEED
	else:
		velocity.x = direction * SPEED

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_dashing:
		velocity.y = JUMP_VELOCITY
		if animated_sprite.sprite_frames.has_animation("jump"):
			animated_sprite.play("jump")

	move_and_slide()

	# Attack input
	if Input.is_action_just_pressed("attack") and not _is_attacking and _attack_timer <= 0.0:
		_start_attack("attack")
	if Input.is_action_just_pressed("upwards_attack") and not _is_attacking and _attack_timer <= 0.0:
		_start_attack("upwards_attack")

	# Dash input
	if Input.is_action_just_pressed("dash") and not _is_dashing and _dash_timer <= 0.0:
		_start_dash(direction)

	# Movement animations
	if not _is_attacking and not _is_dashing:
		if not is_on_floor():
			if animated_sprite.sprite_frames.has_animation("jump") and animated_sprite.animation != "jump":
				animated_sprite.play("jump")
		else:
			if direction != 0.0:
				animated_sprite.flip_h = direction < 0
				if animated_sprite.sprite_frames.has_animation("Walk"):
					animated_sprite.play("Walk")
			else:
				if animated_sprite.sprite_frames.has_animation("Idle"):
					animated_sprite.play("Idle")

# --- DASH FUNCTION ---
func _start_dash(direction: float) -> void:
	if direction == 0:
		direction = 1 if not animated_sprite.flip_h else -1
	_dash_direction = direction
	_is_dashing = true
	_dash_timer = dash_cooldown
	if animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
	await get_tree().create_timer(DASH_DURATION).timeout
	_is_dashing = false

# --- ATTACK FUNCTION ---
func _start_attack(animation_name: String) -> void:
	_is_attacking = true
	_attack_timer = attack_cooldown
	_enemies_hit.clear()
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	if attack_area:
		attack_area.monitoring = true

	var frames: SpriteFrames = animated_sprite.sprite_frames
	var anim_length: float = 0.1
	var count: int = frames.get_frame_count(animation_name)
	var fps: float = frames.get_animation_speed(animation_name)
	if fps > 0.0 and count > 0:
		anim_length = float(count) / fps

	await get_tree().create_timer(anim_length).timeout
	if attack_area:
		attack_area.monitoring = false
	_is_attacking = false

# --- ATTACK HITBOX ---
func _on_attack_area_body_entered(body: Node) -> void:
	if body == self or body in _enemies_hit:
		return
	_enemies_hit.append(body)
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

# --- TAKE DAMAGE ---
func take_damage(amount: int) -> void:
	health -= amount
	print("Player took", amount, "damage! Health:", health)
	if health <= 0:
		queue_free()

# --- SKULL COLLECTION ---
func collect_skull(amount: int = 1) -> void:
	skulls += amount
	_update_skull_label()
	print("Collected skull! Total:", skulls)

func _update_skull_label() -> void:
	if skull_label:
		skull_label.text = "You have collected %d skull%s" % [skulls, "" if skulls == 1 else "s"]
