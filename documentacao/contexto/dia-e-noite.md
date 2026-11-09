# Dia e noite (SOB-03, E9)

## Regra (lógica, testável em headless)

- `DayCycle` (`game/src/core/DayCycle.gd`, `RefCounted`) é função pura do `WorldClock.now()`. O relógio só anda em `_physics_process` da autoridade, então a pausa o para e a fase junto. Nada de `Time` na simulação.
- Ciclo de 12 min (`day_cycle_rules.tres`, `cycle_seconds = 720`): 7 de dia, 1 de entardecer, 3 de noite, 1 de amanhecer, como PARTES do ciclo. O operador muda a duração por `ciclo_dia_s` no `ServerRules` (faixa 60 a 7200); as faixas escalam juntas.
- Faixas meio-abertas, `[início, fim)`: na fronteira exata já vale a faixa nova (420 s entardecer, 480 s noite, 660 s amanhecer, 720 s dia).
- Save: a hora do dia é derivada de `world.time` (já salvo). Não há campo novo. Carregar chama `WorldAuthority.resync_day_phase()` e nunca anuncia a noite (carregar não é evento de jogo).
- Log: `night_started` (entrou na noite) e `day_started` (entrou no dia), via `game_event`, só quando a faixa muda durante o jogo.
- Percepção: x1,5 SÓ à noite e SÓ do Agressivo (`DinoBaseStats.perception_px`). A autoridade decide (`WorldAuthority.perception_scale()`); o dino a recebe por `perception_scale_source` e a predação por `_perception`. Velocidade e desistência da perseguição não mudam.

## Núcleo seguro (B6 da E3) à noite

A margem do `SafeCore` (8 tiles) é MENOR que a percepção noturna do Utahraptor (8 x 1,5 = 12 tiles). A garantia "o caçador nunca entra" continua valendo, porque ela não vem da margem: alvo dentro do núcleo é vedado (`SafeCore.contains`, em `PredationSystem._barred`, `DinoStateMachine.target_barred` e `DinoZone`). Na vertical a elipse noturna (12 / 1,6 = 7,5 tiles) ainda cabe nos 8. Na horizontal o caçador na borda "vê" 4 tiles para dentro do núcleo, mas não pode mirar nem entrar. O teste B6 da E3 (`margem >= perception_tiles`) segue de dia; `DayNightThreatTests` cobre a noite. Se o dono quiser a letra da E3 também à noite, a margem teria de subir a 12 tiles, o que corta a ronda de U1 (mexe em dado de mapa).

## Visual: `CanvasModulate` + `PointLight2D` (decisão)

`DayNightView` (`game/src/ui/DayNightView.gd`, `Node`, filha da `Main`). Motivos: o `CanvasModulate` só tinge o canvas em que está, e o HUD vive no `CanvasLayer` `UI` (outro canvas), então a tinta não o atinge por construção; shader de tela precisaria deixar o HUD de fora por truque; a luz do jogador sai de graça (pixel = cor x (tinta + luz); com luz de cor `1 - tinta` o centro devolve a cor original). Tinta por faixa em dado, com piso `min_tint_channel` (0,35 por canal): nunca preto, sprite de 16 px segue legível. A troca entre faixas é suave (`blend_seconds`, nos últimos segundos de cada faixa). Luz de 5 tiles (`light_radius_tiles`). A luz da Fogueira (4 tiles) entra na E12 com o mesmo desenho. Não existe névoa de tela (removida em 08/11); não voltar.

Estrutural testado: tinta e luz fora de qualquer `CanvasLayer`; a HUD em outro canvas.

## HUD

`PlayerHud` mostra o rótulo da faixa ("Dia", "Entardecer", "Noite", "Amanhecer") no canto de cima à direita, abaixo do "Salvando". Texto em `GameMessages.PHASE_LABELS`.

## Música

`MusicPlayer.follow_world(clock, cycle)` usa a noite do `DayCycle` quando recebe o ciclo (o jogo recebe), para música, tinta e percepção virarem juntas. `MusicRules.is_night` só vale sem ciclo.

## O que não se prova em headless

Cor, brilho, legibilidade dos sprites e a suavidade da transição são olho humano (`godot --path game`).
