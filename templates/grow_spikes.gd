extends "res://templates/base_template.gd"
## GROW & SPIKES - the ball gets bigger with every bounce...
## ...but touching the spikes pops it back to tiny. Can it fill the circle?

static func meta() -> Dictionary:
	return {
		"name": "Grow & Spikes",
		"tagline": "Every bounce it grows. The spikes cut it in half.",
		"icon": "1f315",
		"hook": "Every bounce it grows... can it fill the circle?",
		"title": "",
		"pack": "neon",
		"sliders": [
			["Growth per bounce", "growth", 2, 14, 0.5, "float"],
			["Spike zone", "spikes", 0, 120, 5, "degrees"],
			["Spike spin", "spin", 0, 90, 5, "int"],
			["Speed", "speed", 400, 1600, 50, "int"],
		],
		"defaults": {"growth": 12.0, "spikes": 35.0, "spin": 25.0, "speed": 900.0},
	}

const RING := 470.0
const START_R := 22.0

var ball: RigidBody2D
var ring_angle := 0.0
var pops := 0
var bounces := 0

func start() -> void:
	make_wall(arc_points(CENTER, RING, 0, TAU, 120))
	new_ball()
	update_counter()

func new_ball() -> void:
	var a := randf() * TAU
	ball = make_ball(CENTER, START_R, Vector2(cos(a), sin(a)) * float(cfg.get("speed", 900)), 1)
	ball.bounce_sound = null         # this template plays its own rising notes
	ball.hit.connect(_on_hit)
	add_child(ball)
	bounces = 0

func tick(delta: float) -> void:
	ring_angle += deg_to_rad(float(cfg.get("spin", 30))) * delta

# Is this direction (from the centre) inside the spike zone?
func in_spikes(dir_angle: float) -> bool:
	var zone := deg_to_rad(float(cfg.get("spikes", 50)))
	if zone <= 0.0:
		return false
	var diff := wrapf(dir_angle - ring_angle, -PI, PI)
	return abs(diff) < zone / 2.0

func _on_hit(_body: Node) -> void:
	if over or ball == null:
		return
	var dir := (ball.position - CENTER).angle()
	if in_spikes(dir):
		pop_ball()
		return
	bounces += 1
	var growth := float(cfg.get("growth", 6))
	ball.set_radius(min(ball.radius + growth, RING - 6))
	ball.pop = 1.12
	ball.create_tween().tween_property(ball, "pop", 1.0, 0.15)
	play_sound(scale_pitch((bounces - 1) % 15))
	burst(ball.position + (ball.position - CENTER).normalized() * ball.radius, neon_color(ball.position.y), 12, 300)
	update_counter()
	if ball.radius >= RING - 30:
		ball.freeze = true
		finish("IT MADE IT!")

# Hitting the spikes shatters part of the ball: it shrinks to half size
var safe_until := 0.0

func pop_ball() -> void:
	if time < safe_until:
		return
	safe_until = time + 0.6
	pops += 1
	var lost: float = ball.radius
	ball.set_radius(max(START_R, ball.radius * 0.5))
	bounces = max(0, bounces / 2)
	burst(ball.position, Color(1, 0.35, 0.4), int(30 + lost), 900)
	shake(8.0 + lost / 20.0)
	flash(0.2)
	play_sound(0.5, 4.0)
	update_counter()

func update_counter() -> void:
	var size := 0
	if ball:
		size = int(round((ball.radius - START_R) / (RING - 30 - START_R) * 100.0))
	counter.text = "Size: %d%%    Pops: %d" % [clamp(size, 0, 100), pops]

func draw_scene() -> void:
	draw_neon_polyline(arc_points(CENTER, RING, 0, TAU, 160))
	# Spikes: red triangles pointing inwards, spinning with the zone
	var zone := deg_to_rad(float(cfg.get("spikes", 50)))
	if zone > 0.0:
		var count := int(max(2, zone / deg_to_rad(9)))
		for i in count:
			var a := ring_angle - zone / 2.0 + zone * (i + 0.5) / count
			var w := zone / count / 2.0
			var tip := CENTER + Vector2(cos(a), sin(a)) * (RING - 42)
			var l := CENTER + Vector2(cos(a - w), sin(a - w)) * RING
			var r := CENTER + Vector2(cos(a + w), sin(a + w)) * RING
			draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(1, 0.25, 0.35, 0.9))
			draw_polyline(PackedVector2Array([l, tip, r]), Color(1, 0.7, 0.75), 3, true)
