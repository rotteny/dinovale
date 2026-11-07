# ADR-007: Ids estáveis de spawn e de nó, revisão do mapa por hash e save v5

**Data**: 2026-11-07
**Status**: Proposto
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 3 do roteiro da auditoria geral de 07/11)

## Contexto

O mapa da ilha é estático (`game/data/world/lunata.json`, gerado por `docs/design/mapa_export.py`) e o save v4 guarda só o delta: nós esgotados ou parciais (`world.resource_nodes`) e selvagens que mudaram (`world.wild`). O delta só vale se apontar para o mesmo ponto do mapa. A auditoria geral de 07/11 pôs "ids estáveis de spawn e nó gravados pelo exportador, com revisão por hash" e o save v5 entre os pré-requisitos de etapa nova.

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

## Decisão (recomendada)

Opção 3, com estes contratos:

- **Formato no mapa**: spawns e nós passam de `[x, y]` a `{"id": "...", "x": x, "y": y}`. O id é string curta e opaca (prefixo do tipo e contador, ex.: `w117`, `n1030`); ninguém extrai significado dele. Id nunca é reutilizado: o exportador guarda o maior contador já emitido no próprio arquivo.
- **Correspondência no exportador** (só em tempo de design, nunca no jogo): ponto do mesmo tipo dentro de um raio pequeno do ponto anterior herda o id (raio a decidir pelo dono; proposta: 2 tiles); o resto ganha id novo; id que sumiu é aposentado. O exportador imprime o relatório (mantidos, novos, aposentados) para revisão no PR.
- **Primeira exportação com ids**: os pontos de hoje recebem ids na ordem em que o jogo os numera hoje (selvagem pelo índice do `populate`, nó pela lista atual), para a migração do v4 ser uma conta pura, sem tabela.
- **Revisão do mapa por hash**: `revision` deixa de ser número escrito à mão e passa a ser o hash do conteúdo canônico do `lunata.json` sem o próprio campo (proposta: SHA-256 truncado em 16 hex), calculado pelo exportador. Um teste reprova se o hash gravado não bater com o conteúdo. Com ids estáveis a revisão deixa de ser a trava do delta: serve para avisar na HUD que o mapa mudou e para a migração abaixo.
- **Delta por id, de qualquer revisão**: `world.wild` e `world.resource_nodes` passam a usar `"id"`. Id desconhecido é ignorado (como hoje); o selvagem que volta passa por `_keep_on_island` se o ponto se moveu.
- **`from_dict` recusa espécie diferente**: `Dino.from_dict` passa a ler `species` e devolve `false` se não for a da criatura (estado sem `species`, save antigo, segue aceito). No delta do selvagem, espécie diferente faz a entrada ser ignorada e a criatura nascer nova; não derruba a carga inteira.

### Save v5, fechado agora, uma vez só

Recomendação: **não** manter o "v5 aberto durante a v0.2" que está em avaliação (`docs/contexto/save.md`). Fechar o v5 agora com as três mudanças que quebram o formato, juntas e numa só migração:

1. ids estáveis no delta (este ADR) e `world.map_revision` como texto (hash);
2. `world.time` e prazos absolutos (ADR-006);
3. `player_id` aleatório: 32 hex de `Crypto.generate_random_bytes(16)` na criação do mundo (fora da simulação, não fere a regra de RNG com seed); o `WorldSnapshot` passa a achar o jogador local por `world.local_player_id`, não pelo literal `"local"`.

Campo novo depois disso entra aditivo, com padrão no `from_dict` e sem subir a versão (como `world.carcasses`); só mudança incompatível vira v6.

### Migração `SaveMigrations.v4_to_v5` (pura, sem ler mapa nem `Resource`)

- **Mesma revisão** (`map_id == "lunata"` e `map_revision == 2`): `{"index": i}` vira `{"id": "w<i>"}` e o id de nó `"<tipo>_<k>"` vira o id que a primeira exportação deu a ele (regra fixa, escrita na migração). `map_revision` vira o hash da primeira exportação com ids.
- **Outra revisão ou `legacy_coordinates`**: o delta de selvagem e de nó é descartado, como o v4 já faz entre revisões; domados em `entities` passam intactos.
- `player_id "local"` vira um id novo aleatório em `players` e em todo `owner_player_id` e `feeder_player_id` que apontava para `"local"`; a migração recebe o id gerado como argumento, para continuar pura e testável.
- Tempo: a parte do ADR-006.
- Fixture `v5.json`; `v4.json` nunca é removida.

## Consequências

- **Positivas**: acrescentar espécie, spawn ou nó deixa de corromper o save; a revisão não depende de lembrar de subir um número; estado de uma espécie nunca cai em outra; um único passo de formato antes das etapas novas, com o `player_id` que o M3 precisa já certo.
- **Negativas / trade-offs**: `lunata.json` cresce (cerca de 1.460 pontos ganham id); o exportador fica mais complexo e passa a depender do arquivo anterior; ponto movido além do raio perde o delta (nasce novo), o que é aceitável para selvagem e nó; a migração v4 só preserva o delta de quem está na revisão 2.
- **Riscos**: quem gerar o mapa sem o arquivo anterior emite ids novos para tudo (o exportador deve recusar rodar sem ele, salvo flag explícita de mapa novo); o hash precisa de serialização canônica estável (ordem de chaves e números), senão muda sem o conteúdo mudar.
- **Revisitar se**: houver mais de um mapa por mundo (o id passa a ser `map_id` + id); o mapa passar a ser editado à mão ou por ferramenta que não seja o exportador.

## Decisões para o dono

1. Aprovar id opaco do exportador (opção 3) e o raio de correspondência (proposta: 2 tiles).
2. Aprovar revisão por hash e aplicar o delta por id mesmo com a revisão diferente.
3. Fechar o v5 agora (ids, `world.time`, `player_id`) em vez do v5 aberto durante a v0.2.
4. Aceitar que save v4 de revisão diferente da 2 perde o delta de selvagens e nós (domados ficam).
