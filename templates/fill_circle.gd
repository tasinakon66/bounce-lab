extends "res://templates/base_template.gd"
## FILL THE CIRCLE - every bounce creates a new ball.
## One becomes two, two become four... until the circle is packed full.

static func meta() -> Dictionary:
	return {
		"name": "Fill the Circle",
		"tagline": "Every bounce makes a new ball. Watch it explode.",
		"icon": "2b50",
		"hook": "Every bounce = 1 new ball",
		"title": "",
		"pack": "neon",
		"sliders": [
			["Ball size", "size", 12, 40, 1, "int"],
			["Speed", "speed", 300, 1400, 50, "int"],
			["Full at", "target", 40, 75, 5, "percent_int"],
		],
		"defaults": {"size": 22.0, "speed": 800.0, "target": 60.0},
	}

const RING := 470.0
const MAX_BALLS := 700

var count := 0
var spawn_cooldown := 0.0
var filled_area := 0.0

func start() -> void:
	make_wall(arc_points(CENTER, RING, 0, TAU, 120))
	add_one(CENTER)
	update_counter()

func add_one(pos: Vector2) -> void:
	if count >= MAX_BALLS or over:
		return
	count += 1
	var r := float(cfg.get("size", 22))
	var a := randf() * TAU
	var b := make_ball(pos, r, Vector2(cos(a), sin(a)) * float(cfg.get("speed", 800)), count)
	b.bounce_sound = null
	b.glow = count < 120          # keep it smooth when there are hundreds
	b.hit.connect(_on_hit.bind(b))
	add_child(b)
	filled_area += PI * r * r

func tick(delta: float) -> void:
	spawn_cooldown -= delta
	# a ball squeezed through the wall by the crowd is removed
	for b in get_children():
		if b is RigidBody2D and b.position.distance_to(CENTER) > RING + 60:
			b.queue_free()

func _on_hit(body: Node, b: RigidBody2D) -> void:
	if over or not (body is StaticBody2D):
		return        # only wall bounces spawn new balls
	if spawn_cooldown > 0.0:
		return
	spawn_cooldown = 0.03 if count < 60 else 0.06
	call_deferred("add_one", CENTER + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	if count % 3 == 0:
		play_sound(scale_pitch(min(14, count / 25)) * (1.0 + randf() * 0.02), -6.0)
	update_counter()
	if fill_percent() >= 100:
		finish("FULL!")

func fill_percent() -> int:
	var target := float(cfg.get("target", 60)) / 100.0
	return int(clamp(filled_area / (PI * RING * RING * target) * 100.0, 0, 100))

func update_counter() -> void:
	counter.text = "Balls: %d    Full: %d%%" % [count, fill_percent()]

func draw_scene() -> void:
	draw_neon_polyline(arc_points(CENTER, RING, 0, TAU, 160))
	# progress ring that fills up as the circle packs
	var p := fill_percent() / 100.0
	if p > 0.0:
		draw_arc(CENTER, RING + 26, -PI / 2, -PI / 2 + TAU * p, 120, Color(1, 1, 1, 0.55), 8, true)
