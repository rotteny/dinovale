# Política de segurança

O Dino Vale está em **pré-alpha**: não há versão estável nem build público.
Mesmo assim, levamos a sério falhas de segurança, principalmente em
sincronização de rede (co-op), arquivos de save e scripts de build/CI.

## Como reportar

**Não abra issue pública** para vulnerabilidades.

Use o relato privado do GitHub: aba **Security** do repositório
`rotteny/dinovale`, botão **Report a vulnerability** (GitHub Security
Advisories). Só os mantenedores veem o relato.

Inclua, se possível:

- o que é afetado (arquivo, sistema ou fluxo) e a versão/commit;
- passos para reproduzir;
- o impacto que você enxerga.

## O que esperar

Este é um projeto mantido por poucas pessoas, sem SLA formal. Tentamos
confirmar o recebimento em alguns dias e avisar quando houver correção.
Pedimos que a divulgação pública espere a correção estar disponível.

## Escopo

Dentro: código do jogo (`game/`), scripts (`tools/`), workflows
(`.github/`) e a página (`docs/`).

Fora: vulnerabilidades do próprio Godot Engine (reporte ao projeto
[Godot](https://github.com/godotengine/godot/security)) e de serviços de
terceiros.

## Segredos

Nunca versionamos segredos. Se você encontrar uma credencial no histórico do
repositório, reporte pelo mesmo canal privado.
