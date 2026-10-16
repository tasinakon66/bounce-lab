extends "res://templates/base_template.gd"
## FRIEND BATTLE - put your friends (or emojis) in the arena.
## Every crash costs health. Last one standing wins.
## Made for comments: "Who are you betting on?"

static func meta() -> Dictionary:
	return {
		"name": "Friend Battle",
		"tagline": "Put your friends in the arena. Last one standing wins.",
		"icon": "1f981",
		"hook": "Who wins? Comment your pick!",
		"title": "",
		"pack": "animals",
		"names": true,
		"sliders": [
			["Fighters", "fighters", 2, 6, 1, "int"],
			["Size", "size", 40, 110, 1, "int"],
			["Speed", "speed", 400, 1400, 50, "int"],
		],
		"defaults": {"fighters": 4, "size": 80.0, "speed": 800.0, "names": "Bug, Fish, Bunny, Cat, Dog, Fox"},
	}

const RING := 470.0          # starting size of the arena
const MIN_RING := 250.0      # it shrinks down to this
const SHRINK := 6.0          # pixels per second

var ring := RING

var fighters := []       # each: {ball, hp, name}
var speed := 750.0

func start() -> void:
	speed = float(cfg.get("speed", 750))
	var names := str(cfg.get("names", "")).split(",")
	var n := int(cfg.get("fighters", 4))
	for i in n:
		var a := TAU * i / n
		var pos := CENTER + Vector2(cos(a), sin(a)) * 230.0
		var d := randf() * TAU            # random start direction for every fighter
		var dir := Vector2(cos(d), sin(d))
		var b := make_ball(pos, float(cfg.get("size", 70)), dir * speed, i + 1)
		b.gravity_scale = 0.0
		b.bounce_sound = null
		var nm := names[i].strip_edges() if i < names.size() and names[i].strip_edges() != "" else "Player %d" % (i + 1)
		var f := {"ball": b, "hp": 100.0, "name": nm}
		b.hit.connect(_on_hit.bind(f))
		add_child(b)
		fighters.append(f)
	update_counter()

func tick(delta: float) -> void:
	speed += delta * 10.0     # the fight slowly speeds up
	ring = max(MIN_RING, ring - SHRINK * delta)   # the arena closes in

# Speed is managed inside the physics step (not every drawn frame), and only
# gently, so the physics engine can still bounce fighters off the wall cleanly.
func _physics_process(_delta: float) -> void:
	# every fighter is gently pulled towards its nearest rival, more so in the final two
	var pull := 0.10 if fighters.size() == 2 else 0.02
	for f in fighters:
		var b: RigidBody2D = f.ball
		var v := b.linear_velocity
		var from_center := b.position - CENTER
		var n := from_center.normalized()
		# The arena wall is handled here in code (it shrinks, so it can't be a fixed
		# physics wall): keep the fighter inside and bounce it off cleanly.
		var limit: float = ring - float(b.radius)
		if from_center.length() > limit:
			b.position = CENTER + n * limit
			if v.dot(n) > 0.0:
				v = v - 2.0 * v.dot(n) * n
				play_sound(1.0 + randf() * 0.1, -12.0)
		if v.length() < 1.0:
			v = Vector2.from_angle(randf() * TAU) * speed
		var dir := v.normalized()
		var target_pos := nearest_rival(f)
		# right after a crash, fly apart instead of grinding into each other
		if target_pos != Vector2.INF and time > float(f.get("safe_until", 0.0)) + 0.8:
			dir = (dir + (target_pos - b.position).normalized() * pull).normalized()
		b.linear_velocity = dir * lerp(v.length(), speed, 0.05)
		b.angular_velocity = clamp(b.angular_velocity, -6.0, 6.0)

func nearest_rival(f: Dictionary) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for o in fighters:
		if o == f:
			continue
		var d: float = f.ball.position.distance_to(o.ball.position)
		if d < best_d:
			best_d = d
			best = o.ball.position
	return best

func _on_hit(body: Node, f: Dictionary) -> void:
	if over or not fighters.has(f):
		return
	if not (body is RigidBody2D):
		play_sound(1.0 + randf() * 0.1, -10.0)
		return
	# One crash = one hit (contacts can fire several times per crash)
	if time < f.get("safe_until", 0.0):
		return
	f["safe_until"] = time + 0.5
	# Two fighters crashed: each crash takes health, sometimes a critical hit
	var dmg := randf_range(2.0, 3.6)
	var crit := randf() < 0.08
	if crit:
		dmg *= 2.5
	if fighters.size() == 2:
		dmg *= 1.6       # the final showdown hits harder, so it ends with a bang
	f.hp -= dmg
	var b: RigidBody2D = f.ball
	burst(b.position, b.color, 16 if not crit else 50, 400 if not crit else 800)
	shake(4.0 if not crit else 14.0)
	play_sound(scale_pitch(int(randf() * 5)) * (0.7 if crit else 1.0), 0.0 if crit else -4.0)
	if crit:
		flash(0.15)
		popup_text("CRIT!", b.position)
	if f.hp <= 0.0:
		knock_out(f)
	update_counter()

func knock_out(f: Dictionary) -> void:
	fighters.erase(f)
	var b: RigidBody2D = f.ball
	burst(b.position, b.color, 90, 1000)
	shake(20.0)
	flash(0.35)
	play_sound(0.5, 6.0)
	popup_text(str(f.name) + " is OUT", b.position)
	b.queue_free()
	if fighters.size() == 1:
		var winner: Dictionary = fighters[0]
		finish(str(winner.name).to_upper() + " WINS!")

func popup_text(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(600, 80)
	l.position = pos - Vector2(300, 140)
	ui.add_child(l)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 120, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)

func update_counter() -> void:
	counter.text = "FINAL SHOWDOWN" if fighters.size() == 2 else "Still fighting: %d" % fighters.size()
	if ring <= MIN_RING + 1 and fighters.size() > 1:
		counter.text += "  -  NO ESCAPE"

func draw_scene() -> void:
	draw_neon_polyline(arc_points(CENTER, ring, 0, TAU, 160))
	# faint outline of where the arena started, so you can see it closing
	draw_arc(CENTER, RING, 0, TAU, 160, Color(1, 0.3, 0.35, 0.18), 4, true)
	# health bar and name above every fighter
	var font := ThemeDB.fallback_font
	for f in fighters:
		var b: RigidBody2D = f.ball
		var w := 130.0
		var top: Vector2 = b.position + Vector2(-w / 2, -b.radius - 34)
		draw_rect(Rect2(top, Vector2(w, 14)), Color(0, 0, 0, 0.6))
		var hp: float = clamp(f.hp / 100.0, 0.0, 1.0)
		draw_rect(Rect2(top, Vector2(w * hp, 14)), Color(1, 0.3, 0.3).lerp(Color(0.4, 1, 0.5), hp))
		draw_string(font, top + Vector2(-60, -8), str(f.name), HORIZONTAL_ALIGNMENT_CENTER, w + 120, 32, Color.WHITE)
