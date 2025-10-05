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

@export var cutout_radius := 3.0

@export var cutout_interpolation := 1.0

## Expect room height for removing upper floors
@export var room_height := 5.0

@export_group("Linkage")
## Camera3D to control
@export var camera : Camera3D
## Node used to pivot the camera
@export var camera_pivot: Node3D
## Area3D used to detect the roof
@export var roof_area_3d: Area3D
## Area3D to detect upper floors between player and camera
@export var roof_camera_area_3d: Area3D

# Targets for camera component transforms
var camera_position := Vector3()
var camera_pivot_transform := Transform3D()
var camera_transform := Transform3D()

## Raycast query parameters
var _ray_query_params := PhysicsRayQueryParameters3D.new()

## occlusion cutout mesh targets, and actual values: [a, b, radius]
var _cutout_target := [Vector3(), Vector3(), 0.0]
var _cutout := [Vector3(), Vector3(), 0.0]

## List of FadeArea3Ds that are currently faded due to camera occlusion
var _faded_areas := []

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if follow_node:
        global_position = follow_node.global_position
    _set_camera_vertical_offset(v_offset)
    camera_pivot_transform = camera_pivot.transform
    _update_camera_transform()
    camera.transform = camera_transform

    # set up the occlusion cutout
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
    global_position = follow_node.global_position
    camera_pivot.transform = camera_pivot.transform.interpolate_with(
            camera_pivot_transform, weight)
    camera.transform = camera.transform.interpolate_with(
            camera_transform, weight)

func _process(delta: float) -> void:
    _handle_camera_occlusion(delta, Engine.get_process_frames() % 6 == 0)

    # Update the shape & location of the capsule between the camera root
    # (or the player) and the camera.
    if Engine.get_process_frames() % 15 == 14:
        var shape: CapsuleShape3D = roof_camera_area_3d.get_child(0).shape
        roof_camera_area_3d.position = camera.position/2
        roof_camera_area_3d.position.y += v_offset
        shape.height = camera.position.length()
        roof_camera_area_3d.rotation = camera.rotation * -1.5

    if Engine.get_process_frames() % 15 == 0:
        # Poll the area3d's for any FadeArea3Ds and fade them out if they're not
        # already faded
        var overlapping_areas = roof_camera_area_3d.get_overlapping_areas() + \
            roof_area_3d.get_overlapping_areas()
        var filtered_areas = []
        var limit = global_position.y + room_height
        for area: FadeArea3D in overlapping_areas:
            var area_shape: CollisionShape3D = area.get_child(0)
            var box_center := area_shape.global_position.y
            if box_center < limit:
                continue
           
            if area in filtered_areas:
                continue

            filtered_areas.push_back(area)
            if area not in _faded_areas:
                area.fade = true

        for area in _faded_areas:
            if area not in filtered_areas:
                area.fade = false
        _faded_areas = filtered_areas

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

## Detect camera occlusion, and update global shader values to cut a whole in
## materials so the player is visible
func _handle_camera_occlusion(delta: float, raycast: bool) -> void:

    if raycast:
        # Do a raycast from the camera root position (the player) to the camera.
        # Note the manual adjustment on y here, it's because the root is at the
        # player's feet, and this tries to center more on their chest.
        _ray_query_params.from = global_position
        _ray_query_params.from.y += 1.0
        _ray_query_params.to = camera.global_position
        _ray_query_params.collision_mask = 1
        var result = get_world_3d() \
                .direct_space_state \
                .intersect_ray(_ray_query_params)
        
        if not result:
            # No collision, update the cutout radius to be zero
            _cutout_target[2] = 0.0
        else:
            _cutout_target = [
                camera.global_position,
                result["position"],
                cutout_radius,
            ]

    # Lerp the cutout target values to make the cutout be less jarring
    var weight = clampf(delta * cutout_interpolation, 0, 1.0)
    var cutout = [
        _cutout[0].lerp(_cutout_target[0], weight),
        _cutout[1].lerp(_cutout_target[1], weight),
        lerpf(_cutout[2], _cutout_target[2], weight/3),
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

func _update_fade_group(value: float, group_name: StringName) -> void:
    for mesh_instance: MeshInstance3D in get_tree().get_nodes_in_group(group_name):
        mesh_instance.set_instance_shader_parameter("fade", value)

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


func _on_fade_area_entered(area: FadeArea3D) -> void:
    var shape: CollisionShape3D = area.get_child(0)
    var box_center: Vector3 = shape.global_position
    print(area.get_path(), ", limit ", global_position.y + room_height, ", shape ", box_center.y)
    if area.fade:
        return
    if global_position.y + room_height > box_center.y:
        return
    print("Fading")
    area.fade = true

func _on_fade_area_exited(area: FadeArea3D) -> void:
    print("exit ", area.get_path())
    if area.fade:
        area.fade = false
