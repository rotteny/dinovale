# SPDX-License-Identifier: MIT
class_name DinoBaseStats
extends Resource
## Atributos base de uma criatura, no nível base (`DinoLevelRules.base_level`).
## Precursor do `SpeciesDef` (ADR-003): quando ele existir, estes campos migram para lá.

const SEX_FEMALE := "f"
const SEX_MALE := "m"

@export var id: String = "placeholder_dino"
## Nome da espécie, como o jogador lê (placa do domado).
@export var display_name: String = "Dino"
## Folha do sprite descrita por JSON (quadro, colunas por animação, linhas por direção).
@export_file("*.json") var sheet_path: String = "res://assets/sprites/dinos/paquicefalo.json"
@export var base_health: float = 100.0
## Dano de cada golpe do dino ao jogador (M1: fixo, sem escala por nível; o ciclo é o `threat_profile`). Fonte única do número.
@export var base_damage: float = 4.0
@export var base_torpor: float = 100.0
## Refeições para domesticar no nível base, com dificuldade 1,0.
@export var base_meals: int = 5
@export var difficulty: float = 1.0
## Carne da carcaça no nível base (GDD 5.6; o couro ainda não existe no catálogo).
@export var carcass_meat: int = 4
## Folha inteira do sprite (o PNG que o `sheet_path` descreve). Vazio = a folha da cena (a do Paquicéfalo).
@export var sheet_texture: Texture2D
## Quadro "morto" da espécie (coluna 10 da folha): o desenho da carcaça.
@export var carcass_texture: Texture2D
## Caixa de golpe e de alvo (hurtbox), em pixels (largura, altura): o que o jogador acerta. NÃO colide com o mundo: a
## colisão dos pés vem do porte (`foot_size`). O corpo a lê ao nascer.
@export var hitbox_size: Vector2 = Vector2(24.0, 16.0)
## Chave desta espécie nas vagas de bando do mapa (`IslandMap.spawn_slots[].species`).
@export var spawn_key: String = "paquicefalo"
## Comida ideal da doma (id de `Items`).
@export var ideal_food: String = "berry"
## Agressivo (GDD 6.7): ao avistar o jogador, persegue. Falso = não persegue (os demais tipos de Conduta vêm depois).
@export var aggressive: bool = false
## Percepção do agressivo, em tiles: a distância efetiva é `raiz(dx² + (peso x dy)²)`; 8 e 1,6 dão a elipse
## de 8 tiles na horizontal e 5 na vertical (GDD 4.2).
@export_range(1.0, 32.0) var perception_tiles: float = 8.0
@export_range(1.0, 4.0) var perception_vertical_weight: float = 1.6
## Velocidade da perseguição, em pixels por segundo (GDD 6.7: 90).
@export_range(1.0, 400.0) var chase_speed: float = 90.0
## Distância mínima, em pixels (centro a centro), que o perseguidor mantém do alvo: maior que a soma dos raios dos corpos
## mais uma folga (corpos se encostam a ~22 px). Ao chegar nela o dino PARA em vez de empurrar o jogador.
@export_range(0.0, 64.0) var chase_stop_px: float = 28.0
## [premissa] Sem ataque ainda (M1), quem alcança o alvo desiste e fica em alerta por tanto tempo, para não virar um ímã.
@export_range(0.0, 120.0) var reached_alert_seconds: float = 20.0
## Desiste com o alvo a mais de tantos tiles, ou depois de tantos segundos perseguindo (GDD 6.7: 20 tiles, 15 s).
@export_range(1.0, 64.0) var chase_give_up_tiles: float = 20.0
@export_range(1.0, 120.0) var chase_max_seconds: float = 15.0
## Depois de desistir, segundos sem voltar a perseguir (alerta do GDD 6.7: 5 s).
@export_range(0.0, 60.0) var alert_seconds: float = 5.0
## Chance de nascer macho (`sexo_proporcao_macho` do desenho, `documentacao/design/corte-v02/montaria-vinculo-trabalho.md`): 0,5 = 50/50
## em toda espécie. Sexo não muda atributo, torpor, dieta nem velocidade.
@export_range(0.0, 1.0) var male_ratio: float = 0.5
## Porte (v0.2: Dodo pequeno, Paquicéfalo e Utahraptor médios, Triceratops grande).
@export var size: Enums.DinoSize = Enums.DinoSize.MEDIUM
## Tabela dos pés por porte (a colisão com o mundo).
@export var size_rules: SizeClassRules = preload("res://data/balance/size_classes.tres")
## Tipo de atacante desta espécie perante a doma (`TamingRules.ATTACKER_*`): é a chave de `attack_fixed_loss`.
@export var attacker_kind: String = TamingRules.ATTACKER_CARNIVORE
## Dano em área (null = golpe só no alvo). Só vale se `size` for Grande: veja `area_rules`.
@export var area_attack: AreaAttackRules
## Ciclo de ameaça e golpe do bravo (null = só persegue, como na etapa 3).
@export var threat_profile: ThreatProfile
@export_group("Bando")
## Terrenos (índice do `IslandMap`) onde o bando desta espécie pode nascer. A região da vaga é a máscara; isto a restringe.
@export var spawn_terrains: Array[int] = [3]
## Limites do tamanho do bando: o mapa só escolhe dentro deles (fora, a carga satura).
@export_range(1, 8) var group_size_min: int = 1
@export_range(1, 8) var group_size_max: int = 4
## Os membros nascem a até tantos tiles do centro do bando.
@export_range(0.0, 16.0) var cohesion_radius_tiles: float = 3.0
## Distância mínima, em tiles, entre os centros de dois bandos DESTA espécie (vale se maior que a global do mundo).
@export_range(0.0, 200.0) var min_group_spacing_tiles: float = 24.0
## Segundos de jogo entre o último membro selvagem sair (morte ou doma) e o bando renascer em outro lugar.
@export_range(1.0, 86400.0) var group_respawn_seconds: float = 1200.0
@export_group("")


## Regras de dano em área que valem para esta espécie, ou null. Porte que não é Grande nunca tem, mesmo com o dado preenchido.
func area_rules() -> AreaAttackRules:
	return area_attack if size == Enums.DinoSize.LARGE else null


## Sexo do selvagem de id `spawn_id` (`<vaga>.<geração>.<k>`, ADR-007): fluxo próprio, `["wild", semente do mundo, id, "sex"]`,
## separado do do nível para um sorteio novo nunca deslocar o outro. O mesmo id dá o mesmo sexo na mesma semente.
func roll_sex(map_seed: int, spawn_id: String) -> String:
	var rng := SeededRng.new()
	rng.seed_from(["wild", map_seed, spawn_id, "sex"])
	return SEX_MALE if rng.next_below(1000) < roundi(male_ratio * 1000.0) else SEX_FEMALE


## Colisão dos pés (largura, altura em pixels): vem do porte, pela tabela do GDD.
func foot_size() -> Vector2:
	return size_rules.foot_of(size)
