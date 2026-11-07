# Vínculo, montaria, trabalho, teto do domado e marcos de receita (especificação)

Escrito em 07/11 pela pessoa de game design; **revisado no mesmo dia** com as decisões do dono sobre portes, Stamina do dino, fome gradual, aliados e Armadura de fibra (ver `decisoes-0611-0711.md`, seção Domado). **Só especificação, sem código.** Origem: "Auditoria geral de 07/11" e "Respondido em 07/11" em `decisoes-0611-0711.md` (SHI-01, SHI-02, SHI-06, SHI-08, SHI-11 de `shiro.md`).

Legenda: **[decidido]** palavra do dono; **[premissa]** minha proposta, vale até o teste; **[a validar no playtest]** a conta não responde, só jogar. Tempos são tempo de jogador (balanço). Todos os números vão para `Resource` em `game/data/`; chaves de servidor em `server_rules.json` (ADR-004).

## 1. Vinculado (substitui o Afeto 0-100)

Campo único no domado: `vinculado: bool`. Some a barra, a queda por minuto, o -10 por ferimento e o save do número (save v5 grava só o booleano; migração: Afeto >= 25 vira `true`, senão `false`) [premissa].

| Campo (`DinoBondRules`) | Valor | Marca |
|---|---|---|
| `refeicoes_para_vincular` | 1 | [premissa] (auditoria SHI-06) |
| `comida_valida` | qualquer item da dieta da espécie (`ideal_food`) ou Ração aceita por ela | [premissa] |
| `alcance_alimentar_tiles` | 2 | [premissa] |
| `quem_alimenta` | o dono (quem reservou a doma) | [decidido] (dono da doma = quem alimentou primeiro) |
| Quando conta a refeição | ao **começar** a comer (a fome sobe aos poucos, seção 9); não espera terminar | [premissa] |
| `perde_por_fome`, `perde_por_tempo`, `perde_por_ferimento` | falso, falso, falso | [premissa] |
| `perde_ao_soltar_ou_transferir` | verdadeiro | [premissa] |

**Quando vira verdadeiro:** o dono dá 1 comida da dieta ao domado já acordado, a até 2 tiles. A comida da própria doma não conta (ela acontece antes de ele ser domado).

**O que libera:** (a) ser montado; (b) obedecer "Trabalhar aqui". **Não** depende do vínculo: seguir, ficar, alforje de 4 slots, Neutro defender (já decidido, sem trava).

**Quando se perde:** só se o dono o solta ou o transfere; fome, tempo, ferimento, morte do dono e logout **não** tiram. Domado que morre deixa de existir (regra do alforje na sacolinha, GDD 6.8).

Frases testáveis:
1. Domado recém-saído da doma, sem refeição pós-doma, recusa `request_mount` e `request_work` com o motivo "ainda sem vínculo".
2. Ao dar 1 Baga (Paquicéfalo) ou 1 carne (Utahraptor) a até 2 tiles, `vinculado` vira `true` e o próximo `request_mount` do dono passa.
3. Dar 100 refeições, deixar 60 min sem comer ou ferir o domado não muda `vinculado`; só "Soltar" ou transferir o põe em `false`.

Custo/decisão: a decisão sai do número (era um minigame sem escolha) e vira "levei a comida certa?". Utahraptor exige carne: quem doma sem carne no bolso espera. Aceito [premissa].

## 2. Montaria

### 2.1 Quem pode montar
| Regra | Valor | Marca |
|---|---|---|
| Quem monta | o **dono e os aliados** (sem tribo, só o dono); o dino precisa ter `vinculado = true` | [decidido] |
| "Aliado" no MVP sem tribo | jogador que o dono adicionou à lista `aliados` do dino (menu do domado, "Permitir montar"); no single-player a lista não existe e só o dono monta. A lista vale por dino, é do dono, e cai se o dono soltar ou transferir o dino. Revoga a qualquer momento (desmonta o aliado, ver 2.3). Quando existir tribo, `aliados` passa a ser lido da tribo, sem mudar o dado do dino | [premissa] |
| Chave de servidor `montaria_aliados` | verdadeiro (padrão); falso restringe ao dono | [premissa] |
| Porte | só **Médio e Grande** montam; **Pequeno nunca** (campo `montavel` no porte, seção 7) | [decidido] |
| Espécie montável (v0.2) | Paquicéfalo (Médio, prova técnica), Utahraptor (Médio, V1), Triceratops (Grande, V2). Dodo (Pequeno) não | [decidido] porte; ordem de entrega [premissa] |
| Distância para montar | a até 2 tiles, dino parado ou em Seguir | [premissa] |
| Duração de montar e de desmontar | 0,5 s cada, jogador imóvel | [premissa], [a validar no playtest] |
| Ocupantes | 1 cavaleiro | [premissa] |
| Montado, o jogador | continua entidade no mundo (posição = a do dino), alvo de ataque como antes | [decidido] |
| Ataque montado | nenhum na V1 | [premissa] |
| Alforje | acessível montado, sem desmontar | [decidido] |
| Carga do jogador montado | não pesa (GDD 5.22) | [decidido] |
| Stamina do jogador montado | não gasta; quem gasta é a Stamina do dino | [decidido] |

### 2.2 Stamina do dino e Galope (dados em `MountProfile` e `DinoStaminaRules`)
Substitui a recarga fixa de 6 s: o Galope dura **enquanto houver Stamina**; mais Stamina, mais tempo. Zerou, o dino precisa ficar **parado** um intervalo antes de recuperar; a recuperação é **gradual**. [decidido] a regra; os números são [premissa] e vêm da simulação da seção 6.

| Campo | Valor | Marca |
|---|---|---|
| `stamina_base` (nível de referência 10) | 100 | [premissa] |
| Crescimento com o nível | **automático, sem pontos**: `stamina_max = base x (1 + 0,02 x (L - 10))`, piso 0,7 (mesma inclinação do torpor, `torpor_slope`). L5 = 90, L15 = 110, L25 = 130 | [premissa] |
| Pontos de atributo na Stamina | não (a Stamina do dino não aceita pontos; segue o GDD 5.13) | [premissa] |
| `gasto_galope_s` | 20 por segundo (100 de Stamina = 5 s de Galope; 110 = 5,5 s) | [premissa] |
| `gasto_andando_montado_s` | 0 | [premissa] |
| `atraso_regen_apos_uso_s` | 1,0 (sem Galope por 1 s; pode andar) | [premissa] |
| `atraso_regen_apos_zerar_s` | 3,0 **parado** (velocidade 0); qualquer movimento reinicia a contagem | [premissa] |
| `regen_s` | 12 por segundo, gradual (0 a 100 em 8,3 s) | [premissa] |
| `limiar_retomar_galope` | 20 (depois de zerar, o Galope só volta com 20) | [premissa] |
| Dino sem Stamina com o jogador montado | continua andando a 117 px/s (x1,3); só perde o Galope; **não desmonta** | [premissa] |
| Stamina fora de montaria | o dino não gasta nem regenera de forma que importe; ao desmontar enche a 12/s | [premissa] |

| Espécie | `montavel` | `mult_montado` | `galope_mult` (sobre a velocidade da espécie) | Stamina | Fase |
|---|---|---|---|---|---|
| Paquicéfalo (Médio) | verdadeiro | 1,3 | n/a (sem Galope) | n/a | prova técnica: montar, desmontar, mover |
| Utahraptor (Médio) | verdadeiro | 1,3 | 1,8 | regras acima | V1 |
| Triceratops (Grande) | verdadeiro | 1,3 | n/a na V1 | n/a | V2 |
| Dodo (Pequeno) | falso | n/a | n/a | n/a | n/a |

Todas as linhas desta tabela: [premissa], exceto "Paquicéfalo faz a prova técnica" e "Dodo não monta" [decidido]. Velocidade montada = `velocidade_da_espécie x 1,3`; Galope = `velocidade_da_espécie x 1,8` (substitui, não multiplica). Utahraptor: 90 -> 117 -> 162 px/s. Paquicéfalo: sem velocidade nos `.tres`; uso **70 px/s [premissa]** (91 px/s montado).

### 2.3 Desmonte forçado
| Evento | Efeito | Marca |
|---|---|---|
| Torpor do dino chega ao máximo (dormiu) | desmonta; jogador cai ao lado (1 tile livre); dino dormindo | [premissa] |
| Dino morre ou, na v0.2, fica ferido | desmonta; alforje na regra existente (sacolinha / fica no lugar) | [premissa] |
| Torpor ou vida do jogador chega a 0 | desmonta; dino fica em "Ficar" | [premissa] |
| Cavaleiro sai (desconecta, sai ao menu, salva e sai) | desmonta; dino "Ficar" no lugar | [premissa] |
| Dono solta, transfere o dino ou tira o aliado da lista | desmonta antes | [premissa] |
| Stamina zera | **não** desmonta (perde só o Galope) | [premissa] |
| Sem tile livre ao lado | recusa com aviso | [premissa] |
| Passagem menor que o porte do dino | o dino não passa; não desmonta | [premissa] |

Frases testáveis: (1) montado, quando o torpor do dino chega ao máximo, o jogador está a pé no tile livre mais próximo em até 1 quadro; (2) com o cavaleiro desconectado, nenhum dino fica com `mounted_by` preenchido; (3) montar sem `vinculado`, a mais de 2 tiles, ou sendo jogador fora da lista `aliados`, é recusado sem custo; (4) com a Stamina em 0 o botão de Galope não faz nada e o dino segue a 117 px/s.

## 3. Trabalhar aqui (Paquicéfalo, madeira)

Uma ordem única no menu do domado, `request_work(ponto)`. A função vem do dado `WorkProfile` da espécie, nunca do código do dino. Corrigido em 07/11 (consolidação de roadmap): árvore dá **3 madeira** (`tree.tres`: `yield_amount = 3`, `gather_seconds = 8.0`, `respawn_seconds = 480.0`), não 32; o gargalo é o **nó**, não o alforje.

### 3.1 `WorkProfile` (um `Resource` por espécie, em `game/data/`)

| Campo | Paquicéfalo | Triceratops | Dodo | Utahraptor | Marca |
|---|---|---|---|---|---|
| `species_id` | `pachycephalosaurus` | `triceratops` | `dodo` | `utahraptor` | [decidido] (4 espécies da v0.2) |
| `recurso_tipo` (id do `ResourceDef`) | `tree` | `rock` | `bush_baga` | vazio (não trabalha) | [decidido] Paquicéfalo = madeira; demais [premissa] |
| Rendimento e item | lidos do `ResourceDef` do nó, nunca duplicados aqui | idem | idem | n/a | [decidido] (regra de dado) |
| `taxa_rel` (fração da taxa de mão do jogador) | 0,25 | 0,25 | 0,25 | n/a | [premissa], [a validar no playtest] |
| Tempo por colheita = `gather_seconds / taxa_rel` | 8 / 0,25 = **32 s** | 10 / 0,25 = 40 s | 9 / 0,25 = 36 s | n/a | calculado |
| `raio_tiles` em volta do ponto | 12 | 12 | 12 | n/a | [decidido] |
| `deslocamento_fixo_s` por colheita | 2,5 | 2,5 | 2,5 | n/a | [premissa] |
| `alforje_slots` | 4 | 4 | 4 | n/a | [decidido] |
| `exige` | `vinculado`, acordado, não ferido, não montado | idem | idem | n/a | [premissa] |
| Entra em | M3 | M5 | M3 | n/a | [premissa] |

Chaves de servidor (ADR-004, não são do `WorkProfile`): `dino_trabalhando_max` = 3 por jogador [premissa], [a validar no playtest]; `work_danger_radius_tiles` = **20** [premissa], [a validar no playtest] (se a Mata-baixa parecer "proibida", baixar).

### 3.2 Regras

| Regra | Valor | Marca |
|---|---|---|
| Quem ordena | **só o dono**; aliados montam, não comandam | [decidido] |
| Limite | até **3 dinos trabalhando** por jogador; a 4ª ordem é recusada com o limite na mensagem | [decidido] |
| Ponto recusado | se o ponto está a menos de `work_danger_radius_tiles` (20) de toca de dino agressivo, recusa com "perigo perto"; a regra é de dado, não simula predador distante | [decidido] (raio em dado, inicial 20) |
| Alvo | só nós reais do mapa (ids estáveis, ADR-007); o nó pronto mais próximo do ponto; empate pelo menor id; nó em respawn (480 s) pulado | [decidido] |
| Peso do dino | **fora na v0.2**: o alforje só é limitado pelos 4 slots; o Peso do dino volta com as selas de carga (M4b) | [decidido] |
| Alforje | 4 slots x pilha de 20 (madeira) = 80; só colhe se o rendimento **inteiro** cabe (26 colheitas = 78, para em 78) | [decidido] slots; [premissa] pilha |
| Alforje cheio | o dino para no lugar com "carga cheia", não volta ao dono e não perde item; o dono retira pela tela (E) a até 2 tiles ou montado | [premissa] |
| Distância do dono | **o trabalho não para quando o dono se afasta**: ao passar de `far_radius_tiles` (40, `zone_rules.tres`) só muda de nível de simulação (perto: com física; longe: laço de eventos sem física, mesma regra e mesmo resultado, ver 3.3) | [decidido] |
| Para de fato quando | alforje cheio (por slots); sem nó pronto no raio (espera o respawn, não cancela); dono monta nele ou o chama (Seguir); dino ferido ou dormindo; dono solta ou transfere | [premissa] |
| Perigo durante o trabalho | agressivo a até 8 tiles do dino: a ordem **cai para Seguir** e emite `work_stopped(motivo)`; **sem retomada automática na V1** (retomada fica em análise para depois do playtest do M3) | [decidido] (V1) |
| Exige | `vinculado = true`, senão recusa com "ainda sem vínculo" | [premissa] |

### 3.3 Conservação (invariante testável)

Para todo nó N e todo intervalo [t0, t1] de `world.time`: **itens tirados de N por todos os atores (jogador e dinos) <= estoque de N em t0 + rendimento cheio x recargas vencidas em (t0, t1]**; e **todo item no alforje de um dino saiu de um nó** (a soma dos itens de trabalho nos alforjes nunca passa da soma das colheitas registradas nos nós). Cada colheita escreve o `due_at` no nó real (`t_fim + respawn_seconds`); o dino não tem estoque próprio, só move item do nó para o alforje. Longe, `WorkSim` percorre os mesmos eventos discretos (nó pronto de menor `due_at`, empate por id; `t = max(t_livre, due_at) + deslocamento`; para se `t_fim > world.time` ou se o rendimento não cabe), com número de iterações limitado por `ceil(capacidade/rendimento) + 1`, independente do tempo decorrido. [decidido]

### 3.4 Contas (3 madeira por nó, 480 s, colheita 32 s + 2,5 s)

- Taxa do dino: 3 / 32 = 0,094/s = **5,6 madeira/min**; por ciclo de respawn de 480 s ele faz 480 / 32 = **15 colheitas, ou seja, ~15 nós por ciclo** (45 madeira por ciclo).
- Capacidade dos nós: N árvores dão N x 3 / 480 s. 6 árvores = **2,25 madeira/min** (menos que os 5,6 do dino: o bosque é o gargalo); 26 árvores (mediana do mapa no raio 12) = 9,75/min. **Não existe "bosque de 3 a 4 árvores sustenta um dino"**: 3 a 4 árvores dão 1,1 a 1,5/min, um quarto da taxa do dino.
- Encher o alforje (78 madeira): 6 árvores prontas = **~36 min**; 26 árvores = **~15,5 min** (limite pela taxa e pelos nós). Com 6 árvores prontas em `world.time` 1.800 s: 72; em 3.600 s: 78 e para.
- 3 dinos no mesmo bosque de 6 árvores: 80 no total em ~35 min (contra 36 com 1): bosque pobre não rende com mais dinos (tensão de lugar). Em 26 árvores, 3 dinos: ~9,2 min.
- Jogador com Machado (0,75/s): 80 madeira em 107 s. Um dino rende ~1/8; o valor do dino é o paralelismo, não a taxa.
- Jogo fechado: `world.time` não anda, colheita 0. Aberto 2 h com o jogador longe: 78 (teto do alforje), nunca mais que os nós permitem.

Frases testáveis:
1. Ordem dada sem `vinculado` é recusada com "ainda sem vínculo".
2. Ponto a menos de 20 tiles de toca de agressivo é recusado; a 20 ou mais, aceito; mudar `work_danger_radius_tiles` muda o limite sem código.
3. A 4ª ordem de trabalho simultânea do mesmo jogador é recusada com o limite na mensagem; ordem de um aliado ao dino de outro jogador é recusada.
4. Com o alforje em 78 de 80 o dino para com "carga cheia", nenhum nó é colhido sem o item caber e nenhum item some.
5. Com o dono a 41 tiles, o dino continua colhendo; a diferença entre "perto" e "longe" para o mesmo `world.time` é de no máximo 1 unidade.
6. Para qualquer nó e intervalo, o tirado por todos os atores <= estoque inicial + 3 x recargas vencidas (teste por propriedade, 200 sementes, alternando perto/longe).
7. Agressivo a 8 tiles do dino: nenhum `request_harvest` do dino naquele quadro, ordem passa a Seguir com `work_stopped(motivo)`, e o dino não volta ao ponto sozinho.
8. Nenhum caminho lê Peso do dino: com 40 kg de capacidade fictícia a mesma ordem enche os 78 de madeira.

## 3b. Sexo e aliados

**Sexo** [decidido: existência, sinalização e cores; premissa: sorteio e formato]:
- Todo dino tem `sexo` (`M` ou `F`) desde o spawn. Proporção em dado por espécie, `sexo_proporcao_macho` = 0,5 em todas (50/50), **sem efeito em atributos, torpor, dieta ou velocidade** [decidido].
- Selvagem: sexo fixo pela semente do spawn (`hash(seed, spawn_id)`), igual antes e depois de recarregar. Filhote: sorteado ao nascer. Campo `sexo` no save v5 [decidido].
- Sinal ao lado do "Nv": ♂ `#71ddee` e ♀ `#ef9597`, com contorno escuro e formas diferentes (não só cor); aparece no selvagem (antes da doma, mesma regra do "Nv N": até 6 tiles, acordado e vivo) e na placa do domado.

| Tabela (`species`) | Dodo | Paquicéfalo | Utahraptor | Triceratops | Marca |
|---|---|---|---|---|---|
| `sexo_proporcao_macho` | 0,5 | 0,5 | 0,5 | 0,5 | [decidido] |

Frases testáveis: (1) o mesmo `spawn_id` e a mesma semente dão o mesmo sexo antes e depois de salvar e carregar; (2) em 1.000 sorteios com semente por espécie a proporção de machos fica entre 0,45 e 0,55 [premissa]; (3) trocar o sexo de um dino em teste não altera nenhum atributo calculado; (4) o texto do rótulo continua "Nv N" e o símbolo é elemento separado ao lado.

**Aliados:** lista por dino, editada só pelo dono e revogável (ver 2.1). Frases testáveis: (1) jogador fora da lista tem `request_mount` recusado; (2) remover o aliado com ele montado o desmonta antes de aplicar; (3) aliado na lista não consegue `request_work` nem soltar ou transferir o dino.

## 3c. Reprodução: fatia do M3b (`BreedingDef`)

Atrás da chave de servidor `reproducao_ativa` (desligada por padrão até o M7), condicionada ao teste decisivo do M3. Dado em `BreedingDef` por espécie; chaves de servidor fora do `Resource`. [decidido] a fatia e o custo zero; números [premissa] e [a validar no playtest].

| Campo (`BreedingDef`) | Dodo | Paquicéfalo | Utahraptor | Triceratops | Marca |
|---|---|---|---|---|---|
| `custo_comida_cruzar` | 0 | 0 | 0 | 0 | [decidido] (custo entra no M7) |
| `incubacao_min` (por `world.time`) | 6 | 8 | 10 | 15 | [premissa] |
| `crescimento_min` (filhote a adulto) | 10 | 15 | 20 | 30 | [premissa] |
| `cooldown_femea_min` | 30 | 30 | 30 | 30 | [premissa] |
| `cooldown_macho_min` | 10 | 10 | 10 | 10 | [premissa] |
| `escala_filhote` / `escala_juvenil` / `escala_adulto` | 0,5 / 0,75 / 1,0 | idem | idem | idem | [premissa] |
| `fome_minima_cruzar` | 50 | 50 | 50 | 50 | [premissa] |
| `distancia_max_tiles` entre os dois | 6 | 6 | 6 | 6 | [premissa] |

Chaves de servidor: `domados_max` = **12** por jogador, **ovo e filhote contam** [decidido]; `reproducao_ativa` = falso [decidido].

Regras: (1) Cruzar exige 1 macho e 1 fêmea da mesma espécie, ambos domados do mesmo dono, `vinculado`, adultos, acordados, fome >= 50, não montados nem trabalhando, a até 6 tiles, fêmea fora de cooldown; (2) a fêmea põe o ovo (entidade no mundo, com `born_at`, dono, `mae_id`, `pai_id`); (3) o ovo choca por `world.time - born_at >= incubacao_min` e, se o dono está no limite de 12, **espera sem se perder**; (4) o filhote nasce `vinculado`, não ataca, não monta, não trabalha, não é nocauteável nem alvo; (5) fome 0 **pausa** o crescimento, sem morte; (6) herança sem genética: nível de nascimento = `max(3, floor(0,6 x média dos níveis dos pais))`, `nivel_saida` = média dos pais.

Contas: ovo a adulto no Paquicéfalo = 8 + 15 = 23 min; de 2 a 12 domados são 10 ovos; com 1 fêmea e cooldown de 30 min = 300 min de relógio aberto, com 3 fêmeas = 100 min. Pais L20 e L12 (`nivel_saida` 25 e 15): filho L9 (média 16 x 0,6 = 9,6, piso 9), teto 2 x 20 = 40.

Frases testáveis: (1) par macho+macho ou fêmea+fêmea é recusado; (2) com 12 domados contando ovos e filhotes, `request_breed` é recusado com o limite; (3) ovo posto, salvo, jogo fechado 10 min e reaberto, não avançou em `world.time` (nada chocou); (4) o custo de comida de Cruzar é 0 e nenhum item é consumido; (5) filhote com fome 0 não cresce e não morre; (6) mil nascimentos geram mil ids únicos.

## 4. Teto do domado: opção B [decidido]

Regra: `teto_efetivo = min(dino_teto_multiplicador x nível_final_da_doma, dino_nivel_max)`. `nível_final` = nível selvagem + bônus de Eficiência, **já limitado** por `dino_nivel_max`. Chaves novas em `ServerRules` (hoje só existem 7 chaves e `LEVEL_RANGE [1,50]` só valida as faixas de spawn) [premissa]:

| Chave | Padrão | Marca |
|---|---|---|
| `dino_teto_multiplicador` | 2,0 | [decidido] |
| `dino_nivel_max` | 50 (MVP) | [decidido] |
| `dino_nivel_spawn_max` | 30 | [decidido] (selvagem nasce até 30) |

Bônus: `bonus = floor(nivel_selvagem x 0,5 x Eficiência)` (`taming_bonus = 0.5`; trava `taming_cap = 1.5` do `.tres`) [premissa: o arredondamento é para baixo]. Eficiência alta = 90% (+45%), baixa = 20% (+10%) [premissa; a Ração A real dá 78-92%].

| Selvagem | Eficiência | Final (saída da doma) | 2x final | Teto efetivo (servidor 50) | Níveis de XP a ganhar |
|---|---|---|---|---|---|
| 5 | alta 90% | 7 | 14 | **14** | 7 |
| 5 | baixa 20% | 5 | 10 | **10** | 5 |
| 15 | alta 90% | 21 | 42 | **42** | 21 |
| 15 | baixa 20% | 16 | 32 | **32** | 16 |
| 25 | alta 90% | 36 | 72 | **50** (corta 22) | 14 |
| 25 | baixa 20% | 27 | 54 | **50** (corta 4) | 23 |
| 30 | alta 90% | 43 | 86 | **50** (corta 36) | 7 |
| 30 | baixa 20% | 33 | 66 | **50** (corta 16) | 17 |

**O 50 corta demais?** A regra 2x passa de 50 quando o final >= 25, ou seja, selvagem >= 18 com Eficiência alta e >= 23 com baixa. Corta a partir daí: Triceratops (18-24) e a metade de cima do Utahraptor (5-25) e do selvagem de 25-30. Para esses, o teto vira igual para todos (50) e a Eficiência deixa de elevar o teto; ela só adianta o ponto de partida (36 contra 27 em um 25). Cálculo de proporção: o 2x só decide o teto de quem sai da doma abaixo de 25. **Meu parecer:** manter 50 [decidido] no MVP; o corte é aceitável porque o jogador (teto também em escala de ~19 pontos de nível, GDD 5.16) e o dino ficam na mesma ordem, e o caso "30 alta" que ganha só 7 níveis é raro (selvagem >= 25 sai de `u^2`, ~13% dos sorteios; faixa do Utahraptor vai a 25). **A validar no playtest:** se quem doma um L30 sente que "não tem para onde crescer" (7 níveis a 2 h de XP).

**Correção de código (registrada, não feita aqui):** `game/data/balance/dino_level_rules.tres` tem `max_level = 75`; o MVP é 50. O teto efetivo lido de `ServerRules.dino_nivel_max` vence o do `.tres`, que deve ficar em 50 como valor de reserva.

## 5. Saber vira marcos: as 9 receitas aprendidas

Sem moeda, sem tela de gastar pontos. A receita abre sozinha quando o jogador **faz** o gatilho; ela mostra um aviso ("Aprendeu: X") e entra na aba Receitas da tela P. Total: **17 receitas = 8 conhecidas + 9 aprendidas** [decidido].

Conhecidas (8, nascem abertas): Lança, Machado, Picareta, Fogueira, Bastão, Cesto, Baú, Mochila.

**Observação para o dono:** a lista de `shikamaru.md` tinha a **Bancada** entre as 9. Como a Bancada saiu da v0.2 (a Fogueira faz a Ração, auditoria), a vaga de contagem fica livre. Proponho ocupá-la pela **Armadura de fibra** (1 conjunto de 1 peça, conforme "armadura de 3 peças") para manter 17. Se o dono prefere 16, basta cortar a linha 9.

| # | Receita (aprendida) | Gatilho | Marca |
|---|---|---|---|
| 1 | Ração C | Domar o 1º dino (qualquer espécie) | [premissa] |
| 2 | Abrigo: 1ª peça (chão ou parede, conforme o kit) | Coletar 10 madeira e 4 pedra | [premissa] |
| 3 | Abrigo: 2ª peça | Colocar a 1ª peça | [premissa] |
| 4 | Abrigo: 3ª peça (porta/teto, conforme o kit) | Fechar um anel de 8 peças | [premissa] |
| 5 | Saco de dormir | Passar a primeira noite fora do abrigo (ficar ao relento ao anoitecer) | [premissa], [a validar no playtest] |
| 6 | Cama | Dormir 1 vez no Saco de dormir | [premissa] |
| 7 | Ração B | Domar um dino com Ração C | [premissa] |
| 8 | Ração A | Domar um dino de porte Grande (ou dar 10 refeições de Ração B) | [premissa] |
| 9 | Armadura de fibra [decidido que entra] | Sobreviver a um golpe de carnívoro com vida abaixo de 50% | [premissa], [a validar no playtest] |

Regras: (a) gatilho vale por personagem, não por servidor; (b) gatilhos 1, 7 e 8 usam o **evento de doma concluída** que já existe, sem sistema novo; (c) nenhum gatilho exige nível. Cuidado: o gatilho 9 depende de o jogador se arriscar; se o playtest mostrar que quase ninguém o abre, trocar por "coletar 20 fibra". Os nomes das 3 peças de Abrigo seguem a etapa E8 de `shikamaru.md`.

## 6. Economia de trajeto montado (refeita com Stamina)

Base: `montaria_sim.py velocidade` e simulação própria do pior trajeto (282 tiles = 4.512 px; jogador correndo 86,5 px/s = 52,2 s; a pé 64,5 s). Utahraptor: 117 px/s montado, 162 px/s em Galope, **1 s somado para montar e desmontar**. Parâmetros da seção 2.2 (gasto 20/s, regen 12/s, atraso 1 s, atraso de 3 s parado ao zerar, retomada em 20). Três estilos de jogador:

| Estilo | Stamina 100 (L10) | Stamina 110 (L15) | Stamina 130 (L25) |
|---|---|---|---|
| Sem Galope (só x1,3) | 39,6 s = 24,2% | igual | igual |
| **Descuidado:** galopa até zerar e segue andando sem parar | 37,7 s = **27,8%** | 37,5 s = 28,2% | 37,1 s = 28,9% |
| **Gerencia:** galopa e anda alternando, sem zerar | 34,5 s = **33,9%** | 34,6 s = 33,7% | 34,1 s = 34,7% |
| **Esgota e espera parado** a cada vez | 136 s (pior que a pé) | 136 s | 132 s |

**Resultado:** o Galope por Stamina cumpre a meta de 30% **para quem gerencia a barra** (33,9% a 34,7%, margem de ~4 pontos, melhor que os 31,5% da recarga de 5 s). O jogador que zera a barra e continua andando fica em 27,8% a 28,9%, **abaixo da meta**: ele gastou os 5 s de Galope no começo e perdeu o resto, porque recuperar exige parar 3 s e valeria só 1 s de Galope. Isso é a decisão com custo do sistema, não defeito: a barra tem que ser legível. A variação por nível é pequena (+0,8 ponto entre L10 e L25), então a Stamina por nível não decide o jogo. Esgotar e esperar parado é pior que ir a pé: aceitável como erro punido. Com o atraso de 3 s a metade (1,5 s) o descuidado sobe pouco (o tanque cheio é gasto no começo de qualquer jeito), então não vale o botão; o botão que mexe é `gasto_galope_s` (15/s dá 6,7 s de Galope).

Trajeto de 40 tiles: ~23% (5,7 s contra 7,4 s); o ganho real aí é não gastar Stamina do jogador. Paquicéfalo (91 px/s, sem Galope): 49,6 s contra 52,2 s = 5%: só prova técnica.

**[a validar no playtest]:** se o jogador lê a barra do dino e a administra (senão a meta cai para 28%); se 5 s de Galope cheio é o tempo certo; se os 3 s parado ao zerar punem sem frustrar; se o trajeto real com desvios mantém os 30%.

## 7. Portes: só três (decidido em 07/11)

Substitui os seis portes de GDD 4.2. [decidido] os três portes e suas definições; [premissa] os números de colisão e vão. Dado em `porte.tres` (um por porte).

| Porte | Definição [decidido] | Exemplos [decidido] | Colisão nos pés (px) [premissa] | Passagem mínima (tiles) = ceil((colisão+2)/16) | Cerca / Portão de dino | Entre árvores | Grade de navegação | Monta? |
|---|---|---|---|---|---|---|---|---|
| **Pequeno** | pets e criaturas diminutas | Troodon, Dodo | 12x12 | **1** | cerca fecha; Portão simples (1 tile) abre | passa por vão de 1 tile | grade base (célula 16 px) | não |
| **Médio** | tamanho humano | raptor (Utahraptor), Carbonemys, Parassaurolofo, **Paquicéfalo** | 14x14 | **1** | idem | passa por vão de 1 tile | grade base (a mesma do Pequeno) | sim |
| **Grande** | tudo maior que um humano | Tyrannosaurus, Triceratops, Brontossauro | 28x24 | **2** | cerca fecha; **Portão duplo** (2 simples lado a lado, 8 madeira) | exige 2 tiles livres | grade "inflada": célula livre só se o bloco 2x2 está livre | sim |

Regras: (1) **colisão só nos pés**, a cabeça e a cauda passam por cima (mantém a regra 1 do GDD 4.2); (2) o tamanho do sprite é **por espécie** (campo `escala_visual`), o porte só define colisão, passagem e navegação; um Brontossauro de sprite enorme usa a colisão de Grande, [a validar no playtest] se o visual parece passar por um vão pequeno; (3) o `AStarGrid2D` passa de até quatro grades a **duas** (base e inflada), o que corta custo de navegação e de teste [premissa]; (4) Pequeno e Médio compartilham passagem, então um curral de Portão simples serve aos dois; (5) o Portão e o curral estão fora da v0.2 (cortados), então o Portão duplo vale quando voltarem; (6) árvores nascem com tronco a pelo menos 2 tiles livres de outro tronco (os Grandes passam).

**Efeito no elenco da v0.2:** Dodo = Pequeno (era Diminuto); Paquicéfalo = **Médio** (era Pequeno) e **monta**; Utahraptor = Médio; Triceratops = Grande; Parassaurolofo (fora da v0.2) = Médio.

### Trechos do GDD que citam os portes antigos (só lista, sem edição)
- **4.2 inteira (linhas 85 a 100):** a tabela de seis portes (Diminuto, Pequeno, Médio, Grande, Muito grande, Gigante), as "Regras da tabela" (itens 2, 3 e 4: Portão quíntuplo, "Muito grande e Gigante só em clareira") e o parágrafo "Reclassificação do elenco da v0.2" com "Dodo = Diminuto; Paquicéfalo = Pequeno" e os percentuais de população (diminuto 39%, pequeno 30%, médio 29%, grande 2%, que também aparecem em `mapa-ilha.md` 5 e na linha 113).
- **Linha 796 (alforje por porte):** "1 diminuto, 2 pequeno, 4 médio e grande".
- **6.12 Montaria (linhas ~1042 a 1058):** a regra "Médio ou maior" continua, mas a tabela por espécie diz Paquicéfalo "não montável" (porte pequeno), Dodo e Oviraptor "porte pequeno ou diminuto", Triceratops "Grande" (ok) e o provisório "só Utahraptor e Triceratops montáveis, sem Stamina do dino".
- **Linha 1084 (selas):** "Uma sela serve às duas espécies (porte único)".
- **Outras citações de "porte" a revisar com `grep -n -i porte`:** linhas 19, 87, 115, 347, 495, 861, 864, 872, 1491 e 1522; e `mapa-ilha.md` linha 107 ("Dodo diminuto (16 px)") e a faixa por porte da linha 113.
- **Stamina:** a linha do GDD 5.13 que diz "a Stamina do dino não aceita pontos até haver montaria" precisa citar a fórmula por nível desta spec; o Provisório "sem Stamina do dino" está superado.

## 8. Calculado x precisa jogar

**Calculado:** as tabelas 4, 6 e 7, o tempo de encher o alforje (14,2 min), a regeneração de fome (seção 9).
**Precisa jogar:** se o vínculo por 1 refeição é cerimônia ou nada; a taxa de 25% do dino; o limite de 3 dinos; o raio de 20 tiles do perigo; os números de incubação e crescimento; se o corte do 50 no L30; os gatilhos 5 e 9; o tempo de montar; a leitura da barra de Stamina do dino; a lista de aliados no multiplayer.

## 9. Comer recupera a fome aos poucos (decidido em 07/11)

[decidido] a fome sobe gradualmente, não de uma vez. Números [premissa], base: queda 0,1/s e baga +10, cozida +35 (GDD 5.1); a regra vale ao jogador e ao domado (mesmo `FoodRules`).

| Campo | Valor | Marca |
|---|---|---|
| `taxa_recuperacao_s` | 2 pontos de fome por segundo, enquanto houver "fome pendente" | [premissa] |
| Baga (+10) | sobe em 5 s | calculado |
| Cozida (+35) | sobe em 17,5 s | calculado |
| Comer de novo durante a recuperação | **soma**: o novo valor entra em `fome_pendente`; a taxa continua 2/s (comer mais não acelera), então a segunda comida **espera na fila** | [premissa] |
| Limite | não se come (e não gasta o item) se `fome + fome_pendente >= 100` | [premissa] (já vale "não gasta se cheia", GDD 5.1) |
| Interrupção | dormir ou torpor não pausam; morrer zera a fila | [premissa] |
| Queda de 0,1/s durante a recuperação | continua; o saldo líquido é 1,9/s | calculado |
| Vínculo (seção 1) | a refeição do domado conta ao iniciar, não ao terminar | [premissa] |

Conta: 1 cozida (+35) leva 17,5 s; 3 cozidas seguidas, 52,5 s para +105 (a fome trava em 100: a 3ª só entra se couber). Com 0,1/s de queda, +35 rende 350 s, então a rampa de 17,5 s é 5% da duração: ninguém sente espera, mas impede "comer 10 bagas em 1 s" no meio de um combate para curar torpor indireto (a fome zerada sobe o torpor, GDD 5.10). **A validar:** se a fila de 2/s incomoda em emergência (fome zerada com torpor subindo: 17,5 s para a cozida pode ser lento); botão de ajuste é `taxa_recuperacao_s` (4/s = 8,8 s).

## 10. Pendências do dono
1. Aceitar a Stamina do dino com 100 base, 5 s de Galope, 3 s parado ao zerar (a conta dá 33,9% para quem gerencia, 27,8% para quem zera).
2. Aceitar a lista `aliados` por dino como definição de "aliado" sem tribo.
3. Confirmar o Brontossauro e o Triceratops com a mesma colisão de Grande (28x24, vão de 2).
4. Confirmar a taxa de recuperação de fome (2/s) e se vale para o domado.
