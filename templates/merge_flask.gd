extends "res://templates/base_template.gd"
## MERGE FLASK - balls stream single-file down the neck of a glowing flask.
## Two of the same merge into the next one, all the way up to the goal.

static func meta() -> Dictionary:
	return {
		"name": "Merge Flask",
		"tagline": "Drop, stack, merge... can it reach the top level?",
		"icon": "1f349",
		"hook": "Can it reach the final fruit?",
		"title": "Fruits",
		"pack": "fruits",
		"sliders": [
			["Goal level", "goal", 4, 10, 1, "level"],
			["Drop every", "drop", 0.2, 1.2, 0.05, "seconds"],
			["Bounciness", "bounce", 0.0, 0.8, 0.05, "percent"],
		],
		"defaults": {"goal": 7, "drop": 0.4, "bounce": 0.25},
	}

const NECK_LEFT := 445.0
const NECK_RIGHT := 635.0
const BULB_CENTER := Vector2(540, 970)
const BULB_RADIUS := 495.0

var best := 0
var flask: PackedVector2Array

func start() -> void:
	flask = flask_points()
	make_wall(flask)
	update_counter()
	drop_loop()

func flask_points() -> PackedVector2Array:
	var half := (NECK_RIGHT - NECK_LEFT) / 2.0
	var join_y := BULB_CENTER.y - sqrt(BULB_RADIUS * BULB_RADIUS - half * half)
	var a_left := atan2(join_y - BULB_CENTER.y, -half) + TAU
	var a_right := atan2(join_y - BULB_CENTER.y, half)
	var pts := PackedVector2Array([Vector2(NECK_LEFT, -300), Vector2(NECK_LEFT, join_y)])
	var arc := arc_points(BULB_CENTER, BULB_RADIUS, a_left, a_right, 110)
	for i in range(1, arc.size() - 1):
		pts.append(arc[i])
	pts.append(Vector2(NECK_RIGHT, join_y))
	pts.append(Vector2(NECK_RIGHT, -300))
	return pts

func drop_loop() -> void:
	while not over:
		spawn(Vector2(540 + randf_range(-6, 6), -80), 1, false)
		await get_tree().create_timer(float(cfg.get("drop", 0.4))).timeout

func ball_radius(lvl: int) -> float:
	return 30.0 + lvl * 9.5

func spawn(pos: Vector2, lvl: int, from_merge: bool) -> void:
	var b := make_ball(pos, ball_radius(lvl), Vector2(0, 250), lvl)
	b.level = lvl
	b.bounciness = float(cfg.get("bounce", 0.25))
	b.friction = 0.3
	b.show_number = b.picture == null
	add_child(b)
	if from_merge:
		b.pop = 1.4
		var tw := b.create_tween()
		tw.tween_property(b, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK)
		burst(pos, level_color(lvl), 30 + lvl * 6, 350 + lvl * 40)
		shake(2.0 + lvl * 1.5)
		play_sound(scale_pitch(lvl - 1))
	if lvl > best:
		best = lvl
		update_counter()
		if lvl >= 4 and lvl < int(cfg.get("goal", 7)):
			flash(0.15 + lvl * 0.02)

func merge_balls(a: Node2D, b: Node2D) -> void:
	var pos := (a.position + b.position) / 2.0
	var lvl: int = a.level + 1
	a.queue_free()
	b.queue_free()
	call_deferred("spawn", pos, lvl, true)
	if lvl >= int(cfg.get("goal", 7)):
		var tex := item_texture(lvl)
		finish(str(int(pow(2, lvl))) + "!" if tex == null else "FINAL FORM!", tex)

func update_counter() -> void:
	counter.text = ""   # the level bar below says it all

func draw_scene() -> void:
	draw_neon_polyline(flask)
	# Level ladder: every picture from smallest to the goal, lit up as reached
	var goal := int(cfg.get("goal", 7))
	var r := 30.0 if goal <= 8 else 26.0
	var gap := 14.0
	var total := goal * r * 2 + (goal - 1) * gap
	var x0 := W / 2 - total / 2 + r
	for i in goal:
		var lvl := i + 1
		var p := Vector2(x0 + i * (r * 2 + gap), 1770)
		var lit := lvl <= best
		var tex := item_texture(lvl)
		if lit:
			draw_circle(p, r + 8, Color(level_color(lvl), 0.25))
		if tex:
			draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false,
				Color(1, 1, 1, 1.0 if lit else 0.22))
		else:
			var c := level_color(lvl)
			c.a = 1.0 if lit else 0.22
			draw_circle(p, r, c)
			var txt := str(int(pow(2, lvl)))
			var fs := 20 if txt.length() >= 4 else (24 if txt.length() == 3 else 30)
			draw_string(ThemeDB.fallback_font, p + Vector2(-r, fs * 0.35), txt,
				HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(1, 1, 1, c.a))
		if i < goal - 1:
			draw_line(p + Vector2(r + 2, 0), p + Vector2(r + gap - 2, 0), Color(1, 1, 1, 0.3), 2)
