extends Area2D
## Falling log: shakes, drops, lands, then ROLLS along the ground hurting CT until
## it hits a wall or runs out of time. (A log seen end-on, so it is round.)
##
## SCENE SETUP
##   Area2D                 <- attach this script, place the log where it should hang
##   |- CollisionShape2D    <- circle (best) / rect / capsule
##   |- Sprite2D            <- optional art (it is rotated while rolling);
##   |                         without art a placeholder is drawn
##   |- Trigger (Area2D)    <- OPTIONAL. In ZONE mode one is created below the log if missing.
##
## TRIGGER MODES
##   MANUAL  call trigger() or use a Tap/Trigger switch
##   ZONE    drops when CT enters the trigger area
##   TIMER   drops every `timer_interval` seconds (needs respawn_time > 0 to repeat)
##
## The log lands on / rolls over anything in `ground_mask` and stops at walls in
## `wall_mask` (default: layer 2 "Environment").
## CT API used: take_damage(int), apply_knockback(Vector2), is_hidden(),
##              can_take_damage, is_dead.

enum TriggerMode { MANUAL, ZONE, TIMER }
enum RollDirection { LEFT, RIGHT, TOWARD_PLAYER }
enum State { HANGING, WARNING, FALLING, ROLLING, BROKEN }

signal started_falling
signal landed
signal started_rolling
signal player_hit(player: Node)
signal respawned

@export_category("Trigger")
@export var trigger_mode: TriggerMode = TriggerMode.ZONE
@export var trigger_size: Vector2 = Vector2(300.0, 900.0)
@export var trigger_node_name: StringName = &"Trigger"
@export var timer_interval: float = 5.0
@export var start_delay: float = 0.0
@export var warning_time: float = 0.6
@export var shake_amount: float = 4.0

@export_category("Fall")
@export var fall_gravity: float = 2200.0
@export var max_fall_speed: float = 1800.0
@export var max_fall_distance: float = 4000.0
@export_flags_2d_physics var ground_mask: int = 2
@export_flags_2d_physics var wall_mask: int = 2

@export_category("Rolling")
@export var roll_after_landing: bool = true
@export var roll_direction: RollDirection = RollDirection.TOWARD_PLAYER
@export var roll_speed: float = 480.0
@export var roll_acceleration: float = 700.0
## Seconds it keeps rolling before it breaks apart.
@export var roll_duration: float = 5.0
@export var break_on_wall: bool = true

@export_category("Damage")
@export var fall_damage: int = 1
@export var roll_damage: int = 1
## Seconds between repeated hits while CT stays in contact.
@export var damage_interval: float = 0.7

@export_category("After Rolling")
@export var break_time: float = 0.4
## Seconds until the log re-appears at its start position. 0 = removed for good.
@export var respawn_time: float = 4.0
@export var impact_shake: float = 8.0
@export var dust_on_impact: bool = true

@export_category("Placeholder")
@export var placeholder_color: Color = Color(0.5, 0.33, 0.18)

var state: State = State.HANGING

var _start_pos: Vector2
var _start_scale: Vector2
var _rect: Rect2
var _art: Array[Node2D] = []
var _art_base: Array[Vector2] = []
var _has_art: bool = false
var _timer: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _fallen: float = 0.0
var _dir: float = 1.0
var _roll_left: float = 0.0
var _roll_angle: float = 0.0
var _hit_timer: float = 0.0
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
		circle.radius = 70.0
		cs.shape = circle
		add_child(cs)
	_rect = _rect_of(cs)

	_setup_trigger()
	_timer = start_delay + timer_interval


func _physics_process(delta: float) -> void:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
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
		State.FALLING, State.ROLLING:
			_move(delta)
			if state == State.FALLING or state == State.ROLLING:
				_hurt_overlapping()
		State.BROKEN:
			if respawn_time > 0.0:
				_timer -= delta
				if _timer <= 0.0:
					reset_log()


func _draw() -> void:
	if _has_art:
		return
	var c := _rect.get_center() + _shake_offset
	var r := minf(_rect.size.x, _rect.size.y) * 0.5
	draw_circle(c, r, placeholder_color)
	draw_arc(c, r, 0.0, TAU, 28, placeholder_color.darkened(0.45), 5.0)
	draw_arc(c, r * 0.55, 0.0, TAU, 20, placeholder_color.darkened(0.25), 3.0)
	for k in 3:
		var a := _roll_angle + float(k) * PI / 3.0
		draw_line(c - Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r * 0.5, placeholder_color.darkened(0.35), 3.0)


# ------------------------------------------------------------------ public API

func trigger() -> void:
	if state != State.HANGING:
		return
	state = State.WARNING
	_timer = warning_time
	if warning_time <= 0.0:
		_start_fall()


func activate() -> void:
	trigger()


## Puts the log back at its start position, ready to fall again.
func reset_log() -> void:
	state = State.HANGING
	global_position = _start_pos
	scale = _start_scale
	modulate.a = 1.0
	visible = true
	_vel = Vector2.ZERO
	_fallen = 0.0
	_roll_angle = 0.0
	_shake_offset = Vector2.ZERO
	_timer = timer_interval
	set_deferred("monitoring", true)
	_apply_visual()
	respawned.emit()


# ------------------------------------------------------------------- internals

func _start_fall() -> void:
	state = State.FALLING
	_vel = Vector2.ZERO
	_fallen = 0.0
	_shake_offset = Vector2.ZERO
	_apply_visual()
	started_falling.emit()


func _move(delta: float) -> void:
	_vel.y = minf(_vel.y + fall_gravity * delta, max_fall_speed)

	# Horizontal rolling.
	if state == State.ROLLING:
		_roll_left -= delta
		_vel.x = move_toward(_vel.x, _dir * roll_speed, roll_acceleration * delta)
		var step_x := _vel.x * delta
		if break_on_wall and _wall_ahead(absf(step_x)):
			_break()
			return
		global_position.x += step_x
		_roll_angle += step_x / maxf(_rect.size.x * 0.5, 1.0)
		if _roll_left <= 0.0:
			_break()
			return

	# Vertical: land / follow the ground / keep falling.
	var step_y := _vel.y * delta
	var gap := _ground_gap(maxf(step_y, 0.0) + 6.0)
	if gap <= maxf(step_y, 0.0) + 6.0:
		global_position.y += gap
		_vel.y = 0.0
		_fallen = 0.0
		if state == State.FALLING:
			_on_landed()
	else:
		global_position.y += step_y
		_fallen += maxf(step_y, 0.0)
		if _fallen >= max_fall_distance:
			_break(false)
			return
	_apply_visual()


func _on_landed() -> void:
	_hurt_overlapping()
	landed.emit()
	_impact_effects()
	if not roll_after_landing:
		_break(false)
		return
	_dir = _resolve_direction()
	_roll_left = roll_duration
	state = State.ROLLING
	started_rolling.emit()


func _resolve_direction() -> float:
	match roll_direction:
		RollDirection.LEFT:
			return -1.0
		RollDirection.RIGHT:
			return 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		return 1.0 if p.global_position.x >= global_position.x else -1.0
	return 1.0


func _break(with_effects: bool = true) -> void:
	if state == State.BROKEN:
		return
	state = State.BROKEN
	_timer = respawn_time
	set_deferred("monitoring", false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, maxf(break_time, 0.01))
	t.tween_property(self, "scale", _start_scale * 1.2, maxf(break_time, 0.01))
	t.chain().tween_callback(func() -> void:
		visible = false
		if respawn_time <= 0.0:
			queue_free())
	if with_effects:
		_impact_effects()


func _ground_gap(reach: float) -> float:
	var space := get_world_2d().direct_space_state
	var best := INF
	var inset := 3.0
	for f in [0.2, 0.5, 0.8]:
		var local_x: float = _rect.position.x + _rect.size.x * f
		var from := to_global(Vector2(local_x, _rect.end.y - inset))
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, reach + inset), ground_mask)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			best = minf(best, (hit.position.y - from.y) - inset)
	return best


func _wall_ahead(step: float) -> bool:
	var space := get_world_2d().direct_space_state
	var half_w := _rect.size.x * 0.5 * absf(global_scale.x)
	var from := to_global(_rect.get_center() + Vector2(0.0, -_rect.size.y * 0.15))
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(_dir * (half_w + step + 2.0), 0.0), wall_mask)
	return not space.intersect_ray(q).is_empty()


func _hurt_overlapping() -> void:
	if _hit_timer > 0.0:
		return
	var dmg := fall_damage if state == State.FALLING else roll_damage
	for body in get_overlapping_bodies():
		if _hurt(body, dmg):
			_hit_timer = damage_interval
			player_hit.emit(body)
			return


func _hurt(body: Node, amount: int) -> bool:
	if amount <= 0 or not is_instance_valid(body) or not body.is_in_group("player"):
		return false
	if "is_dead" in body and body.is_dead:
		return false
	if body.has_method("is_hidden") and body.is_hidden():
		return false
	if "can_take_damage" in body and not body.can_take_damage:
		return false
	if body.has_method("take_damage"):
		body.take_damage(amount)
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
		dust.color = Color(0.6, 0.5, 0.4, 0.8)
		get_parent().add_child(dust)
		dust.global_position = to_global(Vector2(_rect.get_center().x, _rect.end.y))
		dust.emitting = true
		get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


func _apply_visual() -> void:
	for i in _art.size():
		_art[i].position = _art_base[i] + _shake_offset
		_art[i].rotation = _roll_angle
	if not _has_art:
		queue_redraw()


func _rect_of(cs: CollisionShape2D) -> Rect2:
	var s: Shape2D = cs.shape
	var ext := Vector2(70.0, 70.0)
	if s is RectangleShape2D:
		ext = s.size * 0.5
	elif s is CircleShape2D:
		ext = Vector2(s.radius, s.radius)
	elif s is CapsuleShape2D:
		ext = Vector2(s.radius, s.height * 0.5)
	return Rect2(cs.position - ext, ext * 2.0)
