extends Node2D

## Isolated manual test bed. It never edits the individual character scenes.
@onready var ct: CharacterBody2D = $CT
@onready var naked_ct: CharacterBody2D = $NakedCT
@onready var alex: CharacterBody2D = $Alex
@onready var ct_override: Node = $CT/PlatformerOverride
@onready var naked_override: Node = $NakedCT/PlatformerOverride
@onready var ct_camera: Camera2D = $CT/Camera2D
@onready var naked_camera: Camera2D = $NakedCT/Camera2D
@onready var alex_camera: Camera2D = $Alex/Camera2D
@onready var mode_label: Label = $HUD/Mode
@onready var stage_label: Label = $HUD/Stage
@onready var story_label: Label = $HUD/StoryPanel/Story

var stages: Array[CharacterBody2D] = []
var avatars: Array[CharacterBody2D] = []
var original_layers: Dictionary = {}
var original_masks: Dictionary = {}
var stage_index: int = -1

var stage_data: Dictionary = {
	"CT": ["Chapters 1-8", "Main playable Coin Troll", "A low-level coin collector pulled into bigger conflicts. Test platforming, coins, ground attack, air attack, dash and block.", "F1 | A/D move | Space jump | J attack | Shift dash | K block"],
	"NakedCT": ["Chapter 1 / pre-suit", "Existing naked CT player", "The original vulnerable CT before the glowing suit. This wrapper remains side-scrolling, never top-down.", "F3 | A/D move | Space jump | existing damage and speech"],
	"Skull": ["Chapter 1", "Basic patrol enemy", "Skulls patrol the bush maze and teach movement, coin collection, and contact danger.", "Patrol -> detect -> chase -> attack -> retreat. Damage: 1."],
	"EliteSkull": ["Chapter 1", "Mini-blocker enemy", "The Elite Skull blocks CT's urgent route to the treasure chest.", "Detect -> chase -> charge -> attack -> retreat/re-engage. Damage: 1."],
	"Horn": ["Chapters 3-4", "Invulnerable pursuer", "Horn ambushes CT on narrow cliffs, then continues the forest pursuit. This is a survival encounter.", "Warning -> locked charge -> collision -> turn -> recover. Damage: 1 + knockback."],
	"Barreldugo": ["Chapter 4", "Projectile enemy / future mount", "Felix teaches combat types here: get close to beat the projectile type, then tame one for the ship ride.", "Detect -> fire -> retreat -> recover. Projectile: 1. Supports tame() after defeat."],
	"Bulls": ["Chapter 5", "Charging obstacle enemy", "Armored Bulls chase Alex until the Queen intervenes. CT must side-dodge straight charges.", "Warning -> straight charge -> collision -> turn -> recover. Damage: 1 + knockback."],
	"BigBoss": ["Chapter 2", "Non-killable survival boss", "Big Boss attacks CT after the chest incident. Pink Girl later blocks him and turns the fight.", "0.8s telegraph -> sword slash / ground slam -> recovery. Slash: 2; shockwave: 1."],
	"PinkGirl": ["Chapter 2", "Shielded story fighter", "Pink Girl blocks Big Boss's lethal attack and eventually KOs him while CT handles reinforcements.", "Approach -> block -> attack -> recover. She is not hostile to CT."],
	"Felix": ["Chapters 3-7", "Non-combat companion", "Felix guides CT, offers combat advice, tames Barreldugo, and later sells items with Alex.", "Follow -> catch-up -> idle comments. Should never push or teleport CT."],
	"Sword": ["Chapters 3-4", "Story warning NPC", "Sword warns CT about Horn, then sensibly takes the stairs after CT falls.", "Story movement and warning dialogue; no combat in the PDF."],
	"Layla": ["Chapters 5-8", "Observer / analyst NPC", "Lala explains CT's rare suit, the Queen's powers, and Sacavuelo's close-range weakness.", "Story dialogue: analysis and reactions; no combat."],
	"WindQueen": ["Chapters 5 & 7", "Aerial rescuer", "The Queen intercepts Bulls, then levitates and powers up to save the falling ship.", "Levitate -> power up -> rescue flight. Hooks: intercept(), rescue()."],
	"SandMayor": ["Chapter 8", "Contract story NPC", "The Mayor offers coins, tricks CT into a magic contract against Ahrena, and silences Lala with mud.", "Contract and coin-bag story dialogue; no invented combat."],
	"Fairy": ["Source-lightweight", "Aerial story NPC", "The source supplies an asset but no combat encounter, so this remains a small floating story role.", "Float and dialogue only."],
	"Alex": ["Chapters 5-7", "Playable duelist", "Alex faces Sacavuelo, loses the shield, misses bow/thunder, then rallies with batons.", "F2 | A/D + Space | Enter batons | W bow | S shield | Tab thunder."],
	"Sacavuelo": ["Chapters 5-7", "Big Bird duel boss", "Sacavuelo challenges Alex on the ship deck using a returning boomerang. Alex must land five close hits.", "Boomerang outbound/return. 5 HP; only close hits work. Boomerang: 1."]
}

func _ready() -> void:
	avatars = [ct, naked_ct, alex]
	stages = [ct, naked_ct, $Skull, $EliteSkull, $Horn, $Barreldugo, $Bulls, $BigBoss, $PinkGirl, $Felix, $Sword, $Layla, $WindQueen, $SandMayor, $Fairy, alex, $Sacavuelo]
	for actor in stages:
		original_layers[actor] = actor.collision_layer
		original_masks[actor] = actor.collision_mask
		if not avatars.has(actor):
			deactivate_actor(actor)
	set_controlled_character(ct)
	introduce_next()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: set_controlled_character(ct)
		KEY_F2: set_controlled_character(alex)
		KEY_F3: set_controlled_character(naked_ct)
		KEY_N: introduce_next()
		KEY_R: get_tree().reload_current_scene()

func set_controlled_character(character: CharacterBody2D) -> void:
	cleanup_lab_transients()
	for avatar in avatars:
		reset_avatar(avatar)
		avatar.process_mode = Node.PROCESS_MODE_INHERIT if avatar == character else Node.PROCESS_MODE_DISABLED
		avatar.visible = avatar == character
		avatar.collision_layer = int(original_layers.get(avatar, avatar.collision_layer)) if avatar == character else 0
		avatar.collision_mask = int(original_masks.get(avatar, avatar.collision_mask)) if avatar == character else 0
		avatar.remove_from_group("player")
		avatar.velocity = Vector2.ZERO
	ct_override.set_physics_process(character == ct)
	naked_override.set_physics_process(character == naked_ct)
	alex.set_physics_process(character == alex)
	ct_camera.enabled = character == ct
	naked_camera.enabled = character == naked_ct
	alex_camera.enabled = character == alex
	character.process_mode = Node.PROCESS_MODE_INHERIT
	character.visible = true
	character.add_to_group("player")
	mode_label.text = "Controller: " + character.name + "  |  F1 Main CT  F2 Alex  F3 Naked CT  N Next  R Reset"

func deactivate_actor(actor: CharacterBody2D) -> void:
	actor.visible = false
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.velocity = Vector2.ZERO

func reset_avatar(avatar: CharacterBody2D) -> void:
	if "max_health" in avatar and "health" in avatar:
		avatar.set("health", avatar.get("max_health"))
	if "is_dead" in avatar:
		avatar.set("is_dead", false)
	if "dead" in avatar:
		avatar.set("dead", false)
	if "can_take_damage" in avatar:
		avatar.set("can_take_damage", true)
	if avatar.modulate.a < 1.0:
		avatar.modulate = Color.WHITE

func cleanup_lab_transients() -> void:
	for transient in get_tree().get_nodes_in_group("character_lab_transient"):
		if is_instance_valid(transient):
			transient.queue_free()

func activate_actor(actor: CharacterBody2D) -> void:
	if avatars.has(actor):
		set_controlled_character(actor)
		actor.global_position = Vector2(360.0, 820.0)
		return
	actor.visible = true
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	actor.collision_layer = int(original_layers[actor])
	actor.collision_mask = int(original_masks[actor])
	actor.velocity = Vector2.ZERO
	var controller: CharacterBody2D = alex if actor.name == "Sacavuelo" else get_active_avatar()
	actor.global_position = controller.global_position + Vector2(430.0, 0.0)
	if actor.has_method("perform_showcase"):
		actor.call("perform_showcase", controller)

func get_active_avatar() -> CharacterBody2D:
	for avatar in avatars:
		if avatar.is_in_group("player"):
			return avatar
	return ct

func introduce_next() -> void:
	cleanup_lab_transients()
	for avatar in avatars:
		reset_avatar(avatar)
	if stage_index >= 0 and stage_index < stages.size() and not avatars.has(stages[stage_index]):
		deactivate_actor(stages[stage_index])
	stage_index += 1
	if stage_index >= stages.size():
		stage_label.text = "Roster complete - press R to restart."
		story_label.text = "All 17 character tests have been introduced."
		return
	var actor := stages[stage_index]
	activate_actor(actor)
	show_stage_info(actor)

func show_stage_info(actor: CharacterBody2D) -> void:
	var info: Array = stage_data.get(actor.name, ["Prototype", "Character test", "No source summary.", "Inspect movement and collision."])
	stage_label.text = "[" + str(stage_index + 1) + "/" + str(stages.size()) + "] " + actor.name + " - " + str(info[1]) + "\nAppears: " + str(info[0])
	story_label.text = str(info[2]) + "\n\nTEST: " + str(info[3])
