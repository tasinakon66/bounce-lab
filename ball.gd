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
var show_number: bool = true             # merge mode: write the number on the ball
var friction: float = 0.0
var pop: float = 1.0                      # >1 while popping in after a merge
var grow_on_hit: float = 0.0              # grow mode: how much bigger per bounce
var max_radius: float = 470.0
var circle_shape: CircleShape2D

var sound_player: AudioStreamPlayer
var cooldown := 0.0   # stops sounds stacking up too fast
var merging := false  # true while this ball is being merged

func _ready() -> void:
	# Number balls get a size and colour based on their level
	if level > 0:
		radius = 28.0 + level * 9.0
		color = Color.from_hsv(fmod(level * 0.13, 1.0), 0.6, 1.0)

	# Make the hitbox match the ball size
	circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	$CollisionShape2D.shape = circle_shape

	# Make it bouncy and slippery
	var mat := PhysicsMaterial.new()
	mat.bounce = bounciness
	mat.friction = friction
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
	var rad := radius * pop
	if picture:
		# The picture spins with the ball
		draw_texture_rect(picture, Rect2(-rad, -rad, rad * 2, rad * 2), false)
	else:
		# Undo the ball's spin so the shine stays in the top-left
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_circle(Vector2.ZERO, rad + 6, Color(color, 0.25))
		draw_circle(Vector2.ZERO, rad, color)
		draw_circle(Vector2(-rad * 0.45, -rad * 0.45), rad * 0.15, Color(1, 1, 1, 0.5))

	# Number in the middle, always upright
	if level > 0 and show_number:
		draw_set_transform(Vector2.ZERO, -rotation)
		var text := str(int(pow(2, level)))
		var font := ThemeDB.fallback_font
		var size := int(rad * 0.8)
		draw_string(font, Vector2(-rad, size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, size, Color.WHITE)

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
	if get_parent().has_method("next_pitch"):
		sound_player.pitch_scale = get_parent().next_pitch()
	elif random_pitch:
		var notes := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]
		sound_player.pitch_scale = notes.pick_random()
	sound_player.play()
