class_name AlexPlayer
extends PlatformerActor

@export var run_speed: float = 400.0
@export var jump_velocity: float = -720.0
@export var bow_speed: float = 760.0
@export var shield_hits: int = 3
@export var attack_range: float = 145.0
@export var combo_window: float = 0.42
var shield_durability: int
var shield_active: bool = false
var combo_step: int = 0
var combo_timer: float = 0.0
var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	shield_durability = shield_hits
	add_to_group("player")

func _physics_process(delta: float) -> void:
	_process_damage_timer(delta)
	if disabled: return
	apply_gravity(delta)
	combo_timer = maxf(combo_timer - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	var input_direction := Input.get_axis("move_left", "move_right")
	move_horizontal(input_direction * run_speed, delta)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	shield_active = Input.is_action_pressed("move_down") and shield_durability > 0
	if Input.is_action_just_pressed("ui_accept"):
		baton_attack()
	if Input.is_action_just_pressed("move_up"):
		fire_bow()
	if Input.is_action_just_pressed("ui_focus_next"):
		use_thunder()
	move_and_slide()

func baton_attack() -> void:
	if attack_timer > 0.0: return
	combo_step = combo_step + 1 if combo_timer > 0.0 else 1
	if combo_step > 3: combo_step = 1
	combo_timer = combo_window
	attack_timer = 0.16
	var damage := 2 if combo_step == 3 else 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and absf(enemy.global_position.x - global_position.x) < attack_range and absf(enemy.global_position.y - global_position.y) < 110.0:
			if signf(enemy.global_position.x - global_position.x) == facing and enemy.has_method("take_damage"):
				enemy.take_damage(damage, global_position)

func fire_bow() -> void:
	var arrow := StoryProjectile.new()
	arrow.owner_actor = self
	arrow.speed = bow_speed
	arrow.arc_gravity = 900.0
	arrow.direction = Vector2(facing, -0.38).normalized()
	arrow.global_position = global_position + Vector2(facing * 45.0, -55.0)
	arrow.collision_layer = 32
	arrow.collision_mask = 10
	arrow.body_entered.connect(_on_arrow_hit.bind(arrow))
	get_tree().current_scene.add_child(arrow)

func _on_arrow_hit(body: Node2D, arrow: StoryProjectile) -> void:
	if body == self: return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		arrow.queue_free()

func use_thunder() -> void:
	# Small item hook: prototype lightning damages the nearest visible enemy.
	var nearest: Node2D
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var distance := global_position.distance_to(enemy.global_position)
			if distance < nearest_distance and distance < 500.0:
				nearest = enemy
				nearest_distance = distance
	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(1, global_position)

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if shield_active and shield_durability > 0:
		shield_durability -= amount
		if shield_durability <= 0:
			shield_active = false
		return
	super.take_damage(amount, source_position)
