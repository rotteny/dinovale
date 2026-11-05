# Ração: comida de domesticação (anexo do GDD)

> **Decisões finais do dono (06/11, GDD 5.4, 5.16 e 5.19): leia antes do resto.** **Rifle, Dardo, arma de fogo, pólvora, fósforo e sílex: adiados sem marco.** Onde este anexo diz **Dardo de sono**, vale: na v0.2 o torpor forçado vem da **fruta-do-sono** (30) e do **preparado** (60); no **M4** entra a **flecha de sono** (75: 15 + 12/s por 5 s, Arco, 10 tiles, -2 E por dose em dormindo). As colunas "Dardos" das tabelas 1.3 e 4.4 e o `DART=50` de `racao_sim.py` ficam como **histórico de conta**. **Aceitas:** teto de evolução do dino = 2x o nível final, máximo `dino_nivel_max` 50 no MVP (75 na 1.0), servidor só trava; Triceratops L18 a L24; Dodo no início do M2; Pilão e Preparado na v0.2; sem Bastão reforçado. A regra de produção (fibra, madeira e pedra à mão; metal e engenharia na Bancada) **não muda a Ração**: ela segue na Bancada.

> **Decisões do dono aceitas (06/11):** pontos do dino em Vida, Dano e Peso; níveis de bônus da Eficiência vêm aplicados; Listro como Covarde e Clareira-brasa fora do M4; Utahraptor solitário e primeiro golpe provoca; doses somam até 3 e a dose forçada (flecha de sono, M4) em dormindo custa 2 de Eficiência; carne não estraga no inventário (carne podre de carcaça velha ou Carniça); sem armas de fogo e sem pólvora; sacolinha com a comida do dino morto; Bastão reforçado **cortado (06/11)**. HUD sem barra de stamina e sem durabilidade (GDD 5.7). **Receitas por Saber** em `receitas.md`.
>
> **Tempo de domar recalibrado (06/11, GDD 5.14):** as tabelas de tempo e refeições abaixo (60 s, 105 s, 0,015 por nível) estão **desatualizadas**; valem `tempo_sim.py` e a seção 5.14: Paquicéfalo 1,3 a 2,0 min, Utahraptor 1,5 a 2,3, Parassaurolofo 1,1 a 1,9, Triceratops 4,8 a 7,0 (Ração C), taxa `domar_velocidade` 1,0.
>
> **Tetos de nível (06/11, GDD 5.16):** dino nasce com nível sorteado com poucos altos (faixas por espécie, teto ao nascer 30); teto de evolução = 2x o nível de doma (recomendo sobre o final, com bônus de Eficiência), o teto do servidor vence e **só trava, sem reduzir** (`dino_nivel_max` 50 no MVP); **aceito pelo dono**; `jogador_nivel_max` 20; XP trava no teto; save acima do teto só trava.
>
> **Comida e fome do jogador (06/11, GDD 5.10):** carne crua +25 de fome, **cozida +35 e cura 10**, podre +5 com -6 de vida; saciedade (> 70) regenera 0,5/s; queda 0,2/s; fome 0 sobe torpor +2/s, desmaio 8 s com 1,5/s. **A Ração Rubra e o domar usam carne crua**, a cozida é só do jogador. **Durabilidade e validade** (5.9): a Ração **não vence**; carne vence em 30 min (crua) e 90 (cozida); `racao.md` 2.4 ("sem validade") perde para a carne. **Armadura** (5.11): 3 materiais em 5 peças com vagas de equipamento (5.20), dano mínimo 1. **Pendentes de decisão (dono): fome, morte por fome, validade, durabilidade, roupas e Listro; Ração nunca é consumida pelo jogador (decidido); preparado, aberto; dardo, à parte (munição de rifle).**
>
> **Rifle e v0.2 (06/11, GDD 5.4 e 5.15), SUPERADO pela decisão final:** o Rifle de dardos e o Dardo saíram **sem marco**; a coluna `dardos_min` e o `DART=50` de `racao_sim.py` valem só como histórico. Domar na v0.2 mantém dormindo com **Bastão** ou **fruta-do-sono**; Ração A zera o extra nos pequenos. Aceitas: fome, validade, durabilidade, roupas, fatores por espécie, dreno 0,15, Listro no M4. Preparado: o jogador não consome, só craftar flecha de sono (M4).

> **Armas, torpor contínuo e sono (06/11, GDD 5.4 e 5.5):** a **flecha de sono (M4)** vale **75 de torpor** (15 imediato + 12/s por 5 s), teto de 3 efeitos ativos, 10 tiles; em dormindo custa **-2 E por dose**, o torpor contínuo **não é ataque**. **Fruta-do-sono** (30) e **preparado de sono** (60, 3 frutas + 1 carne podre rendem 3) forçados pelo dono em dino dormindo **não custam Eficiência**; a **queda de 0,3/s e o dreno por refeição continuam**, e é isso que mantém o preço da Ração. A regra "dardo é a manutenção barata" (V6) fica revista: fruta e preparado a substituem. **Carne podre:** o nó de Carniça saiu; ela vem da carcaça velha e da pilha de carne que vence (GDD 5.5 e 5.9) e **não vence**. Dardos mínimos das tabelas 1.3 **não mudam** com a dose de 50 (`racao_sim.py tabela`, sem diferença).

> **Camada 1 de corte (06/11, GDD 5.3):** fora da 0.2: Lança, Gallimimus, Ração S e Mel, Temperamento. A escada da 0.2 é **Baga, C, B, A**; S e S+ ficam como futuro (S+ no M4). As tabelas S continuam abaixo por referência. A Eficiência real na 0.2 chega a 78 a 92% (A, caso bom), não a 100%. A conta em `nivel_sim.py eficiencia` e `pontos_sim.py` (pontos enxutos: jogador 20 níveis, dino até 2x o nível final com máximo 50, Vida, Dano e Peso) está em GDD 5.1 e 5.3.


Status: rascunho de design, 05/11/2026. Autora: `SHIRO`. Anexo de `docs/design/GDD.md` (a fonte da verdade é o GDD; em conflito, vale o GDD). Todos os nomes são provisórios e originais.

> **Revisão de 05/11 (decisões do dono): ler a seção 10 primeiro.** Nível e Eficiência passam a existir. O **Dardo de sono fica** (R6 abaixo está substituída; **SUPERADO em 06/11: Dardo adiado sem marco, ver o aviso do topo**): atacar o dormindo causa dano e derruba Eficiência, então o jeito barato de manter o torpor sem bater é o dardo (+40 torpor, sem dano, -2 E). Regras definitivas do dono sobre ataques ao dormindo estão na seção 11. O **Afeto inicial** deixa de vir de tabela por qualidade e passa a valer `round(Eficiência/5)`. O S+ ganha papel qualitativo (preserva Eficiência). As seções 1 a 9 seguem como base de conta; onde a seção 10 diverge, vale a 10.

Convenção: **[calculado]** = saiu de conta ou simulação; **[jogar]** = só playtest responde; **[premissa]** = número assumido que a simulação usa.

## 0. Valores reais de hoje (lidos do código)

| Item | Valor | Onde |
|---|---|---|
| Torpor máximo | 100 | `TorporComponent.max_torpor` |
| Torpor por golpe | 40, cooldown 0,35 s | `Player.attack_torpor`, `attack_cooldown` |
| Queda acordado / inconsciente | 5/s / 1/s | `TorporComponent` |
| `wake_ratio` | 0 (acorda em 0) | `TorporComponent` |
| Refeição | 20% a cada 5 s, comida ideal `berry` | `TamingComponent` |
| Domar hoje | 5 refeições x 5 s = **25 s**, janela de **100 s** | calculado |

Dois achados na conta de hoje, que motivam o desenho:

1. **A janela não pressiona.** 25 s de domar em 100 s de janela = 25%. Nunca falha por torpor.
2. **A janela é infinita.** `Dino.apply_torpor` aceita golpe em dino já inconsciente, e o torpor volta a 100 em 3 golpes (1,05 s). Enquanto o golpe for grátis, "acabou o torpor" não existe como risco. Qualquer sistema de qualidade fica sem efeito sobre a janela se isso não mudar.

## 1. O que cada qualidade muda

### 1.1 Regras (frases testáveis)

- R1. Ração tem **qualidade** (C, B, A, S, S+) e **perfil** (Verde e Rubra no MVP; Mista no M4). O perfil diz quem come; a qualidade diz quão bem.
- R2. Cada espécie tem um perfil preferido (come 100%), um secundário (come com progresso por refeição pela metade, afeto inicial 0) e rejeita os demais (nunca consome).
- R3. A qualidade define: refeições necessárias, intervalo entre refeições, **agitação** (torpor perdido a cada refeição; digerir acorda um pouco) e **afeto inicial** do dino domado.
- R4. Refeições necessárias = `ceil(refeições_base x dificuldade_da_espécie)`; progresso por refeição = 100 / refeições.
- R5. Baga e carne crua são **comida simples**: só servem para espécies marcadas `aceita_crua`, são o grau abaixo do C (mais lenta, mais agitação, afeto 0). Comida simples continua alimentando dino domado (fome).
- R6. **[substituída pelas seções 10 e 11]** Golpe em dino inconsciente soma torpor, mas causa dano e derruba Eficiência; o **Dardo de sono** (+40 torpor, sem dano, -2 E) é o caminho barato.
- R7. Dino que acorda antes de 100%: progresso zera, ração já consumida está perdida, ração que sobrou fica no inventário (regra atual do código, mantida).

### 1.2 Tabela de níveis (dificuldade 1,0)

| Nível | Refeições | Intervalo | Tempo | Agitação/refeição | Afeto inicial | Coleta por ração* |
|---|---|---|---|---|---|---|
| Baga (crua) | 10 | 6 s | 60 s | 5 | 0 | 3 s |
| C | 8 | 5 s | 40 s | 3 | 0 | 7 s |
| B | 6 | 5 s | 30 s | 2 | 5 | 10 s |
| A | 5 | 4 s | 20 s | 1,5 | 10 | 15 s |
| S | 4 | 4 s | 16 s | 1 | 20 | 23 s |
| S+ | 3 | 4 s | 12 s | 0,5 | 35 | 48 s |

\* [premissa] ver seção 2.3. Tempo = refeições x intervalo.

### 1.3 Janela de torpor: a conta

Torpor gasto para domar = `tempo x queda/s + refeições x agitação`. Se passar do torpor máximo, precisa de dardo. Valores [calculado] com `racao_sim.py tabela`:

Paquicéfalo (torpor 100, queda 1,0/s, janela 100 s):

| Nível | Refeições | Tempo | Torpor gasto | % da janela | Dardos mínimos |
|---|---|---|---|---|---|
| Baga | 10 | 60 s | 110 | **110%** | 1 |
| C | 8 | 40 s | 64 | 64% | 0 |
| B | 6 | 30 s | 42 | 42% | 0 |
| A | 5 | 20 s | 28 | 28% | 0 |
| S | 4 | 16 s | 20 | 20% | 0 |
| S+ | 3 | 12 s | 14 | 14% | 0 |

Utahraptor (dificuldade 1,5, torpor 120, queda 1,2/s, janela 100 s):

| Nível | Refeições | Tempo | Torpor gasto | % | Dardos |
|---|---|---|---|---|---|
| C | 12 | 60 s | 108 | **90%** | 0 (margem de 12) |
| B | 9 | 45 s | 72 | 60% | 0 |
| A | 8 | 32 s | 50 | 42% | 0 |
| S | 6 | 24 s | 35 | 29% | 0 |
| S+ | 5 | 20 s | 26 | 22% | 0 |

Parassaurolofo (dificuldade 1,5, torpor 140, queda 1,3/s, janela 108 s):

| Nível | Refeições | Tempo | Torpor gasto | % | Dardos |
|---|---|---|---|---|---|
| Baga | 15 | 90 s | 192 | **137%** | 2 |
| C | 12 | 60 s | 114 | 81% | 0 |
| B | 9 | 45 s | 76 | 55% | 0 |
| A | 8 | 32 s | 54 | 38% | 0 |
| S | 6 | 24 s | 37 | 27% | 0 |
| S+ | 5 | 20 s | 28 | 20% | 0 |

Triceratops (dificuldade 2,0, torpor 160, queda 1,5/s, janela 107 s):

| Nível | Refeições | Tempo | Torpor gasto | % | Dardos |
|---|---|---|---|---|---|
| C | 16 | 80 s | 168 | **105%** | 1 |
| B | 12 | 60 s | 114 | 71% | 0 |
| A | 10 | 40 s | 75 | 47% | 0 |
| S | 8 | 32 s | 56 | 35% | 0 |
| S+ | 6 | 24 s | 39 | 24% | 0 |

Leitura: a pressão real da janela só existe nos níveis baixos (C e comida crua), onde o jogador precisa de um dardo no meio da vigília ou fracassa. Nos níveis altos a janela deixa de ser limite e o limite passa a ser o perigo externo (seção 4). Isso é intencional: qualidade compra folga.

Perfil secundário (M4, com a Mista) [calculado]: um dino grande que aceite o perfil só como secundário, em qualidade S, exige 16 refeições x 4 s = 64 s, torpor 64x1,5+16 = 112 de 160 (70%); em C seriam 32 refeições, 160 s, torpor 336: 3 dardos. Quebra-galho, não caminho.

### 1.4 Bônus ao dino depois (SUBSTITUÍDO pela seção 10: agora é Eficiência, que sobe o nível)

Qualidade **não** muda atributo permanente do dino (vida, dano, carga). Motivo: bônus permanente faz do S+ obrigatório e do C um erro irrecuperável. O que a qualidade dá é **Afeto inicial** (0 a 100), a barra de vínculo do D5 (ver GDD, seção de criaturas). Afeto sobe com cuidado (alimentar, ficar perto) e desce com negligência, então o ganho do S+ se dilui.

Conta do alcance [premissa: +4 de afeto por cuidado, um cuidado a cada 90 s]: S+ (35) leva `35/4 x 90 s` = 13 min de cuidado para o C alcançar; S (20) = 7,5 min; A (10) = 3,8 min. É uma vantagem de começo, não de teto. [jogar] se 13 min de cuidado são sensíveis ou irrelevantes.

Dino domado e fome: qualquer Ração restaura 30 de fome do dino, comida simples restaura 10 [premissa, fecha em CRI-07]. Só Ração de nível B ou mais dá +4 de afeto por alimentada; comida simples dá +1.

## 2. Como se obtém

### 2.1 Ingredientes (todos novos têm nome próprio)

| Ingrediente | Fonte | Risco | Quando |
|---|---|---|---|
| Baga, Samambaia, Carne | já existem (arbusto, planta, caça) | baixo | M1 |
| Fibra, Pedra | recursos básicos do plano | baixo | M1/M2 |
| **Tubérculo-lanoso** | monte de terra no campo (cavar) | baixo | M2 |
| **Sal-de-veio** | veio de pedra no bioma rochoso | médio (carnívoro por perto) | M2 |
| **Mel-de-cipó** | colmeia de cipó guardada por marimbondos (zona de dano 8/s) | **médio-alto** | M2 |
| **Seiva-de-brasa** | árvore-brasa na clareira de um carnívoro territorial | **alto** | M2 (Should) ou M4 |

Base por perfil: **Verde** = Baga + Samambaia; **Rubra** = Carne; **Mista** (M4, para onívoros) = 2 Verde + 1 Rubra (por 3 unidades).

### 2.2 Receitas (feitas na **bancada comum**; não há estação própria da Ração)

| Nível | Receita | Rende |
|---|---|---|
| C | 3 base | 2 |
| B | 2 base + 1 Tubérculo | 2 |
| A | 2 base + 1 Tubérculo + 1 Sal-de-veio | 2 |
| S | 2 base + 1 Sal-de-veio + 1 Mel-de-cipó | 2 |
| S+ | 2 base + 1 Mel-de-cipó + 2 Seiva-de-brasa | 2 |
| ~~Dardo de sono~~ (adiado sem marco, 06/11) | 2 Fibra + 1 Pedra | 3 |

Craft: 4 s na bancada comum (a mesma de todas as receitas, PRO-04), sem fornada de espera. Não existe cozimento com timer: espera sem decisão é defeito. O custo da qualidade é **ir buscar o ingrediente**, e a decisão é onde se arriscar.

### 2.3 Custo em tempo [premissa de coleta; calculado a partir dela]

Segundos por unidade coletada [premissa, incluindo caminhada]: Baga 3, Samambaia 4, Carne 8, Tubérculo 8, Sal 10, Mel 25, Seiva 30. Custo por ração (Verde): C 7 s, B 10 s, A 15 s, S 23 s, S+ 48 s. Total por domesticação (Paquicéfalo): 58, 57, 72, 92, 144 s (Baga crua: 30 s). Triceratops (agora Verde, antes Mista): C 116, B 114, A 145, S 184, S+ 288 s.

Ritmo de respawn dos raros [premissa] limita o topo: Seiva 1 árvore x 2 unidades / 15 min = 8 Seiva/h = 8 Ração S+/h. O Triceratops em S+ (6 rações) consome 45 min do ritmo de respawn: S+ é item de campanha, não de estoque.

### 2.4 Onde fica acessível

| Marco | Disponível | Observação |
|---|---|---|
| **M1** | Só Baga crua para o Paquicéfalo. Golpe grátis mantido, agitação desligada. | PRO-04 (receitas) é M2. M1 só prova o loop. |
| **M2 (v0.2) Must** | Bancada comum; Ração C, B, A; Tubérculo; Sal-de-veio; 3 perfis | 3 espécies. |
| **M2 Should** | S com Mel-de-cipó | Depende de uma zona de dano (marimbondos). |
| **M4** | S+ e Seiva-de-brasa; 4ª espécie e seguintes | Ver conflitos e corte em 4.5. |

**O que cortar se apertar:** (1) S+ inteiro e a Seiva; (2) Mel-de-cipó e o nível S; (3) perfil Mista (já fora do MVP); (4) Afeto inicial (a qualidade fica só em tempo e agitação). Núcleo mínimo da v0.2: C, B, A, comida crua, bancada comum, Dardo.

## 3. Preferência por espécie (dados)

Formato proposto para `SpeciesDef` / CSV, em dados, não em código. Nomes provisórios. Os adultos não são "fofos": o Paquicéfalo é neutro e só reage a ameaça, o Utahraptor é agressivo.

```
id            nome           papel / conduta           dificuldade  torpor_max  queda_inconsc  perfil_pref  rejeita  aceita_crua
paquicefalo   Paquicéfalo    herbívoro, Passivo        1.0          100         1.0            verde        rubra    baga
utahraptor    Utahraptor     carnívoro, Agressivo      1.5          120         1.2            rubra        verde    carne
parassaurolofo Parassaurolofo herbívoro de manada, Medroso 1.5        140         1.3            verde        rubra    baga
triceratops   Triceratops    grande, Semi-agressivo    2.0          160         1.5            verde        rubra    -
gallimimus    Gallimimus     herbívoro veloz, Covarde  1.25         100         1.2            verde        rubra    baga
```

**Atualização 05/11:** o **Utahraptor** substitui o Deinonychus (que volta ao catálogo como futuro) e o **Parassaurolofo** entra no M2. Elenco do MVP (decisão do dono: espécie com nome real, só terrestres, sem espécies brasileiras, lista reduzida). Base paleontológica e desvios em `GDD.md` 6.1. O **perfil Mista** e o **perfil secundário** (metade do progresso) ficam reservados ao M4, quando entram onívoros (Oviraptor); no MVP só Verde e Rubra, uma por espécie. Isso troca o perfil do antigo "Triceratops" (Mista) por Verde no Triceratops, o que muda o custo de coleta dele (abaixo). Carga extra: com o Parassaurolofo, as quatro espécies herbívoras do MVP são Verde e só o Utahraptor consome Rubra; se for preciso cortar escopo, a Rubra só se justifica por ele.

Golpes para nocautear (bastão de 30 de torpor, ver 10.6) [calculado]: Paquicéfalo e Gallimimus 4 em L10; Utahraptor 5; Parassaurolofo e Triceratops 6. Carne crua no Utahraptor: mesmo grau da baga crua (15 refeições, 90 s, torpor 90x1,2+75 = 183 contra 132 de máximo no L15: 2 dardos), de propósito desconfortável. Gallimimus aceita baga crua (13 refeições, 78 s, 159 de torpor: 2 dardos).

Dificuldade maior que 1 vem de **tamanho e temperamento**, não de "ser raro". Filhote: ver GDD (filhote domestica com perfil e janela mais generosos, e é o caminho de entrada ao vínculo sem violência).

## 4. Riscos de balanceamento

### 4.1 Estratégia dominante [calculado, simulado]

Custo esperado por domesticação = coleta do que foi consumido + k x segundos expostos + dardos, menos afeto inicial convertido em segundos (1 ponto = 1 s [premissa]). k = quanto vale um segundo de exposição ao perigo em segundos de coleta segura. Casos "médio", melhor nível:

| k | Paquicéfalo | Utahraptor | Parassaurolofo | Triceratops |
|---|---|---|---|---|
| 1 (perigo baixo) | A (Baga crua custa 99, A 83) | B | B | B |
| 3 | S | S | S | A |
| 6 (perigo alto) | S | S | S | S |

Achados:
- Nenhum nível é dominante em todos os cenários, mas **S ganha a maioria**. Qualidade pesa mais quanto mais perigoso o lugar. Bom.
- **S+ perde em todos os cenários** com Seiva a 30 s e 2 por craft (S+ 126 a 406 contra S 89 a 362). Só custo e velocidade não sustentam o S+: a velocidade satura (4 refeições do S contra 3 do S+). Versão anterior com Seiva barata fez do S+ dominante em tudo, então a faixa de equilíbrio é estreita. **Decisão de design:** S+ não é justificado só por número; ou ganha efeito qualitativo ou sai da v0.2 (seção 6).
- A comida crua só vence em k baixo e na primeira espécie: é o que se quer (tutorial barato).
- Com o golpe grátis (R6 ausente) tudo isso é irrelevante, pois a janela nunca limita. O dardo é pré-requisito do sistema.

### 4.2 Tédio de espera

Tempo parado por domesticação (sem dardo): 12 a 80 s conforme nível e espécie. Acima de ~60 s só no C do Triceratops. Regra: toda domesticação tem pelo menos uma decisão viva durante a espera: (a) gastar dardo agora ou arriscar mais um pouco; (b) defender contra invasor; (c) cercar o dino antes. [jogar] se 40 s de vigília sem ameaça é tédio ou tensão. Sem ameaça no local, o sistema vira barra de progresso: o perigo tem que ser parte do desenho do bioma (GDD).

Craft não tem espera: 4 s, sem timer.

### 4.3 Acúmulo sem limite

- Fontes finitas: nós raros com respawn de 8 a 15 min [premissa] (S+ máx. 8/h).
- Ralos: refeições de domar (finito por dino) e alimentação do rebanho (contínuo, ver CRI-07).
- Stack de Ração: 20 comum (C/B/A), 10 para S e S+ [premissa]. Peso/limite de carga do inventário faz o resto.
- Sem validade (apodrecer) na v0.2: custa implementação e não resolve nada que o respawn já resolve. **Cortado.** Se virar problema em playtest, validade só para Verde e Rubra.
- Risco que sobra: jogador estocar C barato e nunca subir. Aceito: C é o piso, e o C só vence em k baixo.

### 4.4 Pressão real da janela

Com R6 (dardo) e agitação, a janela falha só quando: ração de baixo nível sem dardo, ou dardo gasto durante luta (política da simulação: dardo só fora de combate). Simulação Monte Carlo, 4000 corridas por célula, invasor como evento Poisson com 15% de acordar o dino [premissa de ameaça]:

| Caso | Taxa de invasores | Dardos | Observação |
|---|---|---|---|
| bom | 1 a cada 400 s | 3 | |
| médio | 1 a cada 150 s | 2 | |
| ruim | 1 a cada 60 s | 1 | |

Sucesso [calculado]: Paquicéfalo Baga 98% / 94% / 85%; C 99 / 96 / 90; A 99,4 / 98 / 95; S+ 99,6 / 98,7 / 97. Utahraptor, antes do ajuste de 05/11 (então Deinonychus): C 98,5 / 95 / 88; A 99 / 97 / 93; S+ 99,5 / 98 / 96 (não reexecutado com os valores novos). Triceratops C 97 / 92 / 80; A 99 / 96 / 90; S+ 99 / 97,5 / 94. A queda é quase toda do invasor (tempo exposto x taxa x 15%), não do torpor. O número não prova diversão: prova que os níveis baixos custam 5 a 17 pontos de sucesso no caso ruim e o Triceratops em C é o pior caminho (como deve ser).

### 4.5 Conflitos de escopo

- Crafting por dados (PRO-04) está no M2, não no M1. A Ração com receita não existe no M1; o M1 só usa baga.
- Cozinhar é **Could** no plano (fogueira). A Ração usa a **bancada comum**, sem estação nova: **DECIDIDO (05/11)**; o conflito de escopo da estação extra deixa de existir.
- Zona de dano para Mel-de-cipó e carnívoro territorial para Seiva dependem de conteúdo de mundo e ameaça. Cortar S e S+ da v0.2 não quebra o loop.

## 5. Simulação

Script (reproduzível): `docs/design/racao_sim.py`. Python puro, `python3 racao_sim.py tabela|mc|custo`. Fica fora do repo; se o dono quiser reproduzir, o `SORA` o move para `tools/` (fora do escopo desta tarefa).

Resumo do que foi simulado: tabela determinística por espécie e nível (seção 1.3); Monte Carlo com 3 casos (4.4); custo esperado com k = 1, 3, 6 (4.1). Política do jogador na simulação: dardo quando torpor < 22 e sem luta; 1 ração por intervalo.

Limites da simulação: o modelo de ameaça é uma Poisson simples e o custo de coleta é premissa. Serve para mostrar **estrutura** (onde ficam os cruzamentos), não valores finais.

## 6. Calculado x precisa jogar

**Calculado:** tempos, refeições, torpor gasto e % de janela de cada combinação; que o golpe grátis anula a janela; que a faixa de equilíbrio de custo do S+ é estreita e perde em todos os cenários testados.

**Precisa jogar:**
- Se 12 a 80 s de vigília são tensão ou tédio (H1 do plano).
- Os tempos de coleta reais (Mel, Sal, Seiva) e o ritmo de respawn.
- Se o Afeto inicial de 5 a 35 é sentido.
- Se o jogador entende "acorda por digestão" (agitação) sem tutorial; se a falta de arma de torpor à distância na v0.2 (sem Dardo) incomoda ou se Bastão, fruta e preparado bastam. *(O dardo grátis a 3 por craft saiu junto com o Dardo, 06/11.)*
- Taxa real de invasores por bioma.

## 7. Mudanças de código para o `SORA` (não feitas aqui)

1. `ItemDef`: campos `racao_nivel` (C..S+), `racao_perfil`, `stack`. Itens novos: `racao_{verde,rubra}_{c,b,a,s,splus}` (mista só no M4), ingredientes e `dardo_sono`. Lista completa e atual na seção 10.9 (revista na 11).
2. `Items.gd`: sair do catálogo hardcoded para dados (PRO-03/ADR-003); `BERRY`/`MEAT` marcados `comida_simples`.
3. `TamingComponent`: trocar `ideal_food` por lista de aceitos vinda da espécie; ler por refeição `intervalo`, `progresso` e `agitação` da qualidade; progresso pela metade no perfil secundário; rejeitar perfil proibido; chamar `torpor.reduce_torpor(agitação)` a cada refeição; registrar qualidade consumida para o afeto inicial; manter `to_dict` compatível (ADR-002, nova versão de save).
4. **[ver 10.9 e 11]** `Dino.apply_torpor` aceita golpe dormindo, com dano e perda de Eficiência por ataque.
5. `SpeciesDef`: `dificuldade`, `torpor_max`, `queda_inconsciente`, `perfil_pref/sec/rejeita`, `aceita_crua`.
6. Afeto: componente novo (CRI-07), valor inicial vindo do `TamingComponent`.
7. Constantes de equilíbrio em recurso de dados (`RacaoTable`), não em código. Servidor: multiplicadores de tempo de refeição e de custo configuráveis (ver GDD, regras de servidor).
8. Testes headless: tabela determinística da seção 1.3 como casos fixos.
9. M1: só mudar `baga` para 10 refeições x 6 s e aceitar `aceita_crua`; sem agitação, golpe grátis.

## 8. Decisões que dependem do dono

1. **S+: manter na v0.2, empurrar para M4 ou dar efeito qualitativo?** Recomendo empurrar para o M4 e manter S, A, B, C na 0.2. Se ficar, efeito: dino com Afeto de entrada suficiente para exercer ofício imediatamente e invasor não o acorda. **DECIDIDO (05/11): aceita a recomendação.**
2. ~~Golpe dormindo custa dardo~~ **Substituída:** o dardo fica como manutenção barata de torpor; golpe custa dano e Eficiência (seção 11).
3. **Agitação (digestão acorda um pouco): aceitar a regra extra?** Recomendo sim; sem ela a janela só importa com dardo escasso. **DECIDIDO (05/11): aceita a recomendação.**
4. ~~Estação própria (Gral) ou bancada comum?~~ **DECIDIDO (05/11): bancada comum.**
5. **Afeto inicial: aceitar vantagem de começo de até 35 pontos?** **DECIDIDO (05/11): aceita a recomendação.**

## 9. O que ficou sem provar

Tensão e tédio da vigília; tempos de coleta e respawn; taxa de ameaça; se o afeto é percebido; custo de implementação das estações; se `S` é bom demais frente ao `A` no jogo real (a conta o põe vencedor em k alto).

---

## 10. Nível, Vida e Eficiência (decisões do dono de 05/11)

Script: `nivel_sim.py` (importa `racao_sim.py` da mesma pasta; `python3 nivel_sim.py niveis|eficiencia|preco`).

### 10.1 O que mudou nas regras

- **Nível** (inteiro) em todo dino. O mundo sorteia o nível do selvagem; os atributos da espécie são os do nível 10 (`L0`).
- **Eficiência E** (0 a 100%), barra ao lado da domesticação (só com ele dormindo). Começa em 100% no nocaute e só desce.
- Ao fechar a domesticação o nível sobe: **100% de E sobe 50%**.
- Atacar o dormindo causa dano e derruba E (regra do dono, seção 11). Manter o torpor sem bater: fruta e preparado (0 E); na 1.0, flecha de sono (75 de torpor, 0 de dano relevante, -2 E). *(Texto de 05/11: Dardo de sono, +40; adiado sem marco.)*
- Dino acordado: aumento de torpor **não tem barra**; só o comportamento (10.5). Dormindo: barra de torpor, de domesticação e de Eficiência.

### 10.2 Fórmulas de nível (`L` = nível do dino, `L0` = 10)

| Atributo | Fórmula | Piso/teto |
|---|---|---|
| Vida máxima, dano | `base x (1 + 0,04 x (L - 10))` | piso 0,5 |
| Torpor máximo | `base x (1 + 0,02 x (L - 10))` | piso 0,7 |
| Refeições para domar (tempo e custo em Ração) | `ceil(refeições_base x fator x (1 + 0,033 x (L - 10)))` (**atualizado 06/11, GDD 5.14**) | piso 0,5 do fator |
| Peso (capacidade de carga) | `base x (1 + 0,03 x (L - 10))` | piso 0,7 |
| Stamina (reservada, sem uso na 0.2) | `base x (1 + 0,02 x (L - 10))` | piso 0,7 |
| Velocidade, Fome | **sem fórmula**: fixas por espécie (conjunto de atributos do MVP, GDD 5.1) | |
| **Pontos (versão enxuta, 06/11)** | stats de captura congelam no nível final; cada nível por XP = 1 ponto = **+6% da base**, Vida, Dano e Peso no dino; teto **2x o nível final, máx. `dino_nivel_max` 50 no MVP (06/11, GDD 5.16)** | GDD 5.1, `pontos_sim.py` |

[calculado] com `nivel_sim.py niveis`:

| L | Vida/dano | Torpor máx. | Refeições | Peso | Stamina (res.) | Golpes p/ nocautear (torpor 100 / 160) |
|---|---|---|---|---|---|---|
| 1 | 0,64 | 0,82 | 0,86 | 0,73 | 0,82 | 3 / 5 |
| 10 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 4 / 6 |
| 20 | 1,40 | 1,20 | 1,15 | 1,30 | 1,20 | 5 / 8 |
| 30 | 1,80 | 1,40 | 1,30 | 1,60 | 1,40 | 6 / 9 |
| 40 | 2,20 | 1,60 | 1,45 | 1,90 | 1,60 | 6 / 10 |
| 60 | 3,00 | 2,00 | 1,75 | 2,50 | 2,00 | 8 / 12 |

Por que inclinações diferentes: vida e dano crescem rápido (dino forte é perigoso e domar é o caminho, não matar); torpor cresce devagar (nocautear continua viável); tempo de domar cresce pouco (a pressão da janela fica quase igual: torpor e tempo sobem em ritmos próximos, 1,40 contra 1,30 em L30). Golpes contados com o bastão novo (30 de torpor, 0,7 s, 5/s de queda acordado, ver 10.6).

Vida por espécie (base nível 10): Paquicéfalo 80, Utahraptor 80, Parassaurolofo 200, Triceratops 300. Em L30: 144, 144, 360, 540. A Lança (18 de dano) mata um Utahraptor L10 em 5 golpes e um L30 em 8: caça é viável, mas dino de nível alto é parede para arma de dano.

Efeito no tempo e na comida [calculado, Triceratops, dificuldade 2,0]: refeições C/B/A/S/S+ em L10 = 16/12/10/8/6; em L28 = 21/16/13/11/8 (+30%). O custo em Ração e a vigília crescem juntos.

### 10.3 Faixa de nível no mundo

Nível sorteado por `min + floor((max - min + 1) x u^2)`, com `u` uniforme em [0,1): poucos altos (**decisão 06/11, GDD 5.16; antes u^1,5**). Faixas atuais (valem sobre a tabela antiga de 05/11, que ia a 35):

| Espécie | Faixa selvagem (v0.2) | Observação |
|---|---|---|
| Dodo (presa, início do M2) | 3 a 10 | não domável |
| Paquicéfalo | 5 a 20 | tutorial 5 a 8 |
| Utahraptor | 10 a 25 | solitário |
| Parassaurolofo | 10 a 30 | manada de 3 a 5 |
| Triceratops | **18 a 24** | v0.2 **e 1.0** (sem Rifle, L28+ mata sem preparo; GDD 5.15) |
| Clareira-brasa (M4) | espécies novas | a definir com o M4 |

`dino_nivel_spawn_max` 30. Teto de nível **na doma** (Eficiência): `round(1,5 x L)`, no máximo `dino_nivel_max` (**atualizado 06/11, GDD 5.16**: o 75 fixo caiu; MVP 50). O **teto de evolução depois de domado** é 2x o nível de doma, também limitado pelo servidor. Servidor pode mexer nas faixas (10.9).

### 10.4 Como a Eficiência cai

`E = 100 - 0,3 x segundos_dormindo - drenagem_da_ração x refeições - 2 x dardos - soma(ataques recebidos dormindo: fixo + 0,5 x % da vida máx. perdida)`, limitada a 0..100. S+ tem drenagem **negativa**, ou seja, recupera. Detalhe dos ataques na seção 11.

| Fonte | Valor | Motivo |
|---|---|---|
| Tempo dormindo | -0,3 por segundo (**recomendo 0,15; GDD 5.14**) | Quanto mais demora, mais ele se desgasta |
| Refeição: Baga / C / B / A / S / S+ | -2 / -1,5 / -1 / -0,5 / 0 / **+2** | Comida inferior pesa; o S+ restaura |
| Flecha de sono (75 de torpor; era Dardo +40, adiado) | -2 por dose | Sedação forçada de dino acordado ou dormindo; **fruta e preparado não custam** |
| Ataque recebido dormindo | fixo + 0,5 por 1% da vida máx. (seção 11) | Golpe do jogador (fixo 4) e mordida de carnívoro (fixo 8) |

Bônus e arredondamento: `nível_final = min( floor(L x (1 + 0,5 x E/100) + 0,5), floor(1,5 x L + 0,5) )`. Linear de 0 a +50%, arredonda para o mais próximo com meio para cima; E a 100% dá exatamente +50% (nível 20 vira 30). Mostrar ao jogador o **nível previsto** em tempo real ao lado da barra ("20 -> 28"). Valores [calculado]: `(L, E) -> final`: (20,100)=30, (20,99)=30, (20,75)=28, (20,50)=25, (20,0)=20, (7,100)=11, (7,60)=9, (1,100)=2, (60,100)=90.

A "fome" do pedido entra por **comida inferior** (tabela acima): o dino está dormindo, então a pressão de fome vem da qualidade que se oferece. Perfil secundário (metade do progresso por refeição) duplica refeições e portanto também a drenagem, sem regra extra.

Resultado [calculado, `nivel_sim.py eficiencia`]. Casos (reexecutados após a seção 11): bom = nada o ataca; médio = 1 dardo e 2 mordidas de Utahraptor L15; ruim = 2 dardos e 5 mordidas. Nível selvagem típico por espécie.

| Espécie (nível) | Nível | Refeições | Tempo | E bom/médio/ruim | Nível final bom/médio/ruim |
|---|---|---|---|---|---|
| Paquicéfalo (8) | Baga | 10 | 60 s | 62 / 31 / 0 | 10 / 9 / 8 |
| | C | 8 | 40 s | 76 / 45 / 0 | 11 / 10 / 8 |
| | S+ | 3 | 12 s | 100 / 71 / 26 | 12 / 11 / 9 |
| Utahraptor (15) | C | 13 | 65 s | 61 / 33 / 0 | 20 / 17 / 15 |
| | A | 9 | 36 s | 85 / 57 / 16 | 21 / 19 / 16 |
| | S+ | 5 | 20 s | 100 / 76 / 35 | 23 / 21 / 18 |
| Parassaurolofo (20) | C | 14 | 70 s | 58 / 37 / 5 | 26 / 24 / 21 |
| | A | 9 | 36 s | 85 / 63 / 32 | 28 / 26 / 23 |
| | S+ | 6 | 24 s | 100 / 83 / 52 | 30 / 28 / 25 |
| Triceratops (28) | C | 21 | 105 s | 37 / 17 / 0 | 33 / 30 / 28 | **(desatualizado: com o tempo recalibrado, Triceratops L28 com C são 22 refeições e 5,5 min; GDD 5.14)**
| | B | 16 | 80 s | 60 / 40 / 11 | 36 / 34 / 30 |
| | A | 13 | 52 s | 78 / 58 / 29 | 39 / 36 / 32 |
| | S | 11 | 44 s | 87 / 67 / 38 | 40 / 37 / 33 |
| | S+ | 8 | 32 s | 100 / 87 / 58 | 42 / 40 / 36 |

Leitura:
- **A qualidade pesa mais onde o nível é alto.** No Paquicéfalo L8 a diferença entre pior e melhor é 2 níveis (irrelevante: use o que tiver). No Triceratops L28, C contra S+ é 33 contra 42 (+27% de nível, vida e dano ~+36%). Isso cria um gradiente natural: material barato para o começo, S e S+ para a pedreira.
- Com E em 0 a domesticação ainda conclui, sem bônus (seção 11.5). Isso acontece já no caso ruim do Paquicéfalo em Baga/C e do Utahraptor/Triceratops em C.

### 10.5 O S+ e o furo dos golpes (os dois problemas)

**S+ (antes perdia em todos os cenários).** Agora o S+ tem efeito qualitativo: drenagem negativa (+2 por refeição) e menos tempo dormindo, então termina com E mais alta que as demais com os mesmos ataques (caso médio: 71 a 87 contra 17 a 45 do C). Preço implícito [calculado, `nivel_sim.py preco`, caso médio, custo = coleta + exposição com k=1]:

| Espécie (nível) | Passo | Custo extra | Níveis a mais | Preço por nível |
|---|---|---|---|---|
| Triceratops (28) | A -> S | +56 s | +1 | 56 s/nível |
| Triceratops (28) | S -> S+ | +119 s | +3 | 40 s/nível |
| Utahraptor (15) | S -> S+ | +62 s | +1 | 62 s/nível |
| Parassaurolofo (20) | S -> S+ | +123 s | +1 | 123 s/nível |
| Paquicéfalo (8) | S -> S+ | +48 s | 0 | sem ganho |

Se o jogador valoriza um nível em mais de ~40 s de coleta, o S+ compensa no Triceratops (caso médio com mordidas). No Paquicéfalo não compensa; no Utahraptor (62 s por nível) e no Parassaurolofo (123 s por nível) só compensa para quem valoriza muito um nível. **Não deve compensar para todos** (é item de prestígio para a espécie grande). A conta prova que há um intervalo em que S+ vence; **o valor de um nível em tempo de jogo é premissa** e só o playtest fecha. Se o dono quiser S+ útil em mais casos, sobe a inclinação da drenagem ou o bônus para o ofício.

**Furo dos golpes.** Resolvido de dois jeitos juntos (regra do dono, seção 11): golpe no dormindo **causa dano** e tira E (jogador: 4 fixo + 0,5 por 1% de vida; ~5,4 E num Paquicéfalo L8), então bater para segurar o torpor é o caminho caro. O **dardo** (+40 torpor, sem dano, -2 E) é o caminho barato e fica. O torpor nunca é "grátis": ou custa item (dardo, ~5 s de coleta cada) ou custa E e vida. Pressão real: o reforço exige estar colado no dino; um carnívoro que prende o jogador numa luta deixa a janela correr.

### 10.6 Combate: dano, torpor e barra de vida

Todo dino tem **vida** além do torpor. Armas iniciais [proposta; números são [premissa] a testar]:

| Arma | Marco | Dano | Torpor | Cooldown | Uso |
|---|---|---|---|---|---|
| **Bastão-de-sono** | M1 | 2 | 30 | 0,7 s | Nocautear. Dano pequeno; só tira E quando ele já dorme |
| **Lança-de-pedra** | M2 | 18 | 6 | 0,9 s | Caçar e defender. Torpor baixo demais para nocautear (6 em 0,9 s = 6,7/s contra queda de 5/s) |
| Mãos nuas | M1 | 2 | 0 | 0,5 s | Cortável |

Bastão contra Paquicéfalo L10: 30 por golpe, 0,7 s, queda de 5/s: 4 golpes em 2,1 s [calculado]. Triceratops L10: 6 golpes em 3,5 s; Triceratops L40: 10 golpes em 6,3 s. Cada golpe a mais é exposição. O bastão tem dano mínimo (2): com ele acordado isso só gasta vida (o dino chega domado com vida um pouco menor); com ele dormindo, cada golpe tira E (seção 11). Dano em dino acordado **não** tira E.

**Barra de vida (para o `YATORA` e o `SORA`):**
- Aparece sobre o dino **só depois de dano** e some 5 s após o último. Nunca desenhada em dino cheio e fora de combate.
- No máximo **3 barras** na tela (as 3 mais recentes); as demais ficam ocultas.
- O selvagem dormindo mostra o painel de domar (torpor, domesticação, Eficiência) no contexto de interação, não sobre a cabeça.
- Dinos domados: lista de grupo no HUD (M2), barra sobre a cabeça só quando abaixo de 100%.
- Feedback de dano: flash branco de 0,1 s, partículas, som por golpe; vocalização de dor em 75%, 50% e 25% da vida (cada espécie tem a sua).
- Regra de jogo: abaixo de **25% de vida** o selvagem **foge** (carnívoro pode voltar após 10 s); isso é regra de servidor. O mancar é só visual.

### 10.7 Sinais comportamentais do torpor crescente (dino acordado)

Sem barra. Faixas pelo percentual `f = torpor atual / torpor máximo`, com histerese de 3 pontos:

| Faixa | f | Regra (servidor, afeta jogo) | Só visual/som (cliente) |
|---|---|---|---|
| 0 | 0 a 25% | nenhuma | nenhum |
| 1 | 25 a 50% | nenhuma | bocejo ocasional, som baixo de respiração |
| 2 | 50 a 75% | velocidade x0,85 | cambaleio leve, cabeça baixa, bocejos mais frequentes |
| 3 | 75 a 100% | velocidade x0,65; cooldown de ataque x1,5; **pausa de 0,8 s a cada 4 s** (determinística por id do dino e tick) | cambaleio forte, olhos pesados, respiração alta |

Separação: tudo que muda **velocidade, pausa ou cooldown** roda no servidor e é replicado como a **faixa (0 a 3)**, não o valor numérico. Isso cumpre "sem barra" (o cliente nem recebe o número, o que também veda leitura por modificação) e mantém a rede barata (2 bits por dino). Bocejo, cambaleio e som são cliente, disparados pela faixa. Com ele dormindo o valor numérico é replicado para a barra. Efeito de jogo previsto [calculado]: um Utahraptor em faixa 3 corre a 65% e para por 0,8 s a cada 4 s; o jogador de 70 px/s ultrapassa [premissa: velocidade do carnívoro maior que a do jogador, a conferir].

### 10.8 Ofícios, Afeto e v0.2

- **Afeto inicial = `round(E/5)`**: 0 a 20. Substitui a tabela por qualidade (0 a 35). Uma fonte só de bônus por qualidade, menos sistema.
- **Ofícios (revisto em 06/11):** carga passa a **Peso em kg** (Paquicéfalo 40, 52 e 64 kg em L10, L20 e L30; GDD 5.1); dano de defesa usa o **Dano** (Utahraptor base 8 vira 14,4 em L30 [premissa de dano base]). Dino fraco ainda serve; nível alto vale caçar.
- **Fome do rebanho:** medidor fixo por espécie, **sem crescimento por nível** (saiu o +1% por nível). O custo em Ração cresce pelas refeições para domar.
- **Pontos:** os níveis de bônus da Eficiência ficam **aplicados** (sem pontos); a Ração e a Eficiência não mudam. Só os níveis por XP depois de domado rendem pontos (GDD 5.1).
- **Criação (M4):** filhote tem nível baixo (1 a 10) e E própria que cai com negligência; ao crescer usa a mesma fórmula do bônus. Mantém um só sistema.

| Item | Marco | v0.2 |
|---|---|---|
| Nível em todo dino, atributos por fórmula | M2 | **Essencial** |
| Barra de vida e dano (Lança) | M2 | **Essencial** (a Lança pode sair; barra de vida precisa para ameaça) |
| Eficiência e nível final | M2 | **Essencial** (é o furo dos golpes) |
| Faixas de torpor (regra de velocidade) | M2 | Essencial só como visual simples; regra de pausa **cortável** |
| Nível previsto na UI | M2 | Essencial |
| S+ e Seiva | M4 | Cortável |
| Tabela de nível por bioma | M2 (3 espécies) | Essencial |

Sinais de conflito com o plano: ver seção 17 do GDD.

### 10.9 Lista exata para o `SORA` (nada feito aqui)

1. `NivelDino` (recurso de dados): `L0=10`, coeficientes (0,04 vida/dano; 0,02 torpor e Stamina; 0,033 refeições (piso 0,5; GDD 5.14); 0,03 Peso) com pisos da tabela 10.2; **sem** coeficiente de velocidade nem de fome; funções puras testáveis.
2. `SpeciesDef`: adicionar `vida_base`, `dano_base`, `faixa_nivel_por_bioma`, `aceita_crua`, perfis; remover `ideal_food` único.
3. `Dino`: campo `level` (selvagem, sorteado por bioma com `u^1,5` e seed do mundo); `HealthComponent` na cena do dino; vida/dano/torpor máximo derivados do nível; `to_dict` com `level`, `efficiency`; bump de versão do save (ADR-002) com migração (nível 10, E 100).
4. `TorporComponent`: calcular faixa 0..3 com histerese; emitir `band_changed`; manter `wake_ratio`. Servidor aplica velocidade x1/x1/x0,85/x0,65, cooldown x1,5 e pausa de 0,8 s a cada 4 s (determinística) na faixa 3.
5. `TamingComponent`: `efficiency` 0..100 (começa em 100 no nocaute); por tick `-0,3 x delta`; por refeição `-drenagem[qualidade]` (S+ negativa, limitada a 100); `refeições = ceil(base x dificuldade x fator_tempo(L))`; no fim `mark_tamed` aplica `nível_final` com a fórmula 10.4; Afeto inicial `round(E/5)`; sinal `efficiency_changed` e `level_preview_changed`.
6. `Dino.apply_torpor(amount, source)` e `Dino.take_damage(amount, attacker)`: com ele dormindo, cada ataque recebido debita `fixo[atacante] + 0,5 x %vida` de E (fixo 4 jogador, 8 carnívoro) e dano de vida; dardo debita 2 E sem dano. Dano em dino acordado só tira vida. Ver 11.
7. Itens: `bastao_sono` (M1), `lanca_pedra` (M2), `flecha_sono` (M4; 4 flechas comuns + 1 preparado rendem 4). **`dardo_sono` não entra.**
8. `Player`: ler dano/torpor/cooldown da arma equipada; o ataque atual (40, 0,35 s) passa a 30 de torpor e 0,7 s com o bastão (ajuste de dado, cabe a `QA-01`).
9. UI: painel de domar com três barras (torpor, domesticação, Eficiência) e "nível previsto"; barra de vida sobre o dino só após dano (máx. 3), fade de 5 s; lista de grupo no HUD (M2). Sem barra de torpor acordado.
10. Foge abaixo de 25% de vida (comportamento Flee com gatilho).
11. Configuração de servidor em dados: `eficiencia_por_dardo` (2), `eficiencia_fixa_ataque_jogador` (4), `eficiencia_fixa_ataque_carnivoro` (8), `multiplicador_nivel_selvagem`, `faixas_de_nivel`, `eficiencia_drena_tempo` (0,3). 
12e. ~~CarcassSpawner~~ **removido (06/11, dono):** a fonte de carne é a Lança e as presas Dodo e Listro (GDD 5.6, 6.1); sem spawner de carcaça e sem nó de Carniça.
12j. ~~Rifle de dardos~~ **adiado sem marco (decisão final do dono, 06/11):** nada a implementar. Arco, Flecha, Boleadeira (M4) e Besta (M5): `WeaponDef` com `projectile`, `range_tiles` 10, 6 e 14, durabilidade 120; números em GDD 5.4.
12k. **Tetos de nível (GDD 5.16):** chaves `jogador_nivel_max` 20, `dino_nivel_max` 50, `dino_nivel_spawn_max` 30, `dino_teto_multiplicador` 2,0, `dino_teto_base` final; `teto_efetivo(dino) = min(mult x nível_de_doma, dino_nivel_max)`; sorteio `mín + floor((máx-mín+1) x u^2)`; XP que trava (sem acumular) e selo "teto"; save acima do teto mantém nível e pontos.
12d. **Estruturas e Stamina (GDD 8.1 e 5.8):** `StructureDef`/`Structure` com vida e regeneração, `ConductaDef.ataca_estrutura` e `fator_dano_estrutural`, ataque do Agressivo à peça de bloqueio após 2 s sem caminho; `stamina_cost` em `WeaponDef`, custo por segundo de coleta, estado `exhausted` (cooldown x1,5, efeito x0,75, coleta x1,5, no servidor), regen com atraso de 0,5 s, ofego em ação. Sem estrutura de metal.
12c. **Receitas e HUD (GDD 5.7, `receitas.md` 9):** `RecipeDef`, `saber_livre`, `receitas_conhecidas`, tela do Personagem (tecla P, abas), pedidos `aprender_receita` e `craftar` validados no servidor; HUD com vida, fome, XP com nível, selo de ponto livre, linha de aviso de nível e estado ofegante (som e partícula) sem barra de stamina; sem campo de durabilidade.
12b. **Carcaça e sacolinha (GDD 5.6):** entidades de mundo `Carcass {id, species, level, pos, age, carne_left, couro_left, owner_id}` e `LootBag {id, pos, items[], age, owner_id, exclusive_until}`, **salvas** (teto 8 e 20; a mais antiga some) e **sem depender de apresentação**; `age` vira estado fresca (10 min), carniça (até 20 min, só carne podre `ceil(carne/4)`) e remoção; rendimento `base x (1+0,03(L-10))` (piso 0,7) por espécie em `SpeciesDef` (`carne_base`, `couro_base`); itens `couro` (0,4 kg) e carne de 25 de fome (confirmar); pedidos `coletar_carcaca(id, item)` e `pegar_sacolinha(id)` validados no servidor (existência, 2 tiles, 1,5 s por carne e 3 s por couro com barra parcial, dono por 120 s, Peso; o excesso fica na sacolinha); morte permanente de domado gera carcaça e sacolinha com o alforje; sem XP. Teste headless: tabela do GDD 5.6, salvar e carregar com carcaça a meio, expirar e Peso cheio.
12f. **Comida e fome (GDD 5.10):** `decay_per_second` 0,2; fonte de torpor "fome" no jogador (+2/s líquido, fora do teto de 3 efeitos); estado inconsciente (8 s, acordar a 50, 1,5 dano/s); carne crua, cozida e podre como itens com fome, vida e dano; Fogueira com ação "assar" (2 s por carne, 1 madeira por 4); interação "alimentar jogador" (1 s, valida no servidor).
12g. **Validade e durabilidade (GDD 5.9):** pilha `{id, count, expira_em}`, equipamento `{id, iid, durab, durab_max}`, barra de atalhos por slot; carne vencida vira carne podre `ceil(n/4)`; reparo na Bancada; armadura de 3 conjuntos com `max(1, dano x (1 - redução))`.
12h. **Cocho (decidido: só para dino domado) e fome do domado (GDD 5.12):** `Trough {items[], accepts, range=6}`; dino com fome <= 50 vai ao cocho (2 s por unidade), do alforje só <= 25 e sem Ração; domesticação não usa cocho; fome 0 > 2 min tira 1 de Afeto por min e pausa o ofício.
12i. **(Adiado para depois do playtest, dono 06/11) Slot de Oferta / domar passivo:** não implementar agora; proposta em GDD 5.13. **Vale agora:** tecla 1-9 só consome pelo jogador; **o jogador nunca consome Ração, só o dino**; preparado de sono ainda não decidido; domar ativo pela tela de inventário do dino (E, já implementada); **Cocho só para dino domado** (12h).
12a. **Armas e torpor (GDD 5.4, 5.5):** `WeaponDef` com `damage`, `torpor_instant`, `torpor_rate`, `torpor_duration`, `cooldown`, `range_tiles`, `ammo_item`, `reload_time`, `melee_scaled` (só Soco e Bastão escalam com o Dano do jogador). `TorporComponent`: lista de até 3 efeitos `{rate, remaining}`; o 4º renova o de menor `remaining`; tick soma `taxa - queda`; clamp 0 e máx.; **entra em `to_dict`/`from_dict`** (até 3 pares de float) e **não depende de apresentação** (servidor aplica; cliente só mostra a faixa). Itens `fruta_sono` (6/s, 5 s, 0,1 kg), `preparado_sono` (12/s, 5 s), `carne_podre`; nó `arbusto_fruta_sono` (3 frutas, 4 s, respawn 6 a 8 min) e nó `carnica` (2, 4 s, 10 min); receita 3 frutas + 1 carne podre = 3 preparados, 4 s; pedido `forcar_item(dino_id, item_id)` validado no servidor (dino dormindo, alcance 3 tiles, 1,5 s de ação, 3 s de espera por dino, teto de efeitos, sem custo de E); `usar_atalho` com confirmação da fruta sem alvo; arremesso do dardo (6 tiles, 1 s). Jogador usa o mesmo `TorporComponent` (máx. 100) com sinais M2; sono M4. Soco: golpe sem item na mão (10 de torpor, 0,6 s).
12. **Atributos e pontos (GDD 5.1):** `Attributes` (recurso/componente) com Vida, Dano, Stamina, Peso por jogador e dino: `base x (1 + auto(L_captura) + 0,06 x pontos)`; `nivel`, `xp`, `pontos_livres`, `pontos{}`; curvas `30+15(L-1)` (jogador) e `20+10g` (dino); teto de captura+10 e 75; Dino com ponto em Vida, Dano e Peso na 0.2 (Stamina sem ponto até a montaria); sem respec nem teto por atributo; funções puras testáveis. Pedido de rede `distribuir_pontos` validado no servidor (dono, pontos, alvo vivo, 6 tiles, 10 s sem dano); sem respec nem teto por atributo na 0.2. Dano do jogador multiplica dano e torpor do golpe; jogador nível 20, dino captura+10. Save: jogador e dino com os campos do GDD 5.1 e `nome`, bump de versão.
13. **Peso:** `ItemDef.weight`; `InventoryComponent` com `max_weight` (jogador 50 + 3/ponto; alforje do dino = Peso do dino), recusa pegar acima de 100% com mensagem; slots viram exibição; `starting_items` conferido (3,3 kg).
14. **Barra de atalhos (GDD 5.2):** 9 ações de entrada, atribuição por id de item, soma de pilhas, apagado sem estoque; `usar_atalho(item_id)` (sem alvo; a tecla nunca age em dino); dar ao dino é `alimentar_dino(dino_id, item_id)` da tela do dino validado no servidor; cooldowns 0,5/0,3/1,0 s; conferir conflito com teclas 1 a 9.
15. **Nome do dino (GDD 6.9):** campo no fim da domesticação e no painel; 20 caracteres, texto limpo sem marcação, validado no servidor; exibição no painel e na lista do grupo; `filtro_nomes` opcional fora do MVP.
16b. `YATORA`: carcaça por espécie (4 sprites, com estado fresca e carniça), sacolinha no chão (e brilho curto ao expirar), ícones de couro (e quitina, futuro), barra de coleta e lista de itens da carcaça, som de coletar.
16c. `YATORA`: carne cozida e carne podre (ícones), Fogueira acesa e apagada, 15 ícones de peça de roupa (3 materiais x 5 peças) e 6 silhuetas de vaga, jogador deitado e estrelinhas, vinheta e ronco de fome, Dodo e Listro (sprite, carcaça fresca e carniça), aviso e som de durabilidade baixa e de quebra. (Slot de Oferta e aviso de interrupção: adiados.)
16a. `YATORA`: ícones de Soco, flecha de sono e flecha comum (M4), boleadeira (M4), fruta-do-sono (roxo, distinta da baga), preparado de sono, carne podre; arbusto da fruta; sprite do tiro e do impacto da flecha (M4); efeito de torpor contínuo no dino (halo ou zumbido discreto, só visual); animação de dino comendo forçado; sons de arremesso e de mastigar.
16. **Telas:** atributos do jogador e do dino (pontos livres, valor por ponto, prévia do resultado), alforje do dino, barra de atalhos. `YATORA`: ícones dos 4 atributos, moldura e estados dos 9 atalhos (normal, apagado, ativo, recarga), ícone de alforje.
17. Testes headless: tabela 10.2 e 10.4 como casos fixos (incluindo (20,100)=30 e (7,60)=9); ataques em sequência com ele dormindo; save/load com E e nível; faixa de torpor nas fronteiras com histerese.

### 10.10 Itens de som e arte para o `YATORA` (placeholders identificados no CREDITS.md)

Som: golpe do bastão (macio), golpe da lança (seco), impacto em dino (um por classe: pequeno, médio, grande), vocalização de dor por espécie nos 3 limiares, bocejo por espécie, respiração pesada (faixas 1 a 3), sono (ronco) para o dormindo, som de "Eficiência" (tique ao perder, brilho ao recuperar com S+), subida de nível ao domar, fanfarra curta de domado.

Arte: barra de vida do dino (pequena, legível sobre qualquer fundo), barra de Eficiência (cor distinta da domesticação e do torpor), painel de domar de três barras, número de nível sobre o painel e no HUD de grupo, ícone de nível, flash de dano e partículas, animações de bocejo, cambaleio e pausa por espécie (frames mínimos), sprites de bastão e lança, ícones de Ração por qualidade (C a S+) e perfil.

### 10.11 Calculado x precisa jogar

**Calculado:** todas as tabelas de 10.2 a 10.7; que a pressão da janela fica quase constante com o nível; que o S+ tem um intervalo em que compensa (Triceratops alto); ataque ao dormindo (seção 11).

**Só o playtest responde:** se 2 E por dardo, 4 e 8 E fixos por ataque, 0,3 E/s e 0,5 E por 1% de vida são sentidos ou ignorados; se um nível vale 40 s para o jogador; se 4 a 10 golpes de bastão com 0,7 s é cadência boa; se as faixas de torpor são legíveis a olho nu; se a tela com 3 barras de vida cabe sem poluir; se a Lança precisa existir na 0.2; velocidade do carnívoro em relação ao jogador.

**Depende do dono:**
1. ~~Cortar o dardo~~ **Superado (06/11): o Dardo saiu sem marco; a flecha de sono (M4) ocupa o lugar** (seção 11.4 como histórico).
2. Sem teto de reforços: a dose forçada é limitada pelo estoque de flechas ou de preparado (seção 11.4).
3. Afeto inicial vindo da Eficiência (`round(E/5)`) em vez da tabela por qualidade (recomendo sim).
4. Faixas de nível por bioma, fator 1,5 de teto e `L0 = 10`.
5. Bastão com 30 de torpor e 0,7 s (muda os 3 golpes de 40 do jogo atual) e Lança entrar na 0.2.
6. Dino selvagem foge com menos de 25% de vida.

---

## 11. Ataques ao dino dormindo (regras definitivas do dono, 05/11)

Regras do dono: (1) atacar o dormindo causa dano; (2) cada ataque recebido dormindo derruba a Eficiência, até 0% ou até o dino morrer; (3) carnívoros atacam dinos dormindo, e isso também derruba E e causa dano: **é preciso proteger o dino durante a domesticação**.

### 11.1 Quanto cada ataque tira de Eficiência

`E_perdida = fixo[atacante] + 0,5 x (dano / vida máxima x 100)`

| Atacante | Fixo | Arma/ataque | Dano | Cadência [premissa] |
|---|---|---|---|---|
| Jogador | 4 | Bastão 2 / Lança 18 | da arma | 0,7 s / 0,9 s |
| Carnívoro (Utahraptor) | **8** | mordida 8 x (1 + 0,04 x (L - 10)) | 9,6 em L15 | 1,5 s |

O carnívoro tira **o dobro de fixo** (8 contra 4): ele ataca para comer, não para dobrar, e a mordida é mais forte. Tudo por dado e configurável. O termo de dano protege o desenho: dino pequeno perde muito mais por ataque do que dino grande.

Valores [calculado, `nivel_sim.py ataques`]:

| Alvo dormindo | Atacante | E por ataque | Vida por ataque | Ataques até E=0 | Até morrer | Tempo (carnívoro) até E=0 / morte |
|---|---|---|---|---|---|---|
| Paquicéfalo L8 | jogador (bastão) | 5,4 | 2,7% | 19 | 37 | |
| Paquicéfalo L8 | Utahraptor L15 | 14,5 | 13,0% | 7 | 8 | 10,5 s / 12 s |
| Triceratops L28 | jogador (bastão) | 4,2 | 0,4% | 24 | 258 | |
| Parassaurolofo L20 | Utahraptor L15 | 9,7 | 3,4% | 11 | 30 | 16,5 s / 45 s |
| Triceratops L28 | Utahraptor L15 | 8,9 | 1,9% | 12 | 54 | 18 s / 81 s |

Janela de reação: o carnívoro começa a atacar em t=0 e o jogador o afasta em R segundos:

| R | Paquicéfalo L8 (E perdida / vida perdida) | Triceratops L28 |
|---|---|---|
| 2 s | 29 / 26% | 18 / 4% |
| 4 s | 44 / 39% | 27 / 6% |
| 8 s | 87 / 78% | 54 / 11% |
| 12 s | 100 / **morre** | 80 / 17% |

Leitura: dino pequeno e de nível baixo morre se o carnívoro não for afastado em ~10 s e perde metade do bônus em 4 s. Dino grande aguenta bem, mas perde E por inteiro em 18 s. **Isso é a proteção que o dono quer, e é forte**: o pequeno precisa de defesa preparada. [jogar] se 12 s é justo ou punitivo; alavancas de ajuste: cadência da mordida (1,5 para 2,0 s), dano da mordida (x0,75), fixo (8 para 5).

### 11.2 Como o carnívoro detecta a presa dormindo

- **Ronco:** o dino dormindo emite sinal de presa com raio de **8 tiles** (128 px) [premissa]. Ração aumenta: Rubra +4 tiles (cheiro de carne), Verde +0 (Mista +2, a partir do M4).
- O carnívoro em patrulha checa a cada 0,5 s; a presa dormindo no raio vira **alvo candidato**. Escolhe o alvo mais próximo entre o jogador e o dormindo.
- **Aviso ao jogador:** som de farejar e um "!" sobre o carnívoro durante 1,5 s antes da investida; com velocidade de carnívoro 100 px/s [premissa] a investida a 8 tiles leva ~1,3 s. Soma ~3 s de aviso antes da primeira mordida.
- **Decisões do jogador:** (a) afastar o carnívoro matando-o com a Lança, (b) provocar (um golpe nele muda o alvo para o jogador e ele deixa o dormindo; custa risco de dano em si), (c) preparar antes: **curral** de estacas ou paredes em volta (8 peças em anel) e dormir o dino em lugar fechado, (d) escolher a Ração sem cheiro de carne.
- Herbívoros neutros não atacam dormindo.
- **Quando:** a detecção do dormindo entra no **M2** (extensão de CRI-04). No **M1** o carnívoro só persegue o jogador (como o plano), sem alvo dormindo. Risco: sem ameaça, a vigília do M1 vira barra de progresso (H1) e o M1 prova menos. Se o dono quiser testar H1 já no M1, é acrescentar o dormindo como segundo alvo na lógica de perseguição; estimo pouco trabalho em cima do CRI-04, mas é escopo a mais que o plano (não alterei).

### 11.3 Eficiência em 0%

Domestica normalmente, **sem bônus**: nível final = nível selvagem, Afeto inicial 0. Não há outra penalidade (sem "dino arisco" nem recusa). Se o dono quiser mais dureza: E em 0% dá Afeto inicial negativo e ordens falham 30%. Recomendo a versão simples.

Se o dino **morre** (vida em 0) durante a domesticação: a domesticação falha, a Ração já consumida é perdida, o corpo some. É o custo máximo do descuido.

### 11.4 Manter o torpor sem bater: o dardo fica

Alternativas avaliadas:

| Opção | Custo | Veredito |
|---|---|---|
| Golpear o dormindo | Dano + 4 E fixo + 0,5/1% vida (5,4 E no Paquicéfalo; 4,2 no Triceratops) e +30 de torpor | Caro; vira emergência |
| **Dardo de sono** | 1 item (2 Fibra + 1 Pedra rende 3, ~5 s de coleta por dardo) + 2 E; +40 de torpor; exige estar colado | **Escolhido** |
| Ração com sonífero | Novo ingrediente e perfil de Ração | Cortado: mais uma cadeia |
| Ração de maior qualidade | Reduz a agitação por refeição (de 3 a 0) | Cobre **indiretamente**: S e S+ quase não gastam torpor |

Dardo é estritamente melhor que golpe: -2 E contra -5,4 e sem dano. O furo dos golpes fecha: manter torpor continua possível, mas nunca de graça (item ou E). O estoque de dardos é o limite (sem teto adicional). Dardos mínimos [calculado]: Paquicéfalo L8 com baga 115% da janela = 1 dardo; Triceratops L28 em C 101% = 1 dardo; resto 0.

**Reveja da janela de torpor:** a conta de pressão (tabelas 1.3 e 10.2) não muda, pois depende de tempo e agitação. O que mudou é o custo de estender: dardo -2 E e 1 item, golpe -4 a -5 E e dano. A pressão real da janela agora tem duas fontes: (a) baixa qualidade exige dardo; (b) um carnívoro à solta tira E e vida mais rápido do que a janela acaba. No caso ruim da tabela 10.4 (2 dardos e 5 mordidas) o Paquicéfalo termina com E de 0 a 26% em qualquer qualidade e o Utahraptor de 0 a 35%.

### 11.5 Atualizações de conta e regra

- Dano recebido por Eficiência (10.4) vale **só dormindo**, do nocaute ao fim da domesticação. Dano em dino acordado só tira vida.
- Vida que o dino perdeu antes de domar **persiste** depois de domado (recupera lento na base).
- Sem teto de reforços: o dardo é limitado por estoque.

### 11.6 Mudanças para o `SORA` (acréscimos à 10.9)

1. `take_damage(amount, attacker_kind)` no `Dino`: se dormindo e não domado, debita E por `fixo[kind] + 0,5 x %vida`, limitado a 0; vida chega a 0 = `domesticação falha` e dino morre.
2. Alvo "presa dormindo" na lógica Chase do carnívoro (M2), com raio de ronco por perfil da Ração (8/+4/+2/+0 tiles), checagem de 0,5 s e aviso de 1,5 s (`on_target_acquired` para UI e som).
3. Curral: reutilizar `BuildGrid` e paredes; bloquear caminho do carnívoro (sem lógica nova de colisão além da já prevista).
4. Dardo: item e uso `use_dart(dino)` (+40 torpor, -2 E, 0 dano, 1 item, exige alcance de interação).
5. Dados de servidor: `eficiencia_fixa_ataque_jogador` 4, `eficiencia_fixa_ataque_carnivoro` 8, `raio_ronco_tiles` 8, `aviso_carnivoro_s` 1,5, `cadencia_mordida_s` 1,5.
6. Testes: ataque do jogador e do carnívoro com ele dormindo (E e vida), E em 0 domestica sem bônus, morte durante domar falha, dardo não causa dano.

### 11.7 Som e arte (acréscimos para o `YATORA`)

Som: farejar do carnívoro, rosnado de aviso, mordida na presa dormindo, gemido do dormindo ferido, "tique" de Eficiência perdida. Arte: "!" de aviso sobre o carnívoro, sprite do dormindo ferido, estacas e paredes do curral.

### 11.8 O que é cálculo e o que é jogar

**Calculado:** E por ataque, tempo até E=0 e até a morte, janela de reação, resultados por caso, preço do dardo.
**Só o playtest responde:** se 12 s até a morte do pequeno é justo; se o aviso de 3 s dá tempo de reagir; se o curral é viável em 16 s; a cadência e a velocidade do carnívoro; se E=0 sem penalidade extra desmotiva; se o ronco com cheiro de Ração é compreendido.
**Depende do dono:** fixo 4 e 8 por ataque; raio de ronco de 8 tiles; detecção do dormindo no M1 ou M2 (recomendo M2); E=0 sem penalidade; morte do dino na domesticação ser definitiva.

---

## 12. Decisões do dono (05/11) que afetam a Ração

Aceitas as recomendações de `GDD.md` seção 20; as propostas 1, 3 e 10 entram na v0.2, 6, 7 e 9 no M4, 8 adiada, 2 e 5 rejeitadas.

- **DECIDIDO, proposta 1:** `racao_minima` por espécie (Paquicéfalo C, Utahraptor B, Parassaurolofo C, Triceratops A, Gallimimus C); abaixo dela rende 50%; comida crua isenta. Marco M2.
- **DECIDIDO, proposta 3:** sem comida, depois de 1 intervalo o progresso regride 1% por segundo (configurável). Marco M2.
- **DECIDIDO, proposta 4:** opção de servidor `perde_estoque_ao_acordar`, **desligada por padrão**. A regra R7 (a Ração que sobrou fica) segue valendo por padrão.
- **DECIDIDO, proposta 7:** no M4, o S+ passa a pedir 1 Orvalho-de-casco por receita (produzido por dino domado com Afeto 50 ou mais), no lugar da Seiva-de-brasa.
- **DECIDIDO, proposta 10:** ação Observar com prévia (Ração aceita e mínima, refeições, tempo, % da janela, nível esperado) e tabelas em JSON de leitura. Marco M2.
- **DECIDIDO, propostas 2 e 5:** rejeitadas; o intervalo continua fixo por qualidade e a perda de Eficiência por ataque continua linear.
- **Elenco (05/11):** espécies reais (seção 3); Mista e perfil secundário ficam para o M4.
- **DECIDIDO (05/11), todas as pendências anteriores:** S+ no M4 (S, A, B, C na 0.2), agitação aceita, Afeto inicial `round(E/5)`, fixos de 4 e 8 por ataque, E em 0% sem bônus e sem outra penalidade, faixas de nível, bastão de 30 de torpor, Lança na 0.2 cortável como recomendado. **Estação: bancada comum, não o bancada comum.**
