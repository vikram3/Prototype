extends Node2D
## Shockwave hazard. Two flavours:
##
##   GROUND_WAVE    a low wave races along the floor from this node's position.
##                  CT dodges it by JUMPING over it (it only reaches `wave_height`
##                  above the origin).
##   RADIAL_BLAST   an expanding ring (boss shout / ground-pound burst). It cannot be
##                  jumped; stay outside the ring or hide / use a shield.
##
## SCENE SETUP
##   Node2D                 <- attach this script; the origin should sit on the floor
##                             (GROUND_WAVE) or at the blast centre (RADIAL_BLAST).
##   No children are needed. The wave draws itself; set draw_visual = false and
##   listen to the signals if you want your own effect.
##
## USE IT
##   * auto_start + repeat_interval: a pulsing hazard (e.g. a boss arena)
##   * trigger(): fire once from code, an animation call, or a Tap/Trigger switch
##   * set global_position first, then trigger(), to launch it from a moving enemy
##
## No physics layers are involved: the script tests CT's position directly, so it
## works regardless of collision setup. CT API used: take_damage(int),
## apply_knockback(Vector2), is_hidden(), can_take_damage, is_dead.

signal started
signal finished
signal player_hit(player: Node)

enum Mode { GROUND_WAVE, RADIAL_BLAST }
enum Direction { BOTH, LEFT, RIGHT }

@export_category("Shockwave")
@export var mode: Mode = Mode.GROUND_WAVE
@export var direction: Direction = Direction.BOTH
@export var speed: float = 650.0
@export var max_distance: float = 900.0
@export var damage: int = 1
## Knockback is pushed away from (global_position + this).
@export var knockback_origin_offset: Vector2 = Vector2(0.0, 40.0)

@export_category("Timing")
@export var auto_start: bool = false
@export var start_delay: float = 0.5
## > 0 repeats the wave this many seconds after the last one finished.
@export var repeat_interval: float = 0.0
@export var free_when_done: bool = false

@export_category("Ground Wave")
@export var wave_width: float = 90.0
## How high above the origin the wave reaches. CT's feet above this = safe.
@export var wave_height: float = 70.0
## CT's feet more than this far BELOW the origin are not hit (different floor).
@export var depth_tolerance: float = 80.0

@export_category("Radial Blast")
@export var ring_thickness: float = 70.0
## Centre of CT's body relative to its origin (feet), used for the distance test.
@export var target_center_offset: Vector2 = Vector2(0.0, -100.0)

@export_category("CT Size")
## Half of CT's collision width, so grazing the wave counts.
@export var player_half_width: float = 50.0

@export_category("Visual")
@export var draw_visual: bool = true
@export var wave_color: Color = Color(1.0, 0.75, 0.3, 0.85)

var _active: bool = false
var _dist: float = 0.0
var _wait: float = 0.0
var _repeating: bool = false
var _hit_ids: Array[int] = []


func _ready() -> void:
	_repeating = auto_start
	if auto_start:
		_wait = start_delay


func _physics_process(delta: float) -> void:
	if not _active:
		if _repeating:
			_wait -= delta
			if _wait <= 0.0:
				trigger()
		return

	_dist += speed * delta
	_test_players()
	queue_redraw()

	var tail := wave_width if mode == Mode.GROUND_WAVE else ring_thickness
	if _dist - tail > max_distance:
		_finish()


func _draw() -> void:
	if not _active or not draw_visual:
		return
	var fade := clampf(1.0 - _dist / maxf(max_distance, 1.0), 0.15, 1.0)
	var col := wave_color
	col.a *= fade
	if mode == Mode.RADIAL_BLAST:
		var r := maxf(_dist - ring_thickness * 0.5, 1.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, col, ring_thickness)
		return
	for dir in _directions():
		var back := dir * (_dist - wave_width)
		var front := dir * _dist
		var pts := PackedVector2Array([
			Vector2(back, 0.0),
			Vector2(front, 0.0),
			Vector2(front - dir * wave_width * 0.15, -wave_height * 0.65),
			Vector2(front - dir * wave_width * 0.45, -wave_height),
		])
		draw_colored_polygon(pts, col)


# ------------------------------------------------------------------ public API

## Launches the wave from the current position.
func trigger() -> void:
	if _active:
		return
	_active = true
	_dist = 0.0
	_hit_ids.clear()
	started.emit()


func activate() -> void:
	_repeating = repeat_interval > 0.0
	_wait = 0.0
	trigger()


func deactivate() -> void:
	_repeating = false
	if _active:
		_finish()


# ------------------------------------------------------------------- internals

func _finish() -> void:
	_active = false
	queue_redraw()
	finished.emit()
	if free_when_done:
		queue_free()
		return
	if repeat_interval > 0.0 and _repeating:
		_wait = repeat_interval


func _directions() -> Array[float]:
	match direction:
		Direction.LEFT:
			return [-1.0]
		Direction.RIGHT:
			return [1.0]
	return [-1.0, 1.0]


func _test_players() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var id := p.get_instance_id()
		if _hit_ids.has(id):
			continue
		var feet: Vector2 = (p as Node2D).global_position
		var touched := false

		if mode == Mode.GROUND_WAVE:
			var rise := global_position.y - feet.y  # > 0 means CT is above the origin
			if rise > wave_height or rise < -depth_tolerance:
				continue
			var dx := feet.x - global_position.x
			for dir in _directions():
				var along := dx * dir
				if along + player_half_width >= _dist - wave_width and along - player_half_width <= _dist:
					touched = true
		else:
			var d := (feet + target_center_offset).distance_to(global_position)
			touched = d >= _dist - ring_thickness - player_half_width and d <= _dist + player_half_width

		if touched and _hurt(p):
			_hit_ids.append(id)
			player_hit.emit(p)


func _hurt(body: Node) -> bool:
	if damage <= 0 or not is_instance_valid(body):
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
		body.apply_knockback(global_position + knockback_origin_offset)
	return true
