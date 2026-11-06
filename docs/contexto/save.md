# Save, morte e respawn

**Leia quando:** for criar ou alterar algo que persiste (`to_dict`/`from_dict`), formato de save, migração, gatilho de salvamento, morte ou respawn.

Fontes de verdade: `docs/adr/ADR-002-save.md` (formato, escrita atômica, migração), `game/README.md` (seções Save e Saves), `docs/design/GDD.md` seção 12 (gatilhos, respawn, Saco de dormir e Cama).

## Contrato de `to_dict` / `from_dict`

- Todo objeto salvável expõe `to_dict()` e `from_dict()` com dados compatíveis com JSON e **roundtrip testado**. Todo script com `to_dict` em `game/src/` precisa constar em `game/tests/saveable_table.gd`; o teste de arquitetura reprova se faltar.
- **`from_dict` nunca aborta no meio.** Leia cada campo por `SafeRead` (confere tipo, rejeita não finito, limita intervalo); campo inválido cai no padrão.
- **Quem pode recusar o dado devolve `bool`:** `true` = aplicado; `false` = recusado e **nada mudou** (nunca carga parcial). Quem só saneia pode ser `void`.
- `from_dict` não dispara eventos de jogo (`died`, `knocked_out`...). Restaure torpor e domesticação antes da máquina de estados; o torpor é a fonte da verdade.
- Enums são salvos pelo nome. Ids de item e espécie nunca mudam; remover um sem alias perde o item no save.

## Formato

- **Só JSON** em dado externo (save, configuração). Proibidos: `ConfigFile`, `load` de caminho em `user://`, `bytes_to_var_with_objects`, `str_to_var`, `dict_to_inst`, `get_var(true)` (ADR-002; verificado em `tools/checks.d/10-arquitetura.sh`).
- Um mundo em `user://saves/main/world.json` com envelope `{format_version, game_version, saved_at, world, players, entities}`. O `SaveManager` grava de forma atômica (`.tmp`, relê e valida; **só um principal válido vira `.bak`**, e o `.bak` velho só é apagado se for válido) e recusa versão maior que a do jogo. Arquivo de versão futura ou danificado, no principal ou no `.bak`, vai para `world.json.rejected` (`.rejected.1`, ...), fora do rodízio, e **nunca é apagado nem sobrescrito**.
- **Continuar que falha** (save recusado pelo jogo, ilegível ou de versão futura) volta ao título com o motivo (`GameSession.notice`): sem jogo novo e sem gravar nada; o arquivo fica idêntico.
- **Mudou o formato?** Suba a versão, escreva a migração como função pura em `SaveMigrations` e **adicione uma fixture** em `game/tests/fixtures/saves/`; fixture antiga nunca é removida.

## Como o save é disparado

Quem decide é o `SaveScheduler` (`game/src/world/SaveScheduler.gd`; números em `game/data/balance/save_rules.tres`). Não grave direto com o `SaveManager` a partir de gameplay: peça por `request(reason)` ou `save_now(reason)`.

- Gatilhos: a cada 300 s de jogo (relógio que zera a cada save de qualquer origem), morte do jogador, morte de dino domado, voltar ao menu e fechar a janela. A pausa não tem Salvar: o jogador não escolhe quando salvar. A Cama (`SaveManager.Reason.BED`) será o único save por ação do jogador e ainda não existe. Escolher onde renascer salva (`Reason.RESPAWN`).
- **Morto fica morto no arquivo.** O jogador morto é gravado (`life: dead_pending_choice`, vida 0) e carregado morto: o Continuar reabre a tela de morte; só a escolha de respawn (`Main.request_respawn`) o revive. Nunca reviva no `WorldSnapshot.restore`.
- **Respawn dentro do prazo de 10 s:** morte e escolha de região a menos de 10 s do save anterior geram UM save só, o de vivo (o save da morte espera o prazo e leva o estado de então); o arquivo nunca vê o morto. Com a morte já gravada, o respawn também espera o prazo e o arquivo segue como morto até lá. Quem fecha o jogo nesse intervalo salva na hora (`EXIT_MENU`/`QUIT` ignoram o prazo).
- **Formato v2** (`world.resource_nodes`, `world.respawn_count`): migração `SaveMigrations.v1_to_v2`, fixture `v2.json`.
- **Formato v3** (`entities[].state.owner_player_id`, `feeder_player_id`, `state_machine.order`): o dono do domado (o `player_id` do personagem, ADR-003; sobrevive com o dono offline), quem alimentou por último e a ordem Seguir/Ficar (pelo nome do enum). Migração `SaveMigrations.v2_to_v3`: domado de v2 vira do primeiro jogador do save (dono e quem alimentou), ordem STAY; selvagem com domesticação em andamento (progresso ou item na criatura) ganha o primeiro jogador só como quem alimentou, para não terminar domado sem dono. Fixture `v3.json`. Só o domesticado guarda dono e ordem; selvagem com esses campos no arquivo os perde. Na carga, domado sem dono válido (vazio ou `player_id` que não está no save) vira do primeiro jogador do save. `world.next_entity_id` leva o contador real da autoridade.
- Gatilhos no mesmo quadro viram um save só; morte muito próxima do último save espera o prazo, nunca é descartada.
- **O jogo nunca pergunta antes de salvar** e falha de escrita não derruba o jogo nem apaga o arquivo anterior. O pedido que falhou **não se perde**: é refeito depois de `retry_seconds_after_failure` (10 s), sem esperar o intervalo; o aviso na HUD sai só na primeira falha da sequência (ou se a mensagem mudar) e a fila não cresce (um motivo entra uma vez).
- Regras de morte, respawn por região, Saco e Cama, e o que ainda é proposta: `docs/design/GDD.md` seção 12. Em caso de dúvida entre o código e o GDD, o código mostra o que existe e o GDD, o que foi decidido; registre a diferença no relatório.
