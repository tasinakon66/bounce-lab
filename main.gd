extends Node2D

# --- Settings you can change ---
@export var ball_scene: PackedScene = preload("res://ball.tscn")
@export var merge_mode: bool = false     # off = bounce mode, on = merge mode

@export_group("Bounce Mode")
@export var ball_count: int = 5          # how many balls
@export var spawn_delay: float = 0.4     # seconds between each ball

@export_group("Merge Mode")
@export var goal_level: int = 7          # 7 = 128 (2^7)
@export var drop_interval: float = 0.8   # seconds between each new "2"
@export var auto_restart: bool = true    # start again after winning
@export var restart_delay: float = 4.0   # seconds before restarting

var finished := false

func _ready() -> void:
	randomize()
	if merge_mode:
		run_merge_mode()
	else:
		run_bounce_mode()

# ---------- BOUNCE MODE ----------
func run_bounce_mode() -> void:
	for i in ball_count:
		spawn_ball()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_ball() -> void:
	var ball := ball_scene.instantiate()
	ball.position = Vector2(540, 960) + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	ball.modulate = Color.from_hsv(randf(), 0.6, 1.0)
	add_child(ball)

# ---------- MERGE MODE ----------
func run_merge_mode() -> void:
	while not finished:
		var pos := Vector2(540 + randf_range(-200, 200), 650)
		spawn_number_ball(pos, 1)
		await get_tree().create_timer(drop_interval).timeout

func spawn_number_ball(pos: Vector2, lvl: int) -> void:
	var ball := ball_scene.instantiate()
	ball.level = lvl
	ball.start_speed = 150.0
	ball.bounciness = 0.4
	ball.position = pos
	add_child(ball)

func merge_balls(a: Node2D, b: Node2D) -> void:
	var pos := (a.position + b.position) / 2.0
	var new_level: int = a.level + 1
	a.queue_free()
	b.queue_free()
	# Wait for physics to finish this frame before adding the new ball
	call_deferred("spawn_number_ball", pos, new_level)
	if new_level >= goal_level and not finished:
		finished = true
		win(int(pow(2, new_level)))

# ---------- WIN MOMENT ----------
func win(number: int) -> void:
	# A layer that sits on top of everything
	var layer := CanvasLayer.new()
	add_child(layer)

	# 1. White flash that fades out
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(1080, 1920)
	layer.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.6)

	# 2. Big number that pops in
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

	# 3. "Ta-da" chord: three notes played one after another
	for pitch in [1.0, 1.26, 1.498, 2.0]:
		var p := AudioStreamPlayer.new()
		p.stream = preload("res://ping.wav")
		p.pitch_scale = pitch
		add_child(p)
		p.play()
		await get_tree().create_timer(0.12).timeout

	# 4. Restart after a few seconds
	if auto_restart:
		await get_tree().create_timer(restart_delay).timeout
		get_tree().reload_current_scene()
