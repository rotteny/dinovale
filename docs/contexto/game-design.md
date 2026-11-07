# Game design e originalidade

**Leia quando:** for implementar ou alterar regra de jogo, número de balanceamento, nome ou texto que o jogador vê, ou criar conteúdo novo (espécie, item, receita).

Fontes de verdade: `docs/design/GDD.md` (o jogo completo; o sumário por sistema está na seção 16), `docs/design/racao.md`, `docs/design/receitas.md`, `docs/design/catalogo.md`. Escopo e ordem de entrega: `docs/PLANEJAMENTO.md`. Os `*_sim.py` em `docs/design/` calculam os números citados; rode-os em vez de refazer a conta.

## Estado do desenho (07/11)

- **Fonte única das decisões de 06/11 e 07/11:** `docs/design/corte-v02/decisoes-0611-0711.md` (DECIDIDO é palavra do dono; PROVISÓRIO é recomendação aplicada até o dono responder e pode mudar). Propostas detalhadas: `shiro.md` e `shikamaru.md` na mesma pasta. Onde o GDD ainda traz texto antigo que as contradiz, vale o arquivo de decisões.
- **Implementado até a E1:** ilha Lunata, coleta, Soco, carcaça, doma do Paquicéfalo, placa do domado, nível do selvagem visível, cursor, `ServerRules` (ADR-004) e Utahraptor com perseguição. O resto do corte da v0.2 (4 espécies, 17 receitas, etapas E0 a E23) é provisório.
- **Regras decididas:** sobrevivência direta com poucas regras; dia e noite e chuva, neve só em bioma de gelo, sem estações e sem sanidade; fome leve (sem dano, o torpor é a ameaça e o jogador caído pode ser devorado); 4 slots e uma vaga de bolsa (+4 ou +8, não somam) com o Peso mantido; dino sem sela com 4 slots (selas de carga e de trabalho só depois do MVP; a 6.13 do GDD será reescrita); domado Neutro ajuda no combate; montar em porte Médio ou maior, sem sela; ficha de RPG; renascer em local aleatório (provisório: sorteio na ilha inteira, em terra caminhável, com distância de segurança de dinos Agressivo e Semi; as regiões viram reserva) ou numa Cama ou Saco da lista, com nome editável pelo botão direito. Texto antigo no GDD está sob "Histórico (superado em 07/11)": não implemente.
- **Em aberto:** teto de evolução do domado (A, B ou C, GDD 5.16) e a divergência de teto 75 x 50 em `dino_level_rules.tres`.
- **Chaves de servidor:** formato `server_rules.json` (ADR-004); `dano_fome` está obsoleta.

## Como usar o GDD

- Marcações `[proposta]`, `[premissa]` e "precisa jogar" são hipóteses, não decisão. Não as trate como regra fechada nem as altere sem a pessoa de game design ou o dono do projeto.
- Número de balanceamento nasce no GDD, vai para um `Resource` em `game/data/` e só então para o código (ver `arquitetura.md`).
- Divergência entre GDD, plano e código: implemente o que a tarefa pede, registre a diferença no relatório e não "corrija" o documento por conta própria.

## Originalidade (inegociável)

- **Conteúdo original.** Nomes, espécies, itens, textos e mecânicas são próprios. Não copie nome, texto, número, ícone ou estrutura de dados de outro jogo.
- **Termos, números e listas de outros jogos não entram** em código, textos, documentos nem commits. Vale para itens, criaturas, facções e sistemas; na dúvida, invente outro nome. Palavras comuns de dicionário são permitidas. Referência a jogos existentes fica na conversa, nunca em arquivo do repositório.
- **Única exceção:** a seção "Inspirações" do `README.md` da raiz. Não repita esses títulos em nenhum outro arquivo público.
- **Comida de domesticação:** a família se chama **Ração**, com qualidade por letra: **S+, S, A, B, C**, da melhor para a pior. Quantidade de níveis, receitas e efeitos seguem `docs/design/racao.md` e o GDD.
