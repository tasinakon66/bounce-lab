extends "res://templates/base_template.gd"
## MELODY BOUNCE - every bounce plays the next note of a song.
## Perfect for "Guess the song" Reels. All melodies are public domain.

static func meta() -> Dictionary:
	return {
		"name": "Melody Bounce",
		"tagline": "Each bounce plays the next note. Guess the song!",
		"icon": "1f31f",
		"hook": "Guess the song...",
		"title": "",
		"pack": "neon",
		"songs": true,
		"sliders": [
			["Balls", "balls", 1, 6, 1, "int"],
			["Ball size", "size", 20, 90, 1, "int"],
			["Speed", "speed", 300, 1600, 50, "int"],
			["Length (notes)", "notes", 20, 120, 5, "int"],
		],
		"defaults": {"balls": 1, "size": 45.0, "speed": 900.0, "notes": 56},
	}

const RING := 470.0
const SONGS := {
	"twinkle twinkle": [0,0,7,7,9,9,7, 5,5,4,4,2,2,0, 7,7,5,5,4,4,2, 7,7,5,5,4,4,2, 0,0,7,7,9,9,7, 5,5,4,4,2,2,0],
	"ode to joy": [4,4,5,7,7,5,4,2,0,0,2,4,4,2,2, 4,4,5,7,7,5,4,2,0,0,2,4,2,0,0],
	"fur elise": [4,3,4,3,4,-1,2,0,-3, -12,-8,-3,-1, -8,-4,-1,0, -8,4,3,4,3,4,-1,2,0,-3],
	"happy birthday": [-5,-5,-3,-5,0,-1, -5,-5,-3,-5,2,0, -5,-5,7,4,0,-1,-3, 5,5,4,0,2,0],
	"jingle bells": [4,4,4, 4,4,4, 4,7,0,2,4, 5,5,5,5,5,4,4,4,4,2,2,4,2,7],
}

var note := 0

func start() -> void:
	make_wall(arc_points(CENTER, RING, 0, TAU, 120))
	for i in int(cfg.get("balls", 1)):
		var a := randf() * TAU
		var b := make_ball(CENTER + Vector2(randf_range(-80, 80), randf_range(-80, 80)),
			float(cfg.get("size", 45)), Vector2(cos(a), sin(a)) * float(cfg.get("speed", 900)), i + 1)
		b.hit.connect(_on_hit.bind(b))
		add_child(b)
	update_counter()

func next_pitch() -> float:
	var song: Array = SONGS.get(str(cfg.get("song", "twinkle twinkle")), SONGS["twinkle twinkle"])
	var semi: int = song[note % song.size()]
	note += 1
	update_counter()
	if note >= int(cfg.get("notes", 56)):
		finish("DID YOU GUESS IT?")
	return pow(2.0, semi / 12.0)

func _on_hit(_body: Node, b: RigidBody2D) -> void:
	burst(b.position, b.color, 10, 250)
	b.pop = 1.15
	b.create_tween().tween_property(b, "pop", 1.0, 0.12)

func update_counter() -> void:
	counter.text = "Notes: %d" % note

func draw_scene() -> void:
	draw_neon_polyline(arc_points(CENTER, RING, 0, TAU, 160))
