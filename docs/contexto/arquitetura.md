# Arquitetura

**Leia quando:** for criar ou alterar componente, entidade, cena, fluxo de ação do jogador, dado de jogo ou qualquer coisa que o servidor precisaria validar.

Fontes de verdade (não copie, leia): `game/README.md` (seção Arquitetura e Componentes), `docs/adr/ADR-001-autoridade.md`, `docs/adr/ADR-003-ids-e-registries.md`.

## Regras

- **Lógica separada da apresentação.** Componentes (`game/src/components/`) são `Node` (ou `RefCounted`) de lógica pura: não herdam `CanvasItem` e nunca leem `Input`. Só os corpos (jogador e dino) leem input. A UI só observa sinais. Motivo: tudo precisa rodar igual em servidor `--headless`.
- **Composição, não herança profunda.** Comportamento novo vira componente.
- **Estado em Dictionary/JSON.** Todo objeto salvável tem `to_dict()`/`from_dict()` com roundtrip testado (contrato em `save.md`).
- **Ações como intenção.** Mudança de estado do mundo passa por `request_*`. O servidor é autoritativo e o single-player roda como host local (ADR-001). `from_dict` nunca recebe dado de cliente.
- **Dados em `Resource`** (`ItemDef`, `SpeciesDef`, `RecipeDef` e os `.tres` de `game/data/`), com **id estável em string**. Nada de número mágico de balanceamento no código; números novos vão para um `Resource`.
- **Referência entre entidades ou em save usa id estável**, nunca ponteiro de nó. Input só no controlador do jogador e em `src/ui/`; a UI observa e não muda estado; sem RNG global (RNG local só com seed derivada); simulação só em `_physics_process` com `delta`, sem relógio de parede. Essas regras são verificadas por `tools/checks.d/10-arquitetura.sh`.

## Decisões registradas

Uma decisão que muda esses contratos pede um ADR novo em `docs/adr/` (contexto, decisão, consequências), aprovado pelo dono do projeto antes de virar código. Não altere um ADR aceito: escreva outro que o substitua.
