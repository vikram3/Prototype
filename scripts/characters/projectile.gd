class_name StoryProjectile
extends Area2D

@export var speed: float = 620.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var arc_gravity: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var owner_actor: Node2D

func _ready() -> void:
	add_to_group("character_lab_transient")
	monitoring = true
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	direction.y += arc_gravity * delta / maxf(speed, 1.0)
	global_position += direction.normalized() * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == owner_actor:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		queue_free()
	elif not body.is_in_group("enemy"):
		queue_free()
