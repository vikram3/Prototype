extends Node

## Platformer combat extension for the main CT. It cooperates with PlatformerOverride
## instead of replacing CT's existing story, health, coin, or dialogue systems.
enum State { IDLE, GROUND_ATTACK, AIR_ATTACK, DASH_ATTACK, BLOCK, RECOVER }

@export var ground_damage: int = 1
@export var air_damage: int = 2
@export var dash_damage: int = 2
@export var attack_range: float = 140.0
@export var dash_speed: float = 720.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.75
@export var block_damage_multiplier: float = 0.35

var player: CharacterBody2D
var state: State = State.IDLE
var attack_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var facing: float = 1.0

func _ready() -> void:
	player = get_parent() as CharacterBody2D

func _physics_process(delta: float) -> void:
	if player == null:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	if absf(player.velocity.x) > 5.0:
		facing = signf(player.velocity.x)
	if dash_timer > 0.0:
		state = State.DASH_ATTACK
		return
	if Input.is_key_pressed(KEY_K):
		state = State.BLOCK
		return
	if state == State.BLOCK:
		state = State.IDLE
	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0.0:
		start_dash()
		return
	if Input.is_key_pressed(KEY_J) and attack_timer <= 0.0:
		start_attack()

func get_horizontal_target(normal_target: float) -> float:
	if dash_timer > 0.0:
		return facing * dash_speed
	return normal_target

func start_dash() -> void:
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	state = State.DASH_ATTACK
	_hit_enemies(dash_damage, attack_range + 35.0)
	player.show_reaction("Coin-powered shoulder check!", true)

func start_attack() -> void:
	attack_timer = 0.28
	var airborne := not player.is_on_floor()
	state = State.AIR_ATTACK if airborne else State.GROUND_ATTACK
	_hit_enemies(air_damage if airborne else ground_damage, attack_range)
	player.show_reaction("Air bonk!" if airborne else "Back off my coins!", true)

func _hit_enemies(damage: int, hit_range: float) -> void:
	for enemy in player.get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D) or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - player.global_position
		if absf(offset.x) <= hit_range and absf(offset.y) <= 135.0 and signf(offset.x) == facing:
			enemy.take_damage(damage, player.global_position)

func try_block_damage(amount: int) -> bool:
	if state != State.BLOCK:
		return false
	var reduced_damage := max(1, ceili(float(amount) * block_damage_multiplier))
	player.health -= reduced_damage
	player.show_reaction("Blocked it. Mostly.", true)
	return true
