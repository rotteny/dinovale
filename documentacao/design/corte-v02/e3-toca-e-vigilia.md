# E3: toca, âncora, ronda e vigília da doma (CRI-12 partes 1 e 2)

> **Decisões D-E1 a D-E10 aprovadas pelo dono em 08/11 (todas como recomendado).**

Spec da `SHIRO` para as etapas E3a e E3b do `shikamaru.md` (Bloco A). Base: leitura do código (`PredationSystem`, `WildPopulation`, `TamingComponent`, `Dino`, `DinoLevelRules`), do `lunata.json` e do `m1-ameaca-e-corpo.md` (seções 1 a 5, 10 e 11; **não editado aqui**). Sem horas de projeto: "s" e "tiles" são tempo e espaço de jogo.

Legenda: **[lido]** vem do código ou do dado de hoje; **[calculado]** conta feita aqui (scripts de biblioteca padrão, reproduzíveis); **[premissa]** número novo que o playtest ajusta em `.tres`; **[jogar]** só um teste com gente responde; **[decidir]** é do dono.

## 0. O que a leitura do código e do mapa mostrou (muda a spec)

1. **Não existe âncora hoje.** `cohesion_radius_tiles` só é usado no nascimento do bando (`WildLayout`); `DinoWanderState` sorteia direção livre. A "coleira do bando" citada no M1 seção 1 não está no código que li (`grep` por `leash`/`home`/`anchor` em `src/` não acha). A E3a cria a âncora do zero.
2. **O mapa tem 4 bandos de Utahraptor (g29 a g32, 10 animais) para 6 tocas**, com espaçamento mínimo de 40 tiles entre bandos. As tocas U2 e U6 ficam a 21 tiles uma da outra, U3 e U4 a 34, U3 e U5 a 33 [calculado]. Com 40 de espaçamento, no máximo 3 a 4 tocas hospedam bando. E o `shikamaru.md` E1 diz "6 a 11 Utahraptors", o que não fecha com 6 tocas e bando de 2 a 3 (12 a 18).
3. **U1 está a 4 tiles da zona segura** (U1 em y=148; a zona segura da predação começa em y=152, a Campina em y=160). A âncora de 24 tiles de U1 invade a Campina em até 12 tiles. **U6 está num tile de Campina** (terreno 3, enseada da costa; o Utahraptor só nasce em terreno 4) e só 47% do disco de 10 tiles ao redor é Mata; o resto é praia e água [calculado].
4. **"Campina" são duas coisas:** o terreno 3 (aparece também em bolsões da costa norte) e a região de respawn `campina` (retângulo y >= 160, `respawn_rules.tres`). A "zona segura" da predação usa o retângulo mais 8 tiles. Núcleo seguro tem de ser o retângulo, não o terreno.
5. **A mordida no dormindo já está pronta no `TamingComponent`:** `taming_rules.tres` tem `attack_fixed_loss` (carnívoro 8, herbívoro 6, jogador 4) e `loss_per_health_percent` 0,5, e `Dino.take_damage` chama `apply_attack` quando a criatura está em doma. Ou seja, **as perdas da tabela 11.1 saem de graça** assim que a mordida chega ao dormindo; o trabalho da E3b é a predação escolher o dormindo como alvo.
6. **O que bloqueia hoje** (`PredationSystem._prey_ok`): selvagem `UNCONSCIOUS` ou com `taming.is_active()` é recusado (D15). `_alarm` faria o dormindo "fugir" (precisa guarda). `allows_bite` aplica o piso de bando.
7. **A Ração Rubra não existe no código** (`grep` em `game/src` e `game/data` não acha; a doma usa `berry` em `taming_rules.tres`, e o Utahraptor pede `meat`). O "+4 tiles com Rubra" **fica de fora** (seção 2.1); o campo que o receberá já nasce em dado.
8. Atenção ao ler as contas: o dano do Utahraptor **escala por nível** (`DinoLevelRules.damage`, 8 em L10, 9,6 em L15, 11,2 em L20), mas a seção 4 do M1 trata a mordida como "8 fixo". E o Paquicéfalo L8 tem 92 de vida no código (base 100, fator 0,92), não os ~74 que a tabela 11.1 do `racao.md` implica. As contas abaixo usam o código.

## 1. E3a: toca, âncora e ronda

### 1.1 Regras (frases testáveis)

Perfil novo `HomeProfile` em `DinoBaseStats.home` (nulo = sem toca; espécie sem perfil se comporta como hoje). Números em `data/balance/home_rules.tres` (seção 3).

- **H1.** O bando nasce na toca: a vaga do mapa ganha o campo `"den": "U1"`; o centro do bando é a célula da toca (não mais sorteado). A célula de nascimento dos membros segue `cohesion_radius_tiles` (4) e `spawn_terrains` (4).
- **H2. Ronda de 10 tiles.** Sem alvo, o passeio natural só sorteia pontos a até `patrol_tiles` (10) do centro da toca, em tile andável e fora do núcleo seguro (H6). A decisão de andar a 40 px/s e parar 1 a 3 s não muda.
- **H3. Âncora de 24 tiles.** `anchor_tiles` (24) é o raio máximo do bicho em qualquer situação. Só vira **alvo novo** (jogador ou presa) quem está a até 24 tiles da toca, e o **caçador também tem de estar a até 24**. Alvo que passa de 24 tiles da toca encerra a perseguição (`released`, falha: presa entra no `fail_cooldown_s`, jogador não). O limite vale além dos já existentes (20 tiles do alvo, 15 s, 5 s sem visão): vale o que vier primeiro.
- **H4. Volta para a toca.** Ao largar um alvo por qualquer motivo (alvo morto, saiu da âncora, desistência, refeição acabada, nocauteado), cumpre o `alert_seconds` de 5 s que já existe e então **volta ao centro da toca a `return_speed_px_s` (60)** e retoma a ronda ao chegar a `patrol_tiles`. Durante a volta ele continua percebendo alvos (H3); a volta usa a prioridade "coleira" da fila do `PathProvider` (M1 seção 1, item 5).
- **H5. Saciado** (10.3 do M1) continua em ronda normal; **ainda ataca o jogador** (D13). A saciedade só tira a presa.
- **H6. Núcleo seguro único** (seção 1.2).
- **H7. Longe do jogador (modo "distante" da `DinoZone`, passo de 2 tiles a cada 2 s):** o passo também respeita H2 e H3 (barato: um teste de distância ao quadrado).
- **H8. Save:** nada novo. A toca vem do `den` da vaga (derivado do mapa); a volta e a ronda não são salvas (ao carregar, o bando está em ronda). O renascimento do bando (`group_respawn_seconds` 1200, folga de 40 tiles do jogador de `world_rules`) acontece na **mesma toca**; se há jogador a menos de 40 tiles, espera e tenta de novo (a lógica de `waiting` já existe).

### 1.2 Campina como núcleo seguro: unificar com a "zona segura de 8 tiles"

**Hoje:** `PredationSystem._in_safe_zone` = retângulo da região `campina` + `spawn_safe_margin_tiles` (8). Protege **só a presa** (não é elegível lá dentro). O caçador pode entrar.
**Proposta: unificar.** Um único teste `SafeCore.contains(point)` (retângulo da(s) região(ões) de respawn + `spawn_safe_margin_tiles`, **o mesmo dado de hoje**, sem segundo número) usado por três lugares:

1. presa não é elegível dentro dele (como já é);
2. nenhum caçador sorteia ponto de ronda nem nasce dentro dele;
3. perseguição **em curso** pára na borda (não entra); o alvo que está dentro dele deixa de ser candidato novo. O bicho larga, cumpre o alerta e volta (H4).

Por que o mesmo número resolve a defesa do jogador: a margem de 8 tiles é **igual à percepção do Utahraptor** (8 tiles; a vertical pesa 1,6, então 5 tiles em y). Um caçador na borda (y = 152) enxerga, no máximo, até y = 157; o jogador na Campina de verdade (y >= 160) nunca é percebido por quem está de fora [calculado]. Isso evita o exploit "bater de dentro da Campina com a Lança (alcance 1,8 tiles)": quem bate de dentro não foi visto e o bicho não entra. **Condição que o teste B6 trava:** `margem >= perception_tiles` de todo caçador; se alguém subir a percepção para 12, o teste falha e pede a margem junto.

**A diferença que sobra** é só de propósito: antes a margem protegia presa; agora protege presa, jogador e proíbe o caçador. Um dado, um teste, uma função.

**Efeito em U1:** a ronda de 10 tiles de U1 (y 138 a 158) fica cortada pela borda y = 152. **Recomendo mover U1 para (68, 136)** (16 tiles da borda: a ronda inteira cabe; o terreno de 10 tiles ao redor é 100% Mata [calculado]) e **U6 para (32, 130)** (terreno 4; o disco ainda é 53% litoral, a navegação já recusa água; decidir D-E1). Mexer em `lunata.json` muda `revision` e `content_hash` (regerar, como em E0).

### 1.3 Quanto do mapa a âncora cobre (a pergunta "a Mata fica vazia longe das tocas?")

Conta sobre os 6.978 tiles de Mata ao norte da borda (y < 152), com as 6 tocas [calculado]:

| Raio ao redor de uma toca | Mata coberta | Leitura |
|---|---|---|
| 10 (ronda) | 23% | onde ele **está** em repouso |
| 14 | 42% | |
| 16 | 53% | |
| **18 (ronda 10 + ronco 8)** | **65%** | onde a doma é **ouvida** (E3b) |
| 24 (âncora) | 91% | onde ele **pode chegar** perseguindo |

Com U1 movida, a cobertura muda pouco (U1 sai da borda; a diferença vai para dentro da Mata). Leitura: **a Mata não fica vazia**: 91% dela está na âncora; 35% dela é "fora do ronco" (a mais de 18 tiles de qualquer toca), e é aí que o jogador pode domar com folga. Risco de a Mata ficar *morna* e não vazia: o encontro espontâneo acontece em 23% (ronda) a 53% (ronda mais percepção) do mapa; o resto só se o jogador entrar na âncora. [jogar] se isso dá "perigo" ou "passeio".

### 1.4 Faixa de nível por toca

Hoje a Mata tem **uma** faixa, L5 a L25 (`world_rules.tres` `level_bands[4]`), sorteada por `roll_level(band, seed, member_id)`. Proposta: faixa por toca, crescente com a distância da partida (início em (140,196)); uma tabela em dado. `WildPopulation._build_member` usa a faixa da toca se a vaga tem `den`, senão a do terreno (sem mudar o Paquicéfalo).

| Toca | Distância do início (tiles) | Faixa [premissa] | Mordida (8 x fator) | Vida (80 x fator) | Bastão para nocautear (30 de torpor por golpe) |
|---|---|---|---|---|---|
| U1 | 87 | L5 a L10 | 6,4 a 8,0 | 64 a 80 | 4 golpes (2,8 s) |
| U4 | 110 | L8 a L14 | 7,4 a 9,3 | 74 a 93 | 4 a 5 |
| U6 | 128 | L10 a L16 | 8,0 a 9,9 | 80 a 99 | 4 a 5 |
| U2 | 131 | L12 a L18 | 8,6 a 10,6 | 86 a 106 | 5 |
| U5 | 137 | L14 a L22 | 9,3 a 11,8 | 93 a 118 | 5 |
| U3 | 144 | L18 a L25 | 10,6 a 12,8 | 106 a 128 | 5 a 6 (4,2 s) |

Conta que prende o teto: dois Utahraptors L25 com o Bastão custam ao jogador ~95 de 100 de vida (2 x 12,8 por 1,7 s; primeiro cai em 6 golpes, 4,2 s; segundo em mais 4,2 s) [calculado, limite superior: assume mordida contínua]. Sobrevive por pouco: é o topo certo. Bando de 3 em L15 já custa ~119 (letal): por isso o bando é de 2 (D-E2) e a decisão de "fugir" existe (a 120 px/s do sprint contra 90 do bicho, o jogador ganha 30 px/s; ele sai da âncora e o bicho larga).

**Reuso de dado, não de sistema:** `den_level_bands` num `.tres`; Paquicéfalo na Mata continua L5 a L25. Efeito colateral bom: **a Mata dá nível de Paquicéfalo maior que a Campina** (Campina L1 a L12, média ~6,5; Mata L5 a L25, média ~15): o jogador que quer o bônus de nível precisa sair do núcleo seguro e aceitar o ronco. Ver D-E7.

### 1.5 O que acontece com a predação fora da ronda (e dentro da âncora)

A predação (seção 10 do M1) **não muda de regra, muda de arena**:

- **Dentro da ronda (10)**: tudo como hoje; ele percebe a 8 tiles (elipse 8 x 5) e caça.
- **Entre 10 e 24 tiles da toca (excursão):** só existe porque ele foi atrás de um alvo. Pode continuar a perseguição e a caça; **não** escolhe alvo novo se o alvo está a mais de 24 da toca (H3). O `EAT` acontece onde a presa caiu; depois, volta (H4).
- **Presa fora da âncora:** não é candidata, mesmo a 5 tiles dele na borda (o carnívoro "não atravessa o mapa", como o dono mandou na seção 10, regra 1). Presa que foge para fora da âncora com ele no encalço: encerra a caça e entra no `fail_cooldown_s` (60 s).
- **Dentro do núcleo seguro:** nada caça, nada é caçado (1.2).
- **Domado do jogador como presa (D6):** mesma regra: só dentro da âncora. O risco de "levar o domado para perto de uma toca" ganha forma: **a 24 tiles de uma toca** [calculado: 91% da Mata].
- Consequência para o ecossistema (10.5): a pressão sobre os bandos de Paquicéfalo cai de "todo o raio ativo" para "bandos a até 24 tiles de uma toca": 91% da Mata, mas só 65% com ronco/encontro frequente. O piso de bando 2 e a reposição de 600 s seguem; o teste A29 continua valendo.

## 2. E3b: o carnívoro ataca o dormindo (vigília com ameaça)

**Princípio:** nenhum sistema paralelo. O dormindo em doma **vira um tipo de presa do `PredationSystem`**: mesma escolha de alvo (10.2), mesma trava, histerese, `EAT`, saciedade, `fail_cooldown_s`, log e save. A E3b acrescenta uma entrada na elegibilidade, uma fase de "!" e um drop de inventário.

### 2.1 Ronco

- **O ronco é do dormindo**: `snore_tiles` = 8 [premissa, GDD 11.2], círculo de 8 tiles (128 px) em volta do dino. **Círculo, não a elipse** da percepção: ele emite som, não é visto. Vale só para selvagem `UNCONSCIOUS` com `taming.is_active()`.
- **Bônus por comida: fora.** Rubra não existe; a regra "+4 tiles" **não entra**. O campo `snore_bonus_by_food: Dictionary[String, float]` fica em `TamingRules`, vazio, para a Ração Rubra (+4) entrar como uma linha de dado quando existir (`PRO-07`), sem tocar em código. A `berry` (única comida de doma de hoje) soma 0.
- **Quem escuta:** só caçador com `predation.hears_sleepers = true` (Utahraptor sim). `sleeper_range_cap_tiles` (0 = sem teto; o Semi do GDD 942 receberia 4 no dia em que tiver perfil de predação: o Triceratops hoje **não** tem `predation`, então fica fora desta etapa).
- **Alcance real:** `min(snore efetivo, teto)`, medido do caçador ao dormindo em linha reta (círculo).

### 2.2 Checagem, "!" e alvo

- **Checagem a cada 0,5 s:** é o `reevaluate_s` que já existe (0,5, com fase por id). O dormindo entra em `_collect_prey` como candidato quando o caçador está a até `snore` dele, fora do núcleo seguro e dentro da âncora do caçador (H3). **Não há segunda varredura** (custo da seção 10.6 do M1 intacto: o dormindo é só mais um elemento do conjunto ativo; o conjunto ativo é o mesmo de hoje).
- **Escolha:** o mais próximo entre o jogador (distância efetiva da elipse) e o dormindo (círculo), empate em 5% para o jogador (regra 2 da 10.2). Nota: a elipse pesa o eixo vertical 1,6x, então o jogador na vertical do bicho "parece" mais longe que o dormindo; deixa-se assim [jogar].
- **"!" de 1,5 s (`sleeper_alert_s`)**: ao **travar** um dormindo (toda trava nova, sem memória), o caçador entra em `SNIFF`: pára, vira para o dormindo, sinal `sleeper_alerted(hunter, prey)` (UI mostra "!" laranja, o mesmo `hunt_mark_color` da 10.4; som de farejar do `YATORA`). Passados 1,5 s, persegue o dormindo e morde pelo ciclo normal (aviso `windup_s` 0,3, recarga 1,5; 1,7 s por mordida, como a conta da 10.3 do M1). Só presa **dormindo** gera `SNIFF`: caçar presa acordada segue sem aviso (como é hoje).
- **Provocar muda o alvo (reuso do D7):** dano do jogador no caçador (`player_damage_count` muda) vira alvo o jogador e larga o dormindo. **Mudança pequena e importante:** no `SNIFF` e com alvo dormindo essa checagem roda **todo quadro**, não só a cada 0,5 s. Sem isso, uma pancada dada no instante exato da primeira mordida ainda deixa uma mordida passar (13,2 de Eficiência) antes de a reavaliação de 0,5 s ver o dano. O custo é uma comparação de inteiro por caçador.
- **Provocar não chama o bando** do dormindo e o dormindo não foge: `DinoStateMachine.provoke()` e `provoke_as_helper()` já recusam criatura em torpor [lido]; `_alarm` precisa de guarda (`UNCONSCIOUS` não chama `begin_flee`; o domado dormindo já tem essa regra no D16).
- **Quem já mordeu o jogador não troca para o dormindo** (regra 8) e **saciado não escolhe presa** (inclui o dormindo): a saciedade protege a vigília depois de um abate.

### 2.3 As perdas da tabela 11.1 (nada novo no `TamingComponent`)

A mordida chega por `Dino.be_bitten` → `take_damage(dano, "carnivore")` → `TamingComponent.apply_attack`: `E_perdida = 8 + 0,5 x (dano / vida máxima x 100)` [lido, `taming_rules.tres`]. O que a E3b garante é só o teste de que isso acontece com **mordida de caçador**, não só com golpe do jogador. Valores com o código de hoje [calculado]:

| Dormindo | Utahraptor | E por mordida | Mordidas até E=0 / até morrer | Tempo desde a 1ª mordida: 1 / 2 / 3 raptores até E=0 | até morrer |
|---|---|---|---|---|---|
| Paquicéfalo L8 (92 de vida) | L15 (9,6) | 13,2 | 8 / 10 | 11,9 / 5,1 / 3,4 s | 15,3 / 6,8 / 5,1 s |
| Paquicéfalo L8 | L10 (8,0) | 12,3 | 9 / 12 | 13,6 s (1) | 18,7 s (1) |
| Paquicéfalo L20 (140) | L20 (11,2) | 12,0 | 9 / 13 | 13,6 s (1) | 20,4 s (1) |
| Paquicéfalo L25 (160) | L25 (12,8) | 11,5 | 10 / 13 | 15,3 s (1) | 23,8 s (1) |

Isto **corrige a tabela 11.1** (que dava 14,5 de E, 7 mordidas, 10,5 s e 12 s para Paq L8 contra L15): o código dá 13,2, 8 mordidas, 11,9 s e 15,3 s, porque a vida do Paquicéfalo L8 é 92 e não ~74. A diferença é a favor do jogador (+3,4 s). O desenho continua: 1 raptor dá ~12 s, um bando de 2 dá ~5 s, de 3 dá ~3 s.

### 2.4 A doma que acaba na mordida (vida chega a 0)

- A doma **falha** (`TamingComponent._on_died` já faz: `has_failed`, zera progresso, emite `taming_failed`). A carcaça nasce e **o caçador come** (D10; o jogador pode interromper a refeição e pegar a sobra, 10.3).
- **A comida que estava no inventário do dormindo cai no chão.** O dormindo guarda a ração dada pelo jogador no inventário dele (`TamingComponent.food_available()` lê `inventory`). Reusa-se `PredationSystem._tamed_killed`, **extraído** para `_drop_inventory(victim)` (uma pilha por stack, 4 a 12 px do ponto da morte, 300 s, sem o teto de 24 por área; mesmo item de chão do D17). O que já foi consumido na doma está perdido (`racao.md` 11.3).
- **Log ao jogador que alimenta** (`Dino.feeder_player_id`, só a ele): `taming_attacked` WARNING na **primeira** mordida do episódio ("{name} está sendo atacado enquanto dorme.") e `taming_killed` DANGER ("A doma de {name} falhou: {species} o matou."). Dois códigos novos em `GameMessages`/`EVENTS` (teste A18 percorre).

### 2.5 O que muda no `PredationSystem` (lista fechada para o `SORA`)

1. `_prey_ok`: ramo novo para selvagem `UNCONSCIOUS` com `taming.is_active()` quando `rules.sleeper_is_prey` e o caçador `hears_sleepers`: elegível se dentro do ronco, fora do núcleo seguro, dentro da âncora, sem `fail_cooldown_s` **do próprio dormindo** (chave por `combat_id`, não por bando: o fracasso com um dormindo não pode imunizar o bando todo).
2. Piso de bando: **o dormindo em doma ignora o piso** (como o domado, D6). Sem isso, um bando de 2 deixa a doma imune. `allows_bite` ganha a mesma exceção.
3. `_collect_prey`: círculo para o dormindo, elipse para o resto. `_step_prey`: para o dormindo, "visível" é o círculo do ronco (senão o `unseen` de 5 s o libera por não estar na elipse).
4. Fase `SNIFF` no `Hunt` (campo `alert_left`), sinal `sleeper_alerted`, checagem de dano por quadro enquanto o alvo é dormindo.
5. `_alarm`: não foge se `UNCONSCIOUS`.
6. `_on_kill`: se a vítima é selvagem em doma, `_drop_inventory` + `taming_killed`.
7. `Dino.be_bitten`: confirmar (teste) que mordida em `UNCONSCIOUS` não chama `provoke` nem `provoked.emit`.
8. **A28 do M1 e o A32 mudam:** "em doma e nocauteado selvagem não são presa" vira "são, com as condições acima" (ver conflitos).

## 3. Números e a conta de quanto tempo o jogador tem para defender

### 3.1 Valores em `.tres` (todos [premissa], salvo [lido])

| Arquivo | Campo | Valor | Marca |
|---|---|---|---|
| `data/balance/home_rules.tres` (novo, `HomeRules`) | `anchor_tiles` | 24 | [premissa] (pedido do CRI-12) |
| | `patrol_tiles` | 10 | [premissa] (idem) |
| | `return_speed_px_s` | 60 | [premissa] (volta de 24 tiles em 6,4 s; a 40 seria 9,6 s) |
| | `den_level_bands` | tabela 1.4 | [premissa] |
| `data/dino/utahraptor_home.tres` (novo, `HomeProfile`) | usa `home_rules`; `uses_den` | verdadeiro | |
| `data/dino/utahraptor_predation.tres` | `hears_sleepers` | verdadeiro | [decidir D-E4] |
| | `sleeper_alert_s` | 1,5 | [premissa] (GDD 11.2) |
| | `sleeper_range_cap_tiles` | 0 (sem teto) | [premissa] |
| `data/balance/predation_rules.tres` | `sleeper_is_prey` | verdadeiro | [decidir D-E4] |
| | `sleeper_ignores_herd_floor` | verdadeiro | [decidir D-E4] |
| | `spawn_safe_margin_tiles` | 8 (**único número do núcleo seguro**) | [lido] |
| `data/balance/taming_rules.tres` | `snore_tiles` | 8 | [premissa] (GDD 11.2) |
| | `snore_bonus_by_food` | `{}` (Rubra: +4 quando existir) | |
| `lunata.json` | `spawn_slots[].den` | g29..g34 = U1..U6 | |
| `utahraptor.tres` | `min_group_spacing_tiles` | 40 para 20 (tocas a 21 tiles) | [premissa] |

**Auto-hospedagem e grupo:** `ServerRules` já expõe `carnivore_attack_fixed_loss` e `level_bands`; seguir o mesmo padrão para **`den_anchor_tiles`, `den_patrol_tiles`, `sleeper_snore_tiles`, `sleeper_alert_s`** (vazio = valor do `.tres`). Quem hospeda um grupo grande pode alargar o aviso ou encolher a âncora sem recompilar. (As chaves do GDD 13 que a E1 já lista não são alteradas; estas quatro entram junto.)

### 3.2 Probabilidade de o ronco ser ouvido durante a doma (Monte Carlo)

Modelo: raptor anda a 40 px/s (2,5 tiles/s) em passeios de 1 a 4 s e paradas de 1 a 3 s, preso à ronda de 10 tiles (mesma regra da H2); bando nasce a até 4 tiles do centro; o dormindo está a D tiles da toca; janela de 30 s (doma do Paquicéfalo: 5 refeições x 5 s = 25 s em L8; 6 em L15 = 30 s; 7 em L25 = 35 s) [lido `taming_rules`/`DinoLevelRules`]; 1.500 execuções por célula, semente fixa [calculado]:

| D (tiles da toca) | 1 raptor | 2 raptores | 3 raptores |
|---|---|---|---|
| 0 a 6 | 99% | 100% | 100% |
| 10 | 71% | 92% | 97% |
| 14 | 37% | 59% | 73% |
| 16 | 20% | 34% | 47% |
| 18 ou mais | 0% | 0% | 0% (só por excursão: H3) |

Leitura: **domar a menos de 10 tiles de uma toca é quase certeza de ser ouvido; a 16 é uma moeda viciada; a 18 ou mais, o ronco não alcança a ronda**. Isso é uma regra legível: "se vê a toca, vá para mais de 18 tiles". A condição para ser justo é o jogador **saber onde estão as tocas** (sprite da toca visível, pedido ao `YATORA`; ver pergunta Q3 do QA).

### 3.3 O relógio da defesa (Bastão-de-sono e Lança)

Cadeia do primeiro encontro, com o dormindo a 8 tiles do bicho no momento da trava (ele entra no ronco vindo de fora; a checagem de 0,5 s o pega entre 6,8 e 8 tiles) [calculado]:

| Fase | Tempo | Conta |
|---|---|---|
| Latência da checagem | 0 a 0,5 s | não conta no relógio do jogador (o "!" só aparece na trava) |
| "!" (`SNIFF`) | 1,5 s | `sleeper_alert_s` |
| Aproximação | 1,2 a 1,4 s (r = 6,8 a 8 tiles) | 6,8 x 16 / 90 = 1,2; 8 x 16 / 90 = 1,4 |
| `windup_s` | 0,3 s | M1 seção 4 |
| **Aviso total até a 1ª mordida** | **3,0 a 3,2 s** (2,0 s se o bicho já estava a 1 tile) | 1,5 + 1,2 a 1,4 + 0,3 |

Orçamento do jogador: reação 0,5 s [premissa] mais caminho até o bicho (que, no fim, está colado no dormindo). Sprint 120 px/s = 7,5 tiles/s; andando 70 px/s = 4,4 tiles/s:

| Aviso | Orçamento (aviso menos 0,5) | Distância máxima do jogador ao dormindo, correndo | andando |
|---|---|---|---|
| 3,2 s (raptor a 8 tiles) | 2,7 s | 20 tiles | 12 |
| 3,0 s (6,8 tiles) | 2,5 s | 19 | 11 |
| 2,0 s (raptor já perto) | 1,5 s | 11 | 7 |

Na doma o jogador está ao lado do dormindo (precisa dar a comida). **Então 1 raptor, com o jogador atento, sempre dá tempo de pegar o primeiro golpe antes da primeira mordida.** O custo da defesa está em depois:

| Ação | O que acontece | Custo |
|---|---|---|
| **Provocar com Bastão** (2 de dano, 30 de torpor, recarga 0,7 s) | bicho troca de alvo na hora (checagem por quadro); é nocauteado em 4 a 5 golpes (L10 a L20; 2,8 a 3,5 s) | 2 a 3 mordidas no jogador: ~19 a 29 de vida em L15 (9,6 por mordida) [calculado] |
| **Provocar e matar com Lança** (12 de dano, recarga 0,9 s) | 7 a 10 golpes (L10 a L20): 6,3 a 9 s | ~40 de vida em L15 contra 1 raptor; **a Lança é pior que o Bastão para defender**, serve para tirar o bicho do mapa (a população volta em 1200 s) |
| Ficar **entre** o bicho e o dormindo (sem bater) | só funciona **antes** de o bicho estar a 4 tiles do dormindo (regra 4 da 10.2, "em combate"); o jogador mais próximo vira alvo pela distância | sem custo, mas depende de leitura e de posição [jogar] |
| Bando de 2 raptors L15 (a conta 59 de vida com Bastão, limite superior) | a doma tem **5,1 s** até E=0 depois da 1ª mordida; a defesa de um raptor só abate **metade** das mordidas | com 2 raptores, aceitar perder Eficiência ou fugir com o isca; o Bastão sozinho não segura |
| Bando de 3 | 3,4 s até E=0; ~119 de vida no jogador com Bastão | **não se defende; ou se prepara (distância) ou se perde** |

Leitura do desenho: **1 raptor é defendível por quem presta atenção; 2 pedem ou ser rápido ou ter feito a doma longe; 3 não existem por decisão (bando de 2 por toca, D-E2)**. A tensão vem de **dois relógios**: o de 25 a 35 s da doma e o aviso de 3 s; sem o aviso de 3 s a vigília seria ruído, e sem o relógio de 30 s o jogador esperaria o bicho ir embora.

[jogar] se 3 s de aviso é leitura ou susto; se 11,9 s até E=0 com 1 raptor é "curto" demais para quem se distrai; se o "!" laranja é entendido como "vai atacar o dormindo" e não "vem para mim" (P8 do M1).

## 4. Aceite (critérios B1 em diante)

Não achei "B1+" definido em nenhum documento do repositório; adoto a mesma convenção do M1 ("A20 em diante"): **B1 em diante**, cada um um teste de unidade ou de cena headless, com espécies de teste (`tests/data/`) e **nenhum id de espécie no código** (o teste de arquitetura já vigia `utahraptor` e `placeholder_dino`).

**E3a**

| # | Critério |
|---|---|
| B1 | Ronda: espécie de teste com `HomeProfile`, 120 s de passeio com a toca em (X,Y): nenhum ponto de passeio a mais de 10 tiles; sem perfil o passeio é o de hoje. |
| B2 | Âncora: alvo a 23 tiles da toca é candidato; a 25 não é; caçada que cruza 24 encerra com `released(failed)`; jogador fugindo a 120 px/s contra 90 sai da âncora e o bicho larga em até `alert_seconds`. |
| B3 | Volta: depois de largar por qualquer um dos 6 motivos (morta a presa, fora da âncora, desistência, refeição, nocaute da presa, jogador morto), o caçador cumpre 5 s de alerta e chega à ronda a 60 px/s; durante a volta percebe alvo dentro da âncora. |
| B4 | Nascimento: vaga com `den` nasce com centro na célula da toca; membros em terreno 4 a até 4 tiles; renascimento na mesma toca; jogador a menos de 40 tiles adia (waiting). |
| B5 | Faixa por toca: 200 sorteios por toca ficam dentro da faixa da tabela 1.4; vaga sem `den` usa a do terreno. |
| B6 | Núcleo seguro único: `SafeCore.contains` é o mesmo que `_in_safe_zone` (um dado); caçador nunca nasce, passeia nem entra nele em 300 s de simulação, mesmo com o jogador na borda; **`margem >= perception_tiles` de todo caçador** (o teste falha se alguém subir a percepção sem a margem). Jogador a y >= 160 nunca é percebido por caçador a y <= 152. |
| B7 | Perseguição em curso que chega à borda larga e volta; Lança dada de dentro do núcleo não é percebida (B6) e, se atinge, o bicho larga e volta sem entrar. |
| B8 | Predação fora da ronda: presa a 5 tiles dele mas a 25 da toca não é elegível; presa que foge para fora da âncora encerra a caçada com `fail_cooldown_s`; domado do jogador a 25 tiles da toca não é presa. |

**E3b**

| # | Critério |
|---|---|
| B9 | Dormindo (selvagem `UNCONSCIOUS`, em doma) a 7,9 tiles de um caçador `hears_sleepers` vira alvo em até 0,5 s; a 8,1 não; acordado ou domado-dormindo seguem as regras de antes; espécie sem `hears_sleepers` (e o teste `test_carnivore_b` com teto 4) respeita o alcance. |
| B10 | `snore_bonus_by_food = {"x": 4}` no dado do teste sobe o alcance para 12; o padrão `{}` não muda nada (Rubra não está no jogo). |
| B11 | `SNIFF`: ao travar o dormindo o caçador pára por 1,5 s (sinal `sleeper_alerted` uma vez por trava) e a 1ª mordida só sai depois de 1,5 + aproximação + 0,3 s; presa acordada não gera `SNIFF`. |
| B12 | Provocar: dano do jogador durante o `SNIFF` ou no quadro anterior à mordida cancela o ataque no **mesmo quadro**; zero mordida no dormindo; o jogador vira alvo e o ciclo da seção 4 do M1 segue; sem dano do jogador, ele ignora o jogador em combate (regra 5). |
| B13 | Perdas: mordida de caçador no dormindo em doma tira Eficiência `8 + 0,5 x %vida` (Paq L8 com Utahraptor L15: 13,2 por mordida, 8 mordidas até E=0, 10 até a morte); acordado só tira vida; E=0 doma sem bônus (11.3). |
| B14 | Morte na doma: `taming_failed` emitido, carcaça comida pelo caçador, a ração que estava no inventário cai no chão (uma pilha por stack, 4 a 12 px, 300 s, ignora o teto de 24), `taming_killed` só ao `feeder_player_id`; `taming_attacked` uma vez por episódio. |
| B15 | Piso de bando: bando de 2 com 1 em doma e o outro acordado ainda é alvo (`sleeper_ignores_herd_floor`); com a flag desligada, não. Dormindo não foge, não chama bando e não provoca ( `provoked` não é emitido). |
| B16 | Um sistema só: `PredationSystem` é o único que escolhe alvo de caça; nenhum `Node` novo de IA; `tick` com 32 ativos e 6 caçadores continua < 0,3 ms [premissa, medir] (A30) e os testes de distância por reavaliação seguem <= P x A + P. |
| B17 | Saciado não trava dormindo; caçada ao dormindo não é salva; `sated_until` volta igual (A31). |
| B18 | Zero erro de script, `tools/check.sh` verde e **rodar o jogo** (`AGENTS.md`): domar um Paquicéfalo a 8 tiles de uma toca e ver o "!". |

## 5. Conflitos

**Com o M1 (`m1-ameaca-e-corpo.md`; não editado, o `SORA` está nele):**

1. **D15 é revertida de propósito.** Seção 10.1 (linha "Em doma ... continuam fora no M1"), D15 (10.9), conflito 8 e o critério **A32** ("em doma e nocauteado selvagem não") passam a dizer o contrário. O `SORA` ao implementar a E3b ajusta o texto do M1 e o teste A32 num só commit; **o nocauteado selvagem fora de doma ativa não existe** (nocauteado = em doma, `is_active` é "selvagem e dormindo").
2. **A "zona segura de 8 tiles" (D11/D12 e 10.5)** continua valendo para a presa e ganha duas funções (proíbe o caçador, protege o jogador); é o mesmo dado `spawn_safe_margin_tiles`. Nenhum teste A20 a A37 deve quebrar; A29 passa a incluir "caçador não entra".
3. **Seção 4, "mordida 8"** está desatualizada: no código é `8 x fator de nível` (9,6 em L15; 11,2 em L20), o que o M1 chamou de `[lido base_damage]`. As contas desta spec usam o fator.
4. **Seção 1 (fila do `PathProvider`) cita "volta à coleira do bando"**: não achei essa coleira no código; a E3a cria a volta à toca na mesma prioridade da fila.
5. **Percepção elíptica (10.2) x ronco circular:** a escolha "mais próximo" compara elipse com círculo. Assumido; ver [jogar] na 2.2.
6. **`chase_give_up_tiles` 20, `chase_max_seconds` 15, `alert_seconds` 5** não mudam; a âncora é um quarto limite.
7. **Utahraptor "solitário" do GDD 261** já está superado pelo bando de 2 a 3 (conflito 2 do M1); aqui o bando é de 2 por toca (D-E2).

**Com o GDD e o `racao.md`:**

8. **GDD 887 e `racao.md` 11.1:** "mata um Paquicéfalo L8 dormindo em 12 s, zera a Eficiência em 10,5 s" vira **15,3 s e 11,9 s** com a vida de 92 do código; a tabela de 11.1 ("14,5 de E, 7 ataques") usa ~74 de vida. O texto do GDD sai desatualizado; a conta é a do código.
9. **`racao.md` 11.1 diz Lança 18; o `.tres` tem 12** (`wooden_spear.tres`). Usei 12.
10. **GDD 942 (Semi ataca o dormindo só a 4 tiles):** o Triceratops não tem `predation` no código; **fica fora** da E3. O teto `sleeper_range_cap_tiles` existe para o dia em que tiver.
11. **GDD 11.2 "+4 tiles com Rubra":** fora, por não existir Rubra (2.1); entra por dado em `PRO-07`.
12. **`shikamaru.md` E1 ("6 a 11 Utahraptors nas 6 tocas")** não fecha com o bando de 2 a 3 por toca; ver D-E2.
13. **GDD 11.2/GDD 887 falam em "curral" como defesa (c)**: não há curral nesta etapa (depende de construção, E8+). A defesa do jogador é provocar, matar ou escolher o lugar (a 18 tiles ou mais da toca).

## 6. Decisões do dono (cada uma com a recomendação)

- **D-E1. Mover U1 para (68,136) e U6 para (32,130) no `lunata.json`.** Recomendo **sim**: U1 a 4 tiles da zona segura cortaria a ronda ao meio e invadiria a Campina; U6 está num tile de Campina e o bando não nasce lá. Custo: regerar `content_hash` e `revision`. Alternativa: manter e deixar a borda cortar a ronda de U1 (bando fica espremido, vira "bicho parado na borda").
- **D-E2. Um bando por toca, de 2 raptores (12 no total), espaçamento mínimo 20.** Recomendo **sim** e corrigir o "6 a 11" do E1 para 12. Conta: bando de 3 L15 custa ~119 de vida ao jogador com Bastão (letal) e 3 s de janela até E=0; bando de 2 custa ~59 e deixa 5 s. Alternativas: 4 bandos nas 4 tocas com ≥40 de distância (10 raptores; 2 tocas vazias, o mapa tem 2 "tocas fantasma" sem bicho) ou bando de 1 (viola o mínimo de 2 da espécie e anula a lógica de `HerdCall`).
- **D-E3. Núcleo seguro único (retângulo + 8, um dado), o caçador não entra e a perseguição para na borda.** Recomendo **sim**. Preço: o jogador pode "se esconder" na Campina de qualquer perseguição (aceitável: é o tutorial e o refúgio decidido em D30). Alternativa: deixar o caçador entrar até 4 tiles (cria o exploit de bater de dentro).
- **D-E4. Reverter o D15: o dormindo em doma é presa, sem piso de bando.** Recomendo **sim e sim**: sem a ameaça, a vigília é barra de progresso e o QA-01a perde a pergunta 1. Flags `sleeper_is_prey` e `sleeper_ignores_herd_floor` permitem desligar no servidor ou no playtest sem código. Alternativa: manter o piso (bando de 2 deixa a doma imune) ou deixar o dormindo protegido (volta ao M1).
- **D-E5. Faixa de nível por toca (tabela 1.4).** Recomendo **sim**: sem ela a primeira toca pode ter L25 e o jogador de L1 morre sem pista. Alternativa: faixa única da Mata (5 a 25), que é o que existe.
- **D-E6. "!" em toda trava de dormindo, sempre 1,5 s.** Recomendo **sim**. Alternativa: 1,5 s só na primeira trava do episódio; economiza aviso, tira justiça.
- **D-E7. A Campina continua sem ameaça na doma.** Recomendo **sim**: a Campina é o tutorial e o refúgio; o incentivo para sair é o nível (Paq da Mata média L15 contra L6,5 da Campina, bônus de Eficiência 100% sobre L15 = +50% de nível). Risco [jogar]: quem doma sempre na Campina nunca vê ameaça e o QA-01a mede "tensão da vigília" só com quem sair; aceito.
- **D-E8. Mordida no dormindo não chama bando e não provoca.** Recomendo **sim**: a vigília é um duelo entre o jogador e o raptor. Se o dono quiser "o bando acorda e revida", é Etapa nova (a conta do revide, 2,25 por s por atacante, não chega a tempo: 16 s para 25% de vida do bicho contra 15 s para o dormindo morrer).
- **D-E9. Rubra fica fora; entra por `snore_bonus_by_food`.** Recomendo **sim** (não construir o que não existe). 
- **D-E10. Velocidade da volta a 60 px/s.** Recomendo **sim**; ajustável em dado. Alternativa 40 (natural): 9,6 s de bicho exposto no caminho de volta.

## 7. Etapas para o `SORA` (duas, na ordem do `shikamaru.md`)

**E3a. Toca, âncora, ronda e núcleo seguro.** `HomeProfile`/`HomeRules` em `.tres`; campo `den` em `spawn_slots` (leitura em `IslandMap._read_slots`, validação de terreno 4, ids únicos) e `WildLayout`/`WildPopulation` com centro na toca e faixa por toca; ronda no `DinoWanderState` e volta à toca (prioridade "coleira" do `PathProvider`); âncora nos candidatos de `PredationSystem`; `SafeCore` unificando `_in_safe_zone`; movimento de U1 e U6 e as 6 vagas (se D-E1/D-E2 aprovados); teto de dado em `ServerRules`. Testes B1 a B8. Uma tarefa de dado do mapa e uma de IA: respeita "no máximo 2 tarefas de código".

**E3b. Dormindo como presa.** Seção 2.5 inteira (`_prey_ok`, `_collect_prey`, `SNIFF`, `_alarm`, `_on_kill` com `_drop_inventory`, `allows_bite`), `snore_tiles`/`snore_bonus_by_food` em `TamingRules`, `sleeper_*` em `PredationRules`/`utahraptor_predation.tres`, códigos `taming_attacked`/`taming_killed`, e o ajuste do texto do M1 e do A32. Testes B9 a B18. **Pedido ao `YATORA`:** "!" laranja sobre o caçador e som de farejar; sprite/marca da toca visível no mapa (sem isso Q3 falha).

## 8. O que o QA-01a precisa medir (seção 2 do `shikamaru.md`)

O QA-01a responde 5 perguntas; esta etapa alimenta **a 1 (a vigília tem tensão?)** e **a 4 (a Campina funciona como núcleo seguro?)**. O jogo precisa **registrar** (linha por evento, sem dado pessoal, mesmo formato do roteiro do M1): `sleeper_alerted`, `sleeper_bite` (E e vida perdidas), `sleeper_released` (motivo: provocado, morto, saciado, âncora, tempo), `taming_failed_by_hunter`, `den_return`, `core_stop` (perseguição parada na borda), e por doma: posição, distância à toca mais próxima, nível do Paquicéfalo, raptores envolvidos, Eficiência final.

| # | Pergunta | Métrica | Faixa que eu consideraria "funciona" [premissa] |
|---|---|---|---|
| Q1 | A vigília tem tensão? | % das domas feitas na Mata a menos de 18 tiles de toca com "!" | 30% a 70% (a conta do Monte Carlo dá 60 a 100% a até 14 tiles) |
| Q2 | O "!" é entendido? | tempo do "!" ao primeiro golpe do jogador; % que reage antes da 1ª mordida | mediana 1,0 a 2,5 s; 70% reage antes |
| Q3 | O jogador sabe onde estão as tocas? | % que doma a mais de 18 tiles **depois** de levar um ataque; % que cita a toca no formulário | maioria muda de lugar na 2ª doma |
| Q4 | A defesa custa, mas é possível? | Eficiência média perdida por doma atacada; % de morte do dormindo; vida perdida do jogador na defesa | perda 10 a 40 de E; mortes < 15%; vida do jogador < 40 com 1 raptor |
| Q5 | O Bastão ou a Lança? | arma usada para provocar; tempo até o nocaute ou a morte | Bastão em maioria (a conta diz que é o melhor) |
| Q6 | Campina como núcleo seguro funciona? | encontros com Utahraptor dentro de y >= 152: **tem de ser 0**; % que atravessa sem ser atacado; jogador usando a borda como esconderijo | 0 encontros; esconderijo não vira exploit sistemático |
| Q7 | A Mata é "vazia" ou "morna" longe das tocas? | tempo de caminhada sem ver bicho; encontros por 10 min por distância da toca | 1 a 3 encontros por 10 min dentro de 18 tiles; 0 a mais de 24 |
| Q8 | A volta à toca é legível? | % que vê o bicho voltando e entende que "acabou"; ressurgência de ataque imediato | sem "o bicho voltou do nada" |
| Q9 | Perdas na doma desmotivam? | abandono da doma após falha; tentativas de nova doma na mesma sessão | maioria tenta de novo |

**Só um teste com gente responde (não calculei):** se 3 s de aviso é leitura ou susto, se 11,9 s até E=0 é justo, se a Mata fica morna, se o jogador percebe a toca sem texto, se "ficar entre o raptor e o dormindo" é descoberto sem ensinar.

## 9. Calculado x precisa jogar

**Calculado:** cobertura da âncora e da ronda (1.3), faixas por toca (1.4), Eficiência e vida por mordida (2.3), cadeia de aviso (3.3), custo de defesa por arma (3.3, limite superior), probabilidade de ronco (3.2, simulação simplificada: passeio aleatório sem obstáculos).
**Premissa:** todos os números da tabela 3.1 e a reação de 0,5 s do jogador.
**Só jogar:** itens acima e o QA-01a.
