extends "res://templates/base_template.gd"
## MARBLE RACE - racers drop through a field of pegs and spinning bars.
## First to the finish line wins. Viewers bet on a racer in the comments.

static func meta() -> Dictionary:
	return {
		"name": "Marble Race",
		"tagline": "Pegs, spinners, chaos. First to the bottom wins.",
		"icon": "1f60e",
		"hook": "Pick a racer before it starts!",
		"title": "",
		"pack": "faces",
		"names": true,
		"sliders": [
			["Racers", "racers", 2, 8, 1, "int"],
			["Peg rows", "rows", 5, 11, 1, "int"],
			["Spinners", "spinners", 0, 4, 1, "int"],
			["Gravity", "gravity", 0.3, 1.5, 0.05, "float"],
		],
		"defaults": {"racers": 6, "rows": 10, "spinners": 3, "gravity": 0.45,
			"names": "Red, Blue, Green, Gold, Pink, Mint, Sky, Rose"},
	}

const LEFT := 90.0
const RIGHT := 990.0
const TOP := 430.0
const FINISH_Y := 1560.0
const PEG_R := 13.0

var racers := []         # each: {ball, name, place}
var pegs := []           # Vector2 positions (for drawing)
var spinners := []       # each: {body, len, speed}
var places := 0
var podium := []

func start() -> void:
	# side walls and a funnel to the finish
	make_wall(PackedVector2Array([Vector2(LEFT, -200), Vector2(LEFT, FINISH_Y - 120), Vector2(430, FINISH_Y)]))
	make_wall(PackedVector2Array([Vector2(RIGHT, -200), Vector2(RIGHT, FINISH_Y - 120), Vector2(650, FINISH_Y)]))
	# staggered peg field
	var rows := int(cfg.get("rows", 8))
	var gap_y := (FINISH_Y - 260 - TOP) / rows
	var pegs_body := StaticBody2D.new()
	add_child(pegs_body)
	for r in rows:
		var y := TOP + 60 + r * gap_y
		var offset := 0.0 if r % 2 == 0 else 55.0
		var x := LEFT + 55 + offset
		while x < RIGHT - 40:
			var shape := CircleShape2D.new()
			shape.radius = PEG_R
			var col := CollisionShape2D.new()
			col.shape = shape
			col.position = Vector2(x, y)
			pegs_body.add_child(col)
			pegs.append(Vector2(x, y))
			x += 110.0
	# spinning bars between the peg rows
	var n_spin := int(cfg.get("spinners", 2))
	for i in n_spin:
		var body := AnimatableBody2D.new()
		body.position = Vector2(LEFT + (RIGHT - LEFT) * (i + 1) / (n_spin + 1), TOP + 140 + (FINISH_Y - TOP - 500) * float(i) / max(1, n_spin))
		var rect := RectangleShape2D.new()
		rect.size = Vector2(230, 16)
		var col := CollisionShape2D.new()
		col.shape = rect
		body.add_child(col)
		add_child(body)
		spinners.append({"body": body, "len": 230.0, "speed": (1.6 + randf()) * (1 if i % 2 == 0 else -1)})
	# racers line up at the top
	var names := str(cfg.get("names", "")).split(",")
	var n := int(cfg.get("racers", 6))
	for i in n:
		var x: float = lerp(LEFT + 80, RIGHT - 80, float(i) / max(1, n - 1))
		var b := make_ball(Vector2(x, 300 + randf() * 30), 34.0, Vector2(randf_range(-60, 60), 0), i + 1)
		b.bounciness = 0.55
		b.gravity_scale = float(cfg.get("gravity", 0.6))
		b.bounce_sound = null
		var nm := names[i].strip_edges() if i < names.size() and names[i].strip_edges() != "" else "Racer %d" % (i + 1)
		var rc := {"ball": b, "name": nm, "place": 0}
		b.hit.connect(_on_hit.bind(rc))
		add_child(b)
		racers.append(rc)
	update_counter()

func _physics_process(delta: float) -> void:
	for s in spinners:
		s.body.rotation += s.speed * delta

func _on_hit(_body: Node, rc: Dictionary) -> void:
	var b: RigidBody2D = rc.ball
	if b.linear_velocity.length() > 180 and randf() < 0.5:
		var step := int(clamp((b.position.y - TOP) / (FINISH_Y - TOP) * 10.0, 0, 10))
		play_sound(scale_pitch(step), -8.0)

func tick(_delta: float) -> void:
	if over:
		return
	for rc in racers:
		if rc.place == 0 and rc.ball.position.y > FINISH_Y + 10:
			places += 1
			rc.place = places
			podium.append(rc.name)
			burst(rc.ball.position, rc.ball.color, 50, 700)
			shake(10.0 if places == 1 else 4.0)
			play_sound(scale_pitch(14 - places * 2), 2.0)
			update_counter()
			if places == 1:
				flash(0.3)
				end_after_podium()

func end_after_podium() -> void:
	await get_tree().create_timer(2.0).timeout
	finish(str(podium[0]).to_upper() + " WINS!")

func update_counter() -> void:
	var medals := ["1st", "2nd", "3rd"]
	var parts := []
	for i in min(3, podium.size()):
		parts.append("%s %s" % [medals[i], podium[i]])
	counter.text = "   ".join(parts) if parts.size() > 0 else "And they're off..."

func draw_scene() -> void:
	draw_neon_polyline(PackedVector2Array([Vector2(LEFT, 280), Vector2(LEFT, FINISH_Y - 120), Vector2(430, FINISH_Y)]), 4.0)
	draw_neon_polyline(PackedVector2Array([Vector2(RIGHT, 280), Vector2(RIGHT, FINISH_Y - 120), Vector2(650, FINISH_Y)]), 4.0)
	for p in pegs:
		draw_circle(p, PEG_R + 6, Color(neon_color(p.y), 0.18))
		draw_circle(p, PEG_R, neon_color(p.y).lerp(Color.WHITE, 0.3))
	for s in spinners:
		var b: Node2D = s.body
		var half: Vector2 = Vector2(cos(b.rotation), sin(b.rotation)) * float(s.len) / 2.0
		draw_line(b.position - half, b.position + half, Color(neon_color(b.position.y), 0.25), 30, true)
		draw_line(b.position - half, b.position + half, neon_color(b.position.y).lerp(Color.WHITE, 0.4), 12, true)
	# chequered finish line
	for i in 12:
		var c := Color.WHITE if i % 2 == 0 else Color(0.1, 0.1, 0.1)
		draw_rect(Rect2(430 + i * 18.33, FINISH_Y, 18.33, 14), c)
	# names above the racers still running
	var font := ThemeDB.fallback_font
	for rc in racers:
		if rc.place == 0:
			var b: RigidBody2D = rc.ball
			draw_string(font, b.position + Vector2(-100, -46), str(rc.name), HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color(1, 1, 1, 0.9))
