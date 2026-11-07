# ADR-006: Relógio do mundo (`world.time`)

**Data**: 2026-11-07
**Status**: Proposto
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 3 do roteiro da auditoria geral de 07/11)

## Contexto

A auditoria geral de 07/11 (`docs/design/corte-v02/decisoes-0611-0711.md`) pôs o relógio do mundo entre os pré-requisitos de etapa nova. O que vem depois (ovo e reprodução no M7, crescimento do filhote, ordem "Trabalhar aqui" com o dino longe do jogador, servidor dedicado no M3) depende de prazos que sobrevivem ao save e a trechos do mundo que não estão sendo simulados.

Fatos do código hoje (conferidos em 07/11):

- **Não existe tempo do mundo.** O envelope do save tem `saved_at` (data de parede, só metadado, `SaveScheduler.gd:122`), nenhum relógio de jogo.
- **Cada prazo é um contador local que desconta `delta`:**
  - nó esgotado: `ResourceNodeComponent.respawn_left -= delta` (`ResourceNodeComponent.gd:46-47`); vai ao save como o que falta (`respawn_left`, linha 120). Só o esgotado liga `_physics_process` (linha 35).
  - carcaça: `item["age"] += delta` (`CarcassField.gd:36`); vai ao save como `age` e some aos `fresh_seconds` (600 s).
  - autosave: `SaveScheduler._elapsed`, que zera a cada save (é intervalo, não prazo do mundo).
- **O dino fora da zona ativa para.** `DinoZone._apply` desliga o `process_mode` de quem não está ATIVO (`DinoZone.gd:131`): distante e dormente não contam fome nem nada. Domado, com dono, com torpor ou doma em andamento ficam fixados como ativos (`is_pinned`, linhas 120-126).
- **Relógio de parede é proibido na simulação** e verificado em CI (`tools/checks.d/10-arquitetura.sh`, `rule_simulation_has_no_wall_clock`).

O problema dos contadores locais: cada sistema guarda "quanto falta" do seu jeito, só anda quando o nó está processando, e não há um "agora" comum para resolver o que ficou parado. Com um sistema por vez isso funciona; com ovo, crescimento e trabalho longe, vira um contador por regra e um jeito diferente de acordar para cada um.

## Opções consideradas

1. **Timers locais por nó (o que existe)**: cada componente desconta `delta` e salva o restante. Prós: simples, já testado, nada a migrar. Contras: só conta enquanto processa; o que está dormente ou fora da zona ativa congela ou precisa ser processado (custo por quadro com centenas de prazos); não há como resolver "quanto tempo passou" ao acordar; cada sistema novo reinventa o contador.
2. **Tempo de parede** (data do sistema): Prós: conta com o jogo fechado, natural para "o ovo choca amanhã". Contras: proibido pela regra de arquitetura e pelo ADR-001 (o servidor e o teste precisam ser reprodutíveis); o jogador adianta o relógio do sistema e trapaceia; em single-player, fechar o jogo faria o mundo andar sem ninguém para defender o acampamento; teste dependeria de dormir ou de falsificar o relógio.
3. **Relógio do mundo em segundos de jogo, salvo no save, com prazos absolutos**: um `world.time` que só a autoridade avança, em `_physics_process`, e todo prazo é um instante nesse relógio. Contras: migração dos dois prazos que existem; uma regra nova a manter em todos os sistemas.

## Decisão (recomendada)

Opção 3.

- **`world.time`**: número (segundos de jogo, `float`) no `world` do save. Começa em 0 no mundo novo. Só a autoridade o avança, um lugar só (`Main` no host; o servidor dedicado no M3), somando o `delta` de `_physics_process`. Pausa e jogo fechado não contam. Ninguém mais escreve nele; os sistemas recebem o valor (ou um leitor) injetado.
- **Prazo é instante absoluto, nunca contador local.** Regra de qual instante guardar:
  - duração decidida no evento (volta do nó com `respawn_recurso` aplicado, sorteio de tempo): guarda **quando vence** (`due_at`). Mudar a regra do servidor depois não move prazos já marcados.
  - idade que a regra lê (carcaça, crescimento, ovo): guarda **quando começou** (`born_at`); a regra compara `time - born_at` com o número da `Resource`. Mudar a `.tres` vale também para o que já existe.
- **Dormente ou descarregado é resolvido por fórmula ao voltar**, sem simular os segundos perdidos: o sistema que acorda calcula o estado a partir do instante salvo e do `world.time` atual (nó: cheio se `time >= due_at`; carcaça: some se passou de `fresh_seconds`; crescimento: estágio por idade; trabalho longe: unidades produzidas por `floor((time - since) / período)`, limitadas pela capacidade). Prazo que só compara instantes não precisa de `_physics_process`: o nó esgotado deixa de processar por quadro.
- **`from_dict` não avança o tempo.** Carregar restaura `world.time` antes das entidades; cada `from_dict` só lê instantes e saneia (`SafeRead`: `due_at` limitado a `time + duração máxima`, `born_at` não maior que `time`). Quem resolve o que venceu é o primeiro tick depois da carga, pelo caminho normal, para não disparar evento de jogo dentro do `from_dict` (contrato de `docs/contexto/save.md`).
- **Fora do escopo**: fome e torpor do selvagem distante continuam congelados como hoje (não há efeito visível e não há prazo); ciclo de dia e noite (SOB-03) lerá o mesmo relógio quando existir, sem decisão aqui.

## Migração (dentro do save v5 do ADR-007)

Função pura em `SaveMigrations`, sem ler `Resource` (ADR-002):

- `world.time = 0`.
- nó: `respawn_left = r` vira `due_at = r`.
- carcaça: `age = a` vira `born_at = -a`.

Fixture `v5.json` e teste de que a carcaça e o nó de um `v4.json` vencem no mesmo segundo de jogo antes e depois da migração.

## Consequências

- **Positivas**: um "agora" único e reprodutível, testável sem quadros (o teste põe `world.time` e confere); ovo, crescimento e trabalho longe nascem como dado e fórmula, não como contador novo; prazos dormentes custam zero por quadro; o servidor dedicado do M3 herda o mesmo relógio, rodando sem parar com os jogadores offline.
- **Negativas / trade-offs**: dois sistemas e seus testes mudam (nó e carcaça); todo sistema novo com prazo precisa seguir a regra (revisão de código, e vale um teste de arquitetura que reprove `-= delta` em campo salvo, a avaliar); `float` acumulado perde precisão só depois de séculos de jogo (desprezível); em single-player o mundo não anda com o jogo fechado, e isso é decisão de design, não limite técnico.
- **Riscos**: sistema que desconta `delta` e também lê `world.time` conta o tempo duas vezes (a regra acima evita); o relógio avançado fora da autoridade reabre trapaça no M3 (só o host escreve); resolver por fórmula pede que cada regra seja expressa como função do tempo decorrido, o que a ordem "Trabalhar aqui" precisa respeitar desde o primeiro desenho.
- **Revisitar se**: o dono quiser que o mundo single-player ande com o jogo fechado (aí entra um teto de recuperação por fórmula, não relógio de parede na simulação); o M3 precisar sincronizar o relógio com o cliente para predição.

## Decisões para o dono

1. Aprovar o relógio em segundos de jogo, parado com o jogo fechado e na pausa.
2. Aprovar a regra `due_at` (duração fixa no evento) e `born_at` (idade lida da regra).
3. Confirmar que fome e torpor do selvagem distante seguem congelados.
