shader_type canvas_item;
// Pinta a silhueta do desenho com uma cor só (o contorno de destaque do nó ao alcance).
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.5, 1.0);

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a);
}
