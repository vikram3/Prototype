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
	"Horn": "States: patrol -> detect -> charge prep -> locked charge -> collision -> turn -> recover. Invulnerable; 1 damage plus cliff-danger knockback.",
	"Barreldugo": "States: patrol -> detect -> fire -> retreat -> recover -> defeated/tamed. 1-damage projectile every 1.3s; defeat then Felix can tame.",
	"Bulls": "States: patrol -> detect -> charge prep -> straight charge -> collision -> turn -> recover. 1 damage plus knockback; no homing mid-charge.",
	"BigBoss": "States: approach -> 0.8s telegraph -> sword slash/ground slam -> recover. Invulnerable survival boss; slash 2 damage, shockwave 1.",
	"PinkGirl": "States: approach -> defend/block -> attack -> recover -> hit/KO. Background story fight; protects CT, does not target CT.",
	"Felix": "States: follow/catch-up/idle/story. Non-combat, does not push CT, gives coin-path and projectile-weakness advice.",
	"Sword": "States: idle/walk/story. No combat in the source; Horn warning and forest-follow dialogue hooks.",
	"Layla": "States: idle/observe/story. No combat in the source; analyzes CT, Queen, and Sacavuelo close-range weakness.",
	"WindQueen": "States: ground/levitate/fly/power-up/intercept/rescue/story. Invulnerable aerial story role; callable action states.",
	"SandMayor": "States: idle/walk/story/contract. No combat in the source; coin bag, binding contract, and Lala-mud dialogue hooks.",
	"Fairy": "States: idle/levitate/fly/story. No combat defined by the PDF; retained as a lightweight aerial story character.",
	"Alex": "States: run/jump/shield/bow/thunder/baton combo/finisher/shield broken. F2 control. Baton 1/1/2, bow 1, thunder 1, shield 3 hits.",
	"Sacavuelo": "States: position -> boomerang -> pressure -> vulnerable -> hit -> defeat. 5 HP; 1-damage boomerang returns; only close attacks hurt it."
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
	# F1/F2 are always usable: a player prototype must not remain disabled merely
	# because its staged showcase has not been reached yet.
	if character == alex:
		alex.visible = true
		alex.process_mode = Node.PROCESS_MODE_INHERIT
		alex.collision_layer = int(original_layers.get(alex, 1))
		alex.collision_mask = int(original_masks.get(alex, 74))
	ct_override.set_physics_process(ct_active)
	alex.set_physics_process(not ct_active)
	ct_camera.enabled = ct_active
	alex_camera.enabled = not ct_active
	ct.remove_from_group("player")
	alex.remove_from_group("player")
	character.add_to_group("player")
	character.velocity = Vector2.ZERO
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
	prototype.global_position = controller.global_position + Vector2(430.0, 0.0)
	if prototype.has_method("perform_showcase"):
		prototype.call("perform_showcase", controller)
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
