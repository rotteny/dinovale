# SPDX-License-Identifier: MIT
class_name NavigationRules
extends Resource
## Números da navegação do domado e dos selvagens (M1, `m1-ameaca-e-corpo.md` seção 1), só dados. Valores em
## `res://data/balance/navigation_rules.tres`. Quem usa: `GridPathProvider` (grade e orçamento), `PathFollower`
## (replanejar e preso) e `DinoTamedState` (quando o domado desiste).

## Lado do tile do mapa, em pixels.
@export_range(4, 64) var tile_px: int = 16
@export_group("Folga por porte")
## Tiles livres exigidos em volta do caminho, por porte (Pequeno, Médio, Grande). O caminho passa pelo centro da
## célula: o corpo precisa caber. Médio 0 (como o jogador) e Grande 1 [provisório 08/11].
@export_range(0, 4) var clearance_small: int = 0
@export_range(0, 4) var clearance_medium: int = 0
@export_range(0, 4) var clearance_large: int = 1
@export_group("Pedidos")
## Pedido de caminho acima disto (em tiles, maior eixo) é recusado: o dino anda em linha reta até a distância cair.
@export_range(4, 256) var max_request_tiles: int = 48
## Replaneja a cada tanto com o alvo em movimento (e só se o alvo andou `repath_target_moved_tiles` do fim do caminho).
@export_range(0.1, 5.0) var repath_interval_s: float = 0.5
@export_range(0.5, 16.0) var repath_target_moved_tiles: float = 2.0
## Teto de buscas por quadro (o nativo não tem limite de nós: o teto é de pedidos). Passou dele, o pedido espera o próximo quadro.
@export_range(1, 64) var max_requests_per_frame: int = 3
## Chegou ao ponto do caminho a tantos pixels dele: passa ao próximo.
@export_range(1.0, 16.0) var waypoint_reach_px: float = 4.0
## Pedido sem caminho: tenta de novo depois de tanto; a segunda falha seguida também é "preso".
@export_range(0.1, 10.0) var no_path_retry_s: float = 1.0
@export_group("Travar e desistir")
## Janela de medição do progresso e o mínimo que ela precisa dar, em pixels (a 40 px/s esperam-se 40: 15%).
@export_range(0.2, 5.0) var stuck_check_seconds: float = 1.0
@export_range(0.0, 40.0) var stuck_min_progress_px: float = 6.0
## Sem progresso por tanto tempo, o dino está preso (1 s replaneja, 2 s replaneja com folga +1, 3 s preso).
@export_range(1.0, 30.0) var stuck_give_up_seconds: float = 3.0
## A célula à frente do corpo fica bloqueada por tanto tempo quando o dino trava, para o caminho novo contornar.
@export_range(0.5, 60.0) var blocked_cell_seconds: float = 5.0
@export_group("Domado preso")
## "Longe" do dono é mais que isto, em tiles; "fora da tela" é fora da câmera (tela em tiles) mais a margem.
@export_range(1.0, 64.0) var stuck_far_tiles: float = 14.0
@export_range(0.0, 8.0) var stuck_offscreen_margin_tiles: float = 2.0
## Tela do jogo em tiles (320x180 de 16 px): 20 x 11,25.
@export var screen_tiles: Vector2 = Vector2(20.0, 11.25)
## Preso e parado: intervalo mínimo entre tentativas, e quanto a tentativa precisa andar para limpar o episódio.
@export_range(0.5, 60.0) var stuck_retry_min_seconds: float = 5.0
@export_range(0.5, 32.0) var stuck_clear_tiles: float = 4.0


## Folga (em tiles) do porte, mais `extra` (o replanejamento de 2 s pede +1).
func clearance_of(size: Enums.DinoSize, extra: int = 0) -> int:
	var base := clearance_small
	if size == Enums.DinoSize.MEDIUM:
		base = clearance_medium
	elif size == Enums.DinoSize.LARGE:
		base = clearance_large
	return base + maxi(extra, 0)


## O ponto `at` está longe do dono E fora da tela (a desistência do domado só vale nos dois casos)?
func is_far_and_offscreen(at: Vector2, owner_at: Vector2) -> bool:
	var offset := (at - owner_at) / float(tile_px)
	if offset.length() <= stuck_far_tiles:
		return false
	var half := screen_tiles * 0.5 + Vector2(stuck_offscreen_margin_tiles, stuck_offscreen_margin_tiles)
	return absf(offset.x) > half.x or absf(offset.y) > half.y
