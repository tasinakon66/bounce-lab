extends RigidBody2D

# --- Settings you can change ---
@export var start_speed: float = 900.0   # how fast it starts flying
@export var bounciness: float = 1.0      # 1 = never loses energy
@export var radius: float = 40.0         # ball size
@export var color: Color = Color.WHITE   # ball colour
@export var bounce_sound: AudioStream = preload("res://ping.wav")
@export var random_pitch: bool = true     # different note each bounce

var sound_player: AudioStreamPlayer
var cooldown := 0.0   # stops sounds stacking up too fast

func _ready() -> void:
	# Make the hitbox match the ball size
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape

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
	# Soft glow, then the solid ball, then a small shine
	draw_circle(Vector2.ZERO, radius + 6, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.22, Color(1, 1, 1, 0.5))

func _process(delta: float) -> void:
	cooldown -= delta

func _on_hit(_body: Node) -> void:
	if cooldown > 0.0:
		return
	cooldown = 0.05
	if random_pitch:
		# Pick a note from a happy-sounding scale
		var notes := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]
		sound_player.pitch_scale = notes.pick_random()
	sound_player.play()
