# ADR-006: Relógio do mundo (`world.time`)

**Data**: 2026-11-07
**Status**: Aceito (07/11/2026; decisões 1 a 3 do bloco A do dono; trecho do trabalho longe corrigido antes do aceite)
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

## Decisão

Opção 3.

- **`world.time`**: número (segundos de jogo, `float`) no `world` do save. Começa em 0 no mundo novo. Só a autoridade o avança, um lugar só (`Main` no host; o servidor dedicado no M3), somando o `delta` de `_physics_process`. Pausa e jogo fechado não contam. Ninguém mais escreve nele; os sistemas recebem o valor (ou um leitor) injetado.
- **Prazo é instante absoluto, nunca contador local.** Regra de qual instante guardar:
  - duração decidida no evento (volta do nó com `respawn_recurso` aplicado, sorteio de tempo): guarda **quando vence** (`due_at`). Mudar a regra do servidor depois não move prazos já marcados.
  - idade que a regra lê (carcaça, crescimento, ovo): guarda **quando começou** (`born_at`); a regra compara `time - born_at` com o número da `Resource`. Mudar a `.tres` vale também para o que já existe.
- **Dormente ou descarregado é resolvido por fórmula ao voltar**, sem simular os segundos perdidos: o sistema que acorda calcula o estado a partir do instante salvo e do `world.time` atual (nó: cheio se `time >= due_at`; carcaça: some se passou de `fresh_seconds`; crescimento: estágio por idade). O trabalho do dino **não** entra nesta regra: ele consome estoque de nós reais e segue a seção "Trabalho do dino" abaixo. Prazo que só compara instantes não precisa de `_physics_process`: o nó esgotado deixa de processar por quadro.
- **`from_dict` não avança o tempo.** Carregar restaura `world.time` antes das entidades; cada `from_dict` só lê instantes e saneia (`SafeRead`: `due_at` limitado a `time + duração máxima`, `born_at` não maior que `time`). Quem resolve o que venceu é o primeiro tick depois da carga, pelo caminho normal, para não disparar evento de jogo dentro do `from_dict` (contrato de `docs/contexto/save.md`).
- **Fora do escopo**: fome e torpor do selvagem distante continuam congelados como hoje (não há efeito visível e não há prazo); ciclo de dia e noite (SOB-03) lerá o mesmo relógio quando existir, sem decisão aqui.

## Trabalho do dino (ordem `WORK`, ADR-005)

A primeira versão deste ADR resolvia o trabalho longe com `floor((time - since) / período)` limitado pela capacidade do alforje. Isso não tira do estoque do nó: um dino numa árvore só renderia sem limite até encher o alforje, contra a regra de conservação decidida em 07/11. Substituído, antes do aceite, por:

- **Invariante de conservação** (regra verificável): para todo nó N e todo intervalo [t0, t1] do `world.time`, a soma do que todos os atores tiram de N (jogadores, dinos perto e dinos longe) é no máximo o estoque de N em t0 mais o rendimento cheio de N vezes o número de voltas de N cujo `due_at` caiu em [t0, t1]; todo item que entra num alforje de trabalho sai de um nó. Hoje o nó entrega o rendimento inteiro numa colheita e esgota (`ResourceNodeComponent.harvest`, `ResourceNodeComponent.gd:107-117`), então "estoque" é 0 ou 1 colheita.
- **Sem fórmula fechada de produção.** O trabalho é um **laço de eventos sobre nós reais** (`WorkSim`, puro, em `game/src/core/`): `advance(order, now)` processa, em ordem de instante, os eventos entre o último instante resolvido e `now` (colheita vence em `next_at`; nó volta em `due_at`). Na colheita: se o nó atual está disponível e o rendimento inteiro cabe no alforje, tira do nó pelo mesmo caminho da colheita do jogador (o nó esgota e marca `due_at`) e agenda `next_at += período`; senão escolhe o nó disponível mais próximo do ponto, no raio do `WorkProfile`, empate por id estável (ADR-007); sem nó, espera o menor `due_at` do raio; alforje sem espaço para o rendimento inteiro, para com estado "carga cheia".
- **Um código só, perto e longe.** A autoridade chama `advance` a cada tick com o `world.time` atual para toda ordem ativa (no máximo `dino_trabalhando_max` por jogador, contadas varrendo); tick sem evento vencido não faz nada. O nó é um estado só, na autoridade, então jogador e dino nunca contam o mesmo estoque duas vezes. O corpo do dino perto (andar até o nó, animação) é apresentação da Conduta; quem move itens é o evento. O tempo de andar entre nós está dentro do período do `WorkProfile`, não é simulado à parte.
- **Custo e catch-up.** O número de iterações de um `advance` é limitado pelos eventos reais no intervalo (no máximo a capacidade do alforje dividida pelo rendimento, mais as voltas de nó no raio), nunca pelo tempo decorrido. O catch-up de quem ficou sem tick (chunk descarregado, M9) é a mesma chamada com o intervalo maior. Com o jogo fechado em single-player o relógio para e não há o que recuperar.
- **Volta do nó com o lugar ocupado.** Hoje a volta espera o lugar livre (`can_return`, `ResourceNodeComponent.gd:54-55`). O laço trata o nó como indisponível até a autoridade efetivá-lo no tick normal; o invariante continua valendo porque volta atrasada só reduz o que se tira.
- **Testes obrigatórios** (`LEVI`): idempotência `advance(0, T) == advance(0, a) + advance(a, T)` para qualquer `a`; o invariante verificado a cada passo num livro-razão com semente (3 dinos e 1 jogador no mesmo bosque, alternando perto e longe); mesmo cenário perto e longe com o mesmo resultado.

## Migração (dentro do save v5 do ADR-007)

Função pura em `SaveMigrations`, sem ler `Resource` (ADR-002):

- `world.time = 0`.
- nó: `respawn_left = r` vira `due_at = r`.
- carcaça: `age = a` vira `born_at = -a`.

Fixture `v5.json` e teste de que a carcaça e o nó de um `v4.json` vencem no mesmo segundo de jogo antes e depois da migração.

## Consequências

- **Positivas**: um "agora" único e reprodutível, testável sem quadros (o teste põe `world.time` e confere); ovo, crescimento e trabalho longe nascem como dado e fórmula, não como contador novo; prazos dormentes custam zero por quadro; o servidor dedicado do M3 herda o mesmo relógio, rodando sem parar com os jogadores offline.
- **Negativas / trade-offs**: dois sistemas e seus testes mudam (nó e carcaça); todo sistema novo com prazo precisa seguir a regra (revisão de código, e vale um teste de arquitetura que reprove `-= delta` em campo salvo, a avaliar); `float` acumulado perde precisão só depois de séculos de jogo (desprezível); em single-player o mundo não anda com o jogo fechado, e isso é decisão de design, não limite técnico.
- **Riscos**: sistema que desconta `delta` e também lê `world.time` conta o tempo duas vezes (a regra acima evita); o relógio avançado fora da autoridade reabre trapaça no M3 (só o host escreve); resolver por fórmula pede que cada regra seja expressa como função do tempo decorrido, o que a ordem "Trabalhar aqui" respeita pelo laço de eventos da seção "Trabalho do dino" (fórmula fechada `floor(dt / período)` é proibida para produção).
- **Revisitar se**: o dono quiser que o mundo single-player ande com o jogo fechado (aí entra um teto de recuperação por fórmula, não relógio de parede na simulação); o M3 precisar sincronizar o relógio com o cliente para predição.

## Decisões do dono (07/11/2026, bloco A)

1. **Aprovado**: relógio em segundos de jogo, parado na pausa e com o jogo fechado.
2. **Aprovado**: prazo decidido no evento guarda quando vence (`due_at`); idade lida da regra guarda quando começou (`born_at`).
3. **Aprovado**: fome e torpor do selvagem distante seguem congelados.

Junto com a decisão 6 (ADR-007), o dono pediu a correção do trabalho longe antes do aceite; a recomendação aprovada na consolidação foi o laço de eventos, com o invariante de conservação como teste (seção "Trabalho do dino").
