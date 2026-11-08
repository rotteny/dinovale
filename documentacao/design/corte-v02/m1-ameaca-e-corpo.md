# M1 "Ameaça e corpo": especificação para implementação

Escrito pela `SHIRO` em 08/11 para o `SORA` implementar em etapas (seção 8). Não altera o GDD, o plano nem `decisoes-0611-0711.md`; onde há atrito com eles, aparece como **CONFLITO** (seção 9), sem resolução.

Legenda: **[decidido]** é palavra do dono; **[premissa]** é número da equipe que vale até o playtest; **[calculado]** saiu de conta (script de simulação com biblioteca padrão, resultados nas tabelas); **[lido]** é o valor que já está no código ou no dado; **[jogar]** só playtest responde. A conta prova consistência, não diversão.

Regra do `AGENTS.md` que molda tudo aqui: todo número abaixo vai para `Resource` (`.tres`), nunca para o código. Proposta de dados novos:

| Dado | Arquivo | Conteúdo |
|---|---|---|
| `NavigationRules` | `data/balance/navigation_rules.tres` | grade, folgas por porte, orçamento, preso |
| `AggressionRules` | `data/balance/aggression_rules.tres` | tempo para acalmar, alcances de chamada, cores do sinal |
| `ThreatProfile` | `data/dino/threat/<especie>.tres` | velocidades natural e brava, ameaça, ciclo, ataque, revide, bando |
| `DownedRules` | `data/balance/downed_rules.tres` | desmaio, vida do caído, quem ataca o caído, corpo |

Valores de lido hoje: dino anda a 40 px/s (`Dino.move_speed`); Utahraptor persegue a 90, percepção 8 tiles, desiste a 20 tiles ou 15 s, alerta 5 s (`utahraptor.tres`); `chase_stop_px` 28; jogador anda a 70 e corre a 120 por 4 s (`Player.gd`, GDD 5); vida do jogador 100 (`HealthComponent`); tela 320x180 = 20 x 11,25 tiles de 16 px; Paquicéfalo `base_damage` 4 e Utahraptor 8, sem escala por nível (`DinoLevelRules` só escala vida, torpor, refeições e carcaça).

---

## 1. Navegação do domado e dos selvagens

### Regras (frases testáveis)

1. `PathProvider` é uma interface (`request_path(from, to, size_class) -> PathResult`, `invalidate(cell)`). Quem usa não conhece o algoritmo. A implementação recomendada é `AStarGrid2D` do Godot (nativo, sem dependência nova); a alternativa é A* em GDScript atrás da mesma interface. O A* nativo não tem limite de nós por consulta: o teto vira "pedidos por quadro" e "distância máxima do pedido". Se a etapa 1 medir e o nativo não couber, vale o A* em GDScript com orçamento de nós (valores abaixo).
2. A grade é a do mapa: tile de 16 px, 256x256 = 65.536 células [lido]. Bloqueia: água (fundo e raso), árvore e rocha de nó de recurso **que ainda existem**, cenário sólido, estrutura (quando houver). Nó esgotado libera a célula; nó que volta bloqueia de novo; ambos chamam `invalidate(cell)` e todo caminho que passa pela célula é recalculado.
3. Folga por porte (decidido em 07/11: só 3 portes). O corpo tem de caber no caminho, e o caminho passa pelo centro da célula:

| Porte | `clearance_tiles` | Por quê |
|---|---|---|
| Pequeno | 0 | corpo menor que 1 tile |
| Médio | 0 [provisório 08/11] | Médio é do tamanho do humano (GDD:87, 16x32): usa a MESMA folga do jogador e passa onde ele passa. Era 1 [premissa]: medido no mapa real, só 42% do terreno ficava aberto ao Médio (maior região 39% disso), e a mata a 29%. Colisão dos pés do Paquicéfalo é 24x16, maior que 14 px: pode travar onde o A* manda passar (a conferir jogando) |
| Grande | 1 [provisório 08/11] | maior que um humano; vão de 1 ou 2 tiles é recusado, 3 passa. Era 2 [premissa] (só 11% do terreno aberto) |

   Uma grade por valor de folga (3 grades, 196 mil células, sem custo relevante de memória [calculado]).
4. Movimento 8 direções, sem cortar quina (diagonal só se as duas ortogonais estiverem livres), heurística octogonal. O corpo continua colidindo de verdade; o caminho só guia.
5. Quem pede caminho: perseguição (Agressivo e revide), seguir do domado, fuga, volta à coleira do bando. **Passeio natural não usa A\***: sorteia um ponto dentro do raio de coesão (3 a 4 tiles) e anda em linha reta; se a linha bate em célula bloqueada, sorteia outro (até 3 vezes) e fica parado pastando. Isso tira a maior parte dos pedidos.
6. Replanejar: a cada `repath_interval_s` com o alvo em movimento e só se o alvo andou mais de 2 tiles do fim do caminho; imediatamente se `invalidate` tocou o caminho; e quando travar (regra 8).
7. Pedido acima de `max_request_tiles` (48, mais que duas telas) é recusado: o dino anda em linha reta até a distância cair, ou desiste. Pedido sem caminho conta como falha de caminho.

### Números (`NavigationRules`)

| Campo | Valor | Marca |
|---|---|---|
| `tile_px` | 16 | [lido] |
| `max_request_tiles` | 48 | [premissa] |
| `repath_interval_s` | 0,5 (A* nativo) ou 1,0 (GDScript) | [premissa] |
| `max_requests_per_frame` | 3 | [premissa] |
| `max_expanded_nodes_per_search` | 400 (só GDScript) | [premissa] |
| `node_budget_per_frame` | 300 nativo, 60 GDScript (só GDScript) | [premissa, medir na etapa 1] |
| prioridade da fila | perseguição > seguir do domado > fuga > coleira | [premissa] |

**Conta do orçamento para 32 ativos** [calculado]: no pior caso os 32 pedem a cada 0,5 s = 64 pedidos/s = 1,07 por quadro a 60 fps. Caminho de 20 tiles em terreno aberto expande cerca de 20 a 60 nós (A* com heurística octogonal anda quase reto); com árvore no meio sobe a 100 a 200; teto de 400. Média 60 nós x 1,07 = 64 nós/quadro; pior 400 x 1,07 = 428 nós/quadro. Com orçamento de 300 e fila, o pior caso atrasa o pedido em 1 a 2 quadros (menos de 35 ms), invisível. Em GDScript, a 30 µs por nó [premissa, não medido], 60 nós/quadro = 1,8 ms: é o que cabe em 16,6 ms junto do resto, e então o repath sobe para 1,0 s (32 nós/quadro de média). O nativo custa uma ordem de grandeza menos por nó [premissa]: é por isso que o recomendo, **mas a etapa 1 mede antes de decidir** (critério: consulta de pior caso de 48 tiles em até 1 ms no nativo; tick de 32 dinos abaixo de 2 ms).

### Travar e desistir

Dino "quer andar" quando tem destino e não está em pausa de ataque. Está travado quando, em `stuck_check_seconds` = 1,0 s [premissa], avançou menos de `stuck_min_progress_px` = 6 px na direção do próximo ponto (a 40 px/s esperados são 40 px: 15% do esperado) [premissa].

Linha do tempo, tudo em dado:

| Tempo sem progresso | Ação |
|---|---|
| 1,0 s | replaneja; marca como bloqueada, por 5 s, a célula à frente do corpo (o caminho novo contorna) |
| 2,0 s | replaneja de novo, agora com folga de porte +1 |
| 3,0 s | **preso** (`stuck_give_up_seconds` = 3,0 [premissa]) |

Pedido sem caminho: tenta de novo 1 s depois; segunda falha também é preso.

**Preso, selvagem:** o Agressivo desiste da perseguição (já existe) e fica em alerta; o Passivo para de revidar e acalma; nada vai ao log.

**Preso, domado [decidido 08/11 pelo dono]:** se está **longe do dono e fora da tela**, ele **desiste, fica parado, o log diz "<nome> ficou preso" e não há teleporte**. Definição:

- "longe": a mais de `stuck_far_tiles` = 14 do dono [premissa]. A meia-diagonal da tela é raiz(10² + 5,6²) = 11,5 tiles [calculado]; 14 deixa 2,5 tiles de folga.
- "fora da tela": fora do retângulo da câmera (20 x 11,25 tiles) mais `stuck_offscreen_margin_tiles` = 2 [premissa], para ninguém ver o dino sumir do log com ele ainda visível na borda.
- Se está perto ou na tela, continua tentando: replaneja a cada 2 s, sem log (o jogador vê e pode ajudar, por exemplo derrubando a árvore).
- Preso e parado: a ordem continua Seguir, mas ele só tenta de novo quando (a) o jogador dá nova ordem ou aperta G, ou (b) o dono volta a menos de 14 tiles ou à tela, com intervalo mínimo de 5 s entre tentativas [premissa]. A tentativa que anda 4 tiles limpa o estado.
- O log escreve **uma vez** por episódio (`tamed_stuck`); só rearma depois que o dino andar 4 tiles.

---

## 2. Estado de agressão e "acalmar"

### Estado

`aggressive` (bravo) é um estado ortogonal ao comportamento natural, não um tipo novo de Conduta. Entra: ser golpeado (Passivo), avistar o alvo (Agressivo, pela percepção que já existe) ou ser chamado pelo bando (seção 3). Sai quando **8 s [decidido: "cerca de 8 s"] se passam sem dar nem receber dano**; ao sair, o dino esquece o alvo e volta ao natural: **sem rancor**, sem memória de quem bateu, o próximo golpe é um episódio novo. Dormir (torpor) e ser domado também encerram.

Dois atalhos já existentes no GDD 6.7 continuam como [premissa]: atacante a mais de 12 tiles por 5 s acalma o Passivo; Agressivo desiste a 20 tiles, 5 s sem visão ou 15 s (ver CONFLITO 5). Quando o Agressivo desiste, o alerta é o do dado (5 s hoje; 20 s só no caso "alcançou sem poder atacar", decisão 08/11, que vira exceção do ataque ao entrar a mordida).

### Sinal visual (só apresentação; a lógica expõe `is_aggressive` e o sinal `aggression_changed`)

- "!" vermelho sobre a cabeça enquanto bravo, visível em qualquer distância dentro da tela [premissa]. Some ao acalmar.
- "Nv N" (decidido: aparece a 6 tiles, só acordado e vivo) fica avermelhado enquanto bravo. Cor de perigo da paleta do HUD (a mesma do número de dano) [premissa]; o valor é `AggressionRules.alert_color`.
- Cabeça baixa, raspar o pé e grunhido têm sprite e áudio da espécie (pedido ao `YATORA`/`SORA` de arte e som: pendência, ver seção 8, etapa 4).

### Movimento natural x bravo

| | Natural | Bravo |
|---|---|---|
| Velocidade Paquicéfalo | 40 px/s [lido] | 80 px/s (x2,0) [premissa] |
| Velocidade Utahraptor | 40 px/s [lido] | 90 px/s [lido] |
| Rumo | passeia 1 a 4 s e pasta parado [lido `wander_seconds`] | encara o alvo, rodeia, investe |
| Percepção | olha | trava no alvo |

Por que 80 e 90: o jogador anda a 70 e corre a 120 por 4 s. Bravo mais rápido que o andar obriga a decisão "corro e gasto o fôlego" ou "luto". Simulação de fuga em linha reta, sem obstáculo [calculado]:

| Caso | Resultado |
|---|---|
| Raptor (90), jogador corre 4 s e depois anda, partindo a 3 tiles | alcançado aos 11,2 s |
| idem, partindo a 5 tiles | alcançado aos 12,8 s |
| idem, partindo a 8 tiles | o raptor desiste aos 15 s a **1,9 tiles** de distância (30 px, igual ao alcance da mordida) |
| Paquicéfalo bravo (80), partindo a 3 tiles, desiste em 12 s | desiste aos 8,2 s |

Leitura: fugir do raptor só dá certo de longe, em linha reta, com margem de um quadro. Com obstáculo no caminho ele ganha, e o jogador fica sem saída além de lutar (nocautear) ou subir em algo. Isso é intencional para uma ameaça "Essencial", mas é o primeiro candidato a ajuste no playtest [jogar].

### Ciclo encara, rodeia, investe (genérico, dado por espécie)

| Fase | O que acontece | Duração |
|---|---|---|
| `THREAT` | para, vira para o alvo; **grunhido no quadro 0**; cabeça baixa; raspa o pé 2 vezes | `threat_seconds` |
| `APPROACH` | corre ao raio de rodeio com o caminho do `PathProvider` | até chegar |
| `CIRCLE` | gira ao redor do alvo a 0,6x da velocidade brava | `circle_seconds` (sorteio dentro da faixa) |
| `WINDUP` | trava a direção e abaixa o corpo | `windup_s` |
| `LUNGE` | investida em linha reta | até `lunge_max_s` ou contato |
| `RECOVER` | afasta ou para; só ataca de novo na recarga | resto da recarga |

`THREAT` só ocorre **na entrada do episódio**, não a cada investida (senão o ciclo vira tabela de espera). Valores por espécie na seção 3 e 4.

---

## 3. Revide do Paquicéfalo (Passivo) e o bando

Hoje o Paquicéfalo não revida [lido; decisão 08/11 diz que revide e bando são do M1].

### Cabeçada (`ThreatProfile` do Paquicéfalo)

| Campo | Valor | Marca |
|---|---|---|
| `threat_seconds` | 0,8 | [premissa] |
| `circle_seconds` | 0,8 a 1,5 | [premissa] |
| `circle_radius_tiles` | 3,0 | [premissa] |
| `windup_s` | 0,5 | [premissa] |
| `lunge_speed_px_s` / `lunge_max_s` | 150 / 0,3 (cobre 45 px = 2,8 tiles) | [premissa] |
| `attack_reach_px` | 26 | [premissa] |
| `damage` | **6** (o dado de hoje é `base_damage` = 4) | [premissa] |
| `cooldown_s` | 1,6 | [premissa] |
| `knockback_px` | 24 (1,5 tile) em 0,15 s, para no primeiro obstáculo; não empurra caído | [premissa] |
| `attacker_kind` | `herbivore` (já existe em `TamingRules`) | [lido] |

Por que 6: com 4, o bando inteiro tira 4 a 5% da vida por investida e o revide é cosmético. O objetivo é que atacar o bando custe uma fatia visível da vida (um terço no fim de 8 s de contato) e nunca mate o jogador de pé [calculado abaixo].

### O bando ajuda

Bandos de 3 a 4 [decidido; `bandos-e-dano-em-area.md`]. O tamanho é dado de espécie; as regras abaixo são só dado:

| Campo | Valor | Marca |
|---|---|---|
| `call_radius_tiles` | 8 | [lido GDD 6.7] |
| `call_delay_s` | 0,5 | [lido GDD 6.7] |
| `max_helpers` | 2 | [premissa] |
| `helper_max_seconds` | 12 | [premissa] |

- Quando um membro é **golpeado**, todos os membros acordados, vivos, não domados, da **mesma espécie e a até 8 tiles do golpeado** viram candidatos; entram os `max_helpers` mais próximos do jogador, 0,5 s depois, com `THREAT` próprio (então o primeiro ajudante acerta a partir de cerca de 1,3 s + trajeto).
- Bando de 3: os 2 outros entram (3 contra o jogador). Bando de 4: entram os 2 mais próximos, o 4º continua pastando em alerta (olha, não anda). Por quê: limitar o pico de dano quando o jogador escolheu o dino errado.
- Dormindo ou domado não ajuda. Quem já está bravo não é chamado de novo.
- O ajudante usa a mesma regra de acalmar: 8 s sem dano dado ou recebido, mais o teto `helper_max_seconds` = 12 s contado a partir da entrada. Se ele mesmo é golpeado, vira principal (relógio de 8 s dele, sem teto).
- A chamada é por evento de golpe, não por visão. Passivo não tem `share_alert` de visão (ele só olha).
- Nenhum ataque de bando atinge outro dino (sem fogo amigo; só o jogador é alvo no M1).

**Dano esperado do revide** (jogador de pé, contato contínuo, `damage` 6, recarga 1,6 s, o ciclo gasta 40% do tempo em rodeio e ameaça, ou seja, tempo útil de 0,6 [premissa]; os ajudantes começam 2 s depois) [calculado]:

| Atacantes | Dano em 8 s de contato | Dano durante os 4 golpes de Bastão (2,8 s) |
|---|---|---|
| 1 (só o golpeado) | 18 | 6 |
| 2 | 30 | 6 |
| 3 (bando de 3, ou limite com `max_helpers` 2) | 42 | 6 |
| 4 (sem o limite, só para comparar) | 54 | 6 |

Leitura: no tutorial (4 golpes de Bastão em 2,8 s) o nocaute acontece antes de qualquer ajudante chegar; o custo real aparece **depois**, com 2 a 3 Paquicéfalos bravos ao redor do dormindo e o jogador querendo alimentar. Em 8 s o jogador perde até 42 de 100, e eles acalmam em 8 s ou 12 s, então é viável esperar ou afastar. Isso pode ser pesado demais para a primeira doma [jogar] (pergunta P2).

### Quando o Passivo foge em vez de revidar

1. Vida abaixo de 25% (GDD 6.7, linha 939): foge a velocidade brava, sem revidar; volta ao natural 10 s depois com o atacante a mais de 10 tiles (já escrito no GDD).
2. Faixa de torpor 3 (acima de 75%): não revida (já tem lentidão x0,65 e pausas) e foge se o atacante estiver a menos de 3 tiles [premissa]. Dormindo, não faz nada.
3. Bando de 1 sobrevivente (os outros mortos ou domados): revida só se golpeado, sem ajuda; nada novo.

Com Bastão (dano 2), o limite de 25% de vida quase nunca é atingido; só vale com a Lança, que no M1 é build de desenvolvimento [lido, decisões 08/11]. Fica como regra sem uso comum no M1.

---

## 4. Ataque do Utahraptor (Agressivo)

Já existe a perseguição (90 px/s, percepção elíptica 8 x 5 tiles, desiste a 20 tiles, 5 s sem visão ou 15 s) e a distância mínima de 28 px para "quem persegue sem poder atacar" (decisão 08/11). Agora o Utahraptor pode atacar, então o `chase_stop_px` não vale para ele: ele fecha até o alcance da mordida.

| Campo | Valor | Marca |
|---|---|---|
| `threat_seconds` (só na entrada do episódio) | 0,8 | [premissa, ver CONFLITO 3] |
| `circle_seconds` | 0,5 a 1,0 | [premissa] |
| `circle_radius_tiles` | 2,5 | [premissa] |
| `windup_s` | 0,3 | [premissa] |
| `lunge_speed_px_s` / `lunge_max_s` | 0 (sem investida: ele já chega a 90) | [premissa] |
| `attack_reach_px` | 30 (igual ao 28 px do `chase_stop_px` + 2) | [premissa] |
| `damage` | **8** | [lido `base_damage`] |
| `cooldown_s` | 1,5 | [lido GDD 6.1b, linha 261] |
| `knockback_px` | 0 | [premissa] |
| `attacker_kind` | `carnivore` | [lido] |
| `attacks_downed` | verdadeiro | [decidido: morte só por dino sobre o caído] |

- A mordida só sai com o alvo dentro de `attack_reach_px` e depois do `windup_s`; sem alvo no alcance no fim do aviso, a mordida "erra" e a recarga corre inteira.
- Desistência, como hoje: alvo além de 20 tiles, 5 s sem visão, 15 s de perseguição (`chase_max_seconds`), ou 3 s preso (seção 1). Alerta de 5 s depois.
- Tempo de vida do jogador sob mordida contínua, sem nocaute [calculado]: vida 100 + vida do caído 70 (seção 5) = 170; 22 mordidas; 1 raptor = 31,5 s de contato; 2 = 15,8 s; 3 = 10,5 s. O nocaute com Bastão derruba o raptor em 5 golpes (3,5 s) no L20 (GDD 6.1b), com 2 a 3 mordidas no caminho (16 a 24 de vida) [calculado]; é a saída esperada contra 1. Contra bando de 2 a 3, a saída é fugir ou perder.
- Utahraptor mira também o dormindo e o domado, mas isso é M2 (CRI-12); no M1 só o jogador é alvo [lido plano, linha 259].
- O Agressivo "ataca ao avistar" (GDD 934): o aviso de 0,8 s é o jogador ouvir o grunhido e ver "!" antes da mordida. Com a percepção de 8 tiles a 90 px/s, o raptor leva 1,4 s para chegar (128 px / 90) [calculado]: o aviso corre durante a corrida de aproximação quando o alvo está longe, e só é pausa quando o alvo já está perto. Regra: `THREAT` de um alvo a mais de 4 tiles é feito **correndo** (grunhido e "!" no quadro 0, sem parar); a pausa de 0,8 s só vale a menos de 4 tiles [premissa].

---

## 5. Corpo do jogador

### Dois caminhos até o caído

O decidido é: o torpor é a ameaça (o jogador desmaia), fome zerada sobe torpor (+2/s líquido, inconsciente em 50 s, GDD 560 a 582) e **morre só por dino sobre o caído**. Faltava dizer o que acontece quando um dino zera a vida do jogador que está de pé. Proposta (ver CONFLITO 6 e decisão D1):

| Caminho | Gatilho | Vida do caído |
|---|---|---|
| Torpor | torpor do jogador chega a 100 (fome, depois outras fontes no M4) | a vida que ele tinha |
| Vida zero | dano de dino leva a vida a 0 com o jogador de pé | `downed_health` = 70 (restaurada) [premissa] |

Em ambos o jogador entra em `DOWNED`: não anda, não golpeia, não usa item; sem input além de menu. A vida de pé não "mata": zerar a vida é o gatilho do desmaio.

### Duração e morte

| Campo (`DownedRules`) | Valor inicial | Marca |
|---|---|---|
| `downed_seconds` | **10** | [premissa; o QA-01a decide dentro de 8 a 20, GDD 582] |
| `downed_health` | 70 | [premissa] |
| `wake_grace_seconds` (sem dano ao acordar) | 2,0 | [premissa] |
| `wake_torpor` | 50 (da fome; já no GDD 582) | [lido GDD] |
| `body_minutes` | 10 | [decidido, GDD 12.4, linha 1294] |
| `passive_attacks_downed` | falso | [premissa] |

Quem ataca o caído: Agressivo sim (Utahraptor); Passivo e Semi-agressivo não (o Paquicéfalo acalma, e para o jogador o revide não pode matar). Morre quando a vida do caído chega a 0 por dano de dino. Fome, queda, ou nada além de dino, nunca matam [decidido].

Tabela de sobrevivência do caído, mordida de 8 a cada 1,5 s, raptores com fase deslocada [calculado]:

| Vida do caído | Desmaio | 1 raptor | 2 raptores | 3 raptores |
|---|---|---|---|---|
| 50 | 8 s | vive (2) | morre 4,5 s | morre 3,0 s |
| 50 | 10 s | morre 9,0 s | morre 4,5 s | morre 3,0 s |
| **70** | 8 s | vive (22) | morre 6,0 s | morre 4,0 s |
| **70** | **10 s** | **vive (14)** | morre 6,0 s | morre 4,0 s |
| 70 | 12 s | vive (6) | morre 6,0 s | morre 4,0 s |
| 70 | 20 s | morre 12,0 s | morre 6,0 s | morre 4,0 s |
| 100 | 8 s | vive (52) | vive (12) | morre 6,0 s |
| 100 | 10 s | vive (44) | morre 9,0 s | morre 6,0 s |
| 100 | 20 s | morre 18,0 s | morre 9,0 s | morre 6,0 s |

Por que 70 e 10 s: **1 raptor não mata** (sobra 14 de vida; o jogador acorda e tem 2 s de graça para correr) e **2 ou 3 matam em 4 a 6 s** (o bando é a ameaça real). Com 20 s, até 1 raptor mata, e a duração vira o ajuste de dificuldade do QA-01a. Com 8 s, 2 raptores com vida 100 não matam: perde a tensão. Isso é consistência, não diversão [jogar].

Acordar: volta a `ALIVE`, vida restante do caído (mínimo 20 [premissa]), torpor 50, `wake_grace_seconds` sem dano. Raptor ainda colado volta ao ciclo depois da graça.

### Morrer e renascer

1. **Morte:** a vida do caído chega a 0 por dino. O jogador vira corpo no lugar: **todo o inventário e o que veste ou está nos atalhos caem no corpo**, que some em 10 min (`body_minutes`) [decidido, GDD 1294]. Pegar o corpo é a interação "Recuperar itens" (E), com o mesmo alcance de coleta. O corpo guarda tudo; se o jogador não alcança em 10 min, perde.
2. **O que NÃO se perde** [decidido, GDD 163 e 1294]: XP, nível, pontos de nível, Saber e receitas, dinos domados (ficam onde estavam, na ordem atual). O que se perde: os itens (só se o corpo expirar), a fila de fome (`fome_pendente` zera ao morrer, decisão 08/11), e o tempo.
3. **Tela de morte no M1:** uma opção só, "Local aleatório" (a Cama é do M4; **no M1 só o aleatório**). Sorteio por região de `respawn_rules.tres` com 30 tentativas, 16 tiles de Agressivo (`min_distance_from_wild` 128 px [lido]), ponto reserva e proteção de 3 s [lido]. Hoje a única região é a Campina (CONFLITO 4).
4. **Efeito do renascimento** [lido `respawn_rules.tres` e GDD 1259]: vida 100%, fome 50%, torpor 0, inventário vazio.
5. **Salvar:** a morte salva "morto, escolha pendente" (`life: dead_pending_choice`, regra existente em `save.md`); fechar e abrir volta à tela de morte.
6. **Custo da morte** [calculado, premissa de recuperação]: corpo a 2 a 3 min de caminhada = 2 a 3 min de penalidade, mais o risco de o raptor ainda estar por perto. O corpo vence em 10 min, o que dá margem para esperar o raptor sair (alerta 5 s, acalma sem rancor).

---

## 6. Interação com o que já existe

### Dano em área de dino Grande

`AreaAttackRules`, `ServerRules.pvp` (booleana, padrão desligada) e a regra da autoridade já existem em `WorldAuthority.gd` (linhas 194 a 270) com testes (`area_attack_tests.gd`) [lido]. **Nada novo no M1**, porque Paquicéfalo e Utahraptor são Médios (o `area_attack` de ambos é nulo) e o Triceratops é M2. O M1 só precisa de:
- teste: Paquicéfalo e Utahraptor com `area_attack = null` acertam um alvo só;
- teste: a investida do Paquicéfalo não acerta outro dino (bando em volta);
- `pvp` fica falso no single-player e, mesmo ligado, só afeta domado de OUTRO jogador; no M1 não existe outro jogador.

### Fome por atividade

Valores já decididos: parado 0,04, andando 0,06, correndo 0,15; golpe de coleta 0,3, golpe de ataque 0,4 [lido]. Conta de custo da luta [calculado]: 6 golpes contra um raptor = 2,4; fugir 10 s correndo = 1,5; barra 100. A fome **não decide a luta** (a luta custa menos de 3% da barra), e isso é desejado ("o jogo não gira em torno dela"). Sem valor novo. Sofrer dano não gasta fome.

### Stamina

Valores de GDD 5: 100, dreno 25/s, regen 15/s, retoma com 20 [lido]. Exaurido: golpe com recarga x1,5 e efeito x0,75 (GDD 399). No M1 a luta contra o raptor L20 (6 golpes de Bastão) gasta 30; correr 4 s gasta 100. **Fugir de longe e depois lutar deixa o jogador exausto**: 5 golpes viram 9 e 5 mordidas viram 56 de dano (GDD 404, número da simulação anterior). Nenhuma regra nova; só os testes de aceite incluem "exausto" (A12). Caído: stamina regenera como parado; acorda cheio [premissa].

### Log de mensagens (códigos estáveis)

Regra do projeto: a autoridade emite `game_event(code, params)` e `GameMessages` traduz; o teste percorre `EVENTS` e `REASONS` e falha se faltar texto. Códigos novos propostos, pt-BR no `GameMessages.gd`:

| Código | Tipo | Texto | Quando |
|---|---|---|---|
| `tamed_stuck` | WARNING | "{name} ficou preso." | domado preso fora da tela (seção 1), uma vez por episódio |
| `dino_hit_player` | WARNING | "{species} te acertou: -{amount} de vida." | **só o primeiro golpe de cada episódio de agressão** (senão enche o log a cada 1,5 s; o dano em si aparece como número no jogador, decisão 08/11) |
| `player_downed` | DANGER | "Você desmaiou." | entrada em caído. **Hoje o código existe e é emitido na morte** (`WorldAuthority.gd:118`, texto "Você caiu."); mudar o texto e o gatilho |
| `player_woke` | INFO | "Você acordou." | fim do desmaio |
| `player_died` | DANGER | "Você morreu." | morte (substitui o uso atual de `player_downed`) |
| `player_respawned` | INFO | "Você renasceu." | depois da escolha |
| `corpse_recovered` | SUCCESS | "Você recuperou seus itens." | pegar o corpo |
| `corpse_expired` | WARNING | "Seu corpo sumiu: os itens se perderam." | passou `body_minutes` |

Motivos de recusa novos (`REASONS`): `downed` "Você está desmaiado." (hoje `actor_dead` diz "Você está caído."; reaproveitar ou separar), `no_corpse` "Não há corpo aqui." Não propus código de "dino ficou bravo" nem de "acalmou": o "!" e o "Nv" são o canal (menos ruído); se o playtest pedir, entram depois.

---

## 7. Aceite e playtest

### Critérios testáveis (cada um é um teste de unidade ou de cena headless)

| # | Critério |
|---|---|
| A1 | Dino a 10 tiles com uma árvore entre ele e o alvo: contorna e chega, ou desiste em até 3 s **sem ficar colado na árvore**; nunca fica parado indefinidamente. |
| A2 | Vão de 1 tile (16 px): Pequeno passa, Médio e Grande recusam o caminho. |
| A3 | Domado em Seguir, longe (>14 tiles) e fora da tela, sem caminho: em até 3 s fica parado, o log escreve `tamed_stuck` uma vez, e a posição não muda de forma descontínua (sem teleporte). |
| A4 | Domado preso, mas na tela: não escreve `tamed_stuck`; segue tentando. |
| A5 | Árvore derrubada libera a célula e o caminho antigo que passava por ela é replanejado. |
| A6 | 32 dinos ativos pedindo caminho: o orçamento de nós por quadro nunca passa de `node_budget_per_frame`; tick total abaixo de 2 ms. |
| A7 | Golpe no Paquicéfalo: "!" vermelho, "Nv" avermelhado, velocidade 80, `THREAT` de 0,8 s e só depois a cabeçada. |
| A8 | Bando de 3: golpe em um, 0,5 s depois os 2 outros entram; Bando de 4: entram exatamente 2, o 4º não anda. |
| A9 | Sem dar nem receber dano por 8 s (ajustável por `AggressionRules`), o dino volta a 40 px/s, "!" some, "Nv" volta à cor normal, e o próximo golpe é episódio novo com `THREAT` novo. |
| A10 | Cabeçada: dano 6, recarga 1,6 s (mesmo atacante), empurra 24 px e para em obstáculo; não empurra caído. |
| A11 | Passivo com vida abaixo de 25% foge, não revida; volta 10 s depois com o atacante a mais de 10 tiles. |
| A12 | Mordida do Utahraptor: dano 8, recarga 1,5 s; jogador exausto sofre 5 mordidas em 8,4 s em vez de 3,5 s (GDD 404). |
| A13 | Vida do jogador chega a 0 por dino: vira caído com vida 70, 10 s; 1 raptor não mata, 2 matam. |
| A14 | Caído por fome (torpor 100): mesma regra; acorda com torpor 50; comer corta a subida do torpor. |
| A15 | Paquicéfalo nunca ataca o caído; Utahraptor ataca. |
| A16 | Morte deixa corpo com todos os itens (inventário, equipado, atalhos); some em 10 min; "Recuperar" devolve tudo; XP, nível e dinos domados intactos. |
| A17 | Fechar na tela de morte, abrir, e a tela volta; o save de morto lê como morto. |
| A18 | Todo código novo de `EVENTS` e `REASONS` tem texto (teste existente). |
| A19 | Zero erro de script, `tools/check.sh` verde, e rodar o jogo (regra do `AGENTS.md`). |

### Perguntas que o playtest precisa responder (QA-01a, dono + `SHIRO`)

- **P1.** O "!" e o grunhido bastam para o jogador entender que o dino ficou bravo e que ele acalma sozinho? Ou o jogador acha que perdeu a luta?
- **P2.** O revide do bando é justo na primeira doma de Paquicéfalo (tutorial 4 golpes)? Em quantas de 5 vezes o jogador alimenta o dormindo sem sair ou perder mais de 40 de vida?
- **P3.** Bando de Utahraptor (2 a 3) é a "maior ameaça do mapa" (bandos-e-dano-em-area) ou o jogador simplesmente nunca entra na mata-baixa? A fuga de 8 tiles (margem de 1 quadro) é boa tensão ou injusta?
- **P4.** 10 s de desmaio com vida 70: o jogador sente que "perdeu o controle" ou só "esperou"? Que duração dá medo sem raiva (8, 10, 12 ou 20 s)?
- **P5.** Perder o inventário no corpo por 10 min é uma penalidade aceita ou o jogador larga o jogo? Quantos recuperam o corpo?
- **P6.** O jogador entende "ficou preso" e o que fazer? Em quantos casos o dino realmente fica preso, e em quantos é um bug de navegação?
- **P7.** O revide do Paquicéfalo atrapalha o fluxo de domar a ponto de o jogador evitar a espécie (seria o contrário do objetivo)?

### Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Bando de Paquicéfalo punitivo demais na primeira doma | quebra o tutorial do M1 (critério 1 do M1) | `max_helpers`, `damage` e `helper_max_seconds` em dado; reduzir antes de remover |
| A* nativo mais lento que o esperado | quebra os 60 fps com 32 ativos | etapa 1 mede antes de seguir; fallback GDScript com orçamento |
| Folga de porte bloqueia corredores entre árvores densas | dinos Médios "ilhados" no mapa | `clearance_tiles` em dado; teste A2; medir quantos spawns ficam sem caminho até o jogador |
| Desmaio sem dano de dino conhecido de fora | jogador sem nada a fazer por 10 s | é o objetivo; a graça de 2 s e o corpo recuperável compensam |
| Preso com log "ficou preso" frequente | ruído e frustração | contar episódios por hora no playtest (P6) |
| Utahraptor nocauteado com Bastão em 3,5 s elimina a ameaça | o raptor não assusta | só o playtest responde (P3); alternativa: mais vida, não mais dano |
| Perda de itens ao expirar o corpo | frustração em quem fechou o jogo | decisão D4 abaixo; timer só corre com o mundo rodando [premissa] |

---

## 8. Etapas para o SORA

Cada etapa é entregável e testável sozinha, na ordem. Cada uma termina com `tools/check.sh` verde e o jogo rodado.

1. **`PathProvider` e grade.** Interface, grade 256x256 com bloqueio por água, árvore, rocha e cenário, três folgas de porte, `invalidate(cell)`, `NavigationRules` em `.tres`. Benchmark: consulta de 48 tiles e 32 dinos pedindo a cada 0,5 s. Teste A1, A2, A5, A6. Mede e decide A* nativo ou GDScript.
2. **Travar, replanejar e "ficou preso".** Detector de progresso, linha do tempo de 1 s / 2 s / 3 s, perseguição e seguir usando o `PathProvider`, estado `STUCK` do domado, desistência sem teleporte, código `tamed_stuck`. Testes A3, A4.
3. **Estado de agressão.** `AggressionRules`, estado `aggressive`, relógio de 8 s sem dano, "!" vermelho, "Nv" avermelhado, velocidade natural x brava (80 e 90). Sem ataque ainda: o Paquicéfalo só fica bravo e persegue com a distância mínima. Testes A7 (velocidade e sinal), A9.
4. **Ameaça e ciclo + mordida do Utahraptor.** `ThreatProfile`, fases `THREAT`, `APPROACH`, `CIRCLE`, `WINDUP`, `LUNGE`, `RECOVER`; mordida de 8 com recarga 1,5; ameaça correndo a mais de 4 tiles. Pedido de sprite (cabeça baixa, raspar o pé) e grunhido ao `YATORA` com marcador no `CREDITS.md`; entre eles, o `SORA` usa o sprite atual e um som provisório. Teste A12, dano ao jogador, `dino_hit_player`. Por enquanto, vida 0 segue o que existe.
5. **Revide do Paquicéfalo e bando.** Cabeçada, empurrão, chamada a 8 tiles com atraso de 0,5 s, `max_helpers` 2, `helper_max_seconds` 12, foge com vida abaixo de 25%. Testes A8, A10, A11 e os testes de "sem fogo amigo" da seção 6.
6. **Caído, morte, corpo e renascer aleatório.** `DownedRules`, estado `DOWNED` pelos dois caminhos, regra de quem ataca o caído, morte, corpo de 10 min com todos os itens, tela de morte com "Local aleatório", save de morto, códigos `player_downed`, `player_woke`, `player_died`, `player_respawned`, `corpse_recovered`, `corpse_expired`. Testes A13 a A17.
7. **Integração, números e roteiro de playtest.** Os 6 `.tres` conferidos contra esta tabela, `fome` e `stamina` sem regressão, `AreaAttackRules` sem efeito nas duas espécies, teste de carga com 32 ativos agressivos, roteiro de playtest com as perguntas P1 a P7 e um registro por episódio (tempo bravo, dano, mortes, "ficou preso"). Teste A18, A19.

---

## 9. Conflitos e pendências para o dono

CONFLITO 1: `GDD.md:938` diz bando de Paquicéfalo 1 a 3 e Utahraptor 1 a 2; `corte-v02/bandos-e-dano-em-area.md` (decidido) diz Paquicéfalo 3 a 4 e Utahraptor 2 a 3, e `utahraptor.tres` e `placeholder_dino.tres` já seguem o segundo. Usei 3 a 4 e 2 a 3. Sem resolver o texto do GDD.

CONFLITO 2: `GDD.md:261` e `GDD.md:1539` (V26) tratam o Utahraptor como **solitário na 0.2** e dão 11 de dano no L20; o dado de hoje tem bando de 2 a 3 e `base_damage` 8 sem escala por nível (`DinoLevelRules` não tem fração de dano). Usei 8 fixo e bando de 2 a 3. O dano de 11 do GDD não existe no código.

CONFLITO 3: `GDD.md:934` diz que o Agressivo "ataca ao avistar" sem aviso, e a decisão de 08/11 de hoje pede som e animação de ameaça antes de investir. Propus aviso curto (0,8 s) feito correndo quando o alvo está longe (seção 4).

CONFLITO 4: `PLANEJAMENTO.md:136` e `GDD.md:1218` dizem "respawn só na Campina" no M1; `GDD.md:1240` (provisório) diz sorteio na ilha inteira; `game/data/balance/respawn_rules.tres` tem só a Campina. Implementei o que o dado faz (Campina) e deixei a região como dado; trocar para a ilha inteira é só dado.

CONFLITO 5: `GDD.md:939` (abaixo de 25% foge) e `GDD.md:932` (Passivo acalma com atacante a mais de 12 tiles por 5 s) encurtam o "cerca de 8 s" decidido hoje; `utahraptor.tres` tem alerta de 5 s e `decisoes-0611-0711.md:95` tem 20 s para quem alcança sem poder atacar. Mantive os atalhos como [premissa] e pedi confirmação ao dono (D2).

CONFLITO 6: `decisoes-0611-0711.md:44` (morte só por dino sobre o caído) e `GDD.md:560` a `582` só descrevem o desmaio **por fome**. Nada diz o que acontece quando um dino zera a vida do jogador de pé; o código de hoje morre (`WorldAuthority.gd:118`). Propus o caminho "vida zero vira caído" (seção 5). `PLANEJAMENTO.md:270` (SOB-04) ainda coloca o torpor por fome no M2 (SOB-07) e fome de 0,2/s, contra o M1 "ameaça e corpo" do roadmap de 07/11 e a fome por estado de `decisoes-0611-0711.md:89`.

CONFLITO 7: `PLANEJAMENTO.md:101` e `GDD.md:383` dizem "sem barra de stamina" no HUD; `decisoes-0611-0711.md:91` (08/11) decide a barra de Stamina. Não afeta a conta; só o texto.

### Decisões que dependem do dono

- **D1. O que acontece quando a vida do jogador de pé chega a 0?** Recomendo: vira caído (desmaio) com vida do caído de 70, e só dino sobre o caído mata (seção 5). Sem isso, o torpor só vem pela fome e o desmaio nunca aparece no playtest do M1.
- **D2. Os atalhos de acalmar (atacante a mais de 12 tiles por 5 s; Agressivo desiste a 20 tiles ou 15 s) valem junto dos 8 s?** Recomendo que sim: evita o dino perseguir pelo mapa por 8 s sem dano, que seria pior.
- **D3. Duração do desmaio e vida do caído.** Recomendo 10 s e 70, que faz 1 raptor não matar e 2 ou 3 matarem (tabela da seção 5); o QA-01a pode mexer em 8 a 20 s.
- **D4. O corpo (10 min) conta tempo com o jogo fechado?** Recomendo que não (só corre com o mundo rodando, como a espera da Cama, GDD 1285), para fechar o jogo não ser jeito de perder tudo.
- **D5. O revide do bando de Paquicéfalo na primeira doma.** Recomendo começar com `max_helpers` 2 e dano 6, e baixar para dano 4 se P2 falhar, em vez de tirar o bando.
