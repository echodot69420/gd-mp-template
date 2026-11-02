extends MultiplayerSpawner

## Spawns one player per connected peer, but only once every lobby member has
## finished loading the game scene (see SteamManager.mark_level_loaded).  That
## way no spawn packet is ever sent to a peer that does not have this scene yet.

@export var player_scene: PackedScene


func _ready() -> void:
	spawn_function = _spawn_player

	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		SteamManager.level_sync_complete.connect(_spawn_all_players, CONNECT_ONE_SHOT)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Tell the lobby this scene is loaded; on the server this may finish the
	# level sync straight away and spawn everyone.
	# TEMPORARY: two test instances on one Steam account share a single
	# lobby-member entry, so the server gate would open before the second
	# instance finished loading this scene.  The delay makes that test
	# deterministic; with two real accounts the member-data gate is enough.
	if "--lobbytest2" in OS.get_cmdline_args() and multiplayer.is_server():
		await get_tree().create_timer(8.0).timeout
	SteamManager.mark_level_loaded()


func _spawn_all_players() -> void:
	var ids: Array = [multiplayer.get_unique_id()]
	ids.append_array(multiplayer.get_peers())
	for id in ids:
		if not _player_exists(id):
			spawn(id)


## A peer that finishes connecting after the sync completes still needs a player.
func _on_peer_connected(id: int) -> void:
	if SteamManager.is_level_sync_finished() and not _player_exists(id):
		spawn(id)


func _on_peer_disconnected(id: int) -> void:
	var player := _get_player(id)
	if player != null:
		player.queue_free()


## Runs on every peer; the node name must match everywhere so the multiplayer
## authority (the peer ID) can be picked up in player._enter_tree().
func _spawn_player(id: Variant) -> Node:
	var player = player_scene.instantiate()
	player.name = str(id)
	# Spread the starting positions out a little so players do not stack up.
	var index: int = int(id)
	player.position = Vector3((index % 5) * 1.5 - 3.0, 0.0, (int(index / 5.0) % 5) * 1.5 - 3.0)
	return player


func _spawn_root() -> Node:
	return get_node(get_spawn_path())


func _player_exists(id: int) -> bool:
	return _spawn_root().has_node(str(id))


func _get_player(id: int) -> Node:
	return _spawn_root().get_node_or_null(str(id))
