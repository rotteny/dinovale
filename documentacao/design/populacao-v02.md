# População da v0.2 por porte (proposta, 08/11)

> **Proposta aprovada pelo dono em 08/11, com as 9 recomendações.**

Base: decisões do dono de 08/11 em `corte-v02/decisoes-0611-0711.md` ("Rex e Triceratops" e "População por porte"), GDD 4.2 (3 portes), `mapa-ilha.md` 5, `corte-v02/bandos-e-dano-em-area.md` (espaçamentos), `corte-v02/m1-ameaca-e-corpo.md` seção 10 (predação) e `game/data/world/lunata.json`. Marcas: [decidido] é do dono, [calculado] saiu de script, [premissa] é número meu a validar, [jogar] só o playtest responde.

## 1. Regra do dono, em frases testáveis

1. Total de indivíduos: Pequeno > Médio > Grande.
2. No mesmo porte, o carnívoro tem menos indivíduos que o herbívoro.
3. Rex: 1 a 2 por ponto, poucos pontos (raro). Triceratops: 1 a 3 por ponto, muitos pontos (abundante). Os dois são Grandes.
4. Utahraptor: 6 tocas x 2 = 12 [decidido].

## 2. Aviso: o mapa-ilha prometia 360 dinos e a geometria não deixa

O `mapa-ilha.md` 5 fala em 360 dinos (Dodo 140, Paquicéfalo 108, Parassaurolofo 94). Com os espaçamentos de bando da `bandos-e-dano-em-area.md` isso não cabe: [calculado, preenchimento aleatório em `lunata.json`, melhor de 40 sorteios] a Campina comporta no máximo 22 bandos de Dodo a 20 tiles e a Mata-baixa 14 manadas a 24 tiles, já descontando as 6 tocas. O que o mapa gravado tem hoje: Dodo 8 bandos (~24), Paquicéfalo 20 focos (~70), Utahraptor 6 tocas, Triceratops 4 pontos, Parassaurolofo nenhum. A proposta abaixo parte dos números que cabem, não dos 360. Os percentuais do mapa-ilha (39/30/29/2) ficam como histórico.

## 3. Proposta

| Espécie | Porte | Pontos (bandos) | Por ponto | Indivíduos (média) | Região |
|---|---|---|---|---|---|
| Dodo | Pequeno | 8 (hoje) | 2 a 4 | ~24 | Campina |
| Paquicéfalo | Pequeno | 20 (hoje) | 3 a 4 | ~70 | Campina e Mata-baixa |
| **Pequeno total** | | | | **~94** | |
| Parassaurolofo | Médio | **8** manadas | 3 a 5 | ~32 | Mata-baixa, >= 24 tiles entre si |
| Utahraptor | Médio | 6 tocas [decidido] | 2 (U1 a U6) | 12 | Mata-baixa (tocas de `lunata.json`) |
| **Médio total** | | | | **~44** | |
| **Triceratops** | Grande | **10** | **1 a 3** (sorteio uniforme) | **~20** | Pedreira inteira |
| **Rex** | Grande | **2** | **1 a 2** | **~3** | Pedreira, só a parte >= 30 tiles da Mata-baixa |
| **Grande total** | | | | **~23** | |

Ordem [calculado]: Pequeno 94 > Médio 44 > Grande 23 (58%, 27%, 14% de ~161). Mesmo porte: Utahraptor 12 < Parassaurolofo 32, e rex 3 < Triceratops 20 (razão 1 para 6,7; a do Utahraptor é 1 para 2,7). Sem o ajuste do Paquicéfalo para Pequeno (decisão 1 da seção 7) a regra 1 quebra: o Médio passaria a 114 contra 24 do Pequeno.

**Por que 8 manadas de Parassaurolofo e não 20.** A Mata-baixa comporta 14 a 24 tiles e divide o espaço com os focos de Paquicéfalo e as 6 tocas. 8 manadas x 4 = 32 deixa folga e continua acima dos 23 do Grande. Se o dono quiser mais, o caminho é baixar o espaçamento da manada (24 para 20), não encher a mata.

**Triceratops: de 4 pontos para 10, e o espaçamento sai de 30 para 20.** Com 30 tiles a Pedreira comporta no máximo 8 pontos [calculado; os 8 do `mapa-ilha.md` já estavam no limite e dois deles estão a 15 tiles um do outro, abaixo do próprio 16]. Com 20 tiles comportam 14. Simulei 10 Triceratops (espaço 20 entre si) mais 2 rex (40 entre si, 16 de qualquer bando): fecha em 94% dos sorteios de semente [calculado, 300 sorteios]; nos 6% restantes o exportador tenta outra semente. O ponto de Triceratops deixa de ter coordenada fixa; o exportador sorteia com a semente do mundo. Tabela de dados: `group_count` 10, `group_size_min` 1, `group_size_max` 3, espaçamento 20 [premissa].

**Rex: 2 pontos.** Região: Pedreira, faixa de x >= 112 (>= 30 tiles de qualquer tile de Mata-baixa), por isso nunca encosta em Parassaurolofo, Dodo nem Paquicéfalo. Um ponto na faixa centro-norte (x 112 a 160, 708 tiles candidatos; fica a ~17 tiles do Cabo-Salgado, o sal tem guarda) e outro na faixa leste (x >= 170, 323 candidatos). Sorteio deterministico com a semente. Espaçamento rex-rex 40. A ordem de perigo do mapa (Campina, Mata-baixa, Pedreira) fica coerente: o maior carnívoro mora no fim da jornada.

## 4. Conta da predação: o rex não esvazia os Triceratops

Regras usadas [decidido ou lido]: `herd_floor_alive` = 2 (bando com 2 ou menos vivos não é presa), reposição de 1 membro a cada 600 s só com jogador a mais de 40 tiles, caça só dentro do raio ativo de 16 tiles do jogador, saciedade 60 s por carne (teto 600 s), `EAT` 2 s por carne (teto 20 s), D8 presa de porte igual ou menor.

1. **O rex só alcança Grande, Médio e Pequeno herbívoro** (D8). Os Pequenos e Médios estão a >= 30 tiles dele pela geometria acima, então a única presa real é o Triceratops (Grande é "igual"). Utahraptor e outro rex não são presa (carnívoro não caça carnívoro).
2. **Solitário e par nunca são presa.** O piso de 2 protege ponto com 1 ou 2 vivos: com sorteio uniforme de 1 a 3, 2 em cada 3 pontos são imunes. Só o ponto de 3 é elegível, e cai no máximo a 2.
3. **Caçar e repor são excludentes.** Caçar exige o jogador a <= 16 tiles; repor exige o jogador a > 40. Os dois não acontecem ao mesmo tempo, então não há "o rex mata mais rápido que a reposição" dentro de uma mesma visita.
4. **Pior caso (todo ponto a <= 24 tiles de um rex considerado exposto, jogador sempre perto, sem reposição)** [calculado, 1.392 mapas sorteados]: 3,3 pontos expostos em média, população inicial de 20 Triceratops, **perda média 1,1, percentil 95 = 3, máximo 5** (5% em média, 25% no pior mapa). Nunca passa de 1 por ponto.
5. **Ritmo do rex.** Carne do Triceratops L21 ~ 20 [premissa; o GDD dá carniça 6 no L28, ceil(carne/4)]: saciedade min(60 x 20, 600) = 600 s, refeição 20 s. Um rex mata no máximo 1 a cada ~620 s (+ até 40 s de caça): ~5,6 por hora, 2 rex ~11 por hora. O limite vem do piso, não do apetite: depois do primeiro abate de cada ponto de 3 não há mais presa elegível.
6. **Jogador longe = o mundo não caça.** A caçada não fixa o dino como ativo; passada a visita, cada vaga volta em 600 s. Quem quiser "cultivar" a perda precisa ir e voltar mais de 40 tiles a cada 10 min.
7. **Cuidado, não esvazia mas incomoda:** o ponto de 3 próximo de um rex vive em 2 a 3 de 3 [calculado, mesmo custo do M1 10.5].

[jogar] quanto de risco o rex realmente cria para o jogador, e se ele caça antes de perceber o jogador (regra do dono: em combate com selvagem, ignora o jogador, o que pode ser um escape útil).

## 5. Nível do rex ao nascer

Referências lidas: Utahraptor 10 a 25, Triceratops 18 a 24, Parassaurolofo 10 a 30, teto de spawn 30 (`dino_nivel_spawn_max`), sorteio `nível = mín + floor((máx - mín + 1) x u^2)` (poucos altos).

**Proposta: 25 a 30 [premissa].** Média 26,6 e L30 em 6 a 7% dos casos [calculado: 25 + sum(1 - raiz(k/6)), k = 1 a 5 = 1,58]. Razões: (a) o piso 25 passa o máximo do Triceratops (24), então o rex nunca nasce mais fraco que a presa; (b) o teto 30 já é o teto de spawn do servidor, sem precisar mudar chave; (c) o mínimo 25 deixa o rex acima do Utahraptor típico (média ~14). Efeito de `dino_level_rules` (base 10): vida x1,64 em L26, torpor x1,32, refeições x1,24 [calculado]; Triceratops L21 fica em vida x1,44. Doma do rex fica cara (torpor e refeições altos): coerente com raro, e o domar do rex é conteúdo do M3 em diante.

Atenção: `DinoLevelRules` só escala vida, torpor, refeições e carcaça, não o dano. O rex precisa de `base_damage` próprio no `.tres`, acima do 8 do Utahraptor [premissa para o `SORA` e o dono; o ponto de partida que sugiro é uma mordida de ~24 a cada 2,5 s = 9,6 por s contra 4,7 do Utahraptor, o que derruba o jogador de 100 de vida em ~10 s de contato; [jogar]].

## 6. O que ainda precisa jogar

- Se 2 rex (~3 indivíduos) é "raro" de verdade ou se aparece demais em 1 a 2 visitas à Pedreira.
- Se o Triceratops com 1 a 3 por ponto e 10 pontos dá a sensação de "abundante" sem virar parede de dano em área.
- O ritmo do rex caçando Triceratops na frente do jogador (cena boa ou frustrante).
- Se 8 manadas de Parassaurolofo bastam para a Mata-baixa não parecer vazia.

## 7. Decisões que dependem do dono

| # | Decisão | Recomendação e motivo |
|---|---|---|
| 1 | **Paquicéfalo = Pequeno** (o código usa Médio por padrão; o GDD diz Pequeno). | Pequeno. Sem isso Pequeno (24) < Médio (114) e a regra do dono quebra. O `SORA` corrige o dado. |
| 2 | Pontos do rex: 2 ou 3. | 2 (~3 rex). Com 3 pontos são ~4,5 e a razão com o Triceratops cai de 1 para 6,7 a 1 para 4,4, perto demais do Utahraptor. |
| 3 | Triceratops 10 pontos, espaçamento 30 para 20. | Sim: é o que cabe na Pedreira. Alternativa é 8 pontos com espaçamento 30 (~16 indivíduos). |
| 4 | Parassaurolofo: 8 manadas em vez de 20. | 8 (a Mata comporta 14 no máximo e divide espaço). |
| 5 | Nível do rex 25 a 30. | 25 a 30, pelo piso acima do Triceratops e pelo teto de spawn que já é 30. |
| 6 | O rex caça o Triceratops selvagem (D8). | Manter, com piso 2. Dá "ecossistema vivo" e a conta mostra perda média de ~1 em 20. Alternativa: `prey_exclude_ids` com o Triceratops (zero risco, zero cena). |
| 7 | O Triceratops domado é presa do rex (D6 + D8, sem piso). | Manter e avisar no log; é o risco real de levar o domado à Pedreira. Só vale no M2 em diante (domado em combate). |
| 8 | Abandonar os 360 dinos do mapa-ilha e adotar ~161 (esta proposta). | Sim; o preenchimento dos 360 não cabe com os espaçamentos. O `mapa-ilha.md` 5 precisa ser atualizado depois (não mexi). |
| 9 | Portão duplo x folga de navegação do Grande (GDD 4.2). | O corpo passa em 2 tiles, o planejador exige 3 (folga 1). `SORA` e dono definem exceção para portão aberto antes do M3. |
