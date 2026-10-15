extends Node2D

@export var ball_scene: PackedScene = preload("res://ball.tscn")
@export var auto_restart: bool = true    # start again after winning
@export var restart_delay: float = 4.0   # seconds before restarting

# Player's choices. "static" means they survive scene restarts.
static var data := {
	"show_menu": true,
	"merge_mode": false,
	"ball_count": 10,
	"ball_size": 40.0,
	"speed": 900.0,
	"bounciness": 1.0,
	"goal_level": 7,        # 7 = 128
	"drop_interval": 0.8,
}
var finished := false
var best_level := 0
var ui: CanvasLayer

func _ready() -> void:
	randomize()
	ui = CanvasLayer.new()
	add_child(ui)
	if data["show_menu"]:
		build_menu()
	else:
		start_game()

# ================= MENU =================
func build_menu() -> void:
	var theme := Theme.new()
	theme.default_font_size = 46

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = theme
	ui.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 160)
	bg.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	margin.add_child(box)

	var title := Label.new()
	title.text = "BounceLab"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.75, 0.7, 1.0))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Make your own physics Reel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(sub)
	box.add_child(spacer(30))

	# Mode switch
	var mode_btn := Button.new()
	mode_btn.custom_minimum_size = Vector2(0, 110)
	box.add_child(mode_btn)

	# Settings for each mode (only one group shows at a time)
	var bounce_box := VBoxContainer.new()
	bounce_box.add_theme_constant_override("separation", 10)
	box.add_child(bounce_box)
	add_slider(bounce_box, "Balls", "ball_count", 1, 50, 1, "int")
	add_slider(bounce_box, "Ball size", "ball_size", 15, 80, 1, "int")
	add_slider(bounce_box, "Speed", "speed", 200, 2000, 50, "int")
	add_slider(bounce_box, "Bounciness", "bounciness", 0.5, 1.0, 0.05, "percent")

	var merge_box := VBoxContainer.new()
	merge_box.add_theme_constant_override("separation", 10)
	box.add_child(merge_box)
	add_slider(merge_box, "Goal", "goal_level", 3, 10, 1, "power")
	add_slider(merge_box, "Drop every", "drop_interval", 0.2, 2.0, 0.1, "seconds")

	var refresh := func():
		mode_btn.text = "Mode:  " + ("MERGE  (2, 4, 8...)" if data["merge_mode"] else "BOUNCE")
		bounce_box.visible = not data["merge_mode"]
		merge_box.visible = data["merge_mode"]
	mode_btn.pressed.connect(func():
		data["merge_mode"] = not data["merge_mode"]
		refresh.call())
	refresh.call()

	box.add_child(spacer(40))
	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(0, 150)
	start.add_theme_font_size_override("font_size", 70)
	start.pressed.connect(func():
		data["show_menu"] = false
		bg.queue_free()
		start_game())
	box.add_child(start)

func add_slider(parent: Node, title: String, key: String, min_v: float, max_v: float,
		step: float, kind: String) -> void:
	var label := Label.new()
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = data[key]
	slider.custom_minimum_size = Vector2(0, 70)
	label.text = title + ":  " + format_value(data[key], kind)
	slider.value_changed.connect(func(v):
		data[key] = v
		label.text = title + ":  " + format_value(v, kind))
	parent.add_child(label)
	parent.add_child(slider)

func format_value(v: float, kind: String) -> String:
	match kind:
		"percent": return "%d%%" % int(round(v * 100))
		"power": return str(int(pow(2, v)))
		"seconds": return "%.1fs" % v
	return str(int(v))

func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ================= GAME =================
func start_game() -> void:
	# Small "back to menu" button in the corner
	var back := Button.new()
	back.text = "< Menu"
	back.position = Vector2(30, 30)
	back.add_theme_font_size_override("font_size", 44)
	back.pressed.connect(func():
		data["show_menu"] = true
		get_tree().reload_current_scene())
	ui.add_child(back)

	queue_redraw()
	if data["merge_mode"]:
		run_merge_mode()
	else:
		run_bounce_mode()

# ---------- BOUNCE MODE ----------
func run_bounce_mode() -> void:
	var delay: float = clamp(4.0 / float(data["ball_count"]), 0.05, 0.4)
	for i in int(data["ball_count"]):
		spawn_ball()
		await get_tree().create_timer(delay).timeout

func spawn_ball() -> void:
	var ball := ball_scene.instantiate()
	ball.radius = data["ball_size"]
	ball.start_speed = data["speed"]
	ball.bounciness = data["bounciness"]
	ball.position = Vector2(540, 960) + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	ball.modulate = Color.from_hsv(randf(), 0.6, 1.0)
	add_child(ball)

# ---------- MERGE MODE ----------
func run_merge_mode() -> void:
	while not finished:
		var pos := Vector2(540 + randf_range(-200, 200), 650)
		spawn_number_ball(pos, 1)
		await get_tree().create_timer(data["drop_interval"]).timeout

func spawn_number_ball(pos: Vector2, lvl: int) -> void:
	var ball := ball_scene.instantiate()
	ball.level = lvl
	ball.start_speed = 150.0
	ball.bounciness = 0.4
	ball.position = pos
	add_child(ball)
	if lvl > best_level:
		best_level = lvl
		queue_redraw()

func merge_balls(a: Node2D, b: Node2D) -> void:
	var pos := (a.position + b.position) / 2.0
	var new_level: int = a.level + 1
	a.queue_free()
	b.queue_free()
	# Wait for physics to finish this frame before adding the new ball
	call_deferred("spawn_number_ball", pos, new_level)
	if new_level >= int(data["goal_level"]) and not finished:
		finished = true
		win(int(pow(2, new_level)))

# ---------- PROGRESS BAR (merge mode) ----------
func _draw() -> void:
	if data["show_menu"] or not data["merge_mode"]:
		return
	var font := ThemeDB.fallback_font
	var n: int = int(data["goal_level"])
	var r := 34.0
	var gap := 14.0
	var total := n * r * 2 + (n - 1) * gap
	var x0 := 540 - total / 2 + r
	var y := 1600.0
	draw_string(font, Vector2(0, 1510), "Goal: " + str(int(pow(2, n))),
		HORIZONTAL_ALIGNMENT_CENTER, 1080, 56, Color(1, 1, 1, 0.85))
	for i in n:
		var lvl := i + 1
		var c := Color.from_hsv(fmod(lvl * 0.13, 1.0), 0.6, 1.0)
		if lvl > best_level:
			c.a = 0.2
		var p := Vector2(x0 + i * (r * 2 + gap), y)
		draw_circle(p, r, c)
		var txt := str(int(pow(2, lvl)))
		var fs := 22 if txt.length() >= 4 else (26 if txt.length() == 3 else 32)
		draw_string(font, p + Vector2(-r, fs * 0.35), txt,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(1, 1, 1, c.a + 0.3))

# ---------- WIN MOMENT ----------
func win(number: int) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(1080, 1920)
	layer.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.6)

	var label := Label.new()
	label.text = str(number) + "!"
	label.add_theme_font_size_override("font_size", 220)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.9))
	label.add_theme_constant_override("outline_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(1080, 300)
	label.position = Vector2(0, 200)
	label.pivot_offset = Vector2(540, 150)
	label.scale = Vector2.ZERO
	layer.add_child(label)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK)
	pop.tween_property(label, "scale", Vector2.ONE, 0.15)

	for pitch in [1.0, 1.26, 1.498, 2.0]:
		var p := AudioStreamPlayer.new()
		p.stream = preload("res://ping.wav")
		p.pitch_scale = pitch
		add_child(p)
		p.play()
		await get_tree().create_timer(0.12).timeout

	if auto_restart:
		await get_tree().create_timer(restart_delay).timeout
		get_tree().reload_current_scene()
