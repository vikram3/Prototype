class_name Sacavuelo
extends PlatformerActor

enum State { IDLE, POSITION, ATTACK_BOOMERANG, WAIT, REPOSITION, VULNERABLE, HIT, RECOVER, DEFEATED }
@export var detection_range: float = 760.0
@export var close_vulnerability_range: float = 130.0
@export var boomerang_cooldown: float = 1.4
@export var pressure_after: float = 8.0
var state: State = State.IDLE
var attack_timer: float = 0.0
var distance_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	apply_gravity(delta)
	if disabled:
		state = State.DEFEATED
		move_horizontal(0.0, delta)
		move_and_slide()
		return
	var player := find_player()
	if player == null:
		move_and_slide(); return
	var dx := player.global_position.x - global_position.x
	facing = signf(dx) if not is_zero_approx(dx) else facing
	if sprite != null: sprite.flip_h = facing < 0.0
	attack_timer = maxf(attack_timer - delta, 0.0)
	if absf(dx) <= close_vulnerability_range:
		state = State.VULNERABLE
		distance_timer = 0.0
		move_horizontal(0.0, delta)
		say("Too close. Keep your hands off my feathers!")
	else:
		distance_timer += delta
		move_horizontal(facing * walk_speed, delta)
		if attack_timer <= 0.0:
			launch_boomerang(player)
	move_and_slide()

func launch_boomerang(player: Node2D) -> void:
	state = State.ATTACK_BOOMERANG
	attack_timer = boomerang_cooldown * (0.55 if distance_timer >= pressure_after else 1.0)
	say("My boomerang always comes back.", true)
	var projectile := ReturningBoomerang.new()
	projectile.owner_actor = self
	projectile.direction = (player.global_position - global_position).normalized()
	projectile.global_position = global_position + Vector2(facing * 65.0, -40.0)
	projectile.collision_layer = 16
	projectile.collision_mask = 3
	projectile.body_entered.connect(projectile._on_body_entered)
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	# The duel explicitly rewards close range; remote damage cannot skip the encounter.
	if source_position != Vector2.ZERO and global_position.distance_to(source_position) > close_vulnerability_range:
		return
	super.take_damage(amount, source_position)
