# Catálogo de candidatos: fauna e recursos

Rascunho para decisão do dono. Nada aqui entra no jogo sem escolha explícita. Regras do catálogo:

- Só animais que existiram de verdade. Sem monstros, robôs, seres míticos, nem bichos inventados.
- No jogo, a espécie usa o nome real. Se ele for extenso demais, usa um apelido próximo do nome real.
- O MVP usa uma lista reduzida; o resto do catálogo fica para depois.
- Comportamento, aparência e habilidades vêm do nosso design e da paleontologia, nunca de outro jogo.
- Recursos usam nomes comuns da língua. Item com nome inventado fica de fora.

## Elenco do MVP

**v0.2 (5 espécies):** Utahraptor e Paquicéfalo (M1); **Dodo no início do M2** (decisão do dono, 06/11); Triceratops (L18 a L24, também na 1.0) e Parassaurolofo (M2). **M4:** **Listro** e Oviraptor. **Todo dino é domável (GDD 4.1):** Dodo (Covarde de grupo, torpor 50, baga, fator 0,7) e Listro (torpor 48, fator 0,8) têm perfil de doma e ofício leve (GDD 6.1b), além de presa da Lança. Gallimimus fora.

**Faixa de nível ao nascer (v0.2, GDD 5.16; poucos altos, teto ao nascer 30):** Dodo 3 a 10; Paquicéfalo 5 a 20 (tutorial 5 a 8); Utahraptor 10 a 25; Parassaurolofo 10 a 30; Triceratops 18 a 24 (1.0: 18 a 40). Teto de evolução depois de domado: 2x o nível de doma, e o teto do servidor vence.

## Fauna

### Dinossauros herbívoros e onívoros

- **Blindados e com chifres:** Triceratops, Stegosaurus, Kentrosaurus, Ankylosaurus, Pachyrhinosaurus
- **Bípedes e de porte médio:** Iguanodon, Parasaurolophus, Pachycephalosaurus, Gallimimus, Therizinosaurus, Oviraptor, Gigantoraptor
- **Pescoçudos gigantes:** Diplodocus, Brontosaurus, Amargasaurus, Dreadnoughtus

### Dinossauros carnívoros

- **Grandes:** Tyrannosaurus, Giganotosaurus, Carcharodontosaurus, Acrocanthosaurus, Spinosaurus, Yutyrannus
- **Médios:** Allosaurus, Carnotaurus, Ceratosaurus, Baryonyx, Megalosaurus, Megaraptor, Concavenator, Cryolophosaurus, Dilophosaurus
- **Pequenos e em bando:** Utahraptor, Deinonychus, Troodon, Compsognathus, Microraptor

### Outros répteis e anfíbios terrestres

Dimetrodon, Moschops, Lystrosaurus (**Listro, M4**), **Dodo (ave que não voa, início do M2)**, Megalania, Titanoboa, Kaprosuchus, Sarcosuchus, Deinosuchus, Beelzebufo, Diplocaulus, Carbonemys

### Mamíferos pré-históricos

Mamute, rinoceronte-lanudo, tigre-dentes-de-sabre, lobo-terrível, urso-de-cara-curta, preguiça-gigante (Megatherium), Doedicurus, Chalicotherium, Deinotherium, Paraceratherium, Phiomia, Daeodon, Andrewsarchus, Hyaenodon, Thylacoleo, Procoptodon, Castoroides, Megaloceros, Gigantopithecus

### Aves e répteis voadores (bloqueados até haver mecânica de voo definida)

ave-do-terror, Argentavis, Pelagornis, Archaeopteryx, Pteranodon, Quetzalcoatlus, Tapejara, Dimorphodon, Tropeognathus

### Vida aquática (bloqueada até haver mecânica de água definida)

Megalodonte, Mosasaurus, Plesiosaurus, Liopleurodon, Ichthyosaurus, Dunkleosteus, Basilosaurus, Archelon, Trilobita, amonite, celacanto, Leedsichthys

### Artrópodes gigantes reais (só em cavernas, depois do MVP)

**Fora da regra "todo dino é domável" até o dono responder (GDD V77):** não são dino; hoje são fauna-recurso (carcaça com quitina, sem perfil de doma).

Arthropleura, Meganeura, Pulmonoscorpius, Titanomyrma

### Espécies brasileiras (depois do MVP)

Irritator, Oxalaia, Staurikosaurus, Tupandactylus. Tapejara, já listado entre os voadores, também é brasileiro.

## Recursos

- **Básicos:** madeira, pedra, fibra, palha (da árvore), sílex (da pedra), areia, argila
- **Plantas:** seiva, cogumelos, algas, flores, frutas, sementes
- **Minerais:** carvão, ferro, cobre, cristal, obsidiana, sal, enxofre, ouro, gemas, petróleo
- **Animais:** couro, pele, lã, penas, ossos, escamas, quitina, queratina, conchas, seda, mel, ovos, carne
- **Refinados:** barra de metal, aço, cal, argamassa, corda, tecido, vidro, tijolo
- **Na ilha do MVP (`mapa-ilha.md` 8):** só pedra, sal e, no M4, ferro (nó "Filão de ferro"); cobre, cristal, obsidiana e o resto seguem só como candidatos. Nomes de recurso e de fruta são palavras comuns da língua (Baga; Cochilo: Cochilo, Modorra ou Dormideira).
- **Sem marco (decisão do dono, 06/11):** fósforo, pólvora, Rifle, Dardo e qualquer arma de fogo. **Sílex voltou (M4):** sai da pedra comum e da pedra de minério e vira ponta de flecha. **Fontes (GDD 5.9c):** palha da árvore, junto com a madeira (M4); metal só do minério de ferro (M4); quitina só de insetos gigantes, junto com a carne (cavernas, pós-1.0). O enxofre fica só como catálogo, sem uso previsto.

## Pilha e Peso por item (decisão do dono, 06/11; GDD 5.9d)

Cada item tem a sua pilha (`max_stack` em `ItemDef`, só dado). v0.2: Baga 20, Samambaia 30, Carne e carne podre 10, Madeira 20, Pedra 20, Fibra 40 (os seis do código), Couro 20, Cochilo 20, Preparado 20, Ração 20, Tubérculo 20, Sal-de-veio 20, Graveto 40; ferramentas, armas e armadura 1 (individuais). Peso em kg: Madeira 1,0, Pedra 1,5, Carne 0,5, Couro 0,4, Baga e Samambaia 0,1, Fibra 0,05. M4: Palha 40 (0,1 kg), Sílex 30 (0,3), Quitina 20 (0,3), Minério de ferro 10 (2,0), Barra de ferro 10 (1,5), Carvão 20 (0,2), Flecha comum 40, Flecha de sono 20. Regra: alvo de 20 a 30 kg por pilha de material bruto, 2 a 6 kg do leve e 5 kg do que vence.
