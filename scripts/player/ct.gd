extends CharacterBody2D


# ============================================================
# PLATFORMER MOVEMENT
# ============================================================

@export_category("Platformer Movement")
@export var move_speed: float = 500.0
@export var acceleration: float = 2200.0
@export var deceleration: float = 2600.0
@export var jump_velocity: float = -780.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1500.0

@export_category("Jump Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var variable_jump_gravity: float = 1800.0

@export_category("Platformer Controls")
@export var left_action: StringName = &"move_left"
@export var right_action: StringName = &"move_right"
@export var jump_action: StringName = &"jump"

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


# ============================================================
# HEALTH
# ============================================================

@export var max_health: int = 3
@export var death_delay: float = 0.6

var health: int = max_health
var is_dead: bool = false


# ============================================================
# DAMAGE
# ============================================================

@export_category("Damage")

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
# CT does NOT speak on idle, movement, patrol, or time.
#
# All gameplay speech comes from explicit events:
#   coin collected
#   hiding
#   damage
#   death
#   chase/detection events
#   story beats
# ============================================================

@export_category("CT Speech")

@export var speech_enabled: bool = true
@export var speech_duration: float = 2.2
@export var speech_cooldown: float = 0.55

var speech_hide_timer: float = 0.0
var speech_label: Label = null
var story_speech_active: bool = false
var speech_last_time: float = -9999.0


# ============================================================
# CT STORY STATE
# ============================================================

var coins_this_life: int = 0
var damage_count: int = 0
var chase_count: int = 0
var recent_coin_streak: int = 0

var used_speech: Dictionary = {}

var story_controller: Node = null


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
	_update_platformer_movement(delta)

	move_and_slide()


# ============================================================
# PLATFORMER MOVEMENT
# ============================================================

func _update_platformer_movement(delta: float) -> void:
	# Keep the original CT knockback and hit-stun behavior.
	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_friction * delta
	)

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		return

	_update_jump_timers(delta)
	_apply_platformer_gravity(delta)
	_apply_horizontal_movement(delta)
	_handle_jump()
	_apply_variable_jump(delta)

	# Enemy knockback is preserved on top of platformer movement.
	velocity += knockback_velocity

	if absf(velocity.x) > 5.0:
		$Sprite2D.flip_h = velocity.x < 0.0


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed(jump_action):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func _apply_platformer_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _apply_horizontal_movement(delta: float) -> void:
	var direction: float = Input.get_axis(
		left_action,
		right_action
	)

	if absf(direction) > 0.01:
		velocity.x = move_toward(
			velocity.x,
			direction * move_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)


func _handle_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if coyote_timer <= 0.0:
		return

	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _apply_variable_jump(delta: float) -> void:
	if velocity.y < 0.0 and not Input.is_action_pressed(jump_action):
		velocity.y = minf(
			velocity.y + variable_jump_gravity * delta,
			0.0
		)


# ============================================================
# SPEECH DISPLAY
# ============================================================

func _update_speech(delta: float) -> void:
	if speech_label == null:
		return

	if story_speech_active:
		return

	if speech_hide_timer <= 0.0:
		return

	speech_hide_timer -= delta

	if speech_hide_timer <= 0.0:
		speech_label.visible = false


func show_reaction(text: String, force: bool = false) -> void:
	if not speech_enabled:
		return

	if speech_label == null:
		return

	if text.is_empty():
		return

	if story_speech_active:
		return

	if not force:
		var now := Time.get_ticks_msec() / 1000.0

		if now - speech_last_time < speech_cooldown:
			return

		speech_last_time = now

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
# UNIQUE LINE PICKER
#
# Guarantees different text until the pool is exhausted.
# No immediate repeats.
# ============================================================

func _pick_unique_line(pool: Array[String], key: String) -> String:
	if pool.is_empty():
		return ""

	var used: Array = used_speech.get(key, [])

	var available: Array[String] = []

	for line in pool:
		if not used.has(line):
			available.append(line)

	# Pool exhausted -> reset the pool and start a new cycle.
	if available.is_empty():
		used = []
		available = pool.duplicate()

	var index := randi_range(0, available.size() - 1)
	var selected: String = available[index]

	used.append(selected)
	used_speech[key] = used

	return selected


# ============================================================
# COINS
#
# CT ONLY talks about coins here.
# No coin-related lines are used by damage/chase/hiding.
# ============================================================

func coin_collected() -> void:
	if is_dead:
		return

	coins_this_life += 1
	recent_coin_streak += 1

	var pool: Array[String]

	match coins_this_life:
		1:
			pool = [
				"Oh hello, shiny little financial opportunity.",
				"Mine.",
				"Found money. My favorite kind.",
				"One coin. This expedition has funding.",
				"Beautiful. Absolutely beautiful."
			]

		2:
			pool = [
				"Another coin? The universe understands me.",
				"Two already. I am becoming irresponsible.",
				"Coin number two. No witnesses.",
				"This is getting suspiciously profitable.",
				"Okay... we're officially collecting these now."
			]

		3:
			pool = [
				"Three coins. I'm basically an investor.",
				"I should probably stop. I will not.",
				"Look at that. Free money lying around.",
				"Three shiny reasons to keep going.",
				"My pockets are beginning to have purpose."
			]

		4:
			pool = [
				"Four. Completely normal amount of coin obsession.",
				"Nobody needs to know about these.",
				"At this rate, I can retire by lunch.",
				"Who keeps dropping all this money?",
				"I have developed a system. It is called picking them up."
			]

		5:
			pool = [
				"Five! The pocket economy is booming.",
				"Just one more... probably.",
				"Okay, this is becoming a lifestyle.",
				"Five coins and absolutely zero regrets.",
				"I came for adventure. I stayed for loose change."
			]

		6, 7, 8, 9:
			pool = [
				"This feels less like collecting and more like a personality trait.",
				"Coin acquired. Morals still pending.",
				"Keep shining, tiny rectangles.",
				"I hear my pockets getting heavier.",
				"At some point this becomes a treasure hunt.",
				"Nope. Still want more."
			]

		10:
			pool = [
				"TEN! I AM FINANCIALLY DANGEROUS.",
				"Ten coins. This is no longer a hobby.",
				"Okay, who gave me this much money to find?",
				"I have entered my coin goblin era.",
				"Ten! My pockets demand expansion."
			]

		11, 12, 13, 14, 15, 16, 17, 18, 19:
			pool = [
				"Another one for the collection.",
				"I absolutely did not plan on finding this many.",
				"The coin trail continues. So do I.",
				"Shiny thing detected. Career maintained.",
				"One more coin, zero practical reasons.",
				"I should be embarrassed. I am delighted.",
				"These coins are finding me at this point.",
				"Pocket status: concerning.",
				"This is getting deliciously irresponsible."
			]

		20:
			pool = [
				"TWENTY! That's enough to make bad decisions.",
				"Twenty coins. I can feel the greed.",
				"Okay... that is a LOT of shiny.",
				"Twenty! My relationship with money is getting serious.",
				"Mission update: I have become the problem."
			]

		_:
			pool = [
				"Another shiny little victory.",
				"Coin. Pocket. Happiness.",
				"I regret nothing.",
				"Still collecting. Still unwell.",
				"Shiny acquired. Continue immediately.",
				"My pockets are running out of dignity.",
				"At this point, leaving coins behind feels illegal.",
				"This treasure hunt has become very personal.",
				"I found money. Again. Naturally.",
				"Why is this more exciting than it should be?"
			]

	show_reaction(
		DialogueManager.ct("coin"),
		true
	)

	_emit_gameplay_story_event("coin_collected")


# ============================================================
# HIDING
# ============================================================

func enter_hiding(hiding_spot: Node) -> void:
	if current_hiding_spot != null:
		if current_hiding_spot != hiding_spot:
			return

	current_hiding_spot = hiding_spot
	is_player_hidden = true

	recent_coin_streak = 0

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	_set_hidden_visual(true)

	var pool: Array[String] = [
		"Okay. I am now shrub-shaped.",
		"Nobody move. I am part of nature.",
		"Stealth mode: professionally leafy.",
		"If anyone asks, I have always been a bush.",
		"Perfect. Time to become vegetation.",
		"I have chosen the ancient art of hiding.",
		"Camouflage level: questionable.",
		"Nothing to see here. Except... leaves.",
		"I am one with the shrubbery.",
		"Excellent. Tactical plant mode."
	]

	show_reaction(
		DialogueManager.ct("hiding"),
		true
	)

	_emit_gameplay_story_event("player_hidden")


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

	var pool: Array[String] = [
		"Okay. Leaves behind, business ahead.",
		"Bush break is over.",
		"Back to being suspicious.",
		"Nature has released me.",
		"Stealth holiday: concluded.",
		"Time to walk around like that was normal.",
		"I have returned from the wilderness.",
		"All right. Sneaking resumes.",
		"Back on two feet and making poor choices."
	]

	show_reaction(
		DialogueManager.ct("hide_exit"),
		true
	)

	_emit_gameplay_story_event("player_left_hiding")


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
	recent_coin_streak = 0

	var pool: Array[String]

	match damage_count:
		1:
			pool = [
				"HEY! That was attached to me!",
				"Rude!",
				"Excuse me?!",
				"Okay, that hurt.",
				"Unnecessary!"
			]

		2:
			pool = [
				"Okay, now we're having a problem.",
				"That was your second mistake.",
				"Ow! We're escalating!",
				"I was being nice!",
				"Can we discuss this without hitting me?"
			]

		_:
			pool = [
				"STOP BONKING ME!",
				"I HAVE HAD ENOUGH OF THIS!",
				"WHY ARE WE SOLVING EVERYTHING WITH VIOLENCE?!",
				"MY BODY IS NOT A TARGET PRACTICE RANGE!",
				"OKAY! I GET IT! YOU'RE STRONG!",
				"THIS IS BECOMING VERY PERSONAL!"
			]

	show_reaction(
		DialogueManager.ct("damage"),
		true
	)

	_emit_gameplay_story_event("player_damaged")

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

	_emit_gameplay_story_event("player_died")

	Engine.time_scale = 1.0

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	hit_stun_timer = 0.0

	$DamageHitbox.set_deferred(
		"monitorable",
		false
	)

	var pool: Array[String] = [
		"Well. That could have gone better.",
		"I have made several poor decisions today.",
		"Okay. New plan: don't die.",
		"That was aggressively unsuccessful.",
		"I would like to rewind the last few seconds.",
		"Yep. Definitely dead.",
		"Cool. Cool cool cool. Everything is terrible.",
		"I blame the environment.",
		"That was not part of the plan.",
		"Excellent. A complete disaster."
	]

	show_reaction(
		DialogueManager.ct("death"),
		true
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
	var offset := global_position - source_position

	if offset.length_squared() < 0.001:
		return

	var direction := offset.normalized()

	knockback_velocity = direction * knockback_force
	hit_stun_timer = hit_stun_time


# ============================================================
# STORY EVENTS
# ============================================================

func _emit_gameplay_story_event(event_name: String) -> void:
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

	story_controller.emit_gameplay_event(
		event_name,
		0.25
	)


# ============================================================
# CHASE REACTIONS
#
# These are ONLY called when an enemy actually changes state.
# They NEVER mention coins.
# ============================================================

func on_enemy_detected(enemy_type: String = "enemy") -> void:
	if is_dead:
		return

	var pool: Array[String]

	if enemy_type.to_lower().contains("skull"):
		pool = [
			"Oh no. The bony one noticed me.",
			"Great. I have been perceived by a skeleton.",
			"Fantastic. Skeleton eyes. Exactly what I needed.",
			"That skull definitely saw me.",
			"Okay. New objective: remain un-skeletoned.",
			"Why is that thing looking at me like that?",
			"I have been spotted. This is unfortunate.",
			"Well hello there, extremely alarming skull.",
			"That is the face of someone who has bad intentions.",
			"I preferred it when we were strangers."
		]
	else:
		pool = [
			"Oh. That one noticed me.",
			"Uh... I have attracted attention.",
			"That seems bad.",
			"Yep. Definitely saw me.",
			"Okay, stealth has officially failed.",
			"I have been perceived. Terrible development.",
			"That is not the reaction I was hoping for.",
			"Well, this just got complicated."
		]

	show_reaction(
		DialogueManager.ct("skull_detect" if enemy_type.to_lower().contains("skull") else "enemy_detect"),
		true
	)


func on_enemy_chase_started(enemy_type: String = "enemy") -> void:
	if is_dead:
		return

	chase_count += 1
	DialogueManager.next_counter("skull_chase")

	var pool: Array[String]

	if enemy_type.to_lower().contains("skull"):
		pool = [
			"WHY IS THE SKULL SPRINTING?!",
			"NOPE NOPE NOPE—THE SKULL HAS ENTERED RUN MODE!",
			"WHY DOES A SKULL HAVE BETTER CARDIO THAN ME?!",
			"HEY! WE CAN TALK ABOUT THIS!",
			"I WOULD LIKE TO FILE A COMPLAINT WITH THE SKELETON DEPARTMENT!",
			"WHY ARE YOU SO COMMITTED TO THIS?!",
			"STOP FOLLOWING ME! THIS IS GETTING CREEPY!",
			"THIS IS NOT A FAIR RACE! YOU DON'T EVEN HAVE MUSCLES!",
			"WHY IS THE BONE MAN SO FAST?!",
			"I AM BEGINNING TO REGRET BEING VISIBLE!",
			"HELLO! PERSONAL SPACE!",
			"THIS IS A CHASE, NOT A FRIENDSHIP ACTIVITY!",
			"WHY ARE YOU STILL COMING?!",
			"I TAKE BACK EVERYTHING I SAID ABOUT BEING BRAVE!",
			"CAN WE BOTH AGREE THAT THIS IS EMBARRASSING?!",
			"SKULL! PLEASE! I HAVE PLACES TO NOT DIE!"
		]
	else:
		pool = [
			"WHY ARE YOU CHASING ME?!",
			"HEY! I WAS JUST PASSING THROUGH!",
			"NOPE! I AM NOT INTERESTED IN THIS!",
			"CAN WE NOT DO THE RUNNING THING?!",
			"I DON'T KNOW YOU WELL ENOUGH FOR THIS!",
			"WHY AM I ALWAYS THE FAST FOOD IN THESE SITUATIONS?!",
			"PLEASE STOP! I HAVE NOTHING TO DISCUSS!",
			"THIS ESCALATED VERY QUICKLY!",
			"RUNNING WAS NOT IN MY PLAN FOR TODAY!",
			"CAN WE RESCHEDULE THIS CHASE?!"
		]

	show_reaction(
		DialogueManager.ct("skull_chase" if enemy_type.to_lower().contains("skull") else "enemy_chase", {"chase_number": chase_count}),
		true
	)


func on_enemy_attack_started(enemy_type: String = "enemy") -> void:
	if is_dead:
		return

	var pool: Array[String]

	if enemy_type.to_lower().contains("skull"):
		pool = [
			"OH, YOU'RE SWINGING NOW?!",
			"HEY! NO BONKING!",
			"THAT ATTACK LOOKS VERY UNFRIENDLY!",
			"WAIT! I OBJECT!",
			"CAN WE NOT DO THE VIOLENCE PART?!",
			"I HAVE SEEN ENOUGH OF THIS SKULL'S PLAN!"
		]
	else:
		pool = [
			"OH, COME ON!",
			"HEY! DON'T DO THAT!",
			"WAIT! WHAT ARE YOU DOING?!",
			"I DO NOT LIKE THAT ANIMATION!",
			"NO THANK YOU!"
		]

	show_reaction(
		DialogueManager.ct("skull_attack" if enemy_type.to_lower().contains("skull") else "enemy_attack"),
		true
	)


func on_enemy_lost(enemy_type: String = "enemy") -> void:
	if is_dead:
		return

	var pool: Array[String]

	if enemy_type.to_lower().contains("skull"):
		pool = [
			"Ha! Lost me, bonehead.",
			"I am officially too sneaky for skeletons.",
			"YES! The bones have lost the trail!",
			"Good luck finding me, spooky calcium.",
			"That went better than expected.",
			"Excellent. I remain un-boned.",
			"Back to pretending that never happened.",
			"Ghosted by a skull. Incredible.",
			"Survival status: somehow still active."
		]
	else:
		pool = [
			"Ha! Lost you.",
			"Okay. We're good.",
			"I think I escaped that one.",
			"Excellent. Back to normal.",
			"That was close.",
			"I will absolutely not talk about that."
		]

	show_reaction(
		DialogueManager.ct("skull_lost" if enemy_type.to_lower().contains("skull") else "enemy_lost", {"chase_number": chase_count}),
		true
	)


# ============================================================
# OPTIONAL GENERIC ENEMY HOOK
# ============================================================

func enemy_event(event_name: String, enemy_type: String = "enemy") -> void:
	match event_name:
		"detected":
			on_enemy_detected(enemy_type)

		"chase_started":
			on_enemy_chase_started(enemy_type)

		"attack_started":
			on_enemy_attack_started(enemy_type)

		"lost":
			on_enemy_lost(enemy_type)
