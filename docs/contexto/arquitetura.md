# Arquitetura

**Leia quando:** for criar ou alterar componente, entidade, cena, fluxo de ação do jogador, dado de jogo ou qualquer coisa que o servidor precisaria validar.

Fontes de verdade (não copie, leia): `game/README.md` (seção Arquitetura e Componentes), `docs/adr/ADR-001-autoridade.md`, `docs/adr/ADR-003-ids-e-registries.md`, `docs/adr/ADR-004-server-rules.md`.

## Regras

- **Lógica separada da apresentação.** Componentes (`game/src/components/`) são `Node` (ou `RefCounted`) de lógica pura: não herdam `CanvasItem` e nunca leem `Input`. Só os corpos (jogador e dino) leem input. A UI só observa sinais. Motivo: tudo precisa rodar igual em servidor `--headless`.
- **Composição, não herança profunda.** Comportamento novo vira componente.
- **Estado em Dictionary/JSON.** Todo objeto salvável tem `to_dict()`/`from_dict()` com roundtrip testado (contrato em `save.md`).
- **Ações como intenção.** Mudança de estado do mundo passa por `request_*`. O servidor é autoritativo e o single-player roda como host local (ADR-001). `from_dict` nunca recebe dado de cliente. A passagem é `WorldAuthority` (`game/src/world/`): ids de entidade, validação na ordem do ADR-001, negado = nada muda. As ações do jogador sobre criaturas, itens e recursos (`request_attack`, `request_interact`, `request_transfer_slot`, `request_command`, `request_use_item`, `request_equip`, `request_unequip`, `request_gather`) passam por ela com `actor_id`; o `Player` só pede e a regra roda em `Player.perform_*`/`strike`. Teste novo de ação do jogador entra na tabela de negação de `game/tests/authority_tests.gd` e em `net_flow_tests.gd`. O dono do domado é o `player_id` do personagem (`Dino.owner_player_id`, ADR-003), não o id de entidade.
- **Dados em `Resource`** (`ItemDef`, `SpeciesDef`, `RecipeDef` e os `.tres` de `game/data/`), com **id estável em string**. Nada de número mágico de balanceamento no código; números novos vão para um `Resource`.
- **Referência entre entidades ou em save usa id estável**, nunca ponteiro de nó. Input só no controlador do jogador e em `src/ui/`; a UI observa e não muda estado; sem RNG global (RNG local só com seed derivada); simulação só em `_physics_process` com `delta`, sem relógio de parede. Essas regras são verificadas por `tools/checks.d/10-arquitetura.sh`.

## Peças do código que você vai encontrar

- **`ServerRules`** (`game/src/core/ServerRules.gd`, defaults em `ServerRulesDefaults.gd`; ADR-004): regras do mundo que o operador muda, lidas de `server_rules.json` **uma vez** e imutáveis na sessão. Só o host (`Main`, `game/src/world/Main.gd`) chama `ServerRules.load_file`; o consumidor recebe o valor pronto. Chave nova só entra no commit em que ganha consumidor. Valor inválido volta ao padrão da `.tres`. **Regra de arquitetura nova** em `tools/checks.d/10-arquitetura.sh` (`rule_server_rules_only_host_loads_and_nobody_writes`): fora de `world/Main.gd` ninguém chama `load_file`, e ninguém escreve num campo de `server_rules.*`.
- **Dados de balanceamento** (`Resource` em `game/data/balance/`): `CarcassRules` (carcaça fresca por 10 min, GDD 5.6) e `DinoLevelRules` (atributos por nível, alcance do rótulo de nível).
- **Mundo:** `TileOccupancy` (`game/src/world/`) é o ponto único de "tem alguém neste retângulo?" (jogador e dinos hoje; o `BuildGrid` entrará aqui); `CarcassField` guarda as carcaças (entram no registro da autoridade, coleta por `request_gather`).
- **Apresentação:** `WildLevelTag` ("Nv N" do dino selvagem, só acordado, vivo e perto) e `PixelCursor` (cursor do mouse ampliado por inteiro) ficam em `game/src/ui/`.
- **IA do dino:** `DinoChaseState` (`game/src/entities/dino/states/`) é a perseguição do agressivo; ainda sem navegação (a etapa E2 a traz): obstáculo no caminho trava o corpo.

## Decisões registradas

Uma decisão que muda esses contratos pede um ADR novo em `docs/adr/` (contexto, decisão, consequências), aprovado pelo dono do projeto antes de virar código. Não altere um ADR aceito: escreva outro que o substitua. Numeração: ADR-001 a ADR-004 existem; o próximo livre é o **ADR-005** (reservado à Conduta e domesticação, ARQ-04, ainda não escrito).
