# Godot Camera Occlusion Cutout
This is a small playground I made to figure out how to do camera occlusion
cutouts.

All of the work is done in a single VisualShader: (./textures/wall-visual-shader.tres).

It uses three global shader parameters do define a bean shape that should be
rendered with alpha = 0.  The camera controller (./fixed_angle_follow_camera/)
does a raycast from the player's position to the camera, and updates the global
shader parameters to set the ends of the occlusion cutout bean at the first
collision from the player to the camera, and the camera.  When there is no
collision, the radius of the bean is shrunk to zero.

The VisualShader is added to a number of other ShaderMaterials that each have
a different texture.  The VisualShader parameters allow us to specify which
texture to use for the specific material.

## References
* Occlusion Cutout Shader - Inspired by Baldur's Gate III: (https://www.artofsully.com/projects/WXVnyD)
* Cut off geometry shader using a SDF sphere - Godot 4: (https://www.youtube.com/watch?v=GJVdWGvkWbk)
