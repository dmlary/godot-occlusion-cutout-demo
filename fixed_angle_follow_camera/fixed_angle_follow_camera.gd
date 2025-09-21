extends Node3D

## Node3D the camera is following
@export var follow_node : Node3D :
    set (value):
        follow_node = value

## Angle of the camera to the target
@export var angle := 35.0 :
    set(value):
        angle = value
        _update_camera_transform()

## Distance of camera from target
@export var distance := 30.0 :
    set(value):
        distance = clampf(value, distance_min, distance_max)
        _update_camera_transform()

## Maximum camera distance
@export var distance_max = 70

## Minimum camera distance
@export var distance_min = 10

## Vertical offset of the focus in the camera view
@export var v_offset := 0.0 : set = _set_camera_vertical_offset

## Speed at which the camera components interpolate to their target positions
@export var interpolate_speed := 20.0

## Camera orbit speed & direction
@export var orbit_speed := -0.15

@export var cutout_offset := 0.1

@export_group("Linkage")
## Camera3D to control
@export var camera : Camera3D
## Node used to pivot the camera
@export var camera_pivot: Node3D
## MeshInstance3D that is used to draw our occlusion stencil
@export var occlusion_cutout: MeshInstance3D
@export var material: Material

# Targets for camera component transforms
var camera_position := Vector3()
var camera_pivot_transform := Transform3D()
var camera_transform := Transform3D()

## Raycast query parameters
var _ray_query_params := PhysicsRayQueryParameters3D.new()

## Flag to denote if the camera's view is occluded; radius, height
var _occlusion_cutout := [0, 0]

var _cutout_target := [Vector3(), Vector3(), 0.0]
var _cutout := [Vector3(), Vector3(), 0.0]

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if follow_node:
        global_position = follow_node.global_position
    _set_camera_vertical_offset(v_offset)
    camera_pivot_transform = camera_pivot.transform
    _update_camera_transform()
    camera.transform = camera_transform
    _cutout_target = [camera.global_position, Vector3(), 0]
    _cutout = _cutout_target.duplicate()
    
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action("camera_zoom_in"):
        distance -= event.factor
    elif event.is_action("camera_zoom_out"):
        distance += event.factor
    elif event.is_action("release_cursor"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and \
            event is InputEventMouseButton:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion:
        var delta: int
        if Input.is_action_pressed("camera_orbit"):
            delta = event.relative.x
        elif Input.is_action_pressed("player_mouse_steer"):
            delta = -event.relative.x
            pass
        else:
            return
        # Limit the orbit speed by mouse
        _orbit_camera(clampf(delta * 0.4, -45, 45))

func _physics_process(delta: float) -> void:

    # grab the input direction
    var input_dir = Input.get_axis("camera_orbit_left", "camera_orbit_right")
    _orbit_camera(input_dir * orbit_speed)

    camera_position = follow_node.global_position
    
    # smooth updates to each camera component
    var weight = clampf(delta * interpolate_speed, 0, 1.0)
    global_position = global_position.lerp(camera_position, weight * weight)
    camera_pivot.transform = camera_pivot.transform.interpolate_with(
            camera_pivot_transform, weight)
    camera.transform = camera.transform.interpolate_with(
            camera_transform, weight)

    # lerp the shader globals for the cutout position
    var cutout = [
        _cutout[0].lerp(_cutout_target[0], weight),
        _cutout[1].lerp(_cutout_target[1], weight),
        lerpf(_cutout[2], _cutout_target[2], weight),
    ]

    # if the cutout changed, update the global shader params
    if cutout != _cutout:
        _cutout = cutout
        RenderingServer.global_shader_parameter_set(
                "camera_occlusion_cutout_a",
                _cutout[0])
        RenderingServer.global_shader_parameter_set(
                "camera_occlusion_cutout_b",
                _cutout[1])
        RenderingServer.global_shader_parameter_set(
                "camera_occlusion_cutout_radius",
                _cutout[2])

   
func _process(_delta: float) -> void:
    _handle_camera_occlusion()
    pass

func _update_camera_transform() -> void:
    if not is_node_ready():
        return

    # find the y/z coordinates for the camera based on the viewing angle &
    # distance
    var angle_rad = deg_to_rad(angle)
    var y = sin(angle_rad) * distance
    var z = cos(angle_rad) * distance

    camera_transform.origin.y = y
    camera_transform.origin.z = z
    camera_transform = camera_transform.looking_at(Vector3.ZERO)

func _handle_camera_occlusion() -> void:
    _ray_query_params.to = camera.global_position
    _ray_query_params.from = global_position
    _ray_query_params.from.y += 0.5
    _ray_query_params.collision_mask = 1
    var result = get_world_3d() \
            .direct_space_state \
            .intersect_ray(_ray_query_params)
    # print(result)
    if not result:
        _cutout_target[2] = 0.0
    else:
        _cutout_target = [
            camera.global_position,
            result["position"],
            3,
        ]


func _orbit_camera(degrees: float) -> void:
    # assert(delta >= -1.0 && delta <= 1.0)
    var rot : Vector3 = camera_pivot.transform.basis.get_euler()
    rot.y += clampf(degrees, -360, 360)
    # if not is_zero_approx(degrees):
    #     print("rot ", degrees)
    var meep = deg_to_rad(degrees)
    camera_pivot_transform = camera_pivot_transform.rotated(Vector3.UP, meep)

## Ensure that vertical offset propagates to camera3D node
func _set_camera_vertical_offset(offset: float) -> void:
    v_offset = offset
    if camera:
        camera.v_offset = v_offset
