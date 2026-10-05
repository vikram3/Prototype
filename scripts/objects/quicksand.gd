extends Area2D
## Quicksand: slows CT, makes them slowly SINK, and spits them out (with damage)
## if they sink all the way. Mashing jump struggles free and slows the sinking.
##
## SCENE SETUP
##   Area2D                 <- attach this script
##   |- CollisionShape2D    <- RectangleShape2D: its TOP edge is the sand surface
##   |- Sprite2D            <- optional art; without art a placeholder is drawn
##
## IMPORTANT: this is a zone, not a hole. CT keeps standing on your normal floor
## collision; the sinking is shown by lowering CT's sprite (the sand is drawn over
## CT when draw_over_player is on) and by the movement penalties below. Put your
## solid floor under the sand.
##
## HOW IT WORKS WITH CT (ct.gd is NOT modified)
##   Slowdown uses CT's tuning vars (move_speed / jump_velocity / gravity_scale, and
##   PlatformerOverride.run_speed) through the shared modifier block, so it stacks
##   with power-ups and the sand trap and always restores the original values.
##   CT API used: take_damage(int), die(), velocity, is_on_floor(), is_hidden(),
##   show_reaction(text), Sprite2D child, is_dead.

signal player_entered(player: Node)
signal player_exited(player: Node)
signal drowned(player: Node)

@export_category("Movement Penalty")
@export var speed_multiplier: float = 0.35
@export var jump_multiplier: float = 0.55
@export var gravity_multiplier: float = 1.0

@export_category("Sinking")
@export var active: bool = true
## Sinking progress per second (0.28 = about 3.5 s from surface to bottom).
@export var sink_speed: float = 0.28
## Only sink while standing on the ground (not while jumping out).
@export var only_sink_on_floor: bool = true
## Progress recovered per second while not sinking.
@export var recover_rate: float = 0.5
@export var struggle_action: StringName = &"jump"
## Progress removed per struggle press.
@export var struggle_amount: float = 0.14
## How far CT's sprite sinks at full progress (pixels).
@export var sink_visual_depth: float = 90.0
@export var draw_over_player: bool = true

@export_category("Drowning")
@export var drown_damage: int = 1
@export var instant_kill: bool = false
## Upward launch when CT is spat out.
@export var spit_velocity: float = 950.0
## Seconds after being spat out during which CT can't sink again.
@export var grace_time: float = 1.2

@export_category("Placeholder")
@export var default_size: Vector2 = Vector2(400.0, 120.0)
@export var sand_color: Color = Color(0.82, 0.68, 0.38, 0.88)

@export_category("CT Reaction")
@export var enter_lines: Array[String] = [
	"Why is the floor negotiating with me?",
	"This is not solid. This is a lie.",
	"I'm being slowly consumed by sand. Normal Tuesday.",
]
@export var struggle_line: String = "Nope nope nope, WIGGLE!"
@export var drown_lines: Array[String] = [
	"PTOO! Sand in places sand should never be!",
	"The desert spat me out. Rude.",
]

var _inside: Dictionary = {}
var _rect: Rect2
var _has_art: bool = false


func _ready() -> void:
	collision_mask |= 1
	monitoring = true
	var cs: CollisionShape2D = null
	for c in get_children():
		if c is CollisionShape2D and cs == null:
			cs = c
		elif c is Sprite2D or c is AnimatedSprite2D:
			_has_art = true
	if cs == null:
		cs = CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = default_size
		cs.shape = rs
		cs.position = Vector2(0.0, default_size.y * 0.5)
		add_child(cs)
	_rect = _rect_of(cs)
	if draw_over_player:
		z_index = 5
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# CT may already be inside when the scene starts.
	for b in get_overlapping_bodies():
		_on_body_entered(b)


func _physics_process(delta: float) -> void:
	for id in _inside.keys():
		var e: Dictionary = _inside[id]
		var p: Node = e["player"]
		if not is_instance_valid(p) or ("is_dead" in p and p.is_dead):
			_inside.erase(id)
			continue
		if not active:
			e["sink"] = maxf(float(e["sink"]) - recover_rate * delta, 0.0)
			_set_sink_visual(p, float(e["sink"]))
			continue

		var sink: float = e["sink"]
		var grace: float = e["grace"]
		var on_floor: bool = (not p.has_method("is_on_floor")) or p.is_on_floor()

		if grace > 0.0:
			grace -= delta
			sink = maxf(sink - recover_rate * 2.0 * delta, 0.0)
		elif on_floor or not only_sink_on_floor:
			sink += sink_speed * delta
		else:
			sink = maxf(sink - recover_rate * delta, 0.0)

		if Input.is_action_just_pressed(struggle_action) and sink > 0.05:
			sink -= struggle_amount
			if struggle_line != "" and p.has_method("show_reaction"):
				p.show_reaction(struggle_line)

		sink = clampf(sink, 0.0, 1.0)
		e["sink"] = sink
		e["grace"] = grace
		_set_sink_visual(p, sink)

		if sink >= 1.0:
			_drown(p, e)


func _draw() -> void:
	if _has_art:
		return
	var r := _rect
	draw_rect(r, sand_color)
	# Wavy surface line.
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var x := r.position.x + r.size.x * float(i) / float(steps)
		pts.append(Vector2(x, r.position.y + sin(float(i) * 1.3) * 5.0))
	draw_polyline(pts, sand_color.darkened(0.3), 4.0)


# ------------------------------------------------------------------- internals

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var id := body.get_instance_id()
	if _inside.has(id):
		return
	_inside[id] = {"player": body, "sink": 0.0, "grace": 0.0}
	_mod_set(body, get_instance_id(), {
		"speed": speed_multiplier,
		"jump": jump_multiplier,
		"gravity": gravity_multiplier,
	})
	player_entered.emit(body)
	if not enter_lines.is_empty() and body.has_method("show_reaction"):
		body.show_reaction(enter_lines[randi() % enter_lines.size()])


func _on_body_exited(body: Node2D) -> void:
	var id := body.get_instance_id()
	if not _inside.has(id):
		return
	_inside.erase(id)
	_release(body)
	player_exited.emit(body)


func _release(player: Node) -> void:
	if not is_instance_valid(player):
		return
	_mod_clear(player, get_instance_id())
	_clear_sink_visual(player)


func _drown(p: Node, e: Dictionary) -> void:
	e["sink"] = 0.0
	e["grace"] = grace_time
	_set_sink_visual(p, 0.0)
	drowned.emit(p)
	if instant_kill and p.has_method("die"):
		p.die()
		return
	if p.has_method("take_damage") and not ("can_take_damage" in p and not p.can_take_damage):
		p.take_damage(drown_damage)
	if "velocity" in p:
		p.velocity.y = -spit_velocity
	if not drown_lines.is_empty() and p.has_method("show_reaction"):
		p.show_reaction(drown_lines[randi() % drown_lines.size()], true)


func _exit_tree() -> void:
	for id in _inside.keys():
		var p: Node = _inside[id]["player"]
		_release(p)
	_inside.clear()


func _set_sink_visual(player: Node, amount: float) -> void:
	var sprite := player.get_node_or_null("Sprite2D") as Node2D
	if sprite == null:
		return
	if not player.has_meta(&"ct_sprite_base_y"):
		player.set_meta(&"ct_sprite_base_y", sprite.position.y)
	sprite.position.y = float(player.get_meta(&"ct_sprite_base_y")) + amount * sink_visual_depth


func _clear_sink_visual(player: Node) -> void:
	var sprite := player.get_node_or_null("Sprite2D") as Node2D
	if sprite != null and player.has_meta(&"ct_sprite_base_y"):
		sprite.position.y = float(player.get_meta(&"ct_sprite_base_y"))
	if player.has_meta(&"ct_sprite_base_y"):
		player.remove_meta(&"ct_sprite_base_y")


func _rect_of(cs: CollisionShape2D) -> Rect2:
	var s: Shape2D = cs.shape
	var ext := Vector2(200.0, 60.0)
	if s is RectangleShape2D:
		ext = s.size * 0.5
	elif s is CircleShape2D:
		ext = Vector2(s.radius, s.radius)
	elif s is CapsuleShape2D:
		ext = Vector2(s.radius, s.height * 0.5)
	return Rect2(cs.position - ext, ext * 2.0)


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
