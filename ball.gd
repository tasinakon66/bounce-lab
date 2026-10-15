extends RigidBody2D
## One physics ball. Templates create these and set the fields below
## BEFORE adding the ball to the scene (they are read in _ready).

signal hit(body: Node)

var radius: float = 40.0
var color: Color = Color.WHITE
var picture: Texture2D = null        # emoji or photo drawn on the ball
var start_velocity := Vector2.ZERO
var bounciness: float = 1.0          # 1 = never loses energy
var friction: float = 0.0
var level: int = 0                    # merge level: 1 = "2", 2 = "4", ...
var show_number: bool = false
var bounce_sound: AudioStream = null
var glow: bool = true

var pop: float = 1.0                  # >1 while popping in (tweened)
var merging := false
var circle_shape: CircleShape2D
var sound_player: AudioStreamPlayer
var cooldown := 0.0

func _ready() -> void:
	circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	$CollisionShape2D.shape = circle_shape

	var mat := PhysicsMaterial.new()
	mat.bounce = bounciness
	mat.friction = friction
	physics_material_override = mat

	# No air resistance, and no tunnelling through walls at high speed
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)

	if bounce_sound:
		sound_player = AudioStreamPlayer.new()
		sound_player.stream = bounce_sound
		add_child(sound_player)

	linear_velocity = start_velocity

func set_radius(r: float) -> void:
	radius = r
	circle_shape.set_deferred("radius", r)

func _draw() -> void:
	var rad := radius * pop
	if picture:
		if glow:
			draw_circle(Vector2.ZERO, rad + 4, Color(color, 0.12))
		# the picture spins with the ball
		draw_texture_rect(picture, Rect2(-rad, -rad, rad * 2, rad * 2), false)
	else:
		# keep the shine in the top-left however the ball spins
		draw_set_transform(Vector2.ZERO, -rotation)
		if glow:
			draw_circle(Vector2.ZERO, rad + 10, Color(color, 0.15))
			draw_circle(Vector2.ZERO, rad + 5, Color(color, 0.25))
		draw_circle(Vector2.ZERO, rad, color)
		draw_circle(Vector2(-rad * 0.42, -rad * 0.42), rad * 0.16, Color(1, 1, 1, 0.55))
	if level > 0 and show_number:
		draw_set_transform(Vector2.ZERO, -rotation)
		var text := str(int(pow(2, level)))
		var size := int(rad * (0.8 if text.length() < 3 else 0.62))
		draw_string(ThemeDB.fallback_font, Vector2(-rad, size * 0.35), text,
			HORIZONTAL_ALIGNMENT_CENTER, rad * 2, size, Color.WHITE)

func _process(delta: float) -> void:
	cooldown -= delta
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# resting neighbours can merge too, not only fresh impacts
	if level > 0 and not merging:
		for body in get_colliding_bodies():
			try_merge(body)

func try_merge(body: Node) -> void:
	if merging or level <= 0:
		return
	if body is RigidBody2D and "level" in body and body.level == level and not body.merging:
		if get_instance_id() < body.get_instance_id():   # only one of the pair acts
			merging = true
			body.merging = true
			get_parent().merge_balls(self, body)

func _on_body_entered(body: Node) -> void:
	try_merge(body)
	hit.emit(body)
	if sound_player and cooldown <= 0.0:
		cooldown = 0.06
		if get_parent().has_method("next_pitch"):
			sound_player.pitch_scale = get_parent().next_pitch()
		sound_player.play()
