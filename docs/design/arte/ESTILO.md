# Estilo visual do Dino Vale

**Decisão do dono (05/11/2026): o estilo-base é o pacote Ninja Adventure (CC0)** para ambiente, interface e sons. A arte anterior gerada por script (`gerar_arte.gd`, `mock-vale.png`, `mock-vale-2x.png`, `folha-sprites-8x.png`, 49 cores, perspectiva própria) foi **descartada** pelo dono e fica na pasta só como histórico. Não use essas imagens como referência de estilo.

Onde estão os assets: `game/assets/third_party/ninja-adventure/` (mapa de uso em `MAPA.md` da pasta; registro em `game/assets/CREDITS.md`). Prova visual da combinação: `docs/design/arte/pacotes/mock-pacotes-2x.png`. Comparação de pacotes e licenças: `docs/design/arte/pacotes/PACOTES.md`.

## Direção

- **Sensação:** fazenda aconchegante. O mundo é acolhedor; **os animais trazem o perigo**.
- **Carisma só na propaganda e nos filhotes.** Dino adulto é neutro; carnívoro adulto é agressivo.
- Vista **3/4 (de cima)**, personagens de frente na pose padrão, 4 direções (baixo, cima, esquerda, direita). Grade **16x16**.
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
| Jogador | 16x16 | Caveman do pacote (4 direções, 4 quadros de andar, ataque, pulo, morto) |
| Filhote de dino | **16x16** | |
| Dino adulto | **32x32** (2x2 tiles) | pés apoiados na linha de baixo do quadro |
| Árvore | 48x48 | colisão só no tronco |
| Casa | 64x81 (telhado + frente) | |
| Ícones de item | 16x16 (comida 15x15, sementes 8x8) | |

## Interface

Painéis de madeira 9-slice, barras mini sobre o dino (18x4), esferas e corações do pacote, emotes de balão (zz, !, ?, coração). Limitação conhecida: só há barra mini vermelha; se o jogo precisar de cores distintas para vida e confiança, isso é uma **encomenda pequena** ou usar a esfera verde/amarela.

## Sons

Efeitos curtos do pacote (golpe, dor/voz, ataque, menu, coleta) já importados, com ressalva: **ninguém ouviu os arquivos ainda** (ver `MAPA.md`). Faltam sons de dino (rugido, ronco de sono, mordida, filhote).

## Dinos: especificação para encomendar

O pacote não tem dinos nesse estilo. Os bichos importados (Reptile, Lizard, Grey Trex, etc.) são **placeholder** e ficam 16x16 chibi. Os dois pacotes de dinos avaliados foram recusados (ver `pacotes/PACOTES.md`). O briefing para um artista humano (ou arte própria revisada, que entra como placeholder até a troca):

**Entregar, para cada espécie**:

1. **Adulto 32x32 e filhote 16x16**, mesmo desenho base, proporções diferentes: o filhote tem cabeça grande, olho 2x2 com brilho, bochecha, cores vivas (é o contraste com o adulto); o adulto tem postura baixa e séria, olho de 1 px sem brilho, boca reta (herbívoro) ou mandíbula com dentes e sobrancelha baixa (carnívoro). Adulto é **neutro ou agressivo, nunca simpático**.
2. **4 direções**: baixo, cima, esquerda, direita. A direita pode ser o espelho da esquerda (o jogo espelha) se o desenho for simétrico em luz; se não, desenhar as duas. A luz continua vindo de cima à esquerda, então para a direita desenhar à parte ou aceitar o espelho conscientemente.
3. **Poses e animações**, em grade regular, um arquivo por espécie e idade, com nome e tamanho de quadro documentados (cada linha uma animação):
   - **andar**: 4 quadros por direção;
   - **parado**: 2 quadros por direção (pode ser o primeiro quadro de andar);
   - **dormir**: 1 a 2 quadros, deitado (ver de cima, 3/4), 1 pose basta para as 4 direções;
   - **ferido**: 1 quadro por direção (ou 1 quadro só, com 2 tons de cor de dano);
   - **ataque** (adulto carnívoro, e opcional no herbívoro): 3 a 4 quadros por direção, com a boca/garra abertas no quadro de impacto. O efeito de dano (garra, corte) já vem do pacote (`fx/`) e **não faz parte da encomenda**.
4. **Aparência**: contorno `#141b1b` de 1 px, 3 a 4 tons por forma, só cores da paleta do pacote. Herbívoro em tons de terra ou azul-ardósia, carnívoro em laranja-escuro/vermelho e marrom com listras, para **ler a ameaça pela silhueta e por 1 ou 2 cores** a 32 px.
5. **Formato**: PNG com fundo transparente, 1 sprite sheet por espécie e idade (por exemplo, `rex_adult.png` 128x(32 x nº de linhas)), âncora com os pés na base do quadro, sem sombra pintada, sem anti-aliasing. Fornecer também o `.aseprite` (ou os arquivos de origem).
6. **Licença**: CC0 ou CC BY 4.0, com autor identificado. Registrar em `game/assets/CREDITS.md`. Nada com NC ou ND. Arte gerada por IA só como placeholder.
7. **Teste de aceitação**: o dino ao lado do jogador e de uma árvore do pacote, em tamanho real e ampliado, sem parecer colado (mesmo contorno, mesma densidade de detalhe, mesma luz).

Espécies do MVP: ver o plano de design (`docs/`), a cargo da `SHIRO`.

## Decisões em aberto

1. Aprovar o tom do mundo (oliva forte e laranja) e o Caveman como jogador, ou trocar por Cavegirl ou por um personagem encomendado.
2. Barras de cor distinta (vida, confiança, fome): só vermelho no pacote.
3. Quem desenha os dinos e em que prazo (artista humano versus arte própria revisada).
4. Música e trilha: o pacote tem 37 faixas, não avaliadas nem importadas.
