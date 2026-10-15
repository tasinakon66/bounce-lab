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

const RING := 470.0

var fighters := []       # each: {ball, hp, name}
var speed := 750.0

func start() -> void:
	make_wall(arc_points(CENTER, RING, 0, TAU, 120))
	speed = float(cfg.get("speed", 750))
	var names := str(cfg.get("names", "")).split(",")
	var n := int(cfg.get("fighters", 4))
	for i in n:
		var a := TAU * i / n
		var pos := CENTER + Vector2(cos(a), sin(a)) * 230.0
		var dir := Vector2(cos(a + 1.9), sin(a + 1.9))
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
	# keep the action going: constant speed that slowly ramps up
	speed += delta * 12.0
	var showdown := fighters.size() == 2     # final two are pulled towards each other
	for f in fighters:
		var b: RigidBody2D = f.ball
		if b.linear_velocity.length() > 1.0:
			var dir := b.linear_velocity.normalized()
			if showdown:
				var other: RigidBody2D = fighters[1].ball if f == fighters[0] else fighters[0].ball
				dir = (dir + (other.position - b.position).normalized() * 0.04).normalized()
			b.linear_velocity = dir * speed

func _on_hit(body: Node, f: Dictionary) -> void:
	if over or not fighters.has(f):
		return
	if not (body is RigidBody2D):
		play_sound(1.0 + randf() * 0.1, -10.0)
		return
	# Two fighters crashed: each crash takes health, sometimes a critical hit
	var dmg := randf_range(14.0, 26.0)
	var crit := randf() < 0.12
	if crit:
		dmg *= 2.5
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

func draw_scene() -> void:
	draw_neon_polyline(arc_points(CENTER, RING, 0, TAU, 160))
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
