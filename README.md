# Dino Vale

Dino Vale é um jogo 2D de sobrevivência em pixel art, com visão de cima, em que você explora um vale habitado por dinossauros, constrói sua base e transforma criaturas selvagens em companheiras.

É um jogo comunitário: gratuito, de código aberto e pensado para que cada grupo de jogadores possa hospedar o próprio mundo.

> **Estado do projeto:** em desenvolvimento inicial. Ainda não existe versão para baixar e jogar. Por enquanto, o repositório contém a fundação técnica do jogo.

## A proposta

A ideia é unir o ritmo tranquilo de cuidar de um lugar seu com a tensão de sobreviver em um ambiente selvagem. Você começa com pouco, precisa manter a fome e a energia sob controle e aprende a conviver com as criaturas do vale.

O jogo se apoia em três pilares:

- **Sobreviver:** administrar vida, energia e fome enquanto explora o mapa.
- **Domesticar:** derrubar uma criatura sem matá-la, alimentá-la enquanto está inconsciente e conquistá-la antes que ela acorde.
- **Construir:** erguer uma base peça por peça, com fundações, paredes e baús alinhados a um grid.

### Como funciona a domesticação

Toda criatura tem uma barra de **torpor**, separada da vida. Quando o torpor chega ao máximo, ela desmaia. A partir daí começa uma corrida contra o tempo: você oferece a comida ideal e, a cada refeição, o progresso de domesticação aumenta. Se ela acordar antes do fim, o progresso se perde. Se a barra encher, a criatura passa a ser sua companheira.

### Inspirações

Dino Vale é inspirado em jogos que admiramos: *ARK: Survival Evolved*, pela domesticação de criaturas e pela sobrevivência; *Stardew Valley*, pelo ritmo de cuidar de um lugar seu e pelo visual de fazenda em pixel art; e *Terraria*, pela exploração e pela construção em 2D.

Dino Vale é um projeto independente, sem vínculo com esses jogos ou com seus criadores. Todos os nomes pertencem aos seus respectivos donos.

## Para que este jogo existe

Dino Vale nasce de três objetivos:

- **Ser livre:** sem preço, sem microtransações e sem depender de uma empresa para continuar no ar.
- **Pertencer à comunidade:** a meta é que qualquer grupo possa rodar o próprio servidor, com seus mundos e suas regras. O multiplayer e o servidor dedicado estão planejados, mas ainda não existem.
- **Ser aberto:** o código pode ser estudado, modificado e reaproveitado, o que também torna o projeto um exemplo prático de jogo feito em Godot.

## Tecnologia

O jogo é feito em [Godot 4](https://godotengine.org/) com GDScript. As regras ficam separadas da parte visual, para que a mesma lógica possa rodar em um servidor sem interface gráfica.

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| [`game/`](game/) | Projeto Godot. O [README técnico](game/README.md) explica como rodar, a arquitetura e o roadmap. |
| [`html/`](html/) | Landing page de apresentação do jogo. |
| [`docs/`](docs/) | Planejamento do desenvolvimento. |

## Licença

O código é distribuído sob a [licença MIT](LICENSE). A arte e o som próprios usam CC BY 4.0, conforme [ASSETS-LICENSE](ASSETS-LICENSE).
