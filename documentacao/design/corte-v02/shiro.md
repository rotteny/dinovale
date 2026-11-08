# Corte da v0.2 "Primeiro Vale": proposta da SHIRO (revisão 2)

Proposta para o dono decidir. Nada no repositório foi alterado. Sem horas e sem estimativas de tempo de projeto (os segundos e minutos abaixo são tempo de jogo).
Marcas: **[calculado]** vem de número já no código, no GDD ou nos `*_sim.py`; **[premissa]** é número meu, a validar jogando.

Critério: o loop do dono (coletar, comer, fabricar, construir, sobreviver, explorar, domar numa ilha), com dia e noite, chuva, fome leve e o torpor como única ameaça ao personagem. Esta revisão incorpora os pedidos novos do dono como FICA: domado Neutro que ajuda no combate, montaria sem sela, slots que limitam de verdade (4 base, Cesto +4, Mochila +8, uma vaga só), alforje do dino de 4 slots e ficha de RPG na tela.

## 0. Contagem

O M2 do plano (4.3) tem **69 tarefas** (a contagem de 65 que circula está errada).

| Grupo | Antes | Agora | Mudou |
|---|---|---|---|
| FICA | 34 | **35** | CRI-08 sobe de SIMPLIFICA para FICA, reescrita como Neutro |
| SIMPLIFICA | 19 | **19** | CRI-08 sai do grupo; UIX-09 entra (ficha só de leitura) |
| SAI PARA DEPOIS | 16 | **15** | UIX-09 sai do grupo |
| NOVO | 3 | **7** | + CRI-45 (montaria, vem do M4b), CRI-42 (slots e bolsas, vem do M4), ART-18 e SOB-16 (provisórios) |

Fica na v0.2: 35 + 19 + 7 = **61** (de 69). Em número de tarefas o ganho caiu de 12 para 8; o peso real é pior que a contagem (seção 6).

Fatos da branch: `lunata.json` só semeia Paquicéfalo (108 de 360); `player_rules.tres` tem fome a 0,2/s; `HungerComponent` ainda tem dano de fome; o save já guarda nós esgotados; `RespawnPicker`/`RespawnRules` existem; PRO-22 (vagas, só Arma visível) já está entregue na branch.

## 1. FICA (35)

| Id | Por quê |
|---|---|
| MUN-03 | A ilha existe; falta semear Dodo, Utahraptor e Triceratops e fechar `respawn_regioes`. |
| MUN-04 | Sem navegação, parede e porta não protegem do Utahraptor; abrigo é a resposta à noite. |
| MUN-05 | Zona ativa, já pronta. |
| CRI-12 | Carnívoro ataca o dormindo: ameaça da doma e base do SOB-15. |
| QA-01a | Playtest curto de H1; ganha as perguntas de torpor, noite, montaria e slots. |
| CON-01, CON-03 | Construir é um dos seis verbos. |
| PRO-04 | Bancada e receitas por dados. |
| PRO-06 | Baú: com 4 slots vira peça essencial (seção 4.7). |
| PRO-07 | Ração é o produto da doma e a fabricação recorrente que sobra. |
| PRO-13 | Saber e tela de receitas (custo achatado, seção 5.2). |
| PRO-18 | Fogueira: assar e luz à noite. |
| SOB-02 | Corpo recuperável por 10 min: é a consequência de ser devorado. |
| SOB-12, SOB-13 | Morrer precisa ser barato e claro; Saco de dormir e Cama são decisão do dono (D28); o marcador do corpo fica (ilha de 256x256). |
| SAV-02, SAV-04b, ARQ-05, QA-03 | Save, gatilhos e regras em dados. |
| CRI-13 | Lança. |
| CRI-06c | Dodo, **com correção**: o plano diz "sem torpor e sem domar"; a decisão do dono é Dodo como primeira doma. |
| CRI-06 | Triceratops: doma grande e, agora, montaria grande. |
| CRI-08 | **Reescrita como Neutro** (seção 4.6). Substitui o ofício Defender; Carregar sai. |
| CRI-14 | Observar e nível previsto (critério 3 do playtest). |
| CRI-15 | Regressão sem comida: tensão da vigília por quase nada. |
| UIX-04, UIX-12 | HUD final e barra de nível. |
| UIX-15 | Alimentar o domado pela tecla: única forma, o Cocho sai. |
| SOB-05 | Domado ferido some 5 min e volta; com Neutro e montaria o domado vai se machucar mais. |
| ART-09 | Saco de dormir e Cama. |
| INF-08, COM-03, COM-04, COM-05, QA-01 | Release, README, landing, nomes, 2 rodadas de playtest. |

## 2. SIMPLIFICA (19)

| Id | Versão menor |
|---|---|
| CON-02 | Fundação, parede, porta e baú. Sem estaca. |
| PRO-05 | **17 receitas** (seção 5.2). |
| PRO-09 | **Peso mantido** (decisão do dono): 50 kg, impede pegar acima de 100%, sem lentidão, só do jogador; convive com os slots do CRI-42 (seção 4.7). A recusa diz qual limite bateu. |
| PRO-11 | XP, nível e Saber. Sem pontos de atributo. |
| SAV-03 | XP, nível, hora, clima, bolsa equipada e alforje do dino (save v5). |
| SOB-06 | Carcaça à mão e com Lança, carne e couro. Sem sacolinha: o que não cabe fica na carcaça (10 min). |
| SOB-07 | Fome leve e desmaio por torpor (seção 4.3). |
| PRO-16 | Barra de durabilidade e quebra (PRO-15 já entrega); quebrou, refaz. Sem reparo. |
| CRI-07 | Afeto com um limiar (obedece acima de 25 [premissa]); também libera montar. |
| CRI-43 | Menu do domado: Seguir/Ficar, **Montar/Desmontar**, **Alforje (4 slots)** e Alimentar. Sem permissão de co-op, sem "para todos". |
| CRI-27 | Nome de até 20 caracteres, sem filtro. |
| UIX-05 | Tutorial por evento: baga, Bastão, Observar, fome, desmaio, noite, slots. |
| UIX-09 | **Ficha só de leitura** (seção 4.8), aba da tela P. Sem botões de gastar pontos. |
| ART-02 | Ícones das 17 receitas, fome, torpor, Fogueira, Cesto e Mochila. |
| ART-06 | 4 espécies; arte final só depois do playtest (R42). |
| ART-03 | SFX sem aviso de quebra; entra loop de chuva. |
| ART-16 | Só as 6 formações rochosas (marcos de exploração). |
| ART-17 | Dodo 16x16 e Triceratops 48x48. |
| INF-09 | Orçamento de CPU mantido; o teste de perseguição de Medroso sai. |

## 3. SAI PARA DEPOIS (15)

| Id | O jogo perde |
|---|---|
| MUN-07 | Portão duplo e caminho por porte (o montado usa a colisão física, que já é por porte). |
| CRI-26 | Parassaurolofo, 94 dinos. |
| PRO-12, QA-02 | Gastar pontos no jogador e no dino. Ver a ficha na 4.8. |
| PRO-20 | Tetos de nível. |
| CRI-28, CRI-29, PRO-21 | Cochilo, forçar sono, Pilão e Preparado. Não semear o arbusto-do-sono. |
| PRO-14b | Cocho. |
| PRO-17 | Validade e carne podre. |
| SOB-08 | Stamina em golpe e coleta. |
| CON-05 | Dano em parede. |
| CRI-18 | Grupo chama grupo. |
| CRI-19 | Atacar o alvo e Guardar a base (modos). |
| UIX-08 | Lista de grupo; a placa cobre. |

## 4. NOVO

### 4.1 O que o GDD já tem e o que falta

| Item | Já existe | Falta |
|---|---|---|
| Dia e noite | GDD 3: Should, cortável; SOB-03 no M4 (D16) | Voltar ao M2 |
| Chuva | Nada; SOB-11 no M4 sem desenho | Desenho (4.2) |
| Neve | Nada | Fora (4.4) |
| Torpor como ameaça | Inconsciente por fome (5.10), CRI-12, corpo, tela de morte | Dino atacar o jogador caído (4.3) |
| Neutro | 6.11 e 6.11b (Postura, `guarda`) | Só o Neutro fixo (4.6) |
| Montaria | 6.12, M4, com sela e rede | Versão mínima sem sela (4.5) |
| Slots que limitam | 5.21: 24+16, M4 | 4, 8 e 12, já na v0.2 (4.7) |
| Ficha | Tela de atributos (UIX-09) e PRO-22 | Ficha de leitura (4.8) |

### 4.2 Dia e noite e chuva: versão mínima (SOB-03, SOB-11)

- **Ciclo [premissa]:** 12 min, 7 de dia, 1 entardecer, 3 de noite, 1 amanhecer. Em 30 min são 2,5 ciclos [calculado].
- **Visual:** tinta por faixa; à noite, luz de 5 tiles ao redor do jogador e de 4 na Fogueira acesa [premissa].
- **Efeito de jogo (um só):** percepção do Agressivo x1,5 à noite [premissa].
- **Chuva [premissa]:** 2 min, em média a cada 8 min, só visual e sonora. Sem efeito mecânico (um efeito exigiria "coberto", que não existe).
- **Save v5:** hora e clima. `ServerRules`: duração do ciclo e frequência da chuva.

### 4.3 Fome leve e torpor como ameaça (SOB-07 e SOB-15)

1. **Fome a 0,1/s [premissa]** (hoje 0,2/s em `player_rules.tres`): cheio dura 1.000 s; cozida (+35) rende 350 s; baga (+10) rende 100 s [calculado]. 360 pontos de fome por hora = ~10 cozidas ou 36 bagas.
2. **Fome zero não causa dano e não mata.** Sobe o torpor (+2/s líquido): 50 s até o desmaio [GDD 5.10]. Do cheio ao primeiro desmaio: 1.050 s.
3. **SOB-15 (provisório):** o jogador inconsciente entra na lista de alvos do "dormindo" do CRI-12. O domado em Neutro revida a agressão ao dono caído (4.6).
4. **Morte vem do dino**, nunca da fome. Corpo de 10 min, tela de morte, Cama ou Saco.

Conta [calculado a partir do GDD 6.1b]: Utahraptor L20 morde 8 a cada 1,5 s. Desmaio de 8 s = 5 a 6 mordidas = 40 a 48 de 100 (não mata). Desmaio de 20 s [premissa] = 13 mordidas = 104 (mata, mas é espera parada). Duração em dado; o QA-01a decide.

### 4.4 Neve

**Fora da v0.2.** `lunata.json` tem 7 terrenos (agua_funda, agua_rasa, praia, campina, mata_baixa, pedreira, agua_funda_anel); o GDD 4 lista três biomas na 0.2 e o quarto (Clareira-brasa, M4) é de brasa. Não há bioma de gelo no plano. Temperatura está fora (GDD 3). Sem estações.

### 4.5 Montaria sem sela (CRI-45, trazida do M4b): versão mínima da 6.12

**Quem monta:** porte Médio ou maior = **Utahraptor (Médio, 32 px) e Triceratops (Grande, 48 px)**. Dodo e Paquicéfalo não. Dado `montaria: livre` na espécie. A 6.12 tinha só o Utahraptor sem sela; o Triceratops (sela obrigatória) passa a livre.

**Regras da versão mínima:**
- Requisitos: dono, Afeto >= 25 (o limiar único do CRI-07), dino acordado e não ferido. Sem exigência de nível. Sem requisito de fome do dino (o domado não tem fome nesta proposta).
- Controle: WASD move o dino, a câmera o segue, o jogador sai do mundo. Velocidade = espécie x 1,3 [premissa do GDD], sem sprint e **sem custo de Stamina**. Conta [calculado, 6.12]: 117 px/s montado contra ~86 correndo sustentado, **+36%**; sem o x1,3 a montaria seria mais lenta que correr.
- **Sem ataque montado** (o recorte previsto no GDD): montado o dino não luta nem revida; o jogador não usa arma. Dano ao montado vai todo ao dino; o jogador é imune. Vira ferramenta de fuga e de exploração.
- Desmontar: menu, 0,3 s, tile livre. À força: dino ferido (vida 0) derruba o jogador, atordoado 1 s [premissa], dino some 5 min (SOB-05). **Desmaio por torpor também derruba**: a ameaça do 4.3 não pode ser anulada por quem desmaia a cavalo.
- Colisão física do dino; não entra no abrigo (porta de jogador). Não é salva montada: ao salvar e carregar desmonta [premissa].
- Sem rede: single-player, host local. A dependência do NET-10 (M3) cai; `request_mount`/`request_dismount` seguem como intenções validadas, para não refazer no co-op.
- Stamina do dino: não existe.

**Arte (o ponto que o dono perguntou):**
- O GDD 6.12 diz "sprites nenhum": o jogador aparece pequeno sobre o frame do dino, com deslocamento por espécie e direção. **2 espécies x 4 direções = 8 deslocamentos em dados** (eram 12 com 3 espécies) [calculado].
- Mas o jogador de pé (16x32) não serve de cavaleiro: cobriria o Utahraptor de 32 px. Preciso de **uma pose de torso sentado, 4 direções = 4 sprites** [premissa de 16x16] (ART-18, provisório), a mesma pose para as duas espécies; só o deslocamento muda.
- Dois riscos: (1) o dino anda com balanço de quadro, o cavaleiro não acompanha; aceitável com 1 px, senão deslocamento por quadro de andar (2 x 4 x 4 = 32 valores em dados, não arte) [premissa de 4 quadros do ESTILO]; (2) se o sprite final do artista (D25) tiver cabeça ou cauda sobre o dorso, a pose passa a ser **por espécie: 2 x 4 = 8 sprites**. Trabalhar com placeholder até o playtest (R42) e decidir depois.
- Cavaleiro por espécie e direção "de verdade" (sprite composto por quadro de andar): 2 x 4 x 5 quadros = 40 composições [calculado]. Não recomendo para a v0.2.

**Sela:** CRI-46 e as 3 selas ficam no M4b. Direção futura (dono): o dino fica em 4 slots até ter sela; depois haverá **selas de carga e selas de trabalho**, ambas pós-MVP, sem números aqui. **Conflita com a 6.13**: (a) a 6.13 faz a sela obrigatória para montar e essa regra cai; (b) o bônus da sela é "Peso extra do alforje" em kg, e o alforje agora é em slots; (c) a sela é de defesa por material (fibra, couro, metal), e a direção nova é por função; (d) a 6.13 só dá vaga de sela a Parassaurolofo e Triceratops, e agora todo domado tem alforje de 4. A 6.13 e a CRI-46 precisam ser reescritas quando as selas entrarem; nada disso bloqueia a v0.2.

### 4.6 Domado em Neutro (CRI-08 reescrita)

**Regra (6.11b, só o modo Neutro, fixo):** revida agressão feita por selvagem a ele, ao dono (inclusive caído) ou a dino aliado; persegue até 8 tiles e volta [GDD]. Sem fogo amigo (dano entre domados e contra o jogador é 0). **Nunca ataca selvagem inconsciente** (preserva a Eficiência da doma). Dodo e Paquicéfalo...: o traço Fugitivo vale para o Dodo (Covarde, foge em vez de revidar).

**Custo real:** é menor do que parece, porque o Neutro **ocupa o lugar do ofício Defender** que eu já mantinha. Entra: evento de agressão (quem feriu quem), estado "Revidando" do domado com navegação (MUN-04 existe), dano da espécie, volta ao dono. **Continuam fora:** seletor de modo, Passivo e Agressivo, Q do rebanho, Ir até aqui, placa completa com símbolos, limites do V79. Sem seletor, não há símbolo a desenhar.

**Efeito em cadeia:** o Utahraptor domado revida o Utahraptor selvagem e protege o dono desmaiado; é o prêmio da doma e fecha a ameaça do 4.3. Dano maior ao domado: SOB-05 (some 5 min) sustenta, ninguém morre para sempre.

### 4.7 Slots que limitam: 4 base, Cesto 8, Mochila 12, uma vaga só (CRI-42, trazido do M4)

**Decisão do dono:** 4 slots; uma vaga de bolsa; vale a equipada (4, 8 ou 12; não somam). O dino fica em 4 slots (alforje) até ter sela.

**Conflitos com o GDD:**
- **5.1** diz que os 40 slots são só exibição e o Peso limita. Inverte: o slot é o limite.
- **5.21** (base 24, Mochila +16 = 40, M4) fica com base 4 e Mochila 12 no total; o conflito que a 5.21 apontava ("sem limitar, a Mochila é enfeite") some. A recusa de "tirar a Mochila cheia, sem perda" da 5.21 serve de base para a regra de troca abaixo.
- **Barra de 9 atalhos:** é referência, não armazenamento. Recomendo mostrar **só as entradas existentes** (sem molduras vazias), mantendo as teclas 1 a 9. Com 4 slots, haverá poucas entradas; é o esperado.

**A conta com as pilhas atuais** (`slots.py`, pilhas do `catalogo.md`: madeira 20, pedra 20, fibra 40, graveto 40, baga 20, carne 10, Ração 20):

| Momento | Slots | kg |
|---|---|---|
| Minuto 0 a 5, coleta em lote para as ferramentas | 5 | 36,2 |
| Cesto (12 fibra [premissa]) | 1 | 0,6 |
| Bancada (8 madeira, 2 pedra) | 2 | 11,0 |
| Abrigo mínimo (32 madeira, 4 pedra, 1 fibra) | **4** | 38,0 |
| Cama (12 fibra, 8 madeira) | 2 | 8,6 |
| Domar Utahraptor L15: 25 carne para a Ração Rubra C | **3** | 12,5 |
| Domar: 14 rações + 10 carne + 10 bagas | 3 | 6,0 |

**Leitura.** Com 4 slots, a primeira hora **funciona se as ferramentas ficarem fora dos slots**; o abrigo mínimo consome os 4 de uma vez (cabe, sem sobra); a coleta em lote do início (5) passa de 4 e obriga a fabricar no meio da coleta (tensão intencional). Domar o Utahraptor pede 3 slots só de carne mais a Ração: **na prática exige o Cesto**. A demanda do GDD era 10 (M1), 21 (meio) e 26 (pico) [5.21, `slots_sim.py`]; com o corte (sem Cochilo, Preparado, curral, sacolinha) o pico cai para ~17 [calculado: 10 materiais + 3 Rações + Saco de dormir + 3 ferramentas], acima dos 12 da Mochila. O jogo vai viver com a bolsa cheia; o Baú e o ato de voltar à base são o ciclo.

**Ferramentas e armas (individuais) contam como slot?** Se contam, exceto a da vaga Arma, Lança, Machado e Picareta tomam **3 dos 4 slots** e sobra 1 para tudo o resto [calculado]: inviável. **Recomendo que fiquem fora dos slots**, numa área própria (a vaga Arma mais um cinto de 4 posições [premissa], a barra de atalhos os mostra). Comida, material e Ração contam.

**Peso continua como limite? Sim (decisão do dono): 50 kg, impede pegar acima de 100%, sem lentidão.** Conferi na conta da primeira hora qual limite bate primeiro (`slots.py`; pilha x kg: madeira 20 x 1,0 = 20 kg por slot cheio, pedra 20 x 1,5 = 30, carne 10 x 0,5 = 5, couro 20 x 0,4 = 8, graveto 40 x 0,1 = 4, baga 20 x 0,1 = 2, fibra 40 x 0,05 = 2; o peso da Ração não achei, usei 0 [premissa]):

| Momento | Slots | kg (de 50) | Bate primeiro, com 4 / 8 / 12 slots |
|---|---|---|---|
| Minuto 0 a 5, coleta em lote | 5 | 36,2 (72%) | **slot** / nenhum / nenhum |
| Cesto, Bancada, Cama, doma (carne e Ração) | 1 a 3 | 0,6 a 12,5 | nenhum |
| Abrigo mínimo | 4 | 38,0 (76%) | nenhum (encosta nos dois) |
| Abrigo + Cama numa viagem | 4 | 46,6 (93%) | nenhum, perto dos dois |
| 2 abrigos | 6 | 76,1 (152%) | **Peso** (e slot com 4) |
| 12 slots de madeira | 12 | 240 (480%) | **Peso**, com folga enorme |

Leitura:
- **Material pesado bate no Peso, não no slot:** 50 kg são 2,5 slots de madeira ou 1,7 de pedra. Sem o Peso, 4 slots levariam 80 kg de madeira; o Peso corta antes do 3º slot.
- **Material leve e variado bate no slot:** carne, fibra, baga, graveto e Ração ocupam 2 a 8 kg por slot; 12 slots de coisas leves não chegam a 50 kg. Aí só o slot limita.
- **Os dois fazem trabalhos diferentes** (slot = variedade, Peso = massa), a lógica que a própria 5.21 já queria. Faz sentido, com um efeito a aceitar: **Cesto e Mochila não carregam mais obra**, só mais variedade, porque a Mochila não aumenta o Peso (5.21). O abrigo mínimo (76%) cabe numa viagem com os 4 slots exatos; dois abrigos exigem duas viagens ou um dino, com qualquer bolsa.
- **Mensagem de recusa:** "Peso máximo" ou "Inventário cheio", a que bateu; sem gastar o nó. Se os dois baterem, o Peso.
- **Primeira hora:** só o minuto 0 a 5 passa do limite (5 slots, mas 72% do Peso): resolve-se fabricando no meio da coleta. O Peso só aparece na obra grande e no 2º abrigo.
- **Peso fixo:** o "+3 kg por ponto" da 5.1 só existe se os pontos ficarem; sem pontos, a capacidade é 50 kg. Ferramentas e armas fora dos slots continuam contando no Peso (5.20).
- **Alforje do dino (4 slots):** os dois limites valem: Paquicéfalo 40 kg (5.1) contra 4 slots de madeira (80 kg), o Peso morde antes.

**Regra de troca e retirada com inventário cheio (decisão pedida): recusar, nunca perder.**
- **Subir** (nada ou Cesto para Mochila, nada para Cesto): sempre permitido.
- **Descer ou tirar** (Mochila para Cesto, qualquer um para nada): só se, depois do ato, o conteúdo cabe no novo limite. O jogo compacta pilhas sozinho; a conta é o número de pilhas distintas contra o novo limite. Se não couber, **recusa com "Esvazie N pilhas"** e nada muda de lugar.
- A bolsa nova é consumida só depois de entrar na vaga; fabricar a bolsa com a mochila cheia primeiro consome o material (libera slots), depois coloca.
- Morte: o corpo leva tudo, bolsa incluída, pela mesma regra do inventário. Save acima do limite só trava (5.21).
- Para o jogador conseguir esvaziar sem baú por perto: **SOB-16 (provisório), "Descartar" a pilha com confirmação**. Sem ele, o jogador cheio e longe do baú fica preso. O "Largar" completo (SOB-14, M4b) continua fora.
- Coletar com a bolsa cheia: recusa, sem gastar o nó (a mensagem "peso máximo" vira "inventário cheio").

**Nome.** "Saco de fibra" convive com "Saco de dormir" (decisão do dono: GDD 12.3) e com "sacolinha" e a futura "bolsinha". Três "sacos". Recomendo **"Cesto de fibra"** (+4) e **"Mochila de couro"** (+8) e manter "Saco de dormir".

**A Mochila exige couro: resolve a pergunta do couro.** Receita [premissa]: 6 couro + 4 fibra, à mão. Cada Dodo dá 1 couro e o ciclo de caça é de ~30 s [GDD 6.1b], logo 6 couro = 6 Dodos, ~3 min de caça de jogo [calculado]. O couro deixa de ser item morto; o Saco de dormir volta a 8 fibra.

**Alforje do dino (até 4 slots):** reutiliza o `InventoryComponent` do baú; `accepts_individual = false` (GDD 6.13). Entra pelo menu do domado (CRI-43) e no save v5. O "até" pede uma tabela por porte [premissa]: 1 diminuto, 2 pequeno, 4 médio e grande (dado). Sem Carregar (a carga em faixas é M4b).

**Ordem das receitas muda: sim.** O Baú passa a ser a solução de overflow, então vira **conhecido (Saber 0 [premissa])**, junto do Cesto e da Mochila (conhecidos, travados só pelo material). Ordem sugerida: Cesto, Baú, Bancada, Abrigo, Saco de dormir, Ração C, Cama, B, A.

### 4.8 Tela de inventário e ficha de RPG (UIX-09 reduzido, PRO-22)

PRO-22 já entregou 6 vagas (só Arma visível). Na v0.2 não há roupa (M4), então "equipar" vira duas vagas visíveis: **Arma** e **Bolsa** (a 7ª vaga da 5.21). A tela: coluna de vagas à esquerda, grade de 4, 8 ou 12 slots (escurece o que passa do limite) e a ficha. A tela de 5.20 é menor que a de 40 slots, não maior.

**Ficha (aba da tela P, que o PRO-13 já cria; só leitura):**
- *Jogador:* nome, Nv e XP, Saber (saldo), Vida, Fome, torpor (faixa), Dano do golpe (Soco, arma equipada), velocidade andar e correr, slots usados/limite e a bolsa. Não entram Redução (sem roupa), Peso (não limita) e Stamina (sem barra).
- *Dino:* nome, espécie, Nv, Eficiência, Vida, Dano, Afeto, alforje n/4, "Neutro", "montável".
- *Pontos:* se o dono manter D15 (PRO-12/UIX-09/QA-02), a mesma ficha ganha "+" por atributo, sem trocar de tela. Fora disso, o dino cresce por nível e Eficiência.

## 5. Espécies e receitas

### 5.1 Elenco: 4 espécies (Dodo, Paquicéfalo, Utahraptor, Triceratops)

| Papel | Espécie | Onde |
|---|---|---|
| Ameaça | Utahraptor (Agressivo, 6 a 11) | 6 tocas, Mata-baixa |
| Primeira doma e carne | Dodo (Covarde, 140) | Mata-baixa |
| Doma grande | Triceratops (Semi, 8, L18 a 24) | Pedreira |

- **3 espécies** fecham os papéis mas jogam fora o Paquicéfalo pronto (doma, arte 24x24, 108 spawns).
- **5 espécies** soma o Parassaurolofo: arte 32x32, 94 dinos, curral; papel já coberto. Com a montaria, o Parassaurolofo seria o 3º montável, mas o Utahraptor e o Triceratops bastam.
- **Recomendo 4.** População 266 [calculado: 360 menos 94], ~2,8 por tela contra 3,8 [calculado].
- Os dois montáveis são exatamente a ameaça e a doma grande: a montaria é o prêmio de domar os dois mais difíceis.

### 5.2 Receitas: 17

- **Conhecidas (8):** Lança, Machado, Picareta, Fogueira, Bastão, **Cesto de fibra, Baú, Mochila de couro** [premissa].
- **Aprendidas (9 receitas, 7 Saber):** Bancada, Abrigo (3 receitas, 1 Saber), Saco de dormir, Cama, Ração C, B e A.
- **Saem (6):** Pilão, Preparado, Bandagem, Cocho, curral, Portão.

Saber [calculado, `receitas_sim.py ordem`, 13 XP/min do plano]:

| Cenário | Saber | Chega em |
|---|---|---|
| Plano (21 receitas) | 22 | L19, 218 min |
| Só tirar as 6, custos do plano | 11 | L10, 62 min |
| Custo 1, Baú/Cesto/Mochila conhecidos [premissa] | **7** | **L6, 23 min** |

Com o custo do plano a Ração A (doma grande) chega a 62 min, fora de um playtest de 30. Com 7 Saber chega a 23 min.

## 6. Riscos, o que os acréscimos custam e o que precisa de playtest

**Os acréscimos anulam o ganho do corte? Não, mas comem metade.** Em número de tarefas o M2 cai de 69 para 61. O que sai (pontos, validade, Cocho, Stamina, dano de parede, Preparado, Parassaurolofo, rede) é sistema de números e arte. O que entra é **montaria, slots e dia/noite/chuva**, três coisas que tocam entrada de jogador, câmera, inventário, UI, save e arte ao mesmo tempo. Cada acréscimo e o que o paga:

| Acréscimo | Custo real | O que o compensa |
|---|---|---|
| 1. Neutro | Pequeno: substitui o ofício Defender | Já compensado (CRI-08 reaproveitada; CRI-18, CRI-19 fora). Nada a cortar. |
| 2. Montaria | Médio: controle, câmera, desmonte à força, 4 a 8 sprites, 8 deslocamentos, menu | Parassaurolofo, MUN-07 e rede já fora. Se ainda pesar: **só o Utahraptor monta** (menos 1 espécie de offsets e de colisão grande) ou **cortar a chuva** (SOB-11, sem efeito de jogo). |
| 3. Slots | Médio-alto: troca de limite, regra de troca, Descartar, alforje de dino, barra de atalhos, save, UI | Sacolinha sai; o Peso fica (não há troca por troca). Compensa mais o corte da sacolinha. Se pesar: sem Descartar (o Baú basta) e sem alforje do dino (sai do CRI-43). |
| 4. Ficha | Pequeno, só leitura | PRO-12, QA-02 e tela de gastar ponto já fora. |

**Há motivo para voltar a jogar?** Pouco, e mais que na revisão anterior: quatro dominadas encerram o conteúdo, mas agora há montaria (explorar rápido), o domado que luta, a bolsa que cresce com couro (caça tem objetivo) e noite/chuva. Critério 5 do plano ("jogaria de novo amanhã?") segue o mais em risco.

| Risco | Leitura |
|---|---|
| 4 slots podem frustrar mais que desafiar | Pior caso do jogo novo: a primeira hora é gerenciar mochila, não explorar. Só playtest responde. |
| Abrigo = 4 slots exatos | Sem folga; qualquer item extra e o jogador precisa de duas viagens ou do Cesto. |
| Montaria dá +36% sobre correr [calculado] | Pode não valer a pena; sem Stamina, a vantagem é andar sem gastar fôlego. |
| Triceratops montado (48 px) nas árvores | Colisão grande; travadas em canto. |
| Neutro faz o domado ganhar luta demais | O jogador deixa de lutar. Observar. |
| Desmaio de 8 s é fraco, de 20 s é espera | Testar os dois. |
| Mundo com 266 dinos | 2,8 por tela. |
| Arte final depois do playtest (R42) | O playtest vê placeholder, e o cavaleiro depende do sprite final. |

**Precisa jogar para saber:** slots (4, 8, 12) ajudam ou irritam; se a primeira hora cabe; se o Descartar basta; se a montaria vale; ciclo e duração de noite/chuva; desmaio; fome a 0,1/s; Dodo como primeira doma; legibilidade do cavaleiro; Neutro.

## 7. Decisões do dono (6)

1. **Elenco: 4 espécies, sem Parassaurolofo.** Recomendo cortar. 3 espécies jogariam fora o Paquicéfalo pronto; a 5ª custa arte e 94 dinos para um papel coberto; os dois montáveis (Utahraptor e Triceratops) são a ameaça e a doma grande.
2. **Torpor e fome: fome a 0,1/s, sem morte por fome, morte só por dino.** Recomendo. Duração do desmaio (8 s ou 20 s) sai do QA-01a.
3. **Carniça, validade e carne podre: tudo fora.** Recomendo. A margem de validade para a Ração já era de 4,6x a 12x [GDD 6.1b]. Com a validade fora, a pilha de carne pode ir de 10 para 20 [premissa] (hoje 10 por causa do "5 kg do que vence"), o que dá 25 carne em 2 slots em vez de 3.
4. **Pacote de slots.** Recomendo, em bloco: (a) 4 base, Cesto de fibra 8, Mochila de couro 12, uma vaga; (b) ferramentas e armas fora dos slots; (c) Peso fica como limite junto dos slots, 50 kg, sem lentidão (decisão do dono, conferida na seção 4.7); (d) subir sempre vale, descer ou tirar só se couber, senão recusa; (e) Descartar com confirmação; (f) nomes "Cesto de fibra" e "Mochila de couro"; (g) Mochila pede 6 couro + 4 fibra [premissa], o que resolve o couro; (h) Baú, Cesto e Mochila conhecidos. A leitura (a) literal do pedido anterior (4 slots e mais nada) é a que quebra o jogo; a deste pacote é a que o dono confirmou.
5. **Economia: V80, V81 e Saber.** *V80:* os limites são slots (variedade) e Peso (massa); 1.029 árvores x 3 madeira = 3.087 madeira, e o abrigo mínimo pede 32 madeira + 4 pedra + 1 fibra (4 slots); não há escassez de nó, há escassez de espaço e de massa por viagem. Manter respawn de 480 s e 600 s; recontar no `mapa_sim.py`. *V81:* **esperar** (o nó volta se o jogador demolir); o save já guarda nós esgotados. *Saber:* custo 1 por receita com Baú, Cesto e Mochila conhecidos: 7 Saber, L6, 23 min [calculado].
6. **Escopo dos acréscimos do dono: aceitar Neutro fixo, montaria mínima (Utahraptor e Triceratops, sem ataque montado, sem Stamina, sem sela) e ficha só de leitura.** Recomendo, com o gatilho de corte da tabela da seção 6 se o playtest 1 sentir peso: primeiro a chuva, depois o Triceratops montável. Pontos de atributo (PRO-12) ficam fora; se o dono quiser mantê-los, a ficha já tem lugar para o "+".

Sem decisão, só aviso: o CRI-06c precisa ser reescrito (Dodo domável); a 6.13 e a CRI-46 conflitam com a direção das selas de carga e de trabalho e serão reescritas no M4b; neve só com bioma de gelo; chuva sem efeito mecânico.
