# Dino Vale

Sandbox survival 2D top-down em pixel art, com exploração, construção e domesticação de dinossauros. É um jogo comunitário, gratuito e auto-hospedado, feito em Godot 4 com GDScript.

> **Estado:** fundação técnica, com o ciclo de domesticação jogável. A cena principal tem mapa com grama, caminho de terra, árvores, folhagem nas bordas, casa e baú decorativos, um jogador animado (Caveman) e um bicho placeholder (Reptile) passeando em uma área fechada. Arte e sons são do pacote Ninja Adventure (CC0), só como placeholder. A HUD mostra vida e fome, a barra de XP fina ("Nv 1", só o ponto de ligação) e a barra de atalhos 1 a 9, sem barra de stamina (o fôlego é som e nuvem). Com o dino inconsciente, barras de torpor e de domesticação aparecem sobre ele, a qualquer distância, e somem quando ele acorda (domesticado que desmaia mostra só o torpor). O dino da cena tem nível fixo (20, exportado na `Main`). Dá para derrubar o dino com o bastão-de-sono (tecla 4 o põe em mãos; F ou Espaço: 2 de dano e 30 de torpor, recarga de 0,7 s; de mãos livres o golpe é o Soco, 1 de dano e 10 de torpor), abrir o inventário compartilhado com E enquanto ele está inconsciente, passar comida para ele por clique e ver a domesticação chegar a 100%. Dormindo, a Eficiência cai com o tempo, a comida e os golpes, e o nível final sobe pela fórmula (a barra mostra "Nv 20 -> 28"). A barra de vida só aparece depois de dano. O jogo salva em arquivo (veja Save). Ainda não há construção, arte nem som definitivos.

## Controles

| Ação | Tecla |
|---|---|
| Andar | WASD ou setas |
| Correr | Shift |
| Interagir (abrir a criatura inconsciente; num domado seu, a menos de 3 tiles, alterna Seguir e Ficar) | E |
| Golpe com a arma equipada (dano + torpor) na criatura ao alcance | F ou Espaço |
| Inventário próprio | I ou Tab |
| Usar o atalho da barra (comida: o jogador come; equipamento: põe em mãos, de novo tira; Bastão na 4) | 1 a 9 |
| Na tela de inventário: atribuir o item sob o cursor ao atalho | 1 a 9, ou botão direito (primeira posição livre; de novo, tira) |
| Na tela de inventário | clique, ou setas + Enter/Espaço, transfere o slot inteiro; duplo clique ou Enter no Bastão o equipa (e, sem atalho, ele ganha o primeiro livre); duplo clique ou Enter na vaga "Arma" o tira; na tela compartilhada o clique simples NÃO move equipamento que o outro lado aceita (Shift+clique move); Esc, I ou E fecham |
| Pausa (sem tela aberta) | Esc: Continuar ou Voltar ao menu (salva e volta direto, sem perguntar) |
| Menu inicial | setas e Enter, ou mouse; Esc volta de Configurações e Créditos |

Com a tela aberta o jogador não anda. O jogador começa com 10 bagas (a comida ideal do dino), 4 carnes e 3 samambaias. Só a baga avança a domesticação; as outras ficam no inventário.

## Tela inicial, tela cheia e configurações

O jogo abre em `src/ui/TitleScreen.tscn` (cena principal do projeto) com **Um jogador, Multijogador, Configurações, Créditos e Sair**. Um jogador abre **Continuar** (só habilitado com save utilizável) e **Novo jogo**; Novo jogo com save existente pede confirmação (Cancelar selecionado, guarda de 500 ms contra duplo clique), porque ali o jogador apaga um mundo. Multijogador não existe ainda: o item aparece desabilitado com "Em breve". Configurações tem **Tela cheia** e **Volume geral** (Enter alterna a tela cheia; esquerda e direita mudam o volume de 5 em 5%; Enter no volume sobe 10%) e grava em `user://settings.json` (`GameSettings`, JSON lido com `SafeRead`; nunca `ConfigFile`, que executa código; arquivo ausente, grande, ilegível ou com valor inválido cai nos padrões: tela cheia e 80%). **A tela cheia só muda por esse menu: não há tecla de atalho.** Créditos mostram o que está em `assets/CREDITS.md` (`CreditsText`, sem texto próprio; a tabela de registro agrupada por autor, licença e fonte; setas e PgUp/PgDn rolam). O preset de exportação versionado (`export_presets.cfg`) já inclui `assets/CREDITS.md` no `include_filter` (a regra de arquitetura falha sem ele; sem segredo nem caminho local no arquivo); se o texto vier vazio, a tela de Créditos avisa em vez de ficar em branco. Na `Main`, Esc sem tela aberta abre a pausa (`PauseMenu`, pausa a árvore): Continuar ou Voltar ao menu (a cena vem de `Main.menu_scene`; vazia = só Continuar). Voltar ao menu salva e volta direto; se a escrita falhar, a partida não fecha e o motivo aparece na pausa. Com a tela de inventário aberta o Esc é dela. Recusa de equipar por grade cheia (inclusive pela tecla de atalho) aparece como aviso na HUD. A lógica (`MenuNavigation`, `GameSettings`, `CreditsText`) está em `src/core` e não conhece UI; um servidor sem janela não precisa da cena inicial (nem do menu): ele instancia só o mundo.

**Tela cheia e proporção:** `project.godot` abre em tela cheia (`window/size/mode=3`), com `stretch/mode=viewport`, `scale_mode=integer` e `aspect=keep`: a imagem de 320x180 só cresce em múltiplos inteiros (pixel art nítida, nunca esticada) e o que sobra vira barra preta (cor de fundo preta). Em 1280x720 a escala é 4x e em 1920x1080 é 6x, sem barras; em monitores de outra proporção (16:10, ultrawide) ou de resolução que não é múltipla (ex.: 1600x900, 5x com faixa) aparecem barras. A câmera (`PlayerCamera`) fica centrada no personagem e só para no limite do mapa (`data/world/map_bounds.tres`); a névoa de borda (`FogFrame`) é só visual.

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

## Save

Um mundo em `user://saves/main/world.json` (JSON, envelope `{format_version, game_version, saved_at, world, players, entities}`; ADR-002). `SaveManager` (`src/core`) grava de forma atômica (`.tmp`, relê e valida, o save válido atual vira `.bak`, o `.tmp` vira o principal) e lê com limite de 64 MiB, só JSON; principal danificado cai no `.bak`; versão do formato maior que a do jogo é recusada sem tocar no arquivo; arquivo danificado nunca é apagado (vai para `.rejected` ao gravar por cima). `SaveMigrations` guarda as migrações puras encadeadas; as fixtures `tests/fixtures/saves/v1.json`, `v2.json` e `v3.json` nunca são removidas (a v2 acrescenta ao `world` o estado dos nós de recurso e o contador de respawns; a migração v1 para v2 os cria vazios; a v3 acrescenta ao dino domado o dono, `owner_player_id`, e a ordem, `state_machine.order`: a migração v2 para v3 dá ao domado o primeiro jogador do save como dono (`owner_player_id`) e a ordem STAY, e ao selvagem com domesticação em andamento, só como quem alimentou). `WorldSnapshot` (`src/world`) captura e aplica jogador, dino (nível e Eficiência inclusos) e o mundo. O jogador morto é gravado como `dead_pending_choice` e carregado MORTO: o Continuar abre a tela de morte (`DeathScreen`, regiões em `data/balance/respawn_rules.tres`) e só `Main.request_respawn(region_id)` tira desse estado (ponto sorteado pelo `RespawnPicker`, vida 100%, fome 50%, proteção de 3 s; o inventário fica com o jogador até o corpo do SOB-02, M2). Os nós de recurso (MUN-02: `ResourceNode`, dados em `data/resources/`, coleta por `Player.request_gather`) vão no save pelo `ResourceField`.

Quando salva (`SaveScheduler`, números em `data/balance/save_rules.tres`): a cada 300 s de jogo (pausado não conta; o relógio zera a cada save), na morte do jogador, na morte de um dino domado, ao escolher onde renascer, ao voltar ao menu e ao fechar a janela (a pausa não tem Salvar: o jogador não escolhe quando salvar); `SaveManager.Reason.BED` é o ponto de entrada da Cama (que ainda não existe). Gatilhos no mesmo quadro viram um save; morte a menos de 10 s do último espera o prazo (nunca é descartada); menu e sair ignoram o prazo. O jogo nunca pergunta antes de salvar. Um indicador "Salvando" de 1 s aparece no canto. Falha de escrita avisa na HUD, o jogo segue com o arquivo anterior intacto e o pedido é refeito depois de 10 s. Só save válido entra no rodízio `.bak`: versão futura ou arquivo danificado vai para `world.json.rejected[.N]` e nunca é apagado. Continuar com save recusado volta ao título com o motivo, sem jogo novo e sem gravar nada.

## Arquitetura

Três regras guiam o código:

1. **Lógica separada da apresentação.** Regras de jogo estendem `Node` ou `RefCounted`, nunca `CanvasItem`. Elas publicam sinais e valores, e o corpo e a interface reagem. Assim tudo roda igual em um servidor `--headless`.
2. **Composição.** Entidades são montadas com componentes reutilizáveis, sem herança profunda.
3. **Persistência limpa.** Tudo que precisa ser salvo expõe `to_dict()` e `from_dict()` com dados compatíveis com JSON.

### Camada de autoridade (NET-01, ADR-001)

Todo ato do jogador sobre criaturas, itens e nós de recurso é uma intenção `WorldAuthority.request_*` (`src/world/WorldAuthority.gd`), com ids de entidade (`int`) e nunca nó: `request_attack`, `request_interact`, `request_transfer_slot` (alimentar a criatura dormindo ou recolher dela) e `request_command` (Seguir e Ficar). Ela valida nesta ordem (ator vivo, argumento, alvo por id, alcance real, regra de domínio como recarga, posse e estado) e, negada, **não muda nada**, devolve um `Enums.ActionResult` e emite `action_denied`. Alcances em `data/balance/action_rules.tres`. O jogador (`Player.attack`, `try_interact`) e a tela de inventário (`transfer_requested`) só pedem; a `Main` registra o jogador (id 1) e a criatura (id 2) e liga os sinais. `request_use_item(actor_id, slot)`, `request_equip(actor_id, iid, slot_id)`, `request_unequip(actor_id, slot_id)` e `request_gather(actor_id, target_id)` seguem o mesmo contrato (ator vivo, argumento, alvo por id, alcance, regra; negado = nada muda): o `Player` (`request_use_item`, `request_equip`, `request_unequip`, `request_gather`) só pede e a autoridade chama a regra (`perform_use_item`, `perform_equipment`, `perform_gather`). A coleta usa o id do alvo concedido, nunca a mira local. O dono do domado é o `player_id` do personagem (`Dino.owner_player_id`, salvo como `owner_player_id`), e `Dino.player_locator` o acha no mundo.

### Ordens do dino domado (CRI-05)

O domado acordado obedece Seguir ou Ficar (`Enums.DinoOrder`, salvo pelo nome em `state_machine.order`). Seguir anda até o dono e para a 2,5 tiles quando passa de 3 (histerese; números em `data/balance/dino_order_rules.tres`); Ficar para onde está. O dono é quem depositou PRIMEIRO a comida ideal (`Dino.feeder_player_id`, só grava se vazio, vira `owner_player_id` ao fim da domesticação; limpa quando a doma reinicia; recolher da criatura não conta). Golpe de jogador que não reservou tira vida e põe torpor, mas não derruba a Eficiência. O teto de nível do servidor no MVP é 50 (`dino_level_rules.tres`). Seguir anda a 1,8 vezes a velocidade base (72 px/s, o jogador anda a 70): correndo, o dono abre distância e o dino alcança quando ele para. Dono morto ou fora do mundo conta como ausente: o dino fica onde está, a ordem se mantém e ele volta a seguir quando o dono renasce. Pelo jogo: chegar a até 3 tiles do domado seu e apertar E alterna as duas ordens (o prompt diz qual). Só o dono manda; postura, "ir até aqui", comando de rebanho, menu e permissão são do CRI-43 (v0.2).

### Estrutura

```text
game/
├── project.godot
├── assets/                  # sprites, sons e fontes
├── data/                    # balanceamento em .tres (balance/, dino/, weapons/)
├── src/
│   ├── core/                # enums, catálogo de itens
│   │   ├── Enums.gd
│   │   ├── ItemDef.gd       # definição de um item (id, nome, pilha, cor)
│   │   ├── DinoLevelRules.gd  # fórmulas de nível (Resource)
│   │   ├── DinoBaseStats.gd   # atributos base do dino (precursor do SpeciesDef)
│   │   ├── TamingRules.gd     # regras da Eficiência
│   │   ├── TorporBandRules.gd # faixas de torpor
│   │   ├── PlayerRules.gd     # fome (0,2/s e limiar do aviso), recarga de comida, ofego
│   │   ├── SaveManager.gd     # arquivo de save: envelope, escrita atômica, .bak
│   │   ├── SaveMigrations.gd  # migrações puras do envelope
│   │   ├── SaveRules.gd       # intervalo do autosave e prazo de rajada
│   │   ├── GameSession.gd     # pasta dos saves e pedido de Continuar
│   │   ├── WeaponDef.gd       # arma do jogador
│   │   └── Items.gd         # catálogo: berry, meat, fern
│   ├── components/          # componentes reutilizáveis
│   │   ├── HealthComponent.gd
│   │   ├── HungerComponent.gd
│   │   ├── InteractableArea.gd
│   │   ├── InventoryComponent.gd
│   │   ├── HotbarComponent.gd
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
│   │   ├── PlayerHud.gd     # vida, fome, XP (Nv) e prompt
│   │   ├── HotbarBar.gd     # barra de atalhos 1 a 9
│   │   ├── FloatingText.gd  # número flutuante (dano no dino e no jogador)
│   │   ├── BreathSound.gd   # placeholder sintetizado do ofegar
│   │   ├── DinoStatusBars.gd # barras de vida, torpor, domesticação e Eficiência
│   │   ├── DinoView.gd       # sprite do dino: direção, andar, sono, cambaleio, pausa, flash, números, som
│   │   ├── PlayerView.gd     # sprite do jogador: parado, andar, ataque, morto, som do golpe
│   │   ├── SpriteFacing.gd   # colunas de direção e ciclo de andar das folhas do pacote
│   │   ├── StatBar.gd
│   │   ├── InventoryScreen.gd
│   │   └── UiTheme.gd
│   └── world/               # mapa, grid, chunks e estruturas
│       ├── Main.gd          # liga o mundo à UI e ao save
│       ├── SaveScheduler.gd # quando salvar (intervalo, morte, menu, sair)
│       ├── RespawnPicker.gd # sorteio do ponto de respawn numa região
│       ├── ResourceField.gd # nós de recurso do mundo (save e desenho provisório)
│       ├── WorldSnapshot.gd # captura e aplica o estado no envelope
│       ├── Main.tscn
│       ├── Terrain.tscn     # camadas de chão e de cenário, montadas por TerrainView a partir do mapa
│       ├── TerrainTiles.gd  # autotile (blob 47) e TileSets, tudo lido do dado
│       ├── ActivityZone.gd  # regra pura da zona ativa (ativo, distante, dormente)
│       └── DinoZone.gd      # aplica a zona aos dinos (process_mode, passeio em dado)
└── tests/
	├── run_tests.gd
	├── dino_level_tests.gd  # nível, Eficiência, combate, faixas, apresentação
	├── dino_review_tests.gd # regras de save e achados das revisões
	├── hud_hotbar_tests.gd  # HUD, atalhos 1 a 9, ofegar, dano recebido
	├── inventory_model_tests.gd # PRO-15 e PRO-22: pilha/individual, save v2, migração, vagas de equipamento
	├── menu_tests.gd            # apresentação, navegação, configurações, créditos e pausa
	├── save_tests.gd            # save: arquivo, fixture, gatilhos, Continuar/Novo jogo, fome do jogador
	├── fixtures/saves/v1.json   # save v1 congelado (nunca remover)
	├── fixtures/saves/v2.json   # save v2 congelado (nunca remover)
	└── saveable_table.gd
```

### Componentes

**`EquipmentComponent`** (PRO-22, GDD 5.20) são as 6 vagas de equipamento (Arma, Capacete, Camisa, Luva, Calça, Bota), definidas em dados (`data/equipment/layout.tres`: `EquipmentLayout` com `EquipmentSlotDef` `id`, `display_name`, `shown` = `slot_visivel`, `hotbar`); cada item equipável declara sua vaga em `ItemDef.slot` (o Bastão: `weapon`; a vaga Arma recebe qualquer item de mão). O equipado SAI da grade e fica na vaga, com `iid` e durabilidade. `equip(iid, vaga)` valida (item existe na grade, vaga existe, `slot` confere; troca devolve o antigo à grade) e `unequip(vaga)` recusa com "full" se a grade não tem posição livre, sem perder item; ambos devolvem "" ou o motivo. Quem pede é o `Player` (`request_equip`, `request_unequip`, recarga 0,3 s, sinal `equip_refused` para o aviso "Inventário cheio"; vaga errada recusa sem mensagem). A tecla do atalho equipa (grade para vaga) e de novo desequipa; o atalho segue pelo `iid` com o item na vaga e a barra mantém o destaque amarelo; roupa não vai ao atalho (`hotbar` da vaga, validado em `HotbarComponent`). Limpar o atalho não tira o item da vaga. Save `{version: 1, slots: {vaga: item}}` (o item inteiro, porque não está mais na grade; o GDD guarda `{vaga: iid}`), `from_dict` devolve bool e recusa o bloco todo se algo é inválido. A tela mostra só a vaga Arma (as 5 de roupa só no M4, quando existir item). Sem desgaste, redução de dano, peso nem arrastar (fora do escopo).

**`HealthComponent`** guarda a vida da entidade. Sinais: `health_changed`, `damaged`, `healed` e `died`.

**`TorporComponent`** é uma barra independente da vida. Acordada, a criatura não mostra barra: só a faixa 0 a 3 (`band`, 25/50/75% com histerese de 3 pontos, `band_changed`). Faixa 2: velocidade x0,85; faixa 3: x0,65, pausa de 0,8 s a cada 4 s (determinística, `pause_phase`) e cooldown x1,5 (`movement_multiplier`, `is_paused`, `attack_cooldown_multiplier`). Valores em `data/balance/torpor_bands.tres`. Quando `current_torpor >= max_torpor`, emite `knocked_out`. A criatura só acorda quando o torpor cai até `wake_ratio * max_torpor`, e então emite `woke_up`. A queda por segundo é configurável separadamente para consciente e inconsciente, e essa segunda taxa define quanto tempo o jogador tem para domesticar.

**`StaminaComponent`** é o fôlego. Gasta enquanto o corpo diz que está correndo e regenera parado. Ao zerar, entra em exaustão e só volta a correr ao recuperar `resume_threshold`. Sinais: `stamina_changed`, `exhausted` e `recovered`. Abaixo de 25% do máximo (`winded_ratio`, dados) está ofegante (`is_winded`, `winded_intensity`): o `PlayerView` toca sopros cada vez mais rápidos e agudos e, ao zerar, um fôlego longo e uma nuvem de suor (GDD 5.7). Parar de correr por ~1,3 s vem do limiar de retomada (20 a 15/s). Golpes e coleta ainda NÃO gastam stamina (aguarda a SHIRO).

**`HotbarComponent`** guarda 9 entradas: um TIPO de item empilhável (`{id}`, mostra a soma das pilhas; sem estoque fica apagado mas atribuído) ou um item individual por `iid` (`{iid}`, segue o item ao movê-lo; some do inventário = apagado, volta quando o mesmo `iid` volta). Conflito GDD 5.2 x 5.9 (atalho por tipo x por slot): comida fica por tipo (a soma é requisito do 5.2) e equipamento por `iid`; atribuir equipamento por tipo é recusado. Save v2 `{version: 2, slots: [{} | {id} | {iid, id?}]}`; o v1 (strings) migra; versão inválida ou maior e `slots` que não é Array são recusados (`from_dict` devolve false e nada muda). `Player.request_use_item(slot)` é a intenção de usar a tecla (leitura do corpo, ações `hotbar_1` a `hotbar_9`): COMIDA é consumida (fome sobe pelos dados de `data/balance/player_rules.tres`, `PlayerRules`: baga 25 do GDD, carne 40 e samambaia 15 placeholders; não gasta com a fome cheia; recarga 0,5 s) e não mexe no equipado, mesmo com dino dormindo ao alcance (decisão do dono; o dino recebe comida só pela tela dele). EQUIPAMENTO é SELECIONADO: a tecla do Bastão o põe em mãos, de novo desequipa (mãos livres), recarga 0,3 s; item em mãos que sai do inventário, ou cujo atalho é limpo, solta as mãos (mudar o atalho de posição não). Comer e equipar têm recargas separadas (0,5 s e 0,3 s). Atalho de item que saiu do inventário fica apagado com o ícone do tipo (dica `id` guardada na entrada `{iid, id}`) e se limpa, com o inventário aberto, apertando a tecla da posição sem item sob o cursor (só vale para atalho órfão). `Player.equipped_iid` e `current_weapon()` (arma do item, ou o Soco `data/weapons/punch.tres`: dano 1, torpor 10, 0,6 s). O Bastão nasce no inventário como individual (durabilidade 120, sem desgaste ainda) na barra, tecla 4, com as mãos livres. Os números do jogador (queda de fome 0,2/s e aviso a 25%, recargas, limiar de ofego 25%, saciedade) ficam no `.tres`.

**`HungerComponent`** guarda a saciedade (cheia = 100), que cai com o tempo. Em zero emite `starved(damage)` a cada `starvation_interval`; o `Player` liga esse sinal ao `HealthComponent.take_damage`. `eat(amount)` interrompe o dano.

**`InventoryComponent`** (PRO-15, GDD 5.9) tem dois formatos de slot: pilha `{id, count, expira_em}` (`expira_em` 0 = não vence; juntar pilhas com validades diferentes fica com a mais antiga, a regra de 2 min é do PRO-17) e item individual `{id, iid, durab, durab_max}` para arma, ferramenta e armadura (`ItemDef.durability_max > 0`): não empilha, conta como 1 e leva `iid` e durabilidade ao ser transferido. `find_iid`, `remove_iid`, `add_entry` e `transfer_slot` operam por item. O `iid` é "prefixo + contador" (`iid_prefix`: "p" jogador, "d" criatura) até a autoridade (NET-01) alocá-lo. Só o CAMPO de durabilidade existe: desgaste, quebra, reparo e passagem de validade são do PRO-16/17. A criatura NÃO guarda equipamento (`accepts_individual = false` no `Dino.tscn`): `add`, `add_entry`, `transfer`, `transfer_slot` e a carga o recusam, e a tela avisa "X não vai para a criatura". `add_entry` devolve quanto não coube (0 = tudo), recusa entrada inválida (id desconhecido, count 0, individual sem `iid`) e emite `changed` também em inserção parcial; `transfer_slot` tira do slot clicado. `to_dict` sai com `version: 2`; `from_dict` devolve bool e recusa TUDO (nada muda) se a versão é inválida ou maior, se `slots` não é Array (`{}` não apaga o inventário) ou se algum item válido não cabe (regra mais segura: nada some calado; pilha acima do teto é dividida, não cortada). Migra o v1 (`{id, count}` sem versão: equipamento vira N individuais com durabilidade cheia, pilha sem validade) e aplica padrão seguro a `iid` ausente ou repetido, durabilidade e validade inválidas. `capacity` e `max_stack` são exportados; vale o menor entre o teto do inventário e o do item (`Items`). `add(id, n)` devolve quanto NÃO coube, `remove(id, n)` devolve quanto saiu e `count(id)` soma as pilhas. `transfer(destino, id, n)` e `transfer_slot(i, destino)` só movem o que o destino comporta, então item nunca some nem duplica. Ids desconhecidos são rejeitados. Sinal: `changed`.

**`InteractableArea`** (`Area2D`) marca uma entidade como interagível. A regra de quando se pode interagir fica na entidade, que injeta `availability`. Quem muda o estado chama `refresh()`, e `availability_changed` avisa a UI. O `Dino` só pode ser aberto se estiver inconsciente e selvagem.

**`TamingComponent`** consome a comida ideal do `inventory` compartilhado do Dino a cada `seconds_per_meal` enquanto a criatura selvagem está inconsciente e preenche `taming_progress`. Em 100% chama `DinoStateMachine.mark_tamed()`. Sem comida ideal o progresso para e não regride. Se a criatura acordar antes de terminar, o progresso zera, mas a comida que sobrou continua no inventário. Não mantém estoque próprio.

A **Eficiência** (0 a 100) começa em 100 ao dormir e só cai: 0,3 por segundo, 2 por baga e, por ataque recebido dormindo, `fixo[atacante] + 0,5 x % da vida máxima perdida` (jogador 4, carnívoro 8; `apply_attack`). Acordada ou domesticada, não cai. As refeições dependem do nível (`ceil(5 x fator)`). Ao fechar, `nível final = min(floor(L x (1 + 0,5 x E/100) + 0,5), floor(1,5 L + 0,5))` (20 com 100% vira 30; 7 com 60% vira 9; com 0% domestica sem bônus). Sinais: `efficiency_changed`, `level_preview_changed`, `level_finalized`, `taming_failed` (o dino morreu durante a domesticação: o progresso zera e a comida gasta se perde). Valores em `data/balance/taming_rules.tres`.

### Nível e dano no dino

`Dino.level` (exportado, salvo em `to_dict`) deriva vida máxima, dano, torpor máximo e refeições por `DinoLevelRules` (`data/balance/dino_level_rules.tres`) sobre os atributos de `DinoBaseStats` (`data/dino/`): vida e dano x(1 + 0,04 (L-10)), torpor x(1 + 0,02 (L-10)), refeições x(1 + 0,015 (L-10)), com pisos. O máximo vem sempre do nível, nunca do save. A `Main` fixa o nível com `dino_level`.

`Dino.receive_hit(dano, torpor, attacker_kind)` aplica o dano primeiro e o torpor depois (o golpe que derruba não conta como ataque ao dormindo); `Dino.take_damage(dano, attacker_kind)` é a API para qualquer atacante (`"player"` ou `"carnivore"`; desconhecido é rejeitado). Não há IA de carnívoro nem detecção. Dormindo e selvagem, o dano também derruba a Eficiência; acordado, só tira vida. Domesticado não é alvo do jogador.

### Arte, mapa e som (Ninja Adventure, placeholder)

Tudo vem de `assets/third_party/ninja-adventure/` (caminhos, quadros e direções em `MAPA.md` da pasta; registro em `assets/CREDITS.md`). O filtro de textura é nearest (`project.godot`, sem mudança) e só há escala inteira.

- **Mapa:** a ilha Lunata (256x256 tiles de 16 px) vem de `data/world/lunata.json`, exportado por `docs/design/mapa_export.py` a partir de `docs/design/mapa_sim.py` (determinístico, nunca gerado ao rodar; `python3 docs/design/mapa_export.py --check` falha se o arquivo divergir). `IslandMap` lê e valida o dado (arquivo ruim vira mapa vazio). `TerrainView` monta seis camadas `Ground0..5` (autotile blob 47 de `terreno.png` + `terreno.json`, uma por posto de terreno) e a camada `Scenery` (árvores decorativas e formações, colisão só nos pés, ordem por Y). O motor só desenha o que cabe na tela (quadrantes de 16 tiles). Praia e raso se andam sem lentidão; a água funda bloqueia, e só o anel de 2 tiles junto ao raso tem colisão. O limite da câmera é `data/world/map_bounds.tres`. Nós de recurso nascem de `lunata.json` (`ResourceField.populate`, ids `<tipo>_<n>`), com defs em `data/resources/` e as regras em `data/world/world_rules.tres`. O minério existe em dado e fica desligado na v0.2. Os selvagens (Paquicéfalo e, na Mata-baixa, Utahraptor, que persegue o jogador que avista; sem navegação ainda) nascem em bandos, em posição sorteada pela semente do mundo dentro da região de cada vaga do mapa (`WildLayout`; o bando renasce em outro lugar quando o último selvagem morre ou é domado) e vivem na zona ativa (`data/world/zone_rules.tres`: ativo até 16 tiles, distante até 40, teto de 32 ativos; só os ativos têm `DinoView` e barras). O save leva o delta dos selvagens sem dono (`WildPopulation`, id do membro `<vaga>.<geração>.<k>`, e `world.wild_groups` para as vagas não intactas) e os domados como entidades `tamed_dino` e a colheita parcial dos nós (`leftover`).
- **Regras do servidor (ADR-004):** `user://saves/<mundo>/server_rules.json` (ou `--server-rules=<caminho>` nos argumentos de usuário) é escrito pelo jogo uma vez, com os valores do momento, e depois é do operador: o jogo só lê, ao carregar o mundo. Chaves da E1: `multiplicador_coleta`, `respawn_recurso`, `faixas_de_nivel`, `respawn_protecao_s`, `respawn_fome_pct`, `eficiencia_fixa_ataque_jogador`, `eficiencia_fixa_ataque_carnivoro`, `pvp` (booleano, padrão `false`: golpe em área não acerta domados de outro jogador). Valor inválido ou fora da faixa volta ao padrão da `.tres`, com aviso no log. Para pegar um padrão novo da `.tres` num mundo que já tem o arquivo, apague a chave ou o arquivo.
- **Sprites:** o jogador usa `characters/caveman.png` (linhas 0 a 3 andar, 4 ataque, 6 morto); o dino usa `animals/reptile.png` (4 direções x 4 quadros de andar), com o sprite girado 90 graus e o balão "zz" quando dorme. A escolha do quadro é só apresentação (`PlayerView`, `DinoView`); o corpo só expõe `visual`, `velocity` e o sinal `attacked`. O cambaleio é um deslocamento de 1 a 2 px (pixel art não gira em ângulo fracionário).
- **8 direções (08/11):** o jogador e o Paquicéfalo têm folhas de 8 linhas (baixo, cima, esquerda, direita e as 4 diagonais; `linhas_direcao` no JSON). `SpriteFacing.facing_for` escolhe a linha pelo setor de 45 graus, com histerese de 8 graus, e cai no cardinal se a folha tem só 4 linhas; `SpriteFacing.fit_sheet` ajusta `hframes`/`vframes` do sprite ao JSON. Os outros dinos seguem com 4 linhas.
- **Música e menu (08/11):** `MusicPlayer` toca a faixa do menu no título e, no jogo, a de dia ou a de noite conforme o `WorldClock` (divisão em `data/balance/music_rules.tres`, provisória até o ciclo de dia e noite), com crossfade, no barramento Music. O título usa o fundo em 5 camadas com parallax pelo mouse (`MenuBackdrop`), o logo e os botões 9-slice de `assets/ui/menu/`. Placas de dino mostram o símbolo de sexo (`SexIcon`).
- **UI:** painéis 9-slice (`panel_a`, margem 6), células de inventário (`inventory_cell`), ícones de item (`ItemIcons.icon_of`) e da HUD (coração, pena, carne). As barras seguem coloridas por código.
- **Sons:** `hit/hit1.wav` (dano no dino), `pickup/powerup1.wav` (domesticou) e `swing/whoosh.wav` (golpe do jogador), ligados em `cue_streams` das views na `Main.tscn` com `volume_db` +6 (o pacote tem pico de -10 dBFS). Sem som ainda: bocejo, dor, ronco.

### Jogador

`Player` é um `CharacterBody2D` top-down (`motion_mode` floating). Só o corpo lê `Input` (`read_direction`); a regra de movimento (`apply_input(direction, wants_sprint, delta)`) recebe a direção pronta, então é testável sem input real. O sinal `attacked` sai quando o golpe acerta (a `PlayerView` anima e toca o som). Ações: `move_up/down/left/right` (WASD e setas), `sprint` (Shift), `interact` (E), `attack` (F, Espaço) e `inventory` (I, Tab). A diagonal tem o mesmo comprimento que o eixo. Só corre quem está se movendo e tem stamina.

Um detector (`Area2D`) enxerga as `InteractableArea` no alcance, e o `target` é a mais próxima (sinal `target_changed`). `try_interact()` emite `interacted(target)` se a entidade permitir; `attack()` aplica a arma em mãos (`current_weapon()`, um `WeaponDef` de `data/weapons/`: Soco 1/10/0,6 s de mãos livres, ou bastão-de-sono 2/30/0,7 s equipado pela tecla 4) à criatura selvagem alvo, com recarga. Ambos são chamáveis sem teclado. `input_locked` congela o jogador enquanto a tela de inventário está aberta.

### UI

Tudo em `src/ui/` é só apresentação, reage a sinais e pode ser removido sem efeito nas regras. `PlayerHud` mostra vida, fome, a barra de XP com "Nv N" e a `HotbarBar` (9 atalhos), mais o prompt "E para interagir". O XP ainda não existe: `set_experience(nível, atual, necessário)` é só o ponto de ligação e a HUD nasce em Nv 1, XP 0. `PlayerView` mostra o dano recebido (número vermelho e `sound_cue(hurt)`) e o ofegar (`pant`, `gasp`, nuvem). Na tela de inventário, a tecla 1 a 9 com o foco ou o mouse sobre um item o atribui ao atalho; o pedido sai por `hotbar_assign_requested` e a `Main` muda o `HotbarComponent`. `DinoStatusBars` é instanciada na `Main` (fora do `Dino.tscn`), segue o dino e mostra torpor, domesticação e Eficiência com o nível previsto só enquanto ele dorme (domesticação e Eficiência somem se ele já é domesticado), e a barra de vida só depois de dano, até 5 s após o último. `DinoView` faz a apresentação sobre o placeholder: cambaleio por faixa, achatamento e "..." na pausa, bocejo, flash branco de 0,1 s e número flutuante ao levar dano.

**Som (ponto de ligação, sem áudio criado):** `DinoView` emite `sound_cue(cue)` (`hit`, `yawn`, `tamed`) e toca no seu `AudioStreamPlayer2D` se houver stream em `cue_streams`. Coloque os arquivos em `res://assets/sounds/dino/`, registre-os em `assets/CREDITS.md` e arraste-os para `cue_streams` do nó `DinoView` na `Main.tscn`. `InventoryScreen` mostra o inventário do jogador e o da criatura; ela fecha sozinha se o dino acordar, for domesticado ou sair da cena. A `Main` liga `Player.interacted` à tela e a tela ao `input_locked` do jogador. A fonte é a padrão da engine em tamanho 10, pensada para 640x360.

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
  "level": 20,
  "health": { "current": 75.0, "max": 100.0 },
  "torpor": { "current": 100.0, "max": 100.0, "is_unconscious": true, "band": 3, "pause_clock": 0.0, "pause_phase": 1.3 },
  "inventory": { "version": 2, "next_iid": 2, "slots": [ { "id": "berry", "count": 4, "expira_em": 0.0 }, { "id": "sleep_staff", "iid": "p1", "durab": 120, "durab_max": 120 }, {}, {}, {}, {}, {}, {} ] },
  "taming": { "progress": 20.0, "meal_timer": 2.0, "efficiency": 96.2 },
  "state_machine": { "state": "UNCONSCIOUS", "is_tamed": false }
}
```

`Player.to_dict()` salva `version` (2), `position`, `health`, `stamina`, `hunger`, `inventory`, `hotbar` e `equipment` (as vagas). Save antigo (sem `version`; inventário `{id, count}`, barra de strings, item em mãos em `equipped` DENTRO da grade) carrega sem perder itens, e `equipped` migra: o item sai da grade e vai para a vaga Arma se for arma (sem `equipment` no save). Bloco `inventory`, `hotbar` ou `equipment` que existe e não é dicionário, ou com `version` e sem `slots`, recusa o save (`{}` segue válido, parcial); `version` do jogador inválida ou maior também recusa. `Player.from_dict` e `Dino.from_dict` conferem as versões do inventário e da barra ANTES de aplicar qualquer campo: versão desconhecida recusa o save inteiro (devolve false, nada muda). Save parcial: sem `inventory` mantém inventário e barra; com `inventory` e sem `hotbar`, a barra é esvaziada (os `iid` antigos não valem); save de inventário sem versão (formato antigo) ganha o Bastão inicial que não tinha e o atalho na primeira posição livre (versão 1 explícita conta como antigo). Se não houver espaço para esse Bastão sem descartar item, a migração é RECUSADA (`false`, nada muda). Contrato do `bool` de `from_dict` (SAV-01): `true` = aplicado; `false` = recusado e nada mudou, e o SaveManager deve tratá-lo como save inválido, sem carga parcial. `Player` e `Dino` validam o inventário (`InventoryComponent.can_load`, que usa uma cópia `preview()`) antes de tocar em qualquer campo. Item além da capacidade do save é compactado em slot livre; só recusa se não houver. Sem `equipment` nem `equipped` no save, as vagas não mudam; com `inventory` e sem `equipment`, ficam vazias. No `from_dict` do inventário, ids desconhecidos e contagens inválidas são descartados. Save sem `level` (ou com nível inválido) usa o `base_level` do dado e sem `efficiency` usa 100. A faixa de torpor, o relógio e a fase da pausa são salvos; a faixa é revalidada com `next_band(faixa_salva, fração)`, preservando a histerese. O `max` de vida e de torpor do save é ignorado. Campos de tipo errado, NaN ou fora da faixa caem no padrão (`SafeRead`), vida 0 no save vira dino morto na carga (sem `died`) e `progress = 100` dormindo volta à penúltima refeição. `from_dict` não emite `band_changed` nem `level_changed`. A fase da pausa vem do ponto de nascimento até existir id de entidade. Saves antigos com `taming.food_stock` são ignorados (o jogo não foi publicado).

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
- [x] Morte e respawn mínimos do jogador (SOB-01, só Campina); [ ] corpo com itens (SOB-02, M2) e estado `Dead` da criatura
- [ ] Arte, som e fontes definitivos

### Fase 3: multiplayer e servidor dedicado

- [ ] Servidor headless com autoridade sobre a simulação
- [ ] Sincronização por RPC, com validação de toda entrada do cliente
- [ ] Imagem Docker e guia de auto-hospedagem

## Licença

Código sob a [licença MIT](../LICENSE).
