shader_type canvas_item;
render_mode unshaded;
uniform sampler2D visibility_mask : filter_linear, repeat_disable;
uniform float darkness = 0.35;
void fragment() {
	float visible_area = texture(visibility_mask, UV).r;
	COLOR = vec4(0.025, 0.035, 0.065, (1.0-visible_area)*darkness);
}
