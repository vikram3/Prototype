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
var chain_index: int = -1
var chain_timer: float = 0.0
var anim: Node = null
var sword: Area2D = null
var swing_timer: float = 0.0
var swing_damage: int = 1
var swing_hits: Array = []

const ATTACK_CHAIN: Array[String] = ["attack_1", "attack_2", "attack_3", "combo_attack"]

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	anim = player.get_node_or_null("Sprite2D")
	sword = player.get_node_or_null("SwordHitbox") as Area2D

func _physics_process(delta: float) -> void:
	if player == null:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	chain_timer = maxf(chain_timer - delta, 0.0)
	_update_swing(delta)
	if chain_timer <= 0.0:
		chain_index = -1
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	if absf(player.velocity.x) > 5.0:
		facing = signf(player.velocity.x)
	if dash_timer > 0.0:
		state = State.DASH_ATTACK
		return
	# Right mouse button blocks (K also works); left mouse attacks (J also works).
	if Input.is_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if state != State.BLOCK:
			_play("block")
		state = State.BLOCK
		return
	if state == State.BLOCK:
		state = State.IDLE
	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_timer <= 0.0:
		start_dash()
		return
	if (Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and attack_timer <= 0.0:
		start_attack()
	elif Input.is_key_pressed(KEY_L) and attack_timer <= 0.0:
		start_power_attack()
	elif Input.is_key_pressed(KEY_U) and attack_timer <= 0.0:
		start_up_attack()

func get_horizontal_target(normal_target: float) -> float:
	if dash_timer > 0.0:
		return facing * dash_speed
	return normal_target

func start_dash() -> void:
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	state = State.DASH_ATTACK
	_play("dash")
	_swing(dash_damage, dash_duration + 0.1)
	if player.has_method("show_reaction"):
		player.call("show_reaction", "Coin-powered shoulder check!", true)

func start_attack() -> void:
	attack_timer = 0.28
	var airborne: bool = not player.is_on_floor()
	state = State.AIR_ATTACK if airborne else State.GROUND_ATTACK
	if airborne:
		_play("jump_attack")
	else:
		# J chains attack_1 -> attack_2 -> attack_3 -> combo_attack while the chain window is open.
		chain_index = (chain_index + 1) % ATTACK_CHAIN.size()
		chain_timer = 0.6
		_play(ATTACK_CHAIN[chain_index])
	_swing(air_damage if airborne else ground_damage, 0.22)
	if player.has_method("show_reaction"):
		player.call("show_reaction", "Air bonk!" if airborne else "Back off my coins!", true)

func start_power_attack() -> void:
	attack_timer = 0.45
	state = State.GROUND_ATTACK
	_play("power_attack")
	_swing(ground_damage * 2, 0.3)


func start_up_attack() -> void:
	attack_timer = 0.4
	state = State.GROUND_ATTACK
	_play("idle_up_attack")
	_swing(ground_damage, 0.25, true)


func _update_swing(delta: float) -> void:
	if sword == null or swing_timer <= 0.0:
		return
	swing_timer -= delta
	for body in sword.get_overlapping_bodies():
		if body in swing_hits or not body.is_in_group("enemy"):
			continue
		swing_hits.append(body)
		if body.has_method("take_damage"):
			body.call("take_damage", swing_damage, player.global_position)
	if swing_timer <= 0.0:
		sword.monitoring = false
		swing_hits.clear()


## Turns on the sword hitbox in front of CT for a short active window.
## Each enemy is hit at most once per swing.
func _swing(damage: int, duration: float, up: bool = false) -> void:
	if sword == null:
		return
	var face := -1.0 if (anim != null and bool(anim.get("flip_h"))) else 1.0
	var shape := sword.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.position = Vector2(95.0 * face, -200.0 if up else -130.0)
	swing_damage = damage
	swing_hits.clear()
	swing_timer = duration
	sword.monitoring = true


func _play(action_name: String) -> void:
	if anim != null and anim.has_method("play_action"):
		anim.play_action(StringName(action_name))


func _hit_enemies(damage: int, hit_range: float) -> void:
	for enemy in player.get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node2D) or not enemy.has_method("take_damage"):
			continue
		var enemy_node: Node2D = enemy as Node2D
		var offset: Vector2 = enemy_node.global_position - player.global_position
		if absf(offset.x) <= hit_range and absf(offset.y) <= 135.0 and signf(offset.x) == facing:
			enemy.call("take_damage", damage, player.global_position)

func try_block_damage(amount: int) -> bool:
	if state != State.BLOCK:
		return false
	var reduced_damage: int = maxi(1, ceili(float(amount) * block_damage_multiplier))
	var health_value: int = int(player.get("health")) - reduced_damage
	player.set("health", health_value)
	if player.has_method("show_reaction"):
		player.call("show_reaction", "Blocked it. Mostly.", true)
	return true
