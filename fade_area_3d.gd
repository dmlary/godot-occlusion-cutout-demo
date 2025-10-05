extends Area3D
class_name FadeArea3D

## Fade-in/fade-out duration
@export var duration := 0.5

## Set to true if MeshInstance3Ds within the area should fade out
@export var fade := false :
    set=_set_fade


func _set_fade(value: bool) -> void:
    fade = value

    # get all the mesh instances in the area
    var mesh_instances = []
    for body in get_overlapping_bodies():
        for child in body.get_children(true):
            if is_instance_of(child, MeshInstance3D):
                mesh_instances.push_back(child)
    print("fade ",
        "out:" if fade else "in:",
        mesh_instances)
    # kick off a tween to fade them in/out
    create_tween().tween_method(
        _set_fade_shader_parameter.bind(mesh_instances),
        0.0 if fade else 1.0,
        1.0 if fade else 0.0,
        duration)

func _set_fade_shader_parameter(
        value: float,
        mesh_instances: Array) -> void:
    for mesh_instance: MeshInstance3D in mesh_instances:
        mesh_instance.set_instance_shader_parameter("fade", value)
