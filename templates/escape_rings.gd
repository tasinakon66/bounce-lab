extends "res://templates/base_template.gd"
## ESCAPE THE RINGS - a ball trapped inside spinning rings, each with a gap.
## Every time it slips through a gap, that ring shatters. Will it escape?

static func meta() -> Dictionary:
	return {
		"name": "Escape the Rings",
		"tagline": "Spinning rings, tiny gaps. Will it get out?",
		"icon": "1fa90",
		"hook": "Will the ball escape?",
		"title": "",
		"pack": "neon",
		"sliders": [
			["Rings", "rings", 3, 14, 1, "int"],
			["Gap size", "gap", 20, 80, 5, "degrees"],
			["Ring spin", "spin", 20, 160, 5, "int"],
			["Ball size", "size", 14, 40, 1, "int"],
		],
		"defaults": {"rings": 7, "gap": 55.0, "spin": 80.0, "size": 22.0},
	}

const INNER := 110.0
const OUTER := 470.0

var rings := []          # each: {body, radius, speed, angle}
var ball: RigidBody2D
var broken := 0
var hits := 0

func start() -> void:
	var n := int(cfg.get("rings", 8))
	var gap := deg_to_rad(float(cfg.get("gap", 40)))
	for i in n:
		var r: float = lerp(INNER, OUTER, float(i) / max(1, n - 1))
		var body := StaticBody2D.new()
		body.position = CENTER
		add_child(body)
		var arc := arc_points(Vector2.ZERO, r, gap / 2.0, TAU - gap / 2.0, 72)
		for k in arc.size() - 1:
			var seg := SegmentShape2D.new()
			seg.a = arc[k]
			seg.b = arc[k + 1]
			var col := CollisionShape2D.new()
			col.shape = seg
			body.add_child(col)
		var dir := 1.0 if i % 2 == 0 else -1.0
		var spd := deg_to_rad(float(cfg.get("spin", 70))) * dir * (1.0 - 0.35 * float(i) / n)
		var start_angle := randf() * TAU
		body.rotation = start_angle
		rings.append({"body": body, "radius": r, "speed": spd})
	var a := randf() * TAU
	ball = make_ball(CENTER, float(cfg.get("size", 22)), Vector2(cos(a), sin(a)) * 700.0, 1)
	ball.bounce_sound = null
	ball.hit.connect(_on_hit)
	add_child(ball)
	update_counter()

func _on_hit(_body: Node) -> void:
	hits += 1
	play_sound(scale_pitch(broken + (hits % 3)), -4.0)

func tick(delta: float) -> void:
	for ring in rings:
		ring.body.rotation += ring.speed * delta
	if over or ball == null:
		return
	# Has the ball got outside the innermost unbroken ring?
	if not rings.is_empty():
		var inner = rings[0]
		if ball.position.distance_to(CENTER) > inner.radius + ball.radius + 4:
			shatter(inner)
	elif ball.position.distance_to(CENTER) > OUTER + 120:
		finish("ESCAPED!")

func shatter(ring: Dictionary) -> void:
	rings.erase(ring)
	broken += 1
	ball.linear_velocity *= 1.08     # a little faster every ring: tension builds
	for k in 24:
		var a := TAU * k / 24.0
		burst(CENTER + Vector2(cos(a), sin(a)) * ring.radius, neon_color(CENTER.y + sin(a) * ring.radius), 6, 420)
	ring.body.queue_free()
	shake(6.0 + broken)
	flash(0.12)
	play_sound(scale_pitch(min(14, broken * 2)), 2.0)
	update_counter()
	if rings.is_empty():
		ball.gravity_scale = 0.0

func update_counter() -> void:
	counter.text = "Rings left: %d" % rings.size()

func draw_scene() -> void:
	var gap := deg_to_rad(float(cfg.get("gap", 40)))
	for ring in rings:
		var a0: float = ring.body.rotation + gap / 2.0
		draw_neon_polyline(arc_points(CENTER, ring.radius, a0, a0 + TAU - gap, 90), 4.0)
