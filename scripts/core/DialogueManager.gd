extends Node
## CTA DialogueManager
## Add this as an Autoload named "DialogueManager".

var used_lines: Dictionary = {}
var counters: Dictionary = {}

const CT := {
	"coin": [
		"Mine.", "Found money. My favorite kind.", "Beautiful. Absolutely beautiful.",
		"Another coin? The universe understands me.", "Coin number two. No witnesses.",
		"This is getting suspiciously profitable.", "I came for adventure. I stayed for loose change.",
		"Five coins! The pocket economy is booming.", "I have entered my coin goblin era.",
		"Coin acquired. Morals still pending.", "My pockets are beginning to have purpose.",
		"Ten! My pockets demand expansion.", "These coins are finding me at this point.",
		"Pocket status: concerning.", "Shiny acquired. Continue immediately.",
		"Why is this more exciting than it should be?", "I regret nothing.", "Still collecting. Still unwell."
	],
	"damage": [
		"HEY! That was attached to me!", "Rude!", "Excuse me?!", "Okay, that hurt.",
		"Unnecessary!", "Okay, now we're having a problem.", "Ow! We're escalating!",
		"I was being nice!", "Can we discuss this without hitting me?",
		"STOP BONKING ME!", "WHY ARE WE SOLVING EVERYTHING WITH VIOLENCE?!",
		"MY BODY IS NOT A TARGET PRACTICE RANGE!", "OKAY! I GET IT! YOU'RE STRONG!"
	],
	"hiding": [
		"Okay. I am now shrub-shaped.", "Nobody move. I am part of nature.",
		"Stealth mode: professionally leafy.", "If anyone asks, I have always been a bush.",
		"Perfect. Time to become vegetation.", "I have chosen the ancient art of hiding.",
		"Camouflage level: questionable.", "I am one with the shrubbery."
	],
	"hide_exit": [
		"Okay. Leaves behind, business ahead.", "Bush break is over.",
		"Back to being suspicious.", "Nature has released me.",
		"Stealth holiday: concluded.", "Time to walk around like that was normal."
	],
	"skull_detect": [
		"Oh no. The bony one noticed me.", "Great. I have been perceived by a skeleton.",
		"Fantastic. Skeleton eyes. Exactly what I needed.", "That skull definitely saw me.",
		"Okay. New objective: remain un-skeletoned.", "Why is that thing looking at me like that?",
		"Well hello there, extremely alarming skull.", "I preferred it when we were strangers."
	],
	"skull_chase_first": [
		"WHY IS THE SKULL SPRINTING?!",
		"NOPE NOPE NOPE—THE SKULL HAS ENTERED RUN MODE!",
		"WHY DOES A SKULL HAVE BETTER CARDIO THAN ME?!",
		"I WOULD LIKE TO FILE A COMPLAINT WITH THE SKELETON DEPARTMENT!",
		"THIS IS NOT A FAIR RACE! YOU DON'T EVEN HAVE MUSCLES!",
		"WHY IS THE BONE MAN SO FAST?!",
		"I AM BEGINNING TO REGRET BEING VISIBLE!",
		"THIS IS A CHASE, NOT A FRIENDSHIP ACTIVITY!",
		"CAN WE BOTH AGREE THAT THIS IS EMBARRASSING?!",
		"SKULL! PLEASE! I HAVE PLACES TO NOT DIE!"
	],
	"skull_chase_repeat": [
		"YOU AGAIN?!", "OH COME ON, I JUST ESCAPED YOU!",
		"WE ARE REALLY DOING THIS AGAIN?!", "WHY DO YOU REMEMBER ME?!",
		"CAN YOU PLEASE FIND A DIFFERENT HOBBY?!",
		"THIS IS STARTING TO FEEL LIKE A PERSONAL VENDETTA!",
		"NOT THE SKULL AGAIN!", "I HAVE ALREADY RUN AWAY FROM YOU ONCE!"
	],
	"skull_attack": [
		"OH, YOU'RE SWINGING NOW?!", "HEY! NO BONKING!",
		"THAT ATTACK LOOKS VERY UNFRIENDLY!", "WAIT! I OBJECT!",
		"CAN WE NOT DO THE VIOLENCE PART?!"
	],
	"skull_lost_first": [
		"Ha! Lost me, bonehead.", "I am officially too sneaky for skeletons.",
		"YES! The bones have lost the trail!", "Good luck finding me, spooky calcium.",
		"Excellent. I remain un-boned.", "Ghosted by a skull. Incredible."
	],
	"skull_lost_repeat": [
		"Not falling for that twice.", "Yep. Still faster than a skeleton.",
		"Another successful escape from the bone department.",
		"Skeleton: 0. Me: still alive.", "That skull needs better tracking software."
	],
	"enemy_detect": ["Oh. That one noticed me.", "Uh... I have attracted attention.",
		"That seems bad.", "Yep. Definitely saw me.", "Okay, stealth has officially failed."],
	"enemy_chase": ["WHY ARE YOU CHASING ME?!", "HEY! I WAS JUST PASSING THROUGH!",
		"NOPE! I AM NOT INTERESTED IN THIS!", "CAN WE NOT DO THE RUNNING THING?!",
		"I DON'T KNOW YOU WELL ENOUGH FOR THIS!", "THIS ESCALATED VERY QUICKLY!"],
	"enemy_attack": ["OH, COME ON!", "HEY! DON'T DO THAT!", "WAIT! WHAT ARE YOU DOING?!",
		"I DO NOT LIKE THAT ANIMATION!", "NO THANK YOU!"],
	"enemy_lost": ["Ha! Lost you.", "Okay. We're good.", "I think I escaped that one.",
		"Excellent. Back to normal.", "That was close."],
	"death": ["Well. That could have gone better.", "I have made several poor decisions today.",
		"Okay. New plan: don't die.", "That was aggressively unsuccessful.",
		"I would like to rewind the last few seconds.", "Yep. Definitely dead.",
		"Cool. Cool cool cool. Everything is terrible."]
}

func _ready() -> void:
	randomize()

func ct(category: String, context: Dictionary = {}) -> String:
	var key := category
	if category == "skull_chase":
		key = "skull_chase_repeat" if int(context.get("chase_number", 1)) > 1 else "skull_chase_first"
	elif category == "skull_lost":
		key = "skull_lost_repeat" if int(context.get("chase_number", 1)) > 1 else "skull_lost_first"

	return _pick(key, CT.get(key, []))

func next_counter(name: String) -> int:
	var value := int(counters.get(name, 0)) + 1
	counters[name] = value
	return value

func _pick(key: String, pool: Array) -> String:
	if pool.is_empty():
		return ""
	var used: Array = used_lines.get(key, [])
	var available: Array = []
	for line in pool:
		if not used.has(line):
			available.append(line)
	if available.is_empty():
		used = []
		available = pool.duplicate()
	var line: String = available[randi_range(0, available.size() - 1)]
	used.append(line)
	used_lines[key] = used
	return line

func reset() -> void:
	used_lines.clear()
	counters.clear()
