# ADR-002: Formato, versão e restauração de save

**Data**: 2026-11-05
**Status**: Aceito (05/11/2026, aprovado pelo dono)
**Decisores**: dono do projeto; proposta de `KURAMA`

## Contexto

Já existe `to_dict`/`from_dict` em todos os componentes e corpos, com roundtrip por JSON testado, mas não existe arquivo, envelope nem versão. `InventoryComponent._sanitize` é o modelo certo de leitura defensiva. O resto não acompanha. Verificado na 4.7.2 com o código atual:

- `Dino.from_dict({"position": "oi"})` e `{"health": 5}` dão erro de script e **abortam no meio**, deixando a entidade meio restaurada. O mesmo vale para `{"health": {"max": null}}` e `{"max": [1, 2]}`, pois `float()` não aceita esses tipos.
- `position` aceita `inf`: `JSON.stringify` grava INF como `1e99999`, e o parse devolve `inf`. NaN vira `null`.
- `max` vem do save em Health, Torpor, Stamina e Hunger, com `max: 1e308` aceito. Já a capacidade do inventário vem da cena, e essa é a regra certa.
- Todo número de JSON volta como `float`, e inteiros acima de 2^53 perdem precisão (`9007199254740993` não sobrevive ao roundtrip). A seed e o estado do RNG são de 64 bits.

## Opções consideradas

1. **JSON texto**: legível, com diff, validável e sem execução de código. Maior e sem tipos.
2. **Binário `store_var`**: compacto, mas opaco, e mais difícil de migrar e de testar por fixture.
3. **Recurso Godot (`.tres`, `.res`)**: rejeitado. Pode embutir script, o que é execução de código por um save baixado (R6).

## Decisão

Opção 1, em `user://saves/<mundo>/world.json`. A pasta por mundo já deixa lugar para `chunks/x_y.json` no M4.

```json
{
  "format_version": 1,
  "game_version": "0.1.0",
  "saved_at": "2026-11-05T12:00:00Z",
  "world": { "seed": "9007199254740993", "next_entity_id": 18 },
  "players": [ { "player_id": "9f2c...", "entity_id": 1, "state": {} } ],
  "entities": [ { "id": 7, "type": "dino", "species_id": "...", "state": {} } ]
}
```

Em `state` vai o `to_dict` atual, com os ajustes abaixo.

**Difere do item 7.2 do plano:** `players` é lista, não um `player` único. Um mundo de servidor tem vários personagens, inclusive de quem está offline; fazer assim na v1 custa nada e evita a primeira migração.

**Versão.** `format_version` só sobe quando o formato muda. `game_version` e `saved_at` são informativos: nada na simulação os lê. A v1 congela na primeira build entregue a alguém de fora; até lá muda sem migração.

**Migração.** Funções puras encadeadas em `SaveMigrations` (`v1_to_v2`, ...), de `Dictionary` para `Dictionary`, com fixture `tests/fixtures/saves/vN.json` que nunca é removida. Migração não lê registry, cena nem classe de jogo: ela é congelada no tempo, e esses mudam. Roda em memória; o arquivo só é regravado no próximo save. Renomear item ou espécie não é migração, é alias (ADR-003).

**Escrita.** Grava `world.json.tmp`, relê e valida o envelope. Depois apaga o `.bak` antigo, `world.json` vira `.bak` e `.tmp` vira `world.json`. O fluxo não depende de rename sobrescrever destino, comportamento que varia entre sistemas. Se o principal faltar ou falhar, carrega o `.bak` e avisa. Um `.tmp` que sobrar é ignorado.

**Dado não confiável.** O modelo de ameaça é um save baixado da internet: ele não pode executar código, travar nem deixar estado inválido. Editar o próprio save para trapacear não é ameaça.

- Só JSON. Proibidos em dado externo: `load` de caminho vindo de `user://`, `bytes_to_var_with_objects`, `str_to_var`, `dict_to_inst`, `get_var(true)`.
- Limite de tamanho antes do parse (64 MiB [premissa]). Raiz precisa ser `Dictionary`.
- Todo `from_dict` lê por um helper `SafeRead` (`dict`, `number`, `string`, `boolean`) que confere tipo, rejeita não finito e limita o intervalo. Campo inválido cai no padrão; `from_dict` nunca aborta no meio.
- Máximos e capacidades vêm da definição ou da cena, não do save. Sai `max` de Health, Torpor, Stamina e Hunger. Se surgir progressão, grava-se o que a origina (nível), e o máximo é derivado.
- Item ou espécie desconhecidos são descartados com aviso em um relatório de carga; entidade sem definição válida é descartada inteira.
- `format_version` maior que o do jogo, ausente ou não inteiro: recusa explícita, sem tocar no arquivo.

**Ordem de restauração.** Sempre em instâncias novas, nunca sobre entidade viva, e de forma síncrona (nenhum tick no meio):

1. Ler com limite, parsear, validar envelope.
2. Migrar até a versão atual.
3. `world`: seed e `next_entity_id`; registry vazio.
4. Instanciar: para cada entidade e personagem, criar pelo `type`, adicionar à árvore (`from_dict` exige `_ready`) e registrar o ID. ID duplicado ou inválido descarta a entrada; `next_entity_id` sobe para acima do maior ID visto.
5. Restaurar: `from_dict` de cada entidade, na ordem interna atual: posição, health, inventory, torpor, taming, máquina de estados, `taming.reconcile()`. Torpor segue como fonte da verdade da consciência.
6. Resolver referências entre entidades e jogadores. Referência quebrada vira vazia, com aviso. Criatura com vida zero é removida: `from_dict` não emite `died`, e ela ficaria viva para sempre.
7. Só então ligar UI e controller e liberar a simulação.

O que não é salvo: estado de RNG, timers de `DinoIdleState` e `DinoWanderState`, e direção do passeio. Ao carregar, a criatura sorteia de novo. Não muda nenhum resultado de jogo, e por isso a regra de roundtrip vale para `to_dict`, não para o comportamento futuro.

## Consequências

- **Positivas**: save legível e depurável; corrupção e arquivo hostil têm comportamento definido; o layout já comporta co-op e chunks.
- **Negativas / trade-offs**: JSON cresce com o mundo; fixture por versão é mais uma manutenção; um item removido sem alias se perde no primeiro save seguinte.
- **Revisitar se**: `world.json` passar de cerca de 20 MB ou o autosave travar o laço do servidor [premissa]; no M4, a gravação de vários arquivos de chunk pedir consistência entre eles, o que este ADR não resolve.
