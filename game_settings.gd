extends RefCounted

# Static vars live as long as the app is open, so they survive
# scene restarts. This is where the menu stores the player's choices.
static var data := {
	"show_menu": true,
	"merge_mode": false,
	# Bounce mode
	"ball_count": 10,
	"ball_size": 40.0,
	"speed": 900.0,
	"bounciness": 1.0,
	# Merge mode
	"goal_level": 7,        # 7 = 128
	"drop_interval": 0.8,
}
