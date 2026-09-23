extends CharacterBody2D


# ============================================================
# MOVEMENT
# ============================================================

@export var move_speed: float = 500.0


# ============================================================
# HEALTH
# ============================================================

@export var max_health: int = 3
@export var death_delay: float = 0.6

var health: int = max_health
var is_dead: bool = false


# ============================================================
# DAMAGE / STORY REACTIONS
# ============================================================

@export_category("Story Reactions")
@export var gameplay_reactions_enabled: bool = true
@export var gameplay_reaction_cooldown: float = 2.0

var story_controller: Node = null
var last_reaction_time: float = -9999.0

@export var damage_cooldown: float = 0.7
@export var knockback_force: float = 520.0
@export var knockback_friction: float = 2200.0
@export var hit_stun_time: float = 0.12

var can_take_damage: bool = true
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_stun_timer: float = 0.0
var is_flashing: bool = false

var hit_stop_time: float = 0.05


# ============================================================
# HIDING
# ============================================================

@export_category("Hiding Visual")

@export_range(0.1, 1.0, 0.05)
var hidden_opacity: float = 0.4

@export var hiding_fade_duration: float = 0.15

var is_player_hidden: bool = false
var current_hiding_spot: Node = null

var hiding_tween: Tween


# ============================================================
# CT SPEECH
#
# IMPORTANT:
# Player.gd no longer generates autonomous chatter.
#
# CT is SILENT unless an explicit gameplay event calls
# show_reaction() or StoryController calls show_story_speech().
# ============================================================

@export_category("CT Speech")

@export var speech_enabled: bool = true
@export var speech_duration: float = 2.2

var speech_hide_timer: float = 0.0
var speech_label: Label = null

# Story dialogue temporarily owns the speech bubble.
var story_speech_active: bool = false


# ============================================================
# CT STATE
# ============================================================

var coins_this_life: int = 0
var damage_count: int = 0
var recent_coin_streak: int = 0

var last_action: String = "nothing"


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	story_controller = get_tree().get_first_node_in_group(
		"story_controller"
	)

	health = max_health

	speech_label = get_node_or_null("SpeechLabel")

	if speech_label != null:
		speech_label.visible = false


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	if is_dead:
		return

	_update_speech(delta)
	_update_movement(delta)

	move_and_slide()


# ============================================================
# MOVEMENT
# ============================================================

func _update_movement(delta: float) -> void:

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_friction * delta
	)

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		return

	velocity = input_vector * move_speed + knockback_velocity

	if input_vector.x != 0.0:
		$Sprite2D.flip_h = input_vector.x < 0.0


# ============================================================
# SPEECH DISPLAY
#
# There is NO idle timer.
# There is NO movement chatter.
# There is NO random speech generation.
# ============================================================

func _update_speech(delta: float) -> void:

	if not speech_enabled:
		return

	if speech_label == null:
		return

	if story_speech_active:
		return

	if speech_hide_timer <= 0.0:
		return

	speech_hide_timer -= delta

	if speech_hide_timer <= 0.0:
		speech_label.visible = false


func show_reaction(text: String) -> void:

	if not speech_enabled:
		return

	if speech_label == null:
		return

	if text.is_empty():
		return

	if story_speech_active:
		return

	speech_label.text = text
	speech_label.visible = true
	speech_hide_timer = speech_duration


func show_story_speech(
	speaker: String,
	text: String
) -> void:

	if speech_label == null:
		return

	if text.is_empty():
		return

	story_speech_active = true

	speech_label.text = text
	speech_label.visible = true

	speech_hide_timer = 0.0


func hide_story_speech() -> void:

	if speech_label == null:
		return

	story_speech_active = false
	speech_label.visible = false
	speech_hide_timer = 0.0


# ============================================================
# COIN EVENT
#
# Deterministic reactions.
# No pick_random().
# ============================================================

func coin_collected() -> void:

	if is_dead:
		return

	coins_this_life += 1
	recent_coin_streak += 1
	last_action = "coin"

	match coins_this_life:

		1:
			show_reaction("Oh...")

		2:
			show_reaction("Another one.")

		3:
			show_reaction("Okay, this is going well.")

		4:
			show_reaction("Nobody needs to know about these.")

		5:
			show_reaction("Just one more.")

		10:
			show_reaction("I may have a problem.")

		20:
			show_reaction("Okay... that's a lot of coins.")

		_:
			# Silence.
			pass

	emit_gameplay_story_event("coin_collected")


# ============================================================
# HIDING
# ============================================================

func enter_hiding(hiding_spot: Node) -> void:

	if current_hiding_spot != null:
		if current_hiding_spot != hiding_spot:
			return

	current_hiding_spot = hiding_spot
	is_player_hidden = true

	last_action = "hiding"
	recent_coin_streak = 0

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	_set_hidden_visual(true)

	# One deliberate line. Not random.
	show_reaction("Okay... I'm a bush now.")

	emit_gameplay_story_event("player_hidden")


func exit_hiding(hiding_spot: Node) -> void:

	if current_hiding_spot != hiding_spot:
		return

	current_hiding_spot = null
	is_player_hidden = false

	last_action = "left_hiding"

	$DamageHitbox.set_deferred(
		"monitorable",
		true
	)

	_set_hidden_visual(false)

	# One deliberate line. Not random.
	show_reaction("Okay... back to business.")

	emit_gameplay_story_event("player_left_hiding")


func is_hidden() -> bool:
	return is_player_hidden


# ============================================================
# HIDING VISUAL
# ============================================================

func _set_hidden_visual(hidden: bool) -> void:

	var target_opacity := (
		hidden_opacity
		if hidden
		else 1.0
	)

	if hiding_tween != null:
		if hiding_tween.is_valid():
			hiding_tween.kill()

	hiding_tween = create_tween()

	hiding_tween.set_trans(
		Tween.TRANS_SINE
	)

	hiding_tween.set_ease(
		Tween.EASE_OUT
	)

	hiding_tween.tween_property(
		$Sprite2D,
		"modulate:a",
		target_opacity,
		hiding_fade_duration
	)


# ============================================================
# DAMAGE
# ============================================================

func take_damage(amount: int) -> void:

	if is_dead:
		return

	if not can_take_damage:
		return

	if is_player_hidden:
		return

	can_take_damage = false

	health -= amount
	damage_count += 1

	last_action = "damaged"
	recent_coin_streak = 0

	print(
		"CT took damage: ",
		amount
	)

	print(
		"CT health: ",
		health,
		"/",
		max_health
	)

	# Deliberate escalation instead of random lines.
	match damage_count:

		1:
			show_reaction("HEY! Rude.")

		2:
			show_reaction("Okay... now it's personal.")

		_:
			show_reaction("WHY DO YOU KEEP HITTING ME?!")

	emit_gameplay_story_event("player_damaged")

	damage_flash()

	Engine.time_scale = 0.0

	await get_tree().create_timer(
		hit_stop_time,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0

	if health <= 0:
		die()
		return

	await get_tree().create_timer(
		damage_cooldown
	).timeout

	if not is_dead:
		can_take_damage = true


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	if is_dead:
		return

	is_dead = true
	can_take_damage = false

	last_action = "dead"

	emit_gameplay_story_event("player_died")

	Engine.time_scale = 1.0

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	hit_stun_timer = 0.0

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	show_reaction("Okay... that went badly.")

	await get_tree().create_timer(
		death_delay,
		true,
		false,
		true
	).timeout

	CheckpointManager.restart_checkpoint()


# ============================================================
# DAMAGE FLASH
# ============================================================

func damage_flash() -> void:

	if is_flashing:
		return

	is_flashing = true

	var original_modulate := modulate

	modulate = Color(
		1.0,
		0.35,
		0.35,
		1.0
	)

	await get_tree().create_timer(
		0.1
	).timeout

	modulate = original_modulate

	is_flashing = false


# ============================================================
# KNOCKBACK
# ============================================================

func apply_knockback(source_position: Vector2) -> void:

	var offset := global_position - source_position

	if offset.length_squared() < 0.001:
		return

	var direction := offset.normalized()

	knockback_velocity = direction * knockback_force

	hit_stun_timer = hit_stun_time


# ============================================================
# STORY EVENT ROUTING
# ============================================================

func emit_gameplay_story_event(
	event_name: String
) -> void:

	if not gameplay_reactions_enabled:
		return

	if story_controller == null:
		story_controller = get_tree().get_first_node_in_group(
			"story_controller"
		)

	if story_controller == null:
		return

	if not story_controller.has_method(
		"emit_gameplay_event"
	):
		return

	var now := Time.get_ticks_msec() / 1000.0

	if now - last_reaction_time < gameplay_reaction_cooldown:
		return

	last_reaction_time = now

	story_controller.emit_gameplay_event(
		event_name,
		gameplay_reaction_cooldown
	)
