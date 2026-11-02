extends CharacterBody3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var name_label: Label3D = $Label3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _enter_tree() -> void:
	# The node name is the peer ID, so that peer owns this player.
	if name.is_valid_int():
		set_multiplayer_authority(int(name), true)


func _ready() -> void:
	# Only the local player should render through this camera.
	camera_3d.current = is_multiplayer_authority()
	_update_label()


func _update_label() -> void:
	if not name.is_valid_int():
		return
	var player_steam_id: int = SteamManager.peer.get_steam_id_for_peer_id(int(name))
	if player_steam_id > 0:
		name_label.text = Steam.getFriendPersonaName(player_steam_id)
	else:
		name_label.text = "Player %s" % name


func _physics_process(delta: float) -> void:
	# Remote players are driven by the MultiplayerSynchronizer instead.
	if not is_multiplayer_authority():
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
