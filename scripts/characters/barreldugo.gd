class_name Barreldugo
extends PlatformerActor

enum State { IDLE, PATROL, DETECT, ATTACK, RECOVER, HIT, DEFEATED, TAMED, MOUNTED, STORY }
@export var detection_range: float = 560.0
@export var attack_range: float = 460.0
@export var attack_cooldown: float = 1.3
@export var projectile_speed: float = 540.0
@export var tameable: bool = true
var state: State = State.PATROL
var attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	if disabled:
		state = State.DEFEATED
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	if story_mode or state == State.TAMED or state == State.MOUNTED:
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	var player := find_player()
	if player != null:
		var dx := player.global_position.x - global_position.x
		if absf(dx) <= detection_range:
			facing = signf(dx)
			if sprite != null: sprite.flip_h = facing < 0.0
			if absf(dx) <= attack_range and attack_timer <= 0.0:
				fire_at(player)
			else:
				move_horizontal(facing * walk_speed, delta)
		else:
			move_horizontal(0.0, delta)
	else:
		move_horizontal(facing * walk_speed, delta)
	move_and_slide()

func fire_at(player: Node2D) -> void:
	attack_timer = attack_cooldown
	state = State.ATTACK
	say_random(combat_lines)
	var projectile := StoryProjectile.new()
	projectile.owner_actor = self
	projectile.speed = projectile_speed
	projectile.direction = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + Vector2(facing * 40.0, -40.0)
	projectile.collision_layer = 16
	projectile.collision_mask = 3
	projectile.body_entered.connect(projectile._on_body_entered)
	get_tree().current_scene.add_child(projectile)

func tame() -> bool:
	if not tameable or disabled == false:
		return false
	disabled = false
	state = State.TAMED
	set_collision_layer_value(4, false)
	say("Felix has my trust. I will carry the crew.", true)
	return true
