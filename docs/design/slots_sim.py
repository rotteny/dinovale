#!/usr/bin/env python3
"""Slots do inventario e Mochila (Dino Vale, GDD 5.21). Biblioteca padrao. Uso: python3 slots_sim.py demanda
Tudo [premissa]: pilha de 20 para empilhaveis (a fruta ja e 20 no GDD 5.5), equipamento ocupa 1 slot cada, equipado nas vagas nao ocupa slot."""
import math
PILHA = 20
# cenarios: lista de (item, quantidade, empilhavel)
CEN = {
 "M1 inicio (4 ferramentas, coleta curta)": [("Lanca",1,0),("Machado",1,0),("Picareta",1,0),("Bastao",1,0),("madeira",30,1),("pedra",15,1),("fibra",10,1),("graveto",6,1),("baga",10,1)],
 "v0.2 meio (carne, 3 Racoes, fruta, preparado)": [("Lanca",1,0),("Machado",1,0),("Picareta",1,0),("Bastao",1,0),("Pilao",1,0),("madeira",40,1),("pedra",20,1),("fibra",15,1),("graveto",6,1),("baga",15,1),("carne",8,1),("carne (2a pilha, validade)",4,1),("carne podre",3,1),("Racao C",8,1),("Racao B",5,1),("Racao A",3,1),("fruta-do-sono",9,1),("preparado",3,1),("Bandagem",3,1),("couro",6,1)],
 "v0.2 pico (abrigo + curral + domar, tudo junto)": [("Lanca",1,0),("Machado",1,0),("Picareta",1,0),("Bastao",1,0),("Pilao",1,0),("madeira",60,1),("pedra",30,1),("fibra",25,1),("graveto",6,1),("baga",15,1),("carne",12,1),("carne (2a pilha)",6,1),("carne podre",4,1),("Racao C",12,1),("Racao B",8,1),("Racao A",6,1),("fruta-do-sono",12,1),("preparado",6,1),("Bandagem",4,1),("couro",10,1),("Sal-de-veio",4,1),("Tuberculo",6,1)],
 "1.0 (Arco, 2 flechas, Espada, metal, pecas na mochila)": [("Lanca",1,0),("Machado ferro",1,0),("Picareta ferro",1,0),("Bastao",1,0),("Arco",1,0),("Espada",1,0),("Pilao",1,0),("flecha",20,1),("flecha de sono",12,1),("madeira",60,1),("pedra",30,1),("fibra",25,1),("barra",10,1),("carvao",5,1),("minerio",20,1),("carne",12,1),("carne (2a pilha)",6,1),("Racao C",12,1),("Racao B",8,1),("Racao A",6,1),("fruta-do-sono",12,1),("preparado",6,1),("Bandagem",4,1),("couro",10,1),("corda",5,1),("peca reserva 1",1,0),("peca reserva 2",1,0)],
}
def demanda():
    for n, itens in CEN.items():
        slots = sum(math.ceil(q / PILHA) if emp else q for _, q, emp in itens)
        print(f"  {n:58} {slots:2} slots")
    print("Base 24 (provisorio): cobre o M1 e o meio da v0.2 (21), aperta no pico (26) e na 1.0 (31); 40 (24 + mochila 16) cobre tudo e e a grade que ja existe. O Peso (50 kg) segue limitando a massa: os cenarios somam mais madeira do que o jogador carrega, entao a demanda real de slots e menor que a mostrada.")
{"demanda": demanda}[__import__("sys").argv[1]]()
