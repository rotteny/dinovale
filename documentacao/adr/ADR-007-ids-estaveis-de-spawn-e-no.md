# ADR-007: Ids estáveis de spawn e de nó, revisão do mapa por hash e save v5

**Data**: 2026-11-07
**Status**: Aceito (07/11/2026; decisões 4 a 6 do bloco A do dono). Emenda de 07/11 (bandos em posição aleatória por região): **Aceita** (07/11/2026, requisito do dono: bandos longe uns dos outros e em posição aleatória dentro da região certa).
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 3 do roteiro da auditoria geral de 07/11)

## Contexto

O mapa da ilha é estático (`game/data/world/lunata.json`, gerado por `documentacao/design/mapa_export.py`) e o save v4 guarda só o delta: nós esgotados ou parciais (`world.resource_nodes`) e selvagens que mudaram (`world.wild`). O delta só vale se apontar para o mesmo ponto do mapa. A auditoria geral de 07/11 pôs "ids estáveis de spawn e nó gravados pelo exportador, com revisão por hash" e o save v5 entre os pré-requisitos de etapa nova.

Fatos do código hoje (conferidos em 07/11):

- **O selvagem é identificado pela ordem de criação.** `WildPopulation.populate` numera com `created.size()` (`WildPopulation.gd:70`) percorrendo `SPECIES` na ordem (linha 54) e, dentro de cada espécie, a lista do mapa, pulando a célula do tutorial e as repetidas, até `limit`. O `Main` passa `limit = wild_population_max - 1` (`Main.gd:180`; 108 em `world_rules.tres`, logo 107). No mapa atual: índices 0 a 106 são Paquicéfalos, 107 a 116 são Utahraptores.
- **Consequência:** qualquer mudança na lista de Paquicéfalos (inserir, remover, mover para antes ou depois da célula do tutorial) ou no `wild_population_max` desloca todos os índices dos Utahraptores, sem nada no save perceber.
- **O delta não confere a espécie.** Com a mesma revisão, `restore` aplica `creature.from_dict(entry["state"])` na criatura do índice (`WildPopulation.gd:197-202`); `Dino.from_dict` não lê `species` (só `to_dict` o escreve, `Dino.gd:221`). Um índice deslocado aplica o estado de um Paquicéfalo num Utahraptor.
- **O id de nó também é posição em lista.** `ResourceField` monta `"%s_%d" % [kind, i + 1]` (`ResourceField.gd:45`) sobre a lista que o exportador grava ordenada por coordenada (`mapa_export.py:394`). Uma árvore nova em coordenada menor renumera todas as seguintes (1.029 árvores hoje).
- **A revisão é manual.** `REVISION = 2` em `mapa_export.py:27`; o commit que acrescentou os 10 spawns de Utahraptor manteve `"revision": 2` no `lunata.json`. Desta vez não corrompeu nada (os Utahraptores entraram depois dos Paquicéfalos e saves antigos não tinham índice acima de 106), mas a proteção dependeu de sorte, não de regra.
- **`player_id` é fixo.** ADR-003 prometeu 32 hex aleatórios gerados na criação do mundo; o código usa `LOCAL_PLAYER_ID := "local"` (`Player.gd:45`, padrão do campo na linha 50) e o `WorldSnapshot` procura o jogador por esse literal (`WorldSnapshot.gd:54` e `:87`).

## Opções consideradas

1. **Id por coordenada** (`"tree@40,117"`): estável enquanto o ponto não muda. Contra: quebra quando o ponto anda um tile, e o mapa ainda vai ser redesenhado; duas espécies na mesma célula colidem; o save passa a depender da geometria.
2. **`espécie:índice`** (`"utahraptor:3"`): resolve o deslocamento entre espécies. Contra: inserir ou remover um ponto no meio da lista da espécie renumera os seguintes; é o mesmo defeito em escala menor.
3. **Id opaco gravado pelo exportador e mantido entre revisões**: cada spawn e cada nó ganha um id no `lunata.json`; o exportador lê o arquivo anterior e preserva os ids. Contra: o exportador ganha estado (o arquivo anterior) e uma regra de correspondência.

## Decisão

Opção 3, com estes contratos:

- **Formato no mapa**: spawns e nós passam de `[x, y]` a `{"id": "...", "x": x, "y": y}` (implementado como listas paralelas `spawn_ids`/`node_ids`, `mapa_export.py:16`; mesmo efeito). *Para selvagens, substituído pela Emenda de 07/11: o mapa deixa de ter ponto de spawn e passa a ter vaga de bando; nós seguem como aqui.* O id é string curta e opaca (prefixo do tipo e contador, ex.: `w117`, `n1030`); ninguém extrai significado dele. Id nunca é reutilizado: o exportador guarda o maior contador já emitido no próprio arquivo.
- **Correspondência no exportador** (só em tempo de design, nunca no jogo; *para selvagens, a Emenda troca o raio por correspondência de vaga por espécie e região*): ponto do mesmo tipo dentro de um raio pequeno do ponto anterior herda o id (raio a decidir pelo dono; proposta: 2 tiles); o resto ganha id novo; id que sumiu é aposentado. O exportador imprime o relatório (mantidos, novos, aposentados) para revisão no PR.
- **Primeira exportação com ids** (*para selvagens, superado pela Emenda: os ids `w<n>` são aposentados e o delta deles cai na regra de id desconhecido*): os pontos de hoje recebem ids na ordem em que o jogo os numera hoje (selvagem pelo índice do `populate`, nó pela lista atual), para a migração do v4 ser uma conta pura, sem tabela.
- **Revisão do mapa por hash**: `revision` deixa de ser número escrito à mão e passa a ser o hash do conteúdo canônico do `lunata.json` sem o próprio campo (proposta: SHA-256 truncado em 16 hex), calculado pelo exportador. Um teste reprova se o hash gravado não bater com o conteúdo. Com ids estáveis a revisão deixa de ser a trava do delta: serve para avisar na HUD que o mapa mudou e para a migração abaixo.
- **Delta por id, de qualquer revisão**: `world.wild` e `world.resource_nodes` passam a usar `"id"`. Id desconhecido é ignorado (como hoje); o selvagem que volta passa por `_keep_on_island` se o ponto se moveu.
- **`from_dict` recusa espécie diferente**: `Dino.from_dict` passa a ler `species` e devolve `false` se não for a da criatura (estado sem `species`, save antigo, segue aceito). No delta do selvagem, espécie diferente faz a entrada ser ignorada e a criatura nascer nova; não derruba a carga inteira.

### Save v5, fechado agora, uma vez só

Decidido: **não** manter o "v5 aberto durante a v0.2" que estava em avaliação (`documentacao/contexto/save.md`). O v5 fecha agora com as cinco mudanças que quebram o formato ou mudam a geração, juntas e numa só migração:

1. ids estáveis no delta (este ADR) e `world.map_revision` como texto (hash);
2. `world.time` e prazos absolutos (ADR-006);
3. `player_id` aleatório: 32 hex de `Crypto.generate_random_bytes(16)` na criação do mundo (fora da simulação, não fere a regra de RNG com seed); o `WorldSnapshot` passa a achar o jogador local por `world.local_player_id`, não pelo literal `"local"`.
4. **`sex` em todo Dino** (`"f"` ou `"m"`, imutável depois de nascer, sem efeito em atributo nem dieta): `Dino.to_dict`/`from_dict` passam a escrever e ler o campo. O domado sempre o grava; o selvagem o grava quando entra no delta (doma começou, ferido), para que mudar a regra de geração nunca troque o sexo de um dino que o jogador já tocou. Gravado e derivado diferentes: vale o gravado.
5. **`world.next_entity_id` como contrato**: o campo já é gravado (`WorldSnapshot.gd:42`, lido em `:126-127`; contador em `WorldAuthority.next_entity_id`), mas os ids do jogador e do primeiro dino ainda são fixos (`WorldSnapshot.gd:13-14`). No v5 ele passa a ser obrigatório e a única fonte de id de entidade nascida em jogo (ovo, filhote, domado novo), nunca reutilizado; o v5 não muda o formato do campo, só a regra.

### Nível e sexo do selvagem pela semente do spawn

*Emenda de 07/11: a chave do fluxo passa a ser `["wild", world_seed, member_id, ...]`, com `member_id` da vaga e da geração do bando (ver a emenda).* Hoje o nível sai de um fluxo único por mapa, sorteado em sequência (`WildPopulation.gd:51-52` e `:66`): mudar a lista de spawns muda o nível de selvagens que nem estão no delta, e com sexo uma fêmea já vista viraria macho. Decidido: cada spawn tem o próprio fluxo, `SeededRng.seed_from(["wild", map.seed_value, spawn_id, "level"])` para o nível e `[..., "sex"]` para o sexo (fluxos separados, para um sorteio novo nunca deslocar o outro). Sexo meio a meio por espécie, com a proporção em dado, não no código. O mesmo spawn gera o mesmo dino em qualquer revisão que mantenha o id.

Campo novo depois disso entra aditivo, com padrão no `from_dict` e sem subir a versão (como `world.carcasses`); só mudança incompatível vira v6.

### Migração `SaveMigrations.v4_to_v5` (pura, sem ler mapa nem `Resource`)

- **Mesma revisão** (`map_id == "lunata"` e `map_revision == 2`): `{"index": i}` vira `{"id": "w<i>"}` e o id de nó `"<tipo>_<k>"` vira o id que a primeira exportação deu a ele (regra fixa, escrita na migração). `map_revision` vira o hash da primeira exportação com ids.
- **Outra revisão ou `legacy_coordinates`**: o delta de selvagem e de nó é descartado, como o v4 já faz entre revisões; domados em `entities` passam intactos.
- `player_id "local"` vira um id novo aleatório em `players` e em todo `owner_player_id` e `feeder_player_id` que apontava para `"local"`; a migração recebe o id gerado como argumento, para continuar pura e testável.
- Sexo: domado de `entities` sem `sex` recebe `["f", "m"][SeededRng(["sex", "v4", entity_id]).next_below(2)]`, determinístico e sem ler mapa (rodar duas vezes dá o mesmo resultado; teste de idempotência). Selvagem do delta mantido não ganha `sex` na migração: na carga vale o derivado do spawn, como para o selvagem sem mudança.
- `world.next_entity_id` passa como está (o v4 já o grava); a migração só garante que ele é maior que todo id em `entities`.
- Tempo: a parte do ADR-006.
- Fixture `v5.json`; `v4.json` nunca é removida.

## Consequências

- **Positivas**: acrescentar espécie, spawn ou nó deixa de corromper o save; a revisão não depende de lembrar de subir um número; estado de uma espécie nunca cai em outra; um único passo de formato antes das etapas novas, com o `player_id` que o M3 precisa já certo.
- **Negativas / trade-offs**: `lunata.json` cresce (cerca de 1.460 pontos ganham id); o exportador fica mais complexo e passa a depender do arquivo anterior; ponto movido além do raio perde o delta (nasce novo), o que é aceitável para selvagem e nó; a migração v4 só preserva o delta de quem está na revisão 2.
- **Riscos**: quem gerar o mapa sem o arquivo anterior emite ids novos para tudo (o exportador deve recusar rodar sem ele, salvo flag explícita de mapa novo); o hash precisa de serialização canônica estável (ordem de chaves e números), senão muda sem o conteúdo mudar.
- **Revisitar se**: houver mais de um mapa por mundo (o id passa a ser `map_id` + id); o mapa passar a ser editado à mão ou por ferramenta que não seja o exportador.

## Decisões do dono (07/11/2026, bloco A; numeração da consolidação)

4. **Aprovado**: id opaco gravado pelo exportador (opção 3), com raio de correspondência de 2 tiles.
5. **Aprovado**: revisão do mapa por hash e delta aplicado por id mesmo com revisão diferente.
6. **Aprovado**: save v5 fechado agora, com ids, `world.time`, `player_id` aleatório, `sex` e `next_entity_id`; nível e sexo do selvagem pela semente do spawn.

A perda do delta de selvagens e nós em save v4 de revisão diferente da 2 (domados ficam) não foi votada à parte: fica aceita como consequência da decisão 6, já que o v4 não tem como apontar o ponto certo nessa situação.

## Emenda de 07/11: bandos em posição aleatória por região

**Status da emenda**: Aceita (07/11/2026, implementa o requisito do dono). **Decisores**: dono do projeto; proposta de `KURAMA`.

### Contexto da emenda

Requisito do dono (07/11), nas palavras dele: "O bando nunca deve nascer próximo ao outro, para pulverizar pequenos bandos espalhados. O local de nascimento dos bandos também deve ser aleatório, dentro das regiões apropriadas, para não ter, por exemplo, jacaré nascendo no deserto." Junto com `documentacao/design/corte-v02/bandos-e-dano-em-area.md` (bandos de 1 a 4, espaçamento por espécie e entre espécies), isso contradiz o modelo deste ADR, em que cada selvagem é um ponto fixo gravado pelo exportador.

Fatos do código (conferidos em 07/11):

- O exportador sorteia os pontos uma vez, com semente fixa do mapa (`spawns`, `mapa_export.py:297`; `utahraptor_spawns`, `:345`), e os grava em `spawns`/`spawn_ids` (`:512`, ids de `assign_ids`, `:405`). Todo mundo novo tem os mesmos selvagens nos mesmos lugares.
- `WildPopulation.populate` cria um selvagem por ponto (`WildPopulation.gd:54-81`), com nível e sexo semeados por `map.seed_value` e pelo id do ponto (`:71-72`, `:85-88`). Não existe grupo no dado.
- Não existe semente por mundo: `map.seed_value` é a do mapa (igual para todos os mundos); o único sorteio por mundo hoje é o respawn do jogador, `[world_id, _respawn_count]` (`Main.gd:298`).
- Selvagem morto não volta: o id fica em `_dead` e o delta grava `{id, dead: true}` (`WildPopulation.gd:45`, `:161-162`). Não há respawn de selvagem.
- O estado salvo de um selvagem já leva a posição (`Dino.to_dict`, `Dino.gd:237`).
- Zona ativa e distante: `active_radius_tiles = 16`, `far_radius_tiles = 40` (`ZoneRules.gd:8-10`).
- Ilha atual: campina 8.012 tiles, mata-baixa 7.610, pedreira 3.661, praia 2.100 (contado no `lunata.json`).

### Decisão proposta

**1. O que é estável: a vaga de bando, não o ponto.** O exportador grava `spawn_slots`, lista de vagas com id opaco e nunca reutilizado (prefixo `g`, contador `id_counter.g`): `{"id": "g7", "species": "paquicefalo", "region": "r_campina", "size": 3}`. Espécie, região permitida e tamanho são estáveis; a **posição não está no mapa**. O tamanho fica entre `group_size_min` e `group_size_max` da espécie (o `Resource` é o limite; o mapa só escolhe dentro dele; fora do limite, a carga satura e avisa).

**2. Região = máscara gravada pelo exportador.** `spawn_regions`: `{"r_campina": {"terrains": [3], "runs": [[y, x0, x1], ...]}}`, já filtrada pelo bioma, pela distância do mar e pelos tiles bloqueados por nó e cenário (o mesmo `placer.blocked` de hoje). Regiões com nome permitem manter o desenho de `mapa-ilha.md`: `r_nucleo` (anel de 6 a 16 tiles do início), `r_limiar`, `r_campina`, `r_mata`, `r_tocas` (mata-baixa a até 5 tiles de uma toca), `r_pedreira`. O jogo recusa, na carga, tile de região cujo terreno não esteja em `terrains` nem no `spawn_terrains` da espécie da vaga: "jacaré no deserto" é impossível por construção e verificado em dois lugares.

**3. Posição pela semente do mundo, na autoridade.**
- `world.seed`: inteiro de 52 bits (o JSON guarda número como real de 64 bits, exato só até 2^53), de `Crypto.generate_random_bytes(8)` mascarado na criação do mundo (fora da simulação, como o `player_id`). Mundos diferentes, bandos em lugares diferentes; o mesmo mundo, sempre os mesmos.
- **Disposição inicial (geração 0)** é função pura `layout(world_seed, map)`: vagas em ordem crescente do número do id (vaga nova sempre entra no fim, então acrescentar vaga não move as existentes); para cada vaga, candidatos do fluxo `SeededRng.seed_from(["wild", world_seed, slot_id, 0, "pos"])`, um tile uniforme da máscara por tentativa, até `group_spawn_attempts` (dado, [premissa] 30). Aceita o primeiro centro que respeita a distância de todo centro já posto; esgotadas as tentativas, varre a máscara a partir de um ponto sorteado (só dá "sem lugar" se realmente não há). Se uma vaga ainda assim fica sem lugar, a disposição inteira é refeita com a variante seguinte do fluxo (até 8 passadas; `tries` = número da passada), o que acontece em poucas sementes e continua determinístico.
- **Distância entre dois bandos A e B quaisquer**: `max(min_cross_species_spacing_tiles, se mesma espécie: min_group_spacing_tiles da espécie)`. A distância entre espécies vale para **todo par**, inclusive da mesma espécie, como pediu o dono; o espaçamento por espécie só a aumenta. O Paquicéfalo do tutorial (marco fixo `paquicefalo_tutorial`, não é vaga) entra no layout como um centro já posto, e o início tem raio livre `group_start_clearance_tiles` ([premissa] 6, para o núcleo continuar perto).
- **Membros**: cada um a até `cohesion_radius_tiles` do centro, em tile da máscara, do fluxo `[..., slot_id, gen, "member", k]`. Id do membro: `"<slot>.<gen>.<k>"` (ex.: `g7.0.2`, cabe no `MAX_ID_LENGTH` 32). Nível e sexo: `["wild", world_seed, member_id, "level"|"sex"]`; faixa de nível pelo terreno do tile do membro (`level_band_of`, como hoje).
- **Só a autoridade sorteia.** O cliente (M3) recebe os selvagens como entidades com posição; nunca roda `layout` nem respawn, mesmo sendo determinístico, porque o respawn depende do estado do servidor (jogadores e bandos vivos).

**4. Respawn de bando.**
- Vale a frase 7 do documento de bandos: membro morto ou domado não é reposto; o bando continua com os que restam. Quando **nenhum membro selvagem da geração atual está vivo** (todos mortos ou domados), a vaga marca `due_at = time + group_respawn_seconds` (dado por espécie, [premissa] 1.200 s de jogo; regra de prazo do ADR-006: duração decidida no evento guarda quando vence).
- No primeiro tick com `time >= due_at` (nunca dentro de `from_dict`), a autoridade sorteia o centro da geração `gen + 1` na mesma região, fluxo `["wild", world_seed, slot_id, gen + 1, "pos", tries]`, exigindo: a distância do item 3 de todo **bando vivo**; e distância de todo jogador conectado de pelo menos `group_respawn_player_clearance_tiles` (dado em `world_rules`, [premissa] 40 = `far_radius_tiles`: o bando novo nasce dormente, fora da tela e fora da zona distante; um teste garante que o dado nunca fica abaixo de `far_radius_tiles`).
- Se nenhum candidato serve, `tries += 1` e `due_at = agora + group_respawn_retry_seconds` ([premissa] 60 s); o fluxo ganha `tries` no fim (só quando maior que 0). Depois de `group_respawn_relax_after_tries` (3) falhas seguidas relaxa SÓ a distância do jogador, para `group_respawn_relaxed_clearance_tiles` (24); a distância entre bandos e a região nunca relaxam. Nunca bloqueia o tick. (Decisão do dono de 07/11, em `bandos-e-dano-em-area.md` 3.1; substitui o "nunca relaxa".)
- **Determinismo e idempotência**: dado o mesmo estado (semente, geração, `tries`, bandos vivos, posição dos jogadores no tick), o resultado é o mesmo. Como os jogadores fazem parte da entrada, o centro escolhido **é gravado** no momento em que o bando renasce; recarregar o save não sorteia de novo. Salvar antes do vencimento e carregar resolve no primeiro tick com o mesmo fluxo (o centro pode mudar só se os jogadores estiverem em outro lugar, o que é correto). Teste do `LEVI`: matar o bando, salvar, carregar e avançar o relógio dá o mesmo centro que avançar sem salvar, com os jogadores parados.

**5. Save: continua v5, só com campos aditivos (sem v6).** Pela regra deste ADR ("campo novo entra aditivo, com padrão no `from_dict`"):
- `world.seed` (opcional). Ausente (save v5 anterior à emenda): usa `map.seed_value`, então esses mundos ficam todos com a mesma disposição, válida e estável.
- `world.wild_groups` (opcional, padrão lista vazia): uma entrada **só para vaga que não está intacta**: `{"slot": "g7", "gen": 1, "center": [x, y], "due_at": 1234.5, "tries": 0}`. `center` é gravado quando `gen > 0` ou quando algum membro está no delta (a coleira do bando precisa do centro, e uma revisão do mapa que tire outra vaga não pode mover o centro de um bando que o jogador já tocou); `due_at` e `tries` só enquanto espera o respawn. Vaga intacta de geração 0 é recalculada por `layout`, custo zero no save. Leitura com `SafeRead`: `gen` entre 0 e 2^31, `center` dentro do mapa e num tile da região (senão a entrada é descartada e a vaga volta ao layout), `due_at` limitado a `time + group_respawn_seconds`.
- `world.wild` mantém o formato (`{id, state|dead|tamed}`), agora com o id do membro. Entrada de geração diferente da atual da vaga é ignorada e some no próximo save.
- **Por que não precisa de v6**: nada muda de tipo nem de significado em campo existente; os ids `w<n>` de um save v5 anterior viram ids desconhecidos, e o v5 já trata isso (ignorado; estado com doma em andamento ou comida vira entidade, `WildPopulation.gd:200-215`). Domados em `entities` passam intactos. O único efeito é de jogo: selvagens tocados nesse save renascem em outro lugar, e o morto passa a poder voltar pela regra de respawn. Se o dono preferir manter o delta antigo, aí sim seria v6 com tabela `w<n> -> membro`, e não vale: o ponto antigo não tem correspondência com a vaga nova.
- Muda a frase de `documentacao/contexto/save.md` "morto não volta": passa a ser "membro morto não volta; o bando renasce inteiro, em outro lugar, quando o último membro selvagem morre ou é domado". Atualizar o documento quando a emenda for aceita.

**6. Exportador.**
- **Sai**: `spawns` e `spawn_ids` de selvagem (e `spawns()`/`utahraptor_spawns()` como lista de pontos); `id_counter.w` fica como histórico, nunca reutilizado. O Paquicéfalo do tutorial continua marco fixo; o sexo dele passa a vir de `["tutorial"]` (o fallback que `Main.gd:189` já tem); o tutorial é domado e já grava `sex`, então save existente não muda.
- **Entra**: `spawn_regions` (máscara RLE) e `spawn_slots`, a partir de uma tabela no exportador por (espécie, região, tamanhos), com os números do documento de bandos (8 vagas de Dodo, 20 de Paquicéfalo (20 focos, não 24: ver 3.1 do documento), 4 de Utahraptor, 4 de Triceratops; 36 vagas, 110 dinos).
- **Correspondência de vaga** (troca o raio de 2 tiles para selvagens): para cada par (espécie, região), as vagas anteriores em ordem de id ficam com o mesmo id; tamanho diferente mantém o id; excedente é aposentado; falta ganha id novo. O relatório (mantidos, novos, aposentados) continua no PR.
- `canonical()` e `content_hash` passam a cobrir `spawn_regions` e `spawn_slots` (vagas ordenadas por id, runs ordenadas). O formato do arquivo do mapa sobe para `FORMAT = 2` (do mapa, não do save); `IslandMap.load_dict` lê os dois campos novos.
- **Verificação de capacidade no exportador** (sem reimplementar o `layout` em Python, para não haver dois algoritmos que divergem): para cada região, área da máscara contra o disco de exclusão das vagas dela; acima de uma ocupação de [premissa] 50% o exportador recusa. A garantia real é um teste em GDScript (abaixo).

**7. Custo e falha controlada.**
- **Custo na carga (ilha atual)**: decodificar as máscaras, no máximo uns 21 mil tiles (campina, mata-baixa, pedreira e praia somados), uma vez, em `PackedInt32Array` por região; `layout` com 36 vagas × até 30 tentativas × até 37 centros ≈ 40 mil comparações de distância, mais 110 membros × até 20 tentativas. Estimativa: poucos milissegundos em GDScript, uma vez por carga (não por quadro). Teste com orçamento, [premissa] 20 ms na máquina do CI. O respawn custa o mesmo para uma vaga só, e só no evento.
- **Sem espaço válido na geração 0**: a vaga fica vazia neste mundo (não nasce), um `push_warning` com o id da vaga, e o mundo carrega normalmente; nunca relaxa a distância nem põe o bando fora da região. Membro sem tile livre no raio: o bando nasce menor, nunca abaixo de 1. Teste obrigatório (`LEVI`): `layout` com 64 sementes não deixa nenhuma vaga vazia e cumpre as frases testáveis 1 a 5 do documento de bandos (distâncias e pior caso por tela, que dependem só das regras, não da posição).
- **Sem espaço no respawn**: adia (item 4), sem limite de tentativas; `tries` só muda o fluxo.

### Consequências da emenda

- **Positivas**: cada mundo tem disposição própria e reprodutível; bando sempre na região certa; distância mínima entre todo par de bandos garantida por construção; mudar a quantidade de bandos é mudar a tabela de vagas, sem mexer em pontos; o mapa fica menor (perde 118 pontos, ganha 36 vagas e as máscaras).
- **Negativas / trade-offs**: perde-se o controle fino de "este bando aqui"; o designer controla por região, não por ponto; selvagens já tocados em saves v5 anteriores renascem em outro lugar (aceitável no M0; nada do jogador se perde); o save ganha `world.wild_groups`; o respawn depende de onde os jogadores estão, então o centro tem de ser gravado.
- **Riscos**: (a) região pequena perto do acampamento do jogador (ex.: `r_tocas`) pode passar muito tempo sem respawn por causa da distância de 40 tiles: o teste deve medir o tempo de espera com o jogador parado em cada região; (b) o layout depende da ordem das vagas: remover uma vaga pode mover vagas posteriores que estão intactas (só elas; quem está no delta tem centro gravado), o que é aceitável; (c) o `layout` precisa de serialização estável da semente e de iteração estável das máscaras (ordem das runs fixada no exportador), senão a mesma semente dá mundos diferentes entre versões; (d) save v5 sem `world.seed` fica com a disposição comum a todos os mundos, e é por isso que o padrão é a semente do mapa, não um sorteio na carga (sortear na carga daria disposição diferente a cada vez).
- **Revisitar se**: houver bioma por chunk gerado (M9): a máscara vira função do chunk, a regra de vaga continua; o dono quiser posição fixa para algum bando (vaga com `region` de 1 tile resolve, sem mudar o modelo).
- **Documentos a ajustar quando aceita** (não alterados agora): `documentacao/design/corte-v02/bandos-e-dano-em-area.md`, observação de dado no fim da seção 3 ("`spawn_groups` paralelo a `spawn_ids`; id por ponto continua"), que esta emenda substitui; `documentacao/contexto/save.md` (formato v5, campos aditivos e frase "morto não volta").

### Decisões pedidas ao dono

1. Vaga de bando com posição sorteada pela semente do mundo, em região gravada pelo exportador (itens 1 a 3).
2. Bando renasce inteiro, em outro lugar da região, quando o último membro selvagem morre ou é domado; com quais números de espera (`group_respawn_seconds`) e de distância do jogador (40 tiles proposto).
3. Saves v5 anteriores perdem o delta de selvagem (renascem em outro lugar), sem v6.
