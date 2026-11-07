# ADR-008: Corpo controlado, `request_move` e montaria

**Data**: 2026-11-07
**Status**: Proposto
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 8 do M0, roadmap consolidado de 07/11)

## Contexto

No commit `90284ff` o movimento do jogador não é intenção: `Player._physics_process` lê o teclado (`Input.get_vector`, em `read_direction`) e aplica a velocidade no próprio corpo. É a única exceção à regra de arquitetura "Input só em PlayerController e `src/ui`" (`tools/checks.d/10-arquitetura.sh`, regra R-E) e contradiz o ADR-001: no co-op (M8) o servidor precisa receber a direção, não a posição. A tarefa do M0 que cria o `PlayerController` e o `request_move` (KUR-01) está em andamento; este ADR fixa o contrato que ela e a montaria seguem.

O M2 traz a montaria: o dono e os aliados (lista `aliados` por dino, decisão de 07/11) montam o domado `vinculado`; montado, o jogador dirige o dino, com Galope e Stamina (premissas em dado: 100, cerca de 5 s de Galope, 3 s parado ao zerar). Sem um conceito de "corpo controlado", montar viraria um segundo caminho de input só para o dino.

## Opções consideradas

1. **Input do dino montado lido no próprio `Dino`**: rápido. Contra: espalha a exceção de `Input` para outra entidade; duplica o caminho de movimento; quebra no co-op.
2. **Jogador montado vira parte do dino** (o `Player` sai de `entities` e volta ao desmontar): uma entidade a menos para mover. Contra: inventário, vida e `player_id` precisam de um lugar enquanto montado; save e rede ganham um caso especial; morte do dino com o jogador "dentro" fica ambígua.
3. **Corpo controlado + `request_move`**: cada jogador controla um corpo (o próprio ou o do dino em que está montado); o cliente só envia `request_move(actor_id, direction, wants_sprint)`, e a autoridade aplica no corpo controlado. O jogador montado continua entidade em `entities`, com `mounted_on` e posição presa ao assento. Contra: refatora o movimento do `Player` e acrescenta uma intenção chamada todo tick.

## Decisão (proposta)

Opção 3.

- **`request_move(actor_id, direction: Vector2, wants_sprint: bool)`**: direção limitada a comprimento 1 (como `Player.apply_input` já faz); a autoridade resolve o corpo controlado e aplica a regra de velocidade dele (jogador ou espécie). O `PlayerController` (apresentação) lê o `Input` e só chama a intenção. A exceção de `Input` para `Player.gd` sai do teste de arquitetura.
- **Montaria**: `request_mount(actor_id, dino_id)` e `request_dismount(actor_id)`. Montar exige: ator é o dono ou está em `aliados` do dino; dino `vinculado`, acordado, sem ordem `WORK` (montar a cancela, ADR-005), sem cavaleiro; alcance a partir do ator. Desmontar põe o jogador na célula livre mais próxima (`TileOccupancy`).
- **Jogador montado como entidade**: o `Player` fica em `entities` com `mounted_on` (id do dino); sem colisão própria, posição = assento do dino; mantém vida, inventário e alcance (o alcance conta a partir do assento). Dino nocauteado ou morto desmonta o cavaleiro antes de qualquer outro efeito.
- **Stamina e Galope** do dino em dado por espécie; a recuperação guarda valor atual e instante absoluto (`regen_after`), nunca contador `-= delta` (ADR-006).
- **Save**: `mounted_on` e `aliados` (lista de `player_id`) são campos opcionais, aditivos ao v5; carga com `mounted_on` inválido desmonta.

## Consequências

- **Positivas**: fim da exceção de `Input`; o mesmo caminho serve ao single-player, ao co-op e à montaria; a validação de quem monta fica num lugar só.
- **Negativas / trade-offs**: uma intenção por tick por jogador (barata, mas entra na tabela de negação e no limite de taxa do M8); o movimento do `Player` muda de lugar, com risco de regressão de sensação (rodar o jogo, não só o teste).
- **Revisitar se**: o M8 precisar de predição no cliente (o cliente passa a simular o próprio corpo e a autoridade corrige); aparecer montaria com mais de um assento.
