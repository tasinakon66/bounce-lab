extends Node2D
## Shared look and tools for every Reel template:
## space background, neon drawing, hook/theme text, sounds, sparks,
## screen shake, picture packs and the "win" ending.
## Each template extends this file and overrides start(), tick() and draw_scene().

signal done          # the Reel has finished (used for looping and recording)

const CENTER := Vector2(540, 960)
const BALL := preload("res://ball.tscn")
const W := 1080.0
const H := 1920.0

# Emoji packs (Twemoji, CC-BY 4.0) - one picture per level, smallest first
const PACKS := {
	"fruits": ["1f352","1f353","1f347","1f34a","1f34b","1f34e","1f351","1f34d","1f348","1f349"],
	"faces": ["1f642","1f60a","1f600","1f604","1f606","1f602","1f923","1f60e","1f929","1f973"],
	"space": ["2b50","1f319","1f311","1f315","1f30d","1fa90","2600","1f31f","1f30c","1f320"],
	"animals": ["1f41b","1f41f","1f430","1f431","1f436","1f98a","1f43c","1f981","1f418","1f40b"],
	"neon": [],
	"my photos": [],
}
# Glow colour themes (top colour, bottom colour)
const GLOWS := {
	"gold & ice": [Color(1.0, 0.75, 0.25), Color(0.45, 0.9, 1.0)],
	"pink & purple": [Color(1.0, 0.4, 0.75), Color(0.55, 0.4, 1.0)],
	"toxic green": [Color(0.75, 1.0, 0.3), Color(0.2, 1.0, 0.6)],
	"fire": [Color(1.0, 0.85, 0.3), Color(1.0, 0.25, 0.2)],
	"pure white": [Color(1, 1, 1), Color(0.8, 0.85, 1.0)],
}
const BACKGROUNDS := ["space", "black", "grid", "sunset"]

# Rising major scale (semitones) - used so tension builds as things escalate
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24]

static var texture_cache := {}

var cfg := {}            # the player's choices for this template
var ui: CanvasLayer
var cam: Camera2D
var stars := []
var over := false        # true once the ending has started
var time := 0.0
var shake_amount := 0.0
var counter: Label
var neon_top := Color(1.0, 0.75, 0.25)     # gold
var neon_bottom := Color(0.45, 0.9, 1.0)   # cyan

func _ready() -> void:
	randomize()
	cam = Camera2D.new()
	cam.position = CENTER
	add_child(cam)
	cam.make_current()
	ui = CanvasLayer.new()
	add_child(ui)
	for i in 160:
		stars.append([Vector2(randf() * W, randf() * H), randf_range(1.0, 3.2), randf() * TAU])
	var glow: Array = GLOWS.get(str(cfg.get("glow", "gold & ice")), GLOWS["gold & ice"])
	neon_top = glow[0]
	neon_bottom = glow[1]
	build_text()
	start()

# ---------- to override ----------
func start() -> void:
	pass

func tick(_delta: float) -> void:
	pass

func draw_scene() -> void:
	pass

# ---------- frame loop ----------
func _process(delta: float) -> void:
	time += delta
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	shake_amount = move_toward(shake_amount, 0.0, delta * 80.0)
	tick(delta)
	queue_redraw()

func _draw() -> void:
	var bg := str(cfg.get("background", "space"))
	draw_rect(Rect2(-100, -100, W + 200, H + 200), Color(0.015, 0.015, 0.05) if bg != "black" else Color.BLACK)
	match bg:
		"space":
			for s in stars:
				draw_circle(s[0], s[1], Color(1, 1, 1, 0.3 + 0.3 * sin(time * 2.0 + s[2])))
		"grid":
			# slowly scrolling synthwave grid
			var off := fmod(time * 40.0, 90.0)
			for i in range(-1, 23):
				var y := i * 90.0 + off
				draw_line(Vector2(0, y), Vector2(W, y), Color(neon_bottom, 0.10), 2)
			for i in 13:
				draw_line(Vector2(i * 90.0, 0), Vector2(i * 90.0, H), Color(neon_top, 0.10), 2)
		"sunset":
			# vertical gradient made of bands
			for i in 48:
				var k := i / 47.0
				var c := Color(0.12, 0.03, 0.2).lerp(Color(0.55, 0.12, 0.25), k)
				draw_rect(Rect2(0, H * k - 1, W, H / 47.0 + 2), c)
			for s in stars.slice(0, 60):
				draw_circle(s[0] * Vector2(1, 0.5), s[1], Color(1, 1, 1, 0.25 + 0.25 * sin(time * 2.0 + s[2])))
	draw_scene()

# ---------- text: hook at the top, theme at the bottom ----------
func build_text() -> void:
	var hook := RichTextLabel.new()
	hook.bbcode_enabled = true
	hook.fit_content = true
	hook.scroll_active = false
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_theme_font_size_override("normal_font_size", 70)
	hook.add_theme_constant_override("outline_size", 16)
	hook.add_theme_color_override("font_outline_color", Color.BLACK)
	hook.text = "[center][wave amp=18 freq=4]%s[/wave][/center]" % str(cfg.get("hook", ""))
	hook.size = Vector2(W - 80, 260)
	hook.position = Vector2(40, 150)
	ui.add_child(hook)

	# Small watermark: every shared video advertises the app
	if cfg.get("watermark", true):
		var mark := Label.new()
		mark.text = "made with BounceLab"
		mark.add_theme_font_size_override("font_size", 30)
		mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.size = Vector2(W, 50)
		mark.position = Vector2(0, H - 70)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(mark)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("normal_font_size", 80)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	var theme_text := str(cfg.get("title", ""))
	if theme_text != "":
		title.text = "[center][rainbow freq=0.25 sat=0.8 val=1.0]THEME:[/rainbow] %s[/center]" % theme_text.to_upper()
	title.size = Vector2(W, 140)
	title.position = Vector2(0, 1545)
	ui.add_child(title)

	counter = Label.new()
	counter.add_theme_font_size_override("font_size", 64)
	counter.add_theme_constant_override("outline_size", 14)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.size = Vector2(W, 100)
	counter.position = Vector2(0, 1680)
	ui.add_child(counter)

# ---------- neon drawing ----------
func neon_color(y: float) -> Color:
	return neon_top.lerp(neon_bottom, clamp((y - 300.0) / 1300.0, 0.0, 1.0))

func draw_neon_polyline(pts: PackedVector2Array, core: float = 5.0) -> void:
	for layer in [[core * 5.0, 0.10], [core * 2.6, 0.25], [core, 1.0]]:
		for i in pts.size() - 1:
			var c := neon_color(pts[i].y)
			if layer[1] == 1.0:
				c = c.lerp(Color.WHITE, 0.35)
			c.a = layer[1]
			draw_line(pts[i], pts[i + 1], c, layer[0], true)

func arc_points(center: Vector2, r: float, a0: float, a1: float, steps: int = 96) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a: float = lerp(a0, a1, float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

# A solid wall made of short straight pieces along a list of points
func make_wall(pts: PackedVector2Array, parent: Node = self) -> StaticBody2D:
	var body := StaticBody2D.new()
	parent.add_child(body)
	for i in pts.size() - 1:
		var seg := SegmentShape2D.new()
		seg.a = pts[i]
		seg.b = pts[i + 1]
		var col := CollisionShape2D.new()
		col.shape = seg
		body.add_child(col)
	return body

# ---------- sound ----------
func sound_stream() -> AudioStream:
	return load("res://sounds/%s.wav" % str(cfg.get("sound", "ping")))

func play_sound(pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sound_stream()
	p.pitch_scale = pitch
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func scale_pitch(step: int) -> float:
	return pow(2.0, SCALE[clamp(step, 0, SCALE.size() - 1)] / 12.0)

# ---------- effects ----------
func burst(pos: Vector2, color: Color, amount: int = 40, speed: float = 500.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

func flash(strength: float = 0.7) -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, strength)
	f.size = Vector2(W, H)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.5)
	tw.tween_callback(f.queue_free)

# ---------- pictures ----------
func pack_list() -> Array:
	return PACKS.get(str(cfg.get("pack", "neon")), [])

# Picture for item n (1 = smallest). null means "draw a neon ball".
func item_texture(n: int) -> Texture2D:
	if str(cfg.get("pack", "")) == "my photos":
		var photos: Array = cfg.get("photos", [])
		var used := photos.filter(func(p): return str(p) != "")
		if n - 1 < photos.size() and str(photos[n - 1]) != "":
			return load_round_picture(photos[n - 1])
		if used.size() > 0 and cfg.get("cycle_photos", false):
			return load_round_picture(used[(n - 1) % used.size()])
		return null
	var list := pack_list()
	if list.is_empty():
		return null
	var path := "res://emoji/%s.png" % list[(n - 1) % list.size()]
	if not texture_cache.has(path):
		texture_cache[path] = load(path)
	return texture_cache[path]

static func level_color(n: int) -> Color:
	return Color.from_hsv(fmod(0.55 + n * 0.13, 1.0), 0.65, 1.0)

# Loads a photo from disk, crops it to a square and cuts it into a circle
static func load_round_picture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var s := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
	img.resize(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var d := Vector2(x - 127.5, y - 127.5).length()
			if d > 128.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 122.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))   # thin white rim
	var tex := ImageTexture.create_from_image(img)
	texture_cache[path] = tex
	return tex

# A ball with the player's sound and skin
func make_ball(pos: Vector2, r: float, velocity: Vector2, n: int = 1) -> RigidBody2D:
	var b := BALL.instantiate()
	b.position = pos
	b.radius = r
	b.start_velocity = velocity
	b.bounce_sound = sound_stream()
	b.picture = item_texture(n)
	b.color = level_color(n)
	return b

# ---------- the ending ----------
func finish(text: String, picture: Texture2D = null) -> void:
	if over:
		return
	over = true
	# the final picture, huge, spinning in (merge: the top level)
	if picture:
		var big := TextureRect.new()
		big.texture = picture
		big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		big.size = Vector2(420, 420)
		big.position = Vector2(W / 2 - 210, 380)
		big.pivot_offset = Vector2(210, 210)
		big.scale = Vector2.ZERO
		ui.add_child(big)
		var tw := create_tween()
		tw.set_parallel()
		tw.tween_property(big, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
		tw.tween_property(big, "rotation", TAU, 0.45)
	var outro := str(cfg.get("outro", ""))
	if outro != "":
		var o := Label.new()
		o.text = outro
		o.add_theme_font_size_override("font_size", 60)
		o.add_theme_constant_override("outline_size", 12)
		o.add_theme_color_override("font_outline_color", Color.BLACK)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.size = Vector2(W, 100)
		o.position = Vector2(0, 1090)
		o.modulate.a = 0.0
		ui.add_child(o)
		var fade := create_tween()
		fade.tween_interval(0.6)
		fade.tween_property(o, "modulate:a", 1.0, 0.3)
	flash(0.8)
	shake(25.0)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(min(170.0, 1700.0 / max(1, text.length()))))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.45, 0.3, 0.95))
	label.add_theme_constant_override("outline_size", 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(W, 260)
	label.position = Vector2(0, 820)
	label.pivot_offset = Vector2(W / 2, 130)
	label.scale = Vector2.ZERO
	ui.add_child(label)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK)
	pop.tween_property(label, "scale", Vector2.ONE, 0.15)
	for i in 4:
		play_sound(pow(2.0, [0, 4, 7, 12][i] / 12.0))
		burst(Vector2(randf_range(200, 880), randf_range(500, 1300)), level_color(i * 2), 60, 700)
		await get_tree().create_timer(0.13).timeout
	await get_tree().create_timer(3.0).timeout
	done.emit()
