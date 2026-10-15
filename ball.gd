extends RigidBody2D

# --- Settings you can change ---
@export var start_speed: float = 900.0   # how fast it starts flying
@export var bounciness: float = 1.0      # 1 = never loses energy
@export var radius: float = 40.0         # ball size
@export var color: Color = Color.WHITE   # ball colour
@export var level: int = 0               # 0 = normal ball, 1 = "2", 2 = "4", 3 = "8"...
@export var bounce_sound: AudioStream = preload("res://ping.wav")
@export var random_pitch: bool = true     # different note each bounce
var picture: Texture2D = null             # user's photo/emoji (optional)
var grow_on_hit: float = 0.0              # grow mode: how much bigger per bounce
var max_radius: float = 470.0
var circle_shape: CircleShape2D

var sound_player: AudioStreamPlayer
var cooldown := 0.0   # stops sounds stacking up too fast
var merging := false  # true while this ball is being merged

func _ready() -> void:
	# Number balls get a size and colour based on their level
	if level > 0:
		radius = 30.0 + level * 8.0
		color = Color.from_hsv(fmod(level * 0.13, 1.0), 0.6, 1.0)

	# Make the hitbox match the ball size
	circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	$CollisionShape2D.shape = circle_shape

	# Make it bouncy and slippery
	var mat := PhysicsMaterial.new()
	mat.bounce = bounciness
	mat.friction = 0.0
	physics_material_override = mat

	# Turn off air resistance so it never slows down
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0

	# Stop it passing through the wall when moving fast
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	# Let the ball "notice" when it touches something
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_hit)

	# Create the sound player
	sound_player = AudioStreamPlayer.new()
	sound_player.stream = bounce_sound
	add_child(sound_player)

	# Throw it in a random direction at the start
	var angle := randf_range(0.0, TAU)
	linear_velocity = Vector2(cos(angle), sin(angle)) * start_speed

func _draw() -> void:
	# If the user picked a picture, draw that instead (it spins with the ball)
	if picture:
		draw_circle(Vector2.ZERO, radius + 6, Color(1, 1, 1, 0.25))
		draw_texture_rect(picture, Rect2(-radius, -radius, radius * 2, radius * 2), false)
		return

	# Undo the ball's spin, so everything below stays upright
	draw_set_transform(Vector2.ZERO, -rotation)

	# Soft glow, then the solid ball, then a small shine
	draw_circle(Vector2.ZERO, radius + 6, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.45, -radius * 0.45), radius * 0.15, Color(1, 1, 1, 0.5))

	# Write the number in the middle
	if level > 0:
		var text := str(int(pow(2, level)))
		var font := ThemeDB.fallback_font
		var size := int(radius * 0.8)
		draw_string(font, Vector2(-radius, size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, size, Color.WHITE)

func _process(delta: float) -> void:
	cooldown -= delta
	queue_redraw()   # redraw every frame so the number stays upright

func _physics_process(_delta: float) -> void:
	# Keep checking balls we're resting against, not just new hits
	if level > 0 and not merging:
		for body in get_colliding_bodies():
			try_merge(body)

func try_merge(body: Node) -> void:
	# Merge check: same number, and neither ball is already merging
	if merging or level <= 0:
		return
	if body is RigidBody2D and "level" in body:
		var other = body
		if other.level == level and not other.merging:
			# Only one of the two balls should do the merge
			if get_instance_id() < other.get_instance_id():
				merging = true
				other.merging = true
				get_parent().merge_balls(self, other)

func _on_hit(body: Node) -> void:
	try_merge(body)

	# Grow mode: get bigger every bounce
	if grow_on_hit > 0.0 and radius < max_radius:
		radius = min(radius + grow_on_hit, max_radius)
		circle_shape.set_deferred("radius", radius)
		if radius >= max_radius:
			get_parent().win("FULL!")

	# Bounce sound
	if cooldown > 0.0:
		return
	cooldown = 0.05
	if random_pitch:
		var notes := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]
		sound_player.pitch_scale = notes.pick_random()
	sound_player.play()
