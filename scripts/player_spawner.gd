extends MultiplayerSpawner

@export var player_scene:PackedScene

var players = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_multiplayer_authority():
		multiplayer.peer_connected.connect(spawn)
		multiplayer.peer_disconnected.connect(remove_player)
		call_deferred("spawn_host")
	spawn_function = spawn_player
	pass # Replace with function body.

func spawn_host():
	if is_multiplayer_authority():
		spawn(1)

func remove_player(data):
	players[data].queue_free()

func spawn_player(data):
	var p = player_scene.instantiate()
	p.set_multiplayer_authority(data)
	players[data] = p
	return p

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
