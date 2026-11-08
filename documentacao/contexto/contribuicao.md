# Contribuição: escopo, pronto, papéis e revisão

**Leia quando:** for começar uma tarefa, abrir PR, delegar trabalho a outra IA ou pessoa, ou declarar algo pronto.

## Definição de pronto

Uma tarefa só está pronta quando:

1. `tools/check.sh` passa, sem erro novo nem aviso novo de import.
2. Há testes para a lógica nova (e para o bug, se for correção), e eles falham sem a mudança.
3. A tipagem está completa nos arquivos tocados.
4. Os critérios de aceite do briefing estão cumpridos, um a um.
5. Assets novos estão registrados em `game/assets/CREDITS.md`.
6. A doc afetada (`README`, `documentacao/`) foi atualizada, se o comportamento visível mudou.
7. Houve **revisão independente antes do merge**, quando a tarefa mexe em lógica compartilhada, save ou rede (quem revisa não é quem implementou).
8. O jogo foi rodado, quando a mudança é visível (ver `testes-e-validacao.md`).

## Fluxo da v0.2: etapas pequenas

A ordem de execução da v0.2 é a lista de etapas de `documentacao/design/corte-v02/shikamaru.md` (decisões em `decisoes-0611-0711.md`). Cada etapa é **uma entrega jogável** com no máximo 2 tarefas de código: a implementação é revisada por QA **por etapa**, depois fecha com **um commit local** (sem push), e o dono joga antes de a próxima começar. Etapa sem revisão de QA não é base para a seguinte.

## Limite de escopo por tarefa

- Uma tarefa, um objetivo. Mexa só nos arquivos que o briefing lista. Precisou de outro? Pare e peça.
- Sem refatoração oportunista, sem renomear, sem formatar arquivo que não é seu.
- Não apague nem sobrescreva trabalho de outra pessoa ou IA. Trabalhe em branch ou worktree próprio.
- Sem dependência nova, sem mudar `project.godot`, licença ou CI sem pedido explícito.
- Não faça commit nem push sem pedido. Commits feitos com IA registram a ferramenta usada.
- Achou algo fora do escopo? Registre no relatório final; não corrija.

## Papéis (por função)

Uma pessoa pode acumular vários; uma IA recebe um por tarefa.

| Papel | Responsabilidade |
|---|---|
| Implementação em Godot | Gameplay, cenas, componentes, save, rede (`game/`) |
| Game design | Loop, balanceamento, progressão, o vínculo com o dino; mantém o GDD |
| Arte e som | Guia de arte, sprites, tilesets, SFX; segue `arte-e-licencas.md` |
| Landing | Só `docs/`. Não toca na UI do jogo |
| Testes e revisão independente | Testes, testes de arquitetura, revisão de código antes do merge |
| Arquitetura | ADRs: autoridade, formato de save, ids e registries, regras do servidor |
| Infraestrutura | CI, scripts de build, releases |
| Segurança | Gate de segurança de rede (a partir do co-op) |

## Repositório público

Nada de e-mail, caminho local de máquina, credencial, token, dado pessoal, nome de ferramenta interna ou conversa interna em arquivo, commit, PR ou issue. Se precisar citar uma ferramenta, cite apenas as que já estão registradas no repositório (por exemplo, no `CREDITS.md`).
