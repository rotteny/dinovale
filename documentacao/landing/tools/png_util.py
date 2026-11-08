"""Leitura e escrita mínima de PNG RGBA 8 bits (sem Pillow), para as ferramentas da landing."""
import struct
import zlib


def ler(caminho):
    """Devolve (largura, altura, linhas) com cada pixel como tupla (r, g, b, a)."""
    d = open(caminho, "rb").read()
    pos, idat, larg, alt = 8, b"", 0, 0
    while pos < len(d):
        n, tipo = struct.unpack(">I4s", d[pos:pos + 8])
        corpo = d[pos + 8:pos + 8 + n]
        if tipo == b"IHDR":
            larg, alt, prof, cor, _, _, ent = struct.unpack(">IIBBBBB", corpo)
            assert (prof, cor, ent) == (8, 6, 0), "so RGBA 8 bits sem entrelacamento"
        elif tipo == b"IDAT":
            idat += corpo
        pos += 12 + n
    raw, bpl, linhas, ant = zlib.decompress(idat), larg * 4, [], bytearray(larg * 4)
    for y in range(alt):
        f = raw[y * (bpl + 1)]
        atual = bytearray(raw[y * (bpl + 1) + 1:(y + 1) * (bpl + 1)])
        for i in range(bpl):
            a = atual[i - 4] if i >= 4 else 0
            b = ant[i]
            c = ant[i - 4] if i >= 4 else 0
            if f == 1: atual[i] = (atual[i] + a) & 255
            elif f == 2: atual[i] = (atual[i] + b) & 255
            elif f == 3: atual[i] = (atual[i] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                atual[i] = (atual[i] + pr) & 255
        linhas.append([tuple(atual[x * 4:x * 4 + 4]) for x in range(larg)])
        ant = atual
    return larg, alt, linhas


def gravar(caminho, linhas):
    alt, larg = len(linhas), len(linhas[0])
    raw = b"".join(b"\x00" + bytes(v for px in l for v in px) for l in linhas)
    def chunk(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c) & 0xFFFFFFFF)
    open(caminho, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", larg, alt, 8, 6, 0, 0, 0))
                              + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
