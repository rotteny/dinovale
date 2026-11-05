# Dino Vale

Sandbox survival 2D top-down em pixel art, com exploração, construção e domesticação de dinossauros. É um jogo comunitário, gratuito e auto-hospedado, feito em Godot 4 com GDScript.

> **Estado:** fundação técnica, com o ciclo de domesticação jogável. A cena principal mostra um jogador placeholder (azul) e um dinossauro placeholder (laranja) passeando em uma área fechada. A HUD mostra vida, stamina e fome do jogador. Perto do dino aparece o painel dele (estado, torpor e progresso de domesticação). Dá para derrubar o dino com golpes de torpor (F ou Espaço), abrir o inventário compartilhado com E enquanto ele está inconsciente, passar comida para ele por clique e ver a domesticação chegar a 100%. Ainda não há construção, save em arquivo, arte nem som definitivos.

## Controles

| Ação | Tecla |
|---|---|
| Andar | WASD ou setas |
| Correr | Shift |
| Interagir (abrir a criatura inconsciente) | E |
| Golpe de torpor na criatura ao alcance | F ou Espaço |
| Inventário próprio | I ou Tab |
| Na tela de inventário | clique, ou setas + Enter/Espaço, transfere o slot inteiro; Esc, I ou E fecham |

Com a tela aberta o jogador não anda. O jogador começa com 10 bagas (a comida ideal do dino), 4 carnes e 3 samambaias. Só a baga avança a domesticação; as outras ficam no inventário.

## Como rodar

**Requisito:** [Godot 4.7](https://godotengine.org/download) ou mais novo. O projeto foi validado na 4.7.2. Os testes usam a classe `Logger`, que não existe em versões antigas da engine.

Na pasta `game/`, importe o projeto uma vez. Isso gera o cache de classes em `.godot/`, sem o qual os scripts não encontram os `class_name`:

```bash
godot --headless --path . --import
```

| Ação | Comando |
|---|---|
| Abrir no editor | `godot --path . --editor` |
| Rodar o jogo | `godot --path .` |
| Rodar sem janela | `godot --headless --path .` |
| Rodar os testes | `godot --headless --path . --script res://tests/run_tests.gd` |

Os testes saem com código 0 quando passam. Saem com código 1 se uma verificação falhar ou se ocorrer qualquer erro de script.

## Arquitetura

Três regras guiam o código:

1. **Lógica separada da apresentação.** Regras de jogo estendem `Node` ou `RefCounted`, nunca `CanvasItem`. Elas publicam sinais e valores, e o corpo e a interface reagem. Assim tudo roda igual em um servidor `--headless`.
2. **Composição.** Entidades são montadas com componentes reutilizáveis, sem herança profunda.
3. **Persistência limpa.** Tudo que precisa ser salvo expõe `to_dict()` e `from_dict()` com dados compatíveis com JSON.

### Estrutura

```text
game/
├── project.godot
├── assets/                  # sprites, sons e fontes
├── src/
│   ├── core/                # enums, catálogo de itens
│   │   ├── Enums.gd
│   │   ├── ItemDef.gd       # definição de um item (id, nome, pilha, cor)
│   │   └── Items.gd         # catálogo: berry, meat, fern
│   ├── components/          # componentes reutilizáveis
│   │   ├── HealthComponent.gd
│   │   ├── HungerComponent.gd
│   │   ├── InteractableArea.gd
│   │   ├── InventoryComponent.gd
│   │   ├── StaminaComponent.gd
│   │   ├── TamingComponent.gd
│   │   └── TorporComponent.gd
│   ├── entities/
│   │   ├── dino/
│   │   │   ├── Dino.gd              # corpo: aplica a direção à física
│   │   │   ├── Dino.tscn
│   │   │   ├── DinoStateMachine.gd  # cérebro: sem física nem sprite
│   │   │   └── states/              # Idle, Wander, Unconscious, Tamed
│   │   ├── npcs/
│   │   └── player/
│   │       ├── Player.gd            # corpo: lê o input e aplica a física
│   │       └── Player.tscn
│   ├── ui/                  # só apresentação, reage a sinais
│   │   ├── PlayerHud.gd     # barras, painel da criatura e prompt
│   │   ├── DinoPanel.gd
│   │   ├── StatBar.gd
│   │   ├── InventoryScreen.gd
│   │   └── UiTheme.gd
│   └── world/               # grid, chunks e estruturas
│       ├── Main.gd          # liga o mundo à UI
│       └── Main.tscn
└── tests/
    └── run_tests.gd
```

### Componentes

**`HealthComponent`** guarda a vida da entidade. Sinais: `health_changed`, `damaged`, `healed` e `died`.

**`TorporComponent`** é uma barra independente da vida. Quando `current_torpor >= max_torpor`, emite `knocked_out`. A criatura só acorda quando o torpor cai até `wake_ratio * max_torpor`, e então emite `woke_up`. A queda por segundo é configurável separadamente para consciente e inconsciente, e essa segunda taxa define quanto tempo o jogador tem para domesticar.

**`StaminaComponent`** é o fôlego. Gasta enquanto o corpo diz que está correndo e regenera parado. Ao zerar, entra em exaustão e só volta a correr ao recuperar `resume_threshold`. Sinais: `stamina_changed`, `exhausted` e `recovered`.

**`HungerComponent`** guarda a saciedade (cheia = 100), que cai com o tempo. Em zero emite `starved(damage)` a cada `starvation_interval`; o `Player` liga esse sinal ao `HealthComponent.take_damage`. `eat(amount)` interrompe o dano.

**`InventoryComponent`** guarda slots com pilhas (`{id, count}`). `capacity` e `max_stack` são exportados; vale o menor entre o teto do inventário e o do item (`Items`). `add(id, n)` devolve quanto NÃO coube, `remove(id, n)` devolve quanto saiu e `count(id)` soma as pilhas. `transfer(destino, id, n)` e `transfer_slot(i, destino)` só movem o que o destino comporta, então item nunca some nem duplica. Ids desconhecidos são rejeitados. Sinal: `changed`.

**`InteractableArea`** (`Area2D`) marca uma entidade como interagível. A regra de quando se pode interagir fica na entidade, que injeta `availability`. Quem muda o estado chama `refresh()`, e `availability_changed` avisa a UI. O `Dino` só pode ser aberto se estiver inconsciente e selvagem.

**`TamingComponent`** consome a comida ideal do `inventory` compartilhado do Dino a cada `seconds_per_meal` enquanto a criatura selvagem está inconsciente e preenche `taming_progress`. Em 100% chama `DinoStateMachine.mark_tamed()`. Sem comida ideal o progresso para e não regride. Se a criatura acordar antes de terminar, o progresso zera, mas a comida que sobrou continua no inventário. Não mantém estoque próprio.

### Jogador

`Player` é um `CharacterBody2D` top-down (`motion_mode` floating). Só o corpo lê `Input` (`read_direction`); a regra de movimento (`apply_input(direction, wants_sprint, delta)`) recebe a direção pronta, então é testável sem input real. Ações: `move_up/down/left/right` (WASD e setas), `sprint` (Shift), `interact` (E), `attack` (F, Espaço) e `inventory` (I, Tab). A diagonal tem o mesmo comprimento que o eixo. Só corre quem está se movendo e tem stamina.

Um detector (`Area2D`) enxerga as `InteractableArea` no alcance, e o `target` é a mais próxima (sinal `target_changed`). `try_interact()` emite `interacted(target)` se a entidade permitir; `attack()` aplica `attack_torpor` (exportado) à criatura selvagem alvo, com recarga. Ambos são chamáveis sem teclado. `input_locked` congela o jogador enquanto a tela de inventário está aberta.

### UI

Tudo em `src/ui/` é só apresentação, reage a sinais e pode ser removido sem efeito nas regras. `PlayerHud` mostra as barras, o `DinoPanel` (estado, torpor, progresso) e o prompt "E para interagir". `InventoryScreen` mostra o inventário do jogador e o da criatura; ela fecha sozinha se o dino acordar, for domesticado ou sair da cena. A `Main` liga `Player.interacted` à tela e a tela ao `input_locked` do jogador. A fonte é a padrão da engine em tamanho 10, pensada para 640x360.

### Máquina de estados da criatura

```text
        tempo
 IDLE <-------> WANDER
   ^                |
   |   knocked_out  |  (de qualquer estado)
   |                v
   +----------- UNCONSCIOUS <-------+
    acordou         |               | knocked_out
    selvagem        | mark_tamed()  |
                    v               |
                  TAMED ------------+
```

- Um domesticado que desmaia acorda como `TAMED`, nunca como `IDLE`.
- `mark_tamed()` só funciona em criatura selvagem desmaiada. Ela zera o torpor e acorda a criatura.
- A máquina expõe `desired_direction` para o corpo e `state_changed` para a apresentação.
- Fixe `rng.seed` para obter um comportamento reproduzível.

### Saves

Exemplo do que `Dino.to_dict()` produz:

```json
{
  "position": { "x": 48.0, "y": 96.0 },
  "health": { "current": 75.0, "max": 100.0 },
  "torpor": { "current": 100.0, "max": 100.0, "is_unconscious": true },
  "inventory": { "slots": [ { "id": "berry", "count": 4 }, {}, {}, {}, {}, {}, {}, {} ] },
  "taming": { "progress": 20.0, "meal_timer": 2.0 },
  "state_machine": { "state": "UNCONSCIOUS", "is_tamed": false }
}
```

`Player.to_dict()` salva `position`, `health`, `stamina`, `hunger` e `inventory` no mesmo formato. Slot vazio é `{}`. No `from_dict` do inventário, ids desconhecidos, contagens inválidas e slots além da capacidade são descartados, e a contagem é limitada à pilha. Saves antigos com `taming.food_stock` são ignorados (o jogo não foi publicado).

- Enums são salvos pelo nome, então reordená-los não corrompe mundos antigos.
- `from_dict()` não dispara eventos de jogo como `died` ou `knocked_out`.
- Restaure o `TorporComponent` e o `TamingComponent` antes da máquina. O torpor é a fonte da verdade sobre a consciência, e um save inconsistente é corrigido a partir dele (`taming.reconcile()` zera progresso de criatura acordada).

## Roadmap técnico

### Fase 1: fundação single-player

- [x] Estrutura do projeto e configuração para pixel art
- [x] `HealthComponent` e `TorporComponent`
- [x] Máquina de estados da criatura
- [x] Testes headless
- [x] Jogador: movimento top-down e atributos `Health`, `Stamina` e `Hunger`
- [x] `InventoryComponent` e `InteractableArea`
- [x] `TamingComponent`: consumo periódico da comida ideal preenche `TamingProgress` e chama `mark_tamed()`
- [x] Inventário compartilhado com a criatura inconsciente
- [ ] Grid de construção: fundação, parede e baú
- [x] HUD e tela de inventário (placeholder; layout só conferido em captura, sem arte final)
- [ ] Comer do inventário para recuperar fome (hoje a fome só cai)
- [ ] Save e load do mundo em arquivo

### Fase 2: mundo

- [ ] Chunking e geração de mapa
- [ ] Ordens para domesticados: seguir e ficar
- [ ] Morte, respawn e estado `Dead` da criatura
- [ ] Arte, som e fontes definitivos

### Fase 3: multiplayer e servidor dedicado

- [ ] Servidor headless com autoridade sobre a simulação
- [ ] Sincronização por RPC, com validação de toda entrada do cliente
- [ ] Imagem Docker e guia de auto-hospedagem

## Licença

Código sob a [licença MIT](../LICENSE).
