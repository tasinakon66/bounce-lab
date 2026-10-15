extends Node2D

# --- Settings you can change ---
@export var ball_scene: PackedScene = preload("res://ball.tscn")
@export var ball_count: int = 5          # how many balls
@export var spawn_delay: float = 0.4     # seconds between each ball

func _ready() -> void:
	randomize()
	for i in ball_count:
		spawn_ball()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_ball() -> void:
	var ball := ball_scene.instantiate()
	# Start near the centre, with a small random offset
	ball.position = Vector2(540, 960) + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	# Random colour tint for each ball
	ball.modulate = Color.from_hsv(randf(), 0.6, 1.0)
	add_child(ball)
