class_name PlatformerActor
extends CharacterBody2D

## Small shared foundation for the new side-scrolling prototypes.  It intentionally
## does not alter CT or the established Skull implementations.
@export_category("Platformer")
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1200.0
@export var walk_speed: float = 180.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 1800.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var damage_cooldown: float = 0.35
@export var story_mode: bool = false
@export var invulnerable: bool = false
@export_category("Personality")
@export var personality_name: String = ""
@export var idle_lines: PackedStringArray = []
@export var combat_lines: PackedStringArray = []
@export var speech_duration: float = 2.4
@export var speech_cooldown: float = 2.0

var health: int
var facing: float = 1.0
var damage_timer: float = 0.0
var disabled: bool = false
var speech_timer: float = 0.0
var speech_cooldown_timer: float = 0.0
var speech_label: Label

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	_setup_speech()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

func move_horizontal(target_speed: float, delta: float) -> void:
	var rate := acceleration if absf(target_speed) > absf(velocity.x) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if absf(target_speed) > 1.0:
		facing = signf(target_speed)
		if sprite != null:
			sprite.flip_h = facing < 0.0

func find_player() -> Node2D:
	var candidate := get_tree().get_first_node_in_group("player")
	return candidate as Node2D if candidate is Node2D else null

func damage_player(player: Node2D, amount: int = contact_damage) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("take_damage"):
		player.take_damage(amount)
	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)
	say_random(combat_lines)

func take_damage(amount: int = 1, source_position: Vector2 = Vector2.ZERO) -> void:
	if disabled or invulnerable or story_mode or damage_timer > 0.0:
		return
	damage_timer = damage_cooldown
	health -= amount
	if source_position != Vector2.ZERO:
		velocity.x = signf(global_position.x - source_position.x) * 260.0
	if sprite != null:
		sprite.modulate = Color(1.0, 0.45, 0.45)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		disabled = true
		velocity = Vector2.ZERO
		set_collision_layer_value(4, false)

func _process_damage_timer(delta: float) -> void:
	damage_timer = maxf(damage_timer - delta, 0.0)
	speech_cooldown_timer = maxf(speech_cooldown_timer - delta, 0.0)
	if speech_label != null and speech_label.visible:
		speech_timer -= delta
		if speech_timer <= 0.0:
			speech_label.visible = false

func _setup_speech() -> void:
	speech_label = get_node_or_null("SpeechLabel") as Label
	if speech_label == null:
		speech_label = Label.new()
		speech_label.name = "SpeechLabel"
		speech_label.position = Vector2(-150.0, -230.0)
		speech_label.size = Vector2(300.0, 70.0)
		speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		speech_label.add_theme_font_size_override("font_size", 19)
		add_child(speech_label)
	speech_label.visible = false

func say(line: String, force: bool = false) -> void:
	if line.is_empty() or speech_label == null:
		return
	if not force and speech_cooldown_timer > 0.0:
		return
	speech_label.text = (personality_name + ": " if not personality_name.is_empty() else "") + line
	speech_label.visible = true
	speech_timer = speech_duration
	speech_cooldown_timer = speech_cooldown

func say_random(lines: PackedStringArray) -> void:
	if not lines.is_empty():
		say(lines[randi_range(0, lines.size() - 1)])
