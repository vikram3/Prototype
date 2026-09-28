class_name ReturningBoomerang
extends Area2D

@export var speed: float = 600.0
@export var outbound_duration: float = 0.75
@export var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var owner_actor: Node2D
var timer: float = 0.0
var returning: bool = false

func _ready() -> void:
	add_to_group("character_lab_transient")
	timer = outbound_duration
	monitoring = true
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	timer -= delta
	if not returning and timer <= 0.0:
		returning = true
	if returning:
		if owner_actor == null or not is_instance_valid(owner_actor):
			queue_free()
			return
		direction = (owner_actor.global_position - global_position).normalized()
		if global_position.distance_to(owner_actor.global_position) < 32.0:
			queue_free()
			return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body == owner_actor: return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"): body.apply_knockback(global_position)
