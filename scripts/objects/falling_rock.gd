extends Area2D
## Falling rock: hangs in place, shakes, drops, hurts CT if it lands on them, breaks.
##
## SCENE SETUP
##   Area2D                 <- attach this script, place the rock where it should hang
##   |- CollisionShape2D    <- the rock's hit shape (circle / rect / capsule)
##   |- Sprite2D            <- optional art; without art a placeholder is drawn
##   |- Trigger (Area2D)    <- OPTIONAL. If you don't add one and trigger_mode == ZONE,
##                             an invisible trigger below the rock is created for you.
##
## TRIGGER MODES
##   MANUAL  call trigger() yourself, or let a Tap/Trigger switch do it
##   ZONE    drops when CT enters the trigger area below the rock
##   TIMER   drops every `timer_interval` seconds (needs respawn_time > 0 to repeat)
##
## The rock lands on anything in `ground_mask` (default: layer 2 "Environment").
## CT API used: take_damage(int), apply_knockback(Vector2), is_hidden(),
##              can_take_damage, is_dead.

enum TriggerMode { MANUAL, ZONE, TIMER }
enum State { HANGING, WARNING, FALLING, BROKEN }

signal started_falling
signal landed
signal player_hit(player: Node)
signal respawned

@export_category("Trigger")
@export var trigger_mode: TriggerMode = TriggerMode.ZONE
## ZONE mode: size of the auto-created trigger, placed directly below the rock.
@export var trigger_size: Vector2 = Vector2(260.0, 900.0)
@export var trigger_node_name: StringName = &"Trigger"
## TIMER mode: seconds between drops.
@export var timer_interval: float = 4.0
@export var start_delay: float = 0.0
## Shake time before it drops.
@export var warning_time: float = 0.5
@export var shake_amount: float = 5.0

@export_category("Fall")
@export var fall_gravity: float = 2400.0
@export var max_fall_speed: float = 1800.0
## Safety net: the rock breaks if it falls this far without hitting anything.
@export var max_fall_distance: float = 4000.0
@export_flags_2d_physics var ground_mask: int = 2

@export_category("Damage")
@export var damage: int = 1

@export_category("After Landing")
@export var break_time: float = 0.35
## Seconds until the rock re-appears at its start position. 0 = removed for good.
@export var respawn_time: float = 3.0
@export var impact_shake: float = 10.0
@export var dust_on_impact: bool = true

@export_category("Placeholder")
@export var placeholder_color: Color = Color(0.45, 0.43, 0.42)

var state: State = State.HANGING

var _start_pos: Vector2
var _start_scale: Vector2
var _rect: Rect2
var _art: Array[Node2D] = []
var _art_base: Array[Vector2] = []
var _has_art: bool = false
var _timer: float = 0.0
var _vel: float = 0.0
var _fallen: float = 0.0
var _hit_ids: Array[int] = []
var _shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_mask |= 1
	monitoring = true
	_start_pos = global_position
	_start_scale = scale

	var cs: CollisionShape2D = null
	for c in get_children():
		if c is CollisionShape2D and cs == null:
			cs = c
		elif c is Sprite2D or c is AnimatedSprite2D:
			var n := c as Node2D
			_art.append(n)
			_art_base.append(n.position)
	_has_art = not _art.is_empty()
	if cs == null:
		cs = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 60.0
		cs.shape = circle
		add_child(cs)
	_rect = _rect_of(cs)

	_setup_trigger()
	_timer = start_delay + timer_interval


func _physics_process(delta: float) -> void:
	match state:
		State.HANGING:
			if trigger_mode == TriggerMode.TIMER:
				_timer -= delta
				if _timer <= 0.0:
					trigger()
		State.WARNING:
			_timer -= delta
			_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
			_apply_visual()
			if _timer <= 0.0:
				_start_fall()
		State.FALLING:
			_fall(delta)
			_hurt_overlapping()
		State.BROKEN:
			if respawn_time > 0.0:
				_timer -= delta
				if _timer <= 0.0:
					reset_rock()


func _draw() -> void:
	if _has_art:
		return
	var c := _rect.get_center() + _shake_offset
	var r := minf(_rect.size.x, _rect.size.y) * 0.5
	draw_circle(c, r, placeholder_color)
	draw_arc(c, r, 0.0, TAU, 24, placeholder_color.darkened(0.4), 4.0)
	draw_line(c + Vector2(-r * 0.4, -r * 0.2), c + Vector2(r * 0.1, r * 0.3), placeholder_color.darkened(0.5), 3.0)
	draw_line(c + Vector2(r * 0.1, r * 0.3), c + Vector2(r * 0.4, r * 0.05), placeholder_color.darkened(0.5), 3.0)


# ------------------------------------------------------------------ public API

## Starts the warning shake, then the drop.
func trigger() -> void:
	if state != State.HANGING:
		return
	state = State.WARNING
	_timer = warning_time
	if warning_time <= 0.0:
		_start_fall()


func activate() -> void:
	trigger()


## Puts the rock back at its start position, ready to fall again.
func reset_rock() -> void:
	state = State.HANGING
	global_position = _start_pos
	scale = _start_scale
	modulate.a = 1.0
	visible = true
	_vel = 0.0
	_fallen = 0.0
	_shake_offset = Vector2.ZERO
	_hit_ids.clear()
	_timer = timer_interval
	set_deferred("monitoring", true)
	_apply_visual()
	respawned.emit()


# ------------------------------------------------------------------- internals

func _start_fall() -> void:
	state = State.FALLING
	_vel = 0.0
	_fallen = 0.0
	_shake_offset = Vector2.ZERO
	_hit_ids.clear()
	_apply_visual()
	started_falling.emit()


func _fall(delta: float) -> void:
	_vel = minf(_vel + fall_gravity * delta, max_fall_speed)
	var step := _vel * delta
	var gap := _ground_gap(step)
	if gap <= step:
		global_position.y += gap
		_land()
		return
	global_position.y += step
	_fallen += step
	if _fallen >= max_fall_distance:
		_break(false)


func _land() -> void:
	_hurt_overlapping()
	landed.emit()
	_impact_effects()
	_break(true)


func _break(_after_impact: bool) -> void:
	state = State.BROKEN
	_timer = respawn_time
	set_deferred("monitoring", false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, maxf(break_time, 0.01))
	t.tween_property(self, "scale", _start_scale * 1.25, maxf(break_time, 0.01))
	t.chain().tween_callback(func() -> void:
		visible = false
		if respawn_time <= 0.0:
			queue_free())


## Distance from the rock's bottom edge down to the ground (INF if none within `reach`).
func _ground_gap(reach: float) -> float:
	var space := get_world_2d().direct_space_state
	var best := INF
	var inset := 3.0
	for f in [0.15, 0.5, 0.85]:
		var local_x: float = _rect.position.x + _rect.size.x * f
		var from := to_global(Vector2(local_x, _rect.end.y - inset))
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, reach + inset), ground_mask)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			best = minf(best, (hit.position.y - from.y) - inset)
	return best


func _hurt_overlapping() -> void:
	for body in get_overlapping_bodies():
		var id := body.get_instance_id()
		if _hit_ids.has(id):
			continue
		if _hurt(body):
			_hit_ids.append(id)
			player_hit.emit(body)


func _hurt(body: Node) -> bool:
	if not is_instance_valid(body) or not body.is_in_group("player"):
		return false
	if "is_dead" in body and body.is_dead:
		return false
	if body.has_method("is_hidden") and body.is_hidden():
		return false
	if "can_take_damage" in body and not body.can_take_damage:
		return false
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_knockback"):
		body.apply_knockback(global_position)
	return true


func _setup_trigger() -> void:
	var trig := get_node_or_null(NodePath(trigger_node_name)) as Area2D
	if trig == null and trigger_mode == TriggerMode.ZONE:
		trig = Area2D.new()
		trig.name = String(trigger_node_name)
		trig.collision_layer = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = trigger_size
		cs.shape = rs
		cs.position = Vector2(_rect.get_center().x, _rect.end.y + trigger_size.y * 0.5)
		trig.add_child(cs)
		add_child(trig)
	if trig != null and trigger_mode == TriggerMode.ZONE:
		trig.collision_mask |= 1
		trig.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		trigger()


func _impact_effects() -> void:
	if impact_shake > 0.0:
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			if not cam.has_meta(&"ct_shake_base"):
				cam.set_meta(&"ct_shake_base", cam.offset)
			var base: Vector2 = cam.get_meta(&"ct_shake_base")
			var t := cam.create_tween()
			for i in 5:
				t.tween_property(cam, "offset", base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * impact_shake, 0.04)
			t.tween_property(cam, "offset", base, 0.05)
			t.tween_callback(func() -> void:
				if is_instance_valid(cam) and cam.has_meta(&"ct_shake_base"):
					cam.remove_meta(&"ct_shake_base"))
	if dust_on_impact and get_parent() != null:
		var dust := CPUParticles2D.new()
		dust.one_shot = true
		dust.amount = 14
		dust.lifetime = 0.6
		dust.explosiveness = 1.0
		dust.direction = Vector2.UP
		dust.spread = 80.0
		dust.initial_velocity_min = 120.0
		dust.initial_velocity_max = 280.0
		dust.gravity = Vector2(0.0, 600.0)
		dust.scale_amount_min = 4.0
		dust.scale_amount_max = 9.0
		dust.color = Color(0.6, 0.55, 0.5, 0.8)
		get_parent().add_child(dust)
		dust.global_position = to_global(Vector2(_rect.get_center().x, _rect.end.y))
		dust.emitting = true
		get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


func _apply_visual() -> void:
	for i in _art.size():
		_art[i].position = _art_base[i] + _shake_offset
	if not _has_art:
		queue_redraw()


func _rect_of(cs: CollisionShape2D) -> Rect2:
	var s: Shape2D = cs.shape
	var ext := Vector2(60.0, 60.0)
	if s is RectangleShape2D:
		ext = s.size * 0.5
	elif s is CircleShape2D:
		ext = Vector2(s.radius, s.radius)
	elif s is CapsuleShape2D:
		ext = Vector2(s.radius, s.height * 0.5)
	return Rect2(cs.position - ext, ext * 2.0)
