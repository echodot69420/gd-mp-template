extends Node3D

var peer = SteamMultiplayerPeer
@onready var lobbies_list:VBoxContainer = $MultiplayerUI/VBoxContainer/ScrollContainer/LobbiesList

var lobby_id = 0
var lobby_created:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	peer = SteamManager.peer

	Steam.lobby_created.connect(_on_lobby_created)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_host_button_pressed() -> void:
	if lobby_created:
		return
	
	peer.create_lobby(Steam.LOBBY_TYPE_PUBLIC)
	multiplayer.multiplayer_peer = peer

func _on_join_button_pressed() -> void:
	var lobbies_btns = lobbies_list.get_children()
	for i in lobbies_btns:
		i.queue_free()

func _on_lobby_created(connect: int, _lobby_id: int):
	if connect:
		lobby_id = _lobby_id
		Steam.setLobbyData(lobby_id, "name", str(SteamManager.STEAM_USERNAME+"'s Lobby"))
		Steam.setLobbyJoinable(lobby_id, true)
		
		SteamManager.lobby_id = lobby_id
		SteamManager.is_lobby_host = true
