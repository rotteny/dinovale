# ADR-005: Conduta do dino, camada de intenção e ordem `WORK`

**Data**: 2026-11-07
**Status**: Proposto
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 8 do M0, roadmap consolidado de 07/11). Número reservado desde o plano para a Conduta e domesticação (ARQ-04, `documentacao/PLANEJAMENTO.md:252`); este rascunho cobre a parte que o M3 precisa e deixa a domesticação para uma revisão antes do aceite.

## Contexto

O dino decide o que fazer numa máquina de estados fixa: `IDLE`, `WANDER`, `UNCONSCIOUS`, `TAMED`, `CHASE` (`Enums.gd:7`, estados em `game/src/entities/dino/states/`). A "Conduta" hoje é um `bool` (`DinoBaseStats.aggressive`, `DinoBaseStats.gd:30`); o domado só conhece `STAY` e `FOLLOW` (`Enums.gd:10`), trocados por `WorldAuthority.request_command` e aplicados em `DinoStateMachine.set_order` (`DinoStateMachine.gd:132`). Colher é ação só do jogador: `WorldAuthority.request_gather` exige um jogador vivo como ator e a regra roda em `Player.perform_gather`.

O M3 traz o Neutro (revida e protege) e a ordem Trabalhar (dino colhe sozinho em nós reais, perto ou longe do dono). Sem uma camada entre "o que o dino quer" e "o que o corpo faz", cada comportamento novo vira um estado novo com regra própria de colheita, e o Trabalhar duplicaria a regra do jogador.

Decisões já tomadas que este ADR precisa respeitar (roadmap de 07/11): só nós reais; invariante de conservação e laço de eventos (ADR-006, seção "Trabalho do dino"); alforje de 4 slots, sem Peso do dino na v0.2; ponto recusado perto de toca de agressivo (raio em dado, 20 tiles); só o dono ordena; até 3 dinos trabalhando por jogador.

## Opções consideradas

1. **Estado novo por comportamento** (`WorkState`, `NeutralState`) na máquina atual: menor mudança. Contra: a regra de colher fica dentro do estado do dino, separada da do jogador; o trabalho longe (sem física) não roda num estado de nó processado.
2. **Árvore de comportamento genérica**: flexível. Contra: arquitetura prematura para 3 condutas e 3 ordens; difícil de salvar e replicar.
3. **Conduta em dados + intenção + ações compartilhadas**: a Conduta (`Resource`: Passivo, Neutro, Agressivo, com raios e reações) escolhe uma intenção; a ordem do dono (`STAY`, `FOLLOW`, `WORK`) tem prioridade sobre ela; a intenção vira ação (`Move`, `Attack`, `Gather`) que chama a mesma regra que o jogador usa. Contra: refatora o `bool aggressive` e o `DinoStateMachine` em duas camadas.

## Decisão (proposta)

Opção 3.

- **Conduta** em `Resource` por espécie (substitui `aggressive`); o estado salvo continua sendo o id do estado e o alvo, nunca valores internos da percepção.
- **Ordem `WORK`** entra em `Enums.DinoOrder`. O estado da ordem pertence ao Dino, num componente **`WorkOrder`** salvo em `entities[].state.work`: `anchor` (célula global), `started_at`, `next_at` (`due_at` da próxima colheita, ADR-006), `node_id` (id estável do ADR-007, ou vazio) e `status` (`ok`, `full`, `no_node`, `blocked`). Campo opcional: entra no v5 sem subir a versão; sem `work` = sem ordem. A regra (raio de 12 tiles, período, recurso) fica num `WorkProfile` por espécie, fora do save.
- **Intenções novas**, validadas na `WorldAuthority` na ordem do ADR-001:
  - `request_work(actor_id, dino_id, cell)`: ator é o dono (`owner_player_id`), dino domado, `vinculado`, acordado, não ferido, não montado; `cell` dentro do mapa e ao alcance do ator; espécie tem `WorkProfile`; ponto fora do raio de toca de agressivo (dado); menos de `dino_trabalhando_max` ordens `WORK` ativas do mesmo `player_id`, contadas varrendo os domados (sem contador salvo).
  - `request_stop_work(actor_id, dino_id)`: só o dono; apaga o `work` e deixa o dino em `STAY`. Qualquer `request_command` (`STAY`, `FOLLOW`) e montar também apagam o `work`.
- **Ação `Gather` compartilhada**: a colheita (do jogador e do `WorkSim`) passa a uma regra única na autoridade, extraída de `Player.perform_gather`. O dino perto anda até o nó por apresentação; quem move itens é o evento do `WorkSim` (ADR-006). Alforje cheio: para no lugar com "carga cheia", nada se perde; o dono coleta pelo `request_transfer_slot` que já existe.
- **Fora deste rascunho**: domesticação e o que replica da doma (ARQ-04); entram numa revisão deste ADR antes do aceite.

## Consequências

- **Positivas**: um caminho só para colher (sem regra duplicada); Neutro e Agressivo viram dado; o Trabalhar perto e longe usa o mesmo código e o invariante de conservação vale por construção.
- **Negativas / trade-offs**: refatora `DinoStateMachine` e `Player.perform_gather`; `WORK` e as validações aumentam a tabela de negação de `authority_tests.gd`.
- **Revisitar se**: aparecer conduta que não cabe em "intenção + ordem" (bando, fuga coordenada); o dono quiser que aliado também ordene trabalho.
