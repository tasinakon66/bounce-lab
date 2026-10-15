extends StaticBody2D

# --- Settings you can change ---
@export var radius: float = 480.0      # how big the circle is
@export var thickness: float = 8.0     # how thick the line looks
@export var color: Color = Color(0.6, 0.55, 1.0)  # purple-ish

func _ready() -> void:
	# Put the circle in the middle of the phone screen (1080 x 1920)
	position = Vector2(540, 960)

	# Build the invisible wall: 64 short straight lines around a circle
	var points := PackedVector2Array()
	var segments := 64
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	var wall := CollisionPolygon2D.new()
	wall.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	wall.polygon = points
	add_child(wall)

func _draw() -> void:
	# Draw the visible ring so we can see it
	draw_arc(Vector2.ZERO, radius, 0, TAU, 128, color, thickness, true)
