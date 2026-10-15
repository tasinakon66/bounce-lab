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
	if new_level >= goal_level:
		finished = true
		print("Reached ", int(pow(2, new_level)), "!")
