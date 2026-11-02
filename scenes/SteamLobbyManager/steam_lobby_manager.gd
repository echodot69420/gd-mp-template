extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Steam.loblobby_joined.connect("_on_lobby_joined")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
