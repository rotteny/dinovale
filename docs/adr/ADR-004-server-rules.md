# ADR-004: `ServerRules`, regras do mundo em dados (ARQ-05)

**Data**: 2026-11-07
**Status**: Aceito (07/11/2026; implementado na E1)
**Decisores**: dono do projeto; proposta de `KURAMA`; implementação de `SORA` (E1 do `docs/design/corte-v02/shikamaru.md`)

## Contexto

O GDD 13 lista as regras que cada servidor pode mudar (multiplicadores, tempos, distâncias). Hoje esses números estão nas Resources de `game/data/balance/` e `game/data/world/`, que vão empacotadas no `.pck`: mudar uma delas pede reexportar o jogo. A E1 pede que o host local leia um arquivo de regras e que trocar uma chave mude o jogo sem recompilar. CRI-12, SOB-12, SOB-02 e as tarefas seguintes leem essas regras (`shikamaru.md`, ponto 5 da seção final).

Restrições já decididas:

- ADR-001: a autoridade é o servidor; o single-player é o host local. Só a autoridade aplica regra.
- ADR-002: dado externo só em JSON, lido com `SafeRead`; `ConfigFile` é proibido em `game/src/`; `user://saves/<mundo>/` é a pasta do mundo.
- ADR-003: ids estáveis em string.
- AGENTS.md, regra 4: número de balanceamento em `Resource`, nunca no código.

Risco apontado pelo `SHIKAMARU`: o ARQ-05 virar a refatoração geral de "tirar número do código". Este ADR limita o escopo às chaves que as etapas E1 a E5 consomem.

## Opções consideradas

1. **Só as Resources `.tres`**: já existem e têm inspetor. Contra: ficam dentro do `.pck`, então o jogo exportado não muda sem reexportar. Não atende à E1.
2. **JSON com todos os números do jogo, substituindo as Resources**: um lugar só. Contra: é exatamente a refatoração geral que o plano proíbe; perde o inspetor; mistura balanceamento de designer (dano por espécie) com opção de operador (multiplicador de coleta).
3. **JSON de opções de servidor por cima das Resources**: as `.tres` continuam sendo o padrão do jogo; o JSON do mundo guarda só as chaves do GDD 13, e o host aplica esse JSON sobre cópias das Resources ao carregar o mundo. Contra: o mesmo número aparece em dois lugares (padrão na `.tres`, valor do mundo no JSON).

## Decisão

Opção 3.

### O que é

`ServerRules` (`game/src/core/ServerRules.gd`, `RefCounted`) é o conjunto **imutável durante a sessão** dos valores efetivos das chaves do servidor. As Resources seguem sendo a fonte do padrão; o `ServerRules` só diz "neste mundo, este valor".

- **Chave absoluta** (ex.: `respawn_protecao_s`): o padrão é o campo da `.tres` correspondente. O host aplica o valor sobre uma **cópia** da Resource (`duplicate()`; na implementação a cópia é rasa e o campo trocado ganha um dicionário novo, o que basta porque nenhuma outra parte da Resource é alterada), e os consumidores continuam lendo a Resource como hoje. Nunca se escreve na Resource vinda de `preload`: ela é compartilhada pelo cache e o valor vazaria para outro mundo e para os testes.
- **Multiplicador** (ex.: `multiplicador_coleta`): o padrão é 1,0, que é a identidade, não um número de balanceamento. O consumidor recebe o `ServerRules` injetado (como já recebe `WorldRules`) e multiplica no ponto de uso.

Um número do GDD 13 nunca ganha um padrão próprio no `ServerRules.gd`: ou é a identidade (1,0) ou vem da `.tres`. A tabela de chaves em código guarda só **tipo e faixa válida**, que são contrato, não balanceamento.

### Onde fica no disco

| Situação | Caminho |
|---|---|
| Single-player (host local) | `user://saves/<mundo>/server_rules.json`, ao lado do `world.json` |
| Servidor dedicado (M3, futuro) | o mesmo caminho por padrão; `--server-rules=<caminho>` nos argumentos de usuário (`OS.get_cmdline_user_args()`) o substitui |

Formato:

```json
{
  "version": 1,
  "multiplicador_coleta": 1.0,
  "respawn_recurso": 1.0,
  "faixas_de_nivel": { "campina": [1, 12], "mata_baixa": [5, 25], "pedreira": [15, 35] },
  "respawn_protecao_s": 3.0,
  "respawn_fome_pct": 50,
  "eficiencia_fixa_ataque_jogador": 4.0,
  "eficiencia_fixa_ataque_carnivoro": 8.0
}
```

As chaves usam o nome do GDD 13 em português: o arquivo é lido pelo dono e por operador de servidor, e o termo tem de ser o mesmo da documentação (linguagem ubíqua). Os campos e métodos em GDScript ficam em inglês.

O arquivo é **do operador**: o jogo o escreve uma única vez, quando ele não existe (mundo novo ou mundo antigo sem o arquivo), com todas as chaves declaradas e os valores efetivos do momento. Depois disso o jogo só lê; nunca regrava, nem para "consertar". O arquivo não entra no envelope nem na versão do save (ADR-002): tem a própria `version`.

Trocar uma chave vale no próximo carregamento do mundo (voltar ao menu e carregar, ou reiniciar o servidor). Não há recarga a quente: as regras mudarem no meio da sessão quebraria a reprodutibilidade (R-C) e o que já foi validado.

### Validação

Leitura em duas funções, para testar sem disco:

- `ServerRules.parse(text: String, defaults: ServerRulesDefaults) -> ServerRules`: pura.
- `ServerRules.load_file(path: String, defaults: ServerRulesDefaults) -> ServerRules`: lê o arquivo e chama `parse`; se o arquivo não existe, escreve-o com os padrões.

`ServerRulesDefaults` é só o agrupamento das Resources de onde vêm os padrões (`RespawnRules`, `WorldRules`, `TamingRules`), para `parse` não depender de `preload`.

Por chave, com `SafeRead`:

| Caso | Resultado |
|---|---|
| Chave ausente | padrão; sem aviso |
| Tipo errado (`null`, texto, lista, `bool` onde se espera número) | padrão; aviso |
| Inteiro fracionário (`respawn_fome_pct: 50.5`) | padrão; aviso (`SafeRead.integer`) |
| Fora da faixa válida | **padrão, não o limite**; aviso |
| `inf` (o JSON aceita `1e99999`) | padrão; aviso (`SafeRead` recusa não finito) |
| Chave desconhecida (erro de digitação, chave de etapa futura) | ignorada; aviso com o nome |

`SafeRead.number` limita à faixa em vez de recusar. Para o `ServerRules`, número fora da faixa é erro do operador, e cair no limite esconderia o erro (ex.: `multiplicador_coleta: 1000` virar 10 sem ninguém saber). O `ServerRules` lê com `SafeRead.number(valor, NAN, -INF, INF)` e confere a faixa ele mesmo; se precisar se repetir, ganha um `SafeRead.number_in_range` que devolve o `fallback` fora da faixa. O comportamento atual de `SafeRead.number` não muda (o save depende dele).

Por arquivo:

| Caso | Resultado |
|---|---|
| Arquivo ausente | escreve com os padrões e segue |
| Maior que 16 KB, JSON inválido, raiz que não é dicionário | todos os padrões; aviso; **arquivo intocado** |
| `version` inválida ou maior que a conhecida (`SafeRead.format_version`) | todos os padrões; aviso; arquivo intocado |
| Falha ao escrever o arquivo novo | segue com os padrões em memória; aviso |

Os avisos ficam em `ServerRules.problems: PackedStringArray` e saem uma vez com `push_warning` ao carregar o mundo. Nunca `push_error` (o `error_counter` dos testes conta erro) e nunca aborta: o mundo sempre abre.

`faixas_de_nivel` é um dicionário de id de bioma (string, ADR-003) para `[mínimo, máximo]`. Ids aceitos: `campina`, `mata_baixa`, `pedreira`, mapeados para as constantes de terreno do `IslandMap` numa tabela única no `ServerRules.gd`. Cada bioma vale sozinho: entrada inválida (não é lista de dois inteiros, fora de [1, 50], mínimo maior que máximo) mantém o padrão daquele bioma; bioma desconhecido é ignorado com aviso. Biomas omitidos mantêm o padrão do `world_rules.tres`.

### Chaves desta etapa (E1 a E5)

Regra de escopo: **a chave entra no `ServerRules` no mesmo commit em que ganha consumidor.** Chave declarada sem consumidor mentiria no arquivo do operador (ele muda e nada acontece).

| Chave | Tipo e faixa | Padrão vem de | Consumidor | Entra em |
|---|---|---|---|---|
| `multiplicador_coleta` | número [0,1; 10] | 1,0 | colheita: `maxi(1, roundi(yield_amount x mult))`, idem `extra_yields` | E1 |
| `respawn_recurso` | número [0,1; 10] | 1,0 | volta do nó: `respawn_seconds / mult` (2 = volta duas vezes mais rápido; mesma convenção do `domar_velocidade` no 5.14) | E1 |
| `faixas_de_nivel` | dicionário, inteiros [1; 50] | `world_rules.tres` `level_bands` | `WildPopulation.populate` (Paquicéfalo hoje; Utahraptor nas tocas na E1) | E1 |
| `respawn_protecao_s` | número [0; 30] | `respawn_rules.tres` `protection_seconds` | `Player.respawn_at` | E1 |
| `respawn_fome_pct` | inteiro [10; 100] | `respawn_rules.tres` `hunger_ratio` x 100 | `Player.respawn_at` (`hunger_ratio = pct / 100`) | E1 |
| `eficiencia_fixa_ataque_jogador` | número [0; 100] | `taming_rules.tres` `attack_fixed_loss["player"]` | `TamingComponent` | E1 |
| `eficiencia_fixa_ataque_carnivoro` | número [0; 100] | `taming_rules.tres` `attack_fixed_loss["carnivore"]` | `TamingComponent` (o carnívoro só ataca na E3b; a perda já existe) | E1 |
| `raio_ronco_tiles` | inteiro [1; 32] | campo novo na Resource de regras do CRI-12 (8) | detecção do dormindo | E3b |
| `respawn_dist_agressivo_tiles` | inteiro [0; 64] | campo novo em `RespawnRules` (16), substitui `min_distance_from_wild` | `RespawnPicker` | E5 |
| `respawn_dist_semi_tiles` | inteiro [0; 64] | campo novo em `RespawnRules` (8) | `RespawnPicker` | E5 |
| `corpo_minutos` | inteiro [1; 120] | campo novo da Resource do corpo do jogador (10) | corpo do SOB-02 | E5 |
| `corpos_max_por_jogador` | inteiro [1; 10] | idem (3) | corpo do SOB-02 | E5 |

Conversão de tiles para pixels com `RespawnRules.tile_size`. Campo novo de Resource (E3b, E5) nasce na `.tres` com o valor do GDD, como as demais.

### O que NÃO entra

- **Chaves do GDD 13 sem consumidor até a E5**, cada uma entra com a sua tarefa: `multiplicador_refeicao`, `domar_velocidade` e `eficiencia_drena_tempo` (PRO-07; atenção: `taming_rules.tres` ainda tem `time_drain_per_second = 0.3`, o GDD decidiu 0,15, e a correção é do PRO-07, não daqui); `dino_ferido_minutos` e `perde_estoque_ao_acordar` (SOB-05); `afeto_decai` (CRI-07); `autosave_segundos` (SAV-04b, E18; o autosave atual segue no `save_rules.tres`); `cama_espera_s`, `cama_max_por_jogador` (E12); `pontos_por_nivel`, `valor_ponto`, `multiplicador_xp` (E6); `jogador_nivel_max`, `dino_nivel_max`, `dino_nivel_spawn_max`, `dino_teto_*` (PRO-20); `filtro_nomes` (CRI-27); `morte_item` (só `corpo` existe na E5; `perde` e `mantém` não têm código, então a chave mentiria); duração do ciclo e frequência da chuva (SOB-03, SOB-11).
- **`dano_fome`**: a E4 tira o dano de fome (fome zero leva ao desmaio). A chave fica obsoleta; o GDD 13 precisa ser atualizado pelo `SHIRO` para trocá-la pela duração do desmaio, se o dono quiser essa opção de servidor.
- **Geometria do mapa**: regiões de respawn do jogador (`respawn_regioes`: retângulos, pontos reserva, ids), posição das tocas, população por espécie, nós e cenário. Ficam em `respawn_rules.tres`, `world_rules.tres` e `lunata.json`. Elas mudam junto com o mapa, não por servidor; o operador escolhe regra, não desenha ilha.
- **Números de balanceamento que não são do GDD 13** (dano por espécie, vida, velocidade, alcance, `accept_delay`, `max_attempts`, raio livre): continuam nas `.tres`. Nenhum número sai do código nesta tarefa além das chaves acima.
- **Rede**: nenhum `@rpc`, nenhum envio do `ServerRules` ao cliente. Quando o M3 precisar mostrar uma regra no cliente (ex.: espera da Cama), o servidor manda o valor efetivo no estado, nunca o arquivo.
- **Tela de configuração do mundo no menu**: não há; o dono edita o JSON.

### Single-player e servidor dedicado no mesmo caminho

```text
Main (host) ao carregar o mundo
  -> ServerRulesDefaults (preloads das .tres)
  -> ServerRules.load_file(caminho do mundo ou --server-rules)
  -> cópias das Resources com as chaves absolutas aplicadas
  -> injeta Resources e ServerRules nos sistemas da autoridade
```

Só o host lê o arquivo. O código que aplica regra roda na autoridade (ADR-001, R-D), então em rede o cliente nunca precisa do arquivo e não pode alterá-lo. O servidor dedicado futuro difere apenas na origem do caminho; `parse`, validação, aplicação e consumidores são os mesmos. A escolha do caminho é uma função pura (`ServerRules.path_for(world_dir, user_args)`), testável hoje.

## Testes que o `SORA` deve escrever

Arquivo próprio `game/tests/server_rules_tests.gd`, rodando no `tools/check.sh`.

1. **Padrões**: `parse("{}")` devolve, para cada chave, o valor da `.tres` correspondente (absolutas) ou 1,0 (multiplicadores), sem problemas registrados.
2. **Tabela por chave** (para cada chave declarada): valor válido aplicado; ausente, `null`, texto, lista, `bool`, fracionário em chave inteira, abaixo e acima da faixa, `1e99999` caem no padrão e cada um registra problema.
3. **Arquivo malformado**: JSON inválido, raiz em lista, arquivo acima de 16 KB, `version` 0, 2 e `"1"` dão todos os padrões com problema; os bytes do arquivo são iguais antes e depois.
4. **Arquivo ausente**: `load_file` cria o arquivo com todas as chaves declaradas e `version`; a segunda carga devolve os mesmos valores e não reescreve (mesma data de modificação ou mesmos bytes).
5. **Chave desconhecida**: ignorada, problema com o nome da chave, demais chaves aplicadas.
6. **`faixas_de_nivel`**: sobrescrita parcial (só `pedreira`), bioma desconhecido, mínimo maior que máximo, lista de três elementos, fora de [1, 50]; cada bioma inválido mantém só o próprio padrão.
7. **Não vaza para o `preload`**: depois de aplicar `respawn_protecao_s = 10` sobre a cópia, `preload("res://data/balance/respawn_rules.tres").protection_seconds` segue igual.
8. **Consumidor nos dois estados** (critério do ARQ-05 no `PLANEJAMENTO.md`), um por chave da E1: coleta com 1,0 e 2,0 rende 1 e 2; nó volta em `respawn_seconds` e na metade com 2,0; com semente fixa, níveis nascidos dentro da faixa padrão e dentro da faixa trocada; proteção e fome ao renascer com padrão e com valor trocado; perda de Eficiência por ataque com padrão e trocada. As chaves da E3b e da E5 ganham o mesmo par de testes no commit em que entram.
9. **Caminho**: `path_for` sem argumento devolve `user://saves/<mundo>/server_rules.json`; com `--server-rules=x.json` devolve `x.json`; argumento vazio ou malformado cai no padrão.
10. **Arquitetura** (no teste de arquitetura existente): `ServerRules.load_file` só é chamado pelo host (`Main` ou o boot do mundo), nunca por `src/ui/` nem por componente; nenhum consumidor escreve em campo do `ServerRules` depois da carga; `ConfigFile` segue ausente de `game/src/`.

## Consequências

- **Positivas**: a E1 cumpre "trocar uma chave muda o jogo sem recompilar" no jogo exportado; consumidores atuais não mudam de assinatura para as chaves absolutas; o dedicado do M3 herda o mesmo carregamento; arquivo ruim nunca impede o mundo de abrir; o escopo é fechado por tabela, e cada chave nova tem dono e etapa.
- **Negativas / trade-offs**: o mesmo número existe na `.tres` (padrão do jogo) e no JSON do mundo (valor do mundo). Como o arquivo é escrito uma vez com os valores do momento, **mudar a `.tres` depois não altera mundos que já têm o arquivo**: para pegar o padrão novo, apaga-se a chave (ausente = padrão) ou o arquivo. Na E1, o arquivo terá 7 das chaves do GDD 13, não todas; o "Dono testa" da E1 ("tem as chaves do GDD 13") deve ser lido como "tem as chaves que o jogo já usa".
- **Revisitar se**: o dono quiser editar regras pelo menu (aí o jogo passa a escrever o arquivo e precisa de regra de mesclagem); mais de um mundo por instalação com regras compartilhadas; o M3 precisar de regra lida pelo cliente para predição; a lista de chaves passar de algumas dezenas (aí um esquema em dado substitui a tabela em código).
