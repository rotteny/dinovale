# Roteiro de playtest do M1 "Ameaça e corpo"

Para o dono jogar no Windows com `Jogar-dev.bat`, sempre em **mundo novo** (Novo jogo, sem Continuar). O jogo de desenvolvimento já vem com o Bastão-de-sono e a Lança no inventário. Você não precisa saber nada do código: joga, olha e anota.

Como usar: faça os cenários na ordem, um de cada vez. Depois de cada um, anote na tabela do fim (uma linha por cenário). Se quiser repetir um cenário, é só repetir: quanto mais vezes, melhor a resposta. Os "números" (segundos, dano) são os de agora; o objetivo é saber se **parecem certos**, não se estão certos.

Atalhos que vão ser úteis: andar WASD, correr Shift, golpear F ou clique esquerdo, interagir E, ordem Seguir/Ficar G, inventário I, atalhos 1 a 9, histórico do log L.

Resumo do que o jogo deve fazer (para você conferir): o dino que leva golpe fica bravo e acalma sozinho depois de uns 8 s sem bater nem apanhar; o Utahraptor morde; quem cai fica deitado por 10 s; quem morre deixa o corpo com todos os itens por 10 min.

---

## 1. Andar com o domado

**O que fazer:** doma um Paquicéfalo (Bastão-de-sono, depois bagas) e deixa em Seguir (G). Ande em volta de uma árvore grande, de um grupo de árvores e da água. Depois ande para longe, para dentro da mata, e volte.

**O que deve acontecer:** o dino contorna árvore e rocha, não fica colado nelas e te alcança. Se ele ficar preso longe e fora da tela, o log escreve "ficou preso" uma vez e ele para (nunca some nem teleporta). Se ficar preso perto, na tela, não escreve nada e continua tentando.

**Pergunta P6:** você entendeu o "ficou preso" e o que fazer? Em quantas vezes o dino realmente ficou preso, e em quantas pareceu defeito do jogo?

## 2. Paquicéfalo bravo e o bando

**O que fazer:** chegue perto de um bando (3 a 4 Paquicéfalos) e dê um golpe com o **punho** em um deles. Fique por perto uns 10 segundos, depois se afaste e fique longe 10 segundos. Repita com o Bastão-de-sono em outro bando, como se fosse domar.

**O que deve acontecer:** o golpeado ganha um "!" vermelho, o "Nv" dele fica avermelhado, ele encara, rodeia e cabeceia (dano 6 em você, com recuo curto). Meio segundo depois dois colegas do bando vêm ajudar (o quarto só olha). Sem bater nem apanhar por uns 8 s, eles acalmam e o "!" some; o próximo golpe começa tudo de novo.

**Perguntas:**
- **P1:** o "!" e o grunhido bastam para entender que o dino ficou bravo e que ele acalma sozinho? Ou parece que você perdeu a luta?
- **P2:** o revide do bando é justo na primeira doma (4 golpes de Bastão)? Em 5 tentativas, quantas vezes você conseguiu alimentar o dormindo sem sair do lugar e sem perder mais de 40 de vida?
- **P7:** o revide atrapalha tanto que você passa a evitar o Paquicéfalo?

## 3. Utahraptor ameaçando e mordendo

**O que fazer:** ande até a Mata-baixa (onde as árvores são mais fechadas, longe da Campina onde você nasce) e procure um bando de Utahraptor (2 a 3). Entre no campo de visão dele e **não lute**: fique parado uns 3 segundos. Depois repita e **fuja** correndo em linha reta, a partir de uns 8 passos de distância. Depois repita e **lute** com o Bastão-de-sono.

**O que deve acontecer:** ele grunhe e aparece o "!" vermelho; se você está longe ele vem correndo, se está perto ele para um instante e encara. A mordida tira 8 de vida, a cada 1,5 s. Ele desiste se você foge longe, some da vista dele por uns 5 s, ou ele leva 15 s te perseguindo. Com o Bastão ele cai em poucos golpes.

**Perguntas:**
- **P3:** o bando de Utahraptor é "a maior ameaça do mapa", ou você simplesmente nunca mais entra na mata? A fuga, a 8 passos, com margem curtíssima, é tensão boa ou injusta?
- **P1 (de novo):** a hora do "!" e do grunhido deu tempo de reagir?

## 4. Utahraptor caçando Paquicéfalo e domado

**O que fazer (a):** fique longe e **observe**: encontre um Utahraptor perto de um bando de Paquicéfalo (a mata e as bordas perto das tocas são os lugares mais prováveis). Fique a uns 10 passos, fora do alcance da vista dele, e só olhe por 1 a 2 minutos.
**O que fazer (b):** com o domado em Seguir, ande até a vista de um Utahraptor, perto do bando de Paquicéfalo e do seu domado.

**O que deve acontecer:**
- (a) O Utahraptor que persegue um Paquicéfalo mostra "!" **laranja** (caçando outro, não você). O Paquicéfalo foge e o bando ajuda. Quando o raptor abate, ele come a presa inteira, e depois fica "saciado" (alguns minutos sem caçar). Bando de Paquicéfalo nunca cai abaixo de 2 vivos, e o bando que perde membro volta a crescer com o tempo. Se você bate no raptor enquanto ele caça, ele larga a presa e vem em você.
- (b) Seu domado foge do raptor (sem revidar), o log avisa "<nome> está sendo atacado por Utahraptor", e se ele morrer o log diz "foi morto" e o alforje dele fica no chão para você pegar. Seu domado nunca é caçado se estiver na Campina onde você nasce (zona segura) ou se você estiver muito longe.

**Perguntas:**
- **P8:** você entendeu o "!" laranja como "está caçando outro" e agiu ("passo por trás") em vez de se achar a presa?
- **P9:** o bando de Paquicéfalo reduzido (2 a 3 de 4) ainda parece um bando, ou o mapa parece vazio?
- **P10:** quantas caçadas você viu por hora numa região exposta?
- **P11:** perder um domado para o raptor é "a natureza cobra" ou "o jogo pune quem cuida"? O aviso do log chegou a tempo de você fazer alguma coisa?

## 5. Ficar caído

**O que fazer:** deixe um Utahraptor te morder até a vida chegar a zero (ou deixe a fome chegar a zero e espere: o torpor sobe e você apaga). Não faça nada durante o desmaio.

**O que deve acontecer:** "Você caiu." Você fica deitado, de lado, respirando, sem andar nem golpear nem usar item, por 10 s. Com **1** Utahraptor mordendo, você sobrevive e acorda ("Você acordou. Corra!") com uns 14 de vida e 2 s sem poder levar dano. Com **2 ou 3**, você morre em 4 a 6 s. Paquicéfalo nunca ataca quem está caído.

**Pergunta P4:** 10 s de desmaio: você sentiu que "perdeu o controle" ou só "esperou"? Que duração dá medo sem dar raiva (8, 10, 12 ou 20 s)?

## 6. Morrer e recuperar o corpo

**O que fazer:** deixe 2 ou 3 Utahraptors te matarem estando caído (com itens no inventário e nos atalhos). Na tela de morte, escolha "Local aleatório". Volte ao corpo e aperte E sobre ele. Depois, num outro teste, **feche o jogo na tela de morte** e abra de novo (Continuar).

**O que deve acontecer:** "Você morreu. Seus itens ficaram no corpo." Você renasce com vida cheia, fome pela metade e inventário vazio, longe dos selvagens bravos, com 3 s de proteção. O corpo (desenho com a trouxa e um brilho) fica 10 min no lugar; passe o mouse sobre ele para ver "Seus itens x N". E sobre o corpo devolve tudo; se passar de 10 min, "Seu corpo sumiu: N itens se perderam". Nível, XP e dinos domados não mudam. Fechar na tela de morte e abrir de novo volta à tela de morte.

**Perguntas:**
- **P5:** perder o inventário no corpo por 10 min é uma penalidade aceita ou dá vontade de largar o jogo? Você conseguiu recuperar o corpo? Em quanto tempo?
- **P4 (de novo):** o fim do desmaio com morte pareceu justo?

## 7. Clique na moita

**O que fazer:** perto de uma moita de bagas, clique com o botão esquerdo **na moita**, sem nenhuma criatura sob o cursor. Depois clique numa árvore, numa pedra e num item caído no chão. Clique também numa moita **longe**. Por fim, colha duas moitas seguidas.

**O que deve acontecer:** moita e item no chão são colhidos pelo clique (como a tecla E); árvore e rocha levam golpes. Longe demais: nada acontece e o log explica. Entre duas coletas concluídas há uma espera de 1 a 2 s (sem mensagem). Clicar numa criatura continua sendo golpe.

**Pergunta (sem número):** o clique fez o que você esperava, sem acidente (golpe sem querer, coleta sem querer)?

## 8. Cursores e ícone de stamina

**O que fazer:** passe o mouse por moita, árvore, pedra, item no chão, dino selvagem, domado, e por algo fora de alcance. Depois corra (Shift) até o fôlego acabar e solte, observando a barra de stamina abaixo da fome.

**O que deve acontecer:** o cursor muda (mão para colher e pegar, machado na árvore, picareta na pedra, ataque no selvagem, interagir) e apaga fora de alcance. A barra de stamina tem o ícone novo, muda de tom quando está curta (você ofega) e fica cinza ao esgotar, e só volta a correr depois de recuperar um pouco.

**Pergunta (sem número):** o cursor sempre diz o que o clique vai fazer? O ícone da stamina é fácil de ler?

---

## Tabela para anotar

Marque "ok", "estranho" ou "ruim" e escreva uma frase. A coluna "vezes" é quantas vezes você repetiu.

| # | Cenário | Perguntas | Vezes | Ok / estranho / ruim | Anotação (o que viu, o que sentiu) |
|---|---|---|---|---|---|
| 1 | Andar com o domado | P6 | | | |
| 2 | Paquicéfalo bravo e o bando | P1, P2, P7 | | | |
| 3 | Utahraptor ameaçando e mordendo | P1, P3 | | | |
| 4 | Utahraptor caçando | P8, P9, P10, P11 | | | |
| 5 | Ficar caído | P4 | | | |
| 6 | Morrer e recuperar o corpo | P4, P5 | | | |
| 7 | Clique na moita | | | | |
| 8 | Cursores e ícone de stamina | | | | |

### Registro por episódio (uma linha por vez que algo bravo aconteceu)

| Quem ficou bravo | Quanto tempo ficou bravo | Vida que você perdeu | Morreu? | Caiu? | Algum "ficou preso"? | Pareceu bug? |
|---|---|---|---|---|---|---|
| | | | | | | |
| | | | | | | |
| | | | | | | |

### No fim, três respostas

1. O perigo deu medo sem dar raiva? Em que ponto passou da conta?
2. Algo pareceu **injusto** (morte sem aviso, dano que você não viu vir)? O quê?
3. O que você mudaria primeiro: o tempo caído, o revide do bando, a velocidade do raptor, a perda do corpo ou outra coisa?
