# Dino Vale: Game Design Document (GDD)

Status: v0 de visão, 05/11/2026. Autora: `SHIRO`. Fonte da verdade de design. Escopo, prazo e marcos são de `docs/PLANEJAMENTO.md`; onde este documento discorda, está marcado **CONFLITO** e listado na seção 17. Não alterei o plano.

Convenção: **[calculado]** saiu de conta; **[jogar]** só playtest responde; **[premissa]** número assumido. Marco = M1 a M6 do plano. Corte: **Essencial** (sem isso a v0.2 não fecha o loop) ou **Cortável**.

Anexos: `docs/design/racao.md` (comida de domesticação, qualidade S+ a C) e `docs/design/receitas.md` (árvore de receitas e Saber). Em conflito, vale este GDD. Espécies usam nome real (6.1); nomes de itens e sistemas, incluindo Ração, são próprios e originais; biomas e outros termos de design são provisórios.

Decisões do dono de 06/11 e 07/11: a fonte única é `docs/design/corte-v02/decisoes-0611-0711.md` (DECIDIDO e PROVISÓRIO); as propostas detalhadas estão em `docs/design/corte-v02/shiro.md` e `shikamaru.md`. **Onde este GDD ainda traz um texto antigo que as contradiz, vale o arquivo de decisões; os trechos já reescritos trazem a marca "Atualizado em 07/11".** Itens marcados **[provisório, aguarda o dono]** são recomendação da equipe aplicada para o código andar e podem mudar.

## Estado em 07/11

**Implementado (até a etapa E1 do corte da v0.2):** ilha Lunata (mapa único, 256 tiles); coleta de recursos; Soco; carcaça; doma do Paquicéfalo; placa do domado (nome, "Nv" e vida); nível do dino selvagem visível ("Nv N", a até 6 tiles, só acordado e vivo); cursor do mouse em pixel art; `ServerRules` (ADR-004) lendo `server_rules.json`; Utahraptor semeado nas tocas da Mata-baixa, com perseguição. Sprites de IA estão como `IA-placeholder` (arte final depois, com artista).

**Ainda não existe:** slots que limitam e as bolsas, fome leve e desmaio com o caído como alvo, corpo e tela de morte nova, dia e noite, chuva, montaria, Neutro, ficha, Dodo e Triceratops no mundo.

**Onde está o corte da v0.2:** `docs/design/corte-v02/` (`decisoes-0611-0711.md`, `shiro.md`, `shikamaru.md`). O corte (4 espécies, 17 receitas, 24 etapas E0 a E23) é **[provisório, aguarda o dono]**; a ordem das etapas está em `shikamaru.md`.

**Decidido pelo dono (resumo):** sobrevivência direta com poucas regras claras; dia e noite e chuva, neve só em bioma de gelo (não existe na v0.2), **sem estações e sem sanidade**; fome leve; o torpor é a ameaça (o jogador desmaia e pode ser devorado); 4 slots e uma vaga de bolsa (5.21); Peso mantido (5.1); dino sem sela com 4 slots (6.13); domado Neutro ajuda no combate (6.11b); montar em porte Médio ou maior, sem sela (6.12); ficha de RPG (5.20); renascer em local aleatório ou numa Cama ou Saco da lista, com nome editável (12.2 a 12.4).

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

Mapa fixo na 0.2 (plano: MUN-01, MUN-03); chunk e seed no M4. **Na 0.2 o mundo é uma única ilha em meia-lua** (**Lunata**, nome decidido pelo dono; desenho, números e lugares em `mapa-ilha.md`). O mapa completo, com mais terras, vem depois.

| Bioma (provisório) | Papel | Perigo | Recursos | Marco |
|---|---|---|---|---|
| **Campina** | Início, abrigo, Paquicéfalos | Baixo de dia | Baga, Samambaia, Fibra, Tubérculo, madeira | M1 |
| **Mata-baixa** | Madeira, caça, Utahraptor, Dodo | Médio (carnívoro persegue) | Madeira, Carne, **Cochilo, Dodo e Listro**, Mel-de-cipó (cortado) | M2 |
| **Pedreira** | Pedra, Sal-de-veio, Triceratops | Médio-alto (território) | Pedra, Sal | M2 |
| **Clareira-brasa** | Seiva, prestígio | Alto | Seiva-de-brasa | M4 |

Regra de desenho: **o perigo é parte do bioma**, não evento aleatório. Cada bioma tem uma ameaça que justifica a vigília de domar (H1 do plano). Tamanho do mapa fixo: [premissa] **256x256 tiles (16 px)** para a ilha (fixo, decisão do dono; `mapa-ilha.md` 2); o trajeto mais longo do início à ponta (282 tiles) leva **~64 s a pé** a 70 px/s [calculado, `mapa_sim.py`; o antigo "128x128 em ~29 s" não vale mais]; sprint 120 px/s dura 4 s [calculado: stamina 100 / dreno 25/s]. Cortável: 3º bioma na 0.2 (basta 2).

### 4.1 Regras de mundo (decisão do dono, 06/11)

- **O cenário não tem construção humana.** Só natureza e **formações rochosas** (arco, pilar, lajedo, gruta). Casa, vila, ruína, estrada, cerca, ponte, poço, baú e placa só existem se o **jogador** construir (seção 8). **Trilhas naturais** (terra batida por bicho, 1 a 2 tiles, borda orgânica, sem retas longas) podem existir; estrada não.
- **Marcos e obstáculos são rochas** (`mapa-ilha.md` 4). A casa e o baú decorativos do cenário de hoje saem no MUN-01; a "Casa" da tabela de arte (`arte/ESTILO.md`) é só peça do jogador.
- **Limite do mundo:** praia, água rasa e água funda; a funda bloqueia, sem nado na 0.2 (`mapa-ilha.md` 3). **Mapa único e contínuo, sem quadrantes, troca de tela nem teleporte; o que está longe não é desenhado. A câmera acompanha centrada e só para no limite do mapa**, que o personagem não alcança: 12 tiles de mar funda no mínimo entre o caminhável e a borda (`mapa-ilha.md` 2). **Pós-MVP, sem marco e fora da 0.2 (decisão do dono, 06/11):** barcos e dinos que cruzam o mar. Na 0.2 o limite é o retângulo do mapa com uma faixa de oceano visível além da praia, e a água funda bloqueia. **Nada na 0.2 impede a travessia depois:** o mar é parte da grade do mundo (tiles de água funda dentro dos 256 x 256, com colisão só no anel de 2 tiles, que vira regra de dado `atravessavel_por`), então barco e nado mudam a regra de colisão, não o mapa; um mundo maior ou outra ilha entra por `map_id` (6.1) e pelo chunking do M4.
- **Todo dino é domável (decisão do dono, 06/11).** Não existe espécie de dino "só presa" nem "não domável": toda espécie nasce com perfil de doma (`torpor_max`, queda, comida aceita, fator de refeições) e um ofício, e o método vem da Conduta (6.7): Passivo e Curioso com Bastão; Agressivo com Bastão e curral; Semi-agressivo com Bastão no nível certo; **Covarde com 2 golpes de Bastão dentro do susto, ou Arco**; Medroso (futuro) com Arco ou emboscada. A Lança continua abatendo qualquer espécie com carcaça (caçar ou domar é escolha do jogador). Espécie nova só entra no elenco com perfil de doma. **Criaturas que não são dino (artrópodes das cavernas) ficam fora da regra (decisão do dono, 06/11, V77):** são fauna-recurso, caçadas pela Lança, sem perfil de doma.
- **Nó esgotado some por inteiro (decisão do dono, 06/11).** Arbusto, árvore, rocha e pedra (inclui a pedra avulsa), ao terminar a colheita, saem do mapa com **sprite e colisão**, e o tile fica livre para construir. O nó volta pelo respawn já definido (cada nó mantém o seu tempo), **só se o lugar estiver livre**: construção do jogador em cima impede a volta. **Colheita parcial não faz o nó sumir.** Isto substitui o "arbusto desfolhado" que ficava no mapa sem colisão.
- **Mais fonte, para liberar área de construção (decisão do dono, 06/11; substitui a proporção 1:3).** **todas as árvores são coletáveis**, sem árvore decorativa; **rochas soltas são todas coletáveis**; as **formações rochosas fixas** (arco, pilar, lajedo, gruta) seguem como marcos e obstáculos e não se colhem. Nenhum número de nó novo: a contagem exata sai do `mapa-ilha.md` e do MUN-03 (ver V80).
- **Legibilidade (decisão do dono, 06/11):** a formação fixa tem aparência **claramente diferente** da rocha coletável; o **nó coletável ao alcance ganha contorno e o nome do que rende** (ex.: "Madeira").
- **Árvores:** todas são coletáveis, com variantes de aparência (`mapa-ilha.md` 8). Efeito em 20.8: o fóssil ou a marca na rocha fica numa formação rochosa ou gruta, não numa ruína.

### 4.2 Escala, portes e câmera (decisão do dono, 06/11)

**Referência de escala (dono).** Tile 16 px; **humano de 16x32 px = porte Médio**; câmera bem próxima, **viewport 320x180 (20 x 11,25 tiles; 4x em 1280x720, 6x em 1920x1080)**, para sprites com mais detalhe. Seis portes. Números [premissa], tabela em dado (a mesma linha vai para `game/data`, `porte.tres`, quando o `SORA` implementar).

| Porte | Quadro (px) | Altura em humanos | Colisão no chão (px) | Passagem mínima (tiles) | Cerca / Portão de dino / vão | Entre árvores | Espécies na 0.2 | Exemplos do dono |
|---|---|---|---|---|---|---|---|---|
| **Diminuto** | 16x16 | 0,5 | 8x8 | **1** | cerca fecha; Portão de 1 tile passa | passa e some atrás da copa | **Dodo** | dodo, pegomastax, compsognato, lontra |
| **Pequeno** | 24x24 | 0,75 | 12x12 | **1** | idem | passa; copa cobre | **Paquicéfalo** | moschops, paquicefalossauro, dilofossauro |
| **Médio** | 32x32 (dino); humano 16x32 | 1,0 | 14x14 (humano: pés 12x8) | **1** | idem | passa por vão de 1 tile | **Parassaurolofo, Utahraptor** (e o jogador) | parassaurolofo, utahraptor, dente-de-sabre, anquilossauro, doedicuro, castoroides |
| **Grande** | 48x48 | 1,5 | 28x24 | **2** | cerca fecha; **Portão duplo** (2 portões lado a lado); vão de 2 | exige 2 tiles livres | **Triceratops** [assumido] | carnotauro, estegossauro, terizinossauro |
| **Muito grande** [nome assumido] | 64x64 | 2,0 | 44x36 | **3** | Portão triplo; vão de 3 | exige 3 tiles livres | nenhuma (só tabela) | rex, espinossauro, diplódoco |
| **Gigante** | 128x96 | 3,0 | 72x40 | **5** | Portão quíntuplo; vão de 5 | só em clareira ou praia | nenhuma (só tabela) | brontossauro, giganotossauro |

**Regras da tabela.** (1) **Colisão só nos pés** (a cabeça, o pescoço e a cauda ficam sem colisão e passam por cima do jogador pela ordem de profundidade): é isso que impede o Gigante de virar parede. (2) **Passagem mínima = ceil((colisão + 2) / 16)** tiles; os 2 px são folga. (3) **Cerca e parede fecham todos os portes**; só o **Portão de dino** (8.1) abre, e o porte **Grande ou maior precisa de portões lado a lado** (peça existente, sem arte nova; Portão = 4 madeira, então 8 madeira para um Triceratops). Isso muda o curral natural (`mapa-ilha.md` 7): trancar o vão de 4 para um Grande custa 2 Portões em vez de 1, +4 madeira. (4) **Árvore nova 48x80** (copa 3 tiles de largura, tronco 12x8): a de 48x48 ficava com 1,5 humano; as árvores nascem com tronco a pelo menos 2 tiles livres de outro (os Grandes passam) e **Muito grande e Gigante só existem em clareira, praia e campina** [proposta]. (5) **Sprite grande cobre o jogador** (copa, Gigante): o jogador ganha **silhueta translúcida** quando está atrás de qualquer coisa de 48 px ou mais. (6) Filhote = **um porte abaixo** do adulto (Médio vira 24 px, Pequeno 16 px) [proposta, M4]. (7) A escala visual por nível (0,85 a 1,15) se mantém dentro do porte.

**Reclassificação do elenco da v0.2 (era: Dodo pequeno, Paquicéfalo e Utahraptor médios, Parassaurolofo e Triceratops grandes).** **Dodo = Diminuto; Paquicéfalo = Pequeno; Parassaurolofo e Utahraptor = Médio** (o dono citou os três). **Triceratops = Grande (decisão do dono)**: 8 a 9 m, o comprimento do estegossauro e do terizinossauro, que ele pôs no Grande. **Contra-argumento:** pela massa (6 a 12 t) ele iguala o rex, que está no Muito grande. Fico com o Grande porque o porte aqui segue o comprimento e a sensação (48 px, 1,5 humano, passa em vão de 2), e porque o sprite de 48 px é menor que o de 64 (o Muito grande exigiria também portão triplo). **Percentuais da população** (`mapa-ilha.md` 5): diminuto 39%, pequeno 30%, médio 29%, grande 2% nos 360 dinos (140, 108, 104, 8).

**Câmera: 640x360 contra 427x240 contra 320x180** [calculado, `mapa_sim.py camera`]:

| Viewport | Tiles vistos | Escala exata | Aviso lateral antes de o Utahraptor perceber (8 tiles) | Aviso vertical | Humano na altura | Gigante (96 px) na altura |
|---|---|---|---|---|---|---|
| 640x360 | 40 x 22,5 (900) | 2x (720p), 3x (1080p) | 12 tiles (2,7 s) | 3,2 tiles | 8,9% | 27% |
| 427x240 | 26,7 x 15 (400) | 3x em 720p (1281 px, corta 1 px); em 1080p é 4,5x, não inteira | 5,3 tiles (1,2 s) | negativo | 13,3% | 40% |
| **320x180** | **20 x 11,25 (225)** | **4x (720p), 6x (1080p), 8x (1440p)** | **2 tiles (0,5 s)** | **negativo (ele percebe fora da tela)** | **17,8%** | **53%** |

**Recomendo 320x180** (a opção do dono): é de escala inteira em 720p e 1080p e dá mais detalhe aos sprites; a perda (aviso de 0,5 s) é compensada por três mudanças de regra, todas [proposta]: 
1. **Percepção do Agressivo em elipse (decidido): 8 tiles na horizontal e 5 na vertical** (distância efetiva = raiz de dx² + (1,6 dy)²). Sem isso o Utahraptor ataca de fora da tela (a meia altura é 5,6 tiles). Com a elipse, tudo o que ele percebe já está visível. Os demais tipos de Conduta mantêm 8, porque fugir de longe não machuca.
2. **Sinal de ameaça (decidido) na borda a 12 tiles** (seta/olho que pisca no canto da tela mais próximo do Agressivo) **e rosnado audível a 14**. [calculado] avisa 0,7 s antes da percepção se ele corre e 1,6 s se ele ronda (40 px/s). Sem isso o aviso visual é de 0,5 s: injusto. **Perseguição não muda com a câmera:** percebe a 8, contato em 1,2 s parado; andando em fuga ele fecha 1,25 tiles/s (5,6 s); o sprint de 4 s abre 7,5 tiles.
3. **Zona ativa de raio 16** (meia diagonal da tela 11,5 + 4,5 de margem), distante de 16 a 40 (era 24 e 48 a 640x360); quem persegue fica ativo pelo estado. **Câmera centrada que só para no limite do mapa**; a margem de 12 tiles de mar dentro do mapa (`mapa-ilha.md` 2) garante que não pare na prática, e não há mar desenhado além da borda.

**Sensação de tamanho da ilha (256 fixo, decisão do dono):** o tempo a pé não depende da câmera: a ponta norte fica a **64 s** do início (54 s com sprints), e o campo de visão de 320x180 cobre ~4,6 s de caminhada na horizontal. O mapa é um só, contínuo, sem troca de tela nem teleporte. Com a tela menor, a densidade antiga (1 a cada 118 tiles) daria 1,9 no campo de visão; **a densidade é de 1 dino a cada ~59 tiles = 360 dinos (3,8 no campo)**, com 13,5 ativos em média e ~27 no pior caso (raio 16, teto 32). **Escopo de trabalho** (`mapa-ilha.md` 9): o `SORA` refaz HUD, atalhos, inventário e menus para 20x11 tiles; o `YATORA` desenha o jogador 16x32 com animações, Dodo, Paquicéfalo, Utahraptor, Parassaurolofo, Triceratops, árvore 48x80 e a referência dos seis portes. Por espécie: 3 direções desenhadas (a direita espelha a esquerda), andar 4 + parado 2 + ferido 1 (+ ataque 3 a 4 nos que revidam ou mordem) por direção, dormir 2, com limpeza de contorno e paleta e conceito por espécie. **Precisa jogar:** o aviso de 0,5 s mais sinal basta? o sprite de 16 px do Dodo lê bem a 4x? o HUD cabe sem encobrir 11 tiles de altura?

## 5. Sobrevivência

Valores no código: stamina 100, dreno 25/s, regen 15/s, retoma com 20; fome 100, queda 0,5/s hoje. **Atualizado em 07/11: a fome passa a 0,1/s** **[provisório, aguarda o dono]** **e não causa dano nem mata; zerada, sobe o torpor do jogador (5.10).**

| Sistema | Regra | Marco | Corte |
|---|---|---|---|
| Vida | Dano de dino e de fome; regenera lento fora de combate | M1 | Essencial |
| Stamina | Sprint e ataque; esgota em 4 s, volta em 5,3 s (0 a 80) | M1 | Essencial |
| Fome | Leve: 0,1/s; come-se baga/carne; zero **não** causa dano, sobe o torpor (5.10). O jogo não gira em torno dela | M1/M2 | Essencial |
| Dia e noite e chuva | **Decidido (07/11):** ciclo de dia e noite; noite mais perigosa, visão menor; chuva sem efeito mecânico **[provisório, aguarda o dono]**. **Neve só em bioma de gelo (não existe na v0.2); sem estações; sem sanidade** | v0.2 | Essencial (a chuva é decisão do dono) |
| Sede | Não | M2 Could | **Cortar** |
| Temperatura (hipertermia e hipotermia) | **Fora, sem marco (decisão do dono, 06/11)** | -- | Fora |

**Fome (atualizado em 07/11): 0,1/s** **[provisório, aguarda o dono]**. Cheio dura 1.000 s (16,7 min); a baga (+10) rende 100 s e a cozida (+35) rende 350 s [calculado]. O valor antigo de 0,5/s (200 s por barra) está superado.

**O dano de fome sai** (decidido: fome leve; a ameaça é o torpor, 5.10). A chave `dano_fome` do servidor fica obsoleta (13).

### 5.1 Atributos, níveis e pontos (conjunto do MVP)

**Decisão do dono (06/11):** níveis concedem **pontos que o dono distribui**, no dino e no personagem, na **versão enxuta** abaixo. Isto **substitui** a versão "sem pontos e sem nível de jogador" e **conflita com o plano** (seção 9 e conflito 14). Atributos: **Vida, Dano, Stamina, Peso**; **Fome** e **Torpor** são medidores; **Velocidade** é fixa por espécie. Fórmulas do dino selvagem em `racao.md` 10.2; simulação em `pontos_sim.py`.

> **Atualizado em 07/11.** **Pontos de atributo (PRO-12) ficam fora da v0.2** **[provisório, aguarda o dono]**; a ficha de RPG (5.20) é só de leitura. **Peso continua (decidido):** capacidade fixa de 50 kg, impede pegar acima de 100%, sem lentidão; o "+3 kg por ponto" abaixo só vale se os pontos voltarem. **O inventário passa a ter 4 slots que limitam (5.21), além do Peso.**

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

**Escopo:** `Attributes` com fórmula e testes; XP e nível do jogador; XP de companhia e níveis extras do dino; `distribuir_pontos` e validação; tela de pontos jogador e dino; save e versão.

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
| Cochilo | 0,1 | Preparado de sono / Carne podre | 0,15 / 0,5 |
| Baga, Samambaia | 0,1 | Tubérculo, Mel-de-cipó | 0,3 |
| Fibra | 0,05 | Bastão-de-sono / Lança-de-pedra | 2,0 / 2,5 |

Capacidade: **jogador 50 kg** (+3 kg por ponto só se os pontos voltarem; fora da v0.2). Dino (**histórico, superado em 07/11**: o alforje do dino é de 4 slots e a carga em kg é M4b; os números a seguir são só referência; base no nível 10, kg): Paquicéfalo 40, Parassaurolofo 100, Triceratops 120, Gallimimus 25, Utahraptor 0 (não carrega). Com a fórmula [calculado, `nivel_sim.py niveis`]: Paquicéfalo 40/52/64 em L10/20/30; Parassaurolofo 100/130/160; Triceratops 120/156/192; Gallimimus 25/32,5/40.

Contas de referência:
- **Abrigo mínimo** (seção 8): 32 madeira + 4 pedra + 1 fibra = 38,05 kg, **76% da capacidade** do jogador: cabe em uma viagem. Dois abrigos (76 kg) pedem 2 viagens a pé, ou uma com um Paquicéfalo L10 (40 kg) junto.
- **Kit inicial** (10 baga, 4 carne, 3 samambaia): 3,3 kg, 7%.
- **Ração para domar** o Triceratops L28 em C (21 rações): 4,2 kg; nunca é o gargalo.
- **Slots (atualizado em 07/11):** o jogador tem **4 slots** e uma vaga de bolsa (+4 ou +8, 5.21); slots **limitam** a variedade e o Peso limita a massa. A conta antiga de 40 slots só de exibição está superada.

**Ao passar do limite (regra da 0.2; vale até a regra de carga em faixas entrar no M4b, ver 5.1b) (recomendação mais simples):** **impedir pegar** acima de 100%, sem lentidão. Coletar de um nó cheio não gasta o nó; a mensagem diz "peso máximo". Excesso só nasce por produção ou recuperação de corpo, e então o jogador fica acima do limite sem poder pegar mais nada até gastar peso. **Lentidão por sobrecarga** (x0,8 acima de 100%) fica como opção de servidor desligada, para o M4: exige regra de velocidade no servidor e interface; o ganho no MVP é pequeno.

**Ofício Carregar (atualizado em 07/11: o alforje do dino tem 4 slots além do Peso, 6.13; a carga em faixas e a Carregar completa seguem no M4b):** o dino com Afeto de 10 ou mais e a ordem "seguir" carrega um **alforje**, que é o `InventoryComponent` dele com limite de peso igual ao seu Peso. O jogador abre o alforje ao lado dele; é o mesmo inventário que já recebe a Ração na domesticação. Se o dino fica ferido (seção 6.8), o alforje fica no lugar e é recuperável. O Peso do dino **não soma** ao do jogador: dois limites, uma única regra simples.

#### 5.1b Carga em faixas, Largar e bolsinha (decisão do dono, 06/11; **M4b, depois do MVP; fora da 0.2**)

**Substitui, quando entrar, "impedir pegar acima de 100%, sem lentidão".** Até lá vale o texto acima (PRO-09 como está). A regra vale **igual para o personagem e para o dino domado** (alforje), inclusive a faixa acima de 70%.

| Carga | Efeito [decisão do dono] |
|---|---|
| até 70% | nada muda |
| de 70% a menos de 100% | perde velocidade e **não corre** |
| 100% ou mais | **não se move** (o personagem ou o dino) |

- **Quanto de velocidade [proposta, em dado]:** queda **gradual linear**: `mult = 1 - 0,6 x (carga - 0,70) / 0,30`, de 1,00 em 70% a 0,40 logo abaixo de 100%, e 0 a partir de 100% (`carga_livre` 0,70, `carga_parada` 1,00, `carga_vel_min` 0,40). Tabela [calculado, `peso_sim.py curva`]: 75% x0,90 (40 tiles em 10,2 s), 80% x0,80 (11,4 s), 90% x0,60 (15,2 s), 99% x0,42 (21,8 s), contra 9,1 s livre. Por que gradual e não degrau: cada item pego dá retorno (o degrau fixo x0,6 daria 15,2 s em toda a faixa e o jogador não sentiria a escolha de levar mais um lote).
- **Dá para pegar acima de 100%? Sim, em um lote [proposta].** Pegar é permitido enquanto a carga **antes** da ação for menor que 100%; a ação que cruza entra inteira. Máximo = um lote (4 pedra = 6 kg: 112% do jogador, 115% do Paquicéfalo L10). Sem isso a imobilidade nunca aconteceria. "Pegar tudo" (corpo, baú, bolsinha) para em 70% e o restante se pega item a item.
- **Saída sem travar: Largar.** Hoje **não existe ação de largar** (a regra antiga não precisa). Com a nova ela é obrigatória. **Largar** (menu do item: 1, metade ou tudo; ou arrastar para fora da janela; 0,5 s) deixa uma **bolsinha** no chão; **"Largar excesso"** deixa a carga em 70% com um só toque. **Funciona parado em 100%, em qualquer tile, sem recusa.**
- **Bolsinha [decisão do dono + propostas]:** some em **5 min** (`bolsinha_largada_s` = 300, em dado); o relógio **só corre com o mundo rodando** e vai ao save como `restante_s`, como a espera da Cama (12.4). **Qualquer jogador pega** (sem exclusividade, `bolsinha_exclusiva_s` = 0), nenhum selvagem. Limites: **8 por jogador e 60 no mundo** (a mais antiga some, com aviso antes); sem colisão, então **nunca falha** por falta de espaço. Duas bolsinhas coladas **não se fundem** (cada uma com o seu relógio, para a fusão não estender nem encurtar prazo); "E" pega a mais próxima e, se houver empate, abre uma lista. Mesma entidade e mesmo código da sacolinha (5.6), só muda tempo e origem.
- **Dino domado:** o dono abre o alforje (E, a até 2 tiles) e usa o mesmo **Largar**, que deixa a bolsinha ao lado do dino. Dino parado em 100% longe do dono **não trava**: o dono anda até ele (o arco da ilha inteira leva 64 s) e usa Largar; o dono parado também larga primeiro. Dino em **Seguir** que chega a 100% passa para **Ficar** sozinho, com ícone "carga cheia", e o menu mostra Seguir e Ir até aqui cinza com o motivo. Dino com comida no alforje come dali e baixa a carga sozinho (5.12); dino de Ficar a 100% **não vai ao cocho** (não se move): a carga cheia é visível, é responsabilidade do dono. Postura e defesa continuam: um dino a 95% em Guarda anda a x0,5.
- **Montaria (M4b):** a velocidade montada é `espécie x 1,3 x mult(carga do alforje)` (6.12); a carga do jogador não conta montado (o cavaleiro e o que ele leva não pesam, como já está). Com o alforje em 100% o dino montado não anda; o jogador abre o alforje montado (já permitido) e larga.
- **Tela de inventário:** mostra a **% de carga** do personagem e do dino domado ("Carga 38/50 kg, 76%"), com marca em 70% e cores (até 70%, de 70% a 99%, 100%+ "imóvel"). Um ícone na HUD só acima de 70%.
- **Efeitos de conta [calculado, `peso_sim.py viagem`]:** a zona livre é **70% da capacidade antiga** (jogador 35 kg; Paquicéfalo L10 28 kg; Parassaurolofo L20 91 kg). O abrigo mínimo (38,05 kg, 76%) ainda vai em uma viagem, a x0,88 e sem correr (+1,3 s por 40 tiles); dois abrigos (76 kg) já não cabem a pé. Cada ponto de Peso (+6% da base) vale 2,1 kg de zona livre, não 3.
- **Marco:** M4b, fora da 0.2 (junto de Montaria e carga); PRO-09b faixas e % de carga; Largar e bolsinha; corpo de dino; `YATORA` com os sprites de 12.4. **Precisa jogar:** se x0,4 a 99% é punitivo, se 70% livre cabe a construção, se Largar excesso basta em combate.

#### Stamina do dino
Não faz diferença no MVP e **recomendo adiar**: não há montaria nem combate de dino domado que gaste fôlego, e o dino domado segue sem custo. No selvagem, a perseguição e a fuga já têm tempo fixo por Conduta (8, 10 e 15 s), sem stamina. Se um dia a stamina do selvagem substituir esses tempos (fuga = stamina / dreno), o nível a ampliaria em 20% por 10 níveis, mas isso muda números já decididos da Conduta. **Montaria, Postura e Sela: 6.11, 6.12 e 6.13.** **Reservar a fórmula no dado (M4, montaria), sem usar na 0.2:** a Stamina do dino **não aceita pontos** até haver montaria ou combate de dino com fôlego.

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

> **Atualizado em 08/11 (dono):** o atalho também se atribui **arrastando** o item do inventário para a posição (preview; arrastar de uma posição para outra troca; soltar fora limpa); item que não pode ir à barra recusa com a posição em vermelho. **Mover quantidade no inventário:** Shift+clique move 1; clique direito num stack com a outra tela aberta abre "Mover" (1, Quantidade..., Todos); a autoridade valida 1 a N, espaço e (no Bloco C) Peso. Só a baga e a carne crua são comida do jogador; a samambaia é de dino.

Nove posições na parte de baixo da tela. **Concordo com o M1**, porque resolve "comer do inventário" e a troca de arma; só a parte de dino (Ração e dardo) é M2.

- **Fruta e preparado de sono:** ver 5.5. **Regra do dono (06/11): a tecla de atalho sempre faz o jogador consumir.** O Cochilo apertado **come no jogador** (pede segundo aperto em 1,5 s); a Ração **o jogador nunca consome** (decidido); **o preparado de sono também não (decidido 06/11): só vai ao dino pela tela dele**. Dar ao dino **nunca** é pela tecla (5.13).
- **Atribuir:** arrastar do inventário ou, com o cursor sobre o item, apertar a tecla. O atalho aponta para o **id do item**, não para o slot. Mostra a **soma** das pilhas; com 0 fica **apagado mas atribuído** e volta quando houver estoque.
- **Usar (tecla):** comida (baga, carne, samambaia, Cochilo): **o jogador come 1** e restaura fome; **não gasta** se a fome está cheia. Arma ou ferramenta: **equipa**; apertar a tecla do item já equipado **desequipa** (mãos livres). **A arma equipada vive na vaga Arma do inventário (5.20)**; a tecla move da grade à vaga e de volta. Só arma e ferramenta trocam o equipado. **Ração: o jogador nunca consome (decisão do dono, 06/11); só o dino**, a tecla não age. **Preparado de sono: o jogador não consome (decidido 06/11); só vai ao dino pela tela dele (E).**
- **Dino (alinhado à regra do dono, 06/11):** a tecla **nunca** age sobre o dino. No **domar ativo**, a comida (Ração, baga, carne, fruta e preparado de sono) vai pela **tela de inventário do dino, aberta com interagir (E)**, e **o dino come de lá** (já implementado). No **domar passivo**, pelo slot de Oferta (5.13).
- **Cooldown [premissa]:** comida do jogador 0,5 s; troca de equipamento 0,3 s; O intervalo entre Rações vale na tela do dino (`racao.md` 1), e recusar não gasta.
- **Co-op:** a tecla envia `usar_atalho(item_id)` (sem alvo); o servidor valida item, quantidade, cooldown e se o jogador está vivo; **o cliente não decide consumo**. Dar ao dino é pedido separado `alimentar_dino(dino_id, item_id)` da tela do dino. A atribuição é do perfil do jogador (UI), salva com ele, sem validação.
- **Sem munição na v0.2:** Rifle e Dardo foram adiados sem marco (5.4); a flecha (M4) é munição do Arco e da Besta e **não está na barra de atalhos da v0.2**.
- Pode conflitar com ações de teclado de 1 a 9 que o jogo já use (`SORA` confere o mapa de entrada).

### 5.3 Camada 1 de corte: fora da 0.2 (decisão do dono, 06/11)

> **Revisto (06/11, dono):** a **Lança volta como Lança de madeira** (5.4) e **Dodo e Listro entram** como presas pequenas (6.1); o resto da camada 1 segue fora (Gallimimus, Ração S, Mel, Temperamento, dia e noite, configurações, música, NET-03, vocalizações). O parágrafo 1 abaixo vale para **antes** da Lança: com ela, ver 5.4.

**Fora da 0.2:** Arco, Flecha, Boleadeira e Besta (M4 a M5; Rifle, Dardo, arma de fogo, pólvora e fósforo **sem marco**; o sílex volta no M4, 5.9c), Bastão reforçado (cortado); **a Cama voltou à v0.2 no M2, com o Saco de dormir (12.3)**, peças de fibra (depois do playtest), Listro (M4 com o Oviraptor), slot de Oferta (depois do playtest), Lança-de-pedra, Gallimimus, Ração S e Mel-de-cipó, Temperamento do domado, dia e noite, configurações, música, NET-03 e vocalizações por limiar. A **pausa de torpor já está implementada**: fica como está. Tudo continua documentado como futuro. **Mantidos:** Peso, batismo (6.9) e barra de atalhos (5.2).

**1. Sem Lança, como o jogador lida com o Utahraptor?** O Bastão (dano 2) **não mata**: 40 golpes em 27 s, 18 mordidas de 8 = 144 de dano contra 100 de vida [calculado]. O caminho é **nocautear**: Utahraptor L20 (torpor 144) cai em 5 golpes, 2,8 s, com 1 mordida (11 dano); com 10 pontos em Dano, 3 golpes e 1,4 s. Ele dorme cerca de 103 s, mais que os 40 s de domar um Paquicéfalo em C. O que muda: **o ponto de Dano do jogador** passa a multiplicar também o torpor do golpe (é o menor ajuste que dá uso ao atributo sem Lança), e a regra "abaixo de 25% de vida foge" fica sem uso até haver dano maior (sem custo).

**2. Proteger o dormindo continua viável?** Utahraptor L20 mira um Paquicéfalo dormindo (aviso 3 s, mordida a cada 1,5 s, 14,5 E por mordida). **Um Utahraptor:** jogador a 2 tiles, 0 mordidas; chegando 2 s depois, 2 mordidas (-29 E); 4 s depois, 3 (-43 E). **Bando de 2 ou 3:** de -43 a -102 E. Conta falha com bando. **Menor ajuste, sem Lança:** (a) o Utahraptor é **solitário na 0.2** (bando vai ao M4, com curral e dino defensor); (b) o **primeiro golpe do jogador provoca**: o carnívoro troca de alvo para ele (a regra de provocar já existe), o que zera as mordidas no dormindo quando o jogador chega dentro do aviso de 3 s e deixa só -14,5 E se chegar depois. É regra de dado, sem Lança. Medido por `pontos_sim.py protecao`; **precisa jogar** para ver se 3 s de aviso é legível.

**3. Sem Ração S, a escada fica Baga, C, B, A** (`racao.md` 1, 12). Conta com `nivel_sim.py eficiencia` (caso médio, nível final): Triceratops L28 C 30, B 34, A 36; Parassaurolofo L20 C 24, B 25, A 26; Utahraptor L15 B 19, A 19; Paquicéfalo L8 B 10, A 10. A escada **ainda paga no Triceratops e no Parassaurolofo** e é plana nos pequenos (A só poupa 6 a 17 s). `racao_minima` (Paquicéfalo C, Utahraptor B, Parassaurolofo C, Triceratops A) continua válida: o topo exigido é A. A **Eficiência máxima real na 0.2 é 78 a 92%** (A, caso bom), não 100%: o bônus real é de +39% a +46%, não +50%. Sem S+ (M4) e sem S, **ninguém tem dreno 0**; o dardo (-2 E) continua melhor que golpe.

**4. Tipos de Conduta na 0.2: 4 confirmados** (Passivo, Agressivo, Semi-agressivo, Covarde). O Medroso (foge ao avistar) é conduta futura, sem marco; o Temperamento (do domado) também. A conta de fuga fica só no Parassaurolofo (75 px/s, alcançável).

### 5.4 Armas, torpor contínuo e sono (decisão do dono, 06/11)

> **Atualizado em 08/11 (dono):** a Lança de madeira e o Bastão-de-sono são **fabricáveis** (receita no M3: Lança 2 graveto + 3 madeira; o Bastão segue a receita do Saber 1), têm **barra de durabilidade** (Lança 80, Bastão 120), gastam 1 por golpe aceito e **quebram** em 0. No inventário só aparecem em build de desenvolvimento (debug ou `--dev`). A Lança tem alcance próprio de 1,8 tiles.

**Regra do dono:** (1) **só dano, torpor zero:** flecha comum, besta, espada, lança; (2) **dano e torpor em valores próprios:** soco, porrete (o **Bastão-de-sono**) e flecha de sono; (3) **torpor contínuo:** a flecha de sono segue aplicando torpor por um tempo depois de acertar. **Rifle, Dardo e qualquer arma de fogo: adiados sem marco (decisão final do dono, 06/11).** Simulação: `armas_sim.py`.

| Arma | Dano | Torpor imediato | Contínuo | Cooldown | Munição e recarga | Alcance | Marco |
|---|---|---|---|---|---|---|---|
| **Soco** (sem item) | 1 | 10 | -- | 0,6 s | -- | 1 tile | M1 (coleta e pedras: 5.9b) |
| **Bastão-de-sono** (porrete) | 2 | 30 | -- | 0,7 s | -- | 1,5 tiles | M1: **nasce no inventário, sem receita**; a receita (Saber 1) repõe no M2 |
| **Lança de madeira** | 12 | 0 | -- | 0,9 s | -- | 1,8 tiles | M1, **conhecida** |
| **Flecha de sono** (Arco) | 1 | 15 | 12/s por 5 s (60), total 75 | 1,2 s | 1 flecha (4 flechas comuns + 1 Preparado rendem 4); armar 0,6 s incluído | 10 tiles | M4 |
| Flecha comum (Arco) | 14 | 0 | -- | 1,2 s | 1 flecha | 10 tiles | M4 |
| **Boleadeira** (arremesso, 1 uso) | 0 | 0 | prende: velocidade x0,4 por 5 s | 8 s entre arremessos | 1 por arremesso (2 corda + 2 pedra, Mãos) | 6 tiles | M4 |
| **Besta** (usa a mesma flecha) | 22 | 0 | -- | 2,0 s (arma e dispara) | 1 flecha por tiro | 14 tiles | M5 (Bancada, metal) |
| Espada | 20 | 0 | -- | 0,9 s | -- | 1,5 tiles | M4 a M5, **depois da 0.2** |
| ~~Rifle, Dardo, pistola e arma de fogo~~ | | | | | | | **adiados sem marco (decisão final do dono, 06/11); a exceção do Rifle de mola deixa de existir** |

**Lança de madeira (decisão do dono, 06/11).** Dano **12**, torpor **0** (conta como dano puro na regra de armas), recarga **0,9 s**, Stamina **5** por golpe, alcance **1,8 tiles**, custo **2 graveto + 3 madeira**, receita conhecida, feita à mão. Durabilidade 80 (5.9). **É também a ferramenta de abate e de coleta de carcaça** (5.6). Conta (`durab_sim.py lanca`): **Dodo (vida 24) em 2 golpes, 1,8 s; Listro (36) em 3 golpes, 2,7 s; Utahraptor L20 (126) em 11 golpes, 9,9 s, 5 mordidas de 7,5 dps = 37 de dano e 55 de Stamina**. Contra o Utahraptor ela **ajuda pouco**: a Lança de 18 do desenho antigo fechava em 7 golpes e 5,4 s; esta é **de abate de presa, não de duelo**, e o caminho do Utahraptor continua sendo **nocautear com Bastão** (5 golpes). **Espada** (20, 0,9 s) entra depois, no M4, sem mexer no corte da v0.2.

**Armas à distância (decisão final do dono, 06/11; números nossos [premissa]).** **Sem pólvora, sem arma de fogo, sem Rifle e sem Dardo: adiados sem marco**, e com eles o **fósforo** (5.18); o **sílex volta no M4** como ponta de flecha (5.9c). Ficam **arco, besta e boleadeira**, todos de material primitivo ou mecânico. **Marco recomendado:** **M4** Corda (Saber 1), Arco (Saber 2), Flecha comum (2), **Flecha de sono (2)** e Boleadeira (2); **M5** Besta (Saber 4, Bancada). **Tudo à mão, exceto a Besta** (regra de produção, 5.19).
- **Arco** (3 madeira + 2 corda; durabilidade 120 tiros; Stamina 4 por tiro; 10 tiles): **Flecha comum** (2 graveto + 1 sílex + 1 fibra rendem 4, sílex no lugar da pedra a partir do M4, 5.9c; dano 14, torpor 0). **Flecha de sono (entra, recomendo):** 4 flechas comuns + 1 **Preparado de sono** rendem 4 flechas de sono; dano 1, imediato 15, contínuo 12/s por 5 s, **total 75**; **dá ao Preparado um segundo consumidor** (a mão do jogador só o craftar; quem o consome continua sendo o dino, pela tela dele). Conta (`armas_sim.py arco`): nocaute acordado em **3,3 s (Paquicéfalo), 4,1 (Utahraptor), 4,9 (Parassaurolofo) e 6,0 s (Triceratops L28)** = 3, 4, 5 e 6 flechas = **0,75 a 1,5 Preparados**; contra 2,1 a 5,6 s do Bastão, mas **a 10 tiles e sem exposição**. Custo de coleta [premissa]: flecha de sono 3,8 s por dose (`armas_sim.py custo`).
- **Besta** (5 madeira + 2 barra + 2 corda; dano 22, torpor 0; 2,0 s de recarga; 14 tiles; durabilidade 120): mesma flecha. **Vale pelo dano por tiro e alcance, não pela cadência:** Utahraptor L20 em 6 tiros e 12 s contra 9 flechas e 10,8 s do Arco. Custo em metal: 2 barras. **Cortável sem efeito no resto** (a flecha de sono é do Arco).
- **Boleadeira** (2 corda + 2 pedra; 1 uso por arremesso; 6 tiles): **prende, não nocauteia** (velocidade x0,4 por 5 s, dano 0, torpor 0). Função: é a resposta ao Covarde sem Arco e a fuga de emergência. **Sem Covarde o Arco já resolve (`armas_sim.py fuga`: nocaute em 4,8 s a 160 px), então a Boleadeira é a mais cortável**; só fica se o playtest pedir um item de utilidade barato.
- **Rifle de dardos e Dardo:** **fora**. Saem os números antigos (18 + 9/s por 6 s, pente de 4, recarga 3,5 s, 12 tiles); ficam só como registro no histórico do `racao.md`. Triceratops L28 e acima: ver 5.15.

Todos os valores são [premissa a testar]; o cálculo e as consequências vêm abaixo.

**Fórmula.** Torpor atual: `T(t+dt) = clamp(T + (soma das taxas ativas - queda) x dt, 0, máx)`; o imediato soma no acerto. Queda real do código: **5/s acordado, 1/s dormindo** (`TorporComponent`). Dose da flecha de sono = **75 total** (15 + 12 x 5). Efeito líquido de **uma** dose em dino acordado: `15 + (12-5) x 5 = 50`: sozinha **não** nocauteia ninguém (o menor torpor máximo é 104).

**Acúmulo (recomendo): soma até 3 efeitos ativos; o 4º renova o mais antigo.** O teto é **compartilhado** entre flecha de sono, fruta e preparado e vale por alvo. Motivo: renovar sem somar deixaria a flecha sem efeito acordado; soma sem teto faria dela um nocaute instantâneo. Conta (`armas_sim.py arco`, uma flecha a cada 1,2 s, queda 5/s): Paquicéfalo L12 nocauteia em **3,3 s**, Utahraptor L20 em 4,1 s, Parassaurolofo L20 em 4,9 s, Triceratops L28 em 6,0 s, contra 2,1, 3,5, 4,2 e 5,6 s do Bastão (`armas_sim.py ko`): o Arco é cerca de 1,2 a 1,6 vezes mais lento, mas **a 10 tiles**. Escolha real: Bastão rápido e exposto, Arco seguro e lento, **e gasta flecha** (0,75 a 1,5 Preparados por nocaute).

**Efeitos.** Acordado: o torpor sobe e passa pelas faixas (bocejo, passo x0,85, x0,65 com pausa); **nocauteia depois de alguns segundos** conforme a conta acima. **Dino que foge (Covarde, `armas_sim.py fuga`):** Parassaurolofo L20 (75 px/s), jogador a 80 px, flecha a cada 1,2 s a 160 px de alcance: **faixa 2 em 2,7 s e nocaute em 4,8 s**; o Arco é a **resposta ao Covarde** sem depender de sprint. Soco contra o Utahraptor L20: 21 golpes, 12 s, inviável (o ponto é empurrar para o Bastão).

**Flecha de sono e Eficiência.** A flecha em dino **dormindo** custa **-2 de Eficiência por dose** (sem dano). O torpor contínuo **não conta como ataque** ao dormindo (sem dano, sem custo extra, sem acordar nem atrair carnívoro). Em dino **acordado** não custa Eficiência (ela só começa no nocaute). Flecha comum, besta e espada em dormindo são ataque normal (4 ou 8 de Eficiência fixa + 0,5 x % da vida; `racao.md` 11). **Dormindo, fruta e preparado não gastam Eficiência**: para manter o torpor basta 1 preparado por minuto (`armas_sim.py dormindo`).

**Atributo Dano do jogador:** passa a multiplicar **dano e torpor imediato dos golpes corpo a corpo** (Soco, Bastão); **não** multiplica flecha, besta, fruta nem preparado (valor do item). Com 10 pontos: Bastão 48 em vez de 30 (Utahraptor L20 cai de 6 para 4 golpes).

**Armas de fogo: fora do jogo (decidido, 06/11); sem marco, nem na 1.0.** Não combinam com o tom (sobrevivência com pedra, fibra e Ração) nem com a progressão. **Sem Rifle, sem Dardo, sem pólvora e sem fósforo (o sílex volta como ponta de flecha, 5.9c).** Arco e flecha no **M4**, besta no **M5**, **fora da 0.2**.

**Impacto no M1 e M2.** **M1:** Soco e **Bastão-de-sono no inventário desde o início, sem receita** (30 de torpor, 0,7 s). **M2:** a receita do Bastão (Saber 1) repõe; **nenhum dardo na 0.2**. **Escopo novo:** efeitos de torpor contínuo com teto e save (só no M4, para a flecha de sono; a 0.2 só tem fruta e preparado, 5.5); Arco, flecha, besta e boleadeira no M4 a M5: `WeaponDef` com projétil, Besta, Boleadeira.

### 5.5 Cochilo, preparado de sono e carne podre (decisão do dono, 06/11)

> **Regra atual (07/11) **[provisório, aguarda o dono]**:** Carniça, Preparado de sono e carne podre estão **fora da v0.2**. A fruta **Cochilo** existe (nasce na Mata-baixa, 0,1 kg, pilha 20); o resto do desenho de sono e torpor por fruta é histórico até o dono decidir.

#### Histórico (superado em 07/11)

O texto abaixo é o desenho anterior. **Não o implemente**; vale o resumo acima.

**Nome da fruta (decisão do dono, 06/11): Cochilo.** A comestível segue **Baga**. Os ids de código no `game/` não mudam agora.

**Cochilo.** Nasce em arbusto da **Mata-baixa**; nó com 3 frutas, 4 s por fruta, respawn de 6 a 8 min (como o Tubérculo) [premissa]; 0,1 kg, pilha de 20. **Efeito:** 6 de torpor por segundo durante 5 s (**30 no total**, sem imediato); **não é comida** (não dá fome, não é refeição, não conta para domar, não gera agitação). **Marco M2.**

**Preparado de sono.** Receita na bancada comum: **3 Cochilos + 1 carne podre rendem 3 preparados**, 4 s. Efeito: 12/s durante 5 s (**60 cada**); só se dá a **dino** (o jogador não o usa; sem acidente). Peso 0,15 kg. **Marco M2, cortável.**

**Carne podre (revisto 06/11, dono): vem de duas fontes que coexistem.** (1) **Carcaça velha**: a carcaça não coletada vira carniça aos 10 min (5.6). (2) **Pilha de carne que vence** no inventário, baú, cocho ou alforje (5.9): a pilha vira `ceil(n/4)` de carne podre. Isso **substitui a recomendação anterior (V31: carne que não estraga, nó de Carniça)**: o **nó de Carniça sai**, a carniça é só um estado da carcaça. Carne podre: 0,5 kg, **comível** com pequeno dano (5.10), ingrediente do preparado e **não vence**. Oferta contra demanda: `durab_sim.py oferta` (cada caçada larga carcaças; a demanda é 1 por 3 preparados, 2 por domesticação).

**Conta de custo** (`armas_sim.py custo`): flecha de sono = 3,8 s por dose de 75 (0,051 s/torpor) mais -2 E em dormindo (de 2 a 8 s por E: **0,1 a 0,3 s/torpor a mais**); fruta = 4 s por 30 (**0,133 s/torpor**, 0 E); preparado = (3 x 4 + 4 + 4) / 180 = **0,111 s/torpor**, 0 E. Em dormindo, **o Cochilo e o preparado vencem a flecha** (sem gastar Eficiência). Em dino **acordado** a flecha de sono (M4) é única (alcance 10 tiles); **na 0.2 não há arma de torpor à distância**, só Bastão, fruta e preparado.

**Jogador que come fruta** (`armas_sim.py jogador`; torpor máx. 100, queda 5/s, cap 3 efeitos, 0,5 s entre frutas): 1 fruta = +5 (sem sinal); 2 = pico 33 (faixa 1, bocejo); 3 = 60 (faixa 2, lento); 6 = 80 (faixa 3, pausas); **9 = dorme**. Sono [premissa]: acorda em 30 de torpor, queda de 3/s dormindo = **23 s**; **dano acorda**; aliado acorda segurando a interação 2 s. É **só risco**, sem ferramenta: não dá fome nem benefício. **Co-op:** sem PvP; ninguém força fruta em outro jogador; o aliado acorda quem dormiu. **Recomendo no M2: sinais (faixas 1 a 3) e sem sono**; o sono do jogador (bloqueio de entrada, câmera, acordar) fica para o M4: é a parte cara.

**Dino dormindo: forçar é manual, pela tela de inventário do dino (interagir E), sem tecla de atalho (regra do dono, 06/11).** Abrir a tela do dino e escolher fruta ou preparado; o dino consome de lá. Automático não: tiraria a vigilância, o centro da domesticação. Cada item leva **1,5 s de ação** e há **3 s de espera por dino** entre itens forçados; teto de 3 efeitos ativos. Sem custo de Eficiência. **A queda de 0,3 por segundo dormindo continua**: o dono disse que forçar não custa Eficiência, não que o tempo deixa de pesar. **Não conflita**; se o dono quiser congelar essa queda, o furo reabre (abaixo).

**Reabre o furo de torpor grátis? Não, com limite mínimo.** O furo original era golpe grátis em dormindo (resolvido pelo custo em Eficiência: continua). Manter o torpor de um dormindo exige 60 a 90 torpor por minuto (queda 1,0 a 1,5/s): **2 a 3 frutas por minuto** = 8 a 12 s de coleta e 3 a 4,5 s de ação por minuto, **cerca de 20% do tempo**, sem Eficiência. Mas domar dura no máximo 105 s e **o que fixa a qualidade da Ração é a Eficiência por refeição e por tempo (0,3/s: 100 s custam 30)**, que continua. Efeito medido: Parassaurolofo L20 com Baga (18 refeições, 108 s, janela 137%) precisava de 2 doses de flecha de sono (-4 E); com 2 frutas +4 E, **meio nível a mais**. **Limite mínimo (já no desenho):** manter a queda de 0,3/s e o dreno por refeição; ação de 1,5 s por item; espera de 3 s por dino; teto de 3 efeitos; frutas finitas (respawn). Se um teste mostrar domação sem pressão, o primeiro botão é **aumentar o tempo de ação** (2,5 s).

**V6 revisto:** a flecha de sono (M4) deixa de ser a "manutenção barata" do dormindo; é a **ferramenta de dino acordado**; fruta e preparado são a manutenção.

**Atalho (1 a 9), evitar erro:** a tecla do Cochilo **come no jogador** (segundo aperto em 1,5 s: "comer Cochilo?"); a do preparado **não faz nada** (é para o dino, pela tela). Ícone roxo distinto da baga; a baga e a carne nunca dormem ninguém.

**Escopo:** nó e item da fruta; forçar o dino pela tela dele (já implementada; só validação e o teto de 3 efeitos); sinais de torpor no jogador com o mesmo componente; Carniça e item; receita do preparado; sono do jogador M4. **Menor recorte da 0.2:** fruta forçada no dino e sinais no jogador; **preparado e Carniça cortáveis**; sem sono do jogador.

### 5.6 Carcaça e sacolinha (decisão do dono, 06/11)

Animal morto deixa **carcaça** coletável; os itens podem virar **sacolinha** no chão. Simulação: `carcaca_sim.py`.

**Rendimento** = `base x (1 + 0,03(L-10))` (piso 0,7, o mesmo fator do Peso), arredondado [premissa]. Tempo **1,5 s por carne e 3 s por couro com Lança ou Espada; à mão, 3 s e 6 s e 1 de dano ao personagem por item** (Soco em dino, opção B, decisão do dono 06/11, 5.9b), Stamina **3/s**, **1 de durabilidade da arma por carcaça** (só com arma; a mão não gasta nada, só vida, e o piso de 10 de vida vale: o Soco não mata); peso 0,5 kg a carne e 0,4 kg o couro; carne dá **25 de fome** (baga 10) [premissa, o código ainda não define].

| Espécie (base: carne / couro) | Nível típico | Carne | Couro | Tempo | Peso | Fome da carne |
|---|---|---|---|---|---|---|
| Paquicéfalo (4 / 1) | L12 | 4 | 1 | 9 s | 2,4 kg | 100 (17 min) |
| Utahraptor (5 / 2) | L20 | 6 | 3 | 18 s | 4,2 kg | 150 (25 min) |
| *(fora da v0.2)*  Parassaurolofo (10 / 3) | L20 | 13 | 4 | 31,5 s | 8,1 kg | 325 (54 min) |
| Triceratops (14 / 5) | L28 | 22 | 8 | 57 s | 14,2 kg (28% do Peso) | 550 (92 min) |
| Artrópode gigante (pós-MVP, cavernas) | -- | **quitina** no lugar do couro | | | | |

**À mão (B)** [calculado: o dobro do tempo da tabela e 1 de dano por item]: Paquicéfalo 18 s e 5 de dano; Utahraptor 36 s e 9; Parassaurolofo 63 s e 17; **Triceratops 114 s e 30**. Na prática a mão serve às presas pequenas e a quem ficou sem Lança; carcaça grande pede Lança ou Espada (a coleta parcial vale). Triceratops L42 (domado que morreu): 27 e 10, 70 s. Coleta **parcial** permitida (a barra pode ser interrompida e retomada); interromper por mover mais de 3 tiles ou por dano.

**Quanto tempo ficam [premissa]:** carcaça **fresca 10 min**; de 10 a 20 min vira **carniça** (só carne podre: `ceil(carne/4)`; Triceratops L28 dá 6) e some aos 20 min; **sacolinha 10 min**; no máximo **8 carcaças e 20 sacolinhas** no mundo (a mais antiga some). **M4b:** a bolsinha de Largar (5.1b) usa a mesma entidade, com 5 min. Save: menos de 2 KB. Isso dá a **carne podre** (5.5) sem nenhuma regra de estragar no inventário e permite cortar a Carniça-nó se o teste mostrar oferta suficiente.

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

**Couro:** sem sumidouro na 0.2 (**o Bastão reforçado foi cortado, 06/11**): o couro cai como dado e só tem uso no M4 (peças de couro e Arco). Quitina só com as cavernas.

**Marco:** M2. Carcaça e coleta com barra parcial; sacolinha (entidade, pegar, excesso, morte do dino); save e validação; interface (barra, lista de itens), sem o Bastão reforçado. **Menor recorte da 0.2:** só carne (couro como dado, sem uso), coleta de uma vez, sacolinha só para excesso e dino morto, sem carniça envelhecida.

### 5.7 HUD do jogador (decisão do dono, 06/11)

> **Atualizado em 08/11 (dono): a barra de Stamina entra no HUD**, abaixo da Fome (tom diferente quando o fôlego está curto; cinza esgotada). O som e o ofegar seguem. A **durabilidade das armas** aparece como barra fina na base do ícone no inventário, na vaga e no atalho (verde, amarela, vermelha). Há também o **log do sistema** no canto de baixo à esquerda (tecla L abre o histórico).

**Visíveis:** barra de **vida**, barra de **fome**, barra de **XP** e a **barra de atalhos 1 a 9** (5.2). **Sem sede** por agora, **sem barra de stamina**, sem temperatura. M1: vida, fome e atalhos; M2: XP e aviso de ponto.

**Stamina por comportamento, sem barra.** O atributo existe e limita a corrida (dreno 25/s, regen 15/s, retoma com 20; sprint de 4 s, mais 0,24 s por ponto). Sinal em duas etapas [premissa]: (1) abaixo de **25%** (cerca de 1 s antes de zerar, a 25/s) começa um **ofegar** de som crescente; (2) ao **zerar**, o personagem **ofega e para de correr**, e golpes e coleta ficam mais lentos (5.8): anda a 70 até recuperar 20, o que leva **1,3 s** (20/15) [calculado], com som de fôlego e uma pequena nuvem de suor. Sem janela nem texto. Em co-op o estado "ofegante" é um bit replicado, para os outros jogadores ouvirem. O jogador aprende a duração do sprint pelo uso; a tela de atributos mostra "sprint X s" ao distribuir pontos. Golpes e coleta gastam fôlego (5.8) e o mesmo sinal vale.

**Nível e aviso de ponto, o mínimo:** (1) a **barra de XP** fica fina, acima dos atalhos, com **"Nv N"** no começo; (2) um **único selo** ao lado do nível aparece **só quando há algo a gastar** (ponto de atributo livre, ou Saber suficiente para a receita aprendível mais barata) e pulsa devagar, **sem janela nem interrupção**; (3) **uma linha de aviso de 3 s** ao subir de nível ("Nível 7: +1 ponto, +1 Saber") e um som curto. **Tecla P** abre a tela do **Personagem**, com abas Atributos e Receitas (e depois Equipamento). São 4 elementos fixos (vida, fome, XP, atalhos) mais o selo e a linha de aviso.

**Durabilidade (revisto 06/11, dono): existe, fora da HUD.** Ferramentas, armas e armaduras têm durabilidade individual (5.9). O jogador percebe por **tooltip no inventário, aviso ao ficar baixa e som de quebra**; **nenhuma barra na HUD**. Estimativa de percepção em 5.9.

**Escopo:** barra de XP, nível e selo; linha de aviso; estado ofegante com som e partícula (a barra de stamina, se existir, sai de graça). **`YATORA`:** moldura das 3 barras, ícone do selo, partícula de suor, sons de ofegar e de subir de nível.

### 5.8 Stamina em golpes e coleta (decisão do dono, 06/11)

Golpes e coleta também gastam Stamina. Simulação: `stamina_sim.py`.

**Custos [premissa]:** golpe: **Soco 3**, **Bastão 6**, **tiro de arco 4** (5, 8,6 e 4 por segundo; 33, 17 e 25 golpes até esgotar). Coleta, por segundo de ação: **mãos em madeira 4/s (pedra de nó só com Picareta, 5.9b)**, **machado e picareta 3/s**, **baga, fibra, fruta e carcaça 2/s** (a mão em um nó de madeira: 8 s x 4 = 32 por nó, 3 nós seguidos; o machado: 5,2 s x 3 = 15,6). Construir e craftar não gastam. **Regeneração:** 15/s **só depois de 0,5 s sem agir** (sem sprint, golpe nem coleta); sprint 25/s e retomada em 20, como no código.

**Sem Stamina, nada bloqueia (recomendo e adoto):** o golpe sai com **cooldown x1,5 e efeito x0,75**; a coleta leva **x1,5 de tempo**; só o sprint fica bloqueado até recuperar 20 (1,3 s parado). Motivo: bloquear a coleta é espera vazia e bloquear o golpe diante de um carnívoro é espiral de morte. Coleta contínua exaurida roda a 67% da velocidade, contra 79% de quem pausa (15/19): a diferença é pequena, então **a coleta nunca espera, só desacelera**.

**Sinal sem barra (5.7):** o mesmo ofegar cobre tudo: abaixo de 25% (4 golpes ou 6 s de coleta antes de zerar) começa o som crescente; ao zerar, o personagem **ofega** e a **animação de golpe e de coleta fica visivelmente mais lenta**, o que comunica a penalidade sem janela. Sim, o ofego basta.

**Reveja (conta em `stamina_sim.py luta`):**
- **Nocaute do Utahraptor L20 com o Bastão:** 6 golpes = 36 de Stamina, 3,5 s, 2 mordidas (22,4) quando fresco. **Depois de correr 4 s** (stamina 0) o personagem bate exaurido: **9 golpes, 8,4 s, 5 mordidas = 56 de dano**, o dobro. Triceratops L28 pós-sprint: 13 golpes, 12,6 s, 172 de dano (morre).
- **Corrida:** igual (25/s, 4 s); agora **correr e depois lutar custa a luta**.
- **Golpe que provoca:** custa 6 e sai mesmo exaurido (só mais lento); provocar não fica bloqueado.
- **Carcaça de 57 s:** 2/s = 114, esgota aos 50 s e leva **60,5 s**; com 3 pontos (118) não esgota. Irrelevante.

**O ponto em Stamina vale a pena? Sim, por um limiar claro.** Sprint de 4 s (100) mais os 6 golpes do Utahraptor (36) pedem **136: 6 pontos** deixam correr e nocautear sem esgotar (22 de dano contra 56); o Triceratops (9 golpes, 54) pede **154: 9 pontos** (69 contra 172 de dano, pós-sprint). Também dá sprint de 5,4 s com 6 pontos e 6,4 s com 10, e 26,7 golpes seguidos com 10. Contra 6 pontos de Vida (+36 de vida, 3 mordidas): **a Stamina vence quando o jogador corre antes de lutar**, a Vida quando não. Escolha real. Na coleta o ponto vale pouco (~3 s por carcaça grande), aceitável.

**Muda para o `SORA`:** `WeaponDef.stamina_cost`; `ToolDef`/coleta com `stamina_per_second`; estado `exhausted` aplicando x1,5 no cooldown e x0,75 no efeito do golpe e x1,5 no tempo da coleta, **no servidor**; regeneração com atraso de 0,5 s; sinal de ofego abaixo de 25% e ao zerar (bit replicado); o ataque atual do `Player` hoje **não gasta Stamina**; sem barra de stamina; teste headless dos custos e do limiar de 6 pontos.

### 5.9 Durabilidade e validade (decisões do dono, 06/11)

> **Regra atual (07/11):** armas, ferramentas e armaduras têm **durabilidade individual e não empilham** (a tabela de Durabilidade abaixo vale). A **validade** da comida **sai da v0.2** **[provisório, aguarda o dono]**: comida não vence, sem juntar pilhas por `expira_em`. Pilha de carne pode ir a 20 [premissa]. O modelo `{id, iid, durab, durab_max}` para itens individuais segue; o de pilha com validade não.

Simulação: `durab_sim.py`. **Dois sistemas, um modelo de inventário.** Armas, ferramentas e armaduras têm **durabilidade individual e não empilham**. Comida empilhável tem **validade única por pilha**.

**Durabilidade [premissa; tudo a testar]:**

| Item | Durabilidade | Cai | Rendimento |
|---|---|---|---|
| Lança de madeira | 80 | 1 por golpe, 1 por carcaça coletada | dano 12 |
| Bastão-de-sono | 120 | 1 por golpe | KO de Paquicéfalo em 4 golpes = 30 KOs |
| Machado de pedra | 150 | 1 por segundo de coleta | 0,75 madeira/s (mão 0,375): 112 madeira por durabilidade |
| Picareta de pedra | 120 | 1 por segundo de coleta | 0,80 pedra/s (sem Picareta a mão **não coleta** nó de pedra, 5.9b): 96 pedra |
| Machado e Picareta de ferro (M5) | 300 | idem | 1,31 madeira/s e 1,40 pedra/s: 394 e 420 por durabilidade |
| Espada de ferro (M4) | 250 | 1 por golpe | dano 20 |
| Peças de roupa (cada uma): fibra (depois do playtest), couro (M4), metal (M5) | 100 / 150 / 300 **por peça** | 1 por golpe sofrido em **cada peça equipada** (mesmo se o dano caiu a 1) | redução da peça (5.11): soma 10 / 25 / 40% |

**Regra de afinidade por ferramenta: M4, não vale na 0.2 (5.9c). Os rendimentos desta tabela são os da 0.2.**

**Pedra versus ferro:** 1,75x mais rápido e 2x a 2,5x mais durável = **3,5x a 4,4x de material por ferramenta**. **Mão nunca gasta, mas é metade da velocidade e gasta 4 de Stamina/s** (5.8): o jogador **nunca fica travado**.

**Em zero: a peça fica "quebrada", inútil, **sem desaparecer**, até reparar** (não some: a perda seria punição sem decisão). **Reparo:** na **Bancada**, custo **`ceil(50% do material da receita x fração que falta)`**, 1 s por 10% da barra. Lança 100% gasta: 1 graveto + 2 madeira, 10 s; Machado de pedra: 2 madeira + 1 pedra + 1 fibra. **Não reduz a durabilidade máxima** (recomendo: a redução de máximo cria um ralo de descarte que não pede decisão nova).

**Primeira hora (`durab_sim.py hora`):** 20 Dodos + 1 luta de Utahraptor = 71 de 80 na Lança (0,9 reparo); 86 madeira = 115 s de 150 no Machado (0,8); 40 pedra = 50 s de 120 na Picareta (0,4). **Total ~2,1 reparos, 21 s em 3600 (0,6%), ~6 materiais.** É ruído, não punição. **Antes da Bancada (L2, ~3 min) nada gasta o suficiente para quebrar.** Impacto no **Saber**: nenhum (reparo é material, não Saber). No **Peso**: item individual pesa o mesmo; a Lança 1,0 kg, o Machado 2,0, a Picareta 2,5 [premissa], 5,5 kg dos 50 do jogador (11%).

**Percepção, o mínimo:** (1) **tooltip** no inventário com barra e "x/y"; (2) **aviso a 20%**: texto flutuante curto e som; (3) **som e texto ao zerar** ("quebrou"). **Fora da HUD**. Opcional se faltar: ícone da barra de atalhos esmaecido abaixo de 20%.

#### Histórico (superado em 07/11)

O texto abaixo é o desenho anterior. **Não o implemente**; vale o resumo acima.

**Validade da comida (`durab_sim.py validade`) [premissa]:**

| Item | Validade | Ao zerar |
|---|---|---|
| Carne crua | 30 min | vira **carne podre** (`ceil(n/4)`) |
| Carne assada (Fogueira, 2 s por carne, 1 madeira por 4) | 90 min, +10 de fome | idem |
| Baga | 45 min | **some** |
| Cochilo | 30 min | **some** |
| Preparado de sono | 45 min | **some** |
| Carne podre, Ração C/B/A, couro | não vencem | -- |

**Regra mais simples.** Cada pilha guarda **`expira_em`** (hora do servidor), sem tique por quadro. **Juntar:** só se juntam pilhas cuja diferença de `expira_em` for **até 2 min**, e a pilha usa a **mais velha** (perde no máximo 2 min de 30, 6,7%). **Dividir:** as duas metades herdam a mesma `expira_em`. **Baú, cocho e alforje:** **mesma regra e corre igual** (não há geladeira). **Carcaça coletada** começa com a validade cheia. **Servidor desligado** não conta (relógio do mundo).

**Domesticação sem surpresa:** (a) a carne do Utahraptor é caçada em 3 a 6,5 min (5.14), **margem de 4,6x a 12x** com 30 min; (b) **aviso a 25%** (7,5 min na carne crua); (c) o **painel de alimentar mostra "vence em N min"**; (d) a **Ração não vence**, então o estoque de Ração C/B/A é seguro; (e) carne vencida vira carne podre e o preparado de sono **ganha** matéria-prima.

**Modelo de inventário (para o `SORA`):** hoje `{id, count}` e a barra guarda tipo. Passa a **`{id, count, expira_em?}`** para empilháveis e **`{id, iid, durab, durab_max}`** (count 1, não empilha) para equipamento; a **barra de atalhos guarda o slot (ou `iid`)**, não o tipo; **slot de "item na mão"** e, no M4, 2 de armadura; save com versão nova; reparo, uso e validade **validados no servidor**. **Menor recorte:** **M1** o modelo novo com durabilidade só da Lança, Machado, Picareta e Bastão; **M2** validade, carne podre, assar, reparo na Bancada e aviso; M4 armaduras. **Escopo:** modelo de inventário e hotbar por slot; durabilidade, quebra e reparo; tooltip, aviso e sons; validade, conversão em carne podre, aviso no painel; Fogueira (assar). Sem isso a Lança de madeira não pode ter durabilidade.


### 5.9b Soco, mãos e pedras avulsas (decisão do dono, 06/11; vale para o MVP)

**Regras do dono:** (1) **Soco em árvore coleta recursos** e causa **1 de dano ao personagem**; (2) **Soco em pedra causa 1 de dano e não coleta nada**; (3) **pedras avulsas** ficam no chão, coletadas à mão sem ferramenta: são a base das primeiras ferramentas de pedra (Machado 2 pedra, Picareta 3).

- **Atualizado em 08/11 (dono): golpes, não tempo.** Árvore e rocha pedem golpes (árvore 6 à mão e 3 com Machado; rocha 4 com Picareta; veio 6; 1 de vida na conclusão sem ferramenta; progresso zera em 10 s sem golpe) e o recurso cai no chão em pilhas de até 3, recolhido por E ou por cima (some em 300 s). Os números abaixo de 3 madeira em 8 s ficam como histórico.
- **Soco na árvore [proposta de números]:** 3 madeira em 8 s (0,375/s, metade do Machado), Stamina 4/s, **1 de dano por colheita completa** (por golpe seriam ~13 por árvore). Arbusto à mão: coleta sem dano.
- **Soco na pedra (nó):** 1 de dano por toque (tecla E), nada coletado, mensagem "só a Picareta quebra pedra". O nó ganha `ferramenta_minima`. **Isso revoga "mão em pedra 0,40/s" da tabela acima.**
- **Pedra avulsa (`loose_stone`):** 1 pedra em 1 s, sem dano, sem ferramenta; volta em 300 s (núcleo) ou 600 s (trilha). **24 na ilha: 10 no núcleo e 14 na trilha até a Pedreira** (`mapa-ilha.md` 8). Sem softlock: o primeiro Machado e a primeira Picareta pedem 5 pedras avulsas, 6 madeira (2 árvores no Soco) e 2 fibra (1 arbusto rende 2); gastá-las antes em Fogueira ou Bancada só atrasa até 5 min.
- **O Soco não mata o personagem:** o dano a si mesmo para em 10 de vida; abaixo disso o Soco age sem dano. Coleta segue por **E** (barra de coleta, `request_gather`), não por golpe.
- **Soco em dino (decisão do dono, 06/11: opção B fechada).** Dino **vivo** leva dano 1 e torpor 10 (CRI-01) e o **personagem leva 1 de dano** por Soco, com o piso de 10 de vida (o Soco não mata). **A carcaça se coleta à mão**: 3 s por carne e 6 s por couro (o dobro de Lança ou Espada, 5.6) e **1 de dano ao personagem por item**, na mesma barra de coleta. Efeito: o Bastão (30 de torpor, sem custo de vida) vale mais que o Soco (10 de torpor, 1 de vida por golpe), e quem perdeu a Lança ainda come, devagar e sangrando. **Escopo: entra no SOB-06** (`mapa-ilha.md` 9).
- **Escopo:** `ferramenta_minima`, dano do Soco com piso, mensagem e pedra avulsa no MUN-02 (junto do arbusto único); o `YATORA` desenha a pedra avulsa.

### 5.9c Cada ferramenta coleta diferente (decisão do dono, 06/11; **M4, fora da 0.2**)

**Regra do dono.** As duas ferramentas coletam **todos** os recursos, mas cada uma rende mais o que está na sua lista: **Picareta: carne, palha, sílex e metal. Machado: couro, quitina, madeira e pedra.** **"Rende mais" = mais recurso por colheita; a colheita leva o mesmo tempo** (o tempo é do nó, não da ferramenta). Fora da lista rende só a quantidade base. **O Soco não muda**: em pedra de nó não coleta nada (5.9b). Lança e Espada seguem como armas de corte de carcaça, fora desta regra. A regra vem **depois do MVP**; a 0.2 fica como está (5.9b e 5.9). **A pedra fica no Machado (confirmado pelo dono).**

**Qualidade da ferramenta: o GDD já tem um tier, e uso esse (sem segundo sistema).** A tabela de 5.9 já separa **pedra** (Machado 150, Picareta 120 de durabilidade) de **ferro** (M5, Forja; 300 de durabilidade e 1,31 madeira/s e 1,40 pedra/s contra 0,75 e 0,80). A razão é 1,75x na coleta (1,31/0,75 = 1,747; 1,40/0,80 = 1,75) e 2x a 2,5x na durabilidade. Não existe nível de qualidade além disso (as "qualidades" do GDD são da Ração). **O Machado e a Picareta de pedra da v0.2 são a qualidade base (1,0)**: a v0.2 não muda.

**Como a qualidade e a afinidade se somam: multiplicam.** `quantidade = arredondar(base do nó x mult_afinidade x mult_tier)`, arredondando .5 para cima; o tempo é o do nó; a durabilidade máxima é a do tier e cada colheita gasta 1 por segundo dela. Dados [proposta], `ferramentas.tres`:

| Chave | Valor | Conta |
|---|---|---|
| `mult_dentro` / `mult_fora` | **2,0 / 1,0** | é o ganho por segundo que as tabelas da 5.9 já dão (Machado 0,75 madeira/s = 2 x 0,375), agora em quantidade: o ritmo por segundo de uma árvore com Machado fica igual ao de hoje |
| `mult_dentro_carcaca` | **1,5** | carcaça é finita e não volta; o bônus é menor (use 2,0 se o dono quiser a mesma regra) |
| `tier.pedra` | qtd x1,0; durabilidade 150 (Machado) / 120 (Picareta) | qualidade base = v0.2 |
| `tier.ferro` (M5) | qtd **x1,75**; durabilidade 300 | 1,31/0,75 e 1,40/0,80 da 5.9; o tier **vale também na carcaça** (decisão do dono, 06/11; sem a chave `tier_na_carcaca`) |
| `afinidade.machado` | couro, quitina, madeira, pedra | |
| `afinidade.picareta` | carne, palha, silex, metal (minério) | |
| `afinidade.lanca`, `afinidade.espada` | carne, couro; **por tempo**, como na 5.6 | não entram na regra de quantidade |
| `afinidade.soco` | vazia (`mult_fora` 1,0) | |
| `exige` (nó de pedra) | `coleta` (qualquer Machado ou Picareta) | troca `ferramenta_minima` = Picareta da 5.9b; "sem Picareta a mão não coleta nó de pedra" passa a "sem Machado nem Picareta" (só no M4) |

**Fontes e colheita, em dado** (`nos.tres`; quantidade **base** = a do Soco; tempo único por colheita; palha, sílex, minério e quitina só no M4 ou depois):

| Nó | Tempo | Base (item: quantidade) | Volta em | Marco |
|---|---|---|---|---|
| **Árvore coletável** (`tree`) | 8 s | madeira 3; **palha 2** | 480 s | madeira 0.2; **palha M4** |
| **Pedra comum** (`rock`) | 10 s | pedra 4; **sílex 1** | 600 s | pedra 0.2; **sílex M4** |
| **Pedra de minério** (`iron_seam`) | 14 s | **minério 2**; pedra 1; sílex 1 | 900 s | **M4** |
| **Inseto gigante** (carcaça, com a carne) | por item, 3 s | carne como na 5.6; **quitina no lugar do couro**, 3 por carcaça [premissa] | 10 min | **cavernas e insetos, pós-1.0 (marco atual)** |

**Efeito por colheita (mesmo tempo, quantidades com a afinidade; tier de pedra)** [calculado]:

| Colheita | Machado | Picareta | Soco |
|---|---|---|---|
| Árvore, 8 s | **6 madeira + 2 palha** | 3 madeira + **4 palha** | 3 madeira + 2 palha (1 de dano) |
| Pedra comum, 10 s | **8 pedra** + 1 sílex | 4 pedra + **2 sílex** | não coleta |
| Pedra de minério, 14 s | 2 minério + **2 pedra** + 1 sílex | **4 minério** + 1 pedra + **2 sílex** | não coleta |

Com tier de ferro (M5), tudo x1,75 e arredondado: Picareta no minério 2 x 2 x 1,75 = **7 por colheita**.

**O que dependia de tempo, revisto.**
- **Durabilidade** (1 por segundo de coleta, sem mudar): Machado de pedra na árvore, 150 / 8 s = 18,75 colheitas x 6 = **112 madeira por durabilidade cheia, igual à 5.9**; na pedra, 15 colheitas x 8 = **120 pedra**. Picareta de pedra no minério, 120 / 14 = 8,6 colheitas x 4 = **34 minério** (antes 21 com a regra por tempo); na pedra comum (fora da lista), 12 colheitas x 4 = **48 pedra**, como na conta antiga.
- **Picaretas para as 18 barras (5.17: 36 minério):** 9 colheitas de 4 = 126 s, **1,05 Picareta de pedra**, ou seja, uma Picareta e **um reparo** (50% do material, na Bancada) no M4; com o Machado (fora da lista, 2 por colheita) seriam 18 colheitas e 1,7 Machados; com Picareta de ferro (M5), 36/7 = 5,1 colheitas e **0,24 de uma Picareta** (300 / 14 = 21 colheitas = 150 minério por durabilidade). Dos 28 filões, **9 bastam** (112 minério por passada com a Picareta).
- **Nó que some (4.1):** o respawn só vale com o lugar livre; as taxas por segundo e os tempos de volta desta tabela não mudam. Os 'primeiros 5 minutos' abaixo seguem válidos (pedras avulsas continuam a base das primeiras ferramentas; o nó de pedra segue exigindo Picareta). Número da fonte por região: V80.
- **Primeiros 5 minutos: sem softlock, nas mesmas taxas por segundo de antes.** Soco: 3 madeira em 8 s; pedras avulsas à mão. O Machado (3 madeira + 2 pedra avulsa + 1 fibra) abre o nó de pedra com **8 pedra em 10 s (0,8/s)**; a Picareta (3 pedra) deixa de ser o gargalo e o mínimo cai de 5 para 2 pedras avulsas. Gastar as avulsas antes de qualquer ferramenta continua custando até 5 min de respawn. A primeira hora ainda gasta 86 madeira = 115 s e 40 pedra = 50 s, 165 s de 150 de durabilidade do Machado: 1 reparo a mais (~10 s); quem quiser poupar o Machado usa a Picareta, que dá 4 pedra por colheita em vez de 8.
- **Carcaça da opção B (5.6):** o tempo continua **por item e por arma**, não por ferramenta: mão 3 s carne / 6 s couro com 1 de dano por item; Lança e Espada 1,5 / 3 s; **Picareta e Machado, como a mão no tempo (3 / 6 s) e sem dano**, mas com **quantidade = `base x 1,5 (afinidade) x mult_tier`** no que está na lista (Picareta na carne, Machado no couro), com o arredondamento já definido na 5.9c (.5 para cima); a **qualidade da ferramenta também vale na carcaça (decisão do dono, 06/11)**: **pedra 1,0; ferro 1,75** (M5). O **1,5 é número nosso [premissa]**, sem fonte externa; o dono perguntou de onde veio e ele fica assim até resposta. Os exemplos abaixo são de pedra (mult_tier 1,0); com ferro, a Picareta na carne do Utahraptor L20 renderia 6 x 1,5 x 1,75 = 15,75, **16 carne**. Exemplo, Utahraptor L20 (6 carne, 3 couro): Lança 18 s, 6 carne e 3 couro; Picareta 36 s, **9 carne** e 3 couro; mão 36 s, 6 e 3, **9 de dano**. Triceratops L28 (22 e 8): Lança 57 s; Picareta 114 s e **33 carne**; mão 114 s e 30 de dano. Então a Lança é o caminho rápido, a Picareta e o Machado o caminho que rende mais (e gasta 1 de durabilidade por carcaça, como a Lança), e a mão o último recurso.

**Sílex volta ao jogo (decisão do dono): marco M4, junto do Arco.** Consumidor: **Flecha comum passa a ser 2 graveto + 1 sílex + 1 fibra (rende 4)**, o sílex no lugar da pedra (`receitas.md`). **Fósforo e pólvora seguem sem marco.** Cem flechas gastam 25 sílex; as 159 pedras comuns e os 28 filões dão ~190 por passada com o Soco e mais com a Picareta, então sobra (barato de propósito). **Palha:** 264 árvores dão 528 por passada (1.056 com a Picareta); o gasto por peça é o da 8.1 e se calibra no M4 (2 por colheita é premissa).

**A árvore coletável da v0.2 precisa mudar? Não.** `tree.tres` fica como está (`item_id = wood`, 3, 8 s, 480 s): na 0.2 só rende madeira. No M4, `ResourceNodeDef` ganha `drops` (lista de item e quantidade base) e, se vazio, usa `item_id` + `yield_amount` como hoje, então **nenhum `.tres` da 0.2 é migrado**. Na 0.2 a ferramenta de pedra segue acelerando a coleta como hoje; no M4 passa a render quantidade, **com o mesmo ritmo por segundo** (a conta acima). No M4 entram lista de colheitas, afinidade, tier e interface, fora da 0.2.

**O que entraria se a afinidade viesse já na 0.2**: quantidade por afinidade e tier no `request_gather` e na carcaça; `exige: coleta` e mensagem; tooltip "rende mais em ..."; testes; rebalancear 5.9 e `durab_sim.py` (só `SORA`, nada de `YATORA`). Não recomendo: só 4 dos 8 itens existem na 0.2.

**Existência no catálogo** (`catalogo.md`): palha, quitina e ferro estão na lista; **palha é item novo, não é a fibra** (fibra continua do arbusto único); o sílex saiu da lista "sem marco". Nada usa número ou tabela de outro jogo: 2,0, 1,0, 1,5 e 1,75 saem das tabelas do próprio GDD ou são nossos.

**Degraus de ferramenta (decisão do dono, 06/11): mão (Soco), pedra e ferro.** A ideia de um nível de madeira foi removida. A Lança de madeira (5.4) não tem relação e continua.

### 5.9d Tamanho de pilha por item (regra do dono, 06/11; só dado: `max_stack` de cada `ItemDef`, sem sistema novo)

Cada item tem a sua pilha; o que acumula bem é leve, o que pesa acumula pouco, e a pilha do que pesa é menor (validade fora da v0.2). **Regra para escolher [proposta]:** pilha = alvo de peso por pilha dividido pelo peso do item, arredondada para 5 e entre 5 e 40; **alvo 20 a 30 kg** para material bruto (madeira, pedra, minério, barra), **2 a 6 kg** para leve e vegetal, **5 kg** para o que vence (carne, carne podre). Os seis valores que o código já tem (`Items.gd`) ficam: **v0.2 sem mudança de código**.

| Item (v0.2) | Peso (kg, 5.1) | Pilha | kg por pilha cheia | Fonte do valor |
|---|---|---|---|---|
| Baga | 0,1 | **20** | 2 | código |
| Samambaia | 0,1 | **30** | 3 | código |
| Carne | 0,5 | **20** [premissa; era 10 por causa da validade] | 10 | provisório, aguarda o dono; sem validade |
| Madeira | 1,0 | **20** | 20 | código |
| Pedra | 1,5 | **20** | 30 | código |
| Fibra | 0,05 | **40** | 2 | código |
| Couro | 0,4 | 20 | 8 | novo (dado) |
| Cochilo | 0,1 | 20 | 2 | 5.5 |
| ~~Preparado de sono~~ | -- | -- | -- | fora da v0.2 |
| Ração (A, B, C) | 0,2 | 20 | 4 | novo |
| Tubérculo | 0,3 | 20 | 6 | novo |
| Sal-de-veio | 0,5 | 20 | 10 | novo |
| Graveto | 0,05 | 40 | 2 | novo |
| Lança, Machado, Picareta, Bastão, armadura | -- | **1** (individual, com durabilidade) | -- | 5.9 |

**Itens do M4 em diante, pela regra** [proposta, em dado]: **palha** 0,1 kg, pilha 40 (4 kg); **sílex** 0,3 kg, pilha 30 (9 kg); **quitina** 0,3 kg, pilha 20 (6 kg); **minério de ferro** 2,0 kg, pilha 10 (20 kg); **Barra de ferro** 1,5 kg, pilha 10 (15 kg); **carvão** 0,2 kg, pilha 20 (4 kg); **flecha comum** 0,05 kg, pilha 40; **flecha de sono** 0,05 kg, pilha 20 (vale mais, vence menos o espaço). Pesos novos são premissa. A Forja (5.17) guarda minério até 20 e barra até 10 em vagas próprias, então a pilha do inventário não a limita.

> **Histórico (superado em 07/11):** a conta de slots abaixo (21 e 26 de 40) é do desenho antigo. Com 4 slots e bolsa de até 12 (5.21), ver `shiro.md` 4.7. **Muda alguma conta?** [calculado, `slots_sim.py demanda` agora com pilha por item] **Inventário:** v0.2 meio 21 e pico 26 slots, **iguais**; 1.0 passa de 31 para 32 (minério de 20 vira 2 pilhas de 10). **Peso:** nenhuma, ele é por unidade (5.1). **Domesticação:** nenhuma; fome, Ração, Eficiência e bocado contam por unidade, não por pilha. **Validade:** a regra por pilha da 5.9 fica mais branda com a pilha de 10 da carne (juntar pilhas só dentro de 2 min). **Corrigido de passagem:** a 5.17 dizia "madeira até 30 (15 kg)", mas 1,0 kg por madeira dá 30 kg; a Forja não passa a pesar (o Peso dela é o do item).

### 5.10 Comida e fome do jogador (decisão do dono, 06/11)

> **Atualizado em 08/11 (dono):** a queda depende do estado: **parado 0,04/s, andando 0,06/s, correndo 0,15/s**, mais **0,3 por golpe de coleta** e **0,4 por golpe de ataque** [premissa]. **Comer sobe aos poucos:** 4 pontos/s a partir de uma fila (`fome_pendente`); baga +10, carne crua +30 (samambaia não é comida do jogador); comer de novo soma na fila sem acelerar; não se come se fome + fila já enche; morrer zera a fila. Ver `corte-v02/montaria-vinculo-trabalho.md`, seção 9.

> **Atualizado em 07/11 (decidido: fome leve, torpor como ameaça).** A fome existe, mas o jogo não gira em torno dela: **queda 0,1/s** **[provisório, aguarda o dono]** **zerada, não causa dano e não mata**; sobe o torpor do jogador até ele **desmaiar**, e o **jogador caído entra na lista de alvos dos carnívoros** (como o dormindo, 6.7) e **pode ser devorado**; a morte vem de dino, nunca da fome. Duração do desmaio: 8 s ou 20 s, o playtest define **[provisório, aguarda o dono]**. Os valores de 0,2/s, de dano por desmaio e do "9º desmaio" abaixo estão **superados**. **Carne podre, carniça e validade ficam fora da v0.2** **[provisório, aguarda o dono]** (a linha "Carne podre" da tabela não vale).

Simulação: `fome_sim.py fome|ciclo`. **Substitui o dano de fome do `HungerComponent`** (queda 0,5/s, em zero 5 de dano a cada 2 s = morte em 40 s [código real]).

**Regras do dono:** carne crua reduz fome sem curar; estragada dá pequeno dano; cozida reduz mais fome e regenera um pouco de vida; acima de 70% de fome (saciedade) regenera pouca vida; com fome 0 o torpor do jogador sobe; em 100% o jogador fica inconsciente por alguns segundos e leva dano até morrer ou comer.

**Valores [premissa; a barra é de saciedade: 100 cheio]:**

| Item | Fome | Vida | Conta |
|---|---|---|---|
| Carne crua | +25 | 0 | 125 s de fome |
| **Carne cozida** (Fogueira) | **+35** | **+10 em 10 s (1/s, renova)** | 175 s de fome |
| Baga | +10 | 0 | 50 s |
| ~~Carne podre (estragada)~~ (fora da v0.2)  | +5 | **-6, não mata (deixa 1)** | 25 s |
| Saciedade (> 70) | -- | **+0,5/s fora de combate (5 s sem dano)** | vida 100 em 200 s |

**Queda da fome: 0,1/s (atualizado em 07/11).** Cheio dura 1.000 s; a cozida (+35) rende 350 s e a baga (+10) rende 100 s; 360 pontos de fome por hora são cerca de 10 cozidas ou 36 bagas [calculado].

**Cozimento:** na Fogueira, 2 s por carne, 1 madeira para 4 carnes (conta de 5.9); carne cozida vence em **90 min** (crua 30). **Cozida vale para o jogador e para o dino domado (5.12)**; a **Ração Rubra e o domar usam crua** (o Utahraptor aceita carne crua), então a Fogueira **não toca na conta da domesticação**.

**Fome 0, torpor do jogador:** sobe **+2/s líquido**: **inconsciente em 50 s**. Do cheio ao primeiro desmaio: 1.050 s [calculado, queda 0,1/s]. Faixas 25/50/75 em 12,5 / 25 / 37,5 s (efeitos leves).

**Inconsciente (atualizado em 07/11):** o desmaio dura 8 s ou 20 s (QA-01a decide); **sem dano de fome** e sem morte por fome. Com um Utahraptor L20 por perto, 8 s são 5 a 6 mordidas (40 a 48 de 100 de vida: não mata); 20 s são 13 mordidas (mata) [calculado, 6.1b]. Acorda com torpor 50. Comer **qualquer comida (fome > 0)** corta a subida do torpor.

**Inconsciente não come sozinho (recomendo): acorda sozinho em 8 s e come na janela de 25 s; no co-op outro jogador pode alimentar o caído** (interação de 1 s com comida em mãos, valida no servidor), o que o **acorda na hora**. Sem comer automático (não é decisão).

**Cochilo, sono e M4:** a fome é **fonte própria** de torpor, **fora da lista de 3 efeitos e do teto** (5.4). O **estado "inconsciente" do jogador é o mesmo do sono do M4**; o torpor do jogador entra antes, só pelo caminho da fome. Escopo, `SORA`: `decay_per_second` 0,1; `HungerComponent` sem dano (sinal `hunger_zero`); `PlayerTorpor` com fonte "fome"; estado inconsciente com o caído como alvo do carnívoro; interação "alimentar jogador" no co-op; save do torpor.


### 5.11 Armadura por peça e dano mínimo 1 (decisão do dono, 06/11; vagas de equipamento no fim de 06/11)

Simulação: `fome_sim.py armadura` e `fome_sim.py pecas`. **Decisão final do dono: o inventário tem vagas de equipamento (arma, camisa, calça, bota, luva e capacete, 5.20); isso substitui "um conjunto, 1 vaga".** Três materiais (fibra, couro, metal) em **cinco peças**. Só reduz dano; **sem efeito de temperatura**. Pele, osso, quitina e Escudo saem.

**Por peça (o conjunto completo fecha exatamente os valores aceitos: 10%, 25%, 40% e 2, 6, 12 kg).** Divisão pelo corpo [premissa]: camisa 30%, calça 25%, capacete 20%, bota 15%, luva 10% do conjunto, arredondada para inteiro na redução e a 0,1 kg no peso.

| Peça | Fibra: red. / kg / material | Couro: red. / kg / material | Metal: red. / kg / material |
|---|---|---|---|
| Camisa | 3% / 0,6 / 5 fibra | 8% / 1,8 / 3 couro + 1 fibra | 12% / 3,6 / 2 barra + 1 couro |
| Calça | 3% / 0,5 / 4 fibra | 6% / 1,5 / 2 couro + 1 fibra | 10% / 3,0 / 1 barra + 1 couro |
| Capacete | 2% / 0,4 / 3 fibra | 5% / 1,2 / 1 couro + 1 fibra | 8% / 2,4 / 1 barra |
| Bota | 1% / 0,3 / 2 fibra | 3% / 0,9 / 1 couro + 1 fibra | 6% / 1,8 / 1 barra |
| Luva | 1% / 0,2 / 1 fibra | 3% / 0,6 / 1 couro | 4% / 1,2 / 1 barra |
| **Conjunto** | **10% / 2 kg / 15 fibra** | **25% / 6 kg / 8 couro + 4 fibra** | **40% / 12 kg / 6 barra + 2 couro** |

**Mudança de material: a fibra perde as 2 madeira** (15 fibra puras; as peças não repartem 2 madeira em 5); **o resto é igual ao conjunto antigo** (couro 8 + 4 fibra, metal 6 barra + 2 couro). **Durabilidade por peça = a do conjunto antigo: 100 / 150 / 300.** Saber, marco e estação em 5.20 e `receitas.md`: **fibra depois do playtest, couro M4, metal M5**.

**Regras (o mais simples, recomendo):**
1. **A redução é a soma das peças equipadas** (linear, sem bônus de conjunto), com o teto de 50% mantido; o máximo possível é 40%, então **o teto continua só como trava para o futuro** (Escudo ou bônus).
2. **Misturar materiais vale**, sem custo extra de regra: camisa de metal + calça e capacete de couro + bota e luva de fibra = 12 + 6 + 5 + 1 + 1 = **25%** (`fome_sim.py pecas`). Dá escolha de "onde gastar o metal" sem sistema novo.
3. **O ataque de dino atinge todas as peças** (sem sorteio de local): reduz pela soma e **cada peça equipada perde 1 de durabilidade por golpe sofrido**, inclusive o que caiu a 1. **Custo de material por golpe não muda:** o conjunto antigo perdia 1 de 100 e a reposição era 50% de 15 fibra; agora cinco peças perdem 1 de 100 cada, e a reposição de cada uma é 50% do seu material (soma igual). A alternativa "uma peça sorteada por golpe" dá aleatoriedade sem decisão e fica fora.
4. **Peça quebrada (durabilidade 0): reduz 0**, continua equipada, não some; as outras seguem somando (camisa de metal quebrada no exemplo acima: 25% cai a 13%).
5. **Reparo por peça** na Bancada (metal na Forja, como em 5.9): `ceil(50% do material da peça x fração que falta)`, **sem reduzir o máximo**. **Arredondamento:** o mínimo de 1 unidade por peça infla o conjunto reparado do zero para 9 fibra (contra 7,5), 6 couro (contra 4) e **5 barras (contra 3)**. **Recomendo o botão "Reparar tudo equipado"**, que calcula `ceil(50% x soma do material x falta)` uma vez: metal 3 barras, couro 4, fibra 8. **Peso:** cada peça conta no Peso (50 kg + 3/pt): o conjunto de metal tira 12 kg (24%).

**Dano mínimo 1:** `dano_final = max(1, dano x (1 - min(0,5, redução_soma)))` para todo ataque que acerta com **dano base >= 1**; **dano base 0 (fruta, preparado, Boleadeira) continua 0** (é torpor, não "acerta" para dano). **Conta (Utahraptor 11,25; Triceratops 55), conjunto completo:** fibra 10,1 e 49,5; couro 8,4 e 41,3; metal **6,8 e 33,0**; misto de 25%: 8,4. O mínimo só muda o resultado para dano base abaixo de 1,7 (com 40%): marimbondo, golpe de 1, pancada de 2 (metal: 1,2). **Durabilidade:** fibra dura 100 golpes (2,5 min de Utahraptor L20), couro 150 (3,8 min), metal 300 (7,5 min). **Na v0.2 não há roupa nem outra arma que o Bastão:** 19 receitas, 20 Saber.

### 5.12 Comida do dino domado (decisão do dono, 06/11; **o Cocho sai da v0.2 em 07/11**)

> **Regra atual (07/11) **[provisório, aguarda o dono]**:** **sem Cocho na v0.2** (a mobília, o curral e o Portão saem). O jogador alimenta o domado pela tela dele (E) e pela tecla, e o domado tem **alforje de 4 slots** (6.13). A fome do domado fica sem efeito de jogo na v0.2 (montar não exige fome do dino, 6.12). Em aberto: se a queda de Afeto por fome volta com o Cocho. A tabela 5.1 de fome do dino segue como dado.

#### Histórico (superado em 07/11)

O texto abaixo é o desenho anterior. **Não o implemente**; vale o resumo acima.


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

**Cocho (mobília):** Saber **2**, sem pré-requisito (lista plana, 5.19), **8 madeira**, **à mão**, **M2 cortável (a decisão mantém o Cocho fora do corte)**. **Escopo:** nó de cocho com filtro e alcance; o dino "ir comer"; regra do alforje; fome zero (Afeto e ofício); save; tela (reusa a do baú). `YATORA`: cocho vazio e cheio, dino comendo. `SORA`: `Trough {items[], accepts, range=6}`, `fome <= 50` e `<= 25`, filtro de dieta, validade por pilha. Precisa jogar: se 6 tiles e 50% de fome dão conforto ou o dino parece "faminto de pé ao lado do cocho".


### 5.13 Tecla de atalho e slot de oferta (decisão do dono, 06/11; **slot de Oferta ADIADO para depois do playtest**)

> **Decidido (06/11, dono):** (1) **o Cocho fica para dinos domados**; (2) **o slot de Oferta e a domesticação passiva ficam para depois do playtest**: a tabela abaixo é **proposta guardada**, fora do M2 e da v0.2; (3) **o jogador nunca consome Ração, só o dino**; **o preparado de sono ainda não foi decidido**. Sem o slot, **todo domar é ativo** (nocaute, tela do dino com E) e o Paquicéfalo do tutorial segue como está. A regra 2 do dono vale: o dino domado come do inventário dele e do Cocho; o dino em domesticação, da tela dele.

**Regras do dono:** (1) a tecla de atalho (1 a 9) **sempre faz o jogador consumir o item**, nunca alimenta dino; (2) o dino só come se a comida estiver no **slot passivo** (domesticação passiva) ou **no próprio inventário dele**. Nome no jogo: **slot de Oferta** [proposta]. Regras abaixo são minhas, com os números do `racao_sim.py tabela` (Paquicéfalo: 10 refeições com baga, 8 com C, 6 com B, 5 com A; Parassaurolofo: 15 com baga, 12 com C, 9 com B, 8 com A).

| Ponto | Regra recomendada [premissa] |
|---|---|
| **O que é e onde fica** | **1 slot extra** à direita da barra de atalhos, moldura diferente e ícone de folha; guarda **1 pilha** de comida. Mover para ele: arrastar no inventário ou **tecla O** (manda a pilha do atalho selecionado). **Tecla de atalho não toca nele.** |
| **Quem aceita** | Dino **selvagem desperto** de Conduta **Passivo** (Paquicéfalo) ou **Covarde que deixa chegar** (Parassaurolofo, Dodo), **nível até 20**. Semi-agressivo, Agressivo e Curioso **nunca** (não se aproximam). Listro (some em toca) não se aproxima: doma só ativa. |
| **Como pega** | O dino **desperto** vem até **3 tiles** do jogador **parado** (anda a menos de 1 tile por 10 s, sem arma na mão, sem correr) e come **1 unidade do slot a cada 8 s**. O jogador só espera e **vê** (a tensão é parar). |
| **Quanto leva** | Refeições da tabela x 8 s: **Paquicéfalo baga 80 s, C 64 s, A 40 s; Parassaurolofo baga 120 s, C 96 s**, mais ~20 s de aproximação. Ativo: Paquicéfalo baga 60 s + 8,4 s de Soco. |
| **Quando perde ou interrompe** | **Interrompe** (o dino se afasta, o slot fica): jogador corre, saca arma, ataca, leva dano; **qualquer** predador a 8 tiles; jogador a mais de 6 tiles. Progresso do dino **regride 1%/s depois de 15 s** parado e **zera em 60 s** (como em 20.3). **Parassaurolofo:** se alguém da manada for atacado, **a manada toda foge** (alarme, 6.7): interrompe todos. |
| **Eficiência** | **Sem torpor e sem bônus de nível**: o dino fica no **nível da captura** (ativo: Paquicéfalo L8 vira 10 com B; Parassaurolofo L20 vira 24 a 26). **Em troca nasce com Afeto inicial +20** [premissa] (via não violenta, pilar 3). Nunca precisa de dardo. |
| **Qual comida** | **Só o que a espécie aceita no domar**: baga (os dois) ou Ração Verde C, B, A. **Nunca Carne/Rubra** (carnívoro não entra). |
| **Validade** | Corre como em 5.9; a baga vence em 45 min contra 80 a 120 s de domar: **irrelevante**. Se a pilha vencer no meio, o dino para e o aviso aparece. |
| **Co-op** | O dino come **só do slot do primeiro jogador que ofereceu** (`owner_id`); outros jogadores perto são ignorados até zerar. Progresso é do dino. Sem PvP e sem roubo. |

**Alimentar o dormindo (resolvido pelo dono, 06/11):** no domar ativo a comida vai pela **tela de inventário do dino, aberta com interagir (E)**, e o dino come de lá; **já está implementado** e substitui a sugestão do item selecionado. Fruta e preparado no dormindo seguem o mesmo caminho. A regra 2 fica coerente: o dino come do **próprio inventário** (tela do dino) ou do **slot de Oferta**. Sem conflito.

**Cocho e a regra 2 (resolvido: o dono mantém o Cocho, para dinos domados).** O cocho não é o inventário do dino nem o slot: fica como **"inventário do rebanho" por alcance**, extensão da regra 2. Não serve ao dino em domesticação.

**Tutorial: a primeira doma é o Dodo na v0.2 (6.1b); o Paquicéfalo é a do M1 e a segunda da v0.2** (o slot ficou para depois do playtest; o domar é só ativo).

**Escopo guardado (fora da v0.2, adiado pelo dono; `SORA` e `YATORA` não fazem agora):** slot e tecla O; IA "aproximar e comer" (**reusa a IA de "ir comer" do cocho**); estado de progresso, regressão e Afeto +20; interrupções; co-op `owner_id`; save. `YATORA`: moldura do slot, ícone de folha, dino comendo (compartilhado com o cocho). **Menor recorte: só Paquicéfalo, só baga, sem co-op e sem Afeto**. **Fica depois do playtest (decidido)**: o M1 não depende dele; perde-se a via não violenta (pilar 3) na v0.2. Precisa jogar: se esperar parado 80 a 120 s é tensão ou tédio (espera sem decisão é defeito: a decisão aqui é **quando parar de oferecer e fugir do predador**).


### 5.14 Tempo de domar: alvos em minutos (decisão do dono, 06/11)

**Regra do dono:** o **nível do dino** muda **quantas comidas ou Rações** são necessárias e, por isso, o **tempo total**; no MVP o tempo é calibrado para os alvos abaixo na **taxa padrão (1x)**. Simulação: `tempo_sim.py tabela|torpor|eficiencia|curral|carne|hora`. Fórmula nossa: `refeições = ceil(refeições_da_comida x fator_da_espécie x max(0,5; 1 + 0,033 x (L - 10)))` e `tempo = refeições x intervalo x fator_de_bocado / taxa` (**antes 0,015 e piso 0,85**: o nível agora pesa mais). Fatores [premissa calibrada]: Paquicéfalo 1,5; Utahraptor 1,5; Parassaurolofo 1,1; Triceratops 1,7 com **bocado grande x3** (come devagar). Para o Utahraptor a carne crua vale no grau da baga; o Triceratops não aceita baga e **parte da Ração C**.

**Alvos [calculado: modelo dentro de +-6% dos alvos; a calibração em si é premissa]:**

| Espécie | Nível baixo / médio / alto | Comida | Quantidade | Tempo de domar |
|---|---|---|---|---|
| Paquicéfalo | 5 / 10 / 20 | baga | 13 / 15 / 20 | **1,3 / 1,5 / 2,0 min** |
| Utahraptor | 10 / 15 / 25 | carne crua | 15 / 18 / 23 | **1,5 / 1,8 / 2,3 min** |
| *(fora da v0.2)*  Parassaurolofo | 10 / 20 / 30 | baga | 11 / 15 / 19 | **1,1 / 1,5 / 1,9 min** |
| Triceratops | 20 / 28 / 40 | Ração C | 19 / 22 / 28 | **4,8 / 5,5 / 7,0 min** |

Com a **Ração A** o tempo cai a cerca de um terço: Paquicéfalo 0,5 / 0,5 / 0,7 min; Utahraptor 0,5 / 0,6 / 0,8; Parassaurolofo 0,4 / 0,5 / 0,7; Triceratops 2,4 / 2,8 / 3,4 min. **Taxa do servidor:** chave `domar_velocidade` (padrão 1,0): `tempo = tempo / taxa`.

**Manter dormindo (nível médio, comida-base; extra = tempo x queda + refeições x agitação - torpor máximo):** Paquicéfalo L10: janela 100 s, tempo 90 s, extra 65 = **3 golpes de Bastão (2,1 s) ou 7 de Soco (4,2 s)**; Utahraptor L15: extra 88 = 3 de Bastão ou 9 de Soco; Parassaurolofo L20: extra 24 = 1 de Bastão ou 3 de Soco; **Triceratops L28 com C: extra 343 = 12 de Bastão (8,4 s) ou 35 de Soco, ou ~46 s de Cochilo**; com A: extra 55 = 2 de Bastão. Com Ração A o extra é 0 nos três pequenos. Cada golpe em dormindo custa ~5 de Eficiência.

**Eficiência (nível médio): dreno por tempo 0,3 atual e 0,15 recomendado.** Paquicéfalo baga 27 (41), B 78 (84), A 86 (91); Utahraptor carne 16 (33), B 72 (81), A 85 (90); Parassaurolofo baga 39 (52); **Triceratops C 0 (0), B 0 (15), A 34 (59)**. Com 0,3 o Triceratops só paga com A; **recomendo `eficiencia_drena_tempo` de 0,3 para 0,15**. Ração S e S+ pioram o dreno por refeição a favor do jogador (`nivel_sim.py`).

**O que muda a jusante:**
- **Curral (6.x):** o texto dizia 40 a 105 s para o Utahraptor; agora **32 s (Ração A, L10) a 138 s (carne crua, L25)**. A conclusão não muda: a cerca cede em 8 s, a madeira cobre só a intervenção.
- **Carne e validade:** Utahraptor L15 pede **Ração Rubra C: 14 refeições, ~25 carne (13 Dodos, 6,5 min de caça)**; **B: 11 refeições, ~11 carne**; **A: 9, ~10 carne**. Validade da carne crua (30 min): margem de **4,6x (C), 10x (B), 12x (A)**. Baga (45 min) contra 1,1 a 2,0 min de domar: irrelevante.
- **Primeira hora:** não quebra. Paquicéfalo L8: **15 bagas (45 s de coleta), 90 s dormindo, 1 a 3 reforços de torpor**. **Recomendo o Paquicéfalo (primeira doma no M1, segunda na v0.2) entre L5 e L8** (L5: 13 bagas, 78 s; L8: 15 bagas, 90 s). Com Soco (antes do Bastão) a Eficiência de um tutorial com baga fica perto de 0: aceitável, é o aprender.
- **Conflito:** `racao.md` 10.x e 6.1 ("Dificuldade 1,0 / 1,5 / 2,0 / 1,5") e as tabelas de 60 s e 105 s ficam **desatualizadas**; vale esta seção e `tempo_sim.py`.
- **Precisa jogar:** se 5,5 min de Triceratops com a Ração C é tensão ou espera (a saída é a Ração A, 2,8 min); se o Utahraptor com 1,8 min dormindo é vigília longa o bastante para o predador chegar.


### 5.15 A v0.2 sem dardo, sem Oferta, sem Listro e sem fibra: ainda doma? (06/11)

Simulação: `covarde_sim.py para|tri` (perseguição com Stamina por golpe, faixas de torpor e fuga de 16 tiles).

*[Histórico, superado em 07/11: Parassaurolofo e Gallimimus fora da v0.2]* **Parassaurolofo (Covarde, foge a 75 px/s): doma com Bastão, sem ajuste.** Nível 10, 20 e 30: **6, 7 e 8 golpes de Bastão, 3,5 / 4,2 / 5,3 s**, o dino foge 9 / 11 / 15 tiles (a fuga acaba aos 16) e o jogador **não precisa correr**: caminhando gasta só os golpes (Stamina mínima 94); a lentidão das faixas de torpor deixa o dino a menos de 70 px/s antes do 4o golpe. **Soco não serve**: 20 a 34 golpes, 11 a 28 s (só termina porque a fuga acaba). Depois do nocaute: baga, 15 refeições e 90 s no L20, com 1 reforço de Bastão. **Não precisa de armadilha, curral nem novo sistema.** O alarme faz a manada fugir, e isso não atrapalha o alvo.

**Triceratops (Semi-agressivo, investe): doma, mas só com o nível certo; ajuste de dado.** Dano ao jogador (premissa) 20 x (1+0,04(L-10)), a cada 2,5 s, o 1o ataque 0,5 s depois do 1o golpe: **L20: 8 golpes, 4,9 s, 2 ataques de 28 = 56 de dano (de 100)**; **L28: 9 golpes, 5,6 s, 3 ataques = 103: mata**; com 5 pontos em Dano 7 golpes e 69; com 4 em Vida (124) sobra 21. **Menor ajuste: o Triceratops selvagem da v0.2 aparece em L18 a L24** (L24: 62 de dano, sobrevive sem build); **L28 e acima ficam fora (sem Rifle): na 1.0 a faixa continua em L18 a L24**; liberar L25 a L28 só se o dono quiser, e então com conjunto de couro completo (L28: 77 de dano, sobra 23) ou Arco (a 10 tiles) ou metal (62). É só dado de spawn, **sem sistema novo; não precisa de decisão do dono**, só confirmar a faixa. Depois do nocaute, Ração A (2,4 a 2,8 min, extra 42 a 55 = 2 golpes) é o caminho viável; com C o extra é 292 a 343 (Cochilo ou 10 a 12 golpes que zeram a Eficiência).

**Resto:** Paquicéfalo (Soco ou Bastão) e Utahraptor (Bastão, 6 golpes) como antes. **Espécies da v0.2 (atualizado em 07/11): Dodo, Paquicéfalo, Utahraptor e Triceratops = 4**, todas domáveis (4.1); Listro e Oviraptor entram na 1.0 (M4).


### 5.16 Tetos de nível: nascimento, evolução, servidor e jogador (decisão do dono, 06/11)

Simulação: `teto_sim.py spawn|teto|xp|saber`. **Regras do dono:** (1) dinos nascem com nível aleatório e **teto máximo ao nascer**; (2) o dino tem **teto de evolução de 2x o nível de doma** (selvagem em 100 chega no máximo a 200); (3) o **teto do servidor vence** (teto 180: nunca chega a 200, e em 180 o XP trava); (4) o jogador também tem nível máximo.

**Faixa de spawn e distribuição [premissa].** Nível por sorteio **com poucos altos**: `nível = mín + floor((máx - mín + 1) x u^2)`, `u` uniforme (a média cai a 1/3 da faixa, o quarto de cima sai 13% das vezes e não 25%, o nível máximo 2 a 7%). Faixas na v0.2: **Dodo 3 a 10; Paquicéfalo 5 a 20 (zona do tutorial 5 a 8); Utahraptor 10 a 25; Parassaurolofo 10 a 30; Triceratops 18 a 24** (média 19,9; compatível com a faixa de 5.15). Na 1.0 o Triceratops amplia para 18 a 40 (média 25,2). Médias: Dodo 5,2; Paquicéfalo 9,9; Utahraptor 14,9; Parassaurolofo 16,5. **Teto ao nascer no MVP: `dino_nivel_spawn_max` = 30** (o maior da v0.2 é o do Parassaurolofo); o sorteio nunca passa dele nem do `dino_nivel_max`.

**Teto de evolução: três leituras do "2x"** (selvagem 100, bônus de Eficiência 50, final 150): **A) 2x selvagem = 200; B) 2x final = 300; C) 2x selvagem + bônus = 250.** Exemplos do MVP: Paquicéfalo L10 com Ração A (final 15): A 20, **B 30**, C 25; Parassaurolofo L20 com A (final 29): A 40, **B 58**, C 49; Triceratops L24 com A (final 31): A 48, **B 62**, C 55.

**Ambiguidade, recomendação e ponto para o dono: B, 2x sobre o nível final (depois do bônus).** Em **A** o teto não depende da Eficiência: ela só adianta níveis (poupa XP), e **no fim do jogo a Eficiência perde todo o valor**; em **B** cada nível de bônus eleva o teto, e a escada de Rações paga até o fim. B é também a leitura literal de "nível de doma" (o nível em que o dino foi domado, já com o bônus). O risco de B (crescer demais) é coberto pelo **teto do servidor**. **Configurável:** `dino_teto_base` = `final` (recomendo) ou `selvagem`; `dino_teto_multiplicador` = 2,0. **Decisão do dono (V60):** confirmar B.

> **EM ABERTO (07/11, pergunta ao dono):** o teto de evolução do domado é **A) 2x o nível do selvagem (a recomendação atual da equipe), B) 2x o nível final (a recomendação acima, de 06/11) ou C) 2x o selvagem + bônus.** Até o dono responder, **não vale nenhuma das três como regra final.** Há ainda uma **divergência 75 x 50**: o teto do servidor do MVP é **50** (abaixo), mas `dino_level_rules.tres` está em 75; o código deve ser corrigido para 50 quando a regra for fechada. O selvagem nasce até 30.

**Teto do servidor e valores do MVP.** `dino_nivel_max` vence sempre: **teto efetivo = min(multiplicador x nível de doma, `dino_nivel_max`)**; vale também para o nível ao nascer e para o bônus de Eficiência (o final nunca passa dele). **MVP: 50** (não 75): o dino evolui de 15 a 20 níveis, o mesmo tamanho dos 19 pontos do jogador; com 75 seriam 44 pontos no Triceratops (+264% da base) contra 19 no jogador. Conta de XP (curva do dino `20 + 10g`, 15 XP/min, companhia): Triceratops L24 de 31 a 50 = 19 níveis = 2.280 XP = **2,5 h**; Parassaurolofo L20 de 29 a 50 = 21 níveis = 2.730 XP = **3,0 h**; só ao teto 75 passaria de 12 h. **1.0: 75.**

**Dino domado ganha XP como: já estava definido (5.1, item 6)**: o mesmo XP do jogador enquanto está em "seguir" a até 12 tiles, curva `20 + 10g` por nível extra, 1 ponto por nível (Vida, Dano ou Peso). **Muda só o teto** (de captura + 10 para a regra acima). A curva não depende do nível; se o dono quiser que dinos grandes demorem mais, é valor novo (não incluído).

**Ao travar** (dino ou jogador no teto efetivo): **o XP para de acumular** (não fica guardado), a **barra de XP fica cheia com o selo "teto"** (no dino, na tela dele; no jogador, na HUD no lugar do "Nv"), **não nascem pontos novos**, e os **pontos livres que já existiam continuam gastáveis**. Se o teto do servidor subir depois, o XP recomeça de zero no nível atual. **Save acima do teto (recomendo: só trava, não reduz):** reduzir o nível devolveria pontos já gastos e puniria o jogador por uma mudança do servidor; o dino ou jogador acima do novo teto **mantém nível e pontos** e não ganha XP; domar novo respeita o teto novo (o final é cortado nele). **Ponto para o dono (V60).**

**Teto do jogador.** **MVP: `jogador_nivel_max` = 20** (19 pontos de atributo, **24 Saber**; a v0.2 custa **23**, cobre com 1 sobrando). **1.0: recomendo 75** (**90 Saber** contra os **84 da 1.0**, 74 pontos de atributo). **Conferido: a 1.0 completa no L70** (84 Saber com Mochila, selas, Saco e Cama; antes L69 com 82 [calculado, `receitas_sim.py`]); com teto 50 o jogador chega a 60 Saber (71% da árvore), com 20 a 24 (30%): **se o servidor baixar o teto do jogador abaixo de 69, a 1.0 fica incompleta por desenho**. XP do jogador (curva `30 + 15(L-1)`): L20 3.135 XP (4,0 h a 13/min), **L68 35.175 XP (45 h)**, L75 42.735 XP (55 h).

**Marco, M2 (junto do XP do dino); escopo:** teto efetivo (fórmula, `min`, corte do final e do spawn); XP que trava, barra cheia e selo "teto"; sorteio com poucos altos e faixas por espécie em dado; chaves de servidor e leitura; save acima do teto (só travar); texto na tela do dino. **Menor recorte: constantes e XP que trava, sem selo nem chaves.** `YATORA`: selo "teto" (dino e jogador). `SORA`: `Attributes` com `teto_efetivo(dino)`. Precisa jogar: se 2,5 a 3 h de companhia até o teto parece progressão ou espera, e se "poucos altos" deixa os dinos fortes raros demais.


### 5.17 Forja: madeira, carvão e minério (decisão do dono, 06/11)

**Regra do dono:** a Forja **queima madeira para fazer carvão e converte minério em metal**. A própria Forja é feita na Bancada (`receitas.md` 6). Marco **M4 a M5** (sem mudança); fora da v0.2. Números [premissa], contas à mão.

**Mínimo recomendado (dois processos automáticos, um relógio):**

| Processo | Entra | Sai | Tempo |
|---|---|---|---|
| **Queimar** | 3 madeira | 1 carvão | 30 s (10 s por madeira) |
| **Converter** | 2 minério de ferro + 1 carvão | 1 Barra de ferro | 10 s |

- **Carvão é item necessário**, não subproduto solto: sem ele não há barra. **Custo de uma barra: 2 minério + 3 madeira, 40 s de fogo** (antes 2 minério + 1 madeira, 5 s). A Forja faz **uma coisa por vez**: **converte se houver 1 carvão e 2 minério, senão queima** (um relógio só).
- **Inventário da Forja (4 vagas):** madeira até 30 (30 kg), minério até 20, carvão até 10 (0,2 kg cada), barra até 10. **Carga cheia: 30 madeira viram 10 carvão e 20 minério viram 10 barras em 10 x 40 s = 400 s (6,7 min)**.
- **Funciona sozinha com o jogador longe: sim.** O estado fica salvo `{vagas, relógio, t_ultimo}` e o progresso é calculado **na hora de abrir ou salvar** (como a validade das pilhas, 5.9): sem tique por quadro. Só corre com o servidor ligado. A saída para quando a vaga de barra enche.
- **Os itens de metal que a Forja faz:** **18 barras ao todo** (Machado 3, Picareta 3, Espada 4, conjunto de metal 6, **Besta 2; o Rifle (4) saiu**) = **720 s de Forja (40 s por barra), 54 madeira, 36 minério**; coleta: 54 madeira = 72 s com Machado de pedra, 36 minério = ~144 s [premissa: nó de minério 0,25/s]. **Antes eram 20 barras, 800 s, 60 madeira e 40 minério: o corte do Rifle poupa 80 s de Forja e 4 minério por jogador.** Dardo e Rifle sem marco.
- **Carvão tem outro uso? Hoje não.** **Recomendo a forma mais simples: carvão só da Forja (sem receita própria e sem Saber).** **Uso opcional barato:** a **Fogueira aceita carvão** (1 carvão cozinha 10 carnes, 0,2 kg; contra 1 madeira por 4 carnes, 0,5 kg): serve de combustível leve de expedição. Como 3 madeira dão só 1 carvão, a troca não vale como fonte principal. **Decisão do dono (V61): só Forja ou também Fogueira.**

**Escopo extra:** Forja como contêiner de 4 vagas com os dois processos e o catch-up; save e versão; tela (reusa a do baú); item carvão e minério, somado ao que o metal já exige (`receitas.md` 6). **Menor recorte:** sem "funciona longe" (só corre com a tela aberta) , mas o jogador fica parado: **não recomendo** (espera sem decisão). `YATORA`: Forja apagada e acesa com fumaça, ícones de carvão, minério e barra. `SORA`: `Forge {slots, timer, t_last}`, `queimar` e `converter` por dados. Precisa jogar: se 6,7 min por carga é espera boa (o jogador mina e volta) ou lenta.


### 5.18 Pilão e químicos (decisão do dono, 06/11)

**Pilão:** item **portátil**, feito **à mão** (Saber 1, 2 pedra + 1 madeira, 3,5 kg, 100 moagens), usado no personagem pela aba "Moer" do menu de Receitas. **Preparado de sono** (nome único) passa a ser moído no Pilão: 3 Cochilo + 1 carne podre rendem 3, 4 s. **v0.2: 21 receitas, 22 Saber** (sobra 2 dos 24; Saco e Cama voltaram, 12.3; o Bastão reforçado segue cortado); o Pilão e o Preparado são **cortáveis juntos** (sem eles 17 e 16), **mas ficam: aceitos pelo dono**. O Preparado é o único consumidor do Pilão na v0.2.

**Fósforo e pólvora: SEM MARCO (decisão final do dono, 06/11); o sílex voltou no M4 com fonte própria (5.9c).** Sem Rifle e sem arma de fogo nada os consome, então saem da árvore ativa e do mapa de recursos; ficam só como registro (fósforo 2 sílex + 2 pedra rendem 6; pólvora 2 carvão + 2 fósforo rendem 4). **O carvão continua só da Forja** (aceito; opcional na Fogueira, V61). **Escopo da v0.2:** Pilão (item, aba Moer, durabilidade), junto com o Preparado: **Pilão e Preparado entram na v0.2** (aceito). `YATORA`: ícone do Pilão. `SORA`: estação "Pilão" no `RecipeDef` (portátil).


### 5.19 Regra de produção e decisões finais do dono (06/11)

**Regra de produção.** **Fibra, madeira e pedra são feitos na mão** (menu P, estação "Mãos"); **metal e engenharia, na Bancada**; a **Forja continua feita na Bancada** (5.17) e é a estação da Barra e dos itens de metal. Tudo o que usa só material primitivo (graveto, madeira, pedra, fibra, couro, corda) sai da árvore da Bancada. **Reclassificadas para Mãos:** Bastão-de-sono, Baú, Cocho, Cerca e curral, Portão de dino, Abrigo (fundação, parede, porta), Corda, Arco, Flecha, Boleadeira, peças de couro e de fibra, Canteiro, Palha, Tijolo, Pedra. **Ficam na Bancada:** Ração C, B, A, S e S+ (preparo de comida, decisão minha: é a única razão de a Bancada ser necessária na v0.2), Forja, Espada, Machado e Picareta de ferro, conjunto de metal (5 peças) e **Besta** (engenharia). Preparado: Pilão. `receitas_sim.py estacoes`: **v0.2 Mãos 15, Bancada 3 (Ração), Pilão 1; 1.0 Mãos 29, Bancada 11, Pilão 1.**

**Consequência a conhecer (calculado):** a Bancada passa a servir na v0.2 a **3 receitas (a linha da Ração) e ao reparo** (5.9). Continua valendo o Saber 1 e o marco "Bancada no minuto 5", mas a Bancada deixa de ser pré-requisito de armas e abrigos. **Precisa jogar:** se a Ração na Bancada basta como razão para construí-la ou se ela vira degrau vazio.

**Bastão-de-sono nasce no inventário no M1, sem receita** (confirmado, como recomendei): o tutorial da primeira doma (Dodo, 2 golpes; Paquicéfalo no M1, 4 golpes, 2,1 s) não depende de Saber. A receita de **reposição** (Saber 1, 3 madeira + 2 fibra, Mãos) entra no M2.

**Aceitas pelo dono:** (1) **"2x" é sobre o nível final** (nível da captura mais o bônus de Eficiência); (2) **servidor só trava, sem reduzir** (save acima do teto fica parado); (3) **teto de dino 50 no MVP** (75 na 1.0); (4) **Triceratops L18 a L24 na v0.2**; (5) **Dodo no início do M2**; (6) **carvão só na Forja**; (7) **Pilão e Preparado na v0.2**. **Cortes leves aceitos:** dano em construções no recorte mínimo (8.1), **sem Bastão reforçado**, **sem Cama**, **Saber em lista plana** (sem pré-requisito entre receitas; a cadeia mais longa cai de 3 elos para 0). **Corte maior: decidir depois do QA-01a.**

**Totais** (`receitas_sim.py arvore`): **v0.2 21 receitas e 22 Saber (24 disponíveis no L20; sobra 2)** (Saco e Cama de volta, 12.3; antes 19 e 20, e antes 21 e 23 com Bastão reforçado); **1.0 53 receitas e 73 Saber (completa no L61; antes 44 e 82, L69; as 53 contam as 15 peças de roupa, 5.20)**. A diferença é Cama, Bastão reforçado, Rifle, Dardo e a **Barra de ferro** (que é processo da Forja, sem receita no menu, e estava contada por engano), mais Besta e Boleadeira que entram.

### 5.20 Vagas de equipamento e tela do inventário (decisão do dono, 06/11)

> **Atualizado em 07/11 (decidido).** A tela de inventário mostra **equipar itens** e uma **ficha de RPG** com os dados do personagem. **Na v0.2 só há duas vagas visíveis: Arma e Bolsa** (a bolsa é a vaga única de 5.21); as 5 de roupa aparecem no M4. **Ficha só de leitura** **[provisório, aguarda o dono]** (jogador: nome, Nv e XP, Saber, Vida, Fome, torpor, dano, velocidades, slots usados/limite e bolsa; dino: nome, espécie, Nv, Eficiência, Vida, Dano, Afeto, alforje n/4, "Neutro", "montável"); pontos de atributo ficam fora. **Ferramentas e armas ficam fora dos slots** **[provisório, aguarda o dono]** (a vaga Arma mais um cinto; contam no Peso). A grade é de 4, 8 ou 12 slots, não mais de 40.

**Seis vagas:** **Arma, Capacete, Camisa, Luva, Calça e Bota.** Cada item equipável tem um campo `slot`; só cabe na sua vaga. A vaga **Arma** recebe **qualquer item de mão** (arma ou ferramenta: Soco não conta, Bastão, Lança, Machado, Picareta, Arco). **Sem vaga de acessório e sem segunda mão** (nada pedido).

**Receitas (decidido, V69; conta minha): um nó de Saber por material libera as 5 peças** (as 5 aparecem no menu P de uma vez). **Fibra Saber 1, couro Saber 2, metal Saber 6**, os mesmos custos do traje antigo. Alternativa rejeitada, **Saber por peça** (fibra 1, couro 2, metal 4 cada): +26 Saber, **1.0 com 99 Saber**, acima dos 90 do L75 (`receitas_sim.py por_peca`: completa no L83, que não existe). **Totais (`receitas_sim.py arvore`): v0.2 21 receitas e 22 Saber (a roupa não entra; +Saco e Cama, 12.3); 1.0 53 receitas (antes 41; +12 = 15 peças menos 3 trajes) e 73 Saber (não muda), completa no L61.** Estações 1.0: Mãos 37, Bancada 15, Pilão 1 (peças de fibra e couro à mão; as de metal na Bancada, com a barra pronta da Forja).

**Tela mínima:** a tela de inventário (menu) mostra uma **coluna de 6 vagas à esquerda da grade de slots (4, 8 ou 12 na v0.2, 5.21)**, de cima para baixo: Capacete, Camisa, Luva, Calça, Bota e, separada embaixo, Arma; cada vaga vazia mostra uma **silhueta** do tipo. Embaixo da coluna, **dois números: "Redução 25%" e "Peso 18/50 kg"** (M4b: "Carga 18/50 kg, 36%" com marca em 70%, também no inventário do dino, 5.1b) (o Peso já existe no HUD). **Sem boneco.**
- **Equipar:** arrastar o item da grade para a vaga, **ou duplo clique no item** (vai à vaga certa). Vaga errada: recusa sem mensagem. Vaga ocupada: **troca** (o item antigo volta à grade). Leva **0,3 s** (5.2), sem bloqueio em combate.
- **Tirar:** arrastar a peça de volta à grade, ou **duplo clique na vaga**. Se a grade estiver **sem posição livre**, a troca ou a retirada é **recusada com "Inventário cheio"**; nada se perde nem cai no chão.
- **Barra de atalhos (5.2):** a **arma equipada vive na vaga Arma**, não na grade. O atalho aponta para o **id do item** como hoje: apertar a tecla **equipa** (move da grade à vaga, devolvendo a anterior) e apertar de novo **desequipa**; o atalho mostra uma **moldura de "equipado"** e a soma das pilhas inclui a vaga. **Roupa não vai ao atalho** (só consumível, arma e ferramenta). Arma quebrada na vaga: atalho em vermelho.
- **Peça quebrada:** continua na vaga, **reduz 0**, ícone com marca vermelha e a barra de durabilidade zerada no tooltip; aviso uma vez ("Camisa quebrada"); **arma ou ferramenta quebrada age como mãos livres (Soco, mão na coleta, 5.9)**. O reparo na Bancada atua em item **equipado ou na grade**, sem tirar.
- **Peso e morte:** o equipado conta no Peso; na morte segue **a mesma regra do inventário** (sem exceção nova).
- **Co-op:** vagas por jogador; `equipar(iid, vaga)` e `desequipar(vaga)` validados no servidor (item existe, `slot` confere, cooldown); a redução é **calculada no servidor**; save guarda `{vaga: iid}` e a versão do save sobe.
- **Sprite do jogador: não muda por peça (decidido, V70).** A tela mostra o equipado; o personagem fica igual. Custo evitado [premissa: 4 direções x 4 quadros de andar]: 15 peças x 16 = **240 sprites**; mesmo só por material (3 trajes) seriam 48. Fica para depois do playtest, se o dono pedir.

**O que entra agora (M1, Bastão como única arma e nenhuma roupa):** o **modelo de vagas completo (6)** e a **tela com as vagas ao lado da grade, só a Arma visível e ativa**; as 5 de roupa **aparecem quando existir item de roupa** (M4, flag de dados `slot_visivel`). Motivo: o modelo de dados genérico custa o mesmo agora ou depois, e refazer depois mexe em save e rede. **Escopo:** **M1:** modelo de vagas, validação de servidor e save; painel (arrastar, duplo clique, silhueta, só Arma); ligar a barra de atalhos à vaga. **M4:** redução somada, peso e desgaste por golpe em cada peça; reparo por peça e "Reparar tudo equipado"; 15 itens em dados e as 5 vagas visíveis; save e co-op. (O Traje antigo só valia depois do playtest.) **Menor recorte do M1: só a vaga Arma, mantendo o modelo de dados genérico.** `YATORA`: 15 ícones de peça e 6 silhuetas de vaga; sem sprites de corpo.

### 5.21 Slots que limitam e a vaga de bolsa (decisão do dono, 06/11 e 07/11; substitui o texto de "Mochila" de 06/11)

**Decidido pelo dono.** O jogador tem **4 slots**. Há **uma única vaga de bolsa; vale a equipada, os bônus não somam:** **Saco de fibra +4 (8 slots no total)** ou **Mochila de couro +8 (12 no total)**. O **Peso continua** (5.1): 50 kg, impede pegar acima de 100%, sem lentidão. Slot limita a variedade; Peso limita a massa. A bolsa **não** aumenta o Peso.

**Provisório** **[provisório, aguarda o dono]**:
- **Nome "Cesto de fibra"** no lugar de "Saco de fibra", para não confundir com o Saco de dormir (12.3).
- **Ferramentas e armas fora dos slots** (5.20). Comida, material e Ração contam.
- **Trocar para bolsa maior sempre vale; trocar para menor ou tirar só se o conteúdo couber** (conta-se o número de pilhas contra o novo limite); senão **recusa com "Esvazie N pilhas"** e nada se perde. Coletar com a bolsa cheia recusa sem gastar o nó ("Inventário cheio" ou "Peso máximo", o que bateu).
- **Descartar** uma pilha com confirmação (para não prender o jogador longe do baú).
- **Mochila de couro: 6 couro + 4 fibra [premissa]**, à mão; o couro ganha um uso. Sem durabilidade. Save acima do limite só trava.
- Morte: o corpo leva tudo, bolsa incluída (12.4).

**Conta com as pilhas atuais** (`shiro.md` 4.7): abrigo mínimo (32 madeira, 4 pedra, 1 fibra) = 4 slots e 38 kg; domar o Utahraptor L15 pede 3 slots só de carne mais a Ração, então na prática exige a bolsa. Com a validade fora, a pilha de carne pode ir a 20 [premissa] (2 slots em vez de 3).

**Dino:** sem sela, o domado tem **4 slots** no alforje (6.13); a tabela por porte (1 diminuto, 2 pequeno, 4 médio e grande) é [premissa].

**Marco:** v0.2 (PRO-04/05, CON-02, PRO-06 no plano). **Precisa jogar:** se 4 slots incomodam sem ajudar a decisão; se a recusa de tirar a bolsa cheia frustra. `YATORA`: ícones de Cesto e Mochila, sem sprite de corpo.

## 6. Criaturas

### 6.1 Elenco do MVP (espécies reais)

Decisões do dono: a espécie usa o **nome real** (apelido próximo só se for extenso); **só terrestres**, sem voo nem água; **espécies brasileiras ficam para depois do MVP**; lista reduzida, escolhida do `catalogo.md`. Nomes novos substituem os provisórios anteriores.

> **Atualizado em 07/11** **[provisório, aguarda o dono]**: a v0.2 tem **4 espécies: Dodo, Paquicéfalo, Utahraptor e Triceratops.** O Parassaurolofo (e o Gallimimus) saem da v0.2; as linhas abaixo ficam como referência para depois. Faixa de nível do Utahraptor: hoje usa a da Mata-baixa, 5 a 25 (em aberto).

| Papel | Antigo (provisório) | Espécie (nome no jogo) | Conduta | Domar |
|---|---|---|---|---|
| Herbívoro do tutorial | Barrigudo | **Paquicéfalo** (*Pachycephalosaurus*) | **Passivo** (6.7): pasta, ignora você, revida com cabeçada se atacado | Fator de refeições 1,5 (5.14); Ração Verde; aceita baga crua |
| Carnívoro em bando | Rabo-de-faca (via Deinonychus) | **Utahraptor** | **Agressivo**: ataca ao avistar (elipse de 8 tiles na horizontal e 5 na vertical, 4.2), bando de 1 a 2 | Fator de refeições 1,5 (5.14); torpor 120; vida base 80; Ração Rubra; aceita carne crua |
| Grande territorial | Montanhão | **Triceratops** | **Semi-agressivo**: ignora até 4 tiles ou ferimento; aí investe | Fator de refeições 1,7 e bocado x3 (5.14); Ração Verde |
| *(fora da v0.2)* Herbívoro de manada com alarme (M2) | novo | **Parassaurolofo** (*Parasaurolophus*) | **Covarde**: deixa chegar, mas ao ser atacado dá o alarme e o grupo de 3 a 5 foge (alarme a 12 tiles) | Fator de refeições 1,1 (5.14); torpor 140, queda 1,3; vida base 200; Ração Verde; aceita baga crua |
| *(fora da v0.2)*  Fuga (5ª, cortável) | Pernalta | **Gallimimus** | **Covarde**: não foge ao avistar; ao ser atacado dá o susto e foge a 85 px/s (fuga própria da espécie); grupo de 3 a 5 | Dificuldade 1,25; Ração Verde; aceita baga crua |
| **Presa 1, a mais comum (início do M2)** | novo | **Dodo** (*Raphus cucullatus*, ave que não voa) | **Covarde** (decisão do dono, 06/11): pasta, não reage ao ver o jogador; jamais revida e foge se atacado ou se um do grupo (3 a 5) é atacado a até 8 tiles | **Domável** (6.1b): vida 24, torpor 50, queda 0,8/s, fator 0,7, baga; L3 a 10; 2 carne + 1 couro (se abatido); XP 3 |
| **Presa 2, escavador (M4, com o Oviraptor)** | novo | **Listro** (*Lystrosaurus*) | **Covarde**: ao ser atacado foge a 85 px/s (fuga própria da espécie) e some em toca | **Domável** (6.1b, M4): vida 36, torpor 48, queda 0,9/s, fator 0,8, baga; L8 a 16; 3 carne + 2 couro (se abatido); XP 4 |

**Dodo e Listro (revisto 06/11, dono):** presas pequenas e **abundantes**, mais comuns que todas as outras (Dodo 12 por zona, Listro 8, respawn 10 min). **Papéis (decisão do dono, 06/11): Dodo e Listro são Covardes** (e o Parassaurolofo também): jamais revidam e fogem ao serem atacados, ou quando outro do grupo é atacado perto. O Dodo continua o primeiro alvo da Lança, mas o jogador é quem chega até ele (não vem mais ao jogador). O **Curioso** fica só com o Oviraptor, no M4. **Domáveis (decisão do dono, 06/11: o Dodo é domável, e a regra de mundo 4.1 vale para o Listro):** ganham perfil de doma (6.1b) e **mais um sprite de dormindo cada** [premissa]; a caça com Lança segue valendo. **Decidido (06/11): o Listro sai da v0.2 e entra no M4, junto com o Oviraptor. Total: 5 espécies na v0.2** (todas domáveis) e **7 na 1.0**. **Dodo** é ave que não voa: **sai do bloqueio dos voadores**. **Só o Dodo na v0.2:** 12 por zona, respawn 10 min = **72 Dodos/h = 144 carne/h**; demanda de 2 Utahraptors e do jogador ~24 Dodos/h (33%), de 5 Utahraptors ~46 (64%): **cobre**.


### 6.1b Doma do Dodo e do Listro: Covarde que foge com o grupo (decisão do dono, 06/11)

Simulação: `covarde_sim.py dodo`, `tempo_sim.py tabela|torpor|eficiencia|hora`, `conduta_sim.py`. Números [calculado] sobre premissas de dado [premissa]; sensação [jogar].

**Método.** (1) **Aproximar andando**: o Covarde vê a 6 tiles e deixa chegar (6.7). (2) **Nocaute com 2 golpes de Bastão em 0,7 s**: o 2º golpe cai **dentro do susto de 0,8 s**, o alvo nem anda. Torpor máx. do Dodo 50 no L10 (43 no L3): 2 golpes = 60 menos a queda de 3,5 = 56,5, cobre até L10 (50); o Listro tem 48 (54 no L16) para o mesmo fim. (3) O ataque faz o **grupo fugir** (3 a 5, 75 px/s, 10 s ou 16 tiles, alarme a 8): isso **não atrapalha**, o alvo já está no chão, e quando o grupo volta a pastar a 8 tiles **não reage** a quem alimenta (Covarde só reage a ataque). (4) **Alimentar é interação, não ataque**: não dispara alarme. (5) **Reforço de torpor**: **Cochilo** (2 a 3 s; não conta como ataque, o grupo não foge de novo) ou 1 golpe de Bastão (o grupo foge de novo, sem custo para o alvo). **Soco** serve como plano B: 6 a 7 golpes (3,0 a 3,6 s), o alvo foge 9 a 10 tiles antes de cair, o sprint alcança. **A Lança não doma** (dano 12, torpor 0: 2 golpes matam os 24 de vida): a arma escolhida decide entre caçar e domar. O Dodo **jamais revida**: erro custa só a fuga, não vida do jogador.

**Comida e tempo** (dreno por tempo 0,3; Dodo fator 0,7; Verde, rejeita Rubra):

| Nível | Baga: refeições / tempo | Ração A | Reforço de torpor (baga) |
|---|---|---|---|
| L3 | 6 / **36 s** | 3 / 12 s | 16: 1 golpe ou 2 a 3 s de Cochilo |
| L6 | 7 / **42 s** | 4 / 16 s | 23: 1 golpe ou 3 s |
| L10 | 7 / **42 s** | 4 / 16 s | 19: 1 golpe ou 2 s |

Eficiência no L6 (dreno 0,3): baga 64 (nível 6 vira 8), Ração B 90, A 93.

Comida ideal: **baga crua** (já pega na coleta; 6 a 7 bagas = 18 a 21 s de coleta); Ração A só vale se sobrar (poupa 24 a 26 s). Com a Ração A o extra de torpor é 0. **Listro** (M4, mesmo método, 2 golpes de Bastão em L8 a L16): fator 0,8, baga, 9 refeições no L12 (54 s), reforço de 44 torpor = 2 golpes ou 6 s de Cochilo [premissa].

**Utilidade do domado.** **Carregar** (Peso 12 / 15,6 / 19,2 kg em L10 / 20 / 30; Paquicéfalo 40, 3,3x mais): o menor carregador, bolso extra. **Colher** (M4, cortável): coleta passiva de baga/fibra como os herbívoros. **Não Defender** (jamais revida) e **não montável**. **Fugitivo**: Passivo fica parado; Neutro (padrão) e Agressivo fogem ao ver agressão a ele ou a aliado (6.11b). Vida 24 é frágil: o Dodo domado morre fácil, o que dá ao jogador motivo para protegê-lo (curral, Cama). **Listro domado** (M4): Carregar 15 kg e Colher tubérculo (cortável) [premissa].

**Primeira doma: o Dodo (decisão do dono, 06/11, V78)**

| Na v0.2 | Dodo L3 a L5 | Paquicéfalo L5 a L8 |
|---|---|---|
| Nocaute | 2 golpes de Bastão, 0,7 s | 4 golpes, 2,1 s |
| Revide | nenhum | cabeçada se atacado |
| Bagas / dormindo | 6 (18 s) / 36 s | 13 a 15 (39 a 45 s) / 78 a 90 s |
| Reforços | 1 golpe ou 2 a 3 s de Cochilo | 2 a 3 golpes |
| Janela de risco (Utahraptor) | 36 s | 90 s (2,5x) |
| Recompensa | Carregar 12 kg | Carregar 40 kg |
| Onde | Mata-baixa (início do M2) | Campina (M1) |

**Decidido: na v0.2 o Dodo é a primeira doma**, porque o jogador já caçou Dodos com a Lança nos minutos 1 a 8 (conhece o bicho e o grupo que foge) e o tutorial vira "mesma presa, outra arma: 2 golpes de Bastão". O **Paquicéfalo passa a segunda doma** (minuto 12 a 20), a primeira que carrega de verdade. **No M1 nada muda** (o Dodo só existe a partir do início do M2; o Paquicéfalo é a única doma). **O que perde:** a vigília de 36 s tensiona pouco (a hipótese H1 se testa com Paquicéfalo e Utahraptor) e a recompensa de 12 kg é fraca [jogar].

*[Histórico, superado em 07/11: Parassaurolofo e Gallimimus fora da v0.2]* Marco: **M1** Paquicéfalo e Utahraptor; **início do M2** **Dodo** (decisão do dono, 06/11); **M2** Triceratops, Parassaurolofo e (Listro no **M4**); Gallimimus M2 Should, **cortável**. Com as quatro primeiras o elenco fecha exatamente o que o plano prevê (2 no M1, mais 2 em CRI-06); com o Gallimimus são 5, **acima** do que o plano permite (3 a 4). Para o M4 (CRI-10, 4 a 5 espécies a mais): **Oviraptor** (Curioso, onívoro, estreia do perfil Mista). **Deinonychus** e **Lystrosaurus** voltam ao catálogo como futuros. Dados em `racao.md`, seção 3. A conduta de cada espécie está em 6.7. Nomes de Ração e ingredientes seguem originais (a família Ração e seus ingredientes são nossos).

**Apelidos.** "Pachycephalosaurus" é longo demais para HUD; usamos **Paquicéfalo**, forma portuguesa já corrente do nome (não é abreviação). Os demais ficam com o nome real. **Parassaurolofo** é a forma portuguesa completa do nome (sem abreviação).

**Base paleontológica e onde o jogo se afasta** [números aproximados da literatura; **conferir antes de publicar texto de jogo**]:

| Espécie | Porte, dieta, comportamento (plausível) | Onde o jogo se afasta |
|---|---|---|
| Paquicéfalo | Bípede de ~4,5 m, algumas centenas de kg, crânio em domo muito espesso; dieta incerta (plantas e talvez frutos e pequenos animais); uso do domo em disputas é hipótese discutida | Revide por cabeçada tratado como fato; aceita baga crua (frutos: plausível); vida e dificuldade são de jogo, não de massa |
| Utahraptor | O maior dos raptores: ~5 a 6 m, da ordem de 500 kg (muito maior que o Deinonychus, ~70 a 100 kg), garra em foice, carnívoro; restos de vários indivíduos num mesmo sítio sugerem grupo, mas caça em bando é hipótese; provável de penas | Papel, vida e mordida de jogo são níveis, não massa (vida base 80, igual à do Paquicéfalo de massa parecida); bando de 1 a 2 e perseguição a 90 px/s não vêm de medição; **arte deve mostrar penas e porte Médio (32 px, 4.2)** |
| *(fora da v0.2)*  Parassaurolofo (M2) | ~9 a 10 m, de 2,5 a 3,5 t, herbívoro, crista tubular oca; a crista como câmara de ressonância e chamado de grupo é hipótese defendida; hadrossauros costumam ser gregários | Tratamos a crista como alarme de grupo (a hipótese como fato); "Covarde" é escolha de jogo, não comportamento medido |
| Triceratops | ~8 a 9 m, de 6 a 12 t, herbívoro, três chifres e gola; marcas de ferida em chifres sugerem combate | Territorialidade e "aviso e investida" são do jogo; nenhum dino de 6 t é domável em 100 s na vida real |
| *(fora da v0.2)*  Gallimimus | ~6 m, centenas de kg, pernas longas, bico sem dentes, onívoro ou herbívoro; sinais de grupos | Fuga de 85 px/s é muito abaixo da velocidade estimada, reduzida de propósito para ser alcançável (calculado em 6.7) |
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
- **Menu de interação, Ir até aqui, Postura (Calma, Guarda, Ataque) e comando de rebanho: 6.11** (a Postura substitui o Temperamento).

### 6.4 Ofícios (função na base)

| Ofício | Quem | Marco | Corte |
|---|---|---|---|
| Carregar (**fora da v0.2**, M4b; o domado tem alforje de 4 slots, 6.13; a fórmula antiga de Peso em kg é histórica) | herbívoro | M4b | Fora da v0.2 |
| Defender (dano de defesa escala com o nível; também protege dormindo na domesticação) | carnívoro | M2 | Essencial |
| Colher (coleta passiva de baga/fibra) | herbívoro | M4 | Cortável |
| (fora da v0.2) Aviso (chamado da crista antes do invasor chegar, a 12 tiles) | Parassaurolofo | M2 Should | Cortável |

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

**Seis tipos (decisão do dono).** Números em tiles de 16 px e px/s; jogador anda a 70 e corre a 120 por 4 s de stamina [calculado, seção 5]. Todos [premissa] a validar. **Revisto 06/11:** Dodo e Parassaurolofo são Covardes na v0.2 (e o Listro no M4); o Curioso fica só com o Oviraptor (M4) e o Medroso é futuro, sem marco.

| Tipo | Percepção | Gatilho | Reação | Velocidade | Termina e volta ao normal |
|---|---|---|---|---|---|
| **Medroso** (**pós-MVP, sem marco**; nenhuma espécie da 0.2 o usa) | 8 tiles | Jogador (ou dino agressivo) a 8 tiles ou menos: **foge ao avistar e jamais revida** | Foge sem revidar | Fuga **85** | Para de fugir ao chegar a 14 tiles do ameaçador ou após 8 s; fica 5 s em alerta; normal quando o jogador está a mais de 12 tiles por 5 s |
| **Covarde** | 6 tiles (vê, mas deixa chegar) | Só ser atacado, ou **um membro do grupo ser atacado a até `alarme_raio_tiles`** (padrão 8; Parassaurolofo 12): **jamais revida e foge** | Susto de 0,8 s parado e depois foge sem revidar | Fuga **75** (a espécie pode ter a sua: Gallimimus e Listro 85) | 10 s ou 16 tiles; normal com o jogador a mais de 10 tiles por 8 s |
| **Curioso** | 7 tiles | Vê o jogador | Aproxima-se até 3 tiles em até 6 s, fica 4 s rondando, afasta-se até 10 tiles; recarga de 30 s. Se atacado: susto de 0,5 s e foge sem revidar | Aproximação 40, fuga **75** | Janela de proximidade de até 10 s; normal após a recarga |
| **Passivo** | 5 tiles (só olha) | Ser atacado | Ignora até então; depois **revida** o atacante | Base da espécie | Encerra após 8 s sem receber dano ou com o atacante a mais de 12 tiles por 5 s |
| **Semi-agressivo** | 8 tiles | Jogador a **4 tiles** ou menos, ou ser atacado | Aviso (postura e rosnado) quando o jogador entra em 6 tiles, 1,5 s antes; depois ataca | Perseguição **90** | Desiste com o alvo a mais de 20 tiles, 5 s sem visão ou 15 s de perseguição; alerta de 5 s e normal após 6 s com o jogador a mais de 10 tiles |
| **Agressivo** | 8 tiles (horizontal) e 5 (vertical), 4.2 | Avista jogador ou dino não aparentado (herbívoros e dinos domados do jogador) | Ataca ao avistar | Perseguição **90** | Desiste com alvo a mais de 20 tiles, 5 s sem linha de visão ou 15 s de perseguição; alerta de 5 s e normal |

Regras comuns:

- **Grupo.** Atacar um membro **chama os outros** a 8 tiles, com atraso de 0,5 s: Covarde e Curioso do grupo fogem; Passivo do grupo revida; Semi-agressivo e Agressivo do grupo atacam. Tamanhos [premissa]: Paquicéfalo 1 a 3, Utahraptor 1 a 2, Parassaurolofo 3 a 5 (alarme a 12 tiles), Dodo 3 a 5 (alarme a 8), Gallimimus 3 a 5, Triceratops solitário. **Dado da espécie** (definição da espécie, a criar; **não** `ResourceNodeDef`, que é nó de recurso): `conduta`, `fugitivo`, `fuga_px_s`, `alarme_raio_tiles`.
- **Abaixo de 25% de vida (6.6).** Todos os tipos fogem na velocidade da fuga do tipo (Passivo, Semi-agressivo e Agressivo na velocidade base), sem revidar. Passivo e Semi-agressivo voltam ao normal 10 s depois com o atacante a mais de 10 tiles; o Agressivo também volta, mas em alerta por 5 s. Vida regenera 1% por segundo fora de combate [premissa].
- **Nocaute.** As faixas de torpor (6.6) valem para todos os tipos: velocidade x0,85 na faixa 2 e x0,65 na faixa 3. Dormindo, **toda Conduta para** (sem fuga, sem revide). Ao acordar o dino volta ao alerta por 5 s, sem agressão imediata.
- **Quem corre, doma?** Simulação 1D de perseguição em linha reta (`conduta_sim.py`, docs/design) [calculado]: o **Covarde** a 85 px/s é nocauteado em ~5 s e 4 golpes por quem corre os 4 s de sprint a partir de 8 tiles. Vale `v_fuga <= 120 - (raio x 16 - 24)/4 = 94 px/s` para o sprint alcançar; a 100 px/s ou mais é impossível só na corrida. Sem stamina de sprint não alcança nunca. Covarde (susto de 0,8 s) e Curioso (susto de 0,5 s) são nocauteados em 2,1 e 2,6 s, pois o susto deixa os golpes 2 a 4 caírem antes de correr. A lentidão por torpor (x0,85 e x0,65) não foi decisiva na simulação em linha reta; ela passa a importar com obstáculo e mudança de direção [jogar]. Sem o susto, o Covarde a 75 px/s seria quase intocável com o bastão.
- **Carnívoro e presa dormindo.** Vale a regra de `racao.md` 11.2 (ronco de 8 tiles). Por tipo: **Agressivo** ataca dormindo no raio de ronco; **Semi-agressivo** só dormindo a 4 tiles ou menos (o território dele); os demais **nunca**. Todo ataque ao dormindo segue as perdas de Eficiência de `racao.md` 11.1.
- **Base.** Agressivo e Semi-agressivo não atravessam parede, porta fechada nem curral: o Agressivo, sem caminho por 2 s, **ataca a peça de bloqueio mais próxima**; o Semi-agressivo só se provocado (8.1).

**Herança para o Temperamento (domesticado)** [proposta, cortável]:

| Conduta selvagem | Temperamento do domado |
|---|---|
| Passivo | Calmo: obedece sempre acima de Afeto 10 |
| Covarde | Arisco: foge de luta em vez de defender até Afeto 40 |
| Curioso | Explorador: segue a 3 tiles e abre caminho; defende mal |
| Semi-agressivo | Territorial: defende a base melhor (dano de defesa +20% [premissa]) |
| Agressivo | Hostil a estranhos até Afeto 40 (6.3) |

**Marco e corte por tipo.**

| Tipo | Espécie | Marco | v0.2 |
|---|---|---|---|
| Passivo | Paquicéfalo | M1 | Essencial |
| Agressivo | Utahraptor | M1 | Essencial |
| Semi-agressivo | Triceratops | M2 | Essencial (3ª espécie) |
| (fora da v0.2) Covarde | Gallimimus (4ª) | M2 | **Cortável** (4ª espécie é Should) |
| Curioso | Oviraptor | M4 | Fora da 0.2 |
| (fora da v0.2) Covarde | Parassaurolofo | **M2 (antecipado do M4)** | Essencial (4ª espécie) |

**Quantos tipos a v0.2 mostra (atualizado 07/11):** **4 tipos com 4 espécies**: Passivo (Paquicéfalo), Agressivo (Utahraptor), Semi-agressivo (Triceratops) e Covarde (Dodo). Parassaurolofo e Gallimimus ficam fora da v0.2 **[provisório, aguarda o dono]**. O texto do "5 tipos com 5 espécies" de 05/11 é histórico.

*[Histórico, superado em 07/11: Parassaurolofo e Gallimimus fora da v0.2]* **Avaliação: Parassaurolofo como Covarde.** *Encaixe:* o Covarde só reage quando atacado e o alarme de grupo é a regra "atacar um membro chama os outros"; um herbívoro de manada com crista sonora conta exatamente essa história. Para o Parassaurolofo o raio do alarme é **12 tiles** em vez de 8, só por dado (`chama_grupo.raio_tiles`). *Conta* (`conduta_sim.py`, [calculado]): com torpor 140 o Covarde a 75 px/s e susto de 0,8 s é nocauteado em **3,5 s com 6 golpes** (4 golpes e 2,1 s com torpor 100); não exige sprint. Ao atacar um da manada de 3 a 5, os demais fogem juntos, e só o alvo precisa ser perseguido. *Custo de antecipar o Covarde do M4 para o M2:* uma linha de dados no `ConductaDef` e o estado "susto" de 0,8 s (que a máquina de estados genérica já prevê); a fuga é a mesma primitiva já usada pelo Covarde e pela fuga de 25% de vida; mais animações (pose de susto, tremor, corrida, chamado) e testes por tipo [sem estimativa; é dado + arte]. Se o Gallimimus for cortado, a primitiva de fuga continua necessária pelos 25% de vida. *Alternativas:* Covarde (duplicaria o Gallimimus e exigiria a perseguição em corrida, pior para uma espécie de 3 t), Passivo (duplicaria o Paquicéfalo), Curioso (não casa com o alarme). **Recomendo manter o Covarde.** Ofício "Aviso" (o chamado da crista antes do invasor, a 12 tiles) passa a M2 Should, cortável.

**Estrutura sugerida para o `SORA` (dados, sem estados soltos no código).**

- `ConductaDef` (recurso por espécie): `tipo`, `percepcao_tiles`, `gatilho_tiles`, `aviso_s`, `susto_s`, `velocidade_fuga`, `velocidade_perseguicao`, `fuga: {duracao_s, distancia_tiles, alerta_s, normal_apos_s}`, `curiosidade: {aproxima_s, fica_s, distancia_tiles, recarga_s}`, `revida` e `revida_duracao_s`, `chama_grupo: {raio_tiles, atraso_s}`, `desiste: {distancia_tiles, sem_visao_s, perseguicao_s}`, `ataca_dormindo` (`nunca|gatilho|ronco`), `alvos_dino`, `pesos_por_bioma`.
- **Uma máquina de estados genérica** (Normal, Alerta, Aproximando, Fugindo, Revidando, Perseguindo, Aviso) movida por **eventos** (`viu_jogador(dist)`, `atacado`, `perto_demais`, `perdeu_alvo`, `timeout`) e por uma **tabela de transições por tipo em dados**, em cima do `DinoStateMachine` atual. Nada de `if especie == ...` no código.
- Servidor decide tudo; replicar o id do estado (3 bits) e o alvo. Percepção por checagem de raio a cada 0,5 s [premissa de custo: dino x jogador, cabe até o M3; chunk e interesse no M4].
- Testes headless por tipo: cada linha da tabela vira um caso (gatilho, duração, volta ao normal), mais o caso de grupo e o de 25% de vida.

**Animação e áudio para o `YATORA`.** Por tipo: **Covarde** alerta com cabeça erguida, corrida de fuga, respiração ofegante; **Covarde** pose de susto parado, tremor, corrida; **Curioso** aproximação com cabeça inclinada, farejar, recuo; **Passivo** pastar, levantar a cabeça, empurrão de revide; **Semi-agressivo** postura de aviso (crista ou cauda erguida) e rosnado de 1,5 s, investida; **Agressivo** espreita, investida, ataque, farejar presa dormindo. Comuns: bocejo, cambaleio, mancar abaixo de 25% de vida, dormir. Ícones sobre a cabeça: "!" (hostil), "?" (curioso), gota (medo). Sons: grito de alerta que dispara o grupo, rosnado de aviso, rosnado de investida.

**Conflitos com o plano (novos):** ver itens 13 a 17 da seção 17.

### 6.8 Morte do dino

Dino sendo domado com vida 0 **morre** e a domesticação falha (racao.md 11.3). Dino domado com vida 0 fica **ferido** (com morte permanente de servidor, deixa carcaça e sacolinha do alforje: 5.6) e some por 5 min [premissa] para a base (não morte permanente na 0.2). Morte permanente é opção de servidor (seção 13). Estado Dead existe no plano (SOB-02). M2, Essencial na forma branda. **M4b (decisão do dono):** o dino domado a 0 de vida deixa um **corpo com os itens do alforje por 10 min** (dado `corpo_minutos`; o ferido some 5 min e volta sem itens, que seguem no corpo por mais 5); na 0.2 vale o texto acima (alforje no lugar, 5.1).

### 6.9 Nome do dino [decisão do dono]

Ao concluir a domesticação abre um campo para **batizar**; **pular mantém o nome da espécie**. O dono **renomeia** depois no painel do dino. Nome salvo no dino e exibido no painel e na lista do grupo. **Regras (servidor):** até 20 caracteres, texto limpo (sem marcação de formatação, sem caracteres de controle, espaços aparados e repetidos reduzidos), validado como pedido do dono; vazio volta ao nome da espécie. Limite de renomeação: 1 a cada 5 s [premissa]. **Marco M2** (junto da lista do grupo e do painel). **Filtro de palavras:** opção de servidor (`filtro_nomes`, lista de arquivo), fora do MVP.

### 6.10 Ajuste D17 (proposta da SHIRO): Listro e Clareira-brasa

*[Histórico, superado em 07/11: Parassaurolofo e Gallimimus fora da v0.2]* - **Listro como Covarde (decisão do dono, 06/11: o Medroso é conduta futura).** O Parassaurolofo já é o Covarde; o Listro (pequeno, escavador) usa o mesmo tipo, com fuga própria de 85 px/s depois de atacado e sumindo em toca (dado `fuga_px_s` por espécie). No M4 a Conduta tem **5 tipos** na prática (Passivo, Agressivo, Semi-agressivo, Covarde e o Curioso do Oviraptor e do Dodo); o **Medroso** (6.7) fica definido e **sem marco**. Gallimimus fica cortável.
- **Clareira-brasa sai do M4.** Perdeu a Seiva (trocada pelo Orvalho produzido por dino) e a Ração S (cortada); sobra só "bioma de nível alto", que a **Pedreira** cobre estendendo a faixa de 15 a 35 para 15 a 45. Fica com 3 biomas (Campina, Mata-baixa, Pedreira). **Custo:** MUN-11 e SOB-10 encolhem; o carnívoro territorial passa a viver na Pedreira. **Risco:** perde-se um destino de prestígio; compensa-se pelo ofício Produzir e pelo nível alto.

### 6.11 Menu de interação do domado, comandos e Postura (decisão do dono, 06/11)

> **Atualizado em 08/11 (dono): o E nunca dá ordem a dino.** O E pega item no chão, depois nó de recurso, depois estrutura, depois criatura (num domado meu abre o menu de opções, que também sai por clique direito ou Shift+E, a até 2 tiles). As ordens Seguir/Ficar saem do menu e da tecla **G** (alterna o domado mais perto; o log diz "Rex: seguindo" ou "ficando"). Inventário do domado: pelo menu.

> **Atualizado em 07/11:** na v0.2 só existe o modo **Neutro** (ajuda no combate, 6.11b), fixo; a Postura de 3 modos e o "Ir até aqui" seguem depois do playtest.

**O que já existe (não duplico):** ordens **Seguir e Ficar (M1)**, **Atacar o alvo e Guardar a base (M2)** e a obediência por Afeto (6.3); ofícios **Carregar** e **Defender** (6.4); a **tela de inventário do dino por E**, só para o selvagem dormindo em doma (5.14); o alforje (5.1). **O que não existe:** um menu para o dino domado (no código de hoje `can_interact` só aceita criatura selvagem inconsciente: conferido, só leitura), o comando "ir a um ponto" e a Postura. A Postura **substitui o Temperamento do domado** (cortável, 6.3).

**Nomes, sem conflito.** **Conduta** é só do **selvagem** (Passivo, Agressivo, Semi-agressivo, Covarde e Curioso na v0.2; o Medroso é futuro, sem marco; 6.7). Para o **domado** há **ordens** (onde ele fica) e **Postura** (como reage). **Decidido (dono, 06/11): o jogador vê Passivo (pena branca), Neutro (escudo verde, padrão) e Agressivo (raio vermelho)**, com legenda no menu (6.11b); os ids de dado seguem `calma`, `guarda` e `ataque`, e as tabelas abaixo usam esses nomes. No texto, **"modo" é do domado e "Conduta" é do selvagem**: Passivo e Agressivo da Conduta (6.7) são outro conceito, com o mesmo nome por escolha do dono.

**Menu de interação (tecla E, a até 2 tiles de um domado seu):** lista vertical **Montar/Desmontar (6.12), Alforje, Seguir/Ficar, Ir até aqui, Postura**; linha sem condição fica cinza com o motivo ("Afeto baixo"). Selvagem inconsciente e dino dormindo em doma continuam abrindo a tela atual, sem menu. **O menu entra antes da montaria:** as linhas Montar e Ir até aqui só aparecem quando existirem.

**Ordens de movimento:** Seguir (fica a 3 tiles) e Ficar já existem. **Ir até aqui [novo]:** escolher no menu e **clicar no chão a até 15 tiles do jogador** (marcador no ponto); o dino anda por navegação e **fica** lá; sem chegar em 20 s, fica onde estiver. **Guardar a base (6.3) = Ficar + Postura Ataque num raio de 12 tiles** e o ofício Defender (6.4) é o mesmo para carnívoro: **sem lógica própria**, a Postura dá o conteúdo.

**Postura (como reage; vale em Seguir e em Ficar):**

| Postura | Com o jogador e seus dinos | Com selvagens | Com outros jogadores |
|---|---|---|---|
| **Calma** (o "passivo" do pedido) | segue a ordem | **não ataca nem revida**; selvagem hostil ainda o ataca | nunca ataca |
| **Guarda** (o "neutro"; **padrão**) | revida quem o ataca e quem ataca o dono ou outro domado do dono, persegue até 8 tiles e volta | só revida | nunca ataca |
| **Ataque** (o "agressivo") | igual à Guarda | **inicia** combate contra **todo selvagem dentro do alcance de visão da espécie** (percepção da Conduta, 6.7), de qualquer Conduta (decisão do dono, 06/11; pós-MVP); **em Seguir também**: sai, ataca até perder o agro e volta a seguir. Nunca contra selvagem inconsciente; o domado **Fugitivo** foge em vez de atacar (6.11b). Limites na 6.11b (V79) | nunca ataca |

**Regras comuns:** **sem PvP e sem fogo amigo: dano entre domados e contra jogadores é 0**; o domado **nunca ataca selvagem inconsciente** (domar: preserva a Eficiência, `racao.md` 11); **nunca danifica construção** e só passa por **Portão de dino** (8.1). Espécie sem dano tem o traço **Fugitivo** (6.11b): Neutro e Agressivo viram "foge" (dado `posturas_permitidas`: Paquicéfalo, Utahraptor e Triceratops lutam nas três; Parassaurolofo e Gallimimus têm as três, mas só o Passivo fica parado). **Afeto:** abaixo de 10 ignora comando; de 10 a 25 falha 30% **só** em Seguir, Ir até aqui e Atacar o alvo (comandos dados na hora); **Ficar e a troca de Postura sempre valem** (são configuração).

**Alcance, grupo, co-op:** menu a 2 tiles; Ir até aqui a 15 tiles; **comando de rebanho (tecla Q, sem chegar perto): Seguir todos, Ficar todos e Postura de todos**, nos domados do dono a até **12 tiles**, exceto o montado e o ferido (Ir até aqui em grupo fica fora). **Permissão `dino_permissao`: `dono` (padrão: só o dono comanda, monta, muda Postura e põe sela) ou `grupo` (qualquer jogador do grupo)**; **o alforje é aberto ao grupo sempre** (cooperativo, como a sacolinha). O servidor valida `comandar_dino(id, ordem, arg)`: alcance, dono, Afeto, estado.

**Relações:** **cocho** (5.12; **fora da v0.2**): em Ficar a até 6 tiles do cocho o dino come; Postura não muda isso. **Ofícios:** Carregar exige Seguir (6.3, sem mudança). **Fome 0:** o dino segue obedecendo, com a queda de Afeto de 5.12.

**Marco:** menu de interação (Seguir/Ficar e Alforje, com ganchos); Ir até aqui; Postura de 3 modos; comando de rebanho; permissão. **Decidido (dono, 06/11) na v0.2 (M2): menu + Seguir/Ficar todos + permissão** (o alforje precisa de acesso e hoje o domado não abre nada). **Decidido: depois do playtest, Ir até aqui e Postura** (a v0.2 já tem Atacar o alvo e Guardar a base, que cobrem o uso). **Sprites:** nenhum (a mudança aparece no `FloatingText`: "Calma", "Guarda", "Ataque"); opcional 1 marcador de destino. **Precisa jogar:** se Seguir/Ficar basta sem Postura; se o comando de rebanho é preciso com 2 ou 3 dinos.

### 6.11b Placa sobre o dino domado, modos e estados (regra do dono, 06/11; marco abaixo)

**Placa.** Acima do dino domado, de cima para baixo: **nome** (6.9; mostra até 12 caracteres, o resto vira ponto) com **"Nv N"**; depois a **barra de vida** (a barra mini do pacote, 18x4) e, **lado a lado à direita da barra, os símbolos de 8x8** na ordem modo, Seguindo, Sobrepeso (no máximo 3). O menu de interação (6.11) tem uma **legenda** com os mesmos símbolos e seus nomes.

**Modos** (o mesmo sistema da Postura de 6.11, sem sistema paralelo; troca sempre vale, o padrão é Neutro):

| Modo (símbolo) | id | Efeito |
|---|---|---|
| **Passivo** (pena branca) | `calma` | não reage a agressões |
| **Neutro** (escudo verde), padrão | `guarda` | revida agressão feita por selvagem a ele, ao personagem ou a dino aliado |
| **Agressivo** (raio vermelho) | `ataque` | ataca **todo selvagem dentro do alcance de visão da espécie** (percepção da Conduta, 6.7), seja qual for a Conduta dele; **em Seguir também**: sai, ataca até perder o agro e volta a seguir o dono (decisão do dono, 06/11; pós-MVP). Regras comuns de 6.11 seguem: nunca ataca selvagem inconsciente; o domado Covarde (traço Fugitivo) foge em vez de atacar. Limites logo abaixo (V79) |

**Estados:** **Seguindo** (símbolo de **alvo**; **[assumido]**: o dono falou em escudo e em alvo para Seguir, e o escudo verde já é o Neutro) e **Sobrepeso** (símbolo de **peso**; só existe com a carga em faixas, 5.1b, **M4b**).

**Fugitivo (covarde e medroso são o mesmo traço no domado).** Na Conduta selvagem (6.7) o **Covarde** só foge ao ser atacado e o **Medroso** (futuro) foge ao avistar o jogador; nenhum revida. O texto do dono para o **domado** é o mesmo para os dois: **não ataca; corre ao presenciar agressão a ele ou a aliados**. Unifico em um traço de espécie, `fugitivo = verdadeiro`, vindo da Conduta Covarde (ou Medroso, quando existir); não é do indivíduo. **Na v0.2:** **Parassaurolofo (Covarde)** e, se a 5ª espécie ficar, **Gallimimus (Covarde)**; Paquicéfalo (Passivo), Utahraptor (Agressivo) e Triceratops (Semi-agressivo) não têm. Dodo (Covarde, domável, 6.1b) tem os três modos e o traço `fugitivo`; o Listro (M4) também. O alarme de grupo vale para o domado também: "aliados" são os dinos do dono, e o raio é o `alarme_raio_tiles` da espécie (Parassaurolofo 12). `fugitivo`, `fuga_px_s` e `alarme_raio_tiles` são **dado da espécie**, não do `ResourceNodeDef` (nó de recurso). **Comportamento:** Passivo, o fugitivo fica (não reage); Neutro e Agressivo, ele foge: reusa a fuga do Covarde (6.7), susto de 0,8 s, 75 px/s (85 no Gallimimus), até 10 s ou 16 tiles do agressor, e volta ao dono (Seguindo) ou ao ponto (Ficar). "Presenciar" = a até 8 tiles (a mesma distância do chamado de grupo, V18).

**Alcance e limite do Agressivo (para não puxar briga pelo mapa)** (decisão do dono, 06/11, V79; pós-MVP): vale para **qualquer selvagem**, inclusive presa como Dodo e Paquicéfalo, e **para qualquer nível**: o domado pode enfrentar selvagem muito mais forte e **pode morrer** nisso. Distância em **linha reta, em qualquer direção** (círculo em volta do ponto de referência, não caminho a pé). **Perde o agro** quando o alvo morre, foge ou sai da visão, ou nos limites abaixo. **Começa a luta só contra alvo no alcance de visão do dino** (6.7) **e dentro de 12 tiles do ponto de referência**, que é o **dono** em Seguir e o **ponto onde ficou** em Ficar (o mesmo raio de 12 do Guardar a base, 6.3). **Persegue até 12 tiles do ponto de referência e desiste** com o alvo além de 14 tiles, após **10 s de perseguição** (o selvagem Agressivo desiste em 15 s) ou **5 s sem linha de visão**; volta ao dono. Um alvo por vez. O Neutro revida e persegue até 8 tiles, como já está. Assim a briga acontece onde o dono está, nunca longe dele.

**Atualizado em 07/11 (decidido): o domado em Neutro ajuda no combate** (revida agressão feita por selvagem a ele, ao dono, inclusive caído, e aos aliados; persegue até 8 tiles e volta; nunca ataca selvagem inconsciente). **Na v0.2 o Neutro é fixo, sem seletor de postura** **[provisório, aguarda o dono]** (sem símbolos de modo); o Agressivo segue pós-MVP (V79). **Marco** (decisão do dono: regra nova vai para depois do MVP, sem horas): a **placa completa e os símbolos de modo e Seguindo** ficam **depois do MVP, junto da Postura** (que já é depois do playtest, 6.11); o **Sobrepeso**, no **M4b**, com a carga em faixas. **A v0.2 não perde nada:** mantém a barra mini de vida e o `FloatingText` (6.11). **Dependências:** o nome e o nível já existem na v0.2 (6.9 e 6.6, M2), então a placa em si não depende de nada que falte; os **modos** dependem da Postura, os símbolos de **Seguindo** do comando Seguir (M1) e o **Sobrepeso** da 5.1b. O traço Fugitivo precisa da Postura para existir como escolha, mas a fuga ao ser atacado já é a Conduta Covarde da 6.7.

**Ícones 8x8 para o `YATORA`** (contorno de 1 px `#141b1b`, 3 tons por forma, fundo transparente, formas distintas além da cor, para quem não distingue cores; os mesmos servem na legenda do menu, ampliados 2x):
1. **Passivo:** pena branca.
2. **Neutro:** escudo verde.
3. **Agressivo:** raio vermelho.
4. **Seguindo:** alvo (mira).
5. **Sobrepeso:** peso (M4b).

### 6.12 Montaria (decisão do dono, 06/11 e 07/11; entra na v0.2 em versão mínima, sem sela)

> **Atualizado em 07/11 (decidido):** é possível **montar em dinos de porte Médio ou maior, sem sela**. **Entra na v0.2** (a frase "depois do playtest" não vale mais). **Provisório** **[provisório, aguarda o dono]**: só **Utahraptor e Triceratops** montam; **sem ataque montado** (montado o dino não luta nem revida; o jogador não usa arma; o dano vai todo ao dino e o jogador é imune); **sem Stamina do dino**; requisitos: dono, Afeto >= 25, dino acordado e não ferido (sem exigência de fome nem de nível); velocidade da espécie x 1,3; desmontar pelo menu em 0,3 s; o desmaio por torpor também derruba; não entra em abrigo; ao salvar e carregar desmonta; sem rede (host local), com `request_mount` e `request_dismount` validados. Arte: pose de torso sentado em 4 direções (placeholder). **A tabela e os requisitos abaixo, que falam de sela obrigatória, estão superados.**

#### Histórico (superado em 07/11)

O texto abaixo é o desenho anterior. **Não o implemente**; vale o resumo acima.

Já dito antes (não duplico): a Stamina do dino **espera a montaria** (5.1, M4) e o Peso do dino **não soma** ao do jogador. **Nada mais sobre montaria existia.** Simulação: `montaria_sim.py velocidade|duelo`.

**Quais espécies montam (dado `montaria`: `nenhuma`, `livre` ou `sela`):**

| Espécie | Montaria | Motivo |
|---|---|---|
| Dodo, Listro (M4), Oviraptor (M4) | **não montável** | porte pequeno ou diminuto; domáveis para Carregar e Colher (6.1b); Oviraptor a definir no M4 |
| Paquicéfalo | **não montável** | pequeno; é o dino de Carregar (40 kg) |
| Utahraptor | **montável sem sela** (Médio) | rápido, **não carrega** (Peso 0): não há inventário nem defesa a expandir; **não tem vaga de sela** |
| Parassaurolofo | fora da v0.2 | sai do elenco da v0.2 (6.1) |
| Triceratops | **montável sem sela** (Grande) | porte Grande; é a segunda montaria da v0.2 **[provisório, aguarda o dono]** |

**Requisitos de montar:** ser o dono (ou grupo, `dino_permissao`), **Afeto >= 25** (o limiar de "obedece sempre", 6.3), dino **acordado e não ferido** (atualizado em 07/11: sem sela, sem requisito de fome do dino). **Sem exigência de nível** (o nível é de evolução; um segundo portão não acrescenta decisão).

**Controle e velocidade:** WASD move o dino, a câmera o segue, o jogador **sai do mundo** (sem colisão própria). **Velocidade montada = velocidade da espécie x 1,3** (`montaria_velocidade_mult` [premissa]), **sem sprint e sem custo de Stamina** (nem do jogador nem do dino; a Stamina do dino segue reservada). Conta (`montaria_sim.py velocidade`; velocidades de espécie de 6.7 como proxy): Parassaurolofo 97,5 px/s, Utahraptor e Triceratops 117; jogador anda 70 e **corre ~86 sustentado** (120 só em rajada de 4 s). **40 tiles: 9,1 s a pé, 7,5 correndo, 6,6 (Parassaurolofo) ou 5,5 s (Utahraptor e Triceratops) montado: +14% e +37% sobre correr.** **Sem o x1,3 a montaria seria mais lenta que correr** (75 a 90 contra 86); o ganho real é **andar sem gastar Stamina**. **Peso:** o cavaleiro não pesa e o alforje segue acessível montado. **Carga (5.1b, M4b):** a velocidade montada multiplica pela faixa de carga do alforje; em 100% o dino não anda.

**Ataque e dano:** o botão de ataque faz **o dino atacar** (dano e intervalo da espécie, 0 de torpor); o jogador **não usa arma nem ferramenta montado** (guardadas, sem coleta); **não ataca criatura inconsciente** (domar). `montaria_sim.py duelo`: Utahraptor L20 montado contra um selvagem igual, 7,5 dps contra 7,5 dps, 126 de vida: **17 s e empate**; contra Dodo 3 mordidas (3 s). **Dano ao montado: vai todo ao dino** (com a defesa da sela, 6.13), o **jogador é imune e a armadura dele não vale montado**; `dano_final = max(1, dano x (1 - min(0,5, defesa)))`.

**Desmontar:** voluntário pelo menu (E), ao lado do dino, em tile livre, 0,3 s. **À força:** dino **ferido** (vida 0): o jogador cai ao lado, **atordoado 1 s [premissa], sem dano**, e o dino some 5 min (6.8); **desconexão** do jogador desmonta no servidor; **sela quebrada com o jogador montado não derruba** (monta de novo só depois do reparo). **Fome 0** do dino impede montar, não derruba.

**Co-op:** **um cavaleiro por dino, sem garupa** (v1); `rider_id` no servidor; outro jogador do grupo ainda abre o alforje. **Ofícios:** montado, o dino **suspende Defender, Guardar a base e Colher**; Carregar continua. **Afeto:** montar não o altera. **Cocho:** o dino montado **não come do cocho** (o jogador conduz); come do alforje com fome <= 25 como sempre. **Construções:** usa a colisão do dino: **não entra em Abrigo** (porta de jogador), **entra no curral e passa pelo Portão de dino**; não danifica construção.

**Rede (o mais caro):** a **autoridade do movimento do dino montado passa ao cliente do cavaleiro**; o servidor valida velocidade (<= 1,3x + tolerância), colisão e o ataque (alcance e intervalo); `rider_id` replicado; reconexão desmonta; pedidos `montar(dino_id)` e `desmontar()`. **Sprites: nenhum novo.** O jogador aparece **pequeno sobre o dino, reaproveitando o frame parado dele**, filho do sprite do dino, com **deslocamento por espécie e direção** (3 espécies x 4 direções = 12 valores em dados); sem animação de montar.

**Marco:** controle e câmera; velocidade, colisão e Portão; montar, desmontar e desmonte à força; dano ao montado; ataque montado; HUD (vida do dino no lugar da do jogador); rede; offsets do jogador. **Menor recorte** (sem ataque montado e só Utahraptor e Parassaurolofo). **Atualizado em 07/11: entra na v0.2 (E19a e E19b), versão mínima acima.** Antes: depois do playtest (M4), superado: (1) já coincide com "Stamina do dino espera montaria"; (2) a v0.2 tem Peso, validade, vagas e Mochila a provar; (3) o ganho de velocidade só existe com o x1,3 [premissa] e precisa ser sentido; (4) a rede é o maior risco. **Precisa jogar:** se +14% a +37% justificam montar; se o dano ao montado sem armadura do jogador cria um "escudo" fácil.

### 6.13 Alforje do dino, 4 slots, e selas (direção futura; texto de sela MARCADO PARA REESCRITA no M4b)

> **Atualizado em 07/11 (decidido).** **Dino sem sela tem 4 slots** (o alforje, `accepts_individual = false`). **Depois do MVP haverá selas de carga e selas de trabalho**; sem selas no MVP e sem números definidos. **A sela deixa de ser obrigatória para montar (6.12).** O texto a seguir (sela só para Parassaurolofo e Triceratops, bônus de Peso extra em kg, defesa por material fibra/couro/metal, três receitas) é o desenho **antigo, SUPERADO**, e será **reescrito no M4b** junto da CRI-46; **não o implemente.** Conflitos conhecidos: o alforje agora é em slots, não em kg; a direção nova é por função (carga e trabalho), não por defesa; todo domado tem alforje de 4.

#### Histórico (superado em 07/11)

O texto abaixo é o desenho anterior. **Não o implemente**; vale o resumo acima.

**Só as espécies "montável com sela" têm sela** (Parassaurolofo e Triceratops). **O Utahraptor (monta sem sela), o Paquicéfalo e as presas não têm vaga de sela e não recebem bônus de inventário nem de defesa** (correção do dono). A sela **é obrigatória** para montar nas duas espécies (6.12).

**Valores [premissa a testar]. Uma sela serve às duas espécies (porte único); o bônus escala pela espécie pelo Peso dela.**

| Material | Peso extra do alforje | Defesa | Durabilidade | Receita | Saber | Estação | Peso na mão |
|---|---|---|---|---|---|---|---|
| **Fibra** | +20% | 8% | 100 | 20 fibra + 4 madeira | 1 | Mãos | 3 kg |
| **Couro** | +40% | 15% | 150 | 10 couro + 6 fibra | 2 | Mãos | 6 kg |
| **Metal** | +60% | 25% | 300 | 4 barra + 6 couro | 4 | Bancada | 10 kg |

*[Histórico, superado em 07/11: Parassaurolofo e Gallimimus fora da v0.2]* **Alforje com sela (Peso base x (1+0,03(L-10)) mais o extra; `montaria_sim.py` e conta):** **Parassaurolofo L20: 130 kg; fibra 156, couro 182, metal 208.** **Triceratops L24: 170 kg; fibra 204, couro 239, metal 273.** O extra é Peso do alforje (a única regra de carga do dino, 5.1); sem sela de metal, 3 abrigos (114 kg) já cabem numa viagem do Parassaurolofo L20; **o ganho só se vê em obra grande: precisa jogar** (se não, converter em slots depois da Mochila). A sela pesa só na mão do jogador; **no dino não conta**.

**Defesa e dano mínimo 1:** a defesa é uma redução como a do jogador: `dano_final = max(1, dano x (1 - min(0,5, defesa)))` para ataque com dano base >= 1; dano 0 (torpor) segue 0; o teto de 50% **nunca é atingido** (máximo 25%, trava para o futuro). Conta (Utahraptor selvagem, mordida 11,25): **sem sela 11,25; fibra 10,35; couro 9,56; metal 8,44**. O mínimo só muda dano base abaixo de 1,33 (com 25%). **Independe da armadura do jogador** (montado ela não vale, 6.12).

**Durabilidade e reparo:** 1 por golpe **sofrido pelo dino** (montado ou não, inclusive o que caiu a 1), 100 / 150 / 300 (couro dura 150 golpes de Utahraptor = 3,8 min de luta). **Reparo na Bancada, com a sela fora do dino:** `ceil(50% do material x fração que falta)`, **sem reduzir o máximo** (5.9). **Sela quebrada (0): defesa 0, não monta e o extra de Peso se suspende; o que já está no alforje fica (o alforje só trava novos itens, a regra de 5.16) e o jogador montado não é derrubado.**

**Conflito resolvido: vaga própria.** O alforje tem `accepts_individual = false` (conferido no código) porque item individual nele **some da barra do jogador e não volta a ser achado**; a sela é individual (`{id, iid, durab, durab_max}`). **Proposta: uma vaga de sela no dino domado, fora do `InventoryComponent`**; o alforje continua recusando individual (o Bastão segue protegido). A vaga é um campo do dino (`sela`), salvo com ele, **só existe nas espécies `montaria: sela`**; a tela do dino (E, aberta do menu pelo "Alforje") mostra a vaga acima da grade; **equipar = arrastar a sela do inventário do jogador para a vaga**; **sela não vai à barra de atalhos** (como a roupa). Quem equipa: o dono (ou grupo, `dino_permissao`); o dino **não montado**, a até 2 tiles.
- **Retirar:** arrastar de volta ao inventário (ou duplo clique na vaga); **recusa** se o alforje estiver **acima do limite sem o extra** ("Esvazie o alforje") ou se o inventário do jogador estiver **cheio** ("Inventário cheio"); nada se perde. É a mesma regra da Mochila (5.21).
- **Dino ferido** (padrão da 0.2, 6.8): a **sela fica no dino**, com o alforje, e volta com ele aos 5 min.
- **Dino morto (morte permanente, opção de servidor):** a sela vai à **sacolinha** da carcaça (5.6) com os itens do alforje, **durabilidade preservada**, **só do dono por 120 s**, depois de todos; a sacolinha **aceita item individual** (o jogador a coleta no mundo; só a criatura recusa).
- **Save e rede:** o dino salva `sela`; versão do save sobe; `equipar_sela(dino_id, iid)` e `retirar_sela(dino_id)` validados no servidor (alcance, dono, espécie com sela, dino não montado, Peso do alforje).

**Receitas e totais (`receitas_sim.py arvore`):** **três receitas, um nó cada** (fibra Saber 1, couro 2, metal 4): **+3 receitas e +7 Saber.** Com a Mochila provisória (5.21: 1 receita, Saber 2): **1.0 com 59 receitas e 84 Saber, completa no L70** (com Saco e Cama, 12.3; antes 57 e 82, L69; 53 e 73, L61). **v0.2 não muda (21 e 22).** Marco: **junto da montaria (depois do playtest)**; fibra e couro **M4+**, metal **M5**. O couro ganha mais um uso (Mochila e selas).

**Escopo:** item e receitas em dados; vaga de sela no dino e tela (arrastar, retirar com regras); defesa e durabilidade por golpe no dino, com dano mínimo; extra de Peso, trava e recusa; sacolinha com individual na morte permanente; save e rede. **Montaria e sela juntas: versão cheia ou recorte (só dois dinos e sela sem metal)**, **ambas depois do playtest.** `SORA`, lista: `montaria` (nenhuma|livre|sela) em `SpeciesDef`; `sela` como vaga do dino; menu de interação; `dino_permissao`; autoridade do movimento do montado; `rider_id`; defesa do dino com `max(1, ...)`; sacolinha aceitando individual. `YATORA`: 3 ícones de sela e silhueta da vaga; **sem sprite de sela sobre o dino** (recomendo, V73) e 12 deslocamentos do jogador (dado). **Precisa jogar:** se a sela como obrigatória nos dois grandes dá objetivo ou só barreira; se o extra de Peso aparece; se a vaga na tela do dino é achada.

## 7. Coleta e crafting

- **Coleta:** nós de árvore, pedra, arbusto de baga, fibra, com respawn (MUN-02). **Na ilha (`mapa-ilha.md` 8):** toda árvore é coletável (decisão do dono, 06/11; antes 1 em 4), com nó que some ao esgotar (4.1); **arbusto único** (`bush`) rende fibra e a fruta do seu tipo (Baga ou Cochilo) numa colheita e a planta de fibra separada some do mapa; Samambaia, Tubérculo e Sal-de-veio são nós novos; o **filão de ferro** é M4 (metal, `receitas.md` 6). Tempos [premissa]: baga 3 s/unidade, madeira 8 s por 3, pedra 10 s por 4.
- **Crafting (atualizado em 07/11 **[provisório, aguarda o dono]**: a v0.2 fecha em 17 receitas (8 conhecidas, 9 aprendidas); saem Pilão, Preparado de sono, Bandagem, Cocho, curral e Portão; o número de 21 abaixo é o anterior):** `RecipeDef` por dados, **21 receitas na v0.2 (22 Saber; inclui Saco e Cama, 12.3)** (4 conhecidas: Fogueira, Lança de madeira, Machado e Picareta; o Bastão-de-sono já nasce no inventário no M1, sem receita; o resto por Saber, `receitas.md`). **Estações: Mãos (menu P; fibra, madeira e pedra), Bancada comum (metal e engenharia, Ração e reparo), Fogueira (assar) e o **Pilão** (portátil).** Regra de produção em 5.19. Sem timers de espera (espera sem decisão é defeito).
- **Receitas núcleo** [proposta]: Bastão-de-sono no inventário (M1, sem receita; receita de reposição Saber 1 no M2), **Preparado de sono** (3 frutas + 1 carne podre rendem 3, 4 s, **no Pilão, 5.18**; M2, aceito), Ração C a A (Bancada), fundação, parede, porta, baú (à mão).
- Tier 1: madeira, pedra, fibra, baga. Tier 2: Tubérculo, Sal, Mel (risco). Tier 3 (M4): Seiva, receitas de dino grande.

M1: coleta e arma de torpor. M2: tudo acima. **Cortável:** Mel e Ração S (racao.md, seção 2.4).

## 8. Construção e base

Grade de 16 px por `Vector2i` (CON-01). Peças da 0.2: fundação, parede, porta, baú (CON-02/03) e **Cama** (12.3, M2). Propósito (pilar 3): **abrigo** contra noite/predador, **guardar** (baú), e **ponto de ofício** dos dinos.

Conta do abrigo mínimo [premissa de custo]: 2x2 = 4 fundações (3 madeira + 1 pedra), 8 paredes (2 madeira), 1 porta (4 madeira + 1 fibra) = 32 madeira, 4 pedra, 1 fibra. Coleta ~8 s por 3 madeira: 32 madeira = 85 s de coleta + 20 s de pedra + caminhada: ~3 a 4 min de jogo [calculado com premissas]. Cabe na primeira hora.

M2 Essencial. Reparo de **peça** por ação: **cortado** (a peça tem vida e regenera: 8.1). Durabilidade de **item**: existe (5.9). Telhado, eletricidade: fora.

### 8.1 Dano em construções (decisão do dono, 06/11)

**Regra do dono:** dinos causam dano em construções de forma **decrescente: palha recebe mais que madeira; pedra recebe 0**. **Metal fica fora por agora**: nenhuma estrutura de metal. Simulação: `estruturas_sim.py`.

**Vida por peça [premissa]:** 30 por unidade de madeira, 10 por unidade de palha, pedra imune. Alvos: **parede, porta, cerca e portão**; fundação, baú e mobílias **não são alvo**.

| Peça (custo em madeira) | Palha | Madeira | Pedra |
|---|---|---|---|
| Cerca (2) e parede (2) | 20 | 60 | imune |
| Porta e portão de dino (4) | 40 | 120 | imune |

**Dano por espécie [premissa]:** `mordida / cooldown x fator`. Utahraptor L20: 11,2 / 1,5 s x **1,0** = **7,5/s**. Triceratops L28: 34,4 / 2,5 s x **2,0** (chifre e investida) = **27,5/s**. Passivo (Paquicéfalo), Covarde (Parassaurolofo), Curioso e dino domado: **0**, nunca atacam peça.

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

**Marco:** M2. Vida por peça e dano; comportamento do atacante (bloqueio, alvo na peça); regeneração e save (só peças com vida abaixo do máximo); remoção da peça e atualização do caminho; feedback em 3 estágios; testes. **Menor recorte:** só madeira, só Utahraptor, sem regeneração e sem estágios.

**Ponto de atenção (durabilidade):** a vida da peça **não é durabilidade de item**; o item tem durabilidade própria (5.9) e a peça segue regenerando sozinha.

## 9. Progressão e desbloqueios

**Nível de personagem e pontos na versão enxuta** (decisão do dono, 5.1; **substitui o pilar "sem nível de personagem"**, item 14) além de **tier de receita** e **relacionamento**:

| Tier | Desbloqueia | Gate | Marco |
|---|---|---|---|
| 1 | Bastão-de-sono (inventário no M1), Bancada comum, Ração C, abrigo | Coletar | M1/M2 |
| 2 | Ração B e A, baú | Ingrediente de bioma 2 | M2 |
| 3 | Ração S, ofício avançado | Ingrediente de risco, Afeto 40 | M2 Should/M4 |
| 4 a 5 | S+, dinos grandes, região nova | Campanha de recurso | M4 |

**Desbloqueio por Saber (decisão do dono, 06/11):** o personagem **aprende receitas gastando Saber**, moeda separada dos pontos de atributo (1 por nível, +1 nos níveis 5, 10, 15 e 20); o tier continua sendo o gate de **ingrediente**. Árvore em cinco categorias (armas, armaduras, mobílias, construções, recursos diversos), 59 receitas na 1.0 e **21 na 0.2** (4 conhecidas, 22 Saber): `receitas.md`, `receitas_sim.py`. Substitui "desbloqueio por ter feito". Plano: PRO-10 (3 a 5 tiers, M4); 0.2 só 2 tiers.

## 10. Economia de recursos

| Recurso | Fonte [premissa] | Ralo | Limite natural |
|---|---|---|---|
| Madeira | Árvore: 3 por 8 s, respawn **8 min (valor do código; o GDD dizia 5)** | Construção, receitas | Respawn |
| Pedra | Nó: 4 por 10 s, respawn **10 min (valor do código; o GDD dizia 8)** | Construção, flecha (M4) | Respawn |
| Fibra | Planta, 3 s/unidade | Flecha (M4), porta | Respawn curto |
| Baga | Arbusto: 3 por 9 s, respawn 4 min | Fome, Ração, domar | Respawn |
| Carne | **Carcaça de Dodo, Listro e dinos (5.6), com Lança** | Fome, Ração Rubra | Respawn das presas (10 min) |
| Cochilo | Arbusto, respawn 6 a 8 min | Torpor do dino dormindo (5.5) | Respawn, ação 1,5 s |
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

## 12. Morte, respawn e save (decisões do dono, rodada após 06/11)

> **Decisões do dono (não se rediscutem):** 1 mundo na v0.2; autosave a cada 5 min, ao deitar na Cama, ao morrer o jogador, ao morrer um dino domado, ao voltar ao menu e ao sair; **o jogo nunca pergunta antes de salvar.** Respawn **(atualizado em 07/11, decidido): escolher um local aleatório ou um item de uma lista de Camas e Sacos de dormir**; cada um tem nome editável (12.3). Saco: 1 respawn e some, feito à mão com fibra. Cama: respawns infinitos, 1 min de espera entre usos, feita na Bancada, **só ela salva manualmente**. **Cama e Saco voltam para a v0.2, no M2, com a construção** (a Cama tinha saído em 06/11: revertido). Uma Cama em espera aparece na tela de morte com o tempo restante. **Tudo marcado [proposta SHIRO] é meu e o dono aceita ou muda;** números a testar jogando levam [premissa].

**Penalidade (já definida, mantida).** Morte do jogador: **cai o inventário num corpo recuperável** (SOB-02) e volta numa Cama, num Saco ou numa região; perde nada além do tempo. Mínimo no M1 (respawn numa região, a Campina), completo no M2. Conta: se a recuperação leva 2 a 3 min [premissa], a penalidade é ~3 min, no ritmo de sessão de 45 min são 6,7%. [jogar]: se não dói, sobe (o plano aceita "custa algo, não destrói horas"). Opção de servidor: corpo some em N min; morte permanente de dino (seção 13).

### 12.1 Save

| Gatilho | Salva? | Observação |
|---|---|---|
| Autosave | a cada **300 s** de relógio real (`autosave_segundos`) | o relógio **zera a cada save** de qualquer origem |
| Deitar na Cama | sim, **só no single-player**; é o **save manual** | único save manual do jogo; não há botão "salvar" no menu; no multiplayer deitar não salva (decisão do dono) |
| Morte do jogador | sim | salva **o estado de morto** (corpo, itens no corpo, tela de escolha pendente) |
| Morte de dino domado | sim | vale quando a vida do domado chega a 0 (v0.2: vira "ferido" e some 5 min, 6.8; com morte permanente de servidor, vira carcaça) |
| Voltar ao menu / sair | sim | também ao fechar a janela |

- **Sem pergunta, nunca.** Sem "deseja salvar?", sem tela de confirmação, sem pausa. Indicador discreto de 1 s ("Salvando") no canto, sem bloquear. **[proposta]**
- **1 mundo na v0.2.** Menu: Continuar e Novo jogo (Novo jogo apaga o mundo atual, **sem pergunta de salvar, mas com a confirmação normal de apagar**, porque apagar não é salvar). Vários mundos: depois da v0.2; o `map_id` já está reservado no SAV-01. **[proposta: a confirmação de apagar é minha; se o dono quer sem confirmação, avisar]**
- **Eventos em rajada [proposta]:** gatilhos a menos de **10 s** do último save viram **um** save (ex.: jogador e dino morrem no mesmo golpe). Sair ignora o intervalo.
- **Consequência assumida:** como o jogo salva sozinho na morte, **não existe "recarregar para desfazer"**. É o objetivo do dono: a morte do dino domado e a do jogador são definitivas no save.
- **Perda máxima numa queda:** 300 s = 5 min (compatível com o plano: "`kill -9` perde no máximo o intervalo de autosave"). 12 saves/h pelo intervalo, mais os eventos [calculado].
- **Orçamento [premissa, medir]:** escrita atômica com `.bak` (SAV-01) sem travar o quadro: meta < 100 ms ou em thread; se travar, o autosave espera o jogador sair de combate por até 30 s.
- **Multiplayer e servidor dedicado (M3):** `autosave_segundos` vale no servidor; deitar na Cama **não** salva o mundo, que segue só pelo autosave e pelos eventos do servidor.

### 12.2 Respawn

> **Atualizado em 07/11 (decidido).** Ao morrer, o jogador escolhe **local aleatório** ou **um item da lista de Camas e Sacos de dormir**. **Provisório **[provisório, aguarda o dono]**:** o sorteio vale na **ilha inteira**, em terra caminhável, com as mesmas distâncias de segurança de dino Agressivo (16 tiles) e Semi-agressivo (8 tiles); as **regiões em dados** (Campina, Mata-baixa, Pedreira) viram **reserva quando o sorteio falha**, não escolha do jogador. Cada linha da lista mostra o **nome** da Cama ou Saco (editável, 12.3) e a distância ao corpo.

**Tela de morte (atualizado em 07/11):** lista única: (1) **Camas** do jogador, (2) **Saco**, se houver, (3) **"Local aleatório"** (sempre disponível, pré-selecionado se não houver Cama pronta). Cada linha mostra o nome e a distância ao corpo. Uma **Cama em espera** fica cinza com o **tempo restante**. O jogador nunca fica sem opção.

(Atualizado em 07/11: as regiões são o **reserva** do sorteio, não uma escolha na tela.) **Regiões em dados (`respawn_regioes`; retângulos e ponto reserva saem do MUN-03; **valores iniciais da ilha em `mapa-ilha.md` 5**):**

| id | bioma | área sorteável | ponto reserva |
|---|---|---|---|
| `campina` | Campina | tiles caminháveis do bioma | 1 ponto fixo livre, longe de qualquer toca |
| `mata_baixa` | Mata-baixa | idem | idem |
| `pedreira` | Pedreira | idem | idem |

Clareira-brasa (M4) ganha a sua linha quando existir; **uma linha por bioma** mantém o sistema em dados.

**Regras do ponto aleatório (sorteio uniforme entre os tiles caminháveis da **ilha inteira**, 07/11):**
1. **Nunca em colisão:** tile caminhável do mapa, fora do `BuildGrid`, de nó de recurso, de carcaça e de água/borda do mapa.
2. **Distância mínima de dino Agressivo: 16 tiles [proposta]** (o dobro da percepção de 8 tiles do Utahraptor, 6.1); **de Semi-agressivo, 8 tiles [proposta]** (Triceratops só ataca provocado; a margem evita nascer na frente dele). Dino domado não conta.
3. **Até 30 sorteios** [proposta]; se nenhum servir, usa o **ponto reserva** de uma região em dados (a Campina). Conta [`respawn_sim.py ponto`]: região de ~4.900 tiles, R=16 (**superado pela ilha de 256: regiões de 4.000 a 8.300 tiles; a Mata-baixa recusa 55% dos sorteios e o reserva sai em 0%, `mapa_sim.py respawn`**): com até 8 agressivos o reserva sai em 0,05% dos respawns; com 16, 6,65% (R=24 já daria 15% com 8: por isso 16).
4. **Proteção de 3 s [proposta]** (invulnerável, sem atacar) ao nascer; o agressivo pode estar a 16 tiles, não colado.
5. **Efeito do respawn:** vida 100%, fome 50%, torpor 0, **inventário vazio** (tudo está no corpo), Saber, receitas e nível intactos [proposta: fome 50% = 250 s para achar comida].

**Histórico (superado em 07/11):** **Custo do "teleporte":** escolher a Pedreira ao morrer leva o jogador a até ~48 s de caminhada do início (o Sal da Pedreira está a 48 s; o arco inteiro leva 64 s, `mapa-ilha.md` 2); a penalidade real é largar o inventário no corpo, não a distância [calculado]. Não é falha, mas o jogador pode usar a morte como viagem: custo de largar tudo.

### 12.3 Saco de dormir e Cama

| | Saco de dormir | Cama |
|---|---|---|
| Receita | **8 fibra** [proposta] | **12 fibra + 8 madeira** [proposta] |
| Estação | Mãos (menu P) | **Bancada** (decisão do dono) |
| Saber | **1** [proposta] | **1** [proposta] |
| Respawn | **1 vez e some** | infinitos |
| Espera entre usos | -- (some) | **60 s** (`cama_espera_s`) |
| Salva ao deitar | **não** | **sim** (único save manual) |
| Colocar | no chão, 2 s; recolher devolve o item | peça no mundo (como o Baú), 3 s |
| Colisão e vida | sem colisão; **não é alvo** de dino | colisão; vida 30 por unidade de madeira = **240** [8.1], dino só a ataca se ela bloquear o caminho |
| Limite por jogador | **1 colocado** (colocar outro recolhe o primeiro) | **3 colocadas** (`cama_max_por_jogador`) |
| Tempo de coleta | 24 s | 57 s (~1 min) |

Conta [`respawn_sim.py custo`]: fibra 3 s/un, madeira 8 s por 3: Saco 8 x 3 = **24 s**; Cama 12 x 3 + 8 x 8/3 = **57 s**, contra 3 a 4 min do abrigo mínimo (8). A Cama não pode custar mais que o abrigo, senão ninguém a faz antes da primeira noite; e custa mais que o Saco porque rende infinito. **Por que fibra (3 s/un) e não pedra:** a fibra só tem consumidor pequeno na v0.2 (Machado 1, Picareta 1, Bastão 2, Bandagem 3), então sobra; é o ralo natural da Campina. **Peso (premissa):** Saco 0,4 kg (8 fibra x 0,05); Cama 9 kg (12 x 0,05 + 8 x 1), colocada logo, não carregada.

**Conhecidas ou aprendidas [proposta]: ambas aprendidas, Saber 1 cada** (T1, como Baú e Bancada). Motivo: manter as 4 conhecidas que o dono fechou (Fogueira, Lança, Machado, Picareta). O respawn por região já protege o jogador antes de aprender, então o Saco não é urgente. **Impacto na contagem [`receitas_sim.py arvore`]: v0.2 passa de 19 receitas e 20 Saber para 21 e 22** (sobra 2 dos 24 do L20, antes 4); aprender tudo vai do **L17 (175 min) ao L19 (218 min)** a 13 XP/min; **1.0 de 53/73 para 55/75** (completa no **L63**, antes L61), e **com Mochila e selas 59/84 (completa no L70**, antes 57/82, L69). Estações v0.2: Mãos 16, Bancada 4 (Ração x3 + Cama), Pilão 1. Alternativa para o dono: **Saco conhecido** (5 conhecidas): v0.2 21 receitas e 21 Saber, sobra 3, L18.

**Vínculo e uso:**
- **Nome editável (decidido, 07/11):** cada Cama e Saco de dormir tem **nome editável a qualquer momento, pelo botão direito do mouse**; o nome aparece na lista ao renascer. O nome é salvo com a peça e validado no servidor (tamanho e `filtro_nomes`, 13).
- **Deitar** (tecla de interagir, 1 s): no single-player salva o mundo (12.1) e mostra "Salvo"; no multiplayer não salva. Nos dois marca a Cama como ponto de respawn **do dono**. **Não cura, não passa o tempo, não dá bônus** (sem dia e noite na v0.2). Qualquer jogador pode deitar numa Cama alheia para **salvar**; só o **dono** (quem a colocou) renasce nela. Deitar não tem espera; a espera é só do **respawn**.
- **Espera de 60 s:** conta do instante em que alguém **renasce** na Cama. É **por Cama**, não por jogador. Medida em **tempo de jogo** (só corre com o mundo rodando; menu de pausa do single-player não conta e servidor desligado não conta) e **salva como `espera_restante_s`** (não como instante), então fechar e abrir o jogo não a zera nem a estende. Conta: a recuperação do corpo leva 120 a 180 s, então a espera só morde em **morte em sequência** (menos de 60 s depois de renascer); impede ressuscitar sem limite ao lado de uma Cama no meio de uma luta.

### 12.4 Casos de borda

| Caso | Regra |
|---|---|
| **Cama destruída** | sai da lista na hora (também com a tela de morte aberta); o jogador cai nas outras opções; **não devolve material** (peça destruída some, 8.1). Espera some junto. |
| **Cama recolhida pelo dono** | devolve o item inteiro; a espera some; libera 1 do limite de 3. |
| **Saco usado** | o respawn o consome **só depois** do jogador estar posto no mundo. Sai do save. Se a pessoa fecha o jogo na tela de morte, o Saco **continua** (o consumo vem com a escolha). |
| **Saco já colocado e dono morre longe** | continua no chão como opção; sem prazo de validade. |
| **O que se perde ao morrer** | tudo o que carrega **e o que veste/atalhos** cai num corpo; Saber, receitas, nível, pontos e dinos domados **não** se perdem. **Corpo some em 10 min [decisão do dono, 06/11; era 20 min na proposta]** (`corpo_minutos` = 10; `morte_item` mantém corpo/perde/mantém). **Todos os itens ficam no corpo, coletáveis por até 10 min.** **O relógio só corre com o mundo rodando e vai ao save como `restante_s`** (como a espera da Cama; corre durante a tela de morte). **Até 3 corpos por jogador [proposta, mantido]**; o 4º apaga o mais antigo. Marcador do corpo na borda da tela. **Margem [calculado, `peso_sim.py corpo`]:** buscar o corpo leva ~210 s (Cama 60 s + ~150 s); com 10 min sobram 390 s para 1 corpo, 180 s para 2, e o 3º corpo em sequência **expira** (630 s contra 600): o limite de 3 protege da 4ª morte, não do relógio **[jogar]**. **Co-op (M3) [proposta]:** o corpo é só do dono por 120 s e depois de qualquer jogador do grupo (`corpo_aberto_apos_s`; 0 = aberto, -1 = só o dono); sem PvP. |
| **Bolsinha de Largar e corpo de dino domado (M4b)** | fora da 0.2. Bolsinha: 5 min, qualquer jogador pega, 8 por jogador e 60 no mundo, sem colisão, relógio só com mundo rodando e salvo (5.1b). Dino domado a 0 de vida: corpo com os itens do alforje por 10 min (6.8); o ferido volta em 5 min sem itens. Tempos em dado: `bolsinha_largada_s` 300, `corpo_minutos` 10. |
| **Camas por jogador** | **3 colocadas** (limite na hora de colocar, com aviso; recolher libera). Fabricar não tem limite. |
| **Sem Cama nem Saco** | sempre há o **local aleatório** (atualizado em 07/11); sem softlock. |
| **Nenhum ponto válido na região** | ponto reserva fixo da região (garantido livre). |
| **Sacolinha do domado morto** | entra na v0.2, os itens dele não se perdem **[provisório, aguarda o dono]** |
| **Dinos domados quando o dono morre** | ficam onde estavam, na ordem atual (Seguir/Ficar, 6.11); não se perdem. |
| **Morte do dino e do jogador no mesmo golpe** | um save só (rajada de 10 s). |
| **Fechar na tela de morte** | o save guarda "morto, escolha pendente"; ao abrir, a tela de morte volta, com as esperas contando de onde pararam. |
| **Relógio da espera** | `espera_restante_s` no save; só decresce com o mundo rodando. |
| **Co-op (M3)** | Cama é do dono; Saco idem; espera por Cama; autosave no servidor; deitar não salva. |

### 12.5 Marco

M2 (Cama e Saco com a construção; o respawn mínimo do M1 fica como está, só a Campina). **SORA:** autosave e gatilhos, indicador, coalescência (SAV-04); tela de morte com lista, espera e pré-seleção; sorteio do ponto com regras e reserva; regiões em dados (junto do MUN-03); Saco (item, colocar, recolher, consumir); Cama (peça, deitar, dono, limite, espera, save, destruição); corpo com tempo (10 min, antes 20: só um número) e limite de 3, marcador; testes. **YATORA:** 2 sprites (Saco e Cama) e 2 ícones de receita. Cortável sem quebrar o loop: marcador do corpo e limite de 3 corpos.

**Precisa jogar:** se 300 s é intervalo bom (travada ao salvar?); se a Cama sem benefício além de salvar e respawn tem valor; se 1 min de espera é perceptível; se 16 tiles de folga ao nascer basta contra o Utahraptor em corrida; se 10 min de corpo e 3 corpos são generosos ou punitivos (o 3º corpo em sequência expira no pior caso); se escolher a Pedreira para "viajar" vira hábito.

## 13. Co-op e regras de servidor

Co-op é **M3** (plano), não Must da 0.2; o design já assume 2 a 8 jogadores. Servidor autoritativo (ADR-001); single-player é host local. Servidor pequeno, imagem Docker, uma porta UDP.

Regras configuráveis por servidor. **Atualizado em 07/11:** o formato é o **`server_rules.json`** do ADR-004 (`user://saves/<mundo>/server_rules.json`, ou `--server-rules=<caminho>` no servidor dedicado), lido pelo `ServerRules` no carregamento do mundo; as `.tres` dão o padrão. **Já existem 8 chaves:** `multiplicador_coleta`, `respawn_recurso`, `faixas_de_nivel`, `respawn_protecao_s`, `respawn_fome_pct`, `eficiencia_fixa_ataque_jogador`, `eficiencia_fixa_ataque_carnivoro` e `pvp` (08/11); as demais da tabela entram quando a etapa que as usa chegar. **`dano_fome` fica obsoleta** (fome sem dano, 5.10). Duração do ciclo de dia e frequência da chuva entram como chaves novas **[provisório, aguarda o dono]**.

| Chave | Padrão | O que muda |
|---|---|---|
| `multiplicador_refeicao` | 1,0 | Tempo de domar (Ração) |
| `multiplicador_coleta` | 1,0 | Quantidade por nó |
| `respawn_recurso` | 1,0 | Respawn |
| `dano_fome` | -- | **OBSOLETA (07/11):** a fome não causa dano |
| `morte_item` | corpo | corpo / perde / mantém |
| `dino_ferido_minutos` | 5 | 0 desliga, -1 permanente |
| `autosave_segundos` | 300 | Intervalo do autosave (12.1) |
| `cama_espera_s` | 60 | Espera da Cama entre respawns (12.3) |
| `cama_max_por_jogador` | 3 | Camas colocadas por jogador (12.3) |
| `corpo_minutos` / `corpos_max_por_jogador` | 10 / 3 | Duração e quantidade de corpos (12.4) |
| `respawn_dist_agressivo_tiles` / `_semi_` | 16 / 8 | Distância mínima ao nascer em região (12.2) |
| `respawn_protecao_s` | 3 | Invulnerável ao renascer |
| `respawn_fome_pct` | 50 | Fome ao renascer |
| `afeto_decai` | 1,0 | Ritmo de negligência |
| `eficiencia_fixa_ataque_jogador` / `_carnivoro` | 4 / 8 | Perda de Eficiência por ataque ao dormindo |
| `raio_ronco_tiles` | 8 | Detecção do dormindo pelo carnívoro |
| `faixas_de_nivel` | 10.3 | Níveis por bioma |
| `pvp` | desligado | Golpe em área acerta domados de outro jogador |
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

Tutorial contextual (UIX-05, M2): dicas por evento, sem tela de texto. **Dicas da primeira doma (Dodo):** ao empunhar o Bastão perto de um Dodo, "dois golpes seguidos o põem para dormir"; ao nocautear, "o bando foge, mas o dorminhoco fica: dê bagas"; ao pedir reforço, "Cochilo mantém o sono sem assustar o bando".

Revisto em 06/11: **o Bastão-de-sono nasce no inventário no M1, sem receita**; Bancada e Ração C são aprendidas; **o Dodo só existe a partir do início do M2** (esta tabela é a v0.2 inteira). XP: 10 por min até o L5 e 13 depois [premissa]; **abater dá XP: Dodo 3, Listro 4**, coletar e domar dão o resto. `receitas_sim.py` e `durab_sim.py`.

| Minuto | O que acontece [premissa] | Número |
|---|---|---|
| 0 a 1 | 2 graveto + 3 madeira à mão, faz a **Lança** (menu P, conhecida) | ~25 s de coleta |
| 1 a 4 | O **Dodo** (Covarde) pasta; o jogador chega, 2 golpes de Lança (o 2º cai antes de ele fugir), coleta 2 carne + 1 couro; o grupo foge ao 1º golpe | ciclo ~38 s (era ~30 s: +8 s para reencontrar outro grupo), 3 XP: **L2 em ~3,8 min** (30 XP) [premissa] |
| 4 | **Saber 1: Bancada** (8 madeira + 2 pedra, à mão); com Picareta e Machado conhecidos | Bancada no minuto 5 |
| 5 a 8 | Mais Dodos; **L3 aos 7,5 min** (75 XP): +2 Saber (3 no total): **Ração C** e 1 de sobra (a receita do Bastão repõe o do inventário) | Saber 3 |
| 8 a 12 | **Primeira domesticação (decisão do dono, 6.1b): Dodo L3 a L5**, a presa que o jogador já caçou: Bastão do inventário, **2 golpes em 0,7 s dentro do susto**, o grupo foge e não atrapalha; **6 bagas (18 s de coleta), 36 s dormindo, 1 reforço de Bastão ou 2 a 3 s de Cochilo**. **No M1 (sem Dodo) a primeira doma segue o Paquicéfalo L5 a L8:** 4 golpes em 2,1 s, **15 bagas (45 s de coleta), 90 s dormindo, 2 a 3 reforços de Bastão** (5.14); na v0.2 ele vira a **segunda doma** (minuto 12 a 20, carga de 40 kg). Soco: Dodo 6 a 7 golpes, Paquicéfalo 15 | **marco: dino domado em até 12 min** [premissa]; ~3 min de ação |
| 12 a 20 | **Segunda doma: Paquicéfalo** (carga de 40 kg); Abrigo (Saber 1, L4 aos 13 min), curral (Saber 2); Machado e Picareta já gastam ~1 reparo na hora | 3 a 4 min de coleta |
| 20 a 35 | **L5 aos 21 min: 6 Saber (Ração B, Cerca e curral).** Caçar 13 Dodos (6,5 min) = 25 carne para a Ração Rubra C, ou 6 Dodos (3 min) = 11 para B | **Utahraptor domável a partir do M2, ~35 min; 0,6 a 1,8 min de domar** |
| 35 a 50 | Nocautear o Utahraptor com Bastão (5 golpes); vigília e alimentação (validade da carne: 30 min, margem 3x) | primeiro perigo real |
| 50 a 60 | Baú, carga, ofício; salvar e sair | ofício carregar |

**Caminho mínimo de domesticar sem os três itens:** o Dodo (v0.2) e o Paquicéfalo aceitam **baga crua** e o **Bastão do inventário** o nocauteia: **0 Saber**. Para o Utahraptor: **Bancada (1) + Ração C (1) = 2 Saber, no L3 (7,5 min)**, mais Lança e Dodos para a carne. **Onde se fabrica sem Bancada:** no menu P, à mão, **tudo o que é de fibra, madeira e pedra** (regra 5.19): as 4 conhecidas, Bancada, Bastão, Pilão, Baú, Cocho, Abrigo, Cerca, Portão e Bandagem. **Precisa jogar:** o ritmo de XP por abate e se o Soco de 8,4 s no Paquicéfalo é divertido ou só um muro antes do Bastão.

Metas do plano: 3 de 5 testadores completam o fluxo em até 20 min (M1) [premissa do plano]; hipótese H1: a vigília gera tensão, não espera. A primeira hora fecha o loop inteiro uma vez.

**Primeiro minuto**: uma única instrução visível; nenhum menu.

## 16. Resumo por sistema

| Sistema | Marco | v0.2 |
|---|---|---|
| Vida, stamina, fome | M1 | Essencial |
| Coleta, inventário | M1 | Essencial |
| Domar (baga crua) | M1 | Essencial |
| Ordens seguir/ficar | M1 | Essencial |
| Morte e respawn mínimos (região Campina) | M1 | Essencial |
| Autosave 5 min e nos eventos (12.1) | M2 | Essencial |
| Respawn em local aleatório (ilha inteira), Saco e Cama com nome (12.2 a 12.4) | M2 | Essencial |
| Ração C a A (Bancada) | M2 | Essencial |
| Nível, Eficiência, nível previsto, painel de 3 barras | M2 | Essencial |
| Barra de vida (após dano, máx. 3) | M2 | Essencial |
| Bastão-de-sono (dano 2, torpor 30) | M1 | Essencial |
| Lança de madeira (dano 12, torpor 0) | M1 | Essencial |
| Durabilidade, reparo e validade (5.9) | M1 (modelo) e M2 | Essencial |
| Dodo (domável); Listro (domável) no M4 | início do M2 / M4 | Essencial / Should |
| Carnívoro ataca dormindo; curral | M2 | Essencial (M1 só se H1 for testada lá) |
| Soco e Bastão-de-sono | M1 | Essencial |
| Flecha de sono (torpor contínuo, teto de 3 efeitos) | M4 | Should |
| Cochilo e forçar o dino; sinais no jogador | M2 | Essencial |
| Preparado de sono e Carniça | M2 | Cortável |
| Sono do jogador, Arco e flechas, espada, carne que apodrece | M4 | Fora da 0.2 |
| Armas de fogo e pólvora | -- | **Fora do jogo (decidido)** |
| Carcaça e sacolinha (só carne; couro sem uso) | M2 | Essencial |
| Faixas de torpor (visual) e regra de lentidão | M2 | Essencial; **pausa já implementada** |
| Afeto e obediência | M2 | Essencial |
| Ofícios carregar/defender (Peso) | M2 | Essencial |
| Barra de atalhos 1 a 9: comida e equipar | M1 | Essencial |
| Rifle, Dardo, arma de fogo, pólvora e fósforo | **sem marco** | Adiados (decisão do dono, 06/11) |
| Sílex (da pedra comum e do minério; ponta de flecha) | M4 | Volta com o Arco (5.9c) |
| Dar comida ao dino pela tela dele (E) | M1 | Essencial, **já implementado** |
| Atributos, XP e pontos do jogador (nível 20, 4 atributos) | M2 | Essencial (decisão do dono) |
| XP de companhia e pontos do dino (Vida, Dano; +10 níveis) | M2 | Essencial (idem) |
| Respec, teto por atributo, XP por ofício | depois | **Fora da 0.2** |
| Saber e tela de receitas (19 receitas) | M2 | Essencial |
| Dano em construções (madeira, Utahraptor) | M2 | Essencial |
| Stamina em golpes e coleta | M2 | Essencial |
| Palha e pedra como material | M4 | Fora da 0.2 |
| HUD: vida, fome, XP com nível e aviso, atalhos; ofego | M2 (M1 vida, fome, atalhos) | Essencial |
| Nome do dino | M2 | Essencial barato |
| Construção básica | M2 | Essencial |
| Ração S, Mel | -- | **Fora da 0.2 (camada 1)** |
| Dia e noite, chuva | v0.2 | **Essencial (decidido 07/11; antes fora da 0.2)** |
| Slots que limitam, bolsa, ficha, Neutro, montaria sem sela, renascer com lista nomeada | v0.2 | **Essencial (decidido 06/11 e 07/11)** |
| Temperamento do carnívoro domado | -- | **Fora da 0.2 (camada 1)** |
| Conduta: Passivo e Agressivo (Paquicéfalo, Utahraptor) | M1 | Essencial |
| Conduta: Semi-agressivo (Triceratops) | M2 | Essencial |
| Conduta: Covarde (Gallimimus) | M4 (Listro) | **Fora da 0.2 (camada 1)** |
| Conduta: Covarde (Parassaurolofo) | M2 | Fora da v0.2 (sai do elenco, 07/11 **[provisório, aguarda o dono]**) |
| Conduta: Curioso (Oviraptor) | M4 | Fora da 0.2 |
| Grupo chama grupo | M2 | Essencial para Passivo; resto cortável |
| Co-op e servidor | M3 | Fora da 0.2 |
| Criação (ninho, filhote) | M4 | Cortável, identidade |
| Ração S+, Seiva | M4 | Cortável |
| Chunking, seed, 8 espécies | M4 | Fora |

## 17. Conflitos com o plano e o escopo

> **Atualizado em 07/11:** esta lista foi escrita antes do corte da v0.2. Onde ela fala de **21 receitas** (agora **17**), **5 espécies ou Gallimimus** (agora 4 espécies sem Parassaurolofo e Gallimimus), **40 slots** (agora 4 que limitam, 5.21) ou **Cocho** (fora da v0.2), vale a regra atual; os itens afetados levam a marca "histórico".


1. **D5**: o plano recomenda "cuidado e ofícios". Proponho Afeto, Temperamento e Criação; a 0.2 só precisa do Afeto e de dois ofícios. Não alterei o plano.
2. **Fome**: 0,5/s em código esvazia em 3,3 min. Recomendo 0,1/s. Ajuste de dado.
3. **Landing x tom**: propaganda carismática é coerente, mas a landing sugere "dino parceiro fofo"; precisa de revisão para não prometer o que o jogo não entrega.
4. **Crafting é M2, não M1**: o plano põe PRO-04 no M2; a Ração com receita só chega lá. O M1 usa baga crua (racao.md, 2.4).
5. **Espécies**: o plano cita "3 a 4 espécies" na 0.2 (CRI-03: 2, CRI-06: 3 e 4); minha conta fecha com 3. A 4ª é cortável.
6. **Cozinhar é Could** no plano; a Ração usa a **bancada comum** (decidido 05/11), então não há estação extra além da prevista em PRO-04. Conflito resolvido.
7. **Golpe em dino inconsciente deixa de ser grátis** (muda comportamento já implementado em `Dino.apply_torpor` e `Player`; racao.md, seção 0).
8. **Criação de filhote** é novo escopo (M4); não existe no plano.
9. **Nível, Eficiência e vida do dino** (decisões de 05/11) são sistemas novos no M2 que o plano não lista: CRI-03/CRI-05/CRI-07 aumentam (nível e vida na `SpeciesDef`, Eficiência no domar, UI de 3 barras). O plano precisa incluir o escopo novo (aviso ao `SHIKAMARU`).
10. **Combate com dano** (Bastão com dano 2, Lança) altera o ataque atual, que só causa torpor (CRI-01 em andamento).
11. **Carnívoro atacando o dormindo** é comportamento novo; CRI-04 (M1) prevê só Chase e Attack no jogador.
12. **Morte do dino**: plano cita estado Dead (SOB-02) sem dizer se permanente; aqui é "ferido" por padrão.
14. **Nível de personagem e pontos** (5.1): o plano tem "sem nível de personagem" como pilar. Decisão do dono; o design limita o risco (abater não dá XP, teto por atributo, 29 pontos em 30 níveis) mas o plano precisa ser corrigido pelo `SHIKAMARU`.
15. **Inventário por Peso** troca o inventário em slots do plano (itens de inventário, UI de HUD e ofício carregar); exige tela de atributos e de alforje.
16. **Barra de atalhos** (5.2) não está no plano; M1 pede UI de 9 posições e ação por item.
17. **Nome do dino** e **save**: o save passa a guardar nível, pontos, XP e nome por dino e jogador (bump de versão).
22. **Carcaça e sacolinha** (5.6): entidades salvas no mundo e coleta com Peso; não estão no plano; o fim da dúvida do `LEVI` (comida de dino morto) vira regra. Carne podre agora também vem da carniça (carcaça velha).
18. **Carne podre** (revisto 06/11): a validade por pilha existe (5.9) e `racao.md` 2.4 (validade cortada) perde: a recomendação do nó de Carniça cai; a carniça é só estado da carcaça.
19. **V6** (torpor contínuo como manutenção do dormindo) é revisto: fruta e preparado a substituem; a flecha de sono (M4) passa a ser ferramenta de dino acordado.
20. **Torpor do jogador** (sinais e, no M4, sono) não está no plano; reaproveita o `TorporComponent`.
21. **Dose da flecha de sono** (antes dose do dardo, 50): 15 imediato + 12/s por 5 s = 75; `racao_sim.py` guarda o 50 antigo só como histórico (sem Dardo no jogo).
23. **Receitas por Saber** (receitas.md): PRO-04 e PRO-10 do plano não têm moeda nem tela de aprender; o texto "por ter feito" do GDD 9 foi substituído.
24. **HUD** (5.7): barra de XP, aviso de ponto e ofego no lugar da barra de stamina não estão no plano; se o HUD atual tem barra de stamina, ela sai.
25. **Durabilidade (revisto 06/11):** o GDD cortava; agora existe (5.9). **Muda o inventário do código** (`{id,count}` e barra por tipo): item individual e slot na barra; a camada de salvar sobe de versão.
26. **Conduta:** "desistem após 5 s sem caminho" vira "ataca a peça de bloqueio" para o Agressivo (8.1); `Dino` ganha comportamento novo.
27. **Reparo:** o de **peça** continua cortado (regenera, 8.1); o de **item** existe na Bancada (5.9).
28. **Stamina:** o `Player` atual não gasta Stamina em golpe nem coleta; agora gasta (5.8).
29. **Lança** (CRI-13 do plano, M4) volta como **Lança de madeira no M1** e contradiz a camada 1 (5.3); o CRI-12 (carnívoro ataca o dormindo) segue como estava.
30. **Dodo e Listro** passam a 6 espécies na v0.2 (plano prevê 4 a 5) e antecipam a Conduta Covarde (6.7) do M4 para o início do M2 (Dodo, que também é Covarde por decisão do dono); o Listro volta ao M4 e o Curioso fica só com o Oviraptor.
31. **Estações:** "uma só estação, a Bancada" (5/11) vira Mãos + Bancada + Fogueira (`receitas.md` 10).
32. **Receitas conhecidas:** de 6 para 4 (Fogueira, Lança, Machado, Picareta); Bastão, Bancada e Ração C custam Saber; +1 Saber no L3 (24 no L20).
33. **Utahraptor domado fica no M2** (precisa carcaça, Lança e Dodo); no M1 é só ameaça. **Sem Dodo no M1 não há presa nem carne:** a Lança só serve contra Paquicéfalo e Utahraptor (decisão do dono, 06/11).
34. **Fome do jogador** (5.10): substitui o dano de fome do `HungerComponent` (morte em 40 s vira ~5,2 min) e antecipa o estado inconsciente do jogador (M4) para o M2; queda de 0,5 para 0,2/s.
35. **Armadura** (5.11): 3 materiais em **5 peças** (camisa, calça, capacete, bota, luva), dano mínimo 1; vagas de equipamento no inventário (5.20); Escudo e pele saem; **temperatura fora, sem marco**.
*[Histórico, superado em 07/11: o Cocho sai da v0.2.]* 36. **Cocho** (5.12): fica em M2 cortável (Saber 2, 8 madeira); a fome 0 do dino domado passa a ter efeito (Afeto e ofício), onde a tabela 5.1 dizia "nenhum".
37. **Tecla de atalho e Oferta** (5.13): a tecla só consome pelo jogador; alimentar dino é pela tela do dino (E, já implementada) ou pelo slot de Oferta; o cocho não consta na regra 2 (tratado como inventário do rebanho); domar passivo **adiado para depois do playtest**; o atalho em dino da 5.2 saiu.
38. **Rifle e Dardo (decisão final do dono, 06/11): adiados sem marco**; a exceção do Rifle de mola e o conflito 41 deixam de existir. A 1.0 só tem arco, besta e boleadeira (5.4). Sem consumo para o fósforo e a pólvora; o sílex voltou no M4 (5.9c).
39. **Tempo de domar** (5.14): o nível pesa mais (0,033 por nível, antes 0,015) e os fatores por espécie mudam; a tabela de 60 s, 105 s e as Dificuldades antigas ficam desatualizadas; recomendo `eficiencia_drena_tempo` 0,15.
40. **Tetos de nível** (5.16): o teto "captura + 10" e o 75 fixo caem; `pontos_sim.py` (`CAP_EXTRA` removido; `MULT` 2 e `DINO_MAX` 50) já corrigido; o save acima do teto só trava.
41. **Pólvora e fósforo:** sem marco e sem consumidor (5.18); o sílex voltou como ponta de flecha (M4, 5.9c); o químico de sono do pedido é o Preparado de sono (um só nome). O carvão só serve à Forja.
42. **Regra de produção** (5.19): fibra, madeira e pedra à mão; metal e engenharia na Bancada. A Bancada fica com 3 receitas na v0.2 (Ração) mais o reparo.
43. **Dodo no início do M2** (dono): o M1 fica sem presa (a Lança só encontra Paquicéfalo e Utahraptor); o XP do M1 vem de coletar, craftar e domar.
44. **Bastão-de-sono nasce no inventário no M1, sem receita** (a receita de reposição, Saber 1, é do M2). O roteiro do M1 (15) deixa de craftar o Bastão.
45. **Triceratops L28 e acima sem o Rifle:** a faixa da 1.0 fica em L18 a L24 (5.15); liberar L25 a L28 é opção do dono, com couro, Arco ou metal.
46. **Flecha de sono entra no M4** (recomendo, 5.4): dá segundo consumidor ao Preparado sem inventar sistema; **cortável: Boleadeira e Besta**.
47. **Slots que limitam e bolsa** (5.21). *[Histórico: o texto de 06/11 dizia "40 slots só de exibição" e base 24 + 16 no M4.]* **Atual (07/11, decidido):** 4 slots que limitam desde a v0.2 e uma vaga de bolsa (+4 ou +8); o Peso continua.
48. **Nomes:** Conduta é do selvagem e Postura do domado; Passivo e Agressivo ficam só na Conduta (6.11). O pedido "passivo, neutro, agressivo" vira Calma, Guarda e Ataque. **RESOLVIDO (dono, 06/11): Calma, Guarda e Ataque.**
49. **Alforje recusa item individual e a sela é individual** (6.13): resolvido com vaga própria de sela no dino, fora do `InventoryComponent`; a sacolinha da morte permanente aceita individual. **RESOLVIDO (dono, 06/11): vaga própria de sela.**
50. **Montaria sem ganho de velocidade** (6.12): com as velocidades fixas da espécie (75 a 90) a montaria seria mais lenta que correr (~86); só vale com o x1,3 [premissa]. **RESOLVIDO (dono, 06/11): montaria só no M4 com o x1,3 [premissa] a validar jogando; dano ao montado todo no dino.**
51. **Sela só nas espécies "montável com sela"** (correção do dono): Utahraptor monta sem sela e sem vaga; Paquicéfalo não monta. **RESOLVIDO (dono, 06/11).**
52. **Cama e Saco voltam à v0.2 (12.3):** a Cama saiu em 06/11 (cortes leves) e volta por decisão do dono; a contagem de receitas e Saber da v0.2 é a do corte de 07/11 (17 receitas, `shiro.md` 5.2); os totais de 1.0 aqui são do desenho antigo. Plano: Cama no M2, junto da construção.
53. **Teleporte pela morte (12.2):** escolher a Pedreira ao morrer equivale a ~48 s de caminhada; o custo real é largar o inventário no corpo. Aceito; vira problema só se o playtest mostrar morte como viagem.
13. **CRI-04 (M1)** prevê "Flee (herbívoro), Chase e Attack (carnívoro)". Seis tipos de Conduta exigem uma máquina de estados orientada a dados; o herbívoro do M1 é **Passivo** (revida), não foge. Cabe ao `SHIKAMARU` ajustar o escopo.
*[Histórico: o Gallimimus sai da v0.2; são 4 espécies e 4 tipos, 07/11.]* 14. **Tipos x espécies** (CRI-03, CRI-06): a 0.2 mostra 4 tipos com 4 espécies (cabe no plano); o Gallimimus eleva a 5 espécies e 5 tipos, **acima** dos 3 a 4 do plano; Curioso só no M4 (CRI-10).
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
| V16 | Seis tipos de Conduta: aceitar só 3 a 4 na 0.2 e os outros no M4, ou usar variantes por indivíduo no Paquicéfalo da Mata-baixa? | 3 tipos (4 com o Gallimimus) na 0.2; variantes só se faltar variedade no playtest **DECIDIDO (05/11, aceita a recomendação).** Atualizado depois: o dono incluiu o Parassaurolofo (Covarde) no M2, então a 0.2 mostra **4 tipos (5 com o Gallimimus)**. |
| V17 | Paquicéfalo (herbívoro do M1) como Passivo, não Covarde? | Sim, tutorial depende de poder bater e domar **DECIDIDO (05/11, aceita a recomendação).** |
| V18 | Atacar um membro chama o grupo a 8 tiles? | Sim **DECIDIDO (05/11, aceita a recomendação).** |
| V19 | Níveis dão pontos ao jogador e ao dino (1 ponto = 6% da base)? | **DECIDIDO (06/11, dono)** |
| V20 | Os níveis de bônus da Eficiência dão pontos ou vêm aplicados? | **Aplicados**, recomendação; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V21 | Tetos: jogador 20, dino +10, sem teto por atributo | **DECIDIDO** (versão enxuta, 06/11) |
| V22 | Respec e perda de XP na morte | Sem respec e sem perda na 0.2 **DECIDIDO** (versão enxuta) |
| V25 | D17: Listro como Covarde e Clareira-brasa fora do M4 | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V76 | Conduta selvagem: Covarde (jamais revida; foge ao ser atacado ou quando um do grupo é atacado a até `alarme_raio_tiles`) para Parassaurolofo, Dodo, Gallimimus e Listro; Medroso (foge ao avistar) é conduta futura, sem marco; Curioso só no Oviraptor (M4) | **DECIDIDO (06/11, dono).** Fugitivo, fuga e alarme são dado da espécie |
| V77 | Artrópodes gigantes das cavernas (Arthropleura, Meganeura, Pulmonoscorpius, Titanomyrma) não são dino: ficam **fora da regra "todo dino é domável"** como fauna-recurso (Lança, carcaça com quitina, sem perfil de doma) | **DECIDIDO (06/11, dono): opção A.** |
| V78 | Dodo como **primeira doma** na v0.2 (Paquicéfalo vira a segunda; no M1, sem Dodo, nada muda) | **DECIDIDO (06/11, dono).** |
| V80 | Com todas as árvores e todas as rochas soltas coletáveis (muito mais fonte que as 264 árvores coletáveis de hoje (`mapa-ilha.md` 8)), a **economia de madeira e pedra** muda: a conta de 86 madeira e 40 pedra na 1ª hora, o ritmo de respawn por região e o teto de acúmulo (Peso) precisam ser refeitos no `mapa_sim.py`. Mantém o respawn de 480 s e 600 s ou o excesso de fonte pede respawn mais longo? | **ABERTA (dono, 06/11); sem número novo proposto.** Calcular no `mapa_sim.py` com a contagem final do MUN-03; só jogar mostra se o mapa fica vazio demais. |
| V81 | Nó que não volta por construção em cima: o relógio de respawn **cancela** (o nó some de vez) ou **fica esperando** e volta se o jogador demolir? E o nó esgotado fora do raio de zona ativa volta no relógio normal? | **ABERTA (dono, 06/11).** Recomendo esperar: sem perda permanente de fonte; precisa do save de nós esgotados (12.1). |
| V79 | Modo Agressivo do domado (6.11 e 6.11b): decidido que ataca **todo selvagem na visão**, também em Seguir. Em aberto: (a) o limite de 12 tiles do dono / 14 de desistência / 10 s da proposta anterior ainda vale, ou "perde o agro" é o único critério? (b) "perder o agro" = alvo morreu, fugiu ou saiu da visão, ou outro? (c) em Ficar e Guardar a base (6.3), vale a visão inteira ou só o raio de 12? (d) caçar presa pelo mapa (Dodo, Paquicéfalo) agora acontece: aceito? (e) ataca selvagem muito acima do nível dele (Triceratops L28 contra Dodo domado)? | **DECIDIDO (dono, 06/11):** (a) vale o limite de 12 tiles, com 14 de desistência e 10 s; (b) sim: morreu, fugiu ou saiu da visão; (c) só o raio de 12; (d) aceito; (e) sim, e o domado pode morrer. Distância em linha reta, em qualquer direção. |
| V26 | Utahraptor solitário na 0.2 e primeiro golpe provoca (5.3) | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V27 | Regra de armas: torpor zero em flecha comum, besta, lança e espada; torpor próprio em soco, porrete, flecha de sono e dardo; contínuo em flecha e dardo | **DECIDIDO (06/11, dono)**; valores em 5.4 |
| V28 | Armas de fogo | **Fora do jogo, sem marco, e a pólvora não entra DECIDIDO (06/11, dono; reafirmado na decisão final).** |
| V29 | Acúmulo de doses: soma até 3, a 4ª renova a mais antiga; flecha de sono em dormindo -2 E; contínuo não é ataque | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V30 | Cochilo e preparado forçam o dino sem custo de Eficiência; preparado = fruta + carne podre | **DECIDIDO (06/11, dono)**; números em 5.5 |
| V31 | Carne podre: carcaça velha **e** pilha vencida; nó de Carniça cortado | **DECIDIDO (06/11, dono; substitui a recomendação anterior).** |
| V32 | Jogador come fruta: sinais no M2, sono no M4 | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V33 | Carcaça com carne e couro, sacolinha no chão | **DECIDIDO (06/11, dono)**; números em 5.6 |
| V34 | Comida do alforje de dino morto vai para a sacolinha | Recomendo **sim**; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V35 | Couro na 0.2 sem uso: Bastão reforçado ou M4? | **Bastão reforçado CORTADO (06/11, dono)**: o couro só tem uso no M4. |
| V36 | Tempos: carcaça 10 min, carniça até 20, sacolinha 10, só dono 120 s | Recomendo; **DECIDIDO (06/11, dono aceita a recomendação).** |
| V37 | Saber: moeda separada, 1 por nível, +1 no L3 e nos níveis 5, 10, 15 e 20 | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V38 | 0.2 com **17 receitas no corte de 07/11** (antes: 21 receitas, 22 Saber de 24), aprender tudo no teto; 1.0 (53 receitas com as peças, 73 Saber, completa no L61) não; sem reinício | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V39 | Armadura: 3 materiais x 5 peças, soma linear, mistura vale, todas as peças sofrem o golpe, dano mínimo 1; **fibra depois do playtest, fora da v0.2** | **DECIDIDO (dono, 06/11); substitui "1 vaga".** Divisão por peça e "Reparar tudo": recomendo, **PENDENTE** (V69) |
| V40 | Mobílias com função; fogueira passa a ter função (assar), pilão fora | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V41 | Fóssil ensina sem gastar Saber (S e S+ só por fóssil, M4) | **DECIDIDO (06/11, dono aceita a recomendação).** |
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
| V62 | Pilão (à mão, portátil, Saber 1) e Preparado no Pilão: Pilão e Preparado saem da v0.2 em 07/11; **v0.2 com 17 receitas**; fósforo e pólvora **sem marco** (sílex: M4, 5.9c) | **DECIDIDO (dono, 06/11).** |
| V63 | Rifle, Dardo, arma de fogo, pólvora e fósforo (sílex revisto: M4, 5.9c) | **Adiados sem marco (decisão final do dono, 06/11).** |
| V64 | Armas à distância: arco, flecha comum e **flecha de sono** (M4), boleadeira (M4), besta (M5); Preparado como ingrediente da flecha de sono | Recomendo; **PENDENTE** (números em 5.4: flecha de sono 75, Besta 22 de dano a 14 tiles, Boleadeira prende x0,4 por 5 s) |
| V65 | Regra de produção: fibra, madeira e pedra à mão; metal e engenharia na Bancada; Forja feita na Bancada | **DECIDIDO (dono, 06/11).** Ração na Bancada é recomendação minha |
| V66 | Aceitas: 2x sobre nível final, servidor só trava, dino 50 no MVP, Triceratops L18 a L24, Dodo no início do M2, carvão só na Forja, Pilão e Preparado na v0.2; cortes leves (sem Bastão reforçado, **sem Cama: revertido, a Cama volta com o Saco no M2, V75**, Saber em lista plana, dano em construções no recorte mínimo) | **DECIDIDO (dono, 06/11).** Corte maior só depois do QA-01a |
| V67 | Bastão-de-sono no inventário no M1, sem receita | Recomendo e confirmo; **PENDENTE** de aceite explícito |
| V69 | Divisão por peça (camisa 30%, calça 25%, capacete 20%, bota 15%, luva 10%), mistura livre, "Reparar tudo equipado", Saber por conjunto (não por peça) | Aceito; **DECIDIDO (dono, 06/11)**: Saber por conjunto, não por peça |
| V70 | Sprite do jogador **não** muda por peça (só UI) | Aceito; **DECIDIDO (dono, 06/11)** |
| V71 | Mochila: item equipável, 7ª vaga (costas), base 24 + 16 = 40, tirar cheia recusa, excesso na sacolinha, M4; couro + fibra, Saber 2 (provisório) | **DECIDIDO (dono aceitou, 06/11)**: item futuro no M4; números seguem provisórios |
| V72 | Menu de interação do domado, Postura (Calma, Guarda, Ataque), Ir até aqui, comando de rebanho, `dino_permissao` | **DECIDIDO (dono aceitou, 06/11)**: v0.2 só menu + Seguir/Ficar todos + permissão; Postura (Calma, Guarda, Ataque) e Ir até aqui **depois do playtest** |
| V73 | *[Histórico, superado em 07/11: sela obrigatória e montaria no M4]* Montaria: Utahraptor sem sela; Parassaurolofo e Triceratops com sela obrigatória; Paquicéfalo e presas não; x1,3 de velocidade; sem sprite novo | **DECIDIDO (dono aceitou, 06/11)**: classes por espécie, montaria no M4, dano ao montado todo no dino; números seguem [premissa] |
| V74 | Sela (fibra, couro, metal): Peso extra +20/+40/+60%, defesa 8/15/25%, durabilidade 100/150/300, vaga própria no dino | **DECIDIDO (dono aceitou, 06/11)**: sela no M4 junto da montaria (metal M5); valores seguem [premissa] |
| V75 | Save, respawn, Saco e Cama (12): 1 mundo; autosave 300 s e nos eventos, sem perguntar; região ou Cama ou Saco; Saco 8 fibra Saber 1; Cama 12 fibra + 8 madeira na Bancada, Saber 1, espera 60 s | **DECIDIDO (dono, rodada após 06/11)** o desenho; **PENDENTE** os números marcados [proposta] em 12 |
| V68 | Triceratops da 1.0: L18 a L24 (menor ajuste) ou até L28 com couro, Arco ou metal | Recomendo L18 a L24; **PENDENTE** |
| V52 | ~~Dodo presa sem domar~~ **SUPERADO (06/11): todo dino é domável, 4.1 e 6.1b**; **Listro fora da v0.2, no M4 com o Oviraptor**; 5 espécies na v0.2 | **DECIDIDO (06/11, dono).** |
| V53 | Fome do jogador (queda 0,2/s, valores de comida) e morte por fome em ciclos | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V54 | Armadura: fibra 10%/2 kg/100, couro 25%/6 kg/150, metal 40%/12 kg/300 | **DECIDIDO (06/11, dono aceita a recomendação).** |
| V55 | *[Histórico, superado em 07/11: Cocho fora da v0.2]* Cocho (alcance 6 tiles, 40 itens, validade corre, só domado) | **DECIDIDO (06/11, dono: números seguem a recomendação).** |
| V56 | Tecla de atalho sempre consome; dino come do inventário dele (tela, E) ou do Cocho (fora da v0.2); **jogador nunca consome Ração** | **DECIDIDO (06/11, dono)**; preparado de sono **ainda não decidido** |
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
- **Regra proposta** para espécies de Conduta Covarde e Curioso: o jogador **fica parado** e oferece Ração; o dino cruza 3 estágios de distância (6, 4 e 2 tiles), com uma **confiança** de 0 a 100 que sobe 10 por segundo com o jogador imóvel e cai 25 se correr ou atacar; ao chegar a 2 tiles, come a cada intervalo da Ração. Sem torpor: sem janela de torpor e sem barra de torpor.
- **Eficiência:** começa em 100, perde `0,1/s` (sem sono, desgaste menor), a drenagem da Ração por refeição (igual à tabela de `racao.md`), e 10 por susto (movimento brusco); ataques de carnívoros contam como em `racao.md` 11. Para não premiar mais o caminho seguro: **teto de E em 70** (bônus máximo de +35%, não +50%). Nível 20 vira 27 no melhor caso, não 30.
- **Conta de tempo:** C em Paquicéfalo: 3 estágios x 10 s + 8 refeições x 5 s = 70 s parado (contra 40 s dormindo), sem nenhum golpe; fome do dino ignorada.
- **Benefício:** trilha alternativa para os tipos que correm; não exige corrida de 4 s de stamina nem perseguição, coerente com o tom acolhedor; o carnívoro ainda ameaça (o dino acordado foge).
- **Escopo:** grande: modo de interação novo, UI de confiança, três estágios por espécie, estado novo no dino e testes de cena (bem maior que o painel de domar).
- **Marco:** M4, com Curioso e Covarde. **Recomendação: adotar no M4** apenas para Curioso e Covarde; o Gallimimus (Covarde, foge a 85 px/s depois de atacado) continua com nocaute (a conta de 94 px/s mostra que dá para pegá-lo). Cortar da 0.2.

### 20.7 Ingredientes que só seus dinos produzem
- **Regra proposta:** o dino domado com Afeto 50 ou mais e ofício "Produzir" gera **1 Orvalho-de-casco a cada 10 min jogados**, com acúmulo de até 5 por dino (30 a 50 min de teto), sem produção offline. A Ração S+ passa a pedir **1 por receita** (rende 2) em vez da Seiva-de-brasa.
- **Conta:** Triceratops em S+ precisa de 8 rações = 4 receitas = 4 unidades. Com 1 produtor: 40 min; 2: 20 min; 4: 10 min. Antes, com a Seiva: 8 S+/h por respawn. Fica configurável: com 4 produtores, 24 unidades por hora.
- **Benefício:** progressão do próprio rebanho (liga ao D5 e ao Afeto) e **troca conteúdo de mundo (Clareira-brasa e carnívoro territorial) por um ofício**.
- **Custo:** um ofício novo (CRI-08 estendido), um item e um timer persistido no save; um dino específico passa a ser necessário, o que cria dependência circular saudável (o Paquicéfalo que você já tem ajuda a domar o Triceratops).
- **Marco:** M4 (S+ já é M4). **Recomendação: adotar, no lugar da Seiva-de-brasa**, e só para S+. Não aplicar a níveis menores: aumentaria a cadeia de produção, que o escopo da 0.2 não comporta.

### 20.8 Receitas achadas no mundo
- **Regra proposta:** as receitas das Rações S e S+ ficam em **fósseis ou marcas nas rochas** em 3 locais do mapa fixo (formação rochosa na Pedreira, gruta na Mata-baixa, clareira; sem ruína, regra 4.1). **Decidido (dono, 06/11): o fóssil é trocado por fóssil ou marca na rocha (impressão natural, nada feito por humano), com a mesma função de ensinar a receita.**
- **Conta:** 3 locais x 3 a 5 min de ida e volta [premissa] = 9 a 15 min de exploração; o mapa de 256x256 (64 s a pé de ponta a ponta) cabe.
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
| 6 | Domesticar sem nocaute | M4 | **DECIDIDO: adotar** (Curioso e Covarde) |
| 7 | Ingrediente produzido por dino | M4 | **DECIDIDO: adotar** (no lugar da Seiva, só S+) |
| 8 | Receitas achadas no mundo | M4 | **DECIDIDO: adiada** |
| 9 | Filhote criado | M4 | **DECIDIDO: adotar** |
| 10 | Prévia e JSON | M2 | **DECIDIDO: adotar** |

Itens que entram na 0.2: 1, 3 e 10. Os demais ficam para o M4 ou são rejeitados. O que não está provado: valores de 1%/s, 50% e 70% de teto são [premissa]; a sensação de 70 s parado sem torpor e o valor do exploratório de fósseis só playtest responde.

