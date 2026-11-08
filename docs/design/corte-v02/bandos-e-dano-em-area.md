# Bandos e dano em área (v0.2)

Resposta ao playtest de 07/11. Legenda: **[decidido]** é palavra do dono; **[premissa]** é número da equipe que vale até o teste; **[a validar]** só se resolve jogando. Os números calculados saem de `game/data/world/lunata.json` (256x256 tiles, tile 16 px) e de uma simulação com semente fixa; o que a conta prova é consistência, não diversão.

## 1. O que o dono pediu

- **[decidido]** Pequenos focos de 3 ou 4; cada espécie forma bando do seu jeito; na grande maioria o máximo é 4 indivíduos.
- **[decidido]** Dinos Grandes podem atacar em área e acertar adjacentes ao alvo. O dano adjacente é menor que o do alvo principal e diminui com o afastamento.

## 2. Estado de hoje (lido do código e do mapa)

| Espécie | No mapa hoje | Onde | Observação |
|---|---|---|---|
| Paquicéfalo | 108 (= `wild_population_max`) | campina 60, mata-baixa 48 | pontos soltos; o vizinho mais próximo tem mediana de 2 tiles |
| Utahraptor | 10 | mata-baixa | |
| Dodo | 0 | n/d | ainda não existe em `game/data/dino/` |
| Triceratops | 0 | n/d | idem |
| **Total** | **118** | | |

Tela 320x180 a 16 px = **20 x 11,25 tiles = 225 tiles²**.

**Pior caso hoje (contado no mapa, janela deslizante):** 12 paquicéfalos numa tela, 2 utahraptores, **14 dinos no total**. Os agrupamentos naturais (pontos a até 3 tiles um do outro) são 23 solitários, 17 pares, 9 trios, e há aglomerados de 5, 6 e 8: o 12 vem daí.

Fatos do código que limitam o desenho:
- `WildPopulation.populate` cria um selvagem por ponto de `spawns`, com id próprio por ponto (ADR-007). **Não existe "grupo" no dado.**
- `world_rules.level_bands` só tem os biomas 3 (campina 1-12), 4 (mata-baixa 5-25) e 5 (pedreira 15-35). **Praia não tem faixa de nível**, então o Dodo nasce só na campina.
- Os tipos de atacante de `TamingRules` são só `player` e `carnivore`. `Dino.receive_hit` devolve `false` para tipo de atacante que a regra não conhece, então o golpe em área de um herbívoro (Triceratops) exige um tipo novo (ex.: `herbivore`). Registro para o `SORA`.
- `attack_damage` do dino ainda não é usado por nenhuma ação (o ataque do selvagem é do M1).

## 3. Bandos por espécie

Escala geométrica: o foco cabe numa tela. Raio de coesão 3 tiles = diâmetro 6, menos de um terço da largura da tela (20).

### Dado (campos de `DinoBaseStats` ou `GroupRules` dentro dele; nomes em inglês)

| Campo | Dodo (Pequeno) | Paquicéfalo (Médio) | Utahraptor (Médio) | Triceratops (Grande) |
|---|---|---|---|---|
| `group_form` | `loose_flock` | `focus` | `pack` | `pair_or_solo` |
| `group_size_min` | 2 [premissa] | 3 [decidido] | 2 [premissa] | 1 [premissa] |
| `group_size_max` | 4 [decidido] | 4 [decidido] | 3 [premissa] | 2 [premissa] |
| `group_count` no mapa | 8 [premissa] | 20 [premissa, era 24; ver 3.1] | 4 [premissa] | 4 [premissa] |
| `group_sizes` (tamanho de cada bando, em ordem) | 2,3,4,3,3,2,4,3 | 10 de 3 e 10 de 4 | 3,3,2,2 | 2,2,1,1 |
| `cohesion_radius_tiles` (nasce e passeia dentro) | 4,0 [premissa] | 3,0 [premissa] | 4,0 [premissa] | 3,0 [premissa] |
| `min_group_spacing_tiles` (mesma espécie) | 20 [premissa] | 24 [premissa] | 40 [premissa] | 30 [premissa] |
| `spawn_terrains` | campina | campina, mata-baixa | mata-baixa | pedreira |
| `share_alert` (um percebe, o bando todo percebe) | false | true | true | false |
| `max_individuals_total` (calculado) | 24 | 70 | 10 | 6 |

Mundo (em `world_rules`): `min_cross_species_spacing_tiles = 16` [premissa]; `group_leash_factor = 1,5` [premissa] (o membro que se afasta mais de 1,5x o raio volta ao centro do foco; perseguição e fuga ignoram a coleira).

Como cada espécie forma bando:
- **Dodo, `loose_flock`:** bando frouxo de 2 a 4, bichinhos que andam sem ordem dentro de 4 tiles. É o primeiro alvo de doma fácil; 2 a 4 deixa o jogador escolher um e deixar os outros.
- **Paquicéfalo, `focus`:** foco de 3 ou 4 pastando juntos, raio 3. `share_alert` ligado só faz o grupo acordar junto, não atacar.
- **Utahraptor, `pack`:** matilha de 2 ou 3, **máximo 3 e não 4** [premissa]: é agressivo e o torpor é a ameaça ao jogador. Três raptores com `share_alert` são o maior risco do mapa e **[a validar]** com o Soco.
- **Triceratops, `pair_or_solo`:** par ou solitário. É Grande, ocupa mais espaço e tem dano em área; 2 já é um encontro pesado.

Exceção ao "máximo 4": **nenhuma**. Todas as espécies ficam em 4 ou menos.

### Conta: quantos dinos, hoje vs. proposto

| Espécie | Hoje | Proposto | Variação |
|---|---|---|---|
| Dodo | 0 | 24 | +24 |
| Paquicéfalo | 108 | 70 (20 focos: 10x3 + 10x4) | -38 |
| Utahraptor | 10 | 10 (2 trios + 2 pares) | 0 |
| Triceratops | 0 | 6 (2 pares + 2 solitários) | +6 |
| **Total** | **118** | **110** | -8 |

O total cai pouco; o que muda é a distribuição (os 84 de antes viraram 70 pela distância mínima global, seção 3.1). O Paquicéfalo cai porque o espaçamento de 24 tiles só comporta cerca de 25 a 28 focos no campina e na mata-baixa (8.012 + 7.610 tiles): a simulação com 5 sementes deu 25 a 28 focos para D = 24, contra 52 a 55 para D = 16 (que ainda daria pior caso 7 a 8). Se o dono quiser mais paquicéfalos no mapa, o caminho é reduzir D, e o pior caso sobe.

### 3.1 Onde nascem os bandos (requisito do dono, 07/11)

- **[decidido]** Um bando nunca nasce perto de outro: o objetivo é pulverizar pequenos bandos espalhados, não formar regiões cheias.
- **[decidido]** O local de nascimento é aleatório, dentro das regiões apropriadas da espécie (ex.: nenhum jacaré no deserto).

**Distância mínima entre QUALQUER par de bandos** (todas as espécies): `world_rules.min_group_spacing_any_tiles = 16` [premissa]. Vale entre centros de bandos. Substitui o antigo `min_cross_species_spacing_tiles` (16): o número é o mesmo, agora é regra global e não só entre espécies. A distância da mesma espécie continua a da tabela e vale se for maior: `distância exigida = max(global, da espécie)` (Dodo 20, Paquicéfalo 24, Utahraptor 40, Triceratops 30). 16 tiles = 80% da largura da tela (20): em tela comum não cabem dois centros de bando com espaço de sobra.

**Espécie -> região permitida** (códigos do `lunata.json`; só existem hoje: praia 2, campina 3, mata-baixa 4, pedreira 5, água não conta; tiles do mapa em parênteses):

| Espécie | Regiões permitidas | Fora (proibido) | Marca |
|---|---|---|---|
| Dodo | campina (8.012) | praia, mata-baixa, pedreira | premissa; praia só se ganhar faixa de nível (ver 5.5) |
| Paquicéfalo | campina + mata-baixa (15.622) | praia, pedreira | premissa (é o que o mapa já usa) |
| Utahraptor | mata-baixa (7.610) | campina, praia, pedreira | premissa |
| Triceratops | pedreira (3.661) | campina, mata-baixa, praia | premissa |

O dado é `spawn_terrains` por espécie (já na tabela acima); o nome de bioma vem do código de `world_rules.level_bands`, sem número em código.

**Posição por mundo:** o centro de cada bando é sorteado entre os tiles permitidos da espécie, com a semente do mundo (`seed`), e gravado no mapa gerado; o mesmo mundo dá a mesma posição sempre (ADR-007: id por ponto não muda). Mundos de semente diferente têm posições diferentes. Regras do sorteio, na ordem: espécies de maior espaçamento primeiro (Utahraptor, Triceratops, Paquicéfalo, Dodo); centro a pelo menos `spawn_min_distance_player_tiles = 12` [premissa] do início do jogador; o bando do tutorial (123,188) é fixo e conta para as distâncias; todo membro nasce em tile permitido da espécie (não atravessa a divisa de bioma).

**Respawn do bando:** a nova posição é sorteada de novo, entre os tiles permitidos que cumprem juntos: (a) distância exigida de todo bando vivo (global e da espécie); (b) pelo menos `respawn_min_distance_player_tiles = 40` [premissa, = 2 telas de largura] de qualquer jogador conectado; (c) fora da divisa: membros em tile permitido. Não volta ao mesmo lugar por regra (pode cair perto por acaso). Se não houver tile válido: espera `respawn_retry_seconds = 60` [premissa] e tenta de novo, sem limite; a cada 3 falhas seguidas relaxa só a regra (b) para 24 tiles; nunca relaxa (a) nem a região. Um bando que não renasce não é erro, e o log registra "sem lugar" uma vez por bando.

**Conta (simulação, tile a tile, 20 a 100 sementes, só biblioteca padrão, sorteio com ordem acima):**

| Distância global | Dodo (alvo 8) | Paquicéfalo (alvo 24) | Utahraptor (4) | Triceratops (4) |
|---|---|---|---|---|
| nenhuma (só da espécie, como em 3) | 8 | 24 | 4 | 4 |
| 16 | 8 | 22 a 24 (média 23,8) | 4 | 4 |
| 20 | 4 a 8 (média 5,9) | 20 a 24 (23,1) | 4 | 4 |
| 24 | 0 | 20 a 24 (21,9) | 4 | 4 |

Leitura: com global 16, o mapa de 24 paquicéfalos só fecha em **88 de 100 sementes**, e com todos os bandos vivos sobram 0 tiles livres em alguns mundos, então o respawn fica preso a 12 tiles (mundos ruins) quando um bando morre. Com global acima de 20 o Dodo some, porque a campina é compartilhada com o Paquicéfalo. Por isso, **o Paquicéfalo passa de 24 para 20 focos [premissa]**: com 20, 100 de 100 sementes fecham os 4 grupos de espécies e sobram, com um bando morto, no mínimo 55 e em média 272 tiles para o respawn (com 24: 12 e 140). Totais por espécie: **Dodo 24, Utahraptor 10, Triceratops 6 não mudam; Paquicéfalo cai de 84 para 70** (total 110). O pior caso na tela (seção "pior caso") não piora: a distância mínima só afasta mais.

**Frases testáveis (posição):**

1. Dois bandos quaisquer, de qualquer espécie, têm centros a no mínimo `min_group_spacing_any_tiles` (16); da mesma espécie, a no mínimo o maior entre 16 e `min_group_spacing_tiles` dela.
2. Todo membro de bando nasce em tile de `spawn_terrains` da espécie; Dodo e Triceratops nunca nascem em mata-baixa, Utahraptor nunca em campina ou pedreira.
3. Mesma semente de mundo gera as mesmas posições; semente diferente gera posições diferentes em pelo menos 90% dos bandos [premissa].
4. Nenhum centro de bando nasce a menos de 12 tiles do início do jogador.
5. No respawn, a posição do centro novo cumpre (a) e (c) acima e está a 40 tiles ou mais de todo jogador conectado.
6. Sem tile válido, o respawn adia 60 s e tenta de novo; o bando nunca nasce fora da região nem a menos que a distância global de outro bando.
7. Para a semente de referência (`seed` 1) o gerador fecha 100% dos bandos de `group_count` ou falha o teste de geração; sementes que não fecham geram o máximo que cabe e avisam com o número faltante.

Valores por servidor (auto-hospedagem): `min_group_spacing_any_tiles`, `respawn_min_distance_player_tiles` e `respawn_retry_seconds` ficam em `world_rules`, sem constante em código. Observação ao `SORA`: o gerador precisa de teste com várias sementes.

### Conta: pior caso na tela 320x180

Simulação: raio de coesão aplicado, espaçamentos da tabela, tutorial (123,188) respeitado, 20 sementes.

| Caso | Hoje | Proposto |
|---|---|---|
| Paquicéfalos na mesma tela | 12 | **4** (um foco; com D = 24 não cabem dois focos inteiros numa janela de 20 tiles) |
| Utahraptores | 2 | 3 |
| Dodos | 0 | 4 |
| Triceratops | 0 | 2 |
| **Todas as espécies juntas (pior achado)** | **14** | **8** (dois focos de espécies diferentes, 4+4; o típico é 5 a 6) |

O pior caso global de 8 é o "teto honesto" das regras: no máximo 2 focos de espécies diferentes na tela, nunca dois da mesma. Para baixar de 8, `min_cross_species_spacing_tiles` teria de passar de 16 para cerca de 24, ao custo de menos espaço para o bando de Dodos [a validar].

### Frases testáveis (bando)

1. Todo bando nasce com tamanho entre `group_size_min` e `group_size_max` da espécie.
2. Nenhuma espécie tem bando maior que 4.
3. Dois bandos da mesma espécie têm centros a pelo menos `min_group_spacing_tiles`; de espécies diferentes, a pelo menos `min_cross_species_spacing_tiles`.
4. Todo membro nasce a no máximo `cohesion_radius_tiles` do centro do bando, num terreno de `spawn_terrains`.
5. Em qualquer janela de 20 x 11,25 tiles do mapa nasce no máximo 4 da mesma espécie e no máximo 8 no total.
6. Com `share_alert` ligado, quando um membro percebe o jogador, os outros vivos do bando entram em alerta no mesmo quadro; desligado, cada um decide sozinho.
7. Morto ou domado um membro, o bando continua com os demais; o bando não se refaz.
8. O membro que passa de `cohesion_radius_tiles x group_leash_factor` do centro, sem estar perseguindo nem fugindo, volta para o centro.

Observação de dado para quem implementa: o formato do mapa precisa de `spawn_groups` paralelo a `spawn_ids` (cada ponto guarda o id do bando); id por ponto continua, para o delta do save não mudar (ADR-007). A população deixa de ser "uma lista de pontos" no `mapa_export.py`; isso é do `SORA`.

## 4. Dano em área

### Quem tem
Só quem tem o `Resource` `area_attack` preenchido. Regra de elegibilidade: **só porte Grande** [decidido pelo dono]. Na v0.2 isso é **só o Triceratops** [decidido por consequência: é o único Grande da v0.2]. Dodo, Paquicéfalo e Utahraptor não têm.

### Dado (`AreaAttackRules`, no `DinoBaseStats` do Triceratops; `null` = sem área)

| Campo | Valor | Marca |
|---|---|---|
| `enabled` | true | decidido |
| `radius_tiles` (da posição do alvo principal) | 3,0 | premissa |
| `falloff_points` (distância em tiles, fração do dano principal) | (0,0 -> 0,60), (1,0 -> 0,60), (3,0 -> 0,0) | premissa |
| `main_target_fraction` | 1,0 | decidido |
| `max_extra_targets` | 3 | premissa (= foco de 4 menos o alvo principal) |
| `min_fraction` (abaixo disso não acerta) | 0,05 | premissa |
| `scale_torpor` (o torpor do golpe usa a mesma fração) | true | premissa |
| `hits_owner` / `hits_allies` / `hits_own_tamed` | false / false / false | premissa |
| `hits_hostile_player` | true | premissa |
| `hits_wild_of_other_group` | true quando o atacante é domado; false quando o atacante é selvagem | premissa |
| `skip_taming_in_progress` | true | premissa (ver abaixo) |
| `skip_unconscious_extra` | true | premissa |

Curva em palavras: o alvo principal leva 100%. Qualquer coisa a até 1 tile dele leva 60%. De 1 a 3 tiles cai em linha reta de 60% a 0%: a 2 tiles 30%, a 2,5 tiles 15%, a 3 tiles 0. Antes do corte do raio o `min_fraction` já descarta o que daria menos de 5% (a partir de ~2,83 tiles). O adjacente nunca chega a 100%, e o dano só cai conforme se afasta, como o dono pediu.

Fórmula: `fracao(d) = 0,60` se `d <= 1`; `0,60 x (3 - d) / 2` se `1 < d < 3`; `0` se `d >= 3`. `dano_no_alvo = dano_do_golpe x fracao(d)`, onde `d` é a distância entre o centro do alvo principal e o do alvo secundário, em tiles.

### Conta (para a curva não ficar mágica)
Com golpe de dano D, alvo principal no centro de um foco de 3 ou 4 (raio 3, simulação de 20.000 focos): a soma das frações dos adjacentes é em média **0,49 D** e no máximo **1,8 D**; o golpe causa em média 1,5 D no total e no máximo 2,8 D. Exemplo: D = 20 acerta o principal com 20, um vizinho a 1 tile com 12 e outro a 2 tiles com 6. Nunca passa de 4 alvos (principal + 3), mesmo bando cheio.

### Frases testáveis (área)

1. O alvo principal sofre 100% do dano e do torpor do golpe; nenhum alvo secundário sofre mais que 60%.
2. Um alvo secundário a distância `d` do principal sofre `fracao(d)` do dano; a distância maior nunca causa dano maior que a menor.
3. A distância 3 tiles ou mais, ou fração menor que 5%, não é acertada.
4. O golpe atinge no máximo 1 + `max_extra_targets` alvos; se há mais candidatos, valem os mais próximos do alvo principal (empate: id menor).
5. O dono, os aliados e os domados do mesmo dono nunca são acertados por área. Domado de OUTRO jogador só é acertado com a chave de servidor `pvp` ligada (padrão: desligada; decidido pelo dono em 08/11). Sem PvP, a área ignora esses domados.
6. Selvagem com área nunca acerta outro selvagem.
7. Selvagem que está sendo domado (`taming.is_active()`) e não é o alvo principal não é acertado: a área não derruba a Eficiência de um terceiro.
8. Jogador ou dino já inconsciente que não é o alvo principal não leva o golpe em área (a área não "devora" quem caiu).
9. O torpor aplicado a um secundário é o torpor do golpe multiplicado pela mesma `fracao(d)`; o dano em vida segue a mesma curva.
10. Alvo secundário que morre ou desmaia pelo golpe emite os mesmos eventos de um golpe direto.
11. Mudar `radius_tiles` ou `falloff_points` no `Resource` basta para mudar o alcance; nenhum número de área existe em código.

### O que muda por quem ataca
- **Triceratops selvagem** reagindo a agressão: acerta o jogador e o que for domado dele (revide do domado em Neutro também vale); não acerta selvagens.
- **Triceratops domado** em combate (revide em Neutro): acerta selvagens e agressores perto do alvo; não acerta o dono, aliados nem outros domados deles; domados de outro jogador só com `pvp` ligado.
- **Sem custo extra**: a área vem no mesmo golpe e recarga; o custo da escolha é posicional (bater num foco de 4 com o Triceratops rende ~2,5x de dano total).

## 5. O que o cálculo não prova (a validar jogando)

1. Se 24 focos de Paquicéfalo no mapa 256x256 dão sensação de "mundo vazio" entre eles (espaço médio entre focos de 24 a 30 tiles).
2. Se matilha de 3 Utahraptores com `share_alert` é injusta contra o Soco no nível 5 a 25; alternativa: máximo 2 ou `share_alert` desligado.
3. Se `radius_tiles` 3 e adjacente 60% deixam a área forte demais contra o foco de 4 do Paquicéfalo (domado Triceratops pode limpar o foco em poucos golpes). Alternativa: raio 2 ou adjacente 40%.
4. Se o pior caso de 8 na tela (dois focos de espécies diferentes) ainda parece "dinos demais".
5. Se o Dodo só na campina (sem praia) é suficiente ou se a praia ganha faixa de nível no `world_rules`.
6. Se 20 focos de Paquicéfalo com distância global 16 ainda deixam o mundo "vazio" entre bandos, ou se 16 é pouco para 'pulverizar' (subir para 20 custa o Dodo, ver 3.1); se respawn a 40 tiles do jogador é perceptível (bando "surge" ao virar a tela).
