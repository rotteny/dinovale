# Dino Vale: Game Design Document (GDD)

Status: v0 de visão, 05/11/2026. Autora: `SHIRO`. Fonte da verdade de design. Escopo, prazo e marcos são de `docs/PLANEJAMENTO.md`; onde este documento discorda, está marcado **CONFLITO** e listado na seção 17. Não alterei o plano.

Convenção: **[calculado]** saiu de conta; **[jogar]** só playtest responde; **[premissa]** número assumido. Marco = M1 a M6 do plano. Corte: **Essencial** (sem isso a v0.2 não fecha o loop) ou **Cortável**.

Anexos: `docs/design/racao.md` (comida de domesticação, qualidade S+ a C) e `docs/design/receitas.md` (árvore de receitas e Saber). Em conflito, vale este GDD. Espécies usam nome real (6.1); nomes de itens e sistemas, incluindo Ração, são próprios e originais; biomas e outros termos de design são provisórios.

---

## 1. Fantasia e público

**Fantasia.** Você chega a um vale acolhedor onde moram animais perigosos de verdade. Com paciência, cuidado e um bom lanche, um deles passa a confiar em você. O prazer é **conquistar confiança de algo que poderia te comer**.

**Tom (decisão do dono).** O vale é simpático; os animais adultos não são. Adulto é **neutro** (herbívoro: vive a vida dele, foge ou se defende) e carnívoro é **agressivo** (caça, persegue). O carisma fica na **arte de propaganda** (landing, ícone, capa) e nos **filhotes**. Dentro do jogo, o adulto é legível e respeitável, não fofo.

**Público** [premissa]: grupos de 2 a 8 amigos que querem um servidor próprio e gostam de sobreviver sem estresse competitivo; jogador solo curioso do gênero que aprecia ritmo calmo. Sessões de 30 a 60 min. Sem PvP, sem monetização, grátis e aberto (pilares do plano).

## 2. Core loop

| Escala | O que o jogador faz | Por que volta |
|---|---|---|
| **Minuto (2 a 5 min)** | Coletar, craftar, enfrentar ou fugir; nocautear e alimentar um dino | Pequenos ganhos imediatos e perigo legível |
| **Hora (30 a 60 min)** | Sobreviver ao dia, domar um dino, ter abrigo, voltar ao save | Um dino novo no time e uma base maior |
| **Semana (sessões repetidas)** | Cuidar do rebanho, expandir a base, subir de tier de receita, enfrentar região mais perigosa; no servidor, projetos do grupo | Afeto dos dinos (se descuidar, cai), próximo tier, território |

Loop central: explorar e coletar, craftar, nocautear, alimentar vigiando, dino domado, ofício na base, base maior, tier seguinte. Concorda com o plano (seção 2).

## 3. Diferencial do jogo (D5)

**Crítica à recomendação do plano.** "Cuidado e ofícios" (dino com fome, humor e função: carregar, defender) é o padrão do gênero. Faz o dino ser útil, mas não faz o jogo ser reconhecível. Também tem risco: tirar fome e humor do dino pode virar tarefa de manutenção (chatice sem decisão).

**Proposta (recomendada): "Confiança"**, em três peças que se apoiam e se cortam em ordem:

1. **Afeto** (0 a 100) em cada dino domado. Sobe com cuidado e presença, desce com negligência e com dano sofrido. Define **obediência** e **o que ele aceita fazer**. É o lugar onde a qualidade da Ração aparece (afeto inicial).
2. **Temperamento persistente.** Domar não apaga a natureza: um carnívoro domado continua agressivo com estranhos e só segue ordens com Afeto alto; um herbívoro continua cauteloso. O vínculo é **a exceção que você conquistou**, não um interruptor.
3. **Criação.** Filhotes (do ninho, com risco) crescem sob cuidado e viram adultos com Afeto de entrada alto e **ofício à escolha**. O filhote é onde o carisma mora e a via não violenta ao vínculo.

Por que é melhor que "ofícios" sozinho: dá uma **segunda via de domar** (violenta e rápida vs. lenta e cuidadosa), faz o perigo do mundo continuar presente depois de domar, e dá ao grupo uma coisa para conversar ("o meu Utahraptor só me obedece"). Custo: mais sistema de comportamento.

| Peça | Marco | Corte |
|---|---|---|
| Afeto + obediência por limiar (ordens funcionam só acima de X) | M2 | **Essencial** (é CRI-07) |
| Temperamento (carnívoro domado agressivo com estranho) | M2 | Cortável; vira "ele segue e ataca o que você ataca" |
| Criação de filhote (ninho, incubar, crescer) | M4 | Cortável, mas é o que vira identidade |

**CONFLITO 1**: o plano coloca D5 como pendente com recomendação "cuidado e ofícios"; esta proposta a estende com Afeto e Criação. A v0.2 só precisa da primeira linha. Decisão do dono (seção 18).

## 4. Mundo e biomas

Mapa fixo na 0.2 (plano: MUN-01, MUN-03); chunk e seed no M4.

| Bioma (provisório) | Papel | Perigo | Recursos | Marco |
|---|---|---|---|---|
| **Campina** | Início, abrigo, Paquicéfalos | Baixo de dia | Baga, Samambaia, Fibra, Tubérculo, madeira | M1 |
| **Mata-baixa** | Madeira, caça, Utahraptor, manadas de Parassaurolofo | Médio (carnívoro persegue) | Madeira, Carne, **Fruta-do-sono, Dodo e Listro**, Mel-de-cipó (cortado) | M2 |
| **Pedreira** | Pedra, Sal-de-veio, Triceratops | Médio-alto (território) | Pedra, Sal | M2 |
| **Clareira-brasa** | Seiva, prestígio | Alto | Seiva-de-brasa | M4 |

Regra de desenho: **o perigo é parte do bioma**, não evento aleatório. Cada bioma tem uma ameaça que justifica a vigília de domar (H1 do plano). Tamanho do mapa fixo: [premissa] 128x128 tiles (16 px), cruzar a pé (70 px/s) em ~29 s; sprint 120 px/s dura 4 s [calculado: stamina 100 / dreno 25/s]. Cortável: 3º bioma na 0.2 (basta 2).

## 5. Sobrevivência

Valores reais no código: stamina 100, dreno 25/s, regen 15/s, retoma com 20; fome 100, queda 0,5/s, fome zerada dá 5 de dano a cada 2 s.

| Sistema | Regra | Marco | Corte |
|---|---|---|---|
| Vida | Dano de dino e de fome; regenera lento fora de combate | M1 | Essencial |
| Stamina | Sprint e ataque; esgota em 4 s, volta em 5,3 s (0 a 80) | M1 | Essencial |
| Fome | Esvazia, come-se baga/carne; zero causa dano | M1/M2 | Essencial |
| Dia e noite | Noite mais perigosa, visão menor | M2 (Should) | Cortável |
| Sede | Não | M2 Could | **Cortar** |
| Temperatura (hipertermia e hipotermia) | **Fora, sem marco (decisão do dono, 06/11)** | -- | Fora |

**CONFLITO 2 (número)**: fome com 0,5/s esvazia em 200 s (3,3 min) [calculado]. Numa sessão de 45 min são 13 esvaziadas, ou comer a cada ~3 min. É tarefa, não decisão. **Recomendo 0,1/s**: 1000 s = 16,7 min, e uma baga restaurando 25 [premissa] dá 1 baga a cada ~4 min. Ainda exige comida, sem virar relógio. [jogar]. O plano não fixa o valor, então é ajuste de dado, não de escopo.

Dano de fome 5/2 s = 2,5/s: com vida 100 [premissa, conferir] mata em 40 s. Combina com "risco legível" só se a barra avisar bem (HUD).

### 5.1 Atributos, níveis e pontos (conjunto do MVP)

**Decisão do dono (06/11):** níveis concedem **pontos que o dono distribui**, no dino e no personagem, na **versão enxuta** abaixo. Isto **substitui** a versão "sem pontos e sem nível de jogador" e **conflita com o plano** (seção 9 e conflito 14). Atributos: **Vida, Dano, Stamina, Peso**; **Fome** e **Torpor** são medidores; **Velocidade** é fixa por espécie. Fórmulas do dino selvagem em `racao.md` 10.2; simulação em `pontos_sim.py`.

| Atributo | Natureza | Jogador (base) | Dino (base) | Ponto vale (jogador e dino) |
|---|---|---|---|---|
| **Vida** | pontos | 100 | por espécie | +6% da base (jogador +6) |
| **Dano** | pontos | multiplica dano e **torpor imediato dos golpes corpo a corpo** (Soco, Bastão 2 e 30); não multiplica flecha, besta nem fruta (5.4) | por espécie | +6% da base |
| **Stamina** | pontos | 100 (dreno 25/s, regen 15/s; gasta em sprint, golpe e coleta: 5.8) | **reservada**, sem ponto na 0.2 | +6% da base (jogador +6; sprint +0,24 s) |
| **Peso** | pontos | 50 kg | por espécie | +6% da base (jogador +3 kg) |
| **Fome** | medidor | 100, queda 0,1/s | fixo por espécie | nenhum |
| **Torpor** | medidor, só dino | n/a | máximo pela fórmula do nível | nenhum |
| **Velocidade** | fixa | 70 andar, 120 correr | da espécie e da Conduta | nenhum, **sem evolução** |

**Fora do MVP:** oxigênio, sede, resistência a torpor como atributo, habilidade de crafting, velocidade evoluível. **Temperatura fora, sem marco**: roupa e mobília não têm efeito térmico. Regra única e fácil de explicar: **1 ponto = 6% do valor base**, igual para os quatro atributos e para jogador e dino. A velocidade evoluível sai por conta: Utahraptor L30 corre igual ao L10, e o perigo vem de Vida e Dano.

#### Pontos, XP e níveis: versão enxuta da 0.2 (decisão do dono, 06/11)

**Substitui o pilar "sem nível de personagem"** (seção 9, conflito 14). A versão completa (teto por atributo, respec, XP por ofício, Peso por pontos do dino, atributos de 30 níveis) vai para **depois da 0.2**.

**Regras fechadas (v0.2):**
1. **Jogador:** nível 1 a **20**, **1 ponto por nível** (19 pontos), 4 atributos: Vida, Dano, Stamina, Peso. **1 ponto = +6% da base.** Dano do jogador multiplica o **dano e o torpor do golpe da arma** (sem Lança o dano sozinho não serve: ver 5.3).
2. **XP do jogador:** coletar nó +1, craftar +2, **domar `15 + 3 x nível final`**; abater não dá XP. Curva `30 + 15(L-1)`: L10 = 810 XP, L20 = 3.135 XP; a 13 XP/min são **62 min até L10 e 4,0 h até L20** (8 XP/min: 6,5 h; 20 XP/min: 2,6 h) [calculado; ritmo é premissa].
3. **Dino selvagem:** nasce com **nível sorteado dentro da faixa da espécie** e **teto ao nascer** (5.16); stats automáticos (`racao.md` 10.2), sem sorteio por atributo.
4. **Ao domar:** os níveis de bônus da Eficiência vêm **já aplicados, sem pontos** (recomendo). Os stats automáticos congelam no nível final.
5. **Depois de domado:** cada nível por XP vale **1 ponto**, em **Vida, Dano ou Peso** (decidido, 06/11); **Stamina do dino espera montaria**. **Teto de evolução (decisão do dono, 06/11): 2x o nível de doma, e o teto do servidor vence** (5.16); substitui "captura + 10" e o 75 fixo. O teto de 1,5x vale só na domesticação.
6. **XP do dino:** só **companhia**: recebe o mesmo XP que o jogador ganha enquanto está em "seguir" a até 12 tiles. Curva `20 + 10g`: 10 níveis extras = 650 XP = **43 min** a 15 XP/min [calculado].
7. **Morte:** não perde XP, nível nem pontos. **Sem respec** na 0.2 (6% por ponto, 19 pontos: erro barato). **Sem teto por atributo.**
8. **Servidor e co-op:** só o **dono** (quem domou) distribui pontos do dino; o dino compartilhado obedece e não gasta pontos. Pedido `distribuir_pontos(alvo_id, {atributo: n})` conferido no servidor: dono, pontos livres, alvo vivo, até 6 tiles, sem dano recebido em 10 s [premissa]; o servidor deriva os stats e devolve o resultado. **Save:** jogador `{nivel, xp, pontos_livres, pontos{}}`; dino `{nivel_captura, niveis_extras, xp, pontos_livres, pontos{vida,dano,peso}, nome}`.
9. **Chaves de servidor:** `pontos_por_nivel` (1), `valor_ponto` (6%), `multiplicador_xp` (1,0); **tetos de nível são chaves (5.16): `jogador_nivel_max`, `dino_nivel_max`, `dino_nivel_spawn_max`, `dino_teto_multiplicador`, `dino_teto_base`**.

**Tamanho (estimativa minha, premissa; `SHIKAMARU` confirma):** `Attributes` com fórmula e testes 3 h; XP e nível do jogador 2 h; XP de companhia e níveis extras do dino 2 h; `distribuir_pontos` e validação 3 h; tela de pontos jogador e dino 5 h; save e versão 2 h = **17 h**.

**Conta de efeito (`pontos_sim.py build`, jogador L20 com 19 pontos, Bastão 30 de torpor, 0,7 s, sem esquiva):**

| Build | Paquicéfalo L12 | Utahraptor L20 | Triceratops L28 |
|---|---|---|---|
| sem pontos | 4 golpes, 2,1 s | 5 golpes, 2,8 s, 11 dano levado | 8 golpes, 4,9 s, 34 dano |
| tudo Dano (golpe 64) | 2 golpes, 0,7 s | 3 golpes, 1,4 s, 0 dano | 4 golpes, 2,1 s, 0 dano |
| tudo Vida (214) | igual, 3% da vida | 5% | 16% |
| tudo Stamina / Peso | sprint 8,6 s / 107 kg | igual | igual |

Leitura [calculado]: nenhum build quebra, porque **combate é nocaute**, não morte. Dano corta o tempo de nocaute pela metade; Vida absorve o que sobra; Stamina e Peso servem a fuga e logística. **Risco oposto:** os efeitos são pequenos nos biomas da 0.2, e a diferença só aparece com nível 30 a 50 (M4). **Dino (10 pontos, `pontos_sim.py dino`):** Paquicéfalo L18 com tudo em Dano chega a x1,92 de dano (x1,32 sem pontos); com tudo em Vida, x1,92 de vida; com tudo em Peso, 73,6 kg em vez de 49,6. Triceratops L42 com tudo em Dano: x2,88. Nenhum quebra o combate, porque dino domado luta contra selvagem de nível parecido. **Peso do dino não é obrigatório, é conforto:** viagem de 40 tiles leva cerca de 20 s [8,5 s ida, 8,5 volta, carga]; 3 abrigos (114 kg) pedem 2 viagens com Paquicéfalo L18 (49,6 + 50 kg) e **1 viagem com 10 pontos em Peso** (73,6 + 50 = 123,6 kg): ganho de ~20 s por obra. Risco oposto: poucos põem ponto em Peso; aceitável, é atributo de nicho.

#### Peso (capacidade de carga) [premissas a validar]

Substitui a carga por slots do ofício Carregar. Pesos em kg:

| Item | Peso | Item | Peso |
|---|---|---|---|
| Madeira | 1,0 | Ração (qualquer) | 0,2 |
| Pedra | 1,5 | Flecha (comum e de sono) | 0,05 |
| Carne | 0,5 | Sal-de-veio | 0,5 |
| Fruta-do-sono | 0,1 | Preparado de sono / Carne podre | 0,15 / 0,5 |
| Baga, Samambaia | 0,1 | Tubérculo, Mel-de-cipó | 0,3 |
| Fibra | 0,05 | Bastão-de-sono / Lança-de-pedra | 2,0 / 2,5 |

Capacidade: **jogador 50 kg** + 3 kg por ponto (10 pontos = 80 kg). Dino (base no nível 10, kg): Paquicéfalo 40, Parassaurolofo 100, Triceratops 120, Gallimimus 25, Utahraptor 0 (não carrega). Com a fórmula [calculado, `nivel_sim.py niveis`]: Paquicéfalo 40/52/64 em L10/20/30; Parassaurolofo 100/130/160; Triceratops 120/156/192; Gallimimus 25/32,5/40.

Contas de referência:
- **Abrigo mínimo** (seção 8): 32 madeira + 4 pedra + 1 fibra = 38,05 kg, **76% da capacidade** do jogador: cabe em uma viagem. Dois abrigos (76 kg) pedem 2 viagens a pé, ou uma com um Paquicéfalo L10 (40 kg) junto.
- **Kit inicial** (10 baga, 4 carne, 3 samambaia): 3,3 kg, 7%.
- **Ração para domar** o Triceratops L28 em C (21 rações): 4,2 kg; nunca é o gargalo.
- **Slots** continuam só como exibição: 40 slots fixos nunca limitam, pois o MVP tem cerca de 26 tipos de item (6 recursos, 3 plantas, 10 Rações, dardo, 2 armas e ingredientes) [calculado, contagem].

**Ao passar do limite (recomendação mais simples):** **impedir pegar** acima de 100%, sem lentidão. Coletar de um nó cheio não gasta o nó; a mensagem diz "peso máximo". Excesso só nasce por produção ou recuperação de corpo, e então o jogador fica acima do limite sem poder pegar mais nada até gastar peso. **Lentidão por sobrecarga** (x0,8 acima de 100%) fica como opção de servidor desligada, para o M4: exige regra de velocidade no servidor e interface; o ganho no MVP é pequeno.

**Ofício Carregar:** o dino com Afeto de 10 ou mais e a ordem "seguir" carrega um **alforje**, que é o `InventoryComponent` dele com limite de peso igual ao seu Peso. O jogador abre o alforje ao lado dele; é o mesmo inventário que já recebe a Ração na domesticação. Se o dino fica ferido (seção 6.8), o alforje fica no lugar e é recuperável. O Peso do dino **não soma** ao do jogador: dois limites, uma única regra simples.

#### Stamina do dino
Não faz diferença no MVP e **recomendo adiar**: não há montaria nem combate de dino domado que gaste fôlego, e o dino domado segue sem custo. No selvagem, a perseguição e a fuga já têm tempo fixo por Conduta (8, 10 e 15 s), sem stamina. Se um dia a stamina do selvagem substituir esses tempos (fuga = stamina / dreno), o nível a ampliaria em 20% por 10 níveis, mas isso muda números já decididos da Conduta. **Reservar a fórmula no dado (M4, montaria), sem usar na 0.2:** a Stamina do dino **não aceita pontos** até haver montaria ou combate de dino com fôlego.

#### Onde os atributos antigos aparecem e o que muda
| Onde | Antes | Agora |
|---|---|---|
| GDD 6.4 e racao 10.8 (Carregar) | carga em slots: 8, 10 e 13 em L10, L20 e L30 | Peso em kg (tabela acima) |
| racao 10.2 (fator de ofício 0,03) | carga e dano de defesa | 0,03 só para **Peso**; dano de defesa passa a usar o **Dano** (0,04): Utahraptor base 8 vai a 14,4 em L30 (antes 12,8) |
| racao 10.2 (velocidade `x(1+0,005(L-10))`) | evoluía | **removida**; fixa por espécie; as simulações já usavam velocidades fixas |
| racao 10.2 (consumo de fome `x(1+0,01(L-10))`) | crescia | **removido** |
| GDD 10 (ralos) e racao 4.3 | "stack e carga limitam" | stack mais Peso |
| Jogador | stamina, vida, fome em código | + Peso 50 kg, nível, XP e pontos |

### 5.2 Barra de atalhos (teclas 1 a 9) [decisão do dono]

Nove posições na parte de baixo da tela. **Concordo com o M1**, porque resolve "comer do inventário" e a troca de arma; só a parte de dino (Ração e dardo) é M2.

- **Fruta e preparado de sono:** ver 5.5. **Regra do dono (06/11): a tecla de atalho sempre faz o jogador consumir.** A fruta-do-sono apertada **come no jogador** (pede segundo aperto em 1,5 s); a Ração **o jogador nunca consome** (decidido); **o preparado de sono também não (decidido 06/11): só vai ao dino pela tela dele**. Dar ao dino **nunca** é pela tecla (5.13).
- **Atribuir:** arrastar do inventário ou, com o cursor sobre o item, apertar a tecla. O atalho aponta para o **id do item**, não para o slot. Mostra a **soma** das pilhas; com 0 fica **apagado mas atribuído** e volta quando houver estoque.
- **Usar (tecla):** comida (baga, carne, samambaia, fruta-do-sono): **o jogador come 1** e restaura fome; **não gasta** se a fome está cheia. Arma ou ferramenta: **equipa**; apertar a tecla do item já equipado **desequipa** (mãos livres). Só arma e ferramenta trocam o equipado. **Ração: o jogador nunca consome (decisão do dono, 06/11); só o dino**, a tecla não age. **Preparado de sono: o jogador não consome (decidido 06/11); só vai ao dino pela tela dele (E).**
- **Dino (alinhado à regra do dono, 06/11):** a tecla **nunca** age sobre o dino. No **domar ativo**, a comida (Ração, baga, carne, fruta e preparado de sono) vai pela **tela de inventário do dino, aberta com interagir (E)**, e **o dino come de lá** (já implementado). No **domar passivo**, pelo slot de Oferta (5.13).
- **Cooldown [premissa]:** comida do jogador 0,5 s; troca de equipamento 0,3 s; O intervalo entre Rações vale na tela do dino (`racao.md` 1), e recusar não gasta.
- **Co-op:** a tecla envia `usar_atalho(item_id)` (sem alvo); o servidor valida item, quantidade, cooldown e se o jogador está vivo; **o cliente não decide consumo**. Dar ao dino é pedido separado `alimentar_dino(dino_id, item_id)` da tela do dino. A atribuição é do perfil do jogador (UI), salva com ele, sem validação.
- **Sem munição na v0.2:** Rifle e Dardo foram adiados sem marco (5.4); a flecha (M4) é munição do Arco e da Besta e **não está na barra de atalhos da v0.2**.
- Pode conflitar com ações de teclado de 1 a 9 que o jogo já use (`SORA` confere o mapa de entrada).

### 5.3 Camada 1 de corte: fora da 0.2 (decisão do dono, 06/11)

> **Revisto (06/11, dono):** a **Lança volta como Lança de madeira** (5.4) e **Dodo e Listro entram** como presas pequenas (6.1); o resto da camada 1 segue fora (Gallimimus, Ração S, Mel, Temperamento, dia e noite, configurações, música, NET-03, vocalizações). O parágrafo 1 abaixo vale para **antes** da Lança: com ela, ver 5.4.

**Fora da 0.2:** Arco, Flecha, Boleadeira e Besta (M4 a M5; Rifle, Dardo, arma de fogo, pólvora, fósforo e sílex **sem marco**), Bastão reforçado e Cama (cortados), Traje de fibra (depois do playtest), Listro (M4 com o Oviraptor), slot de Oferta (depois do playtest), Lança-de-pedra, Gallimimus, Ração S e Mel-de-cipó, Temperamento do domado, dia e noite, configurações, música, NET-03 e vocalizações por limiar. A **pausa de torpor já está implementada**: fica, sem custo novo. Tudo continua documentado como futuro. **Mantidos:** Peso, batismo (6.9) e barra de atalhos (5.2).

**1. Sem Lança, como o jogador lida com o Utahraptor?** O Bastão (dano 2) **não mata**: 40 golpes em 27 s, 18 mordidas de 8 = 144 de dano contra 100 de vida [calculado]. O caminho é **nocautear**: Utahraptor L20 (torpor 144) cai em 5 golpes, 2,8 s, com 1 mordida (11 dano); com 10 pontos em Dano, 3 golpes e 1,4 s. Ele dorme cerca de 103 s, mais que os 40 s de domar um Paquicéfalo em C. O que muda: **o ponto de Dano do jogador** passa a multiplicar também o torpor do golpe (é o menor ajuste que dá uso ao atributo sem Lança), e a regra "abaixo de 25% de vida foge" fica sem uso até haver dano maior (sem custo).

**2. Proteger o dormindo continua viável?** Utahraptor L20 mira um Paquicéfalo dormindo (aviso 3 s, mordida a cada 1,5 s, 14,5 E por mordida). **Um Utahraptor:** jogador a 2 tiles, 0 mordidas; chegando 2 s depois, 2 mordidas (-29 E); 4 s depois, 3 (-43 E). **Bando de 2 ou 3:** de -43 a -102 E. Conta falha com bando. **Menor ajuste, sem Lança:** (a) o Utahraptor é **solitário na 0.2** (bando vai ao M4, com curral e dino defensor); (b) o **primeiro golpe do jogador provoca**: o carnívoro troca de alvo para ele (a regra de provocar já existe), o que zera as mordidas no dormindo quando o jogador chega dentro do aviso de 3 s e deixa só -14,5 E se chegar depois. É regra de dado, sem Lança. Medido por `pontos_sim.py protecao`; **precisa jogar** para ver se 3 s de aviso é legível.

**3. Sem Ração S, a escada fica Baga, C, B, A** (`racao.md` 1, 12). Conta com `nivel_sim.py eficiencia` (caso médio, nível final): Triceratops L28 C 30, B 34, A 36; Parassaurolofo L20 C 24, B 25, A 26; Utahraptor L15 B 19, A 19; Paquicéfalo L8 B 10, A 10. A escada **ainda paga no Triceratops e no Parassaurolofo** e é plana nos pequenos (A só poupa 6 a 17 s). `racao_minima` (Paquicéfalo C, Utahraptor B, Parassaurolofo C, Triceratops A) continua válida: o topo exigido é A. A **Eficiência máxima real na 0.2 é 78 a 92%** (A, caso bom), não 100%: o bônus real é de +39% a +46%, não +50%. Sem S+ (M4) e sem S, **ninguém tem dreno 0**; o dardo (-2 E) continua melhor que golpe.

**4. Tipos de Conduta na 0.2: 4 confirmados** (Passivo, Agressivo, Semi-agressivo, Medroso). O Covarde sai com o Gallimimus; o Temperamento (do domado) também. A conta de fuga fica só no Parassaurolofo (75 px/s, alcançável).

### 5.4 Armas, torpor contínuo e sono (decisão do dono, 06/11)

**Regra do dono:** (1) **só dano, torpor zero:** flecha comum, besta, espada, lança; (2) **dano e torpor em valores próprios:** soco, porrete (o **Bastão-de-sono**) e flecha de sono; (3) **torpor contínuo:** a flecha de sono segue aplicando torpor por um tempo depois de acertar. **Rifle, Dardo e qualquer arma de fogo: adiados sem marco (decisão final do dono, 06/11).** Simulação: `armas_sim.py`.

| Arma | Dano | Torpor imediato | Contínuo | Cooldown | Munição e recarga | Alcance | Marco |
|---|---|---|---|---|---|---|---|
| **Soco** (sem item) | 1 | 10 | -- | 0,6 s | -- | 1 tile | M1 |
| **Bastão-de-sono** (porrete) | 2 | 30 | -- | 0,7 s | -- | 1,5 tiles | M1: **nasce no inventário, sem receita**; a receita (Saber 1) repõe no M2 |
| **Lança de madeira** | 12 | 0 | -- | 0,9 s | -- | 1,8 tiles | M1, **conhecida** |
| **Flecha de sono** (Arco) | 1 | 15 | 12/s por 5 s (60), total 75 | 1,2 s | 1 flecha (4 flechas comuns + 1 Preparado rendem 4); armar 0,6 s incluído | 10 tiles | M4 |
| Flecha comum (Arco) | 14 | 0 | -- | 1,2 s | 1 flecha | 10 tiles | M4 |
| **Boleadeira** (arremesso, 1 uso) | 0 | 0 | prende: velocidade x0,4 por 5 s | 8 s entre arremessos | 1 por arremesso (2 corda + 2 pedra, Mãos) | 6 tiles | M4 |
| **Besta** (usa a mesma flecha) | 22 | 0 | -- | 2,0 s (arma e dispara) | 1 flecha por tiro | 14 tiles | M5 (Bancada, metal) |
| Espada | 20 | 0 | -- | 0,9 s | -- | 1,5 tiles | M4 a M5, **depois da 0.2** |
| ~~Rifle, Dardo, pistola e arma de fogo~~ | | | | | | | **adiados sem marco (decisão final do dono, 06/11); a exceção do Rifle de mola deixa de existir** |

**Lança de madeira (decisão do dono, 06/11).** Dano **12**, torpor **0** (conta como dano puro na regra de armas), recarga **0,9 s**, Stamina **5** por golpe, alcance **1,8 tiles**, custo **2 graveto + 3 madeira**, receita conhecida, feita à mão. Durabilidade 80 (5.9). **É também a ferramenta de abate e de coleta de carcaça** (5.6). Conta (`durab_sim.py lanca`): **Dodo (vida 24) em 2 golpes, 1,8 s; Listro (36) em 3 golpes, 2,7 s; Utahraptor L20 (126) em 11 golpes, 9,9 s, 5 mordidas de 7,5 dps = 37 de dano e 55 de Stamina**. Contra o Utahraptor ela **ajuda pouco**: a Lança de 18 do desenho antigo fechava em 7 golpes e 5,4 s; esta é **de abate de presa, não de duelo**, e o caminho do Utahraptor continua sendo **nocautear com Bastão** (5 golpes). **Espada** (20, 0,9 s) entra depois, no M4, sem mexer no corte da v0.2.

**Armas à distância (decisão final do dono, 06/11; números nossos [premissa]).** **Sem pólvora, sem arma de fogo, sem Rifle e sem Dardo: adiados sem marco**, e com eles o **fósforo e o sílex** (5.18). Ficam **arco, besta e boleadeira**, todos de material primitivo ou mecânico. **Marco recomendado:** **M4** Corda (Saber 1), Arco (Saber 2), Flecha comum (2), **Flecha de sono (2)** e Boleadeira (2); **M5** Besta (Saber 4, Bancada). **Tudo à mão, exceto a Besta** (regra de produção, 5.19).
- **Arco** (3 madeira + 2 corda; durabilidade 120 tiros; Stamina 4 por tiro; 10 tiles): **Flecha comum** (2 graveto + 1 pedra + 1 fibra rendem 4; dano 14, torpor 0). **Flecha de sono (entra, recomendo):** 4 flechas comuns + 1 **Preparado de sono** rendem 4 flechas de sono; dano 1, imediato 15, contínuo 12/s por 5 s, **total 75**; **dá ao Preparado um segundo consumidor** (a mão do jogador só o craftar; quem o consome continua sendo o dino, pela tela dele). Conta (`armas_sim.py arco`): nocaute acordado em **3,3 s (Paquicéfalo), 4,1 (Utahraptor), 4,9 (Parassaurolofo) e 6,0 s (Triceratops L28)** = 3, 4, 5 e 6 flechas = **0,75 a 1,5 Preparados**; contra 2,1 a 5,6 s do Bastão, mas **a 10 tiles e sem exposição**. Custo de coleta [premissa]: flecha de sono 3,8 s por dose (`armas_sim.py custo`).
- **Besta** (5 madeira + 2 barra + 2 corda; dano 22, torpor 0; 2,0 s de recarga; 14 tiles; durabilidade 120): mesma flecha. **Vale pelo dano por tiro e alcance, não pela cadência:** Utahraptor L20 em 6 tiros e 12 s contra 9 flechas e 10,8 s do Arco. Custo em metal: 2 barras. **Cortável sem efeito no resto** (a flecha de sono é do Arco).
- **Boleadeira** (2 corda + 2 pedra; 1 uso por arremesso; 6 tiles): **prende, não nocauteia** (velocidade x0,4 por 5 s, dano 0, torpor 0). Função: é a resposta ao Medroso sem Arco e a fuga de emergência. **Sem Medroso o Arco já resolve (`armas_sim.py fuga`: nocaute em 4,8 s a 160 px), então a Boleadeira é a mais cortável**; só fica se o playtest pedir um item de utilidade barato.
- **Rifle de dardos e Dardo:** **fora**. Saem os números antigos (18 + 9/s por 6 s, pente de 4, recarga 3,5 s, 12 tiles); ficam só como registro no histórico do `racao.md`. Triceratops L28 e acima: ver 5.15.

Todos os valores são [premissa a testar]; o cálculo e as consequências vêm abaixo.

**Fórmula.** Torpor atual: `T(t+dt) = clamp(T + (soma das taxas ativas - queda) x dt, 0, máx)`; o imediato soma no acerto. Queda real do código: **5/s acordado, 1/s dormindo** (`TorporComponent`). Dose da flecha de sono = **75 total** (15 + 12 x 5). Efeito líquido de **uma** dose em dino acordado: `15 + (12-5) x 5 = 50`: sozinha **não** nocauteia ninguém (o menor torpor máximo é 104).

**Acúmulo (recomendo): soma até 3 efeitos ativos; o 4º renova o mais antigo.** O teto é **compartilhado** entre flecha de sono, fruta e preparado e vale por alvo. Motivo: renovar sem somar deixaria a flecha sem efeito acordado; soma sem teto faria dela um nocaute instantâneo. Conta (`armas_sim.py arco`, uma flecha a cada 1,2 s, queda 5/s): Paquicéfalo L12 nocauteia em **3,3 s**, Utahraptor L20 em 4,1 s, Parassaurolofo L20 em 4,9 s, Triceratops L28 em 6,0 s, contra 2,1, 3,5, 4,2 e 5,6 s do Bastão (`armas_sim.py ko`): o Arco é cerca de 1,2 a 1,6 vezes mais lento, mas **a 10 tiles**. Escolha real: Bastão rápido e exposto, Arco seguro e lento, **e gasta flecha** (0,75 a 1,5 Preparados por nocaute).

**Efeitos.** Acordado: o torpor sobe e passa pelas faixas (bocejo, passo x0,85, x0,65 com pausa); **nocauteia depois de alguns segundos** conforme a conta acima. **Dino que foge (Medroso, `armas_sim.py fuga`):** Parassaurolofo L20 (75 px/s), jogador a 80 px, flecha a cada 1,2 s a 160 px de alcance: **faixa 2 em 2,7 s e nocaute em 4,8 s**; o Arco é a **resposta ao Medroso** sem depender de sprint. Soco contra o Utahraptor L20: 21 golpes, 12 s, inviável (o ponto é empurrar para o Bastão).

**Flecha de sono e Eficiência.** A flecha em dino **dormindo** custa **-2 de Eficiência por dose** (sem dano). O torpor contínuo **não conta como ataque** ao dormindo (sem dano, sem custo extra, sem acordar nem atrair carnívoro). Em dino **acordado** não custa Eficiência (ela só começa no nocaute). Flecha comum, besta e espada em dormindo são ataque normal (4 ou 8 de Eficiência fixa + 0,5 x % da vida; `racao.md` 11). **Dormindo, fruta e preparado não gastam Eficiência**: para manter o torpor basta 1 preparado por minuto (`armas_sim.py dormindo`).

**Atributo Dano do jogador:** passa a multiplicar **dano e torpor imediato dos golpes corpo a corpo** (Soco, Bastão); **não** multiplica flecha, besta, fruta nem preparado (valor do item). Com 10 pontos: Bastão 48 em vez de 30 (Utahraptor L20 cai de 6 para 4 golpes).

**Armas de fogo: fora do jogo (decidido, 06/11); sem marco, nem na 1.0.** Não combinam com o tom (sobrevivência com pedra, fibra e Ração) nem com a progressão. **Sem Rifle, sem Dardo, sem pólvora, sem fósforo e sem sílex.** Arco e flecha no **M4**, besta no **M5**, **fora da 0.2**.

**Impacto no M1 e M2.** **M1:** Soco e **Bastão-de-sono no inventário desde o início, sem receita** (30 de torpor, 0,7 s). **M2:** a receita do Bastão (Saber 1) repõe; **nenhum dardo na 0.2**. **Custo novo [estimativa minha, premissa; `SHIKAMARU` confirma]:** efeitos de torpor contínuo com teto e save 4 h (só no M4, para a flecha de sono; a 0.2 só tem fruta e preparado, 5.5); Arco, flecha, besta e boleadeira no M4 a M5: `WeaponDef` com projétil 8 h, Besta 2 h, Boleadeira 3 h [estimativa].

### 5.5 Fruta-do-sono, preparado de sono e carne podre (decisão do dono, 06/11)

**Fruta-do-sono.** Nasce em arbusto da **Mata-baixa**; nó com 3 frutas, 4 s por fruta, respawn de 6 a 8 min (como o Tubérculo) [premissa]; 0,1 kg, pilha de 20. **Efeito:** 6 de torpor por segundo durante 5 s (**30 no total**, sem imediato); **não é comida** (não dá fome, não é refeição, não conta para domar, não gera agitação). **Marco M2.**

**Preparado de sono.** Receita na bancada comum: **3 frutas-do-sono + 1 carne podre rendem 3 preparados**, 4 s. Efeito: 12/s durante 5 s (**60 cada**); só se dá a **dino** (o jogador não o usa; sem acidente). Peso 0,15 kg. **Marco M2, cortável.**

**Carne podre (revisto 06/11, dono): vem de duas fontes que coexistem.** (1) **Carcaça velha**: a carcaça não coletada vira carniça aos 10 min (5.6). (2) **Pilha de carne que vence** no inventário, baú, cocho ou alforje (5.9): a pilha vira `ceil(n/4)` de carne podre. Isso **substitui a recomendação anterior (V31: carne que não estraga, nó de Carniça)**: o **nó de Carniça sai**, a carniça é só um estado da carcaça. Carne podre: 0,5 kg, **comível** com pequeno dano (5.10), ingrediente do preparado e **não vence**. Oferta contra demanda: `durab_sim.py oferta` (cada caçada larga carcaças; a demanda é 1 por 3 preparados, 2 por domesticação).

**Conta de custo** (`armas_sim.py custo`): flecha de sono = 3,8 s por dose de 75 (0,051 s/torpor) mais -2 E em dormindo (de 2 a 8 s por E: **0,1 a 0,3 s/torpor a mais**); fruta = 4 s por 30 (**0,133 s/torpor**, 0 E); preparado = (3 x 4 + 4 + 4) / 180 = **0,111 s/torpor**, 0 E. Em dormindo, **a fruta e o preparado vencem a flecha** (sem gastar Eficiência). Em dino **acordado** a flecha de sono (M4) é única (alcance 10 tiles); **na 0.2 não há arma de torpor à distância**, só Bastão, fruta e preparado.

**Jogador que come fruta** (`armas_sim.py jogador`; torpor máx. 100, queda 5/s, cap 3 efeitos, 0,5 s entre frutas): 1 fruta = +5 (sem sinal); 2 = pico 33 (faixa 1, bocejo); 3 = 60 (faixa 2, lento); 6 = 80 (faixa 3, pausas); **9 = dorme**. Sono [premissa]: acorda em 30 de torpor, queda de 3/s dormindo = **23 s**; **dano acorda**; aliado acorda segurando a interação 2 s. É **só risco**, sem ferramenta: não dá fome nem benefício. **Co-op:** sem PvP; ninguém força fruta em outro jogador; o aliado acorda quem dormiu. **Recomendo no M2: sinais (faixas 1 a 3) e sem sono**; o sono do jogador (bloqueio de entrada, câmera, acordar) fica para o M4: é a parte cara.

**Dino dormindo: forçar é manual, pela tela de inventário do dino (interagir E), sem tecla de atalho (regra do dono, 06/11).** Abrir a tela do dino e escolher fruta ou preparado; o dino consome de lá. Automático não: tiraria a vigilância, o centro da domesticação. Cada item leva **1,5 s de ação** e há **3 s de espera por dino** entre itens forçados; teto de 3 efeitos ativos. Sem custo de Eficiência. **A queda de 0,3 por segundo dormindo continua**: o dono disse que forçar não custa Eficiência, não que o tempo deixa de pesar. **Não conflita**; se o dono quiser congelar essa queda, o furo reabre (abaixo).

**Reabre o furo de torpor grátis? Não, com limite mínimo.** O furo original era golpe grátis em dormindo (resolvido pelo custo em Eficiência: continua). Manter o torpor de um dormindo exige 60 a 90 torpor por minuto (queda 1,0 a 1,5/s): **2 a 3 frutas por minuto** = 8 a 12 s de coleta e 3 a 4,5 s de ação por minuto, **cerca de 20% do tempo**, sem Eficiência. Mas domar dura no máximo 105 s e **o que fixa a qualidade da Ração é a Eficiência por refeição e por tempo (0,3/s: 100 s custam 30)**, que continua. Efeito medido: Parassaurolofo L20 com Baga (18 refeições, 108 s, janela 137%) precisava de 2 doses de flecha de sono (-4 E); com 2 frutas +4 E, **meio nível a mais**. **Limite mínimo (já no desenho):** manter a queda de 0,3/s e o dreno por refeição; ação de 1,5 s por item; espera de 3 s por dino; teto de 3 efeitos; frutas finitas (respawn). Se um teste mostrar domação sem pressão, o primeiro botão é **aumentar o tempo de ação** (2,5 s).

**V6 revisto:** a flecha de sono (M4) deixa de ser a "manutenção barata" do dormindo; é a **ferramenta de dino acordado**; fruta e preparado são a manutenção.

**Atalho (1 a 9), evitar erro:** a tecla da fruta-do-sono **come no jogador** (segundo aperto em 1,5 s: "comer fruta-do-sono?"); a do preparado **não faz nada** (é para o dino, pela tela). Ícone roxo distinto da baga; a baga e a carne nunca dormem ninguém.

**Estimativa [premissa; `SHIKAMARU` confirma]:** nó e item da fruta 2,5 h; forçar o dino pela tela dele (já implementada; só validação e o teto de 3 efeitos) 1 h; sinais de torpor no jogador com o mesmo componente 2 h; Carniça e item 1 h; receita do preparado 1 h = **7,5 h**; sono do jogador M4 (+4 h). **Menor recorte da 0.2:** fruta forçada no dino e sinais no jogador; **preparado e Carniça cortáveis** (+2 h); sem sono do jogador.

### 5.6 Carcaça e sacolinha (decisão do dono, 06/11)

Animal morto deixa **carcaça** coletável; os itens podem virar **sacolinha** no chão. Simulação: `carcaca_sim.py`.

**Rendimento** = `base x (1 + 0,03(L-10))` (piso 0,7, o mesmo fator do Peso), arredondado [premissa]. Tempo **1,5 s por carne e 3 s por couro, com Lança ou Espada** (**sem ferramenta não se coleta carne nem couro**; mãos só pegam item solto e sacolinha), Stamina **3/s**, **1 de durabilidade da arma por carcaça**; peso 0,5 kg a carne e 0,4 kg o couro; carne dá **25 de fome** (baga 10) [premissa, o código ainda não define].

| Espécie (base: carne / couro) | Nível típico | Carne | Couro | Tempo | Peso | Fome da carne |
|---|---|---|---|---|---|---|
| Paquicéfalo (4 / 1) | L12 | 4 | 1 | 9 s | 2,4 kg | 100 (17 min) |
| Utahraptor (5 / 2) | L20 | 6 | 3 | 18 s | 4,2 kg | 150 (25 min) |
| Parassaurolofo (10 / 3) | L20 | 13 | 4 | 31,5 s | 8,1 kg | 325 (54 min) |
| Triceratops (14 / 5) | L28 | 22 | 8 | 57 s | 14,2 kg (28% do Peso) | 550 (92 min) |
| Artrópode gigante (pós-MVP, cavernas) | -- | **quitina** no lugar do couro | | | | |

Triceratops L42 (domado que morreu): 27 e 10, 70 s. Coleta **parcial** permitida (a barra pode ser interrompida e retomada); interromper por mover mais de 3 tiles ou por dano.

**Quanto tempo ficam [premissa]:** carcaça **fresca 10 min**; de 10 a 20 min vira **carniça** (só carne podre: `ceil(carne/4)`; Triceratops L28 dá 6) e some aos 20 min; **sacolinha 10 min**; no máximo **8 carcaças e 20 sacolinhas** no mundo (a mais antiga some). Save: menos de 2 KB. Isso dá a **carne podre** (5.5) sem nenhuma regra de estragar no inventário e permite cortar a Carniça-nó se o teste mostrar oferta suficiente.

**Co-op:** qualquer jogador coleta carcaça de selvagem e sacolinha (sem PvP; cooperativo). A carcaça e a sacolinha do **dino do dono** são **só do dono por 120 s**, depois de todos. Tudo é pedido validado no servidor: `coletar_carcaca(id, item)` e `pegar_sacolinha(id)` conferem existência, distância (até 2 tiles), tempo, dono e **Peso** (o que não cabe fica na sacolinha); o servidor é quem remove a unidade.

**Fome, Ração, Peso e XP.** A carne da carcaça é a mesma **Carne** do inventário: fome e Ração Rubra; **vence** como pilha (5.9) e vira carne podre; carne podre também vem da carniça. **Peso:** coletar além do limite deixa o resto na **sacolinha** ao lado; o jogador volta ou chama o dino de carga. **Abater continua sem XP e coletar carcaça também não dá XP** (não é nó): sem fazenda de nível. O jogador não abate com o Bastão (dano 2); as carcaças vêm de carnívoro, de dino defensor e de morte permanente de domado (opção de servidor).

**Dino domado que morre (esta resposta ao `LEVI`: sim).** Os itens do alforje, **inclusive a comida que sobrou**, vão para a **sacolinha** na carcaça (só do dono por 120 s). Se o dino fica só **ferido** (padrão da 0.2), o alforje fica no lugar (6.8). O corpo do **jogador** morto continua na regra `morte_item` existente.

**Fonte de carne (resolvido 06/11, dono): Lança, Dodo e Listro.** O furo apontado pelo `SHIKAMARU` (Bastão não abate) fecha com a **Lança de madeira** e **presas pequenas e abundantes**. **Presa abatida e nó de Carniça saem** (V48 resolvido). Conta (`durab_sim.py oferta`):

| Item | Valor |
|---|---|
| Dodo L8 | 2 carne + 1 couro, ciclo de ~30 s (alcançar, 2 golpes, coletar 6 s, voltar) |
| Listro L12 | 3 carne + 2 couro, ciclo de ~38 s |
| Demanda Utahraptor L15 | Rubra B 11 carne = 6 Dodos, 3 min; A 10 = 5; **C ~25 = 13 Dodos, 6,5 min** (5.14) |
| Rebanho de Utahraptor | 14,4 carne/h cada [premissa: 25 de fome por carne]; 5 deles = 72/h = 36 Dodos |
| Oferta (spawn 12 Dodos + 8 Listros por zona, respawn 10 min) | teto de 120 animais/h = 240 + 144 = 384 carne/h |

**Cobre com folga (uso de 19% do teto com 5 Utahraptors).** O **domar do Utahraptor fica no M2** (precisa da carcaça M2, da Lança e do Dodo); no M1 o Utahraptor é só ameaça. Dino morto por outros dinos não é fonte. **M1:** a Lança caça mas **ainda sem carcaça** (a carcaça é M2); **no M1 não há presa: o Dodo chega no início do M2** (decisão do dono, 06/11), como alvo e XP.

**Couro:** sem sumidouro na 0.2 (**o Bastão reforçado foi cortado, 06/11**): o couro cai como dado e só tem uso no M4 (Traje de couro e Arco). Quitina só com as cavernas.

**Marco e custo [estimativa minha, premissa; `SHIKAMARU` confirma]:** M2. Carcaça e coleta com barra parcial 5 h; sacolinha (entidade, pegar, excesso, morte do dino) 3 h; save e validação 3 h; interface (barra, lista de itens) 2 h; = **13 h** (sem o Bastão reforçado, -1 h). **Menor recorte da 0.2:** só carne (couro como dado, sem uso), coleta de uma vez, sacolinha só para excesso e dino morto, sem carniça envelhecida = **9 h**.

### 5.7 HUD do jogador (decisão do dono, 06/11)

**Visíveis:** barra de **vida**, barra de **fome**, barra de **XP** e a **barra de atalhos 1 a 9** (5.2). **Sem sede** por agora, **sem barra de stamina**, sem temperatura. M1: vida, fome e atalhos; M2: XP e aviso de ponto.

**Stamina por comportamento, sem barra.** O atributo existe e limita a corrida (dreno 25/s, regen 15/s, retoma com 20; sprint de 4 s, mais 0,24 s por ponto). Sinal em duas etapas [premissa]: (1) abaixo de **25%** (cerca de 1 s antes de zerar, a 25/s) começa um **ofegar** de som crescente; (2) ao **zerar**, o personagem **ofega e para de correr**, e golpes e coleta ficam mais lentos (5.8): anda a 70 até recuperar 20, o que leva **1,3 s** (20/15) [calculado], com som de fôlego e uma pequena nuvem de suor. Sem janela nem texto. Em co-op o estado "ofegante" é um bit replicado, para os outros jogadores ouvirem. O jogador aprende a duração do sprint pelo uso; a tela de atributos mostra "sprint X s" ao distribuir pontos. Golpes e coleta gastam fôlego (5.8) e o mesmo sinal vale.

**Nível e aviso de ponto, o mínimo:** (1) a **barra de XP** fica fina, acima dos atalhos, com **"Nv N"** no começo; (2) um **único selo** ao lado do nível aparece **só quando há algo a gastar** (ponto de atributo livre, ou Saber suficiente para a receita aprendível mais barata) e pulsa devagar, **sem janela nem interrupção**; (3) **uma linha de aviso de 3 s** ao subir de nível ("Nível 7: +1 ponto, +1 Saber") e um som curto. **Tecla P** abre a tela do **Personagem**, com abas Atributos e Receitas (e depois Equipamento). São 4 elementos fixos (vida, fome, XP, atalhos) mais o selo e a linha de aviso.

**Durabilidade (revisto 06/11, dono): existe, fora da HUD.** Ferramentas, armas e armaduras têm durabilidade individual (5.9). O jogador percebe por **tooltip no inventário, aviso ao ficar baixa e som de quebra**; **nenhuma barra na HUD**. Estimativa de percepção em 5.9.

**Estimativa [premissa; `SHIKAMARU` confirma]:** barra de XP, nível e selo 2,5 h; linha de aviso 0,5 h; estado ofegante com som e partícula 2 h = **5 h** (a barra de stamina, se existir, sai de graça). **`YATORA`:** moldura das 3 barras, ícone do selo, partícula de suor, sons de ofegar e de subir de nível.

### 5.8 Stamina em golpes e coleta (decisão do dono, 06/11)

Golpes e coleta também gastam Stamina. Simulação: `stamina_sim.py`.

**Custos [premissa]:** golpe: **Soco 3**, **Bastão 6**, **tiro de arco 4** (5, 8,6 e 4 por segundo; 33, 17 e 25 golpes até esgotar). Coleta, por segundo de ação: **mãos em madeira e pedra 4/s**, **machado e picareta 3/s**, **baga, fibra, fruta e carcaça 2/s** (a mão em um nó de madeira: 8 s x 4 = 32 por nó, 3 nós seguidos; o machado: 5,2 s x 3 = 15,6). Construir e craftar não gastam. **Regeneração:** 15/s **só depois de 0,5 s sem agir** (sem sprint, golpe nem coleta); sprint 25/s e retomada em 20, como no código.

**Sem Stamina, nada bloqueia (recomendo e adoto):** o golpe sai com **cooldown x1,5 e efeito x0,75**; a coleta leva **x1,5 de tempo**; só o sprint fica bloqueado até recuperar 20 (1,3 s parado). Motivo: bloquear a coleta é espera vazia e bloquear o golpe diante de um carnívoro é espiral de morte. Coleta contínua exaurida roda a 67% da velocidade, contra 79% de quem pausa (15/19): a diferença é pequena, então **a coleta nunca espera, só desacelera**.

**Sinal sem barra (5.7):** o mesmo ofegar cobre tudo: abaixo de 25% (4 golpes ou 6 s de coleta antes de zerar) começa o som crescente; ao zerar, o personagem **ofega** e a **animação de golpe e de coleta fica visivelmente mais lenta**, o que comunica a penalidade sem janela. Sim, o ofego basta.

**Reveja (conta em `stamina_sim.py luta`):**
- **Nocaute do Utahraptor L20 com o Bastão:** 6 golpes = 36 de Stamina, 3,5 s, 2 mordidas (22,4) quando fresco. **Depois de correr 4 s** (stamina 0) o personagem bate exaurido: **9 golpes, 8,4 s, 5 mordidas = 56 de dano**, o dobro. Triceratops L28 pós-sprint: 13 golpes, 12,6 s, 172 de dano (morre).
- **Corrida:** igual (25/s, 4 s); agora **correr e depois lutar custa a luta**.
- **Golpe que provoca:** custa 6 e sai mesmo exaurido (só mais lento); provocar não fica bloqueado.
- **Carcaça de 57 s:** 2/s = 114, esgota aos 50 s e leva **60,5 s**; com 3 pontos (118) não esgota. Irrelevante.

**O ponto em Stamina vale a pena? Sim, por um limiar claro.** Sprint de 4 s (100) mais os 6 golpes do Utahraptor (36) pedem **136: 6 pontos** deixam correr e nocautear sem esgotar (22 de dano contra 56); o Triceratops (9 golpes, 54) pede **154: 9 pontos** (69 contra 172 de dano, pós-sprint). Também dá sprint de 5,4 s com 6 pontos e 6,4 s com 10, e 26,7 golpes seguidos com 10. Contra 6 pontos de Vida (+36 de vida, 3 mordidas): **a Stamina vence quando o jogador corre antes de lutar**, a Vida quando não. Escolha real. Na coleta o ponto vale pouco (~3 s por carcaça grande), aceitável.

**Muda para o `SORA` [estimativa 3 h, premissa]:** `WeaponDef.stamina_cost`; `ToolDef`/coleta com `stamina_per_second`; estado `exhausted` aplicando x1,5 no cooldown e x0,75 no efeito do golpe e x1,5 no tempo da coleta, **no servidor**; regeneração com atraso de 0,5 s; sinal de ofego abaixo de 25% e ao zerar (bit replicado); o ataque atual do `Player` hoje **não gasta Stamina**; sem barra de stamina; teste headless dos custos e do limiar de 6 pontos.

### 5.9 Durabilidade e validade (decisões do dono, 06/11)

Simulação: `durab_sim.py`. **Dois sistemas, um modelo de inventário.** Armas, ferramentas e armaduras têm **durabilidade individual e não empilham**. Comida empilhável tem **validade única por pilha**.

**Durabilidade [premissa; tudo a testar]:**

| Item | Durabilidade | Cai | Rendimento |
|---|---|---|---|
| Lança de madeira | 80 | 1 por golpe, 1 por carcaça coletada | dano 12 |
| Bastão-de-sono | 120 | 1 por golpe | KO de Paquicéfalo em 4 golpes = 30 KOs |
| Machado de pedra | 150 | 1 por segundo de coleta | 0,75 madeira/s (mão 0,375): 112 madeira por durabilidade |
| Picareta de pedra | 120 | 1 por segundo de coleta | 0,80 pedra/s (mão 0,40): 96 pedra |
| Machado e Picareta de ferro (M5) | 300 | idem | 1,31 madeira/s e 1,40 pedra/s: 394 e 420 por durabilidade |
| Espada de ferro (M4) | 250 | 1 por golpe | dano 20 |
| Traje de fibra (depois do playtest), couro (M4), metal (M5) | 100 / 150 / 300 | 1 por golpe sofrido (mesmo se o dano caiu a 1) | redução 10 / 25 / 40% |

**Pedra versus ferro:** 1,75x mais rápido e 2x a 2,5x mais durável = **3,5x a 4,4x de material por ferramenta**. **Mão nunca gasta, mas é metade da velocidade e gasta 4 de Stamina/s** (5.8): o jogador **nunca fica travado**.

**Em zero: a peça fica "quebrada", inútil, **sem desaparecer**, até reparar** (não some: a perda seria punição sem decisão). **Reparo:** na **Bancada**, custo **`ceil(50% do material da receita x fração que falta)`**, 1 s por 10% da barra. Lança 100% gasta: 1 graveto + 2 madeira, 10 s; Machado de pedra: 2 madeira + 1 pedra + 1 fibra. **Não reduz a durabilidade máxima** (recomendo: a redução de máximo cria um ralo de descarte que não pede decisão nova).

**Primeira hora (`durab_sim.py hora`):** 20 Dodos + 1 luta de Utahraptor = 71 de 80 na Lança (0,9 reparo); 86 madeira = 115 s de 150 no Machado (0,8); 40 pedra = 50 s de 120 na Picareta (0,4). **Total ~2,1 reparos, 21 s em 3600 (0,6%), ~6 materiais.** É ruído, não punição. **Antes da Bancada (L2, ~3 min) nada gasta o suficiente para quebrar.** Impacto no **Saber**: nenhum (reparo é material, não Saber). No **Peso**: item individual pesa o mesmo; a Lança 1,0 kg, o Machado 2,0, a Picareta 2,5 [premissa], 5,5 kg dos 50 do jogador (11%).

**Percepção, o mínimo:** (1) **tooltip** no inventário com barra e "x/y"; (2) **aviso a 20%**: texto flutuante curto e som; (3) **som e texto ao zerar** ("quebrou"). **Fora da HUD**. Opcional se faltar: ícone da barra de atalhos esmaecido abaixo de 20%.

**Validade da comida (`durab_sim.py validade`) [premissa]:**

| Item | Validade | Ao zerar |
|---|---|---|
| Carne crua | 30 min | vira **carne podre** (`ceil(n/4)`) |
| Carne assada (Fogueira, 2 s por carne, 1 madeira por 4) | 90 min, +10 de fome | idem |
| Baga | 45 min | **some** |
| Fruta-do-sono | 30 min | **some** |
| Preparado de sono | 45 min | **some** |
| Carne podre, Ração C/B/A, couro | não vencem | -- |

**Regra mais simples.** Cada pilha guarda **`expira_em`** (hora do servidor), sem tique por quadro. **Juntar:** só se juntam pilhas cuja diferença de `expira_em` for **até 2 min**, e a pilha usa a **mais velha** (perde no máximo 2 min de 30, 6,7%). **Dividir:** as duas metades herdam a mesma `expira_em`. **Baú, cocho e alforje:** **mesma regra e corre igual** (não há geladeira). **Carcaça coletada** começa com a validade cheia. **Servidor desligado** não conta (relógio do mundo).

**Domesticação sem surpresa:** (a) a carne do Utahraptor é caçada em 3 a 6,5 min (5.14), **margem de 4,6x a 12x** com 30 min; (b) **aviso a 25%** (7,5 min na carne crua); (c) o **painel de alimentar mostra "vence em N min"**; (d) a **Ração não vence**, então o estoque de Ração C/B/A é seguro; (e) carne vencida vira carne podre e o preparado de sono **ganha** matéria-prima.

**Modelo de inventário (para o `SORA`):** hoje `{id, count}` e a barra guarda tipo. Passa a **`{id, count, expira_em?}`** para empilháveis e **`{id, iid, durab, durab_max}`** (count 1, não empilha) para equipamento; a **barra de atalhos guarda o slot (ou `iid`)**, não o tipo; **slot de "item na mão"** e, no M4, 2 de armadura; save com versão nova; reparo, uso e validade **validados no servidor**. **Menor recorte:** **M1** o modelo novo com durabilidade só da Lança, Machado, Picareta e Bastão; **M2** validade, carne podre, assar, reparo na Bancada e aviso; M4 armaduras. **Custo [estimativa minha; `SHIKAMARU` confirma]:** modelo de inventário e hotbar por slot 12 h; durabilidade, quebra e reparo 6 h; tooltip, aviso e sons 3 h; validade, conversão em carne podre, aviso no painel 5 h; Fogueira (assar) 2 h = **28 h**. Sem isso a Lança de madeira não pode ter durabilidade.


### 5.10 Comida e fome do jogador (decisão do dono, 06/11)

Simulação: `fome_sim.py fome|ciclo`. **Substitui o dano de fome do `HungerComponent`** (queda 0,5/s, em zero 5 de dano a cada 2 s = morte em 40 s [código real]).

**Regras do dono:** carne crua reduz fome sem curar; estragada dá pequeno dano; cozida reduz mais fome e regenera um pouco de vida; acima de 70% de fome (saciedade) regenera pouca vida; com fome 0 o torpor do jogador sobe; em 100% o jogador fica inconsciente por alguns segundos e leva dano até morrer ou comer.

**Valores [premissa; a barra é de saciedade: 100 cheio]:**

| Item | Fome | Vida | Conta |
|---|---|---|---|
| Carne crua | +25 | 0 | 125 s de fome |
| **Carne cozida** (Fogueira) | **+35** | **+10 em 10 s (1/s, renova)** | 175 s de fome |
| Baga | +10 | 0 | 50 s |
| **Carne podre (estragada)** | +5 | **-6, não mata (deixa 1)** | 25 s |
| Saciedade (> 70) | -- | **+0,5/s fora de combate (5 s sem dano)** | vida 100 em 200 s |

**Queda da fome: 0,5/s vira 0,2/s [recomendo; é o parâmetro `decay_per_second`].** Com 0,5/s o jogador come 51 cozidas por hora (26 Dodos, mais que a caça do resto do jogo); com 0,2/s são **21 cozidas/h = 10 Dodos/h, ~5 min de caça por hora**; a barra cheia dura 500 s (8,3 min) e cai a 70 em 150 s.

**Cozimento:** na Fogueira, 2 s por carne, 1 madeira para 4 carnes (conta de 5.9); carne cozida vence em **90 min** (crua 30). **Cozida vale para o jogador e para o dino domado (5.12)**; a **Ração Rubra e o domar usam crua** (o Utahraptor aceita carne crua), então a Fogueira **não toca na conta da domesticação**.

**Fome 0, torpor do jogador:** sobe **+2/s líquido** (anula a queda natural): faixas 25/50/75 em 12,5 / 25 / 37,5 s (efeitos leves da camada 1, sem barra) e **inconsciente em 50 s**. Do cheio ao primeiro colapso: **550 s (9,2 min)**.

**Inconsciente:** **8 s**, **1,5 de dano/s** (12 por desmaio); acorda com torpor 50 e **volta a 100 em 25 s**: **ciclo de 33 s, janela de 25 s para comer**. Morte (vida 100) no **9º desmaio, ~5,2 min depois de zerar** (antes: 40 s), com 8 janelas. Fome 0 sem desmaio não causa dano nem regenera (removido o dano de 5/2 s). Comer **qualquer comida (fome > 0)** corta a subida e o torpor cai pelo normal.

**Inconsciente não come sozinho (recomendo): acorda sozinho em 8 s e come na janela de 25 s; no co-op outro jogador pode alimentar o caído** (interação de 1 s com comida em mãos, valida no servidor), o que o **acorda na hora**. Sem comer automático (não é decisão).

**Fruta-do-sono, sono e M4:** a fome é **fonte própria** de torpor, **fora da lista de 3 efeitos e do teto** (5.4); soma com a fruta (comer fruta com fome 0 acelera o colapso; fruta come fome +0). O **estado "inconsciente" do jogador é o mesmo do sono do M4**: a decisão de sono do M4 **reusa** o estado, o dano e o alimentar do co-op. **O torpor do jogador entra antes (M2)**, só pelo caminho da fome. Custo [estimativa minha; `SHIKAMARU` confirma]: torpor no jogador (componente existente) 2 h; estado inconsciente (entrada bloqueada, deitado, acordar) 4 h; regra fome-para-torpor e troca do dano 2 h; dano por segundo 1 h; alimentar no co-op 3 h; sinais de faixa 2 h = **14 h**. **M1** mantém o dano atual de fome com a queda 0,2/s (custo 0).

**Lista para o `SORA`:** `decay_per_second` 0,2; `HungerComponent` sem `starved` periódico (vira sinal `hunger_zero`); `PlayerTorpor` com fonte "fome" de +2/s líquido; estado inconsciente 8 s e acordar a 50; dano 1,5/s; carne crua, cozida, podre como itens com fome, cura e dano; interação "alimentar jogador"; save de torpor e do ciclo. **Sinais para o `YATORA`:** estômago roncando e vinheta fria nas faixas 25/50/75, sprite deitado e estrelinhas, som de ronco, ícone de carne cozida e de carne podre (esverdeada), partícula de brilho curto na cura.

### 5.11 Armadura e dano mínimo 1 (decisão do dono, 06/11)

Simulação: `fome_sim.py armadura`. **Três conjuntos, 1 vaga (Traje): fibra, couro, metal.** Só reduz dano; **sem efeito de temperatura**. Pele, osso, quitina e Escudo saem.

| Conjunto | Redução | Peso | Durab. | Receita | Saber | Marco |
|---|---|---|---|---|---|---|
| Fibra | 10% | 2 kg | 100 | 15 fibra + 2 madeira | 1 | **depois do playtest (fora da v0.2)** |
| Couro | 25% | 6 kg | 150 | 8 couro + 4 fibra | 2 | M4 |
| Metal | 40% | 12 kg | 300 | 6 barra de ferro + 2 couro (Forja) | 6 | M5 |

**Dano mínimo 1:** `dano_final = max(1, dano x (1 - min(0,5, redução)))` para todo ataque que acerta com **dano base >= 1**; **dano base 0 (fruta, preparado, Boleadeira) continua 0** (é torpor, não "acerta" para dano). **Conta (Utahraptor 11,25; Triceratops 55):** fibra 10,1 e 49,5; couro 8,4 e 41,3; metal **6,8 e 33,0**. O mínimo só muda o resultado para dano base abaixo de 1,7 (com 40%): marimbondo, golpe de 1, pancada de 2 (metal: 1,2). **O teto de 50% continua** (sem ele, 90% deixaria o Triceratops em 5,5 por golpe, quase imunidade); com um só Traje o máximo é 40% e o teto vira **trava para futuro** (Escudo ou bônus). **Durabilidade:** 1 por golpe sofrido, **inclusive o que caiu a 1**: fibra dura 100 golpes (2,5 min de Utahraptor L20), couro 150 (3,8 min), metal 300 (7,5 min). **Peso:** conta no Peso (50 kg + 3/pt): o metal tira 12 kg (24%). **Reparo:** Bancada (metal na Forja), 50% do material, sem reduzir o máximo. **Fibra: decidido, depois do playtest, fora da v0.2** (custaria +8 h); **couro segue sem uso na v0.2** (só Bastão reforçado). Na v0.2 não há armadura: 20 receitas, 22 Saber.


### 5.12 Cocho e a comida do dino domado (decisão do dono, 06/11)

Fome do dino domado: 100, queda **0,1/s** fixa (tabela 5.1): vazio em 1000 s (16,7 min). Um Utahraptor gasta **14,4 carne/h** (0,1 x 3600 / 25); um Paquicéfalo **36 bagas/h** (360 / 10) [calculado].

**Regra do dono:** o dino domado come **da comida no próprio inventário (alforje) ou de cochos por perto, dentro do alcance do cocho.**

| Ponto | Regra recomendada [premissa] | Conta |
|---|---|---|
| **Alcance** | **6 tiles** (96 px) do cocho; o dino em "seguir" ou "ficar" vai até ele, come em 2 s e volta | jogador anda a 70 px/s: 1,4 s de ida |
| **Quando come** | com fome **<= 50**; do alforje só se **<= 25** e **nunca Ração** | 1 unidade por vez: carne +25, baga +10, cozida +35 |
| **Ordem** | **Cocho primeiro, alforje depois** (reserva) | o cocho é a estação de propósito; o alforje carrega o que o dono mandou |
| **Capacidade** | **40 itens** (4 pilhas) | 40 carne cobre 2,8 h de um Utahraptor, mas veja validade |
| **Aceita** | só a **dieta da espécie**: Ração do tipo dele, baga (herbívoro), carne crua ou cozida (carnívoro); **não** aceita carne podre | herbívoro recusa carne |
| **Validade** | **continua correndo** (mesma regra de 5.9, sem geladeira); o vencido fica no cocho e o dino **não come podre** | carne crua 30 min: **7 por Utahraptor**; cozida 90 min: 21; baga 45 min: 27 por Paquicéfalo; **Ração não vence** (~12/h por dino a 30 de fome [premissa], 40 duram 3,3 h) |
| **Quem usa** | **só dino domado.** O dino **dormindo em domesticação** não usa cocho nem alforje: o jogador dá a Ração (Eficiência e quantidade importam: `racao.md`) | evita que o cocho vire atalho de domar |
| **Vários dinos** | **todos no alcance dividem o cocho**, quem tem fome <= 50 primeiro; sem limite fixo | 5 Utahraptors cozida: 51/h, 40 itens duram 47 min |
| **Sem comida** | fome 0 por mais de 2 min: **Afeto -1/min**, ofício pausado e ordens só "seguir/ficar"; **nunca morre de fome** (não pune servidor desligado) | de 100 a 0 em 16,7 min |

**Consequência de design.** Carne crua vence em 30 min: **cocho de carnívoro pede carne cozida ou reabastecer a cada ~30 min**; para ficar longe da base, **Ração** (não vence). O herbívoro com baga aguenta 45 min. É o ciclo cuidar-do-rebanho (pilar) com custo real.

**Cocho (mobília):** Saber **2**, sem pré-requisito (lista plana, 5.19), **8 madeira**, **à mão**, **M2 cortável (a decisão mantém o Cocho fora do corte)**. **Custo [estimativa minha; `SHIKAMARU` confirma]:** nó de cocho com filtro e alcance 5 h; o dino "ir comer" 6 h; regra do alforje 2 h; fome zero (Afeto e ofício) 2 h; save 1 h; tela (reusa a do baú) 2 h = **18 h**. `YATORA`: cocho vazio e cheio, dino comendo. `SORA`: `Trough {items[], accepts, range=6}`, `fome <= 50` e `<= 25`, filtro de dieta, validade por pilha. Precisa jogar: se 6 tiles e 50% de fome dão conforto ou o dino parece "faminto de pé ao lado do cocho".


### 5.13 Tecla de atalho e slot de oferta (decisão do dono, 06/11; **slot de Oferta ADIADO para depois do playtest**)

> **Decidido (06/11, dono):** (1) **o Cocho fica para dinos domados**; (2) **o slot de Oferta e a domesticação passiva ficam para depois do playtest**: a tabela abaixo é **proposta guardada**, fora do M2 e do custo da v0.2; (3) **o jogador nunca consome Ração, só o dino**; **o preparado de sono ainda não foi decidido**. Sem o slot, **todo domar é ativo** (nocaute, tela do dino com E) e o Paquicéfalo do tutorial segue como está. A regra 2 do dono vale: o dino domado come do inventário dele e do Cocho; o dino em domesticação, da tela dele.

**Regras do dono:** (1) a tecla de atalho (1 a 9) **sempre faz o jogador consumir o item**, nunca alimenta dino; (2) o dino só come se a comida estiver no **slot passivo** (domesticação passiva) ou **no próprio inventário dele**. Nome no jogo: **slot de Oferta** [proposta]. Regras abaixo são minhas, com os números do `racao_sim.py tabela` (Paquicéfalo: 10 refeições com baga, 8 com C, 6 com B, 5 com A; Parassaurolofo: 15 com baga, 12 com C, 9 com B, 8 com A).

| Ponto | Regra recomendada [premissa] |
|---|---|
| **O que é e onde fica** | **1 slot extra** à direita da barra de atalhos, moldura diferente e ícone de folha; guarda **1 pilha** de comida. Mover para ele: arrastar no inventário ou **tecla O** (manda a pilha do atalho selecionado). **Tecla de atalho não toca nele.** |
| **Quem aceita** | Dino **selvagem desperto** de Conduta **Passivo** (Paquicéfalo) ou **Medroso** (Parassaurolofo), **nível até 20**. Semi-agressivo, Agressivo, Covarde e Curioso **nunca** (não se aproximam). Presas (Dodo, Listro) não domam. |
| **Como pega** | O dino **desperto** vem até **3 tiles** do jogador **parado** (anda a menos de 1 tile por 10 s, sem arma na mão, sem correr) e come **1 unidade do slot a cada 8 s**. O jogador só espera e **vê** (a tensão é parar). |
| **Quanto leva** | Refeições da tabela x 8 s: **Paquicéfalo baga 80 s, C 64 s, A 40 s; Parassaurolofo baga 120 s, C 96 s**, mais ~20 s de aproximação. Ativo: Paquicéfalo baga 60 s + 8,4 s de Soco. |
| **Quando perde ou interrompe** | **Interrompe** (o dino se afasta, o slot fica): jogador corre, saca arma, ataca, leva dano; **qualquer** predador a 8 tiles; jogador a mais de 6 tiles. Progresso do dino **regride 1%/s depois de 15 s** parado e **zera em 60 s** (como em 20.3). **Parassaurolofo:** se alguém da manada for atacado, **a manada toda foge** (alarme, 6.7): interrompe todos. |
| **Eficiência** | **Sem torpor e sem bônus de nível**: o dino fica no **nível da captura** (ativo: Paquicéfalo L8 vira 10 com B; Parassaurolofo L20 vira 24 a 26). **Em troca nasce com Afeto inicial +20** [premissa] (via não violenta, pilar 3). Nunca precisa de dardo. |
| **Qual comida** | **Só o que a espécie aceita no domar**: baga (os dois) ou Ração Verde C, B, A. **Nunca Carne/Rubra** (carnívoro não entra). |
| **Validade** | Corre como em 5.9; a baga vence em 45 min contra 80 a 120 s de domar: **irrelevante**. Se a pilha vencer no meio, o dino para e o aviso aparece. |
| **Co-op** | O dino come **só do slot do primeiro jogador que ofereceu** (`owner_id`); outros jogadores perto são ignorados até zerar. Progresso é do dino. Sem PvP e sem roubo. |

**Alimentar o dormindo (resolvido pelo dono, 06/11):** no domar ativo a comida vai pela **tela de inventário do dino, aberta com interagir (E)**, e o dino come de lá; **já está implementado** e substitui a sugestão do item selecionado. Fruta e preparado no dormindo seguem o mesmo caminho. A regra 2 fica coerente: o dino come do **próprio inventário** (tela do dino) ou do **slot de Oferta**. Sem conflito.

**Cocho e a regra 2 (resolvido: o dono mantém o Cocho, para dinos domados).** O cocho não é o inventário do dino nem o slot: fica como **"inventário do rebanho" por alcance**, extensão da regra 2. Não serve ao dino em domesticação.

**Paquicéfalo do tutorial: não muda** (o slot ficou para depois do playtest; o domar é só ativo).

**Custo guardado (fora da v0.2, adiado pelo dono; `SORA` e `YATORA` não fazem agora) [estimativa minha]:** slot e tecla O 3 h; IA "aproximar e comer" 4 h (**reusa a IA de "ir comer" do cocho**: soma 2 h se o cocho existe); estado de progresso, regressão e Afeto +20 3 h; interrupções 2 h; co-op `owner_id` 1 h; save 1 h = **~13 h**. `YATORA`: moldura do slot, ícone de folha, dino comendo (compartilhado com o cocho). **Menor recorte: só Paquicéfalo, só baga, sem co-op e sem Afeto** = ~7 h. **Fica depois do playtest (decidido)**: o M1 não depende dele; perde-se a via não violenta (pilar 3) na v0.2. Precisa jogar: se esperar parado 80 a 120 s é tensão ou tédio (espera sem decisão é defeito: a decisão aqui é **quando parar de oferecer e fugir do predador**).


### 5.14 Tempo de domar: alvos em minutos (decisão do dono, 06/11)

**Regra do dono:** o **nível do dino** muda **quantas comidas ou Rações** são necessárias e, por isso, o **tempo total**; no MVP o tempo é calibrado para os alvos abaixo na **taxa padrão (1x)**. Simulação: `tempo_sim.py tabela|torpor|eficiencia|curral|carne|hora`. Fórmula nossa: `refeições = ceil(refeições_da_comida x fator_da_espécie x max(0,5; 1 + 0,033 x (L - 10)))` e `tempo = refeições x intervalo x fator_de_bocado / taxa` (**antes 0,015 e piso 0,85**: o nível agora pesa mais). Fatores [premissa calibrada]: Paquicéfalo 1,5; Utahraptor 1,5; Parassaurolofo 1,1; Triceratops 1,7 com **bocado grande x3** (come devagar). Para o Utahraptor a carne crua vale no grau da baga; o Triceratops não aceita baga e **parte da Ração C**.

**Alvos [calculado: modelo dentro de +-6% dos alvos; a calibração em si é premissa]:**

| Espécie | Nível baixo / médio / alto | Comida | Quantidade | Tempo de domar |
|---|---|---|---|---|
| Paquicéfalo | 5 / 10 / 20 | baga | 13 / 15 / 20 | **1,3 / 1,5 / 2,0 min** |
| Utahraptor | 10 / 15 / 25 | carne crua | 15 / 18 / 23 | **1,5 / 1,8 / 2,3 min** |
| Parassaurolofo | 10 / 20 / 30 | baga | 11 / 15 / 19 | **1,1 / 1,5 / 1,9 min** |
| Triceratops | 20 / 28 / 40 | Ração C | 19 / 22 / 28 | **4,8 / 5,5 / 7,0 min** |

Com a **Ração A** o tempo cai a cerca de um terço: Paquicéfalo 0,5 / 0,5 / 0,7 min; Utahraptor 0,5 / 0,6 / 0,8; Parassaurolofo 0,4 / 0,5 / 0,7; Triceratops 2,4 / 2,8 / 3,4 min. **Taxa do servidor:** chave `domar_velocidade` (padrão 1,0): `tempo = tempo / taxa`.

**Manter dormindo (nível médio, comida-base; extra = tempo x queda + refeições x agitação - torpor máximo):** Paquicéfalo L10: janela 100 s, tempo 90 s, extra 65 = **3 golpes de Bastão (2,1 s) ou 7 de Soco (4,2 s)**; Utahraptor L15: extra 88 = 3 de Bastão ou 9 de Soco; Parassaurolofo L20: extra 24 = 1 de Bastão ou 3 de Soco; **Triceratops L28 com C: extra 343 = 12 de Bastão (8,4 s) ou 35 de Soco, ou ~46 s de fruta-do-sono**; com A: extra 55 = 2 de Bastão. Com Ração A o extra é 0 nos três pequenos. Cada golpe em dormindo custa ~5 de Eficiência.

**Eficiência (nível médio): dreno por tempo 0,3 atual e 0,15 recomendado.** Paquicéfalo baga 27 (41), B 78 (84), A 86 (91); Utahraptor carne 16 (33), B 72 (81), A 85 (90); Parassaurolofo baga 39 (52); **Triceratops C 0 (0), B 0 (15), A 34 (59)**. Com 0,3 o Triceratops só paga com A; **recomendo `eficiencia_drena_tempo` de 0,3 para 0,15**. Ração S e S+ pioram o dreno por refeição a favor do jogador (`nivel_sim.py`).

**O que muda a jusante:**
- **Curral (6.x):** o texto dizia 40 a 105 s para o Utahraptor; agora **32 s (Ração A, L10) a 138 s (carne crua, L25)**. A conclusão não muda: a cerca cede em 8 s, a madeira cobre só a intervenção.
- **Carne e validade:** Utahraptor L15 pede **Ração Rubra C: 14 refeições, ~25 carne (13 Dodos, 6,5 min de caça)**; **B: 11 refeições, ~11 carne**; **A: 9, ~10 carne**. Validade da carne crua (30 min): margem de **4,6x (C), 10x (B), 12x (A)**. Baga (45 min) contra 1,1 a 2,0 min de domar: irrelevante.
- **Primeira hora:** não quebra. Paquicéfalo L8: **15 bagas (45 s de coleta), 90 s dormindo, 1 a 3 reforços de torpor**. **Recomendo o Paquicéfalo do tutorial entre L5 e L8** (L5: 13 bagas, 78 s; L8: 15 bagas, 90 s). Com Soco (antes do Bastão) a Eficiência de um tutorial com baga fica perto de 0: aceitável, é o aprender.
- **Conflito:** `racao.md` 10.x e 6.1 ("Dificuldade 1,0 / 1,5 / 2,0 / 1,5") e as tabelas de 60 s e 105 s ficam **desatualizadas**; vale esta seção e `tempo_sim.py`.
- **Precisa jogar:** se 5,5 min de Triceratops com a Ração C é tensão ou espera (a saída é a Ração A, 2,8 min); se o Utahraptor com 1,8 min dormindo é vigília longa o bastante para o predador chegar.


### 5.15 A v0.2 sem dardo, sem Oferta, sem Listro e sem fibra: ainda doma? (06/11)

Simulação: `medroso_sim.py para|tri` (perseguição com Stamina por golpe, faixas de torpor e fuga de 16 tiles).

**Parassaurolofo (Medroso, foge a 75 px/s): doma com Bastão, sem ajuste.** Nível 10, 20 e 30: **6, 7 e 8 golpes de Bastão, 3,5 / 4,2 / 5,3 s**, o dino foge 9 / 11 / 15 tiles (a fuga acaba aos 16) e o jogador **não precisa correr**: caminhando gasta só os golpes (Stamina mínima 94); a lentidão das faixas de torpor deixa o dino a menos de 70 px/s antes do 4o golpe. **Soco não serve**: 20 a 34 golpes, 11 a 28 s (só termina porque a fuga acaba). Depois do nocaute: baga, 15 refeições e 90 s no L20, com 1 reforço de Bastão. **Não precisa de armadilha, curral nem novo sistema.** O alarme faz a manada fugir, e isso não atrapalha o alvo.

**Triceratops (Semi-agressivo, investe): doma, mas só com o nível certo; ajuste de dado.** Dano ao jogador (premissa) 20 x (1+0,04(L-10)), a cada 2,5 s, o 1o ataque 0,5 s depois do 1o golpe: **L20: 8 golpes, 4,9 s, 2 ataques de 28 = 56 de dano (de 100)**; **L28: 9 golpes, 5,6 s, 3 ataques = 103: mata**; com 5 pontos em Dano 7 golpes e 69; com 4 em Vida (124) sobra 21. **Menor ajuste: o Triceratops selvagem da v0.2 aparece em L18 a L24** (L24: 62 de dano, sobrevive sem build); **L28 e acima ficam fora (sem Rifle): na 1.0 a faixa continua em L18 a L24**; liberar L25 a L28 só se o dono quiser, e então com Traje de couro (L28: 77 de dano, sobra 23) ou Arco (a 10 tiles) ou metal (62). É só dado de spawn, **sem sistema novo; não precisa de decisão do dono**, só confirmar a faixa. Depois do nocaute, Ração A (2,4 a 2,8 min, extra 42 a 55 = 2 golpes) é o caminho viável; com C o extra é 292 a 343 (fruta-do-sono ou 10 a 12 golpes que zeram a Eficiência).

**Resto:** Paquicéfalo (Soco ou Bastão) e Utahraptor (Bastão, 6 golpes) como antes. **Espécies da v0.2: Paquicéfalo, Utahraptor, Parassaurolofo, Triceratops (domáveis) e Dodo (presa) = 5**; **na 1.0 entram Listro e Oviraptor (M4)**.


### 5.16 Tetos de nível: nascimento, evolução, servidor e jogador (decisão do dono, 06/11)

Simulação: `teto_sim.py spawn|teto|xp|saber`. **Regras do dono:** (1) dinos nascem com nível aleatório e **teto máximo ao nascer**; (2) o dino tem **teto de evolução de 2x o nível de doma** (selvagem em 100 chega no máximo a 200); (3) o **teto do servidor vence** (teto 180: nunca chega a 200, e em 180 o XP trava); (4) o jogador também tem nível máximo.

**Faixa de spawn e distribuição [premissa].** Nível por sorteio **com poucos altos**: `nível = mín + floor((máx - mín + 1) x u^2)`, `u` uniforme (a média cai a 1/3 da faixa, o quarto de cima sai 13% das vezes e não 25%, o nível máximo 2 a 7%). Faixas na v0.2: **Dodo 3 a 10; Paquicéfalo 5 a 20 (zona do tutorial 5 a 8); Utahraptor 10 a 25; Parassaurolofo 10 a 30; Triceratops 18 a 24** (média 19,9; compatível com a faixa de 5.15). Na 1.0 o Triceratops amplia para 18 a 40 (média 25,2). Médias: Dodo 5,2; Paquicéfalo 9,9; Utahraptor 14,9; Parassaurolofo 16,5. **Teto ao nascer no MVP: `dino_nivel_spawn_max` = 30** (o maior da v0.2 é o do Parassaurolofo); o sorteio nunca passa dele nem do `dino_nivel_max`.

**Teto de evolução: três leituras do "2x"** (selvagem 100, bônus de Eficiência 50, final 150): **A) 2x selvagem = 200; B) 2x final = 300; C) 2x selvagem + bônus = 250.** Exemplos do MVP: Paquicéfalo L10 com Ração A (final 15): A 20, **B 30**, C 25; Parassaurolofo L20 com A (final 29): A 40, **B 58**, C 49; Triceratops L24 com A (final 31): A 48, **B 62**, C 55.

**Ambiguidade, recomendação e ponto para o dono: B, 2x sobre o nível final (depois do bônus).** Em **A** o teto não depende da Eficiência: ela só adianta níveis (poupa XP), e **no fim do jogo a Eficiência perde todo o valor**; em **B** cada nível de bônus eleva o teto, e a escada de Rações paga até o fim. B é também a leitura literal de "nível de doma" (o nível em que o dino foi domado, já com o bônus). O risco de B (crescer demais) é coberto pelo **teto do servidor**. **Configurável:** `dino_teto_base` = `final` (recomendo) ou `selvagem`; `dino_teto_multiplicador` = 2,0. **Decisão do dono (V60):** confirmar B.

**Teto do servidor e valores do MVP.** `dino_nivel_max` vence sempre: **teto efetivo = min(multiplicador x nível de doma, `dino_nivel_max`)**; vale também para o nível ao nascer e para o bônus de Eficiência (o final nunca passa dele). **MVP: 50** (não 75): o dino evolui de 15 a 20 níveis, o mesmo tamanho dos 19 pontos do jogador; com 75 seriam 44 pontos no Triceratops (+264% da base) contra 19 no jogador. Conta de XP (curva do dino `20 + 10g`, 15 XP/min, companhia): Triceratops L24 de 31 a 50 = 19 níveis = 2.280 XP = **2,5 h**; Parassaurolofo L20 de 29 a 50 = 21 níveis = 2.730 XP = **3,0 h**; só ao teto 75 passaria de 12 h. **1.0: 75.**

**Dino domado ganha XP como: já estava definido (5.1, item 6)**: o mesmo XP do jogador enquanto está em "seguir" a até 12 tiles, curva `20 + 10g` por nível extra, 1 ponto por nível (Vida, Dano ou Peso). **Muda só o teto** (de captura + 10 para a regra acima). A curva não depende do nível; se o dono quiser que dinos grandes demorem mais, é valor novo (não incluído).

**Ao travar** (dino ou jogador no teto efetivo): **o XP para de acumular** (não fica guardado), a **barra de XP fica cheia com o selo "teto"** (no dino, na tela dele; no jogador, na HUD no lugar do "Nv"), **não nascem pontos novos**, e os **pontos livres que já existiam continuam gastáveis**. Se o teto do servidor subir depois, o XP recomeça de zero no nível atual. **Save acima do teto (recomendo: só trava, não reduz):** reduzir o nível devolveria pontos já gastos e puniria o jogador por uma mudança do servidor; o dino ou jogador acima do novo teto **mantém nível e pontos** e não ganha XP; domar novo respeita o teto novo (o final é cortado nele). **Ponto para o dono (V60).**

**Teto do jogador.** **MVP: `jogador_nivel_max` = 20** (19 pontos de atributo, **24 Saber**; a v0.2 custa **23**, cobre com 1 sobrando). **1.0: recomendo 75** (**90 Saber** contra os **82 da 1.0**, 74 pontos de atributo). **Conferido: a 1.0 só completa no L69** (L68 dá 81, L69 dá 82 [calculado]); com teto 50 o jogador chega a 60 Saber (74% da árvore), com 20 a 24 (30%): **se o servidor baixar o teto do jogador abaixo de 69, a 1.0 fica incompleta por desenho**. XP do jogador (curva `30 + 15(L-1)`): L20 3.135 XP (4,0 h a 13/min), **L68 35.175 XP (45 h)**, L75 42.735 XP (55 h).

**Custo e marco [estimativa minha; `SHIKAMARU` confirma]:** teto efetivo (fórmula, `min`, corte do final e do spawn) 2 h; XP que trava, barra cheia e selo "teto" 1,5 h; sorteio com poucos altos e faixas por espécie em dado 1,5 h; chaves de servidor e leitura 0,5 h; save acima do teto (só travar) 1 h; texto na tela do dino 0,5 h = **7 h**, **M2** (junto do XP do dino). **Menor recorte: constantes e XP que trava, sem selo nem chaves = 3 h.** `YATORA`: selo "teto" (dino e jogador). `SORA`: `Attributes` com `teto_efetivo(dino)`. Precisa jogar: se 2,5 a 3 h de companhia até o teto parece progressão ou espera, e se "poucos altos" deixa os dinos fortes raros demais.


### 5.17 Forja: madeira, carvão e minério (decisão do dono, 06/11)

**Regra do dono:** a Forja **queima madeira para fazer carvão e converte minério em metal**. A própria Forja é feita na Bancada (`receitas.md` 6). Marco **M4 a M5** (sem mudança); fora da v0.2. Números [premissa], contas à mão.

**Mínimo recomendado (dois processos automáticos, um relógio):**

| Processo | Entra | Sai | Tempo |
|---|---|---|---|
| **Queimar** | 3 madeira | 1 carvão | 30 s (10 s por madeira) |
| **Converter** | 2 minério de ferro + 1 carvão | 1 Barra de ferro | 10 s |

- **Carvão é item necessário**, não subproduto solto: sem ele não há barra. **Custo de uma barra: 2 minério + 3 madeira, 40 s de fogo** (antes 2 minério + 1 madeira, 5 s). A Forja faz **uma coisa por vez**: **converte se houver 1 carvão e 2 minério, senão queima** (um relógio só).
- **Inventário da Forja (4 vagas):** madeira até 30 (15 kg), minério até 20, carvão até 10 (0,2 kg cada), barra até 10. **Carga cheia: 30 madeira viram 10 carvão e 20 minério viram 10 barras em 10 x 40 s = 400 s (6,7 min)**.
- **Funciona sozinha com o jogador longe: sim.** O estado fica salvo `{vagas, relógio, t_ultimo}` e o progresso é calculado **na hora de abrir ou salvar** (como a validade das pilhas, 5.9): sem tique por quadro. Só corre com o servidor ligado. A saída para quando a vaga de barra enche.
- **Os itens de metal que a Forja faz:** **18 barras ao todo** (Machado 3, Picareta 3, Espada 4, Traje de metal 6, **Besta 2; o Rifle (4) saiu**) = **720 s de Forja (40 s por barra), 54 madeira, 36 minério**; coleta: 54 madeira = 72 s com Machado de pedra, 36 minério = ~144 s [premissa: nó de minério 0,25/s]. **Antes eram 20 barras, 800 s, 60 madeira e 40 minério: o corte do Rifle poupa 80 s de Forja e 4 minério por jogador.** Dardo e Rifle sem marco.
- **Carvão tem outro uso? Hoje não.** **Recomendo a forma mais simples: carvão só da Forja (sem receita própria e sem Saber).** **Uso opcional barato:** a **Fogueira aceita carvão** (1 carvão cozinha 10 carnes, 0,2 kg; contra 1 madeira por 4 carnes, 0,5 kg): serve de combustível leve de expedição, +0,5 h. Como 3 madeira dão só 1 carvão, a troca não vale como fonte principal. **Decisão do dono (V61): só Forja ou também Fogueira.**

**Custo extra [estimativa minha; `SHIKAMARU` confirma]:** Forja como contêiner de 4 vagas com os dois processos e o catch-up 5 h; save e versão 1,5 h; tela (reusa a do baú) 2 h; item carvão e minério 1 h = **9,5 h**, somado ao que o metal já custa (`receitas.md` 6). **Menor recorte:** sem "funciona longe" (só corre com a tela aberta) = -2 h, mas o jogador fica parado: **não recomendo** (espera sem decisão). `YATORA`: Forja apagada e acesa com fumaça, ícones de carvão, minério e barra. `SORA`: `Forge {slots, timer, t_last}`, `queimar` e `converter` por dados. Precisa jogar: se 6,7 min por carga é espera boa (o jogador mina e volta) ou lenta.


### 5.18 Pilão e químicos (decisão do dono, 06/11)

**Pilão:** item **portátil**, feito **à mão** (Saber 1, 2 pedra + 1 madeira, 3,5 kg, 100 moagens), usado no personagem pela aba "Moer" do menu de Receitas. **Preparado de sono** (nome único) passa a ser moído no Pilão: 3 fruta-do-sono + 1 carne podre rendem 3, 4 s. **v0.2: 19 receitas, 20 Saber** (sobra 4 dos 24; antes 21 e 23, com Cama e Bastão reforçado); o Pilão e o Preparado são **cortáveis juntos** (sem eles 17 e 16), **mas ficam: aceitos pelo dono**. O Preparado é o único consumidor do Pilão na v0.2.

**Fósforo, pólvora e sílex: SEM MARCO (decisão final do dono, 06/11).** Sem Rifle e sem arma de fogo nada os consome, então saem da árvore ativa e do mapa de recursos; ficam só como registro (fósforo 2 sílex + 2 pedra rendem 6; pólvora 2 carvão + 2 fósforo rendem 4). **O carvão continua só da Forja** (aceito; opcional na Fogueira, V61). **Custo da v0.2 [estimativa minha]:** Pilão (item, aba Moer, durabilidade) **3 h**, junto com o Preparado: **Pilão e Preparado entram na v0.2** (aceito). `YATORA`: ícone do Pilão. `SORA`: estação "Pilão" no `RecipeDef` (portátil).


### 5.19 Regra de produção e decisões finais do dono (06/11)

**Regra de produção.** **Fibra, madeira e pedra são feitos na mão** (menu P, estação "Mãos"); **metal e engenharia, na Bancada**; a **Forja continua feita na Bancada** (5.17) e é a estação da Barra e dos itens de metal. Tudo o que usa só material primitivo (graveto, madeira, pedra, fibra, couro, corda) sai da árvore da Bancada. **Reclassificadas para Mãos:** Bastão-de-sono, Baú, Cocho, Cerca e curral, Portão de dino, Abrigo (fundação, parede, porta), Corda, Arco, Flecha, Boleadeira, Traje de couro e de fibra, Canteiro, Palha, Tijolo, Pedra. **Ficam na Bancada:** Ração C, B, A, S e S+ (preparo de comida, decisão minha: é a única razão de a Bancada ser necessária na v0.2), Forja, Espada, Machado e Picareta de ferro, Traje de metal e **Besta** (engenharia). Preparado: Pilão. `receitas_sim.py estacoes`: **v0.2 Mãos 15, Bancada 3 (Ração), Pilão 1; 1.0 Mãos 29, Bancada 11, Pilão 1.**

**Consequência a conhecer (calculado):** a Bancada passa a servir na v0.2 a **3 receitas (a linha da Ração) e ao reparo** (5.9). Continua valendo o Saber 1 e o marco "Bancada no minuto 5", mas a Bancada deixa de ser pré-requisito de armas e abrigos. **Precisa jogar:** se a Ração na Bancada basta como razão para construí-la ou se ela vira degrau vazio.

**Bastão-de-sono nasce no inventário no M1, sem receita** (confirmado, como recomendei): o tutorial do Paquicéfalo não depende de Saber (4 golpes, 2,1 s). A receita de **reposição** (Saber 1, 3 madeira + 2 fibra, Mãos) entra no M2.

**Aceitas pelo dono:** (1) **"2x" é sobre o nível final** (nível da captura mais o bônus de Eficiência); (2) **servidor só trava, sem reduzir** (save acima do teto fica parado); (3) **teto de dino 50 no MVP** (75 na 1.0); (4) **Triceratops L18 a L24 na v0.2**; (5) **Dodo no início do M2**; (6) **carvão só na Forja**; (7) **Pilão e Preparado na v0.2**. **Cortes leves aceitos:** dano em construções no recorte mínimo (8.1), **sem Bastão reforçado**, **sem Cama**, **Saber em lista plana** (sem pré-requisito entre receitas; a cadeia mais longa cai de 3 elos para 0). **Corte maior: decidir depois do QA-01a.**

**Totais** (`receitas_sim.py arvore`): **v0.2 19 receitas e 20 Saber (24 disponíveis no L20; sobra 4)**, antes 21 e 23; **1.0 41 receitas e 73 Saber (completa no L61; antes 44 e 82, L69)**. A diferença é Cama, Bastão reforçado, Rifle, Dardo e a **Barra de ferro** (que é processo da Forja, sem receita no menu, e estava contada por engano), mais Besta e Boleadeira que entram.

## 6. Criaturas

### 6.1 Elenco do MVP (espécies reais)

Decisões do dono: a espécie usa o **nome real** (apelido próximo só se for extenso); **só terrestres**, sem voo nem água; **espécies brasileiras ficam para depois do MVP**; lista reduzida, escolhida do `catalogo.md`. Nomes novos substituem os provisórios anteriores.

| Papel | Antigo (provisório) | Espécie (nome no jogo) | Conduta | Domar |
|---|---|---|---|---|
| Herbívoro do tutorial | Barrigudo | **Paquicéfalo** (*Pachycephalosaurus*) | **Passivo** (6.7): pasta, ignora você, revida com cabeçada se atacado | Fator de refeições 1,5 (5.14); Ração Verde; aceita baga crua |
| Carnívoro em bando | Rabo-de-faca (via Deinonychus) | **Utahraptor** | **Agressivo**: ataca ao avistar a 8 tiles, bando de 1 a 2 | Fator de refeições 1,5 (5.14); torpor 120; vida base 80; Ração Rubra; aceita carne crua |
| Grande territorial | Montanhão | **Triceratops** | **Semi-agressivo**: ignora até 4 tiles ou ferimento; aí investe | Fator de refeições 1,7 e bocado x3 (5.14); Ração Verde |
| Herbívoro de manada com alarme (M2) | novo | **Parassaurolofo** (*Parasaurolophus*) | **Medroso**: deixa chegar, mas ao ser atacado dá o alarme e o grupo de 3 a 5 foge (alarme a 12 tiles) | Fator de refeições 1,1 (5.14); torpor 140, queda 1,3; vida base 200; Ração Verde; aceita baga crua |
| Fuga (5ª, cortável) | Pernalta | **Gallimimus** | **Covarde**: foge a 85 px/s a partir de 8 tiles; grupo de 3 a 5 | Dificuldade 1,25; Ração Verde; aceita baga crua |
| **Presa 1, a mais comum (início do M2)** | novo | **Dodo** (*Raphus cucullatus*, ave que não voa) | **Curioso**: vem até 3 tiles e ronda; se atacado, foge sem revidar | **Não domável** (presa); vida 24, **sem torpor**; L3 a 10; 2 carne + 1 couro; XP 3 |
| **Presa 2, escavador (M4, com o Oviraptor)** | novo | **Listro** (*Lystrosaurus*) | **Covarde**: foge a 85 px/s e some em toca | **Não domável**; vida 36, sem torpor; L8 a 16; 3 carne + 2 couro; XP 4 |

**Dodo e Listro (revisto 06/11, dono):** presas pequenas e **abundantes**, mais comuns que todas as outras (Dodo 12 por zona, Listro 8, respawn 10 min). **Papéis sem repetir:** o Dodo é o **Curioso** (vem até você, é o primeiro alvo da Lança); o Listro é o **Covarde** (foge, exige perseguir, rende mais). **Recomendo na v0.2 as duas como presa simples, sem domar**: sem Ração, sem Eficiência, sem torpor, sem batismo: **só vida, Conduta, carcaça e sprite** (**+10 h e 2 sprites**, contra ~16 h de uma espécie domável). **Decidido (06/11): o Listro sai da v0.2 e entra no M4, junto com o Oviraptor. Total: 5 espécies na v0.2** (4 domáveis + o Dodo) e **7 na 1.0**. **Dodo** é ave que não voa: **sai do bloqueio dos voadores**. **Só o Dodo na v0.2:** 12 por zona, respawn 10 min = **72 Dodos/h = 144 carne/h**; demanda de 2 Utahraptors e do jogador ~24 Dodos/h (33%), de 5 Utahraptors ~46 (64%): **cobre**.


Marco: **M1** Paquicéfalo e Utahraptor; **início do M2** **Dodo** (decisão do dono, 06/11); **M2** Triceratops, Parassaurolofo e (Listro no **M4**); Gallimimus M2 Should, **cortável**. Com as quatro primeiras o elenco fecha exatamente o que o plano prevê (2 no M1, mais 2 em CRI-06); com o Gallimimus são 5, **acima** do que o plano permite (3 a 4). Para o M4 (CRI-10, 4 a 5 espécies a mais): **Oviraptor** (Curioso, onívoro, estreia do perfil Mista). **Deinonychus** e **Lystrosaurus** voltam ao catálogo como futuros. Dados em `racao.md`, seção 3. A conduta de cada espécie está em 6.7. Nomes de Ração e ingredientes seguem originais (a família Ração e seus ingredientes são nossos).

**Apelidos.** "Pachycephalosaurus" é longo demais para HUD; usamos **Paquicéfalo**, forma portuguesa já corrente do nome (não é abreviação). Os demais ficam com o nome real. **Parassaurolofo** é a forma portuguesa completa do nome (sem abreviação).

**Base paleontológica e onde o jogo se afasta** [números aproximados da literatura; **conferir antes de publicar texto de jogo**]:

| Espécie | Porte, dieta, comportamento (plausível) | Onde o jogo se afasta |
|---|---|---|
| Paquicéfalo | Bípede de ~4,5 m, algumas centenas de kg, crânio em domo muito espesso; dieta incerta (plantas e talvez frutos e pequenos animais); uso do domo em disputas é hipótese discutida | Revide por cabeçada tratado como fato; aceita baga crua (frutos: plausível); vida e dificuldade são de jogo, não de massa |
| Utahraptor | O maior dos raptores: ~5 a 6 m, da ordem de 500 kg (muito maior que o Deinonychus, ~70 a 100 kg), garra em foice, carnívoro; restos de vários indivíduos num mesmo sítio sugerem grupo, mas caça em bando é hipótese; provável de penas | Papel, vida e mordida de jogo são níveis, não massa (vida base 80, igual à do Paquicéfalo de massa parecida); bando de 1 a 2 e perseguição a 90 px/s não vêm de medição; **arte deve mostrar penas e porte médio (32 a 40 px)** |
| Parassaurolofo (M2) | ~9 a 10 m, de 2,5 a 3,5 t, herbívoro, crista tubular oca; a crista como câmara de ressonância e chamado de grupo é hipótese defendida; hadrossauros costumam ser gregários | Tratamos a crista como alarme de grupo (a hipótese como fato); "Medroso" é escolha de jogo, não comportamento medido |
| Triceratops | ~8 a 9 m, de 6 a 12 t, herbívoro, três chifres e gola; marcas de ferida em chifres sugerem combate | Territorialidade e "aviso e investida" são do jogo; nenhum dino de 6 t é domável em 100 s na vida real |
| Gallimimus | ~6 m, centenas de kg, pernas longas, bico sem dentes, onívoro ou herbívoro; sinais de grupos | Fuga de 85 px/s é muito abaixo da velocidade estimada, reduzida de propósito para ser alcançável (calculado em 6.7) |
| Oviraptor (M4) | Pequeno de ~2 m, bico, onívoro; curiosidade é do jogo | Curioso é invenção de design |

**Desvios gerais:** o vale mistura espécies de formações distintas do Cretáceo; tamanhos de jogo são níveis, não massas; domesticar um adulto selvagem em minutos é ficção.

**Conteúdo futuro (depois do MVP): artrópodes gigantes, só em cavernas** (decisão do dono, 05/11). Ficam fora do elenco do MVP e do M4 no escopo. **Decisão de mapa a tomar antes do M4:** como o M4 traz chunking e seed (MUN-10, MUN-11), o modelo de dados de mapa precisa prever **mapa interior separado ligado por uma entrada no mundo** (id de mapa no save e na replicação), em vez de camada do chunk; tratar isso no ADR de chunking. Para a 0.2 basta reservar o campo `map_id` no save (custo desprezível); nada de caverna na 0.2 nem sistema detalhado agora.

### 6.2 Domesticação

Nocautear com o Bastão-de-sono (30 de torpor por golpe, 0,7 s; 4 golpes num Paquicéfalo L10, 6 num Triceratops L10) [premissa que muda os "3 golpes de 40" atuais], alimentar com Ração, vigiar. Acordado, o torpor crescente **não tem barra**: o jogador lê pelo comportamento (6.6). Dormindo, aparece o painel de domar com **três barras: torpor, domesticação e Eficiência**, e o **nível previsto** ("20 -> 28"). Regras e contas (qualidade, janela, torpor forçado, agitação, Eficiência) em `racao.md`, seções 1, 10 e 11. Resumo do tempo [calculado]: 12 a 105 s de vigília conforme nível e espécie; M1 só com baga crua (60 s) e sem Eficiência.

**Vigília com perigo (regra do dono).** Atacar o dormindo causa dano e derruba a Eficiência; carnívoros também atacam o dormindo. É preciso **proteger o dino durante a domesticação**: matar ou provocar o carnívoro, ou preparar um curral. Um Utahraptor livre mata um Paquicéfalo L8 dormindo em 12 s e zera sua Eficiência em 10,5 s [calculado, racao.md 11.1]. Com Eficiência 0% ainda doma, sem bônus.

### 6.3 Vínculo, Afeto, ordens

- **Afeto** 0 a 100. Inicial = `round(Eficiência/5)` (0 a 20), ou seja, vem de quão bem foi a domesticação (racao.md 10.8). Sobe +4 por alimentada com Ração B ou melhor, +1 com comida simples; desce -1/min sem cuidado e -10 ao ser ferido por você [premissas].
- **Ordens** (M1): seguir e ficar. (M2): atacar o alvo, guardar a base. Obediência: acima de 25 obedece sempre; de 10 a 25 falha 30% das vezes; abaixo de 10 ignora [premissa, jogar].
- **Carnívoro domado**: com Afeto menor que 40 ainda ataca estranhos e pode atacar animal neutro por conta própria (Temperamento, cortável).

### 6.4 Ofícios (função na base)

| Ofício | Quem | Marco | Corte |
|---|---|---|---|
| Carregar (alforje com **Peso** `base x (1+0,03(L-10))`: Paquicéfalo 40 / 52 / 64 kg em L10 / 20 / 30; Parassaurolofo 100 / 130 / 160) | herbívoro | M2 | Essencial |
| Defender (dano de defesa escala com o nível; também protege dormindo na domesticação) | carnívoro | M2 | Essencial |
| Colher (coleta passiva de baga/fibra) | herbívoro | M4 | Cortável |
| Aviso (chamado da crista antes do invasor chegar, a 12 tiles) | Parassaurolofo | M2 Should | Cortável |

Plano: CRI-08 (carregar e defender). Concorda.

### 6.5 Filhotes

Carisma permitido aqui. Filhote é pequeno, de arte expressiva, **não ataca** e não pode ser nocauteado: entra por **ninho** (ovo ou filhote guardado pela mãe, com risco de mãe agressiva) ou por filhote nascido de dinos domados (M4+). Cresce em ~20 min jogados [premissa] alimentado 8 a 10 vezes com Ração do perfil da espécie [premissa], vira adulto com Afeto de entrada 60 e ofício escolhido. Conta de custo: ninho (risco) + 20 min de cuidado = o mesmo Afeto de 17 min de cuidado após domar com S+ (35 pontos a +4 por 90 s = 13 min) mais a escolha do ofício [calculado, aproximação]. M4, **Cortável**. [jogar] se compensa o tempo.

### 6.6 Vida, nível e Eficiência (decisões do dono, 05/11)

- **Vida.** Todo dino tem barra de vida, com resposta visual e sonora ao dano (flash, partículas, gemido por espécie em 75, 50 e 25% da vida). A barra aparece **só depois de dano**, some 5 s após o último, e há **no máximo 3 barras na tela** (as 3 mais recentes) para não poluir com vários dinos. Domados: lista de grupo no HUD (M2). Selvagem abaixo de 25% de vida foge (regra de servidor).
- **Nível.** Inteiro, em todo dino. Atributos da espécie valem no nível 10. Vida e dano `x(1+0,04(L-10))`, torpor máx. `x(1+0,02(L-10))`, refeições para domar `x max(0,5; 1+0,033(L-10))` (5.14), Peso `x(1+0,03(L-10))`, Stamina `x(1+0,02(L-10))` (reservada). Velocidade e Fome não crescem (5.1). Depois de domado: níveis extras por XP viram pontos do dono, teto de evolução em 5.16. Tabela completa em `racao.md` 10.2. Níveis selvagens por bioma: Campina 1 a 12; Mata-baixa 5 a 25; Pedreira 15 a 35; Clareira 30 a 50 (M4).
- **Eficiência.** Barra de 0 a 100% que começa cheia no nocaute e só cai: tempo dormindo, comida inferior, flecha de sono e, principalmente, **ataques recebidos dormindo**. Ao concluir a domesticação, `nível final = round(nível x (1 + 0,5 x E))`, teto 1,5 vezes: 100% leva nível 20 a 30; 50% leva a 25; 0% fica em 20. Fontes de perda e contas: `racao.md` 10.4 e 11.1.
- **Sinais de torpor com ele acordado**, em quatro faixas (25/50/75%): faixa 1 bocejo; faixa 2 passo mais lento (x0,85) e cambaleio; faixa 3 velocidade x0,65, cooldown x1,5 e uma pausa de 0,8 s a cada 4 s. **Regra (servidor):** velocidade, cooldown e pausa; replicada só a faixa (0 a 3), nunca o valor, o que também impede ler o torpor por modificação. **Só visual/som (cliente):** bocejo, cambaleio, respiração. Marco M2; a pausa é cortável.
- **Efeito do nível no jogo.** Dino de nível alto é parede para arma de dano (Paquicéfalo L30 tem 144 de vida contra 80 no L10) e barato de nocautear (6 golpes contra 4): o jogo empurra para domar, não para caçar. Qualidade da Ração pesa mais quanto maior o nível (Triceratops L28: de 33 com C a 42 com S+).

Marco: M2 para tudo acima (sem nível/Eficiência no M1). **Essencial** na 0.2: nível, Eficiência, barra de vida, painel de 3 barras. **Cortável**: pausa de torpor na faixa 3, vocalizações por limiar, faixas de nível para 3 biomas (2 bastam).

### 6.7 Conduta selvagem (tipos de comportamento)

**Nomes, para não confundir.** **Conduta** é o comportamento do dino **selvagem**, definido por espécie, que vale até ele dormir ou ser domado. **Temperamento** é o traço persistente do dino **domesticado** (seção 3). A Conduta acaba na domesticação; o Temperamento a herda como traço (tabela abaixo).

**Seis tipos (decisão do dono).** Números em tiles de 16 px e px/s; jogador anda a 70 e corre a 120 por 4 s de stamina [calculado, seção 5]. Todos [premissa] a validar. **Revisto 06/11:** Curioso (Dodo) e Covarde (Listro) passam a existir antes do M4; o Oviraptor, no M4, reusa o Curioso.

| Tipo | Percepção | Gatilho | Reação | Velocidade | Termina e volta ao normal |
|---|---|---|---|---|---|
| **Covarde** | 8 tiles | Jogador (ou dino agressivo) a 8 tiles ou menos; também se atacado | Foge sem revidar | Fuga **85** | Para de fugir ao chegar a 14 tiles do ameaçador ou após 8 s; fica 5 s em alerta; normal quando o jogador está a mais de 12 tiles por 5 s |
| **Medroso** | 6 tiles (vê, mas deixa chegar) | Só ser atacado | Susto de 0,8 s parado e depois foge sem revidar | Fuga **75** | 10 s ou 16 tiles; normal com o jogador a mais de 10 tiles por 8 s |
| **Curioso** | 7 tiles | Vê o jogador | Aproxima-se até 3 tiles em até 6 s, fica 4 s rondando, afasta-se até 10 tiles; recarga de 30 s. Se atacado: susto de 0,5 s e foge sem revidar | Aproximação 40, fuga **75** | Janela de proximidade de até 10 s; normal após a recarga |
| **Passivo** | 5 tiles (só olha) | Ser atacado | Ignora até então; depois **revida** o atacante | Base da espécie | Encerra após 8 s sem receber dano ou com o atacante a mais de 12 tiles por 5 s |
| **Semi-agressivo** | 8 tiles | Jogador a **4 tiles** ou menos, ou ser atacado | Aviso (postura e rosnado) quando o jogador entra em 6 tiles, 1,5 s antes; depois ataca | Perseguição **90** | Desiste com o alvo a mais de 20 tiles, 5 s sem visão ou 15 s de perseguição; alerta de 5 s e normal após 6 s com o jogador a mais de 10 tiles |
| **Agressivo** | 8 tiles | Avista jogador ou dino não aparentado (herbívoros e dinos domados do jogador) | Ataca ao avistar | Perseguição **90** | Desiste com alvo a mais de 20 tiles, 5 s sem linha de visão ou 15 s de perseguição; alerta de 5 s e normal |

Regras comuns:

- **Grupo.** Atacar um membro **chama os outros** a 8 tiles, com atraso de 0,5 s: Covarde, Medroso e Curioso do grupo fogem; Passivo do grupo revida; Semi-agressivo e Agressivo do grupo atacam. Tamanhos [premissa]: Paquicéfalo 1 a 3, Utahraptor 1 a 2, Parassaurolofo 3 a 5 (alarme a 12 tiles), Gallimimus 3 a 5, Triceratops solitário.
- **Abaixo de 25% de vida (6.6).** Todos os tipos fogem na velocidade da fuga do tipo (Passivo, Semi-agressivo e Agressivo na velocidade base), sem revidar. Passivo e Semi-agressivo voltam ao normal 10 s depois com o atacante a mais de 10 tiles; o Agressivo também volta, mas em alerta por 5 s. Vida regenera 1% por segundo fora de combate [premissa].
- **Nocaute.** As faixas de torpor (6.6) valem para todos os tipos: velocidade x0,85 na faixa 2 e x0,65 na faixa 3. Dormindo, **toda Conduta para** (sem fuga, sem revide). Ao acordar o dino volta ao alerta por 5 s, sem agressão imediata.
- **Quem corre, doma?** Simulação 1D de perseguição em linha reta (`conduta_sim.py`, docs/design) [calculado]: o **Covarde** a 85 px/s é nocauteado em ~5 s e 4 golpes por quem corre os 4 s de sprint a partir de 8 tiles. Vale `v_fuga <= 120 - (raio x 16 - 24)/4 = 94 px/s` para o sprint alcançar; a 100 px/s ou mais é impossível só na corrida. Sem stamina de sprint não alcança nunca. Medroso (susto de 0,8 s) e Curioso (susto de 0,5 s) são nocauteados em 2,1 e 2,6 s, pois o susto deixa os golpes 2 a 4 caírem antes de correr. A lentidão por torpor (x0,85 e x0,65) não foi decisiva na simulação em linha reta; ela passa a importar com obstáculo e mudança de direção [jogar]. Sem o susto, o Medroso a 75 px/s seria quase intocável com o bastão.
- **Carnívoro e presa dormindo.** Vale a regra de `racao.md` 11.2 (ronco de 8 tiles). Por tipo: **Agressivo** ataca dormindo no raio de ronco; **Semi-agressivo** só dormindo a 4 tiles ou menos (o território dele); os demais **nunca**. Todo ataque ao dormindo segue as perdas de Eficiência de `racao.md` 11.1.
- **Base.** Agressivo e Semi-agressivo não atravessam parede, porta fechada nem curral: o Agressivo, sem caminho por 2 s, **ataca a peça de bloqueio mais próxima**; o Semi-agressivo só se provocado (8.1).

**Herança para o Temperamento (domesticado)** [proposta, cortável]:

| Conduta selvagem | Temperamento do domado |
|---|---|
| Passivo | Calmo: obedece sempre acima de Afeto 10 |
| Covarde, Medroso | Arisco: foge de luta em vez de defender até Afeto 40 |
| Curioso | Explorador: segue a 3 tiles e abre caminho; defende mal |
| Semi-agressivo | Territorial: defende a base melhor (dano de defesa +20% [premissa]) |
| Agressivo | Hostil a estranhos até Afeto 40 (6.3) |

**Marco e corte por tipo.**

| Tipo | Espécie | Marco | v0.2 |
|---|---|---|---|
| Passivo | Paquicéfalo | M1 | Essencial |
| Agressivo | Utahraptor | M1 | Essencial |
| Semi-agressivo | Triceratops | M2 | Essencial (3ª espécie) |
| Covarde | Gallimimus (4ª) | M2 | **Cortável** (4ª espécie é Should) |
| Curioso | Oviraptor | M4 | Fora da 0.2 |
| Medroso | Parassaurolofo | **M2 (antecipado do M4)** | Essencial (4ª espécie) |

**Quantos tipos a v0.2 mostra (atualizado 05/11):** **4 tipos com 4 espécies**: Passivo (Paquicéfalo), Agressivo (Utahraptor), Semi-agressivo (Triceratops) e **Medroso (Parassaurolofo, antecipado do M4)**. Com o Gallimimus (Covarde, cortável) são **5 tipos com 5 espécies**, acima das 3 a 4 do plano (CRI-03: 2 em M1; CRI-06: 3 e 4 em M2). Só o **Curioso** (Oviraptor) fica no M4 (CRI-10). Os seis tipos exigem seis espécies. **Opção barata** (decisão do dono): variante por indivíduo no Paquicéfalo da Mata-baixa (pesos `Passivo 60% / Medroso 25% / Curioso 15%` [premissa]) mostraria o Curioso sem espécie nova; a Campina fica 100% Passivo no tutorial. Custo: um campo `pesos_conduta` por bioma.

**Avaliação: Parassaurolofo como Medroso.** *Encaixe:* o Medroso só reage quando atacado e o alarme de grupo é a regra "atacar um membro chama os outros"; um herbívoro de manada com crista sonora conta exatamente essa história. Para o Parassaurolofo o raio do alarme é **12 tiles** em vez de 8, só por dado (`chama_grupo.raio_tiles`). *Conta* (`conduta_sim.py`, [calculado]): com torpor 140 o Medroso a 75 px/s e susto de 0,8 s é nocauteado em **3,5 s com 6 golpes** (4 golpes e 2,1 s com torpor 100); não exige sprint. Ao atacar um da manada de 3 a 5, os demais fogem juntos, e só o alvo precisa ser perseguido. *Custo de antecipar o Medroso do M4 para o M2:* uma linha de dados no `ConductaDef` e o estado "susto" de 0,8 s (que a máquina de estados genérica já prevê); a fuga é a mesma primitiva já usada pelo Covarde e pela fuga de 25% de vida; mais animações (pose de susto, tremor, corrida, chamado) e testes por tipo [sem estimativa; é dado + arte]. Se o Gallimimus for cortado, a primitiva de fuga continua necessária pelos 25% de vida. *Alternativas:* Covarde (duplicaria o Gallimimus e exigiria a perseguição em corrida, pior para uma espécie de 3 t), Passivo (duplicaria o Paquicéfalo), Curioso (não casa com o alarme). **Recomendo manter o Medroso.** Ofício "Aviso" (o chamado da crista antes do invasor, a 12 tiles) passa a M2 Should, cortável.

**Estrutura sugerida para o `SORA` (dados, sem estados soltos no código).**

- `ConductaDef` (recurso por espécie): `tipo`, `percepcao_tiles`, `gatilho_tiles`, `aviso_s`, `susto_s`, `velocidade_fuga`, `velocidade_perseguicao`, `fuga: {duracao_s, distancia_tiles, alerta_s, normal_apos_s}`, `curiosidade: {aproxima_s, fica_s, distancia_tiles, recarga_s}`, `revida` e `revida_duracao_s`, `chama_grupo: {raio_tiles, atraso_s}`, `desiste: {distancia_tiles, sem_visao_s, perseguicao_s}`, `ataca_dormindo` (`nunca|gatilho|ronco`), `alvos_dino`, `pesos_por_bioma`.
- **Uma máquina de estados genérica** (Normal, Alerta, Aproximando, Fugindo, Revidando, Perseguindo, Aviso) movida por **eventos** (`viu_jogador(dist)`, `atacado`, `perto_demais`, `perdeu_alvo`, `timeout`) e por uma **tabela de transições por tipo em dados**, em cima do `DinoStateMachine` atual. Nada de `if especie == ...` no código.
- Servidor decide tudo; replicar o id do estado (3 bits) e o alvo. Percepção por checagem de raio a cada 0,5 s [premissa de custo: dino x jogador, cabe até o M3; chunk e interesse no M4].
- Testes headless por tipo: cada linha da tabela vira um caso (gatilho, duração, volta ao normal), mais o caso de grupo e o de 25% de vida.

**Animação e áudio para o `YATORA`.** Por tipo: **Covarde** alerta com cabeça erguida, corrida de fuga, respiração ofegante; **Medroso** pose de susto parado, tremor, corrida; **Curioso** aproximação com cabeça inclinada, farejar, recuo; **Passivo** pastar, levantar a cabeça, empurrão de revide; **Semi-agressivo** postura de aviso (crista ou cauda erguida) e rosnado de 1,5 s, investida; **Agressivo** espreita, investida, ataque, farejar presa dormindo. Comuns: bocejo, cambaleio, mancar abaixo de 25% de vida, dormir. Ícones sobre a cabeça: "!" (hostil), "?" (curioso), gota (medo). Sons: grito de alerta que dispara o grupo, rosnado de aviso, rosnado de investida.

**Conflitos com o plano (novos):** ver itens 13 a 17 da seção 17.

### 6.8 Morte do dino

Dino sendo domado com vida 0 **morre** e a domesticação falha (racao.md 11.3). Dino domado com vida 0 fica **ferido** (com morte permanente de servidor, deixa carcaça e sacolinha do alforje: 5.6) e some por 5 min [premissa] para a base (não morte permanente na 0.2). Morte permanente é opção de servidor (seção 13). Estado Dead existe no plano (SOB-02). M2, Essencial na forma branda.

### 6.9 Nome do dino [decisão do dono]

Ao concluir a domesticação abre um campo para **batizar**; **pular mantém o nome da espécie**. O dono **renomeia** depois no painel do dino. Nome salvo no dino e exibido no painel e na lista do grupo. **Regras (servidor):** até 20 caracteres, texto limpo (sem marcação de formatação, sem caracteres de controle, espaços aparados e repetidos reduzidos), validado como pedido do dono; vazio volta ao nome da espécie. Limite de renomeação: 1 a cada 5 s [premissa]. **Marco M2** (junto da lista do grupo e do painel). **Filtro de palavras:** opção de servidor (`filtro_nomes`, lista de arquivo), fora do MVP.

### 6.10 Ajuste D17 (proposta da SHIRO): Listro e Clareira-brasa

- **Listro como Covarde, não Medroso.** O Parassaurolofo já é o Medroso. Com o Gallimimus cortado, o **Covarde** fica livre: o Listro (pequeno, escavador, foge ao ver o jogador a 85 px/s e some em toca) ocupa o tipo. No M4 a Conduta volta a **5 tipos** (Passivo, Agressivo, Semi-agressivo, Medroso, Covarde) mais o Curioso do Oviraptor = 6 com 6 espécies, sem repetir. Gallimimus sai do catálogo do MVP (fica como futuro).
- **Clareira-brasa sai do M4.** Perdeu a Seiva (trocada pelo Orvalho produzido por dino) e a Ração S (cortada); sobra só "bioma de nível alto", que a **Pedreira** cobre estendendo a faixa de 15 a 35 para 15 a 45. Fica com 3 biomas (Campina, Mata-baixa, Pedreira). **Custo:** MUN-11 e SOB-10 encolhem; o carnívoro territorial passa a viver na Pedreira. **Risco:** perde-se um destino de prestígio; compensa-se pelo ofício Produzir e pelo nível alto.

## 7. Coleta e crafting

- **Coleta:** nós de árvore, pedra, arbusto de baga, fibra, com respawn (MUN-02). Tempos [premissa]: baga 3 s/unidade, madeira 8 s por 3, pedra 10 s por 4.
- **Crafting:** `RecipeDef` por dados, **19 receitas na v0.2 (20 Saber)** (4 conhecidas: Fogueira, Lança de madeira, Machado e Picareta; o Bastão-de-sono já nasce no inventário no M1, sem receita; o resto por Saber, `receitas.md`). **Estações: Mãos (menu P; fibra, madeira e pedra), Bancada comum (metal e engenharia, Ração e reparo), Fogueira (assar) e o **Pilão** (portátil).** Regra de produção em 5.19. Sem timers de espera (espera sem decisão é defeito).
- **Receitas núcleo** [proposta]: Bastão-de-sono no inventário (M1, sem receita; receita de reposição Saber 1 no M2), **Preparado de sono** (3 frutas + 1 carne podre rendem 3, 4 s, **no Pilão, 5.18**; M2, aceito), Ração C a A (Bancada), fundação, parede, porta, baú (à mão).
- Tier 1: madeira, pedra, fibra, baga. Tier 2: Tubérculo, Sal, Mel (risco). Tier 3 (M4): Seiva, receitas de dino grande.

M1: coleta e arma de torpor. M2: tudo acima. **Cortável:** Mel e Ração S (racao.md, seção 2.4).

## 8. Construção e base

Grade de 16 px por `Vector2i` (CON-01). Peças da 0.2: fundação, parede, porta, baú (CON-02/03). Propósito (pilar 3): **abrigo** contra noite/predador, **guardar** (baú), e **ponto de ofício** dos dinos.

Conta do abrigo mínimo [premissa de custo]: 2x2 = 4 fundações (3 madeira + 1 pedra), 8 paredes (2 madeira), 1 porta (4 madeira + 1 fibra) = 32 madeira, 4 pedra, 1 fibra. Coleta ~8 s por 3 madeira: 32 madeira = 85 s de coleta + 20 s de pedra + caminhada: ~3 a 4 min de jogo [calculado com premissas]. Cabe na primeira hora.

M2 Essencial. Reparo de **peça** por ação: **cortado** (a peça tem vida e regenera: 8.1). Durabilidade de **item**: existe (5.9). Telhado, eletricidade: fora.

### 8.1 Dano em construções (decisão do dono, 06/11)

**Regra do dono:** dinos causam dano em construções de forma **decrescente: palha recebe mais que madeira; pedra recebe 0**. **Metal fica fora por agora**: nenhuma estrutura de metal. Simulação: `estruturas_sim.py`.

**Vida por peça [premissa]:** 30 por unidade de madeira, 10 por unidade de palha, pedra imune. Alvos: **parede, porta, cerca e portão**; fundação, baú e mobílias **não são alvo**.

| Peça (custo em madeira) | Palha | Madeira | Pedra |
|---|---|---|---|
| Cerca (2) e parede (2) | 20 | 60 | imune |
| Porta e portão de dino (4) | 40 | 120 | imune |

**Dano por espécie [premissa]:** `mordida / cooldown x fator`. Utahraptor L20: 11,2 / 1,5 s x **1,0** = **7,5/s**. Triceratops L28: 34,4 / 2,5 s x **2,0** (chifre e investida) = **27,5/s**. Passivo (Paquicéfalo), Medroso (Parassaurolofo), Covarde, Curioso e dino domado: **0**, nunca atacam peça.

**Quando atacam:** **Agressivo** (Utahraptor): com alvo dentro (jogador ou dino dormindo) e **sem caminho livre por 2 s**, bate na peça de bloqueio mais próxima (**substitui "desistem após 5 s"**). **Semi-agressivo** (Triceratops): só **provocado** (golpeado) e com alvo dentro. O **primeiro golpe do jogador provoca**: o carnívoro vai ao jogador, não à peça. Na 0.2 só o Utahraptor ataca estruturas.

**Tempo para romper uma peça [calculado]:**

| Peça | Utahraptor L20 (7,5/s) | Triceratops L28 (27,5/s) |
|---|---|---|
| Cerca ou parede de palha (20) | 2,7 s | 0,7 s |
| Porta ou portão de palha (40) | 5,4 s | 1,5 s |
| Cerca ou parede de madeira (60) | **8,0 s** | 2,2 s |
| Porta ou portão de madeira (120) | 16,1 s | 4,4 s |
| Pedra | imune | imune |

**O curral de madeira resiste à domesticação contra o Utahraptor? Não à inteira, sim à intervenção.** Domar leva **32 a 138 s** (5.14); a cerca cede em 8 s (16 s com duas camadas). A janela útil é o aviso de 3 s mais o nocaute do Utahraptor, 3,5 s com o Bastão (2,1 s com 10 pontos de Dano): **6,5 s**. Madeira cobre (8 s, 16 s em dupla); **palha não** (2,7 s, 5,4 s em dupla). Depois do nocaute o Utahraptor dorme cerca de 110 s. Contra o Triceratops provocado a madeira é papel (2,2 s): é aí que a pedra entra.

**Pedra imune torna a proteção trivial? Em campo não; na base sim, de propósito.** Curral 3 x 3 de pedra: 36 Pedra = **54 kg (108% do Peso)**, 90 s de mineração, 72 s de construção (6 s por peça): não cabe em volta de um dormindo na janela de 40 a 105 s nem na mochila. É proteção de **base**. **Limite mínimo, sem mudar a regra:** pedra só no **T3** (4 Saber e Tijolo), **3 a 4 Pedra por peça** (4,5 a 6 kg), **tempo de construção 6 s** (madeira 3 s, palha 1,5 s) e o **Peso** (8 peças por viagem). Em campo, a decisão é palha (leve, 1,2 kg o curral, 18 s, fraca) contra madeira (12 kg, 36 s, média).

**Reparo:** sem item e sem ação: a peça **regenera ao máximo em 60 s** depois de **10 s sem dano** [premissa]. Durabilidade de **item** é outra coisa (5.9). **Destruída:** a peça **some** (vão aberto), **sem devolver material**; fundação e mobílias ficam; o baú e seu conteúdo não são afetados; reconstruir paga o custo.

**Materiais da 0.2: só madeira** (nenhuma receita nova; o Utahraptor solitário é a única ameaça às peças). **Palha** (parede, cerca e porta, 1 Saber, nó de palha) **M4**; **pedra** **M4+** (T3); metal fora.

**Marco e custo [estimativa minha, premissa; `SHIKAMARU` confirma]:** M2. Vida por peça e dano 1,5 h; comportamento do atacante (bloqueio, alvo na peça) 3 h; regeneração e save (só peças com vida abaixo do máximo) 2 h; remoção da peça e atualização do caminho 1,5 h; feedback em 3 estágios 1,5 h; testes 1,5 h = **11 h**. **Menor recorte:** só madeira, só Utahraptor, sem regeneração e sem estágios = **6 h**.

**Ponto de atenção (durabilidade):** a vida da peça **não é durabilidade de item**; o item tem durabilidade própria (5.9) e a peça segue regenerando sozinha.

## 9. Progressão e desbloqueios

**Nível de personagem e pontos na versão enxuta** (decisão do dono, 5.1; **substitui o pilar "sem nível de personagem"**, item 14) além de **tier de receita** e **relacionamento**:

| Tier | Desbloqueia | Gate | Marco |
|---|---|---|---|
| 1 | Bastão-de-sono (inventário no M1), Bancada comum, Ração C, abrigo | Coletar | M1/M2 |
| 2 | Ração B e A, baú | Ingrediente de bioma 2 | M2 |
| 3 | Ração S, ofício avançado | Ingrediente de risco, Afeto 40 | M2 Should/M4 |
| 4 a 5 | S+, dinos grandes, região nova | Campanha de recurso | M4 |

**Desbloqueio por Saber (decisão do dono, 06/11):** o personagem **aprende receitas gastando Saber**, moeda separada dos pontos de atributo (1 por nível, +1 nos níveis 5, 10, 15 e 20); o tier continua sendo o gate de **ingrediente**. Árvore em cinco categorias (armas, armaduras, mobílias, construções, recursos diversos), 57 receitas na 1.0 e **19 na 0.2** (6 conhecidas, 22 Saber): `receitas.md`, `receitas_sim.py`. Substitui "desbloqueio por ter feito". Plano: PRO-10 (3 a 5 tiers, M4); 0.2 só 2 tiers.

## 10. Economia de recursos

| Recurso | Fonte [premissa] | Ralo | Limite natural |
|---|---|---|---|
| Madeira | Árvore: 3 por 8 s, respawn 5 min | Construção, receitas | Respawn |
| Pedra | Nó: 4 por 10 s, respawn 8 min | Construção, flecha (M4) | Respawn |
| Fibra | Planta, 3 s/unidade | Flecha (M4), porta | Respawn curto |
| Baga | Arbusto: 3 por 9 s, respawn 4 min | Fome, Ração, domar | Respawn |
| Carne | **Carcaça de Dodo, Listro e dinos (5.6), com Lança** | Fome, Ração Rubra | Respawn das presas (10 min) |
| Fruta-do-sono | Arbusto, respawn 6 a 8 min | Torpor do dino dormindo (5.5) | Respawn, ação 1,5 s |
| Carne podre | **Carcaça velha (carniça) e pilha de carne vencida (5.9)** | Preparado de sono | Duas fontes coexistem |
| Tubérculo, Sal | Nó: respawn 6 a 8 min | Ração B, A, S | Respawn |
| Mel, Seiva | Nó de risco, respawn 8 a 15 min | Ração S, S+ | Máx. 8 S+/h |
| Ração | Bancada comum | Domar, alimentar | Ingredientes |

Ralos permanentes: **fome do jogador**, **fome do rebanho** (fixa), **flechas** (M4). **Ralo de reparo** (5.9, ~0,6% do tempo na 1ª hora) e **validade da comida** (5.9). Acúmulo: stack e Peso limitam (inventário finito); respawn limita. Ver `racao.md` seções 2.3 e 4.3.

## 11. Combate e perigo

- Combate **simples**, com dano e torpor separados por arma [proposta, números [premissa]]: **Bastão-de-sono** (M1): dano 2, torpor 30, 0,7 s, serve para nocautear; **Lança-de-pedra** (M2): dano 18, torpor 6, 0,9 s, serve para caçar e defender e **não nocauteia** (6 em 0,9 s é 6,7/s contra queda de 5/s). Mãos nuas (dano 2) cortáveis. Jogador foge, nocauteia ou mata.
- **Atacar o dormindo causa dano e tira Eficiência** (jogador: 4 fixo + 0,5 por 1% da vida; carnívoro: 8 fixo + o mesmo termo). Dano em dino acordado só tira vida.
- **Carnívoro ataca dormindo** (raio de ronco 8 tiles; aviso de ~3 s; M2). Defesa: matar, provocar ou cercar com **curral**.
- **Perigo legível** (pilar 2): sombra, som e barra antes do ataque; carnívoro avisa 1,5 s [premissa].
- Dano ao jogador: do carnívoro agressivo e da fome. Sem dano ambiental na 0.2, exceto zona de marimbondos (Mel).
- Dinos defendem por ordem e por Afeto. Pico: carnívoro persegue durante a vigília de domar. Respiro: bioma seguro (Campina de dia).

M1: Flee, Chase, Attack (CRI-04). M2: invasão da base. M4: ameaças e dificuldade (SOB-10). **Cortável**: invasão escalonada.

## 12. Morte e penalidade

Morte do jogador: **cai o inventário num corpo recuperável** (SOB-02), volta numa cama/ponto de respawn, perde nada além do tempo. Mínimo no M1 (respawn), completo no M2. Conta: se a recuperação leva 2 a 3 min [premissa], a penalidade é ~3 min, no ritmo de sessão de 45 min são 6,7%. [jogar]: se não dói, sobe (o plano aceita "custa algo, não destrói horas").

Opção de servidor: corpo some em N min; morte permanente de dino (seção 13).

## 13. Co-op e regras de servidor

Co-op é **M3** (plano), não Must da 0.2; o design já assume 2 a 8 jogadores. Servidor autoritativo (ADR-001); single-player é host local. Servidor pequeno, imagem Docker, uma porta UDP.

Regras configuráveis por servidor (arquivo de dados; todo valor que varia):

| Chave | Padrão | O que muda |
|---|---|---|
| `multiplicador_refeicao` | 1,0 | Tempo de domar (Ração) |
| `multiplicador_coleta` | 1,0 | Quantidade por nó |
| `respawn_recurso` | 1,0 | Respawn |
| `dano_fome` | 1,0 | Dano de fome |
| `morte_item` | corpo | corpo / perde / mantém |
| `dino_ferido_minutos` | 5 | 0 desliga, -1 permanente |
| `afeto_decai` | 1,0 | Ritmo de negligência |
| `eficiencia_fixa_ataque_jogador` / `_carnivoro` | 4 / 8 | Perda de Eficiência por ataque ao dormindo |
| `raio_ronco_tiles` | 8 | Detecção do dormindo pelo carnívoro |
| `faixas_de_nivel` | 10.3 | Níveis por bioma |
| `eficiencia_drena_tempo` | **0,15/s (decidido; era 0,3)** | Pressão de domar demorado |
| `domar_velocidade` | 1,0 | Taxa de domar: tempo / taxa (5.14) |
| `pontos_por_nivel` / `valor_ponto` | 1 / 6% | Pontos por nível e valor de cada um |
| `jogador_nivel_max` / `dino_nivel_max` | **20 / 50 (MVP)**; 1.0: 75 / 75 | Tetos de nível do jogador e do dino (o do servidor vence; 5.16) |
| `dino_nivel_spawn_max` | 30 | Teto de nível ao nascer |
| `dino_teto_multiplicador` / `dino_teto_base` | 2,0 / `final` | Teto de evolução do dino = multiplicador x nível de doma (`final` ou `selvagem`) |
| `multiplicador_xp` | 1,0 | Ritmo de nível |
| `filtro_nomes` | desligado | Lista de palavras bloqueadas |

Regra de co-op: vários jogadores no mesmo dino acordando-o: o último a golpear não zera o progresso de domar. Vínculo é com o jogador que domou; o dono pode **compartilhar** (ordem de grupo) [decisão do dono]. M3, Essencial só na 0.3.

## 14. Direção de arte e tom

Coerente com a landing (`html/`: "um vale cheio de dinossauros esperando um amigo", chips "Já existe/Vem aí", linguagem leve, papel e cores quentes). **Propaganda carismática; jogo respeitoso.**

- **Mundo**: cores quentes, vale de dia ensolarado, noite azulada. Pixel art 16 px; jogador 16x24, dino 24 a 48 px (D2).
- **Adultos**: silhueta clara e proporção realista estilizada; olhos pequenos e sem expressão "fofa"; carnívoros com leitura clara de ameaça (postura, cor de alerta).
- **Filhotes**: cabeça grande, olhos grandes, animação expressiva. É o único lugar de carisma explícito.
- **Humor**: textos curtos e secos, uma piada por tela; a landing já fala "tirar uma soneca". O humor vem do **contraste**: lanchinho para um bicho que te comeria.
- **Interface**: ícones legíveis; sem gradiente exagerado; barras de torpor e domar sempre visíveis.
- **Som**: ambiente do vale, cada espécie com som próprio de aviso.

**CONFLITO 3 (landing)**: a landing diz "faça um dinossauro tirar uma soneca... é seu parceiro", tom carismático. Coerente com propaganda, mas fica **honesta** se o jogo mostrar adultos neutros: ajustar a landing para não prometer dino fofo em jogo (decisão do dono). Arte de IA só placeholder (D3).

Marco: guia de arte M1; kit v0 M2; arte final M5.

## 15. Onboarding e primeira hora

Tutorial contextual (UIX-05, M2): dicas por evento, sem tela de texto.

Revisto em 06/11: **o Bastão-de-sono nasce no inventário no M1, sem receita**; Bancada e Ração C são aprendidas; **o Dodo só existe a partir do início do M2** (esta tabela é a v0.2 inteira). XP: 10 por min até o L5 e 13 depois [premissa]; **abater dá XP: Dodo 3, Listro 4**, coletar e domar dão o resto. `receitas_sim.py` e `durab_sim.py`.

| Minuto | O que acontece [premissa] | Número |
|---|---|---|
| 0 a 1 | 2 graveto + 3 madeira à mão, faz a **Lança** (menu P, conhecida) | ~25 s de coleta |
| 1 a 4 | O **Dodo** (Curioso) se aproxima; 2 golpes de Lança, coleta 2 carne + 1 couro | ciclo ~30 s, 3 XP: **L2 aos 3 min** (30 XP) |
| 4 | **Saber 1: Bancada** (8 madeira + 2 pedra, à mão); com Picareta e Machado conhecidos | Bancada no minuto 5 |
| 5 a 8 | Mais Dodos; **L3 aos 7,5 min** (75 XP): +2 Saber (3 no total): **Ração C** e 1 de sobra (a receita do Bastão repõe o do inventário) | Saber 3 |
| 8 a 12 | **Primeira domesticação: Paquicéfalo L5 a L8.** Nocaute: **Bastão do inventário, 4 golpes, 2,1 s** (Soco 15 golpes em 8,4 s só se o Bastão quebrar). **15 bagas (45 s de coleta), 90 s dormindo, 2 a 3 reforços de Bastão** (5.14) | **marco: dino domado em até 12 min** [premissa]; ~3 min de ação |
| 12 a 20 | Abrigo (Saber 1, L4 aos 13 min), curral (Saber 2); Machado e Picareta já gastam ~1 reparo na hora | 3 a 4 min de coleta |
| 20 a 35 | **L5 aos 21 min: 6 Saber (Ração B, Cerca e curral).** Caçar 13 Dodos (6,5 min) = 25 carne para a Ração Rubra C, ou 6 Dodos (3 min) = 11 para B | **Utahraptor domável a partir do M2, ~35 min; 0,6 a 1,8 min de domar** |
| 35 a 50 | Nocautear o Utahraptor com Bastão (5 golpes); vigília e alimentação (validade da carne: 30 min, margem 3x) | primeiro perigo real |
| 50 a 60 | Baú, carga, ofício; salvar e sair | ofício carregar |

**Caminho mínimo de domesticar sem os três itens:** o Paquicéfalo aceita **baga crua** e o **Bastão do inventário** o nocauteia: **0 Saber**. Para o Utahraptor: **Bancada (1) + Ração C (1) = 2 Saber, no L3 (7,5 min)**, mais Lança e Dodos para a carne. **Onde se fabrica sem Bancada:** no menu P, à mão, **tudo o que é de fibra, madeira e pedra** (regra 5.19): as 4 conhecidas, Bancada, Bastão, Pilão, Baú, Cocho, Abrigo, Cerca, Portão e Bandagem. **Precisa jogar:** o ritmo de XP por abate e se o Soco de 8,4 s no Paquicéfalo é divertido ou só um muro antes do Bastão.

Metas do plano: 3 de 5 testadores completam o fluxo em até 20 min (M1) [premissa do plano]; hipótese H1: a vigília gera tensão, não espera. A primeira hora fecha o loop inteiro uma vez.

**Primeiro minuto**: uma única instrução visível; nenhum menu.

## 16. Resumo por sistema

| Sistema | Marco | v0.2 |
|---|---|---|
| Vida, stamina, fome | M1 | Essencial |
| Coleta, inventário | M1 | Essencial |
| Domar (baga crua) | M1 | Essencial |
| Ordens seguir/ficar | M1 | Essencial |
| Morte e respawn mínimos | M1 | Essencial |
| Ração C a A (Bancada) | M2 | Essencial |
| Nível, Eficiência, nível previsto, painel de 3 barras | M2 | Essencial |
| Barra de vida (após dano, máx. 3) | M2 | Essencial |
| Bastão-de-sono (dano 2, torpor 30) | M1 | Essencial |
| Lança de madeira (dano 12, torpor 0) | M1 | Essencial |
| Durabilidade, reparo e validade (5.9) | M1 (modelo) e M2 | Essencial |
| Dodo (presa); Listro no M4 | início do M2 / M4 | Essencial / Should |
| Carnívoro ataca dormindo; curral | M2 | Essencial (M1 só se H1 for testada lá) |
| Soco e Bastão-de-sono | M1 | Essencial |
| Flecha de sono (torpor contínuo, teto de 3 efeitos) | M4 | Should (~8 h) |
| Fruta-do-sono e forçar o dino; sinais no jogador | M2 | Essencial (~7,5 h) |
| Preparado de sono e Carniça | M2 | Cortável (~2 h) |
| Sono do jogador, Arco e flechas, espada, carne que apodrece | M4 | Fora da 0.2 |
| Armas de fogo e pólvora | -- | **Fora do jogo (decidido)** |
| Carcaça e sacolinha (só carne; couro sem uso) | M2 | Essencial (~9 h); completa ~14 h |
| Faixas de torpor (visual) e regra de lentidão | M2 | Essencial; **pausa já implementada, sem custo novo** |
| Afeto e obediência | M2 | Essencial |
| Ofícios carregar/defender (Peso) | M2 | Essencial |
| Barra de atalhos 1 a 9: comida e equipar | M1 | Essencial |
| Rifle, Dardo, arma de fogo, pólvora, fósforo e sílex | **sem marco** | Adiados (decisão do dono, 06/11) |
| Dar comida ao dino pela tela dele (E) | M1 | Essencial, **já implementado** |
| Atributos, XP e pontos do jogador (nível 20, 4 atributos) | M2 | Essencial (decisão do dono, ~17 h) |
| XP de companhia e pontos do dino (Vida, Dano; +10 níveis) | M2 | Essencial (idem) |
| Respec, teto por atributo, XP por ofício | depois | **Fora da 0.2** |
| Saber e tela de receitas (19 receitas) | M2 | Essencial (~11 h, 9 além do PRO-04) |
| Dano em construções (madeira, Utahraptor) | M2 | Essencial (~11 h; recorte 6 h) |
| Stamina em golpes e coleta | M2 | Essencial (~3 h) |
| Palha e pedra como material | M4 | Fora da 0.2 |
| HUD: vida, fome, XP com nível e aviso, atalhos; ofego | M2 (M1 vida, fome, atalhos) | Essencial (~5 h) |
| Nome do dino | M2 | Essencial barato |
| Construção básica | M2 | Essencial |
| Ração S, Mel | -- | **Fora da 0.2 (camada 1)** |
| Dia/noite | -- | **Fora da 0.2 (camada 1)** |
| Temperamento do carnívoro domado | -- | **Fora da 0.2 (camada 1)** |
| Conduta: Passivo e Agressivo (Paquicéfalo, Utahraptor) | M1 | Essencial |
| Conduta: Semi-agressivo (Triceratops) | M2 | Essencial |
| Conduta: Covarde (Gallimimus) | M4 (Listro) | **Fora da 0.2 (camada 1)** |
| Conduta: Medroso (Parassaurolofo) | M2 | Essencial |
| Conduta: Curioso (Oviraptor) | M4 | Fora da 0.2 |
| Grupo chama grupo | M2 | Essencial para Passivo; resto cortável |
| Co-op e servidor | M3 | Fora da 0.2 |
| Criação (ninho, filhote) | M4 | Cortável, identidade |
| Ração S+, Seiva | M4 | Cortável |
| Chunking, seed, 8 espécies | M4 | Fora |

## 17. Conflitos com o plano e o escopo

1. **D5**: o plano recomenda "cuidado e ofícios". Proponho Afeto, Temperamento e Criação; a 0.2 só precisa do Afeto e de dois ofícios. Não alterei o plano.
2. **Fome**: 0,5/s em código esvazia em 3,3 min. Recomendo 0,1/s. Ajuste de dado.
3. **Landing x tom**: propaganda carismática é coerente, mas a landing sugere "dino parceiro fofo"; precisa de revisão para não prometer o que o jogo não entrega.
4. **Crafting é M2, não M1**: o plano põe PRO-04 no M2; a Ração com receita só chega lá. O M1 usa baga crua (racao.md, 2.4).
5. **Espécies**: o plano cita "3 a 4 espécies" na 0.2 (CRI-03: 2, CRI-06: 3 e 4); minha conta fecha com 3. A 4ª é cortável.
6. **Cozinhar é Could** no plano; a Ração usa a **bancada comum** (decidido 05/11), então não há estação extra além da prevista em PRO-04. Conflito resolvido.
7. **Golpe em dino inconsciente deixa de ser grátis** (muda comportamento já implementado em `Dino.apply_torpor` e `Player`; racao.md, seção 0).
8. **Criação de filhote** é novo escopo (M4); não existe no plano.
9. **Nível, Eficiência e vida do dino** (decisões de 05/11) são sistemas novos no M2 que o plano não lista: CRI-03/CRI-05/CRI-07 aumentam (nível e vida na `SpeciesDef`, Eficiência no domar, UI de 3 barras). Não estimei horas; o plano precisa reestimar (aviso ao `SHIKAMARU`).
10. **Combate com dano** (Bastão com dano 2, Lança) altera o ataque atual, que só causa torpor (CRI-01 em andamento).
11. **Carnívoro atacando o dormindo** é comportamento novo; CRI-04 (M1) prevê só Chase e Attack no jogador.
12. **Morte do dino**: plano cita estado Dead (SOB-02) sem dizer se permanente; aqui é "ferido" por padrão.
14. **Nível de personagem e pontos** (5.1): o plano tem "sem nível de personagem" como pilar. Decisão do dono; o design limita o risco (abater não dá XP, teto por atributo, 29 pontos em 30 níveis) mas o plano precisa ser corrigido pelo `SHIKAMARU`.
15. **Inventário por Peso** troca o inventário em slots do plano (itens de inventário, UI de HUD e ofício carregar); exige tela de atributos e de alforje, sem estimativa minha.
16. **Barra de atalhos** (5.2) não está no plano; M1 pede UI de 9 posições e ação por item.
17. **Nome do dino** e **save**: o save passa a guardar nível, pontos, XP e nome por dino e jogador (bump de versão).
22. **Carcaça e sacolinha** (5.6): entidades salvas no mundo e coleta com Peso; não estão no plano; o fim da dúvida do `LEVI` (comida de dino morto) vira regra. Carne podre agora também vem da carniça (carcaça velha).
18. **Carne podre** (revisto 06/11): a validade por pilha existe (5.9) e `racao.md` 2.4 (validade cortada) perde: a recomendação do nó de Carniça cai; a carniça é só estado da carcaça.
19. **V6** (torpor contínuo como manutenção do dormindo) é revisto: fruta e preparado a substituem; a flecha de sono (M4) passa a ser ferramenta de dino acordado.
20. **Torpor do jogador** (sinais e, no M4, sono) não está no plano; reaproveita o `TorporComponent`.
21. **Dose da flecha de sono** (antes dose do dardo, 50): 15 imediato + 12/s por 5 s = 75; `racao_sim.py` guarda o 50 antigo só como histórico (sem Dardo no jogo).
23. **Receitas por Saber** (receitas.md): PRO-04 e PRO-10 do plano não têm moeda nem tela de aprender; o texto "por ter feito" do GDD 9 foi substituído. Estimativa de 9 h além do PRO-04, sem valor oficial.
24. **HUD** (5.7): barra de XP, aviso de ponto e ofego no lugar da barra de stamina não estão no plano; se o HUD atual tem barra de stamina, ela sai.
25. **Durabilidade (revisto 06/11):** o GDD cortava; agora existe (5.9). **Muda o inventário do código** (`{id,count}` e barra por tipo): item individual e slot na barra; a camada de salvar sobe de versão.
26. **Conduta:** "desistem após 5 s sem caminho" vira "ataca a peça de bloqueio" para o Agressivo (8.1); `Dino` ganha comportamento novo.
27. **Reparo:** o de **peça** continua cortado (regenera, 8.1); o de **item** existe na Bancada (5.9).
28. **Stamina:** o `Player` atual não gasta Stamina em golpe nem coleta; agora gasta (5.8).
29. **Lança** (CRI-13 do plano, M4) volta como **Lança de madeira no M1** e contradiz a camada 1 (5.3); o CRI-12 (carnívoro ataca o dormindo) segue como estava.
30. **Dodo e Listro** passam a 6 espécies na v0.2 (plano prevê 4 a 5) e antecipam as Condutas Curioso e Covarde (6.7) do M4 para o início do M2 (Dodo); o Covarde (Listro) volta ao M4.
31. **Estações:** "uma só estação, a Bancada" (5/11) vira Mãos + Bancada + Fogueira (`receitas.md` 10).
32. **Receitas conhecidas:** de 6 para 4 (Fogueira, Lança, Machado, Picareta); Bastão, Bancada e Ração C custam Saber; +1 Saber no L3 (24 no L20).
33. **Utahraptor domado fica no M2** (precisa carcaça, Lança e Dodo); no M1 é só ameaça. **Sem Dodo no M1 não há presa nem carne:** a Lança só serve contra Paquicéfalo e Utahraptor (decisão do dono, 06/11).
34. **Fome do jogador** (5.10): substitui o dano de fome do `HungerComponent` (morte em 40 s vira ~5,2 min) e antecipa o estado inconsciente do jogador (M4) para o M2; queda de 0,5 para 0,2/s.
35. **Armadura** (5.11): 3 conjuntos, 1 vaga, dano mínimo 1; Escudo e pele saem; **temperatura fora, sem marco**.
36. **Cocho** (5.12): fica em M2 cortável (Saber 2, 8 madeira); a fome 0 do dino domado passa a ter efeito (Afeto e ofício), onde a tabela 5.1 dizia "nenhum".
37. **Tecla de atalho e Oferta** (5.13): a tecla só consome pelo jogador; alimentar dino é pela tela do dino (E, já implementada) ou pelo slot de Oferta; o cocho não consta na regra 2 (tratado como inventário do rebanho); domar passivo **adiado para depois do playtest**; o atalho em dino da 5.2 saiu.
38. **Rifle e Dardo (decisão final do dono, 06/11): adiados sem marco**; a exceção do Rifle de mola e o conflito 41 deixam de existir. A 1.0 só tem arco, besta e boleadeira (5.4). Sem consumo para o sílex, o fósforo e a pólvora.
39. **Tempo de domar** (5.14): o nível pesa mais (0,033 por nível, antes 0,015) e os fatores por espécie mudam; a tabela de 60 s, 105 s e as Dificuldades antigas ficam desatualizadas; recomendo `eficiencia_drena_tempo` 0,15.
40. **Tetos de nível** (5.16): o teto "captura + 10" e o 75 fixo caem; `pontos_sim.py` (`CAP_EXTRA` removido; `MULT` 2 e `DINO_MAX` 50) já corrigido; o save acima do teto só trava.
41. **Pólvora, fósforo e sílex:** sem marco e sem consumidor (5.18); o químico de sono do pedido é o Preparado de sono (um só nome). O carvão só serve à Forja.
42. **Regra de produção** (5.19): fibra, madeira e pedra à mão; metal e engenharia na Bancada. A Bancada fica com 3 receitas na v0.2 (Ração) mais o reparo.
43. **Dodo no início do M2** (dono): o M1 fica sem presa (a Lança só encontra Paquicéfalo e Utahraptor); o XP do M1 vem de coletar, craftar e domar.
44. **Bastão-de-sono nasce no inventário no M1, sem receita** (a receita de reposição, Saber 1, é do M2). O roteiro do M1 (15) deixa de craftar o Bastão.
45. **Triceratops L28 e acima sem o Rifle:** a faixa da 1.0 fica em L18 a L24 (5.15); liberar L25 a L28 é opção do dono, com couro, Arco ou metal.
46. **Flecha de sono entra no M4** (recomendo, 5.4): dá segundo consumidor ao Preparado sem inventar sistema; **cortável: Boleadeira e Besta**.
13. **CRI-04 (M1)** prevê "Flee (herbívoro), Chase e Attack (carnívoro)". Seis tipos de Conduta exigem uma máquina de estados orientada a dados; o herbívoro do M1 é **Passivo** (revida), não foge. Cabe ao `SHIKAMARU` reestimar.
14. **Tipos x espécies** (CRI-03, CRI-06): a 0.2 mostra 4 tipos com 4 espécies (cabe no plano); o Gallimimus eleva a 5 espécies e 5 tipos, **acima** dos 3 a 4 do plano; Curioso só no M4 (CRI-10).
15. **"Isca"** aparece no core loop do plano (seção 2) sem tarefa no backlog. Se o Covarde entrar na 0.2 e a corrida não bastar, a isca vira necessária.
16. **Grupo chama grupo** e percepção por raio custam replicação e CPU no M3; ainda sem orçamento (NET-10/NET-12, NET-20).
17. **Domesticação de quem corre** exige perseguição jogável em obstáculos (colisão do mapa, MUN-01); sem testes de cena, só em playtest.

## 18. Perguntas de visão para o dono

| # | Pergunta | Recomendação |
|---|---|---|
| V1 | O diferencial do jogo é Afeto + Temperamento + Criação, ou só cuidado e ofícios? | Afeto na 0.2, Criação como meta do M4 **DECIDIDO (05/11).** |
| V2 | Carnívoro domado continua agressivo com estranhos? | Sim, por Afeto menor que 40; liga ao tom decidido **DECIDIDO (05/11).** |
| V3 | Dino domado pode morrer para sempre? | Não por padrão, opção de servidor **DECIDIDO (05/11).** |
| V4 | A landing será ajustada para o tom "vale acolhedor, bicho perigoso"? | Sim, trocar "parceiro" por promessa honesta **DECIDIDO (05/11).** |
| V5 | A qualidade S+ da Ração entra na 0.2? | Não; S, A, B, C na 0.2, S+ no M4 (`racao.md`) **DECIDIDO (05/11).** |
| V6 | Torpor contínuo é a manutenção barata do dormindo (sem dano, -2 E)? | Sim; golpe no dormindo fica caro por regra do dono **DECIDIDO (05/11).** **Revisto (06/11):** fruta e preparado são a manutenção; a flecha de sono (M4) é de dino acordado (5.5). |
| V11 | Fixo de 4 (jogador) e 8 (carnívoro) por ataque ao dormindo, e raio de ronco de 8 tiles? | Sim, a testar; alavancas em racao.md 11.1 **DECIDIDO (05/11).** |
| V12 | Carnívoro atacar o dormindo no M1 ou no M2? | M2; no M1 só persegue o jogador **DECIDIDO (05/11).** |
| V13 | Eficiência 0% doma sem bônus e sem penalidade extra? | Sim **DECIDIDO (05/11).** |
| V14 | Faixas de nível por bioma, teto 1,5x, nível-base 10 | Aceitar para testar **DECIDIDO (05/11).** |
| V15 | Bastão 30 de torpor a 0,7 s no lugar dos 3 golpes de 40 atuais? | Sim, para o torpor acordado ser legível **DECIDIDO (05/11).** |
| V16 | Seis tipos de Conduta: aceitar só 3 a 4 na 0.2 e os outros no M4, ou usar variantes por indivíduo no Paquicéfalo da Mata-baixa? | 3 tipos (4 com o Gallimimus) na 0.2; variantes só se faltar variedade no playtest **DECIDIDO (05/11, aceita a recomendação).** Atualizado depois: o dono incluiu o Parassaurolofo (Medroso) no M2, então a 0.2 mostra **4 tipos (5 com o Gallimimus)**. |
| V17 | Paquicéfalo (herbívoro do M1) como Passivo, não Covarde? | Sim, tutorial depende de poder bater e domar **DECIDIDO (05/11, aceita a recomendação).** |
| V18 | Atacar um membro chama o grupo a 8 tiles? | Sim **DECIDIDO (05/11, aceita a recomendação).** |
| V19 | Níveis dão pontos ao jogador e ao dino (1 ponto = 6% da base)? | **DECIDIDO (06/11, dono)** |
| V20 | Os níveis de bônus da Eficiência dão pontos ou vêm aplicados? | **Aplicados**, recomendação; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V21 | Tetos: jogador 20, dino +10, sem teto por atributo | **DECIDIDO** (versão enxuta, 06/11) |
| V22 | Respec e perda de XP na morte | Sem respec e sem perda na 0.2 **DECIDIDO** (versão enxuta) |
| V25 | D17: Listro como Covarde e Clareira-brasa fora do M4 | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V26 | Utahraptor solitário na 0.2 e primeiro golpe provoca (5.3) | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V27 | Regra de armas: torpor zero em flecha comum, besta, lança e espada; torpor próprio em soco, porrete, flecha de sono e dardo; contínuo em flecha e dardo | **DECIDIDO (06/11, dono)**; valores em 5.4 |
| V28 | Armas de fogo | **Fora do jogo, sem marco, e a pólvora não entra DECIDIDO (06/11, dono; reafirmado na decisão final).** |
| V29 | Acúmulo de doses: soma até 3, a 4ª renova a mais antiga; flecha de sono em dormindo -2 E; contínuo não é ataque | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V30 | Fruta-do-sono e preparado forçam o dino sem custo de Eficiência; preparado = fruta + carne podre | **DECIDIDO (06/11, dono)**; números em 5.5 |
| V31 | Carne podre: carcaça velha **e** pilha vencida; nó de Carniça cortado | **DECIDIDO (06/11, dono; substitui a recomendação anterior).** |
| V32 | Jogador come fruta: sinais no M2, sono no M4 | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V33 | Carcaça com carne e couro, sacolinha no chão | **DECIDIDO (06/11, dono)**; números em 5.6 |
| V34 | Comida do alforje de dino morto vai para a sacolinha | Recomendo **sim**; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V35 | Couro na 0.2 sem uso: Bastão reforçado ou M4? | **Bastão reforçado CORTADO (06/11, dono)**: o couro só tem uso no M4. |
| V36 | Tempos: carcaça 10 min, carniça até 20, sacolinha 10, só dono 120 s | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V37 | Saber: moeda separada, 1 por nível, +1 no L3 e nos níveis 5, 10, 15 e 20 | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V38 | 0.2 com **19 receitas (4 conhecidas, 20 Saber de 24)**, aprender tudo no teto; 1.0 (41 receitas, 73 Saber, completa no L61) não; sem reinício | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V39 | Armadura: 3 conjuntos, 1 vaga, dano mínimo 1; **fibra depois do playtest, fora da v0.2** | **DECIDIDO (06/11, dono).** |
| V40 | Mobílias com função; fogueira passa a ter função (assar), pilão fora | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V41 | Pergaminho ensina sem gastar Saber (S e S+ só por pergaminho, M4) | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V42 | Pontos do dino em Vida, Dano e Peso; Stamina espera montaria | **DECIDIDO (06/11, dono).** |
| V43 | HUD do jogador: vida, XP, fome, atalhos; sem barra de stamina, sem sede; sem durabilidade (5.7) | **DECIDIDO (06/11, dono).** |
| V44 | Dano de dino em construções decrescente: palha mais que madeira, pedra 0; metal fora por agora | **DECIDIDO (06/11, dono).** |
| V45 | Golpes e coleta gastam Stamina | **DECIDIDO (06/11, dono).** |
| V46 | Vida por peça (palha 10, madeira 30 por unidade), dano estrutural, regeneração de 60 s | **DECIDIDO (06/11, dono).** |
| V47 | Custos de Stamina (Soco 3, Bastão 6, tiro de arco 4; coleta 2 a 4/s; **Lança 5, carcaça 3/s**) | **DECIDIDO (06/11, dono).** |
| V48 | Fonte de carne sem Lança | **RESOLVIDO (06/11, dono): Lança de madeira + Dodo e Listro; presa abatida e Carniça (nó) cortadas.** |
| V49 | Durabilidade (lança 80, machado 150, picareta 120, bastão 120; zero = quebrada; reparo na Bancada por 50%, sem reduzir o máximo; sem barra na HUD) | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V50 | Validade (carne 30 min, assada 90, baga 45, fruta 30, preparado 45; Ração não vence; juntar até 2 min; baú igual) | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V51 | Metal: Forja (**construída na Bancada, decidido 06/11**, e estação dos itens de metal), Barra, Espada no M4, Machado e Picareta de ferro no M5; nada na v0.2; construções de metal fora | Forja na Bancada **DECIDIDO (dono)**; marcos recomendo, **PENDENTE** |
| V61 | Forja: queima 3 madeira em 1 carvão (30 s) e converte 2 minério + 1 carvão em 1 barra (10 s); 4 vagas, funciona longe, carvão só da Forja ou também Fogueira | Regra **DECIDIDA (dono)**; números e o uso do carvão: **PENDENTE** |
| V62 | Pilão (à mão, portátil, Saber 1) e Preparado no Pilão: **v0.2 com 19 receitas e 20 Saber** (antes 21 e 23); fósforo, pólvora e sílex **sem marco** | **DECIDIDO (dono, 06/11).** |
| V63 | Rifle, Dardo, arma de fogo, pólvora, fósforo e sílex | **Adiados sem marco (decisão final do dono, 06/11).** |
| V64 | Armas à distância: arco, flecha comum e **flecha de sono** (M4), boleadeira (M4), besta (M5); Preparado como ingrediente da flecha de sono | Recomendo; **PENDENTE** (números em 5.4: flecha de sono 75, Besta 22 de dano a 14 tiles, Boleadeira prende x0,4 por 5 s) |
| V65 | Regra de produção: fibra, madeira e pedra à mão; metal e engenharia na Bancada; Forja feita na Bancada | **DECIDIDO (dono, 06/11).** Ração na Bancada é recomendação minha |
| V66 | Aceitas: 2x sobre nível final, servidor só trava, dino 50 no MVP, Triceratops L18 a L24, Dodo no início do M2, carvão só na Forja, Pilão e Preparado na v0.2; cortes leves (sem Bastão reforçado, sem Cama, Saber em lista plana, dano em construções no recorte mínimo) | **DECIDIDO (dono, 06/11).** Corte maior só depois do QA-01a |
| V67 | Bastão-de-sono no inventário no M1, sem receita | Recomendo e confirmo; **PENDENTE** de aceite explícito |
| V68 | Triceratops da 1.0: L18 a L24 (menor ajuste) ou até L28 com couro, Arco ou metal | Recomendo L18 a L24; **PENDENTE** |
| V52 | Dodo presa sem domar; **Listro fora da v0.2, no M4 com o Oviraptor**; 5 espécies na v0.2 | **DECIDIDO (06/11, dono).** |
| V53 | Fome do jogador (queda 0,2/s, valores de comida) e morte por fome em ciclos | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V54 | Armadura: fibra 10%/2 kg/100, couro 25%/6 kg/150, metal 40%/12 kg/300 | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V55 | Cocho (alcance 6 tiles, 40 itens, validade corre, só domado) | **DECIDIDO (06/11, dono: números seguem a recomendação).** |
| V56 | Tecla de atalho sempre consome; dino come do inventário dele (tela, E) ou do Cocho; **jogador nunca consome Ração** | **DECIDIDO (06/11, dono)**; preparado de sono **ainda não decidido** |
| V58 | Dardo e Rifle de dardos (antes opção A, exceção às armas de fogo) | **SUBSTITUÍDO (decisão final do dono, 06/11): Rifle, Dardo, arma de fogo, pólvora, fósforo e sílex adiados sem marco** (V63). |
| V59 | Tempo de domar calibrado nos alvos de 5.14 (Paquicéfalo 1,3 a 2,0 min, Utahraptor 1,5 a 2,3, Parassaurolofo 1,1 a 1,9, Triceratops 4,8 a 7,0 com C), dreno por tempo 0,3 para 0,15, Paquicéfalo do tutorial L5 a L8 | Calibração decidida pelo dono; fatores e dreno recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V60 | Tetos de nível: spawn com poucos altos nas faixas de 5.16 e teto ao nascer 30; teto de evolução 2x o nível de doma, **sobre o nível final (B, recomendo)**; servidor vence (`dino_nivel_max` 50 no MVP, 75 na 1.0); XP trava sem acumular; save acima do teto só trava; `jogador_nivel_max` 20 (MVP) e 75 (1.0) | Regras **DECIDIDAS (dono)**; **ponto ambíguo: A, B ou C e reduzir ou travar: PENDENTE** |
| V57 | Slot de Oferta (domar passivo) | **ADIADO para depois do playtest (dono, 06/11)**; proposta guardada em 5.13 |
| V23 | Barra de atalhos 1 a 9 no M1 | **DECIDIDO (06/11, dono)**; recomendo M1 |
| V24 | Nome do dino, 20 caracteres, filtro como opção de servidor | **DECIDIDO (06/11, dono)**; M2 |
| V7 | Vínculo com o jogador que domou ou compartilhado no servidor? | Compartilhado com ordem de grupo (M3) **DECIDIDO (05/11).** |
| V8 | Sessão alvo é 30 a 60 min ou mais longa? | 30 a 60 min na 0.2; revisar no M4 **DECIDIDO (05/11).** |
| V9 | Fome mais lenta (0,1/s) ou o ritmo atual de 3,3 min? | 0,1/s **DECIDIDO (05/11).** |
| V10 | Estação da Ração: estação própria ou bancada comum? | Bancada comum **DECIDIDO (05/11).** |

## 19. Calculado x precisa jogar

**Calculado:** tempos de domar e % de janela (racao.md); fome 3,3 min vs 16,7 min; stamina 4 s/5,3 s; abrigo ~3 a 4 min de coleta com as premissas; tabela de custo por nível.

**Calculado (novo):** tabelas de nível, Eficiência, ataque ao dormindo e janela de reação (racao.md 10 e 11).

**Precisa jogar:** se 40 a 80 s de vigília é tensão; se 12 s até o pequeno morrer é justo ou punitivo; se o jogador entende nível previsto e Eficiência; se as faixas de torpor são legíveis sem barra; se 3 barras de vida cabem na tela; se um nível vale ~40 s de coleta; se Afeto é sentido; se o carnívoro domado agressivo diverte ou irrita; se a Criação compensa 20 min; se a primeira hora cabe no cronograma; se a morte pesa. Todo número marcado [premissa] está nessa lista até o playtest do QA-01.

## 20. Propostas em avaliação (domesticação)

**Decisão do dono (05/11):** aceitas as recomendações abaixo. **Na v0.2:** 1, 3 e 10. **No M4:** 6, 7 e 9. **Adiada:** 8. **Rejeitadas:** 2 e 5. **Item 4:** fica como opção de servidor `perde_estoque_ao_acordar`, desligada por padrão. Nenhuma regra decidida anterior foi alterada. Cada proposta vem com custo, benefício, marco e recomendação; todas as regras e números são nossos. Contas dos itens 1, 3, 4, 5, 7 e 9 em `nivel_sim.py` e cálculos de apoio no docs/design (`docs/design/`). Tudo [premissa] a validar em playtest.

### 20.1 Exigência por espécie (Ração mínima)
Cada espécie tem `racao_minima`; abaixo dela a Ração rende **50%** do progresso por refeição (rende menos que a comida crua, que é 10% por refeição); do mínimo para cima, funciona como hoje. Mínimos: Paquicéfalo C, Utahraptor B, Parassaurolofo C, Triceratops A, Gallimimus C.

| Espécie | Ração | Refeições | Tempo | Torpor da janela | Dardos (histórico, sem Dardo desde 06/11) | E final (sem ataque) |
|---|---|---|---|---|---|---|
| Utahraptor L15 | C (abaixo) | 26 | 130 s | 177% | 3 | 22 |
| Utahraptor L15 | B (mínimo) | 10 | 50 s | 61% | 0 | 75 |
| Triceratops L28 | C (abaixo) | 41 | 205 s | 198% | 6 | 0 |
| Triceratops L28 | B (abaixo) | 31 | 155 s | 135% | 2 | 23 |
| Triceratops L28 | A (mínimo) | 13 | 52 s | 45% | 0 | 78 |

- **Benefício:** dá sentido a cada nível (C para a 1ª espécie, B para a 2ª, A para a 3ª; S e S+ sobram como prêmio acima do piso) e amarra progressão a bioma: o Sal-de-veio (nível A) vem da Pedreira, onde mora o Triceratops. Resolve o "S+ vale para tudo" sem inflar o custo do S+.
- **Custo:** um campo por espécie e um multiplicador; a decisão cai (menos opções por espécie, o que reduz estratégia dominante, mas também a escolha).
- **Marco:** M2. **Recomendação: adotar**, com piso suave (50%), não proibição, e com comida crua isenta. Verificar o ciclo da Pedreira: o jogador precisa de Sal-de-veio antes de domar o Triceratops, mas o Sal fica onde ele patrulha. É intencional, e é risco a testar.

### 20.2 Fome como relógio da refeição (e comida errada comida)
O dino come quando sente fome (intervalo variável por espécie e comida); item errado no inventário pode ser comido e atrasa.
- **Conta:** com fração `w` de itens errados no inventário, as refeições desperdiçadas por refeição boa são `w/(1-w)`; com `w = 20%`, +25% de tempo (C no Paquicéfalo: 40 s viram 50 s e 25% mais drenagem de Eficiência). O intervalo variável sozinho (uniforme +-20% em 8 refeições) muda o total em ~1,6 s de desvio, ou 4% (imperceptível).
- **Benefício:** só o que se coloca no inventário passa a importar. Mas a "decisão" é trivial (não colocar lixo), então é custo sem escolha.
- **Custo:** modelo de fome por dino, aleatoriedade (não reprodutível e mais difícil na rede) e testes não determinísticos.
- **Marco:** M4 no mínimo. **Recomendação: não adotar.** Alternativa de custo zero: variação de apetite por id do dino (determinística, +-20%) se quiserem sensação de bicho vivo.

### 20.3 Sem comida, o progresso regride
- **Regra proposta:** depois de 1 intervalo sem comida, perde 1% por segundo.
- **Conta:** ausente por 10 s perde 5% (0,4 refeição de C); 20 s perde 15% (1,2 refeição); 40 s perde 35% (2,8 refeições). Em C, uma refeição vale 12,5%.
- **Benefício:** quem conta mal as Rações ou se afasta para buscar mais sofre; casa com a prévia (20.10) que diz quantas levar.
- **Custo:** baixo (um timer no `TamingComponent`); a janela de torpor já pune a falta de comida, e a regressão duplica a punição.
- **Marco:** M2. **Recomendação: adotar suave** (1%/s), configurável. Não ir acima de 2%/s: 40 s sem comida zera 70%.

### 20.4 A Ração do inventário se perde se ele acordar
- **Conta** (perda de metade do estoque restante / perda total, com a taxa de falha dos casos médio e ruim): Triceratops C (estoque de 200 s de coleta, falha 20%): +20 s / +40 s esperados; Triceratops S+ (396 s, falha 6%): +12 s / +24 s; Paquicéfalo C (58 s, falha 10%): +3 s / +6 s por tentativa.
- **Benefício:** mais tensão; o fracasso pesa.
- **Custo:** dobra a punição de uma morte ou despertar já punido (Ração consumida, Eficiência, tempo); desestimula levar estoque; o impacto é pequeno nos casos bons (3 a 40 s) e frustrante nos ruins.
- **Marco:** M2. **Recomendação: não adotar como regra padrão**; oferecer `perde_estoque_ao_acordar` na configuração de servidor (padrão desligado) para quem quiser mais dureza.

### 20.5 Eficiência com perda decrescente
- **Curva nossa proposta:** o peso do ataque `n` é `max(0,4; 0,85^n)`.
- **Conta:** Paquicéfalo (14,5 E por mordida): E zera em 7 mordidas na regra linear e em 13 com a curva (a vida do Paquicéfalo acaba em 8: a curva deixa o bônus vivo enquanto o dino morre); Triceratops (8,9 E): 12 contra 24.
- **Benefício:** menos "bola de neve"; evita E zerado por 1 descuido.
- **Custo:** contradiz a regra decidida (cada ataque derruba E até 0% ou a morte do dino) e enfraquece a proteção do dino, que era o ponto da regra; um dino quase morto manteria bônus.
- **Marco:** M2. **Recomendação: não adotar para ataques.** Se o playtest mostrar que E zera cedo demais, aplicar a curva só aos golpes do jogador no dormindo e ao tempo, não às mordidas.

### 20.6 Domesticação sem nocaute (comida na mão)
- **Regra proposta** para espécies de Conduta Medroso, Curioso e Covarde: o jogador **fica parado** e oferece Ração; o dino cruza 3 estágios de distância (6, 4 e 2 tiles), com uma **confiança** de 0 a 100 que sobe 10 por segundo com o jogador imóvel e cai 25 se correr ou atacar; ao chegar a 2 tiles, come a cada intervalo da Ração. Sem torpor: sem janela de torpor e sem barra de torpor.
- **Eficiência:** começa em 100, perde `0,1/s` (sem sono, desgaste menor), a drenagem da Ração por refeição (igual à tabela de `racao.md`), e 10 por susto (movimento brusco); ataques de carnívoros contam como em `racao.md` 11. Para não premiar mais o caminho seguro: **teto de E em 70** (bônus máximo de +35%, não +50%). Nível 20 vira 27 no melhor caso, não 30.
- **Conta de tempo:** C em Paquicéfalo: 3 estágios x 10 s + 8 refeições x 5 s = 70 s parado (contra 40 s dormindo), sem nenhum golpe; fome do dino ignorada.
- **Benefício:** trilha alternativa para os tipos que correm; não exige corrida de 4 s de stamina nem perseguição, coerente com o tom acolhedor; o carnívoro ainda ameaça (o dino acordado foge).
- **Custo:** alto: modo de interação novo, UI de confiança, três estágios por espécie, estado novo no dino e testes de cena (3 a 4 vezes o custo do painel de domar [premissa; sem estimativa do plano]).
- **Marco:** M4, com Curioso e Medroso (que também entram no M4). **Recomendação: adotar no M4** apenas para Curioso e Medroso; o Covarde, que corre, continua com nocaute (a conta de 94 px/s mostra que dá para pegá-lo). Cortar da 0.2.

### 20.7 Ingredientes que só seus dinos produzem
- **Regra proposta:** o dino domado com Afeto 50 ou mais e ofício "Produzir" gera **1 Orvalho-de-casco a cada 10 min jogados**, com acúmulo de até 5 por dino (30 a 50 min de teto), sem produção offline. A Ração S+ passa a pedir **1 por receita** (rende 2) em vez da Seiva-de-brasa.
- **Conta:** Triceratops em S+ precisa de 8 rações = 4 receitas = 4 unidades. Com 1 produtor: 40 min; 2: 20 min; 4: 10 min. Antes, com a Seiva: 8 S+/h por respawn. Fica configurável: com 4 produtores, 24 unidades por hora.
- **Benefício:** progressão do próprio rebanho (liga ao D5 e ao Afeto) e **troca conteúdo de mundo (Clareira-brasa e carnívoro territorial) por um ofício**.
- **Custo:** um ofício novo (CRI-08 estendido), um item e um timer persistido no save; um dino específico passa a ser necessário, o que cria dependência circular saudável (o Paquicéfalo que você já tem ajuda a domar o Triceratops).
- **Marco:** M4 (S+ já é M4). **Recomendação: adotar, no lugar da Seiva-de-brasa**, e só para S+. Não aplicar a níveis menores: aumentaria a cadeia de produção, que o escopo da 0.2 não comporta.

### 20.8 Receitas achadas no mundo
- **Regra proposta:** as receitas das Rações S e S+ ficam em **pergaminhos** em 3 locais do mapa fixo (ruína na Pedreira, gruta na Mata-baixa, clareira); B e A seguem por uso.
- **Conta:** 3 locais x 3 a 5 min de ida e volta [premissa] = 9 a 15 min de exploração; mapa de 128x128 cabe.
- **Benefício:** motivo para explorar. Risco: bloqueia a progressão se o jogador não achar; em mapa fixo vira roteiro de wiki e perde o "achar"; mundo gerado (M4) resolve.
- **Custo:** item e save de receitas conhecidas; conteúdo de mundo (3 pontos).
- **Marco:** M4 (mundo por seed, MUN-11). **Recomendação: adiar para o M4 e fazer só para S e S+**; na 0.2 manter desbloqueio por ter feito (seção 9), que já está no GDD.

### 20.9 Filhote criado: sem bônus de domesticação, Eficiência cheia para o vínculo
- **Regra proposta:** o filhote não passa por nocaute; durante o crescimento (20 min jogados, 8 a 10 alimentadas), cada alimentada perdida tira 5 E; ao crescer: `nível adulto = round((nível do filhote + 8) x (1 + 0,5 x E/100))`, Afeto inicial `round(E/5)`.
- **Conta:** filhote nível 1 a 10; com E 100: 14 a 27; com E 80: 13 a 25; com E 60: 12 a 23. Compare com selvagem domado L28 em S+: 42. A criação rende nível médio, mas Afeto 20 e escolha de ofício: **não domina** a domesticação.
- **Benefício:** coerente com 6.5; identidade do jogo (vínculo por cuidado) sem competir em força.
- **Custo:** reutiliza a fórmula de E; falta só o ciclo de crescimento (M4).
- **Marco:** M4. **Recomendação: adotar como está.**

### 20.10 Prévia de domesticação
- **Regra proposta:** ação "Observar" (2 s, ao alcance de 6 tiles) abre um painel com: perfil de Ração aceito e mínimo, refeições necessárias por nível de Ração para aquele nível de dino, tempo e **porcentagem da janela de torpor** (nunca o torpor atual, que continua sem barra), E previsto sem ataques e nível final esperado. Mesmos números que o painel de domar já precisa.
- **Dados:** tabelas de espécies, Ração e coeficientes em **JSON** de leitura, versionado (alinha com ADR-003); calculadoras da comunidade usam o mesmo arquivo.
- **Conta:** o painel calcula `refeições = ceil(base x fator x max(0,5; 1 + 0,033(L-10)))` (5.14), `tempo = refeições x intervalo`, janela `= tempo x queda + refeições x agitação / torpor máximo`; já existem no `TamingComponent` e no `NivelDino`. Custo extra é só UI e exportação, estimado [premissa] em menos de 1 dia de trabalho do `SORA` depois que a base existir.
- **Benefício:** ensina o sistema sem tutorial de texto, reduz erro de preparo (Rações a menos) e atende a comunidade sem trabalho nosso.
- **Marco:** M2 (UI) e JSON já no M2. **Recomendação: adotar.** Cuidado: Observar custa 2 s de exposição; se o dino for agressivo, a prévia fica perigosa, o que é desejável.

### 20.11 Resumo das recomendações

| # | Proposta | Marco | Decisão |
|---|---|---|---|
| 1 | Exigência por espécie | M2 | **DECIDIDO: adotar** (piso suave 50%) |
| 2 | Fome como relógio | M4+ | **DECIDIDO: rejeitada** |
| 3 | Regressão sem comida | M2 | **DECIDIDO: adotar** (1%/s) |
| 4 | Perder estoque ao acordar | M2 | **DECIDIDO: opção de servidor, desligada por padrão** |
| 5 | Perda decrescente de E | M2 | **DECIDIDO: rejeitada** |
| 6 | Domesticar sem nocaute | M4 | **DECIDIDO: adotar** (Curioso e Medroso) |
| 7 | Ingrediente produzido por dino | M4 | **DECIDIDO: adotar** (no lugar da Seiva, só S+) |
| 8 | Receitas achadas no mundo | M4 | **DECIDIDO: adiada** |
| 9 | Filhote criado | M4 | **DECIDIDO: adotar** |
| 10 | Prévia e JSON | M2 | **DECIDIDO: adotar** |

Itens que entram na 0.2: 1, 3 e 10. Os demais ficam para o M4 ou são rejeitados. O que não está provado: valores de 1%/s, 50% e 70% de teto são [premissa]; a sensação de 70 s parado sem torpor e o valor do exploratório de pergaminhos só playtest responde.

