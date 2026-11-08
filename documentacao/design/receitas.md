# Dino Vale: receitas e Saber (árvore do personagem)

> Enxugada em 06/11 (decisão do dono) e **fechada com as decisões finais do dono (06/11)**: fica só o que tem função em um sistema definido. **Rodada seguinte (decisão do dono): Cama e Saco de dormir entram na v0.2 (M2), Saber 1 cada; contagem atual abaixo e em `GDD.md` 12.3.** **55 receitas na 1.0** (antes 53 sem Saco e Cama; 44 na primeira enxuta; as 15 peças de roupa por vagas de equipamento, ver abaixo; **59 com Mochila e selas, itens futuros provisórios: 84 Saber, L70, notas 17 a 19**), **21 na v0.2** (19 sem Saco e Cama; 21 antes dos cortes, outra composição); **Saber 75 na 1.0** (completa no L63; 73 e L61 sem Saco e Cama), **22 na v0.2** (24 disponíveis no L20: **sobra 2**). **Vagas de equipamento (decisão do dono, 06/11): arma, camisa, calça, bota, luva e capacete; substitui "1 vaga".** Roupa por peça: 3 materiais x 5 peças = **15 receitas, mas só 3 nós de Saber** (um por material libera as 5 peças). Saíram: **Rifle, Dardo, Bastão reforçado** e a **Barra de ferro** (processo da Forja, sem receita no menu; estava contada por engano). Entraram: **Besta** (M5) e **Boleadeira** (M4). **Saber em lista plana: sem pré-requisito entre receitas.** **Regra de produção:** fibra, madeira e pedra à mão; metal e engenharia na Bancada (a Forja é feita na Bancada). Números: `receitas_sim.py arvore|estacoes`. Durabilidade e validade: `GDD.md` 5.9; armadura: 5.11; armas à distância: 5.4; regra e aceitas: 5.19.

## 1. Moeda: Saber (pontos de receita)

- **Separado dos pontos de atributo.** **1 Saber por nível (L2 em diante), +1 no nível 3 e +1 nos níveis 5, 10, 15 e 20**: 24 no L20, 60 no L50, 90 no L75 [premissa; o +1 do L3 é novo: garante 3 Saber aos 6 min, ver `GDD.md` 15].
- **Custo por tier:** conhecida 0; T1 1 (curral 2); T2 2 a 3; T3 4; T4 6. **Sem pré-requisito entre receitas (lista plana, decisão do dono, 06/11):** a UI é uma lista, ordenada por custo. Pedido validado no servidor, sem devolução.
- **Começam conhecidas (4), decisão do dono:** **Fogueira, Lança de madeira, Machado de pedra, Picareta de pedra.** Todo o resto custa Saber (ou fóssil, M4). **O Bastão-de-sono nasce no inventário no M1, sem receita** (o tutorial do Paquicéfalo não gasta Saber); a receita de reposição custa Saber 1 no M2.
- **v0.2: 21 receitas custam 22 Saber; o teto do L20 dá 24 (sobra 2).** Aprende-se tudo no L19 (22 Saber: 218 min a 13 XP/min, `receitas_sim.py ordem`; era L17 e 175 min com 19 receitas); no L20 sobram 2 (a escolha é de **ordem**). **1.0: 55 receitas, custo 75; completa só no L63** (60 no L50; `saber_ate(61) = 60 + 1 + 12`). Se o Preparado de sono for cortado, saem o Pilão e ele: **19 receitas e 18 Saber**.

## 2. Árvore ativa (negrito = v0.2; entre parênteses, o Saber)

| Categoria | Receitas |
|---|---|
| **Armas e ferramentas** (13 na 1.0) | **Lança de madeira (0)**, **Machado de pedra (0)**, **Picareta de pedra (0)**, **Bastão-de-sono (1, Mãos; o 1o nasce no inventário)**, **Pilão (1, cortável com o Preparado)**; M4: Arco (2), Flecha comum (2), **Flecha de sono (2)**, Boleadeira (2); **M4 a M5 (metal, Bancada/Forja):** Espada de ferro (6), Machado de ferro (6), Picareta de ferro (6), **Besta (4, M5)** |
| **Armaduras** (3 conjuntos de **5 peças**, 15 receitas, 3 nós) | **Conjunto de fibra (1, depois do playtest)**, **de couro (2, M4)**, **de metal (6, M5, Bancada)**: camisa, calça, capacete, bota, luva |
| **Mobílias** (8) | **Fogueira (0)**, **Bancada comum (1)**, **Baú (1)**, **Cocho (2, cortável)**, **Saco de dormir (1)**, **Cama (1, na Bancada)**; M4: Canteiro (2); depois: Forja (4, **feita na Bancada**) |
| **Mochila (item futuro, M4)** | Mochila (Saber 2, provisório; couro + fibra, Mãos): equipável, 7ª vaga de equipamento, expande os slots (`GDD.md` 5.21) |
| **Construções** (10) | **Abrigo de madeira (1: fundação, parede e porta, 3 receitas)**, **Cerca e curral (2)**, **Portão de dino (1)**; M4: Palha (1, 3 receitas); depois: Pedra (4, 2 receitas) |
| **Recursos diversos** (9) | **Ração C (1)**, **Ração B (2)**, **Ração A (3)**, **Bandagem (1)**, **Preparado de sono (3, cortável, feito no Pilão)**; M4: Corda (1), Tijolo (2), Ração S e S+ (só fóssil) |

**Sem cadeia (lista plana):** nenhuma receita pede outra. A cadeia mais longa de estações é Bancada, Forja, Barra (processo), item de metal.

## 3. v0.2: o que cada uma pede (custo em material [premissa])

| Receita | Estação | Material |
|---|---|---|
| Lança de madeira | Mãos | 2 graveto + 3 madeira |
| Machado de pedra | Mãos | 3 madeira + 2 pedra + 1 fibra |
| Picareta de pedra | Mãos | 3 madeira + 3 pedra + 1 fibra |
| Fogueira | Mãos | 4 madeira + 3 pedra |
| Bancada comum | Mãos | 8 madeira + 2 pedra |
| Bastão-de-sono (reposição; o 1o nasce no inventário) | **Mãos** | 3 madeira + 2 fibra |
| Ração C, B, A | **Bancada** (preparo de comida) | `racao.md` |
| Pilão | Mãos | 2 pedra + 1 madeira (3,5 kg) |
| Preparado de sono | **Pilão** | 3 Cochilo (nome provisório, `mapa-ilha.md` 8) + 1 carne podre rendem 3, 4 s de moagem (`GDD.md` 5.5 e 5.18) |
| Baú, Cocho | **Mãos** | 6 madeira / 8 madeira |
| Abrigo, Cerca e curral, Portão | **Mãos** (peça à mão no mundo) | `GDD.md` 8 |
| Bandagem | Mãos | 3 fibra |
| **Saco de dormir** (1 respawn e some; `GDD.md` 12.3) | Mãos | **8 fibra** [proposta SHIRO] |
| **Cama** (respawn infinito, espera de 60 s, único save manual; `GDD.md` 12.3) | **Bancada** (decisão do dono) | **12 fibra + 8 madeira** [proposta SHIRO] |

**Pedra das primeiras ferramentas (decisão do dono, GDD 5.9b):** o Machado (2 pedra) e a Picareta (3 pedra) saem de **pedras avulsas** apanhadas à mão (24 na ilha, 10 no núcleo); o Soco não quebra nó de pedra. A cadeia Soco na árvore, pedra avulsa, 1 arbusto, craft fecha em ~1 min sem softlock (`mapa-ilha.md` 8).

**Fibra (mapa da ilha, decisão do dono):** vem do **arbusto**, que rende 2 Fibra junto da fruta (Baga ou Cochilo); não há mais planta de fibra separada (`mapa-ilha.md` 8). As receitas não mudam.

**Regra de produção (decisão do dono, 06/11): fibra, madeira e pedra se fazem à mão (menu P, estação Mãos); metal e engenharia, na Bancada; a Forja é feita na Bancada.** Mãos: 16 receitas da v0.2 (com o Saco); Bancada: 4 (a linha da Ração e a Cama) mais o reparo; Pilão: 1 (`receitas_sim.py estacoes`; 1.0 com tudo: Mãos 41, Bancada 17, Pilão 1). **Consequência:** a Bancada deixa de ser pré-requisito de armas e abrigos; fica como a estação da Ração, do reparo, da Forja e da Besta. **A Fogueira** assa carne (`GDD.md` 5.9: validade 30 para 90 min e +10 de fome). Ver conflito 1.

## 4. Armaduras, mobílias e recursos (resumo; decisões V37 a V41 aceitas)


- **Armadura (decisão do dono, 06/11): três materiais, só fibra, couro e metal, em cinco peças (camisa, calça, capacete, bota, luva); pele, osso, quitina e Escudo saem.** Reduz dano e **só isso (sem temperatura)**. **Um nó de Saber por material libera as 5 peças** (o Saber por peça somaria +26 e a 1.0 iria a 99, acima dos 90 do L75: `receitas_sim.py por_peca`). **Mistura de materiais vale; redução é a soma; todas as peças sofrem o golpe; peça quebrada reduz 0.** Tabela por peça e contas em `GDD.md` 5.11, tela e vagas em 5.20.

| Conjunto (5 peças) | Redução | Peso | Durabilidade (por peça) | Material do conjunto [premissa] | Saber | Marco |
|---|---|---|---|---|---|---|
| **Fibra** | 10% | 2 kg | 100 | 15 fibra (**Mãos**; sem as 2 madeira, que não se dividem) | 1 | depois do playtest |
| **Couro** | 25% | 6 kg | 150 | 8 couro + 4 fibra (**Mãos**) | 2 | M4 |
| **Metal** | 40% | 12 kg | 300 | 6 barra de ferro + 2 couro (**Bancada**, barra pronta) | 6 | M5 |

**Por peça** (camisa 30%, calça 25%, capacete 20%, bota 15%, luva 10% do conjunto): redução fibra 3/3/2/1/1, couro 8/6/5/3/3, metal 12/10/8/6/4 (camisa, calça, capacete, bota, luva); peso e material em `GDD.md` 5.11 (`fome_sim.py pecas`). **Reparo por peça:** na Bancada (o de metal na Forja), `ceil(50% do material da peça x fração que falta)`, com botão **"Reparar tudo equipado"** (soma antes de arredondar: metal 3 barras em vez de 5); **não reduz o máximo**. **Dano mínimo 1:** `dano = max(1, dano x (1 - redução))` para todo ataque que acerta com dano base >= 1; ataque de dano 0 (dardo) continua 0 (`GDD.md` 5.11).
- **Mobílias:** só as que têm função (Baú guarda, Canteiro produz baga, Forja funde; **Cama e Saco de dormir voltaram à v0.2 por decisão do dono, com função: respawn e save, `GDD.md` 12**). **Cocho (decisão do dono, 06/11): o dino domado come da comida do cocho num raio de 6 tiles (e do alforje se faltar); Saber 2, sem pré-requisito, 8 madeira, à mão, M2 cortável; 40 itens; a validade corre dentro** (`GDD.md` 5.12). **Sem decoração e sem efeito térmico.**
- **Recursos:** Ração, Bandagem, Preparado, Corda, Couro curtido, Tijolo, Barra de ferro. Nada sem consumidor.

## 5. Estruturas e dano de dino

Regra completa em `GDD.md` 8.1: madeira 60/120, palha 20/40, pedra imune, **sem metal**.

## 6. Metal: Forja, ferramentas e o conjunto de metal (recomendação)

- **Nada na v0.2 depende de metal.** A 1.0 depende só para **Espada**, **segundo tier de coleta** (ferro 1,75x mais rápido, 2x a 2,5x mais durável, `durab_sim.py ferr`) e o **conjunto de metal** (40%).
- **Recomendo manter, depois da v0.2:** com durabilidade, a ferramenta de pedra vira um tier real que o jogador quer superar (394 madeira por ferramenta de ferro contra 112 de pedra). **Se cortar, corta junto a Espada de ferro** (usar Lança) e saem 6 itens (Forja, Machado, Picareta, Espada, conjunto de metal e Besta), **32 Saber** (a Barra é processo, sem receita); sobram fibra e couro (10% e 25%).
- **Receita:** **Forja (Saber 4, 8 madeira + 20 pedra, 30 kg, fabricada na Bancada, decisão do dono 06/11; depois de pronta é a estação dos itens de metal)**, Barra de ferro (**processo da Forja, sem receita no menu**: 3 madeira queimam em 1 carvão em 30 s e 2 minério + 1 carvão viram 1 barra em 10 s, `GDD.md` 5.17), Machado de ferro (3 barras + 2 madeira + 1 fibra), Picareta de ferro (3 barras + 2 madeira), Espada de ferro (4 barras + 1 couro), **Besta (5 madeira + 2 barras + 2 corda, Saber 4, M5)**. **Minério** é nó novo de pedra (precisa de Picareta de pedra): o **Filão de ferro** (`iron_seam`, 2 minério em 14 s, volta em 900 s), 8 na Pedreira (flanco leste), **só instanciados no M4** (`mapa-ilha.md` 8); 36 minério para as 18 barras de tudo, 3 passadas, 30 min de espera [calculado, `mapa_sim.py recursos`].
- **Marco: M4 a M5** (Espada com a Forja no M4; Machado, Picareta e conjunto de metal no M5). Escopo: 1 recurso, 6 receitas, 4 sprites de item, 1 nó de minério e a Forja com carvão (5.17).


## 6b. Pilão e químicos (decisão do dono, 06/11; `GDD.md` 5.18)

- **Pilão:** **item portátil, feito à mão e usado no próprio personagem** (menu Receitas, aba "Moer"); não é estação colocada. **Saber 1** (T1), receita **2 pedra + 1 madeira**, **3,5 kg** (3,0 + 0,5), durabilidade 100 moagens (1 por moagem), estação "Mãos".
- **Preparado de sono (nome único; é o químico de sono do pedido):** a receita **sai da Bancada e vai ao Pilão**: 3 Cochilo + 1 carne podre rendem 3 preparados, **4 s** de moagem, Stamina 3/s (12). Saber 3, sem pré-requisito (lista plana). **v0.2: 21 receitas e 22 Saber** (o Pilão soma 1 e 1; Saco e Cama, +2 e +2); **cabe nos 24 (sobra 2)**.
- **Fósforo e pólvora: SEM MARCO (decisão final do dono, 06/11).** Sem Rifle e sem arma de fogo nada os consome; ficam fora da árvore ativa e do mapa de recursos (registro: fósforo 2 sílex + 2 pedra rendem 6; pólvora 2 carvão + 2 fósforo rendem 4). Se um dia entrarem, são +2 receitas (Saber 2 e 3).
- **Sílex (decisão do dono, 06/11): volta no M4, com fonte** (pedra comum e pedra de minério, GDD 5.9c). **Consumidor: a Flecha comum passa a 2 graveto + 1 sílex + 1 fibra (rende 4)**, o sílex no lugar da pedra; sem receita nova. Fósforo continua sem marco.

## 7. O que saiu da árvore ativa

**Cortadas:** Armadilha de laço, Lança de pedra, Traje de pele, de osso e de quitina, Escudo (todos), Couro curtido, Placa, Tapete de pele, Tocha, Secador, Composteira, Teto, Rampa e escada, Portão reforçado, Muralha, Tecido, Argamassa, Aço, Baú reforçado e **toda estrutura de metal**; **Bastão reforçado (06/11)**; **a Cama de fibra voltou como Cama e Saco de dormir (decisão do dono, rodada após 06/11)**; **Rifle, Dardo, Fósforo, Pólvora e Sílex: adiados sem marco (06/11)**. **Voltaram por decisão do dono (06/11):** Boleadeira (M4) e Besta (M5). **Lista "depois":** Armadilha de laço, Tapete e Placa. Motivo comum: nenhum sistema definido as consome.

## 8. Tiers, fósseis, co-op e save

- Ração S e S+ **só por fóssil** (M4, Saber não paga). Fóssil ensina sem Saber.
- **Co-op:** Saber e receitas são do **personagem**, não do servidor. Bancada e Fogueira são da base e servem quem estiver perto.
- **Save:** `saber_gasto`, `receitas[]`; versão do save sobe.

## 9. Marco e listas

- **M1:** Lança de madeira, Machado, Picareta e Fogueira como itens e receitas por dados (`RecipeDef`), menu P aba Receitas. **M2:** Bancada, Saber e as 17 aprendíveis da v0.2 (21 receitas menos as 4 conhecidas), **Saco e Cama junto da construção**. **M4:** conjunto de couro (5 peças), arco, flechas (comum e de sono), Boleadeira, Corda, Tijolo, Palha, Canteiro, fósseis. **M4 a M5:** metal e Besta.
- **`SORA`:** `RecipeDef` com estação (Mãos, Bancada, Fogueira, Forja), `saber_custo`, `prereq`; tela P com aba Receitas; validação de servidor do gasto; Fogueira com ação "assar".
- **`YATORA`:** ícones das 21 receitas da v0.2 (com Saco e Cama; sem Bastão reforçado) e 2 sprites de peça (Saco colocado e Cama) e sprite da Fogueira (acesa e apagada); **15 ícones de peça** (fibra, couro, metal x camisa, calça, capacete, bota, luva) e 6 silhuetas de vaga; **sem sprite de corpo por peça** (recomendo, V70) e sem variação de frio ou calor.

## 10. Conflitos e o que falta provar

1. **"Uma só estação" (05/11) vira Mãos + Bancada + Fogueira.** Custo: 1 sprite e 1 ação. Se o dono preferir uma só estação, a Fogueira só assa (não é estação de receita) e já vale como está.
2. **Fogueira estava "fora por falta de função"**; a função é assar carne (validade). Só vale se a validade da carne ficar (decidido).
3. **v0.2 completa no L20:** escolha só de ordem. Aceito.
4. **Precisa jogar:** ritmo do Saber (3 no L3), se 4 receitas conhecidas bastam para o início, se a ordem Bancada, Bastão, Ração C é óbvia ao jogador.

5. **Fibra: decidido, depois do playtest e fora da v0.2** (vagas e peças ficam em 5.20; as peças de fibra são do M4). **Couro segue sem uso na v0.2** (o Bastão reforçado foi cortado); só serve ao Arco e ao Traje de couro no M4.
6. **Temperatura fora, sem marco (decisão do dono):** roupas e mobílias **não** têm efeito de calor ou frio; roupa só reduz dano.
7. **Cocho:** mantido na v0.2 como cortável; se cortar, o dino domado só come do alforje (limiar 25) e do jogador.
8. **Cocho e Oferta:** o Cocho segue como inventário do rebanho (`GDD.md` 5.12 e 5.13). O slot de Oferta **não é receita nem mobília**: é interface, sem Saber.
9. **Rifle e Dardo: adiados sem marco (decisão final do dono, 06/11)**, substituindo a exceção de 5.4. Ficam arco, besta e boleadeira (GDD 5.4): Corda (1), Arco (2), Flecha comum (2), Flecha de sono (2), Boleadeira (2) no M4; Besta (4) no M5. **Flecha de sono entra (recomendo):** 4 flechas comuns + 1 Preparado rendem 4; dá ao Preparado um segundo uso. Cortáveis sem dano ao resto: Boleadeira e Besta.
10. **Preparado de sono (v0.2):** feito no Pilão, sem pré-requisito (lista plana); o jogador não o consome, só o dino pela tela dele, e a flecha de sono (M4) o usa como ingrediente.
11. **Forja na Bancada (decisão do dono, 06/11):** a receita da Forja pede a Bancada como estação; a Forja continua sendo a estação de Barra de ferro, Machado, Picareta, Espada e conjunto de metal (a Besta é feita na Bancada). Cadeia: Bancada, Forja, Barra, itens de metal (4 elos; a cadeia mais longa da 1.0 não muda).
12. **Forja queima madeira (decisão do dono, 06/11):** o carvão é item necessário da barra (2 minério + 1 carvão), feito de 3 madeira; Forja de 4 vagas que trabalha sozinha; custo de uma barra 2 minério + 3 madeira. A Barra de ferro deixa de ser receita de menu. Carvão só da Forja é a recomendação; usar na Fogueira é decisão do dono (V61).

13. **Pólvora e Rifle: resolvido (06/11).** Sem Rifle e sem arma de fogo, a pólvora, o fósforo e o sílex ficam sem marco; não há mais conflito com 5.4.
14. **Carvão só da Forja (aceito pelo dono, 06/11).** Opcional na Fogueira (V61), não pedido.
15. **Regra de produção (06/11):** a Bancada fica com 3 receitas da v0.2 (Ração) mais o reparo; **precisa jogar** se isso a justifica ou se a Ração deveria ir à Mão (então a Bancada só serviria à Forja e à Besta, no M4+).
16. **Saber em lista plana (06/11):** sem pré-requisito; a UI ordena por custo. Se o playtest pedir "descoberta" em árvore, volta como dado (campo `prereq` já existe no `RecipeDef`).
17. **Mochila (decisão do dono, 06/11; ITEM FUTURO, sem números definitivos):** couro + fibra, Mãos, Saber 2, **M4**; **fora da v0.2** (v0.2 segue com 21 receitas e 22 Saber com Saco e Cama). Provisório na 1.0: **56 receitas e 77 Saber (completa no L65)**. **Conflito:** só tem efeito se os slots passarem a limitar (5.1 dizia só exibição); recomendação em `GDD.md` 5.21 (base 24 + 16 = 40, tirar cheia recusa). Dá ao couro um uso.
18. **Selas (decisão do dono, 06/11; só para as espécies "montável com sela": Parassaurolofo e Triceratops; Utahraptor monta sem sela e sem vaga):** Sela de fibra (Saber 1; 20 fibra + 4 madeira; Mãos), de couro (Saber 2; 10 couro + 6 fibra; Mãos), de metal (Saber 4; 4 barra + 6 couro; Bancada). Cada uma é 1 receita e 1 nó. Dão Peso extra de alforje (+20/+40/+60%) e defesa (8/15/25%); vaga própria no dino (`GDD.md` 6.13). **Marco: junto da montaria, depois do playtest** (fibra e couro M4+, metal M5). **Fora da v0.2** (19 receitas e 20 Saber).
19. **Totais provisórios da 1.0 com Mochila e selas: 59 receitas e 84 Saber (completa no L70)**; antes 55 e 75 (L63) sem Mochila e selas; 53 e 73 (L61) sem Saco e Cama. `receitas_sim.py arvore`.
20. **Decidido pelo dono (06/11), sem mudar números:** Saber por conjunto de roupa (3 nós, 15 receitas), sprite sem mudança por peça, Mochila e selas no M4 (selas junto da montaria; metal M5), Postura e Ir até aqui depois do playtest. Totais (atualizados com Saco e Cama): v0.2 21 receitas e 22 Saber; 1.0 provisória 59 e 84 (L70). Conflitos 47 a 51 do `GDD.md` resolvidos.

21. **Saco e Cama (decisão do dono; números propostos pela SHIRO, `GDD.md` 12.3, `respawn_sim.py custo`):** Saco 8 fibra (24 s de coleta), Mãos, Saber 1; Cama 12 fibra + 8 madeira (57 s), Bancada, Saber 1. **Os dois são aprendidos, não conhecidos** (mantém as 4 conhecidas); custo: aprender tudo passa do L17 ao L19 e a sobra do L20 cai de 4 a 2. **Alternativa:** Saco conhecido (5 conhecidas): 21 Saber, sobra 3, L18. **Precisa jogar:** se a ordem Bancada, Bastão, Ração C, Abrigo deve abrir espaço para a Cama antes de a primeira morte acontecer (a ordem recomendada da sim a põe em 8 Saber, L8, ~40 min).
