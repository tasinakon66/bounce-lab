extends Node2D

@export var ball_scene: PackedScene = preload("res://ball.tscn")
@export var auto_restart: bool = true    # start again after winning
@export var restart_delay: float = 4.0   # seconds before restarting

const CENTER := Vector2(540, 960)
const MODES := ["bounce", "merge", "escape", "grow"]
const MODE_NAMES := {
	"bounce": "BOUNCE",
	"merge": "MERGE  (2, 4, 8...)",
	"escape": "ESCAPE THE RING",
	"grow": "GROW TILL FULL",
}
const SOUNDS := ["ping", "piano", "marimba", "bell", "pop", "retro"]

# Player's choices. "static" means they survive scene restarts.
static var data := {
	"show_menu": true,
	"mode": "bounce",
	"sound": "ping",
	"picture": null,        # the user's chosen ball picture
	# bounce / shared
	"ball_count": 10,
	"ball_size": 40.0,
	"speed": 900.0,
	"bounciness": 1.0,
	# merge
	"goal_level": 7,        # 7 = 128
	"drop_interval": 0.8,
	# escape
	"gap": 50.0,
	"spin": 60.0,
	"max_balls": 150,
	# grow
	"growth": 4.0,
}

var finished := false
var best_level := 0
var ui: CanvasLayer
var counter: Label
@onready var arena = $Arena

func _ready() -> void:
	randomize()
	ui = CanvasLayer.new()
	add_child(ui)
	# Testing shortcut: run with "-- --mode=merge" to skip the menu
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			data["mode"] = arg.substr(7)
			data["show_menu"] = false
	if data["show_menu"]:
		build_menu()
	else:
		start_game()

# ================= MENU =================
func build_menu() -> void:
	var theme := Theme.new()
	theme.default_font_size = 44

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = theme
	ui.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 120)
	bg.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
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
	box.add_child(spacer(20))

	var mode_btn := big_button(box, 110)
	var sound_btn := big_button(box, 90)

	# One settings group per mode (only the chosen one is visible)
	var groups := {}
	for m in MODES:
		var g := VBoxContainer.new()
		g.add_theme_constant_override("separation", 6)
		box.add_child(g)
		groups[m] = g

	var g = groups["bounce"]
	add_slider(g, "Balls", "ball_count", 1, 50, 1, "int")
	add_slider(g, "Ball size", "ball_size", 15, 80, 1, "int")
	add_slider(g, "Speed", "speed", 200, 2000, 50, "int")
	add_slider(g, "Bounciness", "bounciness", 0.5, 1.0, 0.05, "percent")
	add_picture_buttons(g)

	g = groups["merge"]
	add_slider(g, "Goal", "goal_level", 3, 10, 1, "power")
	add_slider(g, "Drop every", "drop_interval", 0.2, 2.0, 0.1, "seconds")

	g = groups["escape"]
	add_slider(g, "Gap size", "gap", 20, 120, 5, "degrees")
	add_slider(g, "Ring spin", "spin", 0, 180, 5, "int")
	add_slider(g, "Ball size", "ball_size", 15, 80, 1, "int")
	add_slider(g, "Speed", "speed", 200, 2000, 50, "int")
	add_slider(g, "Max balls", "max_balls", 20, 400, 10, "int")
	add_picture_buttons(g)

	g = groups["grow"]
	add_slider(g, "Start size", "ball_size", 15, 80, 1, "int")
	add_slider(g, "Growth per bounce", "growth", 1, 15, 0.5, "float")
	add_slider(g, "Speed", "speed", 200, 2000, 50, "int")
	add_picture_buttons(g)

	var refresh := func():
		mode_btn.text = "Mode:  " + MODE_NAMES[data["mode"]]
		sound_btn.text = "Sound:  " + str(data["sound"]).to_upper()
		for m in MODES:
			groups[m].visible = m == data["mode"]
	mode_btn.pressed.connect(func():
		data["mode"] = MODES[(MODES.find(data["mode"]) + 1) % MODES.size()]
		refresh.call())
	sound_btn.pressed.connect(func():
		data["sound"] = SOUNDS[(SOUNDS.find(data["sound"]) + 1) % SOUNDS.size()]
		play_sound(data["sound"], 1.0)   # preview the sound
		refresh.call())
	refresh.call()

	box.add_child(spacer(30))
	var start := big_button(box, 150)
	start.text = "START"
	start.add_theme_font_size_override("font_size", 70)
	start.pressed.connect(func():
		data["show_menu"] = false
		bg.queue_free()
		start_game())

func big_button(parent: Node, height: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	parent.add_child(b)
	return b

func add_slider(parent: Node, title: String, key: String, min_v: float, max_v: float,
		step: float, kind: String) -> void:
	var label := Label.new()
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = data[key]
	slider.custom_minimum_size = Vector2(0, 60)
	label.text = title + ":  " + format_value(data[key], kind)
	slider.value_changed.connect(func(v):
		data[key] = v
		label.text = title + ":  " + format_value(v, kind))
	parent.add_child(label)
	parent.add_child(slider)

func add_picture_buttons(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(spacer(10))
	parent.add_child(row)
	var pick := Button.new()
	pick.custom_minimum_size = Vector2(0, 100)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pick)
	var clear := Button.new()
	clear.text = "Remove"
	clear.custom_minimum_size = Vector2(220, 100)
	row.add_child(clear)

	var refresh := func():
		pick.text = "Picture: " + ("CHOSEN (change)" if data["picture"] else "choose image...")
		clear.disabled = data["picture"] == null
	refresh.call()
	# keep every copy of these buttons in sync
	pick.visibility_changed.connect(refresh)

	clear.pressed.connect(func():
		data["picture"] = null
		refresh.call())

	pick.pressed.connect(func():
		var dlg := FileDialog.new()
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
		dlg.use_native_dialog = true
		dlg.file_selected.connect(func(path: String):
			var tex := load_round_picture(path)
			if tex:
				data["picture"] = tex
			refresh.call())
		ui.add_child(dlg)
		dlg.popup_centered_ratio(0.8))

# Loads an image, crops it to a square, and cuts it into a circle
func load_round_picture(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var s := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
	img.resize(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			if Vector2(x - 127.5, y - 127.5).length() > 128.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func format_value(v: float, kind: String) -> String:
	match kind:
		"percent": return "%d%%" % int(round(v * 100))
		"power": return str(int(pow(2, v)))
		"seconds": return "%.1fs" % v
		"degrees": return "%d°" % int(v)
		"float": return "%.1f" % v
	return str(int(v))

func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func play_sound(sound_name: String, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://sounds/%s.wav" % sound_name)
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ================= GAME =================
func start_game() -> void:
	var back := Button.new()
	back.text = "< Menu"
	back.position = Vector2(30, 30)
	back.add_theme_font_size_override("font_size", 44)
	back.pressed.connect(func():
		data["show_menu"] = true
		get_tree().reload_current_scene())
	ui.add_child(back)

	queue_redraw()
	match data["mode"]:
		"merge": run_merge_mode()
		"escape": run_escape_mode()
		"grow": run_grow_mode()
		_: run_bounce_mode()

# Creates a ball with the player's sound, picture, size and speed
func make_ball(pos: Vector2) -> RigidBody2D:
	var ball := ball_scene.instantiate()
	ball.radius = data["ball_size"]
	ball.start_speed = data["speed"]
	ball.bounciness = data["bounciness"]
	ball.bounce_sound = load("res://sounds/%s.wav" % data["sound"])
	ball.position = pos
	if data["picture"]:
		ball.picture = data["picture"]
	else:
		ball.modulate = Color.from_hsv(randf(), 0.6, 1.0)
	ball.add_to_group("balls")
	return ball

# ---------- BOUNCE MODE ----------
func run_bounce_mode() -> void:
	var delay: float = clamp(4.0 / float(data["ball_count"]), 0.05, 0.4)
	for i in int(data["ball_count"]):
		add_child(make_ball(CENTER + Vector2(randf_range(-150, 150), randf_range(-150, 150))))
		await get_tree().create_timer(delay).timeout

# ---------- ESCAPE MODE ----------
# A spinning ring with a gap. Every ball that escapes becomes 2 new balls.
func run_escape_mode() -> void:
	arena.gap_degrees = data["gap"]
	arena.spin_speed = data["spin"]
	arena.build()
	counter = Label.new()
	counter.add_theme_font_size_override("font_size", 80)
	counter.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.9))
	counter.add_theme_constant_override("outline_size", 16)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.size = Vector2(1080, 120)
	counter.position = Vector2(0, 260)
	ui.add_child(counter)
	add_child(make_ball(CENTER))
	update_counter()

func update_counter() -> void:
	if counter:
		counter.text = "Balls: %d" % get_tree().get_nodes_in_group("balls").size()

func _physics_process(_delta: float) -> void:
	if data["mode"] != "escape" or finished or data["show_menu"]:
		return
	for ball in get_tree().get_nodes_in_group("balls"):
		if ball.is_queued_for_deletion():
			continue
		if ball.position.distance_to(CENTER) > arena.radius + ball.radius + 20:
			ball.remove_from_group("balls")
			ball.queue_free()
			play_sound(data["sound"], 2.0)
			for i in 2:
				if get_tree().get_nodes_in_group("balls").size() < int(data["max_balls"]):
					add_child(make_ball(CENTER))
	update_counter()
	if get_tree().get_nodes_in_group("balls").size() >= int(data["max_balls"]):
		finished = true
		arena.spin_speed = 0.0
		win(str(int(data["max_balls"])) + "!")

# ---------- GROW MODE ----------
# One ball that gets bigger every bounce until it fills the circle
func run_grow_mode() -> void:
	var ball := make_ball(CENTER)
	ball.grow_on_hit = data["growth"]
	ball.max_radius = arena.radius - 8
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
	ball.bounce_sound = load("res://sounds/%s.wav" % data["sound"])
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
		win(str(int(pow(2, new_level))) + "!")

# Progress bar under the circle (merge mode)
func _draw() -> void:
	if data["show_menu"] or data["mode"] != "merge":
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
func win(text: String) -> void:
	if finished and data["mode"] == "grow":
		return
	finished = true
	var layer := CanvasLayer.new()
	add_child(layer)

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(1080, 1920)
	layer.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.6)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 200)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.9))
	label.add_theme_constant_override("outline_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(1080, 300)
	label.position = Vector2(0, 160)
	label.pivot_offset = Vector2(540, 150)
	label.scale = Vector2.ZERO
	layer.add_child(label)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK)
	pop.tween_property(label, "scale", Vector2.ONE, 0.15)

	for pitch in [1.0, 1.26, 1.498, 2.0]:
		play_sound(data["sound"], pitch)
		await get_tree().create_timer(0.12).timeout

	if auto_restart:
		await get_tree().create_timer(restart_delay).timeout
		get_tree().reload_current_scene()
