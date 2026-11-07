# Estilo visual do Dino Vale

**Decisão do dono (05/11/2026): o estilo-base é o pacote Ninja Adventure (CC0)** para ambiente, interface e sons. A arte anterior gerada por script (`gerar_arte.gd`, `mock-vale.png`, `mock-vale-2x.png`, `folha-sprites-8x.png`, 49 cores, perspectiva própria) foi **descartada** pelo dono e fica na pasta só como histórico. Não use essas imagens como referência de estilo.

Onde estão os assets: `game/assets/third_party/ninja-adventure/` (mapa de uso em `MAPA.md` da pasta; registro em `game/assets/CREDITS.md`). Prova visual da combinação: `docs/design/arte/pacotes/mock-pacotes-2x.png`. Comparação de pacotes e licenças: `docs/design/arte/pacotes/PACOTES.md`.

## Direção

- **Sensação:** fazenda aconchegante. O mundo é acolhedor; **os animais trazem o perigo**.
- **Carisma só na propaganda e nos filhotes.** Dino adulto é neutro; carnívoro adulto é agressivo.
- Vista **3/4 (de cima)**, personagens de frente na pose padrão, 4 direções (baixo, cima, esquerda, direita). Grade **16x16**; câmera **320x180** (20 x 11,25 tiles), 4x em 1280x720.
- Natureza cheia de miudezas (flores, pedras, tufos, arbustos), como no pacote.

## Regras herdadas do pacote (para tudo que for desenhado novo)

- **Contorno de 1 px escuro**, quase preto azulado: `#141b1b` (a cor mais escura da paleta do pacote). Nunca preto puro, nunca sem contorno. É o que separa o personagem do chão.
- **3 a 4 tons por forma**, sem gradiente suave, sem anti-aliasing, sem pixel solto. Realce claro na borda de cima e esquerda, tom escuro embaixo e à direita.
- **Luz de cima** (levemente à esquerda). Sem sombra projetada pintada no sprite, a menos que o jogo defina uma sombra única.
- **Paleta do pacote**: 54 cores em `third_party/ninja-adventure/palette.png` (tons quentes de terra e laranja, verdes oliva, azuis-ardósia, vermelho e rosa). Cor nova só se vier dessa paleta; se faltar uma, pedir ao dono. Referência de ambiente: grama oliva `#a8a129`/`#adbc3a`, terra `#d3865f`, laranja `#ef914f`, azul `#2d697b` e `#79b8ce`.
- **Formas chibi**: cabeça grande, corpo curto, olhos de 1 px (adulto) ou 2x2 com brilho (filhote).
- Sem texto nos sprites.

## Tamanhos

| Elemento | Quadro | Observação |
|---|---|---|
| Tile | 16x16 | |
| Jogador | **16x32** (humano = porte Médio, GDD 4.2) | 4 direções (3 desenhadas), andar 4, parado 2, golpe 4, coleta 3, ferido, morto; o caveman de 16x16 do pacote sai |
| Dino por porte | **Diminuto 16x16, Pequeno 24x24, Médio 32x32, Grande 48x48, Muito grande 64x64, Gigante 128x96** | pés na linha de baixo do quadro; colisão só nos pés (GDD 4.2) |
| Filhote de dino | um porte abaixo do adulto | M4 |
| Árvore | **48x80** (era 48x48, que ficaria com 1,5 humano) | colisão só no tronco (12x8) |
| Casa | 64x81 (telhado + frente) | **Só peça que o jogador constrói; nunca cenário** (regra de mundo, GDD 4.1) |
| Ícones de item | 16x16 (comida 15x15, sementes 8x8) | |

## Interface

Painéis de madeira 9-slice, barras mini sobre o dino (18x4), esferas e corações do pacote, emotes de balão (zz, !, ?, coração). Limitação conhecida: só há barra mini vermelha; se o jogo precisar de cores distintas para vida e confiança, isso é uma **encomenda pequena** ou usar a esfera verde/amarela.

## Sons

Efeitos curtos do pacote (golpe, dor/voz, ataque, menu, coleta) já importados, com ressalva: **ninguém ouviu os arquivos ainda** (ver `MAPA.md`). Faltam sons de dino (rugido, ronco de sono, mordida, filhote).

## Dinos: especificação para encomendar

O pacote não tem dinos nesse estilo. Os bichos importados (Reptile, Lizard, Grey Trex, etc.) são **placeholder** e ficam 16x16 chibi. Os dois pacotes de dinos avaliados foram recusados (ver `pacotes/PACOTES.md`). O briefing para um artista humano (ou arte própria revisada, que entra como placeholder até a troca):

**Entregar, para cada espécie**:

1. **Quadro por porte (GDD 4.2): Diminuto 16x16, Pequeno 24x24, Médio 32x32, Grande 48x48, Muito grande 64x64, Gigante 128x96; filhote um porte abaixo**, mesmo desenho base, proporções diferentes: o filhote tem cabeça grande, olho 2x2 com brilho, bochecha, cores vivas (é o contraste com o adulto); o adulto tem postura baixa e séria, olho de 1 px sem brilho, boca reta (herbívoro) ou mandíbula com dentes e sobrancelha baixa (carnívoro). Adulto é **neutro ou agressivo, nunca simpático**.
2. **4 direções**: baixo, cima, esquerda, direita. A direita pode ser o espelho da esquerda (o jogo espelha) se o desenho for simétrico em luz; se não, desenhar as duas. A luz continua vindo de cima à esquerda, então para a direita desenhar à parte ou aceitar o espelho conscientemente.
3. **Poses e animações**, em grade regular, um arquivo por espécie e idade, com nome e tamanho de quadro documentados (cada linha uma animação):
   - **andar**: 4 quadros por direção;
   - **parado**: 2 quadros por direção (pode ser o primeiro quadro de andar);
   - **dormir**: 1 a 2 quadros, deitado (ver de cima, 3/4), 1 pose basta para as 4 direções;
   - **ferido**: 1 quadro por direção (ou 1 quadro só, com 2 tons de cor de dano);
   - **ataque** (adulto carnívoro, e opcional no herbívoro): 3 a 4 quadros por direção, com a boca/garra abertas no quadro de impacto. O efeito de dano (garra, corte) já vem do pacote (`fx/`) e **não faz parte da encomenda**.
4. **Aparência**: contorno `#141b1b` de 1 px, 3 a 4 tons por forma, só cores da paleta do pacote. Herbívoro em tons de terra ou azul-ardósia, carnívoro em laranja-escuro/vermelho e marrom com listras, para **ler a ameaça pela silhueta e por 1 ou 2 cores** no tamanho do porte (16 a 48 px na 0.2).
5. **Formato**: PNG com fundo transparente, 1 sprite sheet por espécie e idade (por exemplo, `rex_adult.png` com colunas de 64 px de largura, 64 x nº de linhas de altura), âncora com os pés na base do quadro, sem sombra pintada, sem anti-aliasing. Fornecer também o `.aseprite` (ou os arquivos de origem).
6. **Licença**: CC0 ou CC BY 4.0, com autor identificado. Registrar em `game/assets/CREDITS.md`. Nada com NC ou ND. Arte gerada por IA só como placeholder.
7. **Teste de aceitação**: o dino ao lado do jogador e de uma árvore do pacote, em tamanho real e ampliado, sem parecer colado (mesmo contorno, mesma densidade de detalhe, mesma luz).

Espécies do MVP: ver o plano de design (`docs/`), a cargo da `SHIRO`.

## Decisões em aberto

1. Aprovar o tom do mundo (oliva forte e laranja) e o Caveman como jogador, ou trocar por Cavegirl ou por um personagem encomendado.
2. Barras de cor distinta (vida, confiança, fome): só vermelho no pacote.
3. Quem desenha os dinos e em que prazo (artista humano versus arte própria revisada).
4. Música e trilha: o pacote tem 37 faixas, não avaliadas nem importadas.

## Primeira leva da escala nova (06/11/2026)

Tudo arte propria por script (CC BY 4.0), paleta do pacote conferida ao gravar, alfa 0/1. Regenerar da raiz do repositorio: `godot --headless --script docs/design/arte/gerar_jogador.gd` (idem `gerar_terreno.gd`, `gerar_cenario.gd`); `arte_lib.gd` e comum; `montar_cena.gd -- <pasta>` monta a cena 320x180 (4x), a folha do jogador e o teste de ladrilhamento.

- **Jogador** `sprites/jogador/jogador.png` (160x128, quadro 16x32, 10 colunas x 4 linhas) e `jogador.json`. Linhas: baixo, cima, esquerda, direita (a direita e desenhada, nao espelho). Colunas: 0-1 parado, 2-5 andar, 6-8 golpe (preparo, impacto, volta), 9 caido. Pes em y=30, contorno em y=31. Sem equipamento: camadas depois, no mesmo quadro.
- **Terreno** `sprites/cenario/terreno.png` (256x400) e `terreno.json`. Terrenos em rank: 0 agua funda, 1 agua rasa, 2 praia, 3 Campina, 4 Mata-baixa, 5 Pedreira, 6 trilha (so por cima). Linhas 0-6: 16 variacoes cheias por terreno (0-7 lisas, 8-15 com detalhe). Linhas 7-24: transicao tipo blob de 47 tiles por terreno (rank 1 a 6), com FORA transparente: empilhe uma camada por rank, e a camada R recebe a mascara dos vizinhos com rank >= R (mascara no JSON). Mata-baixa sobre Campina, Pedreira sobre Mata-baixa, praia sobre agua rasa com espuma. Sem animacao de agua nesta leva.
- **Recursos** em `sprites/recursos/`: `tree_collect_80.png` (48x80, tronco de 12 px no pe, colisao 12x8), `rock_stone_32.png` e `rock_ore_32.png` (32x32) e `*_empty_32.png`. Os arquivos antigos (16 px e 32x48) ficam ate o SORA trocar; o toco de 16x16 serve de esgotado da arvore.
- **Cenario** em `sprites/cenario/`: `formacao_a` (64x80, espigoes), `formacao_b` (96x48, crista), `formacao_c` (64x48, matacoes), natural, sem construcao.
  A nevoa de borda virou shader (07/11) e a imagem `nevoa_borda.png` foi removida.

## Segunda leva (07/11/2026)

- **Dinos** `sprites/dinos/<especie>.png` + `.json`: dodo 16, paquicefalo 24, parassaurolofo 32, utahraptor 32, triceratops 48. Gerador `gerar_dinos.gd`. Layout igual nas cinco: 11 colunas x 4 linhas (down, up, left, right); colunas 0-1 parado, 2-5 andar, 6-8 golpe (Dodo e Parassaurolofo: susto, sem ataque), 9 dormindo, 10 morto. Dormindo e morto sao desenhados de lado (down/left olham esquerda, up/right direita). Pes em y=S-2. Estado: placeholder de script revisado; as vistas de frente e de costas de Parassaurolofo e Utahraptor leem menos que as de lado.
- **Jogador** revisado (`gerar_jogador.gd`): andar de frente/costas com 4 quadros distintos, golpe para cima refeito, caido nas 4 direcoes (de costas, de bruços, de lado esq/dir).
- **Icones 8x8** `sprites/ui/icon_{feather,shield,bolt,target,weight}.png` (`gerar_ui.gd`): pena branca, escudo verde, raio vermelho, alvo, peso.
- **Conferencia**: `montar_dinos.gd -- <arquivo.png>` monta os dinos ao lado do humano, em 1x e 4x, sobre Campina e Pedreira.
- Regenerar tudo: `godot --headless --script docs/design/arte/gerar_dinos.gd` (idem `gerar_jogador.gd`, `gerar_ui.gd`).
