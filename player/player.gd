extends CharacterBody3D

@export var speed = 5.0
@export var turn_sensitivity = 0.3
@export var camera: Camera3D

@export_group("Internal Linkage")
@export var rig: Node3D
@export var interactable_area: Area3D
@export var input_prompt: Node3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

    # XXX difference between move & steer:
    # * keyboard move is relative to the player's forward
    # * controller move is relavite to the camera's rotation

    # handle player-oriented movement
    var player_input = Input.get_vector(
            "player_strafe_left",
            "player_strafe_right",
            "player_move_forward",
            "player_move_back",
    )
    var direction = (transform.basis * Vector3(player_input.x, 0, player_input.y))
    direction.y = 0
    direction = direction.normalized()

    # handle camera-oriented movement
    var camera_input = Input.get_vector(
            "player_move_screen_left",
            "player_move_screen_right",
            "player_move_screen_up",
            "player_move_screen_down",
    )
    var camera_dir = (
        camera.global_basis * Vector3(camera_input.x, 0, camera_input.y)
    )
    camera_dir.y = 0
    camera_dir = camera_dir.normalized()

    direction = (direction + camera_dir).normalized()


    if Input.is_action_pressed("player_mouse_steer"):
        var look_dir = camera.global_position.direction_to(global_position)
        look_dir.y = 0
        look_at(global_position + look_dir, Vector3.UP)
    elif camera_dir:
        look_at(global_position + camera_dir, Vector3.UP)


    # if direction:
    #     print("player-input",
    #         ": player_input", player_input,
    #         ": camera_input", camera_input,
    #         ", direction ", direction,
    #         ", camera ", camera.global_position,
    #     )

    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed

    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)

    # rig.update_character_vector(velocity)
    move_and_slide()
