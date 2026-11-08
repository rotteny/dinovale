# ADR-003: IDs estáveis e registries de dados

**Data**: 2026-11-05
**Status**: Aceito (05/11/2026, aprovado pelo dono)
**Decisores**: dono do projeto; proposta de `KURAMA`

## Contexto

Hoje as entidades não têm identidade. `Dino` e `Player` são nós fixos em `Main.tscn`; referências são ponteiros de nó; `to_dict` não diz qual entidade nem qual espécie é. Carregar um save sobre essa cena duplicaria ou sobrescreveria a criatura errada. Sem ID, `request_*` (ADR-001) também não consegue apontar um alvo.

`Items.gd` já acerta no essencial: ids são strings estáveis e a fachada estática (`has`, `get_def`, `max_stack`) esconde o catálogo. Mas o catálogo é código, e `ItemDef` é `RefCounted` com argumentos obrigatórios no `_init`. Verificado na 4.7.2: `Resource` com `_init` assim falha ao carregar de `.tres`, com erro de construção da instância. `TamingComponent.ideal_food` e `Player.starting_items` apontam para constantes de item em código.

## Opções consideradas

**ID de entidade**

1. **Contador inteiro por mundo**: pequeno em RPC, legível em log, e só a autoridade cria entidades. Depende de persistir o contador.
2. **UUID em string**: dispensa contador, mas pesa em todo pacote e resolve um problema que não temos (geração distribuída). Godot não tem classe própria para isso.
3. **`NodePath` ou nome de nó**: muda com reparent e com chunks.

**Dados de conteúdo**

1. **`Resource` em `res://` com manifesto explícito**: tipado, editável no editor, funciona em export.
2. **`Resource` descoberto por varredura de pasta**: sem manifesto, mas o comportamento em build exportada precisaria de validação própria.
3. **JSON**: bom para mods, sem benefício hoje. O plano (7.5) reserva para mods de terceiros.

## Decisão

ID de entidade: opção 1. Dados de conteúdo: opção 1. Uma varredura em teste cobre a desvantagem do manifesto (arquivo esquecido).

### Quatro identidades, sem misturar

| Identidade | Tipo | Exemplo | Vida | Quem emite |
|---|---|---|---|---|
| Conteúdo | `String` | `berry` | para sempre | autor do dado |
| `entity_id` | `int` | `42` | a do mundo | autoridade |
| `player_id` | `String` | 32 hex aleatórios | a do personagem | autoridade, na criação |
| `peer_id` | `int` | `1` | a da conexão | engine; nunca salvo |

### Entidades

- `entity_id` começa em 1; 0 é "nenhum". Vem de `world.next_entity_id`, salvo no mundo, e **nunca é reutilizado**, nem após morte.
- `EntityRegistry` é um nó do mundo, não autoload nem `static`: `spawn`, `get_by_id`, `despawn`. Assim um teste monta vários mundos sem estado vazando. Toda entidade nasce e morre por ele; `health.died` deixa de ligar direto em `queue_free`.
- `EntityFactory` mapeia `type` para cena. Entidades com estado saem de `Main.tscn`: o mundo as cria no jogo novo ou a partir do save. Cena fixa fica só para terreno e limites.
- O nome do nó é `E<id>`, para que o caminho seja igual em todos os peers [premissa: confirmar no S0].
- Referência persistida ou enviada em rede é sempre ID. Ponteiro de nó fica só na memória local.
- Criatura domesticada guarda `owner_player_id` desde a v1: aponta para o personagem, que continua existindo com o dono offline.
- `player_id` local é gerado na criação do mundo. Identidade entre máquinas e autenticação ficam para o M3, com revisão de `NEZUKO`.

Em JSON, `entity_id` é número (seguro até 2^53) e volta como `float`, então é lido por `SafeRead`. Seed vai como string decimal, porque tem 64 bits (ADR-002).

**RNG.** A seed do mundo é sorteada na criação. O RNG de cada entidade usa `hash([seed, entity_id])`; o de chunk, `hash([seed, x, y])`.

### Registries

```text
game/data/items/berry.tres      ItemDef (Resource)
game/data/items/catalog.tres    ItemCatalog: items + aliases
game/data/species/...           SpeciesDef, mesmo padrão (CRI-03)
game/data/recipes/...           RecipeDef, mesmo padrão
```

- `ItemDef` vira `Resource` com `@export` e `_init` sem argumentos obrigatórios. `max_stack` mínimo 1 passa a ser validado em teste.
- `Items` continua sendo a fachada estática, agora lendo `catalog.tres` de forma preguiçosa. Quem a usa não muda. `Species` e `Recipes` seguem o padrão. Estático é aceitável aqui porque o dado é imutável, ao contrário do `EntityRegistry`.
- Definições são somente leitura em execução: o cache de recursos as compartilha. Estado por entidade fica em componente.
- Gramática de id: `^[a-z][a-z0-9_]*$`. O prefixo `mod:` fica reservado.
- **Id publicado nunca muda nem some.** Renomear ou remover exige entrada em `aliases` (antigo para atual), resolvida na leitura de save. Alias é permanente, sem ciclo, e aponta para id vivo. A lista `tests/fixtures/ids/*.txt` só cresce e guarda todo id já publicado.
- Save e rede carregam id, nunca o `Resource`. `.tres` só de `res://`.
- Gameplay não cita item por constante: `ideal_food` vai para `SpeciesDef` e `starting_items` para um dado de personagem inicial. `Items.BERRY` e semelhantes saem de `src/` em CRI-03; testes usam o id literal.
- No M3, o handshake compara um hash do conteúdo, além da versão de protocolo.

## Consequências

- **Positivas**: `request_*`, save e réplica usam o mesmo endereço; conteúdo novo é só dado; renomear não corrompe mundo.
- **Negativas / trade-offs**: manifesto para manter; `spawn` obrigatório torna a criação de entidade um pouco mais verbosa, inclusive nos testes; `Main.tscn` deixa de mostrar criaturas no editor.
- **Revisitar se**: mods entrarem no escopo (registries precisam aceitar JSON validado); entidades precisarem nascer fora da autoridade, como efeitos preditos no cliente, que por isso não recebem `entity_id`; ou a string de id pesar em rede medida no M3 (tabela de ids curtos na sessão).
