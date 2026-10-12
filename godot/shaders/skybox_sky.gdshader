shader_type sky;

#include "res://shaders/skybox.gdshaderinc"

void sky() {
	COLOR = skybox_color(EYEDIR);
}
