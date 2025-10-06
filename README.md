# Godot Camera Occlusion Playground

This is a small playground I made to figure out how to handle camera occlusion
in Godot 4.5.  There are two techniques demonstrated in this repository, the
first is an occlusion cutout that makes holes in walls to allow the player to
remain visible.  The second is fading out upper floors when they are above the
player, or obscure the camera.

## Camera Occlusion Cutout

The work to create the cutout is done in a
[VisualShader](./textures/shader-fade-cutout.tres)

It uses three global shader parameters do define a bean shape that should be
rendered with alpha = 0.  The [camera controller](./fixed_angle_follow_camera/)
does a raycast from the player's position to the camera (in
`_handle_camera_occlusion()`) to set one end of the occlusion cutout bean to
be at the collision point, the other end is at the camera.  If there is no
collision, the radius of the cutout is shrunk to 0.

The VisualShader is added to a number of other ShaderMaterials that each have
a different texture.  The VisualShader parameters allow us to specify which
texture to use for the specific material.

## VisualShader implementing camera occlusion cutout
### Vertex Shader
We just set a number of varyings to get world-space values in the fragment shader.

<img width="718" height="391" alt="Screenshot 2025-09-21 at 2 37 08 PM" src="https://github.com/user-attachments/assets/f3b491b2-32fe-4be9-89a2-379b60c205fe" />

### Fragment Shader
The bottom part of this shader is all just to wrap the texture around the
mesh, similar to tri-planar, but in the mesh object's local space.

The top-half of the shader implements the cutout.

<img width="1213" height="743" alt="Screenshot 2025-09-21 at 2 35 53 PM" src="https://github.com/user-attachments/assets/f0effbd3-5700-4da2-aad9-baa39469f6b4" />

The shader also implements the dithering-based fade to transparency in the
middle of the graph.

## Fade

To fade out sections of buildings above the player, we use a 4x4 bayer matrix
to detemine which fragments to discard in a
[visual shader](./textures/shader-fade.tres).
The top section of this fragment shader implements fading, while the bottom is
for mapping the texture onto the surface.
This adds a `fade` shader instance parameter to any MeshInstance3D that is
using the shader material.

I created a [FadeArea3D](./fade_area_3d.gd) class that is used to put the
bounding box around all StaticBody3Ds that make up a single story of a
building.  When the `fade` export is set to true, `FadeArea3D` will create a
tween to set the `fade` shader instance parameter for every MeshInstance3D 
that is in a `StaticBody3D` that overlaps the `FadeArea3D`.  This will cause
every MeshInstance3D within a StaticBody3D within the `FadeArea3D` to fade out.

When `fade` export is set to `false`, the `fade` shader instance variable is
tweened back to `0.0`, causing the MeshInstance3Ds to fade in.

### But why don't the stairs fade out?!?
It's important to show paths off the current floor even when the floor above is
faded out.  There are two ways to do this:
* Use a material that doesn't implement a `fade` instance variable
* Move the StaticBody3D for the stairs into a separate layer that is not masked
  by the `FadeArea3D`

I went with the second option in this project.  `FadeArea3D`s default to a
collision mask of 1 (Default layer).  My stairs, I put in a separate collision
layer (Player, and Enemy), so they're not detected by the `FadeArea3D`, but
the player is still able to traverse them.

## References
* Occlusion Cutout Shader - Inspired by Baldur's Gate III: https://www.artofsully.com/projects/WXVnyD
* Cut off geometry shader using a SDF sphere - Godot 4: https://www.youtube.com/watch?v=GJVdWGvkWbk
* Source for the SDF code used to create the bean: https://iquilezles.org/articles/distfunctions/
* Recreating Baldur's Gate III camera system in Unreal Engine v5: https://www.youtube.com/playlist?list=PL9AKGyHd-pX0g2u2avo29oBUZUqU49KLh
