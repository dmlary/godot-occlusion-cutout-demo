extends Area3D
class_name FadeArea3D

## Fade-in/fade-out duration
@export var duration := 0.5

## Set to true if MeshInstance3Ds within the area should fade out
@export var fade := false :
    set=_set_fade

func _ready():
    # connect body_entered and body_exited to handle NPCs passing through the
    # FadeArea3D.
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

## When a body enters the FadeArea3D, if the area is faded out, do the same to
## the MeshInstance3Ds inside the body
func _on_body_entered(body: PhysicsBody3D) -> void:
    if not fade:
        return

    var meshes = []
    for child in body.get_children(true):
        if is_instance_of(child, MeshInstance3D):
            meshes.push_back(child)

    _update_mesh_instances(meshes, fade)

## When a body exits the FadeArea3D, if the area is faded out, fade in the
## body's MeshInstance3Ds
func _on_body_exited(body: PhysicsBody3D) -> void:
    if not fade:
        return

    var meshes = []
    for child in body.get_children(true):
        if is_instance_of(child, MeshInstance3D):
            meshes.push_back(child)

    _update_mesh_instances(meshes, false)

## When the fade state changes, fade all MeshInstance3Ds within the FadeArea3D
func _set_fade(value: bool) -> void:
    fade = value

    # get all the mesh instances in the area
    var mesh_instances = []
    for body in get_overlapping_bodies():
        for child in body.get_children(true):
            if is_instance_of(child, MeshInstance3D):
                mesh_instances.push_back(child)

    _update_mesh_instances(mesh_instances, fade)

## Use a tween to update the provided mesh instances to fade in or out
func _update_mesh_instances(mesh_instances: Array, fade_out: bool) -> void:
    print("fade ",
        "out:" if fade else "in:",
        mesh_instances)
    if not mesh_instances:
        return

    # kick off a tween to fade them in/out
    create_tween().tween_method(
        _set_fade_shader_parameter.bind(mesh_instances),
        0.0 if fade_out else 1.0,
        1.0 if fade_out else 0.0,
        duration)

## Method used by the tween in _update_mesh_instances() to set the fade shader
## parameter.
func _set_fade_shader_parameter(
        value: float,
        mesh_instances: Array) -> void:
    for mesh_instance: MeshInstance3D in mesh_instances:
        mesh_instance.set_instance_shader_parameter("fade", value)
