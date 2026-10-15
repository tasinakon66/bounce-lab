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

# Songs: each number is a note, in semitones above/below middle of the sound
# (all public-domain melodies, so no copyright problems)
const MUSIC := {
	"random notes": [],
	"twinkle twinkle": [0,0,7,7,9,9,7, 5,5,4,4,2,2,0, 7,7,5,5,4,4,2, 7,7,5,5,4,4,2],
	"ode to joy": [4,4,5,7,7,5,4,2,0,0,2,4,4,2,2, 4,4,5,7,7,5,4,2,0,0,2,4,2,0,0],
	"fur elise": [4,3,4,3,4,-1,2,0,-3, -12,-8,-3,-1, -8,-4,-1,0, -8,4,3,4,3,4,-1,2,0,-3],
	"happy birthday": [-5,-5,-3,-5,0,-1, -5,-5,-3,-5,2,0, -5,-5,7,4,0,-1,-3, 5,5,4,0,2,0],
}
# Picture packs for merge mode: one emoji per level (Twemoji, CC-BY 4.0)
const PACKS := {
	"fruits": ["1f352","1f353","1f347","1f34a","1f34b","1f34e","1f351","1f34d","1f348","1f349"],
	"faces": ["1f642","1f60a","1f600","1f604","1f606","1f602","1f923","1f60e","1f929","1f973"],
	"space": ["2b50","1f319","1f311","1f315","1f30d","1fa90","2600","1f31f","1f30c","1f320"],
	"animals": ["1f41b","1f41f","1f430","1f431","1f436","1f98a","1f43c","1f981","1f418","1f40b"],
	"numbers": [],
	"my photos": [],
}
const RANDOM_SCALE := [0, 2, 4, 7, 9, 12]
var note_index := 0
static var texture_cache := {}

# Player's choices. "static" means they survive scene restarts.
static var data := {
	"show_menu": true,
	"mode": "bounce",
	"sound": "ping",
	"music": "random notes",
	"picture": null,        # the user's chosen ball picture
	# bounce / shared
	"ball_count": 10,
	"ball_size": 40.0,
	"speed": 900.0,
	"bounciness": 1.0,
	# merge
	"goal_level": 7,        # 7 = 128
	"drop_interval": 0.45,
	"pack": "fruits",
	"level_pics": {},       # my photos: level number -> picture
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

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	scroll.add_child(box)

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
	var music_btn := big_button(box, 90)

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
	add_pack_picker(g)

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
		music_btn.text = "Notes:  " + str(data["music"]).to_upper()
		for m in MODES:
			groups[m].visible = m == data["mode"]
	mode_btn.pressed.connect(func():
		data["mode"] = MODES[(MODES.find(data["mode"]) + 1) % MODES.size()]
		refresh.call())
	sound_btn.pressed.connect(func():
		data["sound"] = SOUNDS[(SOUNDS.find(data["sound"]) + 1) % SOUNDS.size()]
		play_sound(data["sound"], 1.0)   # preview the sound
		refresh.call())
	music_btn.pressed.connect(func():
		var keys := MUSIC.keys()
		data["music"] = keys[(keys.find(data["music"]) + 1) % keys.size()]
		note_index = 0
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

# Merge mode: choose an emoji pack, or a photo for every level
func add_pack_picker(parent: Node) -> void:
	var pack_btn := big_button(parent, 100)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	parent.add_child(rows)
	var preview := HBoxContainer.new()
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(preview)

	# One row per level for "my photos"
	for lvl in range(1, 11):
		var row := HBoxContainer.new()
		var num := Label.new()
		num.text = str(int(pow(2, lvl)))
		num.custom_minimum_size = Vector2(130, 0)
		row.add_child(num)
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(0, 90)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.expand_icon = true
		pick.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.text = "  choose photo..."
		if data["level_pics"].has(lvl):
			pick.icon = data["level_pics"][lvl]
			pick.text = "  change"
		pick.pressed.connect(func():
			open_picture_dialog(func(tex):
				data["level_pics"][lvl] = tex
				pick.icon = tex
				pick.text = "  change"))
		row.add_child(pick)
		rows.add_child(row)

	var refresh := func():
		pack_btn.text = "Pictures:  " + str(data["pack"]).to_upper()
		rows.visible = data["pack"] == "my photos"
		for c in preview.get_children():
			c.queue_free()
		for lvl in range(1, 8):
			var tex = level_texture(lvl)
			if tex:
				var r := TextureRect.new()
				r.texture = tex
				r.custom_minimum_size = Vector2(110, 110)
				r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.add_child(r)
	pack_btn.pressed.connect(func():
		var keys := PACKS.keys()
		data["pack"] = keys[(keys.find(data["pack"]) + 1) % keys.size()]
		refresh.call())
	refresh.call()

# The picture used for a merge level (or null = plain numbered ball)
func level_texture(lvl: int) -> Texture2D:
	if data["pack"] == "my photos":
		return data["level_pics"].get(lvl, null)
	var list: Array = PACKS[data["pack"]]
	if list.is_empty() or lvl > list.size():
		return null
	var path := "res://emoji/%s.png" % list[lvl - 1]
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]

func open_picture_dialog(on_done: Callable) -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path: String):
		var tex := load_round_picture(path)
		if tex:
			on_done.call(tex))
	ui.add_child(dlg)
	dlg.popup_centered_ratio(0.8)

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

# Each bounce asks for the next note: either the next note of the song,
# or a random happy-sounding one
func next_pitch() -> float:
	var song: Array = MUSIC[data["music"]]
	var semitone: int
	if song.is_empty():
		semitone = RANDOM_SCALE.pick_random()
	else:
		semitone = song[note_index % song.size()]
		note_index += 1
	return pow(2.0, semitone / 12.0)

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
# Flask shape: a narrow neck at the top that opens into a big round bulb
const NECK_LEFT := 440.0
const NECK_RIGHT := 640.0
const BULB_CENTER := Vector2(540, 970)
const BULB_RADIUS := 500.0
var stars := []

func flask_points() -> PackedVector2Array:
	var half := (NECK_RIGHT - NECK_LEFT) / 2.0
	var join_y := BULB_CENTER.y - sqrt(BULB_RADIUS * BULB_RADIUS - half * half)
	var a_left := atan2(join_y - BULB_CENTER.y, -half) + TAU    # about 258 degrees
	var a_right := atan2(join_y - BULB_CENTER.y, half)          # about -78 degrees
	var pts := PackedVector2Array([Vector2(NECK_LEFT, -300), Vector2(NECK_LEFT, join_y)])
	var steps := 90
	for i in range(1, steps):
		var a: float = lerp(a_left, a_right, float(i) / steps)
		pts.append(BULB_CENTER + Vector2(cos(a), sin(a)) * BULB_RADIUS)
	pts.append(Vector2(NECK_RIGHT, join_y))
	pts.append(Vector2(NECK_RIGHT, -300))
	return pts

func build_flask() -> void:
	arena.queue_free()
	var body := StaticBody2D.new()
	add_child(body)
	var pts := flask_points()
	for i in pts.size() - 1:
		var seg := SegmentShape2D.new()
		seg.a = pts[i]
		seg.b = pts[i + 1]
		var col := CollisionShape2D.new()
		col.shape = seg
		body.add_child(col)
	# Twinkly background stars
	for i in 140:
		stars.append([Vector2(randf() * 1080, randf() * 1920), randf_range(1.0, 3.0), randf() * TAU])
	# "THEME: ..." title at the bottom, like the Reels
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 84)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.text = "[center][rainbow freq=0.25 sat=0.8 val=1.0]THEME:[/rainbow] %s[/center]" % str(data["pack"]).to_upper()
	title.size = Vector2(1080, 140)
	title.position = Vector2(0, 1530)
	ui.add_child(title)

func run_merge_mode() -> void:
	build_flask()
	while not finished:
		# A steady single-file stream down the neck
		spawn_number_ball(Vector2(540, -80), 1)
		await get_tree().create_timer(data["drop_interval"]).timeout

func _process(_delta: float) -> void:
	if data["mode"] == "merge" and not data["show_menu"]:
		queue_redraw()   # keeps the stars twinkling

# Burst of little sparks where two balls merged
func merge_burst(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 250.0
	p.initial_velocity_max = 600.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func spawn_number_ball(pos: Vector2, lvl: int) -> void:
	var ball := ball_scene.instantiate()
	ball.level = lvl
	ball.start_speed = 0.0
	ball.bounciness = 0.25
	ball.friction = 0.3
	ball.picture = level_texture(lvl)
	ball.show_number = ball.picture == null
	if lvl > 1:
		# Merge juice: pop, sparks, and a note that rises with every level
		ball.pop = 1.35
		var t := ball.create_tween()
		t.tween_property(ball, "pop", 1.0, 0.25).set_trans(Tween.TRANS_BACK)
		merge_burst(pos, Color.from_hsv(fmod(lvl * 0.13, 1.0), 0.5, 1.0))
		var steps := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]
		play_sound(data["sound"], pow(2.0, steps[min(lvl - 2, 9)] / 12.0))
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
	var r := 30.0
	var gap := 12.0
	var total := n * r * 2 + (n - 1) * gap
	var x0 := 540 - total / 2 + r
	# Space background with twinkling stars
	draw_rect(Rect2(0, 0, 1080, 1920), Color(0.02, 0.02, 0.06))
	var t := Time.get_ticks_msec() / 1000.0
	for st in stars:
		draw_circle(st[0], st[1], Color(1, 1, 1, 0.35 + 0.35 * sin(t * 2.0 + st[2])))
	# Neon flask: glow layers, colour fading from gold at the top to cyan at the bottom
	var pts := flask_points()
	for layer in [[26.0, 0.10], [14.0, 0.25], [5.0, 1.0]]:
		for i in pts.size() - 1:
			var k: float = clamp((pts[i].y + 0.0) / 1500.0, 0.0, 1.0)
			var c := Color(1.0, 0.75, 0.25).lerp(Color(0.45, 0.9, 1.0), k)
			if layer[1] == 1.0:
				c = c.lerp(Color.WHITE, 0.35)
			c.a = layer[1]
			draw_line(pts[i], pts[i + 1], c, layer[0], true)
	var y := 1790.0
	draw_string(font, Vector2(0, 1720), "Goal: " + str(int(pow(2, n))),
		HORIZONTAL_ALIGNMENT_CENTER, 1080, 56, Color(1, 1, 1, 0.85))
	for i in n:
		var lvl := i + 1
		var c := Color.from_hsv(fmod(lvl * 0.13, 1.0), 0.6, 1.0)
		if lvl > best_level:
			c.a = 0.2
		var p := Vector2(x0 + i * (r * 2 + gap), y)
		var tex := level_texture(lvl)
		if tex:
			draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false,
				Color(1, 1, 1, 1.0 if lvl <= best_level else 0.25))
			continue
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
