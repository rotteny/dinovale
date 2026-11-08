# ADR-001: Servidor autoritativo e regras "pronto para rede"

**Data**: 2026-11-05
**Status**: Aceito (05/11/2026, aprovado pelo dono)
**Decisores**: dono do projeto (decisão D8); proposta de `KURAMA`

## Contexto

O multiplayer só entra no M3, mas o que encarece o retrofit é a lógica que muda estado a partir de input local, sem ID estável e sem ação validável (PLANEJAMENTO, R1). O código atual tem uma boa base (componentes sem apresentação, `apply_input` recebe a direção pronta), e quatro pontos que não sobrevivem à rede:

- `Player` lê `Input` no mesmo script que simula. Um servidor dedicado também tem esse corpo, então "`Input` só em corpos" não basta.
- `Player.attack()` aplica torpor direto no alvo, e o alcance é só a forma do detector.
- `InventoryScreen` chama `transfer_slot` direto: a UI muda estado.
- `TamingComponent`, `TorporComponent`, `HungerComponent` e `DinoStateMachine` simulam em qualquer máquina que os instancie.

Verificado na 4.7.2 (confirma a premissa do plano): o peer padrão é `OfflineMultiplayerPeer`, com `is_server() == true`. Nele, `rpc_id(1, ...)` de um método `any_peer, call_local` roda na hora, com `get_remote_sender_id() == 1`; em chamada direta o valor é 0. O modo offline não serializa argumentos, então não acusa argumento inválido para a rede.

## Opções consideradas

1. **Servidor autoritativo, single-player como host local (D8)**: um só caminho de código, e o cliente nunca é fonte de verdade. Custa uma camada de ações desde o M1.
2. **Single-player direto, rede depois**: mais rápido agora, mas reescreve `Player`, `Dino` e UI no M3, com conteúdo já construído em cima.
3. **Lockstep determinístico**: pouca banda, mas exige simulação bit a bit idêntica, que a física em float não garante.
4. **Cliente autoritativo**: o mais simples, e incompatível com servidor público (R6).

## Decisão

Opção 1. Concordo com a D8.

```text
teclado / UI -> PlayerController -> WorldAuthority.request_*() -> valida -> componentes
                                                                              |
UI <------------------------------- sinais <----------------------------------+
```

`WorldAuthority` é um único nó do mundo, ponto de passagem de toda ação do jogador. Um nó só dá um caminho estável para RPC e um lugar só para mapear peer e limitar taxa. Ele valida e delega: as regras continuam nas entidades e nos componentes (`can_interact`, `apply_torpor`, `transfer_slot`). Se passar de cerca de 10 ações, divide-se por tema, mantendo o nó de entrada.

Contrato de `request_*`:

- Assinatura `request_x(actor_id: int, ...)`, só com `int`, `float`, `bool`, `String` e `Vector2`. Nunca `Node`, `Object`, `NodePath` nem `Dictionary`.
- Ordem de validação: ator existe e está vivo; argumentos finitos e no intervalo; alvo existe (por ID); alcance por distância real; regra de domínio (recarga, posse, `can_interact`).
- Negada, não muda nada: devolve `Enums.ActionResult` e emite `action_denied`. O retorno serve a teste e log; a UI nunca atualiza estado por ele, porque em rede ele não existirá.
- `actor_id` nunca vem do payload do cliente. No M1 quem o fornece é o `PlayerController`; no M3, um RPC fino resolve `get_remote_sender_id()` para o ator na sessão. Por isso o gameplay não usa `@rpc` até o S0, onde ele entra sem mudar as regras de validação.

Ações iniciais: `request_move`, `request_attack`, `request_interact`, `request_transfer_slot`. As demais (comer, coletar, ordenar) nascem no mesmo formato.

### Regras obrigatórias a partir de agora

| Regra | Enunciado | Verificação |
|---|---|---|
| **R-A** | Mudança de estado causada por jogador só passa por `request_*`. Cliente manda intenção, nunca fato (posição, dano, item). | Tipos da assinatura por reflexão; tabela de negação com estado idêntico antes e depois |
| **R-B** | Toda referência entre máquinas ou em save usa ID estável (ADR-003). | Varredura de `get_instance_id` e `NodePath` em dados |
| **R-C** | Sem `randf`, `randi` ou `randomize` globais. Cada RNG deriva da seed do mundo. | Varredura |
| **R-D** | Simulação só em `_physics_process`, só com `delta` e só na autoridade. `_process` fica para apresentação. | Varredura; teste: simulação desligada, `to_dict` não muda após N frames |
| **R-E** | `Input` só em `PlayerController` e `src/ui/`. | Varredura |
| **R-F** | UI só observa sinais e lê valores. Fora de `src/ui/` e `src/world/`, ninguém referencia classe de UI. | Varredura de mutadores e de dependências; mundo roda sem UI |

R-C serve à reprodutibilidade de testes e de mundo, não a lockstep. Por isso o estado do RNG não vai para o save (ADR-002).

`InteractableArea` herda `CanvasItem` por ser `Area2D`. É exceção aceita à regra do README: é sensor físico, sem regra de jogo, e não desenha.

`from_dict` nunca recebe dado de cliente. O fluxo cliente para servidor é só `request_*`; o comentário "save e RPC" em `from_dict` deve sair.

### Mudanças no código atual (NET-01)

- **Player**: extrair `read_direction`, `_unhandled_input` e a leitura de `sprint` para um `PlayerController` local. `_physics_process` passa a consumir a última intenção recebida (`request_move`). Direção com NaN ou INF é negada.
- **Player**: `attack()` e `try_interact()` viram chamadas a `request_*` com `target_id`. `target` passa a ser sugestão de mira do cliente, e a autoridade mede o alcance por distância, com folga para os raios das áreas (o detector tem 22), senão o prompt aparece e a ação é negada. A recarga fica no `Player`, consultada pela autoridade; `attack_torpor` nunca vem do cliente.
- **Player**: `input_locked` vai para o controller, porque tela aberta é estado do cliente e não regra. `starting_items` sai do `_ready` e vai para a criação de personagem.
- **Interação**: `request_interact` responde com `interaction_granted(actor_id, target_id)`, que substitui `Player.interacted`, e a `Main` abre a tela por ele. A autoridade chama `entity.can_interact()` direto; `InteractableArea` e `availability` ficam só para prompt e mira.
- **Inventory**: `InventoryComponent` não muda; `transfer_slot` vira operação interna. `InventoryScreen` chama `request_transfer_slot(actor_id, from_id, index, to_id)`, com alcance e `can_interact` revalidados a cada transferência. Sem "sessão de baú" no servidor: nada de estado extra, e dois jogadores no mesmo baú são resolvidos pela ordem de chegada.
- **Taming**: o consumo continua sendo simulação, sem `request_*`; o depósito entra por `request_transfer_slot`, que registra quem alimentou. `mark_tamed` recebe o dono, gravado em `owner_player_id` (ADR-003). Quem ganha a criatura em caso de disputa é decisão de design do M3; no M1, é o último a depositar a comida ideal.
- **Simulação**: `WorldAuthority.set_simulation_enabled(bool)` liga ou desliga o `_physics_process` do grupo `simulation`, em um só ponto. Entra no S0.
- **DinoStateMachine**: `rng` recebe seed derivada (ADR-003); hoje cada instância sorteia a sua.

## Consequências

- **Positivas**: o S0 vira troca de transporte, não reescrita; ações ficam testáveis sem teclado; a mesma tabela de negação protege o servidor público.
- **Negativas / trade-offs**: mais uma camada e um ID em toda ação; cliente remoto sente a latência no movimento até haver predição, decisão que fica para o M3.
- **Revisitar se**: o S0 estourar 15 sessões ou exigir reescrever mais de 30% de `Player`, `Dino` e componentes (limiares do plano); ou o dono desistir de servidor dedicado.
