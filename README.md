# Godot Camera Occlusion Cutout
This is a small playground I made to figure out how to do camera occlusion
cutouts.


https://github.com/user-attachments/assets/e7f58479-7c14-40df-95fa-06f75468d869


All of the work is done in a single [VisualShader](./textures/wall-visual-shader.tres)

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
The top half of this shader is all just to wrap the texture around the
mesh, similar to tri-planar, but in the mesh object's local space.

The bottom half of the shader implements the cutout.

<img width="1213" height="743" alt="Screenshot 2025-09-21 at 2 35 53 PM" src="https://github.com/user-attachments/assets/f0effbd3-5700-4da2-aad9-baa39469f6b4" />

## References
* Occlusion Cutout Shader - Inspired by Baldur's Gate III: https://www.artofsully.com/projects/WXVnyD
* Cut off geometry shader using a SDF sphere - Godot 4: https://www.youtube.com/watch?v=GJVdWGvkWbk
* Source for the SDF code used to create the bean: https://iquilezles.org/articles/distfunctions/
