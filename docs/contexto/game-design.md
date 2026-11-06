# Game design e originalidade

**Leia quando:** for implementar ou alterar regra de jogo, número de balanceamento, nome ou texto que o jogador vê, ou criar conteúdo novo (espécie, item, receita).

Fontes de verdade: `docs/design/GDD.md` (o jogo completo; o sumário por sistema está na seção 16), `docs/design/racao.md`, `docs/design/receitas.md`, `docs/design/catalogo.md`. Escopo e ordem de entrega: `docs/PLANEJAMENTO.md`. Os `*_sim.py` em `docs/design/` calculam os números citados; rode-os em vez de refazer a conta.

## Como usar o GDD

- Marcações `[proposta]`, `[premissa]` e "precisa jogar" são hipóteses, não decisão. Não as trate como regra fechada nem as altere sem a pessoa de game design ou o dono do projeto.
- Número de balanceamento nasce no GDD, vai para um `Resource` em `game/data/` e só então para o código (ver `arquitetura.md`).
- Divergência entre GDD, plano e código: implemente o que a tarefa pede, registre a diferença no relatório e não "corrija" o documento por conta própria.

## Originalidade (inegociável)

- **Conteúdo original.** Nomes, espécies, itens, textos e mecânicas são próprios. Não copie nome, texto, número, ícone ou estrutura de dados de outro jogo.
- **Termos, números e listas de outros jogos não entram** em código, textos, documentos nem commits. Vale para itens, criaturas, facções e sistemas; na dúvida, invente outro nome. Palavras comuns de dicionário são permitidas. Referência a jogos existentes fica na conversa, nunca em arquivo do repositório.
- **Única exceção:** a seção "Inspirações" do `README.md` da raiz. Não repita esses títulos em nenhum outro arquivo público.
- **Comida de domesticação:** a família se chama **Ração**, com qualidade por letra: **S+, S, A, B, C**, da melhor para a pior. Quantidade de níveis, receitas e efeitos seguem `docs/design/racao.md` e o GDD.
