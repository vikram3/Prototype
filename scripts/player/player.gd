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
# DAMAGE / KNOCKBACK
# ============================================================

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
# SPEECH
# ============================================================

@export_category("CT Speech")

@export var speech_enabled: bool = true

@export_group("Speech Timing")
@export var idle_speech_min_time: float = 2.0
@export var idle_speech_max_time: float = 4.0
@export var movement_speech_chance: float = 0.45
@export var speech_duration: float = 2.0

var speech_timer: float = 0.0
var speech_hide_timer: float = 0.0

var speech_label: Label = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	health = max_health

	speech_label = get_node_or_null("SpeechLabel")

	if speech_label != null:
		# SpeechLabel position, size, font, color,
		# alignment, outline and shadow are controlled
		# entirely from the editor.
		speech_label.visible = false

	_reset_speech_timer()

	if speech_enabled:
		await get_tree().process_frame
		_show_random_speech(_intro_text())


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

	# Normal movement.
	velocity = input_vector * move_speed + knockback_velocity

	# Flip CT only when moving horizontally.
	if input_vector.x != 0.0:
		$Sprite2D.flip_h = input_vector.x < 0.0

		# Random movement chatter.
		if randf() < movement_speech_chance * delta:
			_show_random_speech(_movement_text())


# ============================================================
# SPEECH SYSTEM
# ============================================================

func _update_speech(delta: float) -> void:
	if not speech_enabled:
		return

	if speech_label == null:
		return

	# Hide speech after duration.
	if speech_hide_timer > 0.0:
		speech_hide_timer -= delta

		if speech_hide_timer <= 0.0:
			speech_label.visible = false

	# Random idle talking.
	speech_timer -= delta

	if speech_timer <= 0.0 and not is_dead:
		_show_random_speech(_idle_text())
		_reset_speech_timer()


func _reset_speech_timer() -> void:
	speech_timer = randf_range(
		idle_speech_min_time,
		idle_speech_max_time
	)


func show_speech(text: String) -> void:
	if not speech_enabled:
		return

	if speech_label == null:
		return

	if text.is_empty():
		return

	speech_label.text = text
	speech_label.visible = true

	speech_hide_timer = speech_duration


func _show_random_speech(lines: Array[String]) -> void:
	if lines.is_empty():
		return

	show_speech(lines.pick_random())


# ============================================================
# SPEECH — INTRO
# ============================================================

func _intro_text() -> Array[String]:
	return [
		"Okay... where are the coins?",
		"Today's gonna be a rich day.",
		"I smell treasure.",
		"Nobody said I couldn't take these.",
		"Time to get rich!",
		"Operation: Steal All The Coins.",
		"Hehehe... shiny.",
		"Okay CT, act normal.",
		"I am definitely not stealing anything.",
		"Where's the good stuff?"
	]


# ============================================================
# SPEECH — IDLE
# ============================================================

func _idle_text() -> Array[String]:
	return [
		"Where are my coins?",
		"That bush looks suspicious.",
		"Maybe I should steal that too.",
		"Coin coin coin coin coin...",
		"I am being extremely sneaky.",
		"Very professional treasure hunting.",
		"I wonder what's over there.",
		"Something shiny must be nearby.",
		"I definitely have a plan.",
		"This is going perfectly.",
		"Nobody suspects a thing.",
		"I could really use some coins.",
		"Why is everyone guarding their coins?",
		"I was born for this.",
		"Stealth mode activated.",
		"Hehehe..."
	]


# ============================================================
# SPEECH — MOVEMENT
# ============================================================

func _movement_text() -> Array[String]:
	return [
		"NYOOOM!",
		"Coming through!",
		"Coin time!",
		"Shhh... sneaky mode.",
		"Outta my way!",
		"Gotta go!",
		"Fast feet!",
		"Treasure hunt!",
		"Catch me if you can!",
		"Zoom!",
		"I'M BUSY!",
		"COINS!",
		"Where's the treasure?!"
	]


# ============================================================
# SPEECH — COIN
# ============================================================

func _coin_text() -> Array[String]:
	return [
		"OOOH! SHINY!",
		"MY PRECIOUS!",
		"FREE MONEY!",
		"CHA-CHING!",
		"GET IN MY POCKET!",
		"RICH RICH RICH!",
		"THE TREASURE IS REAL!",
		"YESSS!",
		"ANOTHER ONE!",
		"KEEP 'EM COMING!",
		"MY COIN!",
		"HEHEHEHE!",
		"THIS IS MINE NOW."
	]


# ============================================================
# SPEECH — DAMAGE
# ============================================================

func _damage_text() -> Array[String]:
	return [
		"HEY! RUDE!",
		"OW!",
		"THAT HURT!",
		"HEY! I HAVE COINS!",
		"MY BEAUTIFUL FACE!",
		"OKAY! THAT'S PERSONAL!",
		"RUDE!",
		"THAT WAS MY GOOD SIDE!",
		"I'M TELLING SOMEONE!",
		"WHY?!",
		"HEY! WATCH IT!",
		"UNCOOL!"
	]


# ============================================================
# SPEECH — HIDING
# ============================================================

func _hiding_text() -> Array[String]:
	return [
		"Shhh...",
		"I'm a bush now.",
		"You can't see me.",
		"I have become foliage.",
		"Definitely just a plant.",
		"I am invisible.",
		"Totally natural bush.",
		"Nobody look over here.",
		"Stealth level: genius.",
		"I am one with the bush."
	]


# ============================================================
# SPEECH — EXIT HIDING
# ============================================================

func _exit_hiding_text() -> Array[String]:
	return [
		"Okay, I'm out!",
		"Coast clear!",
		"Back to stealing!",
		"That was close.",
		"Nobody saw me.",
		"Back to business!",
		"Operation continues!"
	]


# ============================================================
# SPEECH — DEATH
# ============================================================

func _death_text() -> Array[String]:
	return [
		"MY COINS!!!",
		"NOOOOO!",
		"BUT I WAS GETTING RICH!",
		"THIS IS SO UNFAIR!",
		"MY TREASURE...",
		"I'LL BE BACK!",
		"WHY IS EVERYTHING TRYING TO KILL ME?!",
		"OKAY... THAT DIDN'T GO WELL.",
		"REMATCH!",
		"I REGRET NOTHING!",
		"MY BEAUTIFUL COINS!",
		"WAIT! I WASN'T READY!"
	]


# ============================================================
# PUBLIC COIN EVENT
# ============================================================

func coin_collected() -> void:
	show_speech(_coin_text().pick_random())


# ============================================================
# HIDING
# ============================================================

func enter_hiding(hiding_spot: Node) -> void:
	if current_hiding_spot != null and current_hiding_spot != hiding_spot:
		return

	current_hiding_spot = hiding_spot
	is_player_hidden = true

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	_set_hidden_visual(true)

	show_speech(
		_hiding_text().pick_random()
	)


func exit_hiding(hiding_spot: Node) -> void:
	if current_hiding_spot != hiding_spot:
		return

	current_hiding_spot = null
	is_player_hidden = false

	$DamageHitbox.set_deferred(
		"monitorable",
		true
	)

	_set_hidden_visual(false)

	show_speech(
		_exit_hiding_text().pick_random()
	)


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

	if hiding_tween != null and hiding_tween.is_valid():
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

	show_speech(
		_damage_text().pick_random()
	)

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

	Engine.time_scale = 1.0

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	hit_stun_timer = 0.0

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	show_speech(
		_death_text().pick_random()
	)

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
	var offset := (
		global_position -
		source_position
	)

	if offset.length_squared() < 0.001:
		return

	var direction := offset.normalized()

	knockback_velocity = (
		direction *
		knockback_force
	)

	hit_stun_timer = hit_stun_time
