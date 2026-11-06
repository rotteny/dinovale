// SPDX-License-Identifier: MIT
// Névoa de borda (GDD 4.2, mapa-ilha.md 3): só cor e transparência, sem alterar o jogo. A forma
// (moldura de ~2 tiles em degraus) vem pronta numa máscara gerada por `FogFrame.build_mask`, que
// os testes conseguem ler; aqui só se aplica a cor e a opacidade máxima.
shader_type canvas_item;

uniform sampler2D mask : filter_nearest;
uniform float max_alpha = 0.28;
uniform vec4 fog_color : source_color = vec4(0.85, 0.9, 0.92, 1.0);

void fragment() {
	COLOR = vec4(fog_color.rgb, texture(mask, UV).r * max_alpha);
}
