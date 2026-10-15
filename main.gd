extends Node2D
## BounceLab app shell: template gallery -> editor -> preview / record.
## The Reels themselves live in res://templates/ (one file per template).

const TEMPLATES := ["merge_flask", "friend_battle", "marble_race", "grow_spikes", "fill_circle", "escape_rings", "melody_bounce"]
const SOUNDS := ["ping", "piano", "marimba", "bell", "pop", "retro"]
const SETTINGS_FILE := "user://settings.json"
const RECORD_FILE := "user://record.json"
const OVERRIDE_FILE := "res://override.cfg"   # makes the recorder window 1080x1920
const BASE := preload("res://templates/base_template.gd")

const ACCENT := Color(0.62, 0.52, 1.0)
const ACCENT_2 := Color(0.45, 0.9, 1.0)
const BG := Color(0.035, 0.035, 0.08)
const CARD := Color(0.09, 0.08, 0.16)

var per := {}            # template id -> that template's settings (cfg)
var current := "merge_flask"
var screen: Control      # the menu screen currently shown
var layer: CanvasLayer
var playing: Node2D      # the running template (preview)
var recording := false
var theme_ui: Theme

func _ready() -> void:
	randomize()
	theme_ui = make_theme()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	load_settings()
	# The recorder's size override is only needed at start-up, so remove it now
	# (also cleans up if a recording was interrupted)
	if FileAccess.file_exists(OVERRIDE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE_FILE))
	var args := OS.get_cmdline_user_args()
	if "--record" in args:
		start_recording_run()
		return
	# Testing shortcut: "-- --play=grow_spikes" skips the menus
	for a in args:
		if a.begins_with("--play="):
			current = a.substr(7)
			start_preview()
			return
		if a.begins_with("--edit="):
			current = a.substr(7)
			show_editor()
			return
	show_home()

# On a computer, show a phone-shaped window that fits the screen.
# (The recorder skips this so it can render a full 1080x1920 video.)
func fit_window() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	var scr := DisplayServer.screen_get_usable_rect()
	var h := int(scr.size.y * 0.9)
	var w := int(h * 9.0 / 16.0)
	get_window().size = Vector2i(w, h)
	get_window().position = scr.position + (scr.size - Vector2i(w, h)) / 2

# ================= settings =================
static func template_script(id: String) -> Script:
	return load("res://templates/%s.gd" % id)

func cfg_for(id: String) -> Dictionary:
	var m: Dictionary = template_script(id).meta()
	var c: Dictionary = per.get(id, {})
	# fill in anything missing (new settings added in later versions)
	for k in m.defaults:
		if not c.has(k):
			c[k] = m.defaults[k]
	var extra := {"hook": m.hook, "title": m.title, "pack": m.pack, "sound": "ping",
		"outro": "Follow for part 2!", "glow": "gold & ice", "background": "space", "watermark": true,
		"song": "twinkle twinkle", "photos": ["", "", "", "", "", "", "", "", "", ""]}
	for k in extra:
		if not c.has(k):
			c[k] = extra[k]
	per[id] = c
	return c

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_FILE))
		if parsed is Dictionary:
			per = parsed.get("per", {})
			current = str(parsed.get("current", current))
	if not current in TEMPLATES:
		current = TEMPLATES[0]

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"per": per, "current": current}))

# ================= look =================
func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 44
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD
	normal.set_corner_radius_all(30)
	normal.border_color = Color(ACCENT, 0.45)
	normal.set_border_width_all(2)
	normal.content_margin_left = 30
	normal.content_margin_right = 30
	normal.content_margin_top = 18
	normal.content_margin_bottom = 18
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = ACCENT_2
	hover.bg_color = CARD.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(ACCENT, 0.35)
	for s in ["normal", "focus"]:
		t.set_stylebox(s, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_constant("icon_max_width", "Button", 150)
	t.set_constant("h_separation", "Button", 28)
	var line: StyleBoxFlat = normal.duplicate()
	line.bg_color = Color(0, 0, 0, 0.35)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", hover)
	return t

func new_screen() -> VBoxContainer:
	if screen:
		screen.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = theme_ui
	layer.add_child(bg)
	screen = bg
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 60)
	bg.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 24)
	scroll.add_child(box)
	return box

func label(parent: Node, text: String, size: int = 44, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func button(parent: Node, text: String, height: float = 110) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	parent.add_child(b)
	return b

func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func emoji(code: String) -> Texture2D:
	return load("res://emoji/%s.png" % code)

# ================= HOME: template gallery =================
func show_home() -> void:
	stop_preview()
	var box := new_screen()
	label(box, "BounceLab", 130, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	label(box, "Viral physics Reels in one tap", 46, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(spacer(30))
	label(box, "CHOOSE A TEMPLATE", 34, ACCENT_2)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	box.add_child(grid)
	for id in TEMPLATES:
		var m: Dictionary = template_script(id).meta()
		var card := Button.new()
		card.text = m.name
		card.custom_minimum_size = Vector2(0, 560)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var thumb_path := "res://thumbs/%s.png" % id
		card.icon = load(thumb_path) if ResourceLoader.exists(thumb_path) else emoji(m.icon)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.add_theme_constant_override("icon_max_width", 400)
		card.add_theme_font_size_override("font_size", 40)
		card.tooltip_text = m.tagline
		card.pressed.connect(func():
			current = id
			show_editor())
		grid.add_child(card)
	box.add_child(spacer(20))
	label(box, "Emoji art: Twemoji (CC-BY 4.0)", 26, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER)

# ================= EDITOR: customise the Reel =================
func show_editor() -> void:
	stop_preview()
	var m: Dictionary = template_script(current).meta()
	var c := cfg_for(current)
	var box := new_screen()

	var back := button(box, "<  Templates", 90)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_home)
	label(box, m.name, 90, ACCENT)
	label(box, m.tagline, 38, Color(1, 1, 1, 0.6))

	section(box, "TEXT")
	text_field(box, "Hook (top of the video)", c, "hook")
	text_field(box, "Theme (bottom - leave empty to hide)", c, "title")
	text_field(box, "Ending message (shown when it finishes)", c, "outro")
	if m.get("names", false):
		text_field(box, "Fighter names, in order, separated by commas", c, "names")

	section(box, "LOOK & SOUND")
	pack_picker(box, c)
	var sound_btn := button(box, "", 100)
	var set_sound := func(): sound_btn.text = "Sound:  " + str(c.sound).to_upper()
	set_sound.call()
	sound_btn.pressed.connect(func():
		c.sound = SOUNDS[(SOUNDS.find(c.sound) + 1) % SOUNDS.size()]
		set_sound.call()
		preview_sound(c.sound))
	cycle_button(box, "Glow", c, "glow", BASE.GLOWS.keys())
	cycle_button(box, "Background", c, "background", BASE.BACKGROUNDS)
	var wm := CheckButton.new()
	wm.text = "  'made with BounceLab' watermark"
	wm.button_pressed = bool(c.watermark)
	wm.toggled.connect(func(on): c.watermark = on)
	box.add_child(wm)
	if m.get("songs", false):
		var songs: Array = template_script(current).SONGS.keys()
		var song_btn := button(box, "", 100)
		var set_song := func(): song_btn.text = "Song:  " + str(c.song).to_upper()
		set_song.call()
		song_btn.pressed.connect(func():
			c.song = songs[(songs.find(c.song) + 1) % songs.size()]
			set_song.call())

	section(box, "PHYSICS")
	for s in m.sliders:
		slider(box, s[0], c, s[1], s[2], s[3], s[4], s[5])

	box.add_child(spacer(20))
	var play := button(box, "PREVIEW", 150)
	play.add_theme_font_size_override("font_size", 60)
	play.pressed.connect(func():
		save_settings()
		start_preview())
	var rec := button(box, "RECORD VIDEO", 130)
	rec.add_theme_color_override("font_color", Color(1, 0.55, 0.6))
	var info := label(box, "", 32, Color(1, 1, 1, 0.6))
	rec.pressed.connect(func():
		save_settings()
		info.text = record_video())
	box.add_child(spacer(60))

func cycle_button(parent: Node, title: String, c: Dictionary, key: String, options: Array) -> void:
	var b := button(parent, "", 100)
	var show := func(): b.text = title + ":  " + str(c[key]).to_upper()
	show.call()
	b.pressed.connect(func():
		var i := options.find(c[key])
		c[key] = options[(i + 1) % options.size()]
		show.call())

func section(parent: Node, text: String) -> void:
	parent.add_child(spacer(10))
	label(parent, text, 32, ACCENT_2)

func text_field(parent: Node, title: String, c: Dictionary, key: String) -> void:
	label(parent, title, 34, Color(1, 1, 1, 0.7))
	var e := LineEdit.new()
	e.text = str(c.get(key, ""))
	e.custom_minimum_size = Vector2(0, 100)
	e.text_changed.connect(func(t): c[key] = t)
	parent.add_child(e)

func slider(parent: Node, title: String, c: Dictionary, key: String,
		lo: float, hi: float, step: float, kind: String) -> void:
	var l := label(parent, "", 38)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(c.get(key, lo))
	s.custom_minimum_size = Vector2(0, 64)
	l.text = title + ":  " + fmt(s.value, kind)
	s.value_changed.connect(func(v):
		c[key] = v
		l.text = title + ":  " + fmt(v, kind))
	parent.add_child(s)

static func fmt(v: float, kind: String) -> String:
	match kind:
		"percent": return "%d%%" % int(round(v * 100))
		"percent_int": return "%d%%" % int(v)
		"level": return "level %d  (= %d)" % [int(v), int(pow(2, v))]
		"seconds": return "%.2fs" % v
		"degrees": return "%d deg" % int(v)
		"float": return "%.1f" % v
	return str(int(v))

func pack_picker(parent: Node, c: Dictionary) -> void:
	var packs: Array = BASE.PACKS.keys()
	var btn := button(parent, "", 100)
	var preview := HBoxContainer.new()
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(preview)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	parent.add_child(rows)
	label(rows, "Pick a photo for each level, smallest first. Mum, dad, your cat... anything.", 32, Color(1, 1, 1, 0.6))
	for i in 10:
		var pick := button(rows, "", 96)
		pick.expand_icon = true
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var refresh_row := func():
			var path := str(c.photos[i])
			pick.text = "%d.   %s" % [i + 1, path.get_file() if path != "" else "choose photo..."]
			pick.icon = BASE.load_round_picture(path) if path != "" else null
		refresh_row.call()
		pick.pressed.connect(func():
			pick_photo(func(path):
				c.photos[i] = path
				refresh_row.call()))

	var refresh := func():
		btn.text = "Pictures:  " + str(c.pack).to_upper()
		rows.visible = c.pack == "my photos"
		for child in preview.get_children():
			child.queue_free()
		var list: Array = BASE.PACKS[c.pack]
		for code in list.slice(0, 8):
			var r := TextureRect.new()
			r.texture = emoji(code)
			r.custom_minimum_size = Vector2(100, 100)
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.add_child(r)
		preview.visible = not list.is_empty()
	btn.pressed.connect(func():
		c.pack = packs[(packs.find(c.pack) + 1) % packs.size()]
		refresh.call())
	refresh.call()

func pick_photo(on_done: Callable) -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path: String): on_done.call(path))
	layer.add_child(dlg)
	dlg.popup_centered_ratio(0.8)

func preview_sound(sound_name: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://sounds/%s.wav" % sound_name)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ================= PREVIEW =================
func start_preview() -> void:
	if screen:
		screen.queue_free()
		screen = null
	spawn_template(cfg_for(current))
	if recording:
		return
	var back := Button.new()
	back.text = "<  Edit"
	back.theme = theme_ui
	back.position = Vector2(30, 30)
	back.custom_minimum_size = Vector2(220, 90)
	back.pressed.connect(show_editor)
	back.name = "BackButton"
	layer.add_child(back)

func spawn_template(c: Dictionary) -> void:
	if playing:
		playing.queue_free()
	playing = template_script(current).new()
	playing.cfg = c
	playing.done.connect(_on_template_done)
	add_child(playing)

func _on_template_done() -> void:
	if recording:
		get_tree().quit()          # closing saves the video
	else:
		spawn_template(cfg_for(current))   # loop forever, like a Reel

func stop_preview() -> void:
	if playing:
		playing.queue_free()
		playing = null
	var back := layer.get_node_or_null("BackButton")
	if back:
		back.queue_free()

# ================= RECORDING =================
# Starts a second copy of the app with Godot's Movie Maker switched on.
# It plays the Reel once at 1080x1920 / 60fps, then closes itself and the
# video (with sound) is saved in Videos/BounceLab.
func record_video() -> String:
	var f := FileAccess.open(RECORD_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"template": current, "cfg": cfg_for(current)}))
	f.close()
	var videos := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
	if videos == "":
		videos = OS.get_user_data_dir()
	var dir := videos.path_join("BounceLab")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var out := dir.path_join("%s_%s.avi" % [current, stamp])
	# The preview window is phone-sized (405x720). For the video we want full
	# 1080x1920, so the recorder starts with a temporary settings override.
	var o := FileAccess.open(OVERRIDE_FILE, FileAccess.WRITE)
	if o:
		o.store_string("[display]\n\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\n")
		o.close()
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--write-movie", out, "--position", "0,0", "--", "--record"])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		return "Could not start the recorder."
	return "Recording in a new window. It closes by itself when the Reel ends.\nSaved to: " + out

func start_recording_run() -> void:
	recording = true
	if FileAccess.file_exists(RECORD_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECORD_FILE))
		if parsed is Dictionary:
			current = str(parsed.get("template", current))
			per[current] = parsed.get("cfg", {})
	start_preview()
