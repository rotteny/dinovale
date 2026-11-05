# Dino Vale

Sandbox survival 2D top-down em pixel art, com exploração, construção e domesticação de dinossauros. É um jogo comunitário, gratuito e auto-hospedado, feito em Godot 4 com GDScript.

> **Estado:** fundação técnica, com o ciclo de domesticação jogável. A cena principal tem mapa com grama, caminho de terra, árvores, folhagem nas bordas, casa e baú decorativos, um jogador animado (Caveman) e um bicho placeholder (Reptile) passeando em uma área fechada. Arte e sons são do pacote Ninja Adventure (CC0), só como placeholder. A HUD mostra vida e fome, a barra de XP fina ("Nv 1", só o ponto de ligação) e a barra de atalhos 1 a 9, sem barra de stamina (o fôlego é som e nuvem). Com o dino inconsciente, barras de torpor e de domesticação aparecem sobre ele, a qualquer distância, e somem quando ele acorda (domesticado que desmaia mostra só o torpor). O dino da cena tem nível fixo (20, exportado na `Main`). Dá para derrubar o dino com o bastão-de-sono (tecla 4 o põe em mãos; F ou Espaço: 2 de dano e 30 de torpor, recarga de 0,7 s; de mãos livres o golpe é o Soco, 1 de dano e 10 de torpor), abrir o inventário compartilhado com E enquanto ele está inconsciente, passar comida para ele por clique e ver a domesticação chegar a 100%. Dormindo, a Eficiência cai com o tempo, a comida e os golpes, e o nível final sobe pela fórmula (a barra mostra "Nv 20 -> 28"). A barra de vida só aparece depois de dano. Ainda não há construção, save em arquivo, arte nem som definitivos.

## Controles

| Ação | Tecla |
|---|---|
| Andar | WASD ou setas |
| Correr | Shift |
| Interagir (abrir a criatura inconsciente) | E |
| Golpe com a arma equipada (dano + torpor) na criatura ao alcance | F ou Espaço |
| Inventário próprio | I ou Tab |
| Usar o atalho da barra (comida: o jogador come; equipamento: põe em mãos, de novo tira; Bastão na 4) | 1 a 9 |
| Na tela de inventário: atribuir o item sob o cursor ao atalho | 1 a 9, ou botão direito (primeira posição livre; de novo, tira) |
| Na tela de inventário | clique, ou setas + Enter/Espaço, transfere o slot inteiro; duplo clique ou Enter no Bastão o equipa (e, sem atalho, ele ganha o primeiro livre); duplo clique ou Enter na vaga "Arma" o tira; na tela compartilhada o clique simples NÃO move equipamento que o outro lado aceita (Shift+clique move); Esc, I ou E fecham |
| Pausa (sem tela aberta) | Esc: Continuar ou Voltar ao menu (pede confirmação: a partida não é salva) |
| Menu inicial | setas e Enter, ou mouse; Esc volta de Configurações e Créditos |

Com a tela aberta o jogador não anda. O jogador começa com 10 bagas (a comida ideal do dino), 4 carnes e 3 samambaias. Só a baga avança a domesticação; as outras ficam no inventário.

## Tela inicial, tela cheia e configurações

O jogo abre em `src/ui/TitleScreen.tscn` (cena principal do projeto) com **Um jogador, Multijogador, Configurações, Créditos e Sair**. Um jogador entra na `Main` (sempre um jogo novo: não há save em disco). Multijogador não existe ainda: o item aparece desabilitado com "Em breve". Configurações tem **Tela cheia** e **Volume geral** (Enter alterna a tela cheia; esquerda e direita mudam o volume de 5 em 5%; Enter no volume sobe 10%) e grava em `user://settings.json` (`GameSettings`, JSON lido com `SafeRead`; nunca `ConfigFile`, que executa código; arquivo ausente, grande, ilegível ou com valor inválido cai nos padrões: tela cheia e 80%). **A tela cheia só muda por esse menu: não há tecla de atalho.** Créditos mostram o que está em `assets/CREDITS.md` (`CreditsText`, sem texto próprio; a tabela de registro agrupada por autor, licença e fonte; setas e PgUp/PgDn rolam). O preset de exportação versionado (`export_presets.cfg`) já inclui `assets/CREDITS.md` no `include_filter` (a regra de arquitetura falha sem ele; sem segredo nem caminho local no arquivo); se o texto vier vazio, a tela de Créditos avisa em vez de ficar em branco. Na `Main`, Esc sem tela aberta abre a pausa (`PauseMenu`, pausa a árvore): Continuar ou Voltar ao menu (a cena vem de `Main.menu_scene`; vazia = só Continuar). Voltar ao menu pede confirmação (Cancelar é o padrão) enquanto não houver save em arquivo (`PauseMenu.confirm_discard`). Com a tela de inventário aberta o Esc é dela. Recusa de equipar por grade cheia (inclusive pela tecla de atalho) aparece como aviso na HUD. A lógica (`MenuNavigation`, `GameSettings`, `CreditsText`) está em `src/core` e não conhece UI; um servidor sem janela não precisa da cena inicial (nem do menu): ele instancia só o mundo.

**Tela cheia e proporção:** `project.godot` abre em tela cheia (`window/size/mode=3`), com `stretch/mode=viewport`, `scale_mode=integer` e `aspect=keep`: a imagem de 640x360 só cresce em múltiplos inteiros (pixel art nítida, nunca esticada) e o que sobra vira barra preta (cor de fundo preta). Em tela 16:9 de 1920x1080 a escala é 3x sem barras; em monitores de outra proporção (16:10, ultrawide) ou de resolução que não é múltipla (ex.: 1600x900, 2x com faixa grande) aparecem barras.

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
├── data/                    # balanceamento em .tres (balance/, dino/, weapons/)
├── src/
│   ├── core/                # enums, catálogo de itens
│   │   ├── Enums.gd
│   │   ├── ItemDef.gd       # definição de um item (id, nome, pilha, cor)
│   │   ├── DinoLevelRules.gd  # fórmulas de nível (Resource)
│   │   ├── DinoBaseStats.gd   # atributos base do dino (precursor do SpeciesDef)
│   │   ├── TamingRules.gd     # regras da Eficiência
│   │   ├── TorporBandRules.gd # faixas de torpor
│   │   ├── PlayerRules.gd     # fome, recarga de comida, ofego
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
│       ├── Main.gd          # liga o mundo à UI
│       ├── Main.tscn
│       ├── Terrain.tscn     # mapa em TileMapLayer (gerado por tools/gerar_mundo.gd)
│       └── world_tiles.tres # TileSet (chão, natureza, colisão no tronco)
└── tests/
    ├── run_tests.gd
    ├── dino_level_tests.gd  # nível, Eficiência, combate, faixas, apresentação
    ├── dino_review_tests.gd # regras de save e achados das revisões
    ├── hud_hotbar_tests.gd  # HUD, atalhos 1 a 9, ofegar, dano recebido
    ├── inventory_model_tests.gd # PRO-15 e PRO-22: pilha/individual, save v2, migração, vagas de equipamento
    ├── menu_tests.gd            # apresentação, navegação, configurações, créditos e pausa
    └── saveable_table.gd
```

### Componentes

**`EquipmentComponent`** (PRO-22, GDD 5.20) são as 6 vagas de equipamento (Arma, Capacete, Camisa, Luva, Calça, Bota), definidas em dados (`data/equipment/layout.tres`: `EquipmentLayout` com `EquipmentSlotDef` `id`, `display_name`, `shown` = `slot_visivel`, `hotbar`); cada item equipável declara sua vaga em `ItemDef.slot` (o Bastão: `weapon`; a vaga Arma recebe qualquer item de mão). O equipado SAI da grade e fica na vaga, com `iid` e durabilidade. `equip(iid, vaga)` valida (item existe na grade, vaga existe, `slot` confere; troca devolve o antigo à grade) e `unequip(vaga)` recusa com "full" se a grade não tem posição livre, sem perder item; ambos devolvem "" ou o motivo. Quem pede é o `Player` (`request_equip`, `request_unequip`, recarga 0,3 s, sinal `equip_refused` para o aviso "Inventário cheio"; vaga errada recusa sem mensagem). A tecla do atalho equipa (grade para vaga) e de novo desequipa; o atalho segue pelo `iid` com o item na vaga e a barra mantém o destaque amarelo; roupa não vai ao atalho (`hotbar` da vaga, validado em `HotbarComponent`). Limpar o atalho não tira o item da vaga. Save `{version: 1, slots: {vaga: item}}` (o item inteiro, porque não está mais na grade; o GDD guarda `{vaga: iid}`), `from_dict` devolve bool e recusa o bloco todo se algo é inválido. A tela mostra só a vaga Arma (as 5 de roupa só no M4, quando existir item). Sem desgaste, redução de dano, peso nem arrastar (fora do escopo).

**`HealthComponent`** guarda a vida da entidade. Sinais: `health_changed`, `damaged`, `healed` e `died`.

**`TorporComponent`** é uma barra independente da vida. Acordada, a criatura não mostra barra: só a faixa 0 a 3 (`band`, 25/50/75% com histerese de 3 pontos, `band_changed`). Faixa 2: velocidade x0,85; faixa 3: x0,65, pausa de 0,8 s a cada 4 s (determinística, `pause_phase`) e cooldown x1,5 (`movement_multiplier`, `is_paused`, `attack_cooldown_multiplier`). Valores em `data/balance/torpor_bands.tres`. Quando `current_torpor >= max_torpor`, emite `knocked_out`. A criatura só acorda quando o torpor cai até `wake_ratio * max_torpor`, e então emite `woke_up`. A queda por segundo é configurável separadamente para consciente e inconsciente, e essa segunda taxa define quanto tempo o jogador tem para domesticar.

**`StaminaComponent`** é o fôlego. Gasta enquanto o corpo diz que está correndo e regenera parado. Ao zerar, entra em exaustão e só volta a correr ao recuperar `resume_threshold`. Sinais: `stamina_changed`, `exhausted` e `recovered`. Abaixo de 25% do máximo (`winded_ratio`, dados) está ofegante (`is_winded`, `winded_intensity`): o `PlayerView` toca sopros cada vez mais rápidos e agudos e, ao zerar, um fôlego longo e uma nuvem de suor (GDD 5.7). Parar de correr por ~1,3 s vem do limiar de retomada (20 a 15/s). Golpes e coleta ainda NÃO gastam stamina (aguarda a SHIRO).

**`HotbarComponent`** guarda 9 entradas: um TIPO de item empilhável (`{id}`, mostra a soma das pilhas; sem estoque fica apagado mas atribuído) ou um item individual por `iid` (`{iid}`, segue o item ao movê-lo; some do inventário = apagado, volta quando o mesmo `iid` volta). Conflito GDD 5.2 x 5.9 (atalho por tipo x por slot): comida fica por tipo (a soma é requisito do 5.2) e equipamento por `iid`; atribuir equipamento por tipo é recusado. Save v2 `{version: 2, slots: [{} | {id} | {iid, id?}]}`; o v1 (strings) migra; versão inválida ou maior e `slots` que não é Array são recusados (`from_dict` devolve false e nada muda). `Player.request_use_item(slot)` é a intenção de usar a tecla (leitura do corpo, ações `hotbar_1` a `hotbar_9`): COMIDA é consumida (fome sobe pelos dados de `data/balance/player_rules.tres`, `PlayerRules`: baga 25 do GDD, carne 40 e samambaia 15 placeholders; não gasta com a fome cheia; recarga 0,5 s) e não mexe no equipado, mesmo com dino dormindo ao alcance (decisão do dono; o dino recebe comida só pela tela dele). EQUIPAMENTO é SELECIONADO: a tecla do Bastão o põe em mãos, de novo desequipa (mãos livres), recarga 0,3 s; item em mãos que sai do inventário, ou cujo atalho é limpo, solta as mãos (mudar o atalho de posição não). Comer e equipar têm recargas separadas (0,5 s e 0,3 s). Atalho de item que saiu do inventário fica apagado com o ícone do tipo (dica `id` guardada na entrada `{iid, id}`) e se limpa, com o inventário aberto, apertando a tecla da posição sem item sob o cursor (só vale para atalho órfão). `Player.equipped_iid` e `current_weapon()` (arma do item, ou o Soco `data/weapons/punch.tres`: dano 1, torpor 10, 0,6 s). O Bastão nasce no inventário como individual (durabilidade 120, sem desgaste ainda) na barra, tecla 4, com as mãos livres. Os números do jogador (queda de fome 0,1/s, recargas, limiar de ofego 25%, saciedade) ficam no `.tres`.

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

- **Mapa:** `Terrain.tscn` tem as camadas `Ground` (grama e caminho), `Decor` (tufos, flores, pedras), `Trees` (árvores com colisão só no tronco, ordenadas por `y` com o jogador e o dino) e `Foliage` (folhagem das bordas, à frente do jogador, sem colisão), mais a casa (colisão só na base da parede) e o baú (só decorativo). A área continua fechada pelas 4 bordas da `Main`. O arquivo é gerado por `tools/gerar_mundo.gd` (determinístico): `godot --headless --path game --script ../tools/gerar_mundo.gd`, depois `--import`.
- **Sprites:** o jogador usa `characters/caveman.png` (linhas 0 a 3 andar, 4 ataque, 6 morto); o dino usa `animals/reptile.png` (4 direções x 4 quadros de andar), com o sprite girado 90 graus e o balão "zz" quando dorme. A escolha do quadro é só apresentação (`PlayerView`, `DinoView`); o corpo só expõe `visual`, `velocity` e o sinal `attacked`. O cambaleio é um deslocamento de 1 a 2 px (pixel art não gira em ângulo fracionário).
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
- [ ] Morte, respawn e estado `Dead` da criatura
- [ ] Arte, som e fontes definitivos

### Fase 3: multiplayer e servidor dedicado

- [ ] Servidor headless com autoridade sobre a simulação
- [ ] Sincronização por RPC, com validação de toda entrada do cliente
- [ ] Imagem Docker e guia de auto-hospedagem

## Licença

Código sob a [licença MIT](../LICENSE).
