class_name EliteSkull
extends CharacterBody2D

# ============================================================
# STANDALONE PLATFORMER ELITE SKULL
# ============================================================
# Replace the existing EliteSkull script with this file.
#
# Scene:
# EliteSkull
# ├── Sprite2D
# ├── CollisionShape2D
# ├── DamageArea          optional
# │   └── CollisionShape2D
# └── SpeechLabel         optional
#
# IMPORTANT:
# The old edge RayCast2D system has been removed.
# Edge turning is controlled by two downward physics raycasts
# created by this script at the actual feet positions.
#
# The skull:
# - patrols horizontally
# - turns before a real platform edge
# - never intentionally crosses a gap
# - chases CT only horizontally
# - stops at gaps during chase
# - attacks CT
# - retreats/re-engages
# - supports CT enemy_event(), damage, knockback and speech
# ============================================================


@export_category("Movement")
@export var patrol_speed: float = 150.0
@export var chase_speed: float = 260.0
@export var retreat_speed: float = 190.0
@export var search_speed: float = 140.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 1600.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1000.0

@export_category("Platform Edge")
@export var turn_at_edge: bool = true
@export var edge_check_distance: float = 20.0
@export var edge_check_depth: float = 80.0
@export var edge_check_start_height: float = 4.0
@export var edge_turn_cooldown: float = 0.18

@export_category("Detection")
@export var detection_distance: float = 500.0
@export var detection_vertical_range: float = 180.0
@export var close_detection_distance: float = 90.0
@export var detection_behind_distance: float = 25.0
@export var lose_target_delay: float = 1.25
@export var require_line_of_sight: bool = true
@export var detection_collision_mask: int = 2
@export var detection_debug: bool = false

@export_category("Combat")
@export var max_health: int = 3
@export var attack_damage: int = 1
@export var attack_distance: float = 105.0
@export var attack_hit_distance: float = 135.0
@export var charge_duration: float = 0.25
@export var attack_duration: float = 0.25
@export var retreat_duration: float = 0.40
@export var retreat_distance: float = 180.0
@export var reengage_delay: float = 0.30

@export_category("Damage")
@export var hit_stun_duration: float = 0.12
@export var knockback_strength: float = 260.0
@export var knockback_vertical: float = 100.0
@export var damage_cooldown: float = 0.20

@export_category("Search")
@export var search_duration: float = 4.0

@export_category("Speech")
@export var enemy_speech_enabled: bool = true
@export var speech_duration: float = 1.2


enum State {
	PATROL,
	CHASE,
	CHARGE,
	ATTACK,
	RETREAT,
	REENGAGE,
	SEARCH,
	DEAD
}


var state: State = State.PATROL

var player: Node2D = null
var health: int = 0
var direction: float = 1.0

var last_seen_position := Vector2.ZERO

var charge_timer := 0.0
var attack_timer := 0.0
var retreat_timer := 0.0
var reengage_timer := 0.0
var search_timer := 0.0
var speech_timer := 0.0
var hit_stun_timer := 0.0
var damage_timer := 0.0
var edge_turn_timer := 0.0

var attack_has_hit := false
var dead := false

var damage_area: Area2D
var detection_ray: RayCast2D
var lost_target_timer: float = 0.0

var left_edge_ray: RayCast2D
var right_edge_ray: RayCast2D

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var speech_label: Label = get_node_or_null("SpeechLabel")


func _ready() -> void:
	health = max_health

	_find_player()
	_find_damage_area()
	_setup_detection_ray()
	_setup_edge_rays()
	_setup_speech()

	state = State.PATROL

	if sprite != null:
		direction = -1.0 if sprite.flip_h else 1.0

	update_facing()

	print(
		"[EliteSkull] READY player=",
		player,
		" position=",
		global_position,
		" state=",
		get_state_name()
	)


func _physics_process(delta: float) -> void:
	if dead:
		return

	_update_timers(delta)
	_update_speech(delta)
	_find_player()

	if hit_stun_timer > 0.0:
		_apply_gravity(delta)
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)
		move_and_slide()
		return

	match state:
		State.PATROL:
			_update_patrol(delta)

		State.CHASE:
			_update_chase(delta)

		State.CHARGE:
			_update_charge(delta)

		State.ATTACK:
			_update_attack(delta)

		State.RETREAT:
			_update_retreat(delta)

		State.REENGAGE:
			_update_reengage(delta)

		State.SEARCH:
			_update_search(delta)

	_apply_gravity(delta)
	move_and_slide()


# ============================================================
# TIMERS / GRAVITY
# ============================================================

func _update_timers(delta: float) -> void:
	hit_stun_timer = maxf(hit_stun_timer - delta, 0.0)
	damage_timer = maxf(damage_timer - delta, 0.0)
	edge_turn_timer = maxf(edge_turn_timer - delta, 0.0)
	lost_target_timer = maxf(lost_target_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return

	velocity.y = minf(
		velocity.y + gravity * delta,
		max_fall_speed
	)


# ============================================================
# PLAYER
# ============================================================

func _find_player() -> void:
	if player != null and is_instance_valid(player):
		return

	var found := get_tree().get_first_node_in_group("player")

	if found is Node2D:
		player = found as Node2D


func has_valid_player() -> bool:
	if player == null:
		return false

	if not is_instance_valid(player):
		player = null
		return false

	return true


func player_is_hidden() -> bool:
	if not has_valid_player():
		return false

	if player.has_method("is_hidden"):
		return bool(player.is_hidden())

	return false


func distance_to_player() -> float:
	if not has_valid_player():
		return INF

	return global_position.distance_to(player.global_position)


# ============================================================
# EDGE DETECTION
# ============================================================
# This is deliberately NOT based on a single RayCast2D attached
# to the skull.
#
# Two rays are created at the actual left/right feet.
# Only the ray in the direction of movement is checked.
#
# Collision mask 2 = Environment, matching the project setup.
# ============================================================

func _setup_edge_rays() -> void:
	left_edge_ray = RayCast2D.new()
	left_edge_ray.name = "LeftEdgeRay"
	left_edge_ray.collision_mask = 2
	left_edge_ray.collide_with_bodies = true
	left_edge_ray.collide_with_areas = false
	left_edge_ray.exclude_parent = true
	left_edge_ray.enabled = true
	add_child(left_edge_ray)

	right_edge_ray = RayCast2D.new()
	right_edge_ray.name = "RightEdgeRay"
	right_edge_ray.collision_mask = 2
	right_edge_ray.collide_with_bodies = true
	right_edge_ray.collide_with_areas = false
	right_edge_ray.exclude_parent = true
	right_edge_ray.enabled = true
	add_child(right_edge_ray)


func _get_collision_half_width() -> float:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision == null or collision.shape == null:
		return 18.0

	var rect := collision.shape.get_rect()

	return maxf(rect.size.x * 0.5, 8.0)


func _get_collision_bottom() -> float:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision == null or collision.shape == null:
		return 24.0

	var rect := collision.shape.get_rect()

	return collision.position.y + rect.position.y + rect.size.y


func _update_edge_rays() -> void:
	if left_edge_ray == null or right_edge_ray == null:
		return

	var half_width := _get_collision_half_width()
	var bottom := _get_collision_bottom()

	# Slightly inside the feet rather than exactly on the body edge.
	var inset := 5.0

	var left_x := -maxf(half_width - inset, 4.0)
	var right_x := maxf(half_width - inset, 4.0)

	left_edge_ray.position = Vector2(
		left_x,
		bottom - edge_check_start_height
	)

	right_edge_ray.position = Vector2(
		right_x,
		bottom - edge_check_start_height
	)

	left_edge_ray.target_position = Vector2(
		0.0,
		edge_check_depth
	)

	right_edge_ray.target_position = Vector2(
		0.0,
		edge_check_depth
	)

	left_edge_ray.force_raycast_update()
	right_edge_ray.force_raycast_update()


func _has_floor_ahead(check_direction: float) -> bool:
	if not turn_at_edge:
		return true

	if edge_turn_timer > 0.0:
		return true

	if absf(check_direction) < 0.01:
		return true

	_update_edge_rays()

	if check_direction < 0.0:
		return left_edge_ray.is_colliding()

	return right_edge_ray.is_colliding()


func _at_platform_edge(check_direction: float) -> bool:
	if not turn_at_edge:
		return false

	if edge_turn_timer > 0.0:
		return false

	# IMPORTANT:
	# Do not edge-test while the body is airborne.
	# Otherwise gravity/spawn can be interpreted as an edge.
	if not is_on_floor():
		return false

	return not _has_floor_ahead(check_direction)


func _turn_from_edge() -> void:
	velocity.x = 0.0
	direction *= -1.0
	edge_turn_timer = edge_turn_cooldown
	update_facing()

	print(
		"[EliteSkull] EDGE -> TURN direction=",
		direction
	)


func _stop_at_edge() -> void:
	velocity.x = 0.0


# ============================================================
# PATROL
# ============================================================

func start_patrol() -> void:
	if dead:
		return

	state = State.PATROL
	velocity.x = 0.0
	lost_target_timer = 0.0
	_set_damage_area_enabled(false)


func _update_patrol(delta: float) -> void:
	if _can_detect_player():
		start_chase()
		return

	if _at_platform_edge(direction):
		_turn_from_edge()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * patrol_speed,
		acceleration * delta
	)

	update_facing()


# ============================================================
# DETECTION
# ============================================================

func _setup_detection_ray() -> void:
	detection_ray = RayCast2D.new()
	detection_ray.name = "DetectionRay"
	detection_ray.enabled = true
	detection_ray.collision_mask = detection_collision_mask
	detection_ray.collide_with_bodies = true
	detection_ray.collide_with_areas = false
	detection_ray.exclude_parent = true
	add_child(detection_ray)


func _player_is_in_detection_zone() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	var offset := player.global_position - global_position
	var horizontal := offset.x
	var vertical := absf(offset.y)

	if vertical > detection_vertical_range:
		return false

	# Very close CT can be detected even if slightly behind.
	if absf(horizontal) <= close_detection_distance:
		return true

	# Normal detection is directional.
	# The skull only sees forward, not through its back.
	if direction > 0.0:
		if horizontal < -detection_behind_distance:
			return false
	else:
		if horizontal > detection_behind_distance:
			return false

	if absf(horizontal) > detection_distance:
		return false

	return true


func _has_detection_line_of_sight() -> bool:
	if not require_line_of_sight:
		return true

	if detection_ray == null:
		return true

	if not has_valid_player():
		return false

	detection_ray.global_position = global_position

	detection_ray.target_position = to_local(
		player.global_position
	)

	detection_ray.force_raycast_update()

	if not detection_ray.is_colliding():
		return true

	var collider := detection_ray.get_collider()

	# Player itself can be a CharacterBody2D.
	if collider == player:
		return true

	# Some player setups have a collision child/body.
	if collider is Node and player.is_ancestor_of(collider):
		return true

	return false


func _can_detect_player() -> bool:
	if not _player_is_in_detection_zone():
		return false

	return _has_detection_line_of_sight()


func _can_keep_chasing_player() -> bool:
	if not has_valid_player():
		return false

	if player_is_hidden():
		return false

	# During chase we allow a slightly larger vertical tolerance
	# so slopes/steps do not instantly break pursuit.
	var offset := player.global_position - global_position

	if absf(offset.y) > detection_vertical_range * 1.5:
		return false

	if absf(offset.x) > detection_distance * 1.35:
		return false

	if _can_detect_player():
		lost_target_timer = lose_target_delay
		return true

	if lost_target_timer > 0.0:
		return true

	return false


# ============================================================
# CHASE
# ============================================================

func start_chase() -> void:
	if not has_valid_player():
		start_patrol()
		return

	if state != State.CHASE:
		print(
			"[EliteSkull] CHASE STARTED distance=",
			distance_to_player()
		)

	state = State.CHASE
	last_seen_position = player.global_position
	lost_target_timer = lose_target_delay

	if detection_debug:
		print(
			"[EliteSkull] TARGET DETECTED distance=",
			distance_to_player(),
			" direction=",
			direction,
			" target=",
			player.global_position
		)

	_face_player()

	if enemy_speech_enabled:
		show_speech("GET BACK HERE!")

	_call_player_enemy_event("detected", "EliteSkull")
	_call_player_enemy_event("chase_started", "EliteSkull")


func _update_chase(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if player_is_hidden():
		start_search()
		return

	if not _can_keep_chasing_player():
		start_search()
		return

	var horizontal := player.global_position.x - global_position.x

	if absf(horizontal) <= attack_distance:
		start_charge()
		return

	direction = -1.0 if horizontal < 0.0 else 1.0

	if _at_platform_edge(direction):
		_stop_at_edge()
		update_facing()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * chase_speed,
		acceleration * delta
	)

	update_facing()


# ============================================================
# CHARGE
# ============================================================

func start_charge() -> void:
	if not has_valid_player():
		start_patrol()
		return

	state = State.CHARGE
	velocity.x = 0.0
	charge_timer = charge_duration
	attack_has_hit = false

	_face_player()

	if enemy_speech_enabled:
		show_speech("GOT YOU!")


func _update_charge(delta: float) -> void:
	if not has_valid_player():
		start_search()
		return

	_face_player()

	charge_timer -= delta

	if charge_timer <= 0.0:
		start_attack()


# ============================================================
# ATTACK
# ============================================================

func start_attack() -> void:
	if not has_valid_player():
		start_search()
		return

	state = State.ATTACK
	velocity.x = 0.0
	attack_timer = attack_duration
	attack_has_hit = false

	_face_player()
	_set_damage_area_enabled(true)

	_perform_attack_hit()

	if enemy_speech_enabled:
		show_speech("HA!")


func _update_attack(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		deceleration * delta
	)

	if has_valid_player():
		_face_player()

	attack_timer -= delta

	_perform_attack_hit()

	if attack_timer > 0.0:
		return

	_set_damage_area_enabled(false)

	if attack_has_hit:
		start_retreat()
	else:
		start_chase()


func _perform_attack_hit() -> void:
	if attack_has_hit:
		return

	if not has_valid_player():
		return

	if player_is_hidden():
		return

	if distance_to_player() > attack_hit_distance:
		return

	attack_has_hit = true

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)

	if player.has_method("damage_flash"):
		player.damage_flash()


# ============================================================
# RETREAT
# ============================================================

func start_retreat() -> void:
	state = State.RETREAT
	retreat_timer = retreat_duration
	velocity.x = 0.0
	_set_damage_area_enabled(false)

	if enemy_speech_enabled:
		show_speech("BACK OFF!")


func _update_retreat(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	direction = signf(
		global_position.x - player.global_position.x
	)

	if absf(direction) < 0.01:
		direction = -1.0

	if _at_platform_edge(direction):
		_turn_from_edge()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * retreat_speed,
		acceleration * delta
	)

	update_facing()

	retreat_timer -= delta

	if retreat_timer <= 0.0 or distance_to_player() >= retreat_distance:
		start_reengage()


# ============================================================
# RE-ENGAGE
# ============================================================

func start_reengage() -> void:
	state = State.REENGAGE
	reengage_timer = reengage_delay
	velocity.x = 0.0


func _update_reengage(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	reengage_timer -= delta

	if reengage_timer > 0.0:
		return

	if _can_detect_player():
		start_chase()
	else:
		start_search()


# ============================================================
# SEARCH
# ============================================================

func start_search() -> void:
	state = State.SEARCH
	search_timer = search_duration
	velocity.x = 0.0

	if enemy_speech_enabled:
		show_speech("COME OUT!")


func _update_search(delta: float) -> void:
	if not has_valid_player():
		start_patrol()
		return

	if _can_detect_player():
		start_chase()
		return

	search_timer -= delta

	if search_timer <= 0.0:
		start_patrol()
		return

	var horizontal := last_seen_position.x - global_position.x

	if absf(horizontal) < 20.0:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)
		return

	direction = -1.0 if horizontal < 0.0 else 1.0

	if _at_platform_edge(direction):
		_turn_from_edge()
		return

	velocity.x = move_toward(
		velocity.x,
		direction * search_speed,
		acceleration * delta
	)

	update_facing()


# ============================================================
# FACING
# ============================================================

func _face_player() -> void:
	if not has_valid_player():
		return

	var dx := player.global_position.x - global_position.x

	if absf(dx) > 0.01:
		direction = -1.0 if dx < 0.0 else 1.0

	update_facing()


func update_facing() -> void:
	if sprite != null:
		sprite.flip_h = direction < 0.0


# ============================================================
# DAMAGE AREA
# ============================================================

func _find_damage_area() -> void:
	damage_area = get_node_or_null("DamageArea") as Area2D

	if damage_area == null:
		damage_area = get_node_or_null("DamageHitbox") as Area2D

	if damage_area != null:
		damage_area.monitoring = false
		damage_area.monitorable = true


func _set_damage_area_enabled(enabled: bool) -> void:
	if damage_area == null:
		return

	damage_area.set_deferred("monitoring", enabled)


# ============================================================
# HEALTH / DAMAGE
# ============================================================

func take_damage(amount: int = 1) -> void:
	if dead or damage_timer > 0.0:
		return

	damage_timer = damage_cooldown
	health -= amount
	hit_stun_timer = hit_stun_duration

	damage_flash()

	if health <= 0:
		die()


func apply_knockback(source_position: Vector2) -> void:
	if dead:
		return

	var away := global_position - source_position

	if absf(away.x) < 0.01:
		away.x = -direction

	direction = signf(away.x)

	if absf(direction) < 0.01:
		direction = -1.0

	velocity.x = direction * knockback_strength
	velocity.y = -knockback_vertical


func damage_flash() -> void:
	if sprite == null:
		return

	var tween := create_tween()

	tween.tween_property(
		sprite,
		"modulate",
		Color(1.0, 0.35, 0.35, 1.0),
		0.05
	)

	tween.tween_property(
		sprite,
		"modulate",
		Color.WHITE,
		0.10
	)


func die() -> void:
	if dead:
		return

	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO

	_set_damage_area_enabled(false)

	if has_node("AnimationPlayer"):
		var animation_player := get_node("AnimationPlayer") as AnimationPlayer

		if animation_player.has_animation("death"):
			animation_player.play("death")
			await animation_player.animation_finished

	queue_free()


# ============================================================
# SPEECH
# ============================================================

func _setup_speech() -> void:
	if speech_label != null:
		speech_label.visible = false


func show_speech(text: String) -> void:
	if not enemy_speech_enabled:
		return

	if speech_label == null:
		return

	if text.is_empty():
		return

	speech_label.text = text
	speech_label.visible = true
	speech_timer = speech_duration


func _update_speech(delta: float) -> void:
	if speech_label == null or not speech_label.visible:
		return

	speech_timer -= delta

	if speech_timer <= 0.0:
		speech_label.visible = false


# ============================================================
# CT COMPATIBILITY
# ============================================================

func _call_player_enemy_event(event_name: String, enemy_type: String) -> void:
	if not has_valid_player():
		return

	if player.has_method("enemy_event"):
		player.enemy_event(event_name, enemy_type)


func register_damage_area_hit() -> void:
	attack_has_hit = true


func is_attacking() -> bool:
	return state == State.ATTACK


func get_state_name() -> String:
	match state:
		State.PATROL:
			return "PATROL"
		State.CHASE:
			return "CHASE"
		State.CHARGE:
			return "CHARGE"
		State.ATTACK:
			return "ATTACK"
		State.RETREAT:
			return "RETREAT"
		State.REENGAGE:
			return "REENGAGE"
		State.SEARCH:
			return "SEARCH"
		State.DEAD:
			return "DEAD"

	return "UNKNOWN"
