extends Area2D
## Power-up pickup: temporary SPEED / JUMP / DAMAGE / SUPER boost for CT.
##
## SCENE SETUP (same layout as Coin.tscn)
##   Area2D                 <- attach this script
##   |- CollisionShape2D    <- optional (a circle is created if missing)
##   |- Sprite2D            <- optional art; without art a placeholder is drawn
##
## HOW IT WORKS WITH CT (ct.gd is NOT modified)
##   CT's tuning values are plain variables, so the power-up scales them and puts
##   the originals back when it expires:
##     SPEED   CT.move_speed            (and PlatformerOverride.run_speed)
##     JUMP    CT.jump_velocity         (and PlatformerOverride.jump_velocity)
##     DAMAGE  CombatController.ground_damage / air_damage / dash_damage
##   Several modifiers (power-ups, quicksand, sand trap) stack by multiplying; the
##   original values are restored when the LAST one ends.
##   While active, the collected pickup stays in the scene (invisible) as controller.
##
## The "SHARED MODIFIER BLOCK" at the bottom is identical in power_up.gd,
## quicksand.gd and sand_trap.gd so the three cooperate without a shared base class.

signal collected
signal power_started(player: Node)
signal power_ended(player: Node)

enum PowerType { SPEED, JUMP, DAMAGE, SUPER }

@export_category("Power")
@export var power_type: PowerType = PowerType.SPEED
@export var duration: float = 8.0
@export var speed_multiplier: float = 1.5
@export var jump_multiplier: float = 1.2
@export var damage_multiplier: float = 2.0
## Tints CT's sprite while active (alpha 0 disables the tint).
@export var player_tint: Color = Color(1.0, 0.85, 0.3, 1.0)

@export_category("Respawn")
## Seconds until the pickup comes back. 0 = one use.
@export var respawn_time: float = 0.0

@export_category("Look")
@export var bob_height: float = 8.0
@export var bob_speed: float = 3.0
@export var pickup_radius: float = 60.0

@export_category("CT Reaction")
@export var reaction_lines: Array[String] = [
	"I feel... extremely capable. That's new.",
	"Power acquired. Responsibility not included.",
	"Okay, THIS is the good stuff.",
]
@export var expire_lines: Array[String] = [
	"And I'm back to being average.",
	"Power's gone. Dignity optional.",
]

var is_collected: bool = false

var _time: float = 0.0
var _art: Array[Node2D] = []
var _art_base: Array[Vector2] = []
var _has_art: bool = false
var _player: Node = null
var _remaining: float = 0.0
var _respawn_left: float = 0.0


func _ready() -> void:
	collision_mask |= 1
	monitoring = true
	var has_shape := false
	for c in get_children():
		if c is CollisionShape2D:
			has_shape = true
		elif c is Sprite2D or c is AnimatedSprite2D:
			var n := c as Node2D
			_art.append(n)
			_art_base.append(n.position)
	_has_art = not _art.is_empty()
	if not has_shape:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = pickup_radius
		cs.shape = circle
		add_child(cs)
	_time = randf() * TAU


func _physics_process(delta: float) -> void:
	if _player != null:
		_remaining -= delta
		if _remaining <= 0.0 or not is_instance_valid(_player) or ("is_dead" in _player and _player.is_dead):
			_end_power(true)
		return

	if is_collected:
		if respawn_time > 0.0:
			_respawn_left -= delta
			if _respawn_left <= 0.0:
				_respawn()
		return

	_time += delta * bob_speed
	var bob := Vector2(0.0, sin(_time) * bob_height)
	for i in _art.size():
		_art[i].position = _art_base[i] + bob
	if not _has_art:
		queue_redraw()

	for body in get_overlapping_bodies():
		if body.is_in_group("player") and _collect(body):
			break


func _draw() -> void:
	if _has_art or is_collected:
		return
	var c := Vector2(0.0, sin(_time) * bob_height)
	var col := Color(1.0, 0.8, 0.2)
	match power_type:
		PowerType.SPEED:
			col = Color(0.3, 0.8, 1.0)
		PowerType.JUMP:
			col = Color(0.5, 1.0, 0.4)
		PowerType.DAMAGE:
			col = Color(1.0, 0.35, 0.3)
	draw_circle(c, pickup_radius * 0.7, col.darkened(0.35))
	draw_arc(c, pickup_radius * 0.7, 0.0, TAU, 32, col, 4.0)
	# Lightning bolt glyph.
	var s := pickup_radius * 0.5
	var bolt := PackedVector2Array([
		c + Vector2(0.15, -1.0) * s, c + Vector2(-0.55, 0.1) * s, c + Vector2(-0.05, 0.1) * s,
		c + Vector2(-0.2, 1.0) * s, c + Vector2(0.6, -0.2) * s, c + Vector2(0.05, -0.2) * s,
	])
	draw_colored_polygon(bolt, Color(1, 1, 1))


# ------------------------------------------------------------------ public API

func collect(player: Node) -> void:
	_collect(player)


# ------------------------------------------------------------------- internals

func _collect(player: Node) -> bool:
	if is_collected or not is_instance_valid(player):
		return false
	if "is_dead" in player and player.is_dead:
		return false

	_player = player
	_remaining = duration
	is_collected = true
	_respawn_left = respawn_time
	visible = false
	set_deferred("monitoring", false)

	var mult := {}
	match power_type:
		PowerType.SPEED:
			mult = {"speed": speed_multiplier}
		PowerType.JUMP:
			mult = {"jump": jump_multiplier}
		PowerType.DAMAGE:
			mult = {"damage": damage_multiplier}
		PowerType.SUPER:
			mult = {"speed": speed_multiplier, "jump": jump_multiplier, "damage": damage_multiplier}
	_mod_set(player, get_instance_id(), mult)
	_apply_tint(player)

	collected.emit()
	power_started.emit(player)
	if not reaction_lines.is_empty() and player.has_method("show_reaction"):
		player.show_reaction(reaction_lines[randi() % reaction_lines.size()])
	return true


func _end_power(say_line: bool) -> void:
	var p := _player
	_player = null
	if is_instance_valid(p):
		_mod_clear(p, get_instance_id())
		_restore_tint(p)
		power_ended.emit(p)
		if say_line and not expire_lines.is_empty() and p.has_method("show_reaction"):
			p.show_reaction(expire_lines[randi() % expire_lines.size()])
	if respawn_time <= 0.0:
		queue_free()


func _exit_tree() -> void:
	# Never leave CT boosted/slowed if this node disappears (scene change etc.).
	if _player != null and is_instance_valid(_player):
		_mod_clear(_player, get_instance_id())
		_restore_tint(_player)
		_player = null


func _respawn() -> void:
	is_collected = false
	visible = true
	set_deferred("monitoring", true)


func _apply_tint(player: Node) -> void:
	if player_tint.a <= 0.0:
		return
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	if not player.has_meta(&"ct_tint_base"):
		player.set_meta(&"ct_tint_base", sprite.self_modulate)
	sprite.self_modulate = player_tint


func _restore_tint(player: Node) -> void:
	if _mod_any_left(player):
		return
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and player.has_meta(&"ct_tint_base"):
		sprite.self_modulate = player.get_meta(&"ct_tint_base")
	if player.has_meta(&"ct_tint_base"):
		player.remove_meta(&"ct_tint_base")


# =====================================================================
# SHARED MODIFIER BLOCK  (identical in power_up / quicksand / sand_trap)
#
# Each source registers multipliers per channel ("speed", "jump", "gravity",
# "damage"). Values on CT are always recomputed as  original * product(all sources)
# and the originals are restored once no source is left.
# =====================================================================

const _MOD_KEY := &"ct_mod_sources"
const _BASE_KEY := &"ct_mod_base"


func _mod_targets(player: Node) -> Array:
	var out: Array = []
	for pair in [["move_speed", "speed"], ["jump_velocity", "jump"], ["gravity_scale", "gravity"]]:
		if pair[0] in player:
			out.append([player, pair[0], pair[1]])
	var override := player.get_node_or_null("PlatformerOverride")
	if override != null:
		for pair in [["run_speed", "speed"], ["jump_velocity", "jump"], ["gravity_scale", "gravity"]]:
			if pair[0] in override:
				out.append([override, pair[0], pair[1]])
	var combat := player.get_node_or_null("CombatController")
	if combat != null:
		for prop in ["ground_damage", "air_damage", "dash_damage"]:
			if prop in combat:
				out.append([combat, prop, "damage"])
	return out


func _mod_set(player: Node, source_id: int, multipliers: Dictionary) -> void:
	var sources: Dictionary = player.get_meta(_MOD_KEY, {})
	sources[source_id] = multipliers
	player.set_meta(_MOD_KEY, sources)
	_mod_refresh(player)


func _mod_clear(player: Node, source_id: int) -> void:
	var sources: Dictionary = player.get_meta(_MOD_KEY, {})
	sources.erase(source_id)
	player.set_meta(_MOD_KEY, sources)
	_mod_refresh(player)


func _mod_any_left(player: Node) -> bool:
	var sources: Dictionary = player.get_meta(_MOD_KEY, {})
	return not sources.is_empty()


func _mod_refresh(player: Node) -> void:
	var sources: Dictionary = player.get_meta(_MOD_KEY, {})
	var base: Dictionary = player.get_meta(_BASE_KEY, {})
	for t in _mod_targets(player):
		var node: Node = t[0]
		var prop: String = t[1]
		var key := "%s.%s" % [node.name, prop]
		if sources.is_empty():
			if base.has(key):
				node.set(prop, base[key])
			continue
		if not base.has(key):
			base[key] = node.get(prop)
		var factor := 1.0
		for id in sources:
			factor *= float(sources[id].get(t[2], 1.0))
		var original = base[key]
		if typeof(original) == TYPE_INT:
			node.set(prop, maxi(1, roundi(float(original) * factor)) if factor > 0.0 else 0)
		else:
			node.set(prop, float(original) * factor)
	if sources.is_empty():
		if player.has_meta(_BASE_KEY):
			player.remove_meta(_BASE_KEY)
		if player.has_meta(_MOD_KEY):
			player.remove_meta(_MOD_KEY)
	else:
		player.set_meta(_BASE_KEY, base)
