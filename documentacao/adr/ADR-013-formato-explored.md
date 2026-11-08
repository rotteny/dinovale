# ADR-013: Formato `explored` da névoa de exploração por jogador

**Data**: 2026-11-07
**Status**: Proposto
**Decisores**: dono do projeto; proposta de `KURAMA` (tarefa 8 do M0, roadmap consolidado de 07/11)

## Contexto

O M2b traz minimapa e névoa persistente. Decidido em 07/11: minimapa sem dinos nem recursos; mapa geral a 1 px por 2x2 tiles; revelação num raio de 12 tiles, calculada pela autoridade. Hoje não existe névoa de jogo (a moldura visual de névoa da tela, `FogFrame`, foi removida em 08/11). A ilha tem 256x256 tiles (`lunata.json`, campo `size`) e o M9 pode trazer mundo maior em chunks (ADR-012, ainda não escrito). O formato precisa nascer agora para não pedir v6 quando o mundo crescer.

## Opções consideradas

1. **Bitmap único do mapa inteiro**: simples. Contra: amarrado ao tamanho do mapa; mundo maior muda o formato; grava área nunca vista.
2. **Lista de células reveladas**: esparsa. Contra: cresce sem limite (milhares de pares) e é cara de testar por pertinência.
3. **Blocos esparsos em coordenada global**: blocos fixos de tiles, cada um um bitmap de células; bloco nunca visto não existe. Contra: um nível a mais de indexação.

## Decisão (proposta)

Opção 3.

- **Dono do dado**: o jogador, por `player_id` aleatório (ADR-007): `players[].explored`. A autoridade revela a partir da posição autoritativa (do corpo controlado, ADR-008); o cliente nunca envia "explorei".
- **Formato**: `explored = {"v": 1, "cell": 2, "block": 64, "blocks": {"<bx>,<by>": "<base64>"}}`. Célula de 2x2 tiles (o mesmo pixel do mapa geral); bloco de 64x64 tiles, logo 32x32 células = 1.024 bits = 128 B por bloco. Bit `cy * 32 + cx` do bloco, byte em ordem crescente, bit menos significativo primeiro. Coordenadas globais de tile, independentes do chunk de dados: o chunk do M9 pode ter qualquer tamanho.
- **Tamanho** [conta]: a ilha de 256x256 tiles dá no máximo 16 blocos, 2 KB de bits (cerca de 2,7 KB em base64) com tudo explorado.
- **Revelação**: só quando o corpo muda de célula; marca as células cujo centro está a até 12 tiles (raio em dado). Bloco inválido na carga (base64 ruim, tamanho errado) é descartado sozinho, sem derrubar o save (`SafeRead`).
- **Rede**: cada cliente recebe só a própria máscara, em diff por bloco; a máscara de outro jogador é informação privada.
- **Save**: campo opcional e aditivo ao v5; `v` permite trocar célula ou bloco no futuro por migração local do campo.

## Consequências

- **Positivas**: formato estável de 256x256 a mundo grande sem v6; custo de revelação só na troca de célula; teste puro (posição dentro, máscara fora).
- **Negativas / trade-offs**: resolução de 2x2 tiles (borda da névoa em degraus de 32 px); marcadores do jogador ficam para outra decisão.
- **Revisitar se**: o mapa geral mudar de escala; o bench de mundo grande (M9) mostrar memória ou rede acima do gatilho.
