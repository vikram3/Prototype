extends Node2D

## Staged manual integration lab. Only one prototype is active at a time.
## F1 gives the existing platformer CT control; F2 gives Alex control for the
## Sacavuelo duel. N introduces the next prototype and R resets the lab.
@onready var ct: CharacterBody2D = $CT
@onready var alex: CharacterBody2D = $Alex
@onready var ct_override: Node = $CT/PlatformerOverride
@onready var ct_camera: Camera2D = $CT/Camera2D
@onready var alex_camera: Camera2D = $Alex/Camera2D
@onready var mode_label: Label = $HUD/Mode
@onready var stage_label: Label = $HUD/Stage

var stages: Array[CharacterBody2D] = []
var original_layers: Dictionary = {}
var original_masks: Dictionary = {}
var stage_index: int = -1
var stage_notes: Dictionary = {
	"Horn": "Aggressive, invulnerable survivor enemy. 1 damage per locked straight charge; strong knockback and 0.6s warning.",
	"Barreldugo": "Projectile type. Fires 1-damage shots every 1.3s; can be defeated, then tamed by Felix.",
	"Bulls": "Charge enemy. 1 damage and knockback on a readable straight charge; recovers and turns after a collision.",
	"BigBoss": "Chapter 2 survival boss. Invulnerable. 0.8s telegraph, 2-damage sword slash, 1-damage travelling ground shockwave.",
	"PinkGirl": "Story fighter. Approaches Big Boss, alternates attack and shield block; no damage to CT.",
	"Felix": "Non-combat companion. Platform-aware follow, no pushing, exploration and combat-advice dialogue.",
	"Sword": "Story NPC. No combat. Warns CT of Horn and follows through the stairs.",
	"Layla": "Observer NPC. No combat. Explains CT's rare suit, the Queen, and Sacavuelo's close-range weakness.",
	"WindQueen": "Invulnerable aerial story character. Levitate, fly, power-up, intercept Bulls, and rescue the ship through script calls.",
	"SandMayor": "Story NPC. No combat. Contract and coin-bag dialogue hook for the Chapter 8 sequence.",
	"Fairy": "Lightweight aerial story NPC. No combat defined by the source material.",
	"Alex": "Playable: baton combo (1/1/2 damage), arced bow (1), shield blocks 3 hits, and thunder hook (1).",
	"Sacavuelo": "5 HP boss. 1-damage returning boomerang; becomes vulnerable only when Alex gets within close range."
}

func _ready() -> void:
	set_controlled_character(ct)
	stages = [$Horn, $Barreldugo, $Bulls, $BigBoss, $PinkGirl, $Felix, $Sword, $Layla, $WindQueen, $SandMayor, $Fairy, $Alex, $Sacavuelo]
	for prototype in stages:
		original_layers[prototype] = prototype.collision_layer
		original_masks[prototype] = prototype.collision_mask
		deactivate(prototype)
	introduce_next()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		set_controlled_character(ct)
	elif event.keycode == KEY_F2:
		set_controlled_character(alex)
	elif event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.keycode == KEY_N:
		introduce_next()

func set_controlled_character(character: CharacterBody2D) -> void:
	var ct_active := character == ct
	ct_override.set_physics_process(ct_active)
	alex.set_physics_process(not ct_active)
	ct_camera.enabled = ct_active
	alex_camera.enabled = not ct_active
	ct.remove_from_group("player")
	alex.remove_from_group("player")
	character.add_to_group("player")
	mode_label.text = "Controlling: " + character.name + "  |  F1 CT / F2 Alex / N Next / R Reset"

func deactivate(prototype: CharacterBody2D) -> void:
	prototype.visible = false
	prototype.process_mode = Node.PROCESS_MODE_DISABLED
	prototype.collision_layer = 0
	prototype.collision_mask = 0

func activate(prototype: CharacterBody2D) -> void:
	prototype.visible = true
	prototype.process_mode = Node.PROCESS_MODE_INHERIT
	prototype.collision_layer = int(original_layers[prototype])
	prototype.collision_mask = int(original_masks[prototype])
	var controller := alex if prototype == $Sacavuelo else ct
	set_controlled_character(controller)
	prototype.global_position = controller.global_position + Vector2(580.0, 0.0)
	if prototype.has_method("say_random"):
		prototype.call("say_random", prototype.get("idle_lines"))
	stage_label.text = "Stage " + str(stage_index + 1) + "/" + str(stages.size()) + ": " + prototype.name + " active\n" + str(stage_notes.get(prototype.name, "Story prototype active."))

func introduce_next() -> void:
	var keep_alex_for_duel := stage_index >= 0 and stage_index + 1 < stages.size() and stages[stage_index] == alex and stages[stage_index + 1] == $Sacavuelo
	if stage_index >= 0 and stage_index < stages.size() and not keep_alex_for_duel:
		deactivate(stages[stage_index])
	stage_index += 1
	if stage_index >= stages.size():
		stage_label.text = "All prototypes tested. Press R to restart the sequence."
		return
	activate(stages[stage_index])
