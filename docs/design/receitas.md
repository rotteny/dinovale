# Dino Vale: receitas e Saber (árvore do personagem)

Anexo do `GDD.md` (em conflito, vale o GDD). Decisão do dono (06/11): o personagem **aprende receitas gastando pontos**. Cinco categorias: **armas, armaduras, mobílias, construções e recursos diversos**. Árvore própria, em português, com nomes comuns; nada de lista, nível, custo ou nome de outro jogo. **Rejeitados:** eletricidade, eletrônicos, explosivos modernos, mergulho, drones, foguetes, tecnologia futurista, luxo sem função. **Sem armas de fogo e sem pólvora, nem na 1.0 (decidido).** Contas em `receitas_sim.py` (`arvore`, `ritmo`, `ordem`, `armadura`). Legenda: **[calculado]** sai do script; **[premissa]** valor a testar jogando.

## 1. Moeda: Saber (pontos de receita)

- **Pool separado dos pontos de atributo (recomendo).** Conta: 19 pontos de atributo (nível 20) mais 22 de receita da 0.2 somam 41 contra 19 disponíveis num pool único [calculado]: o jogador não teria atributo nenhum ou não teria receitas essenciais (Ração B é pedida pelo Utahraptor, o curral protege o dormindo).
- **Ganho:** 1 Saber por nível (L2 a L20), **+1 nos níveis 5, 10, 15 e 20**: 5 em L5, 11 em L10, 23 em L20 [calculado]. Com 13 XP/min: 16 min até L5, 62 min até L10, 4,0 h até L20.
- **Custo por tier:** conhecida 0; T1 1 (curral 2); T2 2 a 3; T3 4; T4 6 [premissa]. Pré-requisito é **outra receita aprendida**, nunca "ter feito" algo.
- **Gastar:** pedido do jogador na tela de receitas; o servidor valida e debita. Sem devolução nem reinício na 0.2.
- **Aprende tudo no teto?** **Na 0.2 sim:** 22 de 23 Saber (sobram 1). Com poucas receitas a escolha é de **ordem** (o que ter aos 16 min, aos 62 min), sem beco sem saída. **Na 1.0 não:** a árvore completa custa 140 Saber contra 59 em L50 (42%) e 89 em L75 (64%) [calculado]; aí o jogador especializa e o **reinício de Saber (pago)** passa a ser necessário. O teto da 1.0 e os custos de T3 e T4 são [premissa] e se ajustam quando o teto for fechado.
- **Começam conhecidas (6), para não travar:** Bancada comum (feita à mão), Bastão-de-sono, Ração C, Fundação, Parede e Porta de madeira. Com elas o jogador doma o Paquicéfalo (baga crua) e o Utahraptor (aceita carne crua) e ergue o abrigo mínimo [calculado: 32 Madeira, 4 Pedra, 1 Fibra]. Nada de M1 e M2 exige aprender para avançar.

## 2. Árvore completa pensada para a 1.0 (57 receitas, metal fora por agora)

**Negrito = v0.2.** Entre parênteses, o custo em Saber. Poucos itens por tier.

### Armas (inclui ferramentas): 15 receitas
| Tier | Itens |
|---|---|
| T1 | **Bastão-de-sono (0)**, **Machado de pedra (1)**, **Picareta de pedra (1)** |
| T2 | **Dardo de sono (2)**, **Bastão reforçado (2, cortável)**, Arco (2), Flecha comum (2), Flecha de sono (2), Boleadeira (2) |
| T3 | Lança de pedra (4), Armadilha de laço (4) |
| T4 | Machado, Picareta, Espada e Besta de metal (6 cada; **fora por agora**) |

### Armaduras: 6 receitas (nenhuma na 0.2)
| Tier | Itens |
|---|---|
| T1 | Traje de pele (1) |
| T2 | Traje de couro (2), Escudo de madeira (2) |
| T3 | Traje de osso e quitina (4) |
| T4 | Traje de metal (6), Escudo de metal (6) (**fora por agora**) |

### Mobílias: 11 receitas
| Tier | Itens |
|---|---|
| T1 | **Bancada comum (0)**, **Baú (1)**, **Cama de fibra (1, cortável)**, Placa (1) |
| T2 | **Cocho (2, cortável)**, Canteiro (2), Tocha (1, só com noite), Tapete de pele (1) |
| T3 | Forja (4, só com metal: fora por agora), Composteira (4), Secador (4, só se a carne passar a apodrecer no inventário) |

### Construções: 11 receitas (peças atacáveis: madeira, palha; pedra imune; **sem estrutura de metal**)
| Tier | Itens |
|---|---|
| T1 | **Fundação, Parede e Porta de madeira (0)**, **Cerca e curral de madeira (2)**, Parede, cerca e porta de palha (1, M4) |
| T2 | **Portão de dino (1)**, Teto (2), Rampa e escada (2) |
| T3 | Fundação e parede de pedra (4), Portão reforçado (4) |
| T4 | Muralha de pedra e argamassa (6) |

### Recursos diversos (processados e consumíveis): 14 receitas
| Tier | Itens |
|---|---|
| T1 | **Ração C (0)**, **Bandagem (1)**, Corda (1) |
| T2 | **Ração B (2)**, **Ração A (3)**, **Preparado de sono (3, cortável)**, Couro curtido (2), Tecido (2), Tijolo (2) |
| T3 | Argamassa (4), Barra de ferro (4), Ração S (só por pergaminho) |
| T4 | Aço (6), Ração S+ (só por pergaminho) |

Base de recursos: `catalogo.md` (básicos, plantas, minerais, animais e refinados). **Fora por regra:** pólvora, vidro de luxo, tudo o que pede armas de fogo.

## 3. Recorte da v0.2: 19 receitas, 6 conhecidas, 22 Saber

| Categoria | Receita | Saber | Pré-requisito | Ingredientes [premissa] | Marco |
|---|---|---|---|---|---|
| Armas | **Bastão-de-sono** | 0 | -- | 2 Madeira, 2 Fibra (M1 entrega o item pronto) | M1 |
| Armas | Machado de pedra | 1 | -- | 2 Madeira, 2 Pedra, 1 Fibra; coleta de madeira -35% | M2 |
| Armas | Picareta de pedra | 1 | -- | idem; coleta de pedra -35% | M2 |
| Armas | Dardo de sono | 2 | -- | 2 Fibra, 1 Pedra rendem 3 | M2 |
| Armas | Bastão reforçado (cortável) | 2 | Bastão | 1 Bastão, 2 Couro; torpor 36 | M2 |
| Mobílias | **Bancada comum** | 0 | -- | 6 Madeira, 4 Pedra | M2 |
| Mobílias | Baú | 1 | -- | 6 Madeira, 1 Fibra; guarda 100 kg | M2 |
| Mobílias | Cama de fibra (cortável) | 1 | -- | 6 Fibra, 2 Madeira; ponto de renascimento (liga à seção 12 do GDD; conferir) | M2 |
| Mobílias | Cocho (cortável) | 2 | Baú | 6 Madeira, 2 Pedra; guarda 10 Rações; o rebanho come sozinho com fome abaixo de 40 | M2 |
| Construções | **Fundação** | 0 | -- | 3 Madeira, 1 Pedra | M2 |
| Construções | **Parede** | 0 | -- | 2 Madeira (60 de vida) | M2 |
| Construções | **Porta** | 0 | -- | 4 Madeira, 1 Fibra (120 de vida) | M2 |
| Construções | Cerca e curral | 2 | Parede | 2 Madeira por peça (60 de vida); curral 3 x 3 = 12 peças, 24 Madeira (12 kg) | M2 |
| Construções | Portão de dino | 1 | Cerca e curral | 4 Madeira, 2 Fibra (120 de vida) | M2 |
| Recursos | **Ração C** | 0 | -- | `racao.md` 2.2 | M2 |
| Recursos | Ração B | 2 | Ração C | `racao.md` 2.2 (Tubérculo, Sal) | M2 |
| Recursos | Ração A | 3 | Ração B | `racao.md` 2.2 | M2 |
| Recursos | Bandagem | 1 | -- | 3 Fibra, 1 Samambaia; cura 30 de vida em 3 s | M2 |
| Recursos | Preparado de sono (cortável) | 3 | Dardo de sono | 3 Fruta-do-sono, 1 carne podre rendem 3 | M2 |

Cadeia mais longa: 2 (Ração C, B, A). Ordem recomendada com 13 XP/min [calculado]: Dardo (L3, 6 min), Ração B (L5, 16 min), Curral (L6), Machado, Picareta, Baú, Bandagem (L10, 62 min), Portão, Cama, Ração A (L14, 120 min), Cocho, Preparado (L18), Bastão reforçado (L20, 241 min). **Cortar se apertar:** Bastão reforçado, Cama, Cocho, Preparado (8 Saber, 4 receitas): sobram 15 receitas, dentro da faixa pedida.

## 4. Armaduras

**Regra mais simples:** **dois slots**, Traje (corpo) e Escudo (mão livre), cada peça com **redução fixa de dano** físico recebido (mordida e golpe), **sem durabilidade**, que **soma até o teto de 50%**. Traje: T1 10%, T2 20%, T3 30%, T4 40%; Escudo de madeira +10%; peso: 2, 5, 9 e 14 kg e 3 kg do escudo [premissa]. **Peso conversa com a armadura:** a peça equipada **conta no Peso**: o T4 ocupa 28% dos 50 kg do jogador, e cada ponto de Peso (3 kg) paga cerca de um quinto de uma peça. Escolha real entre carregar recurso e vestir. Fome não é reduzida; a perda de Eficiência por mordida no dormindo não muda.

**A v0.2 precisa de armadura? Não.** Conta (`receitas_sim.py armadura`): na 0.2 o jogador leva 1 mordida por luta (Utahraptor L20 mordida 11,2; Triceratops L28 mordida 34,4), então o T1 poupa 1 a 3 de vida. Só pesa em nível alto: Triceratops L42, 2 mordidas de 45,6 (91 de 100 de vida) caem para **73 com T2, 64 com T3 e 55 com T4**, e com 10 pontos de Dano (1 mordida) de 46 para 27. Isso é M4, quando a Pedreira ampliada (15 a 45) e o nível 30 a 50 existem.

**O couro sem uso resolve com armadura de couro?** Não na 0.2: o Bastão reforçado (1 h) dá -0,7 s de nocaute no Utahraptor L20 (3,5 para 2,8 s) e é o sumidouro mais barato; **mantenho o Bastão reforçado como cortável** (decidido). O traje de couro leva o couro no M4.

**Marco M4, custo [estimativa minha, premissa; `SHIKAMARU` confirma]:** 2 slots de equipamento, interface e save 3 h; `ArmorDef` e redução em `take_damage` 1,5 h; peso equipado 0,5 h = **5 h**. Arte: **só ícones** no começo (sem camada de sprite no personagem): 6 ícones; camada visual no personagem é custo alto e fica para depois. **Armadura para dino** só com arreio e montaria (M6+).

## 5. Mobílias: função ou decoração barata

| Peça | Benefício | Marco |
|---|---|---|
| Bancada comum | estação de todas as receitas | M2 |
| Baú | guarda 100 kg [premissa] | M2 |
| Cama de fibra | **ponto de renascimento** | M2 cortável |
| Cocho | guarda Ração e alimenta o rebanho com fome baixa | M2 cortável |
| Canteiro | produz baga (1 a cada 4 min, até 5) [premissa] | M4 |
| Composteira | transforma sobras e carne podre em adubo, canteiro x1,5 | M4+ |
| Forja | estação de metal | fora por agora |
| Secador | carne conservada, **só** se a carne passar a apodrecer (hoje não apodrece) | futuro condicional |
| Tocha | luz, só com dia e noite (cortado) | M4 |
| **Só visual (máximo 3):** Placa (nome de baú ou curral, texto limpo de 20 caracteres), Tapete de pele | barato, sem função | M4 |

Fogueira e pilão **ficam fora**: a fogueira não tem função sem noite, temperatura e cozinhar (cozinhar viraria espera com timer, defeito); o pilão não se justifica (a Ração se faz na bancada comum, decidido). Mesa, cadeira e estante: luxo sem função, **rejeitados**.

## 6. Recursos diversos (refinados)

Processados na **bancada comum** (T1 e T2) ou na **forja** (T3 e T4), **4 s, sem timer de espera**: Corda (3 Fibra rendem 1), Couro curtido (Couro e Sal), Tecido (2 Corda), Tijolo (Argila e Palha), Argamassa (Cal e Areia), Barra de ferro (Ferro e Carvão), Aço (Ferro e mais Carvão). Consumíveis: Ração C, B e A, Bandagem, Preparado de sono (a S e a S+ só por pergaminho). **Corda** ensina o jogador a ligar fibra a arma (Arco, Armadilha, Tecido). **Pólvora: fora**, junto com as armas de fogo.

## 6b. Estruturas e dano de dino (decisão do dono, 06/11; regra completa em `GDD.md` 8.1)

- **Materiais, do mais frágil ao imune:** palha (10 de vida por unidade) > madeira (30) > pedra (**imune**). **Metal fora por agora**, sem estruturas de metal; a Barra de ferro, a Forja e as peças de metal ficam como futuro, não são estruturas.
- **Quem ataca peças:** Agressivo (Utahraptor) com alvo dentro e sem caminho por 2 s; Semi-agressivo (Triceratops) só provocado. Passivo, Medroso, Covarde, Curioso e domados nunca.
- **Contas [calculado, `estruturas_sim.py`]:** Utahraptor L20 rompe cerca ou parede de madeira em **8,0 s**, porta em 16,1 s; palha em 2,7 s e 5,4 s; Triceratops provocado rompe a madeira em 2,2 s. **O curral de madeira não aguenta a domesticação inteira (40 a 105 s) mas cobre a intervenção (6,5 s: aviso mais nocaute).**
- **Pedra imune não é trivial em campo:** curral 3 x 3 = 36 Pedra = 54 kg (108% do Peso), 90 s de mineração, 72 s de construção. É proteção de base. **Limites mínimos (sem mudar a regra):** T3 (4 Saber, Tijolo), 3 a 4 Pedra por peça, construção de 6 s (madeira 3 s, palha 1,5 s) e Peso.
- **Reparo:** a peça regenera ao máximo em 60 s depois de 10 s sem dano; **destruída, some** e reconstruir paga o custo.
- **0.2: só madeira**, nenhuma receita nova. Palha e pedra no M4.
- **`SORA`:** `StructureDef` (`material`, `hp_max`, `attackable`), entidade com `hp` salvo só se abaixo do máximo, regeneração com atraso de 10 s, pedido de dano no servidor, `ConductaDef` com `ataca_estrutura` (sempre, provocado, nunca) e `fator_dano_estrutural`, remoção da peça e atualização do caminho, testes das tabelas. **`YATORA`:** peças de palha e madeira com 3 estágios de dano, pedra sem estágio, lascas e poeira, sons de impacto por material, sprite de palha e do nó de palha.
- **Marco e custo [premissa]:** M2, 11 h (recorte 6 h).

## 7. Relação com tiers, pergaminhos e receitas achadas

- **Tiers (GDD 9):** o tier continua sendo o **gate de ingrediente** (o que dá para obter em cada bioma); o **Saber** é o gate de **permissão** (o que o personagem sabe fazer). Duas travas independentes, ambas visíveis na tela de receitas. O texto "desbloqueio por ter feito, sem árvore de pontos" **é substituído** por esta regra.
- **Receitas achadas (proposta 8, adiada, M4):** no M4 o **pergaminho** é um item único que ensina a receita **sem gastar Saber**; a Ração S e a S+ só nascem assim (ruínas na Pedreira, gruta na Mata-baixa). Se a proposta 8 não vier, S e S+ viram nós de 4 e 6 Saber. Pergaminho também pode ensinar T3 e T4 raros.

## 8. Co-op e save

- **Receita é por personagem.** Quem sabe a Ração A cozinha para o grupo: papel de cozinheiro, ferreiro, construtor.
- `aprender_receita(recipe_id)`: pedido validado no servidor (receita existe, não conhecida, pré-requisito aprendido, Saber suficiente); o servidor debita e responde. `craftar(recipe_id)` também é validado (conhecida, ingredientes, bancada a 2 tiles). Peça já colocada no mundo **qualquer jogador usa**; **colocar** exige conhecer a receita.
- **Save do jogador:** `saber_livre` e a lista `receitas_conhecidas` (ids; cerca de 6 a 25). Bump de versão. O Saber gasto não precisa ser guardado: deriva do conjunto.

## 9. Marco, custo e listas

**Custo [estimativa minha, premissa; `SHIKAMARU` confirma]:** ganho de Saber no nível 0,5 h; dados das 19 receitas 1,5 h; aprender (pedido, validação, save) 2,5 h; bloqueio na bancada (lista filtrada e `craftar` validado) 1,5 h; tela de receitas 5 h = **11 h**, dos quais cerca de **9 h além do PRO-04**. **Menor recorte:** sem pré-requisito nem linhas (lista plana por categoria) = 7 h. **M2, Essencial** (sem ela as receitas da 0.2 não têm gate).

**Para o `SORA`:**
1. `RecipeDef`: `id`, `nome`, `categoria` (armas, armaduras, mobilias, construcoes, recursos), `tier`, `custo_saber`, `prereq[]`, `conhecida_inicial`, `estacao`, `ingredientes{}`, `saida{item, qtd}`, `tempo_craft`, `marco`.
2. Componente do personagem: `saber_livre`, `receitas_conhecidas`; ganho no subir de nível (1, mais 1 nos níveis 5, 10, 15, 20).
3. Tela de receitas: cinco abas, estados (conhecida, aprendível, bloqueada por pré-requisito, sem Saber), mostra ingredientes e custo, botão aprender (pedido ao servidor).
4. Bancada: lista só as receitas conhecidas; as demais aparecem apagadas com "aprenda na tela de receitas".
5. Pedidos `aprender_receita` e `craftar` validados no servidor; **sem depender de apresentação**; save e teste headless (custos, pré-requisitos sem ciclo, ganho 23 em L20).
6. M4: slots de Traje e Escudo, `ArmorDef`, redução com teto de 50%, Peso equipado.

**Para o `YATORA`:** ícone do Saber (moeda); ícones de Machado, Picareta, Bastão reforçado, Bandagem, Baú, Cama, Cerca, Portão de dino, Cocho, Preparado (e depois Arco, flechas, Corda, Couro curtido, Tecido, Tijolo e 6 de armadura); sprites de estruturas (cerca, portão, cocho, baú, cama, bancada); cartões e linhas de pré-requisito da tela de receitas; sons de aprender e de fabricar.

## 10. Conflitos, decisões e o que falta provar

- **Conflitos:** o pilar "sem nível de personagem" (já registrado); o plano prevê tiers (PRO-10) e o crafting (PRO-04) sem Saber; GDD 9 dizia "sem árvore de pontos"; Cama pede conferir a regra de renascimento (seção 12).
- **Decisões do dono (recomendações):** Saber separado, 1 por nível mais 1 nos níveis 5, 10, 15 e 20; 19 receitas na 0.2 com 6 conhecidas; aprender tudo no teto na 0.2 e sem reinício; pergaminho ensina sem Saber; armadura no M4 (2 slots, sem durabilidade, soma 50%); no máximo 3 mobílias só visuais.
- **Calculado:** custos, ritmo de Saber, ordem, a conta da armadura. **Precisa jogar:** se 22 Saber em 4 h passa a sensação de escolha, se o curral de 24 Madeira é pesado, e se 100 kg de baú e 40 Madeira de abrigo equilibram o Peso.
