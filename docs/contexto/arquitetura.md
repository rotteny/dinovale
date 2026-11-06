# Arquitetura

**Leia quando:** for criar ou alterar componente, entidade, cena, fluxo de ação do jogador, dado de jogo ou qualquer coisa que o servidor precisaria validar.

Fontes de verdade (não copie, leia): `game/README.md` (seção Arquitetura e Componentes), `docs/adr/ADR-001-autoridade.md`, `docs/adr/ADR-003-ids-e-registries.md`.

## Regras

- **Lógica separada da apresentação.** Componentes (`game/src/components/`) são `Node` (ou `RefCounted`) de lógica pura: não herdam `CanvasItem` e nunca leem `Input`. Só os corpos (jogador e dino) leem input. A UI só observa sinais. Motivo: tudo precisa rodar igual em servidor `--headless`.
- **Composição, não herança profunda.** Comportamento novo vira componente.
- **Estado em Dictionary/JSON.** Todo objeto salvável tem `to_dict()`/`from_dict()` com roundtrip testado (contrato em `save.md`).
- **Ações como intenção.** Mudança de estado do mundo passa por `request_*`. O servidor é autoritativo e o single-player roda como host local (ADR-001). `from_dict` nunca recebe dado de cliente. A passagem é `WorldAuthority` (`game/src/world/`): ids de entidade, validação na ordem do ADR-001, negado = nada muda. As ações do jogador sobre criaturas, itens e recursos (`request_attack`, `request_interact`, `request_transfer_slot`, `request_command`, `request_use_item`, `request_equip`, `request_unequip`, `request_gather`) passam por ela com `actor_id`; o `Player` só pede e a regra roda em `Player.perform_*`/`strike`. Teste novo de ação do jogador entra na tabela de negação de `game/tests/authority_tests.gd` e em `net_flow_tests.gd`. O dono do domado é o `player_id` do personagem (`Dino.owner_player_id`, ADR-003), não o id de entidade.
- **Dados em `Resource`** (`ItemDef`, `SpeciesDef`, `RecipeDef` e os `.tres` de `game/data/`), com **id estável em string**. Nada de número mágico de balanceamento no código; números novos vão para um `Resource`.
- **Referência entre entidades ou em save usa id estável**, nunca ponteiro de nó. Input só no controlador do jogador e em `src/ui/`; a UI observa e não muda estado; sem RNG global (RNG local só com seed derivada); simulação só em `_physics_process` com `delta`, sem relógio de parede. Essas regras são verificadas por `tools/checks.d/10-arquitetura.sh`.

## Decisões registradas

Uma decisão que muda esses contratos pede um ADR novo em `docs/adr/` (contexto, decisão, consequências), aprovado pelo dono do projeto antes de virar código. Não altere um ADR aceito: escreva outro que o substitua.
