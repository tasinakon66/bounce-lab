extends StaticBody2D

# --- Settings you can change ---
@export var radius: float = 480.0      # how big the circle is
@export var thickness: float = 8.0     # how thick the line looks
@export var color: Color = Color(0.6, 0.55, 1.0)  # purple-ish
@export var gap_degrees: float = 0.0   # size of the opening (0 = closed circle)
@export var spin_speed: float = 0.0    # how fast the ring turns (degrees per second)

const SEGMENTS := 96

func _ready() -> void:
	position = Vector2(540, 960)
	build()

# (Re)build the wall out of short straight pieces, skipping the gap
func build() -> void:
	for c in get_children():
		c.queue_free()
	var gap := deg_to_rad(gap_degrees)
	for i in SEGMENTS:
		var a1 := TAU * i / SEGMENTS
		var a2 := TAU * (i + 1) / SEGMENTS
		if gap > 0.0 and (a1 < gap / 2.0 or a2 > TAU - gap / 2.0):
			continue   # this piece is part of the opening
		var seg := SegmentShape2D.new()
		seg.a = Vector2(cos(a1), sin(a1)) * radius
		seg.b = Vector2(cos(a2), sin(a2)) * radius
		var col := CollisionShape2D.new()
		col.shape = seg
		add_child(col)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if spin_speed != 0.0:
		rotation += deg_to_rad(spin_speed) * delta

func _draw() -> void:
	var gap := deg_to_rad(gap_degrees)
	draw_arc(Vector2.ZERO, radius, gap / 2.0, TAU - gap / 2.0, 160, color, thickness, true)
