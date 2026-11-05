#!/usr/bin/env python3
"""Gera toda a arte pixel (SVG) da landing do Dino Vale, sem dependências.

Uso:  python3 tools/gen_art.py     (grava em ../assets, de forma determinística)

Tudo é desenhado por primitivas (elipses, folhas, grades de pixels) e sai como
SVG com `shape-rendering: crispEdges`. Nada de imagens externas.
"""
import math
import os
import random

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))

# ---------------------------------------------------------------- paleta
P = dict(
    ink="#2B1A12", line="#3A2418", e="#FFFFFF", tongue="#FF6F83", cheek="#FF8FA0",
    # criaturas
    lar="#FF9B3D", lar_s="#E07424", lar_h="#FFC27A", lar_b="#FFE7B0", plate="#FFD23F", plate_s="#E5A515",
    ver="#43C6A1", ver_s="#2A9E80", ver_h="#8BE6CB", ver_b="#D9F8EA", frill="#FF8FA3", frill2="#FFC1CB", horn="#FFF2CC",
    beb="#5FBDF2", beb_s="#3A93CC", beb_h="#A6DFFF", beb_b="#E3F5FF", shell="#FFFFFF", shell_s="#DCD6C2",
    # folhas
    j0="#0E4527", j1="#125A30", j2="#17703B", j3="#1F8A47", j4="#3BB54F",
    f_line="#0F4A2A", f_dark="#1D7A3C", f_mid="#2FA24B", f_light="#5CCB4F", f_vein="#17602F", f_hi="#9BE05A",
    # objetos
    h0="#5A3A22", h1="#8F5E36", h2="#B07A45", ro="#CC9438", rd="#9C6A22",
    c0="#6B4423", c1="#A87340", cm="#CFCFC4",
    r0="#4B514C", r1="#8E948E", r2="#B9BEB5",
    fi1="#E2531F", fi2="#F59B2B", fi3="#FFE27A",
    berry="#E5384F", berry_h="#FF8A98", bush="#2F9A45", bush_d="#1D6B30",
    heart="#FF4D6A", heart_h="#FFB3C1", heart_d="#8A1F2D",
    fy="#FFD23F", fc="#FF6F61", fw="#FFF8E1",
    g1="#58BC4A", g2="#4AAE44", gh="#8CD95B", gd="#2E8A3A",
)


class Canvas:
    def __init__(self, w, h, wrap_x=False, wrap_y=False):
        self.w, self.h, self.wx, self.wy = w, h, wrap_x, wrap_y
        self.px = {}

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if self.wx:
            x %= self.w
        if self.wy:
            y %= self.h
        if 0 <= x < self.w and 0 <= y < self.h and c:
            self.px[(x, y)] = P.get(c, c)

    def get(self, x, y):
        return self.px.get((x, y))

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c)

    def ellipse(self, cx, cy, rx, ry, c, shade=None, hi=None):
        for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
                px, py = (i + .5 - cx) / rx, (j + .5 - cy) / ry
                if px * px + py * py <= 1:
                    col = c
                    if shade and px + py > .72:
                        col = shade
                    elif hi and px + py < -1.0:
                        col = hi
                    self.set(i, j, col)

    def blit(self, other, ox, oy):
        for (x, y), c in other.px.items():
            self.set(ox + x, oy + y, c)

    def outline(self, col, times=1):
        col = P.get(col, col)
        for _ in range(times):
            add = {}
            for (x, y) in self.px:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (x + dx, y + dy)
                    if q not in self.px and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                        add[q] = col
            self.px.update(add)

    def mirrored(self):
        m = Canvas(self.w, self.h, self.wx, self.wy)
        m.px = {(self.w - 1 - x, y): c for (x, y), c in self.px.items()}
        return m

    def svg(self, label=None):
        by = {}
        for (x, y), c in self.px.items():
            by.setdefault(c, []).append((x, y))
        parts = []
        for c, pts in sorted(by.items()):
            rows = {}
            for x, y in pts:
                rows.setdefault(y, []).append(x)
            d = []
            for y, xs in sorted(rows.items()):
                xs.sort()
                s = prev = xs[0]
                for x in xs[1:] + [None]:
                    if x is not None and x == prev + 1:
                        prev = x
                        continue
                    d.append(f"M{s} {y}h{prev - s + 1}v1h-{prev - s + 1}z")
                    if x is not None:
                        s = prev = x
            parts.append(f'<path fill="{c}" d="{"".join(d)}"/>')
        aria = f'role="img" aria-label="{label}"' if label else 'aria-hidden="true"'
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" '
                f'shape-rendering="crispEdges" {aria}>{"".join(parts)}</svg>')

    def save(self, name, **kw):
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name), "w") as f:
            f.write(self.svg(**kw))


# ---------------------------------------------------------------- folhas
def leaf(c, bx, by, length, ang, hw, cols, notch=False):
    """Folha de selva: base em (bx,by), apontando para `ang` graus (0 = direita, 90 = baixo)."""
    dark, mid, light, vein = cols
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    r = int(length + hw + 2)
    for y in range(by - r, by + r + 1):
        for x in range(bx - r, bx + r + 1):
            dx, dy = x - bx, y - by
            u = dx * ux + dy * uy
            v = -dx * uy + dy * ux
            t = u / length
            if t < 0 or t > 1:
                continue
            w = hw * (math.sin(math.pi * t ** .75)) ** .85
            if abs(v) > w:
                continue
            if notch and abs(v) > max(1.6, w * .5) and int(u // 2.5) % 2 == 0:
                continue
            if abs(v) > w - 1.2:
                col = dark
            elif abs(v) < .8:
                col = vein
            elif int(u) % 5 == 0 and abs(v) > 1.6:
                col = vein
            elif v < 0:
                col = light
            else:
                col = mid
            c.set(x, y, col)


FOLHA_VIVA = ("f_line", "f_mid", "f_light", "f_vein")
FOLHA_MEDIA = ("j0", "f_dark", "f_mid", "f_vein")
FOLHA_FUNDO = ("j0", "j2", "j3", "j1")


def strip_lateral(w, h, seed, layers):
    """Faixa vertical de folhas saindo da borda esquerda; repete sem emenda em Y."""
    c = Canvas(w, h, wrap_y=True)
    rnd = random.Random(seed)
    for cols, n, lmin, lmax, hwmin, hwmax in layers:
        for _ in range(n):
            leaf(c, rnd.randint(-10, 4), rnd.randint(0, h - 1), rnd.randint(lmin, lmax),
                 rnd.randint(-55, 55), rnd.randint(hwmin, hwmax), cols, notch=rnd.random() < .35)
    return c


def copa(w, h, seed):
    """Folhas penduradas do topo; repete sem emenda em X."""
    c = Canvas(w, h, wrap_x=True)
    rnd = random.Random(seed)
    for cols, n, lmin, lmax in ((FOLHA_FUNDO, w // 9, 22, 36), (FOLHA_MEDIA, w // 12, 18, 30), (FOLHA_VIVA, w // 16, 14, 24)):
        for _ in range(n):
            leaf(c, rnd.randint(0, w - 1), rnd.randint(-8, 0), rnd.randint(lmin, lmax),
                 rnd.randint(50, 130), rnd.randint(5, 8), cols, notch=rnd.random() < .3)
    return c


def borda(w, h, seed, base="j0"):
    """Ponta de folhas apontando para cima, para o topo das seções escuras."""
    c = Canvas(w, h, wrap_x=True)
    rnd = random.Random(seed)
    for cols, n, lmin, lmax in ((FOLHA_FUNDO, w // 8, 9, 14), (FOLHA_MEDIA, w // 12, 7, 12)):
        for _ in range(n):
            leaf(c, rnd.randint(0, w - 1), h + rnd.randint(0, 3), rnd.randint(lmin, lmax),
                 rnd.randint(-125, -55), rnd.randint(3, 5), cols)
    c.rect(0, h - 3, w, 3, base)
    return c


def selva(w, h, seed):
    """Fundo escuro de selva que repete em X e Y."""
    c = Canvas(w, h, wrap_x=True, wrap_y=True)
    c.rect(0, 0, w, h, "j0")
    rnd = random.Random(seed)
    for cols, n in ((("j0", "j1", "j1", "j0"), 16), (("j0", "j1", "j2", "j1"), 12), (("j1", "j2", "j3", "j1"), 7)):
        for _ in range(n):
            leaf(c, rnd.randint(0, w - 1), rnd.randint(0, h - 1), rnd.randint(28, 50),
                 rnd.randint(0, 359), rnd.randint(8, 13), cols, notch=rnd.random() < .3)
    for _ in range(9):
        c.set(rnd.randint(0, w - 1), rnd.randint(0, h - 1), "#FFE36B")
    return c


# ---------------------------------------------------------------- criaturas
KINDS = ("lar", "ver", "beb")


def chibi(kind="lar", eyes="open", mouth="open", look=0):
    """Dinossauro de frente, 32x32. kind: lar (laranja), ver (verde com gola), beb (azul, recém-nascido)."""
    body, sh, hi, bel = P[kind], P[kind + "_s"], P[kind + "_h"], P[kind + "_b"]
    c = Canvas(32, 32)
    if kind == "ver":
        c.ellipse(16, 11.5, 14.8, 12, "frill")
        for x, y in ((4, 8), (3, 13), (28, 8), (29, 13), (7, 3), (25, 3), (16, 0), (11, 1), (21, 1)):
            c.set(x, y, "frill2")
    if kind == "lar":
        for x in (9, 16, 23):
            c.ellipse(x, 3.6, 2.7, 3.7, "plate", shade="plate_s")
    c.ellipse(27.5, 24.5, 4.6, 2.7, body, shade=sh)
    c.ellipse(16, 21.5, 9.6, 8.3, body, shade=sh)
    c.ellipse(16, 23.5, 6.1, 5.7, bel)
    c.ellipse(6.5, 21, 2.7, 2.1, body, shade=sh)
    c.ellipse(25.5, 21, 2.7, 2.1, body, shade=sh)
    c.ellipse(11, 28.6, 4.3, 2.2, sh)
    c.ellipse(21, 28.6, 4.3, 2.2, sh)
    if kind == "ver":
        c.ellipse(8, 4.5, 1.9, 3.5, "horn")
        c.ellipse(24, 4.5, 1.9, 3.5, "horn")
    c.ellipse(16, 12.5, 11.6, 9.9, body, shade=sh, hi=hi)
    if kind == "ver":
        c.ellipse(16, 16.6, 2.4, 1.6, "horn")
    if kind == "beb":
        for x in range(5, 28):
            zig = 6 + (1 if (x // 2) % 2 == 0 else 0)
            for y in range(0, zig + 1):
                if ((x - 16) / 11.4) ** 2 + ((y - 5) / 6.0) ** 2 <= 1:
                    c.set(x, y, "shell_s" if y == zig else "shell")
    c.ellipse(7, 15.5, 2.3, 1.6, "cheek")
    c.ellipse(25, 15.5, 2.3, 1.6, "cheek")
    for ex in (11, 21):
        if eyes == "open":
            c.ellipse(ex, 11.8, 3.2, 3.8, "e")
            c.ellipse(ex + look * .8, 12.6, 1.8, 2.4, "ink")
            c.set(ex + look * .8 - 1, 11, "e")
        elif eyes == "happy":
            for dx, dy in ((-2, 13), (-1, 12), (0, 12), (1, 12), (2, 13)):
                c.set(ex + dx, dy, "ink")
        elif eyes == "sleep":
            for dx, dy in ((-2, 12), (-1, 13), (0, 13), (1, 13), (2, 12)):
                c.set(ex + dx, dy, "ink")
        elif eyes == "closed":
            c.rect(ex - 2, 12, 5, 2, "ink")
    c.set(15, 14, "ink")
    c.set(17, 14, "ink")
    if mouth == "open":
        c.rect(13, 17, 7, 1, "ink")
        c.rect(14, 18, 5, 1, "ink")
        c.rect(15, 19, 3, 1, "tongue")
        c.set(12, 16, "ink")
        c.set(20, 16, "ink")
    else:
        for x, y in ((12, 16), (13, 17), (14, 18), (15, 18), (16, 18), (17, 18), (18, 18), (19, 17), (20, 16)):
            c.set(x, y, "ink")
    c.outline("line")
    return c


def only_diff(a, b):
    d = Canvas(a.w, a.h)
    for k, v in b.px.items():
        if a.px.get(k) != v:
            d.px[k] = v
    return d


# ---------------------------------------------------------------- objetos
def campfire():
    c = Canvas(11, 11)
    for x, y in ((1, 8), (3, 9), (5, 9), (7, 9), (9, 8), (0, 6), (10, 6)):
        c.rect(x, y, 2, 2, "r1")
    c.rect(4, 7, 4, 2, "c1")
    c.rect(5, 1, 1, 2, "fi2")
    c.rect(4, 3, 3, 1, "fi2")
    c.rect(3, 4, 5, 3, "fi1")
    c.rect(4, 4, 3, 3, "fi2")
    c.rect(5, 5, 1, 2, "fi3")
    c.rect(4, 6, 3, 1, "fi3")
    c.outline("line")
    return c


def bush():
    c = Canvas(13, 10)
    c.ellipse(6.5, 5.5, 6, 4.2, "bush", shade="bush_d")
    for x, y in ((3, 4), (7, 3), (9, 6), (5, 7)):
        c.rect(x, y, 2, 2, "berry")
        c.set(x, y, "berry_h")
    c.outline("line")
    return c


def chest():
    c = Canvas(10, 9)
    c.rect(1, 2, 8, 6, "c1")
    c.rect(1, 1, 8, 2, "c0")
    c.rect(1, 4, 8, 1, "c0")
    c.rect(4, 3, 2, 3, "cm")
    c.outline("line")
    return c


def heart():
    rows = [".XX...XX.", "XXXX.XXXX", "XXXXXXXXX", "XXXXXXXXX", ".XXXXXXX.", "..XXXXX..", "...XXX...", "....X...."]
    c = Canvas(9, 8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "X":
                c.set(x, y, "heart")
    c.set(1, 1, "heart_h")
    c.set(2, 1, "heart_h")
    c.set(1, 2, "heart_h")
    c.outline("heart_d")
    return c


def zzz():
    c = Canvas(14, 14)

    def z(x, y, s):
        for i in range(s):
            c.set(x + i, y, "ink")
            c.set(x + s - 1 - i, y + 1 + i, "ink")
            c.set(x + i, y + s + 1, "ink")
    z(0, 7, 4)
    z(7, 0, 5)
    return c


def flower(c, x, y, col):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        c.set(x + dx, y + dy, col)
    c.set(x, y, "fw")


def mound(c, cx, cy, rx, ry):
    c.ellipse(cx, cy, rx, ry, "g1", shade="g2", hi="gh")


def tufts(c, y, seed, n, x0=0, x1=None):
    rnd = random.Random(seed)
    for _ in range(n):
        x = rnd.randint(x0, (x1 or c.w) - 1)
        c.set(x, y + rnd.randint(0, 3), "gd")
        c.set(x, y + rnd.randint(0, 3) - 1, "gh")


# ---------------------------------------------------------------- cenas
def hero_layers():
    W, H = 80, 64
    openeyes = Canvas(W, H)
    for cx, cy, rx, ry in ((14, 61, 13, 5), (40, 62, 15, 5), (66, 61, 13, 5)):
        mound(openeyes, cx, cy, rx, ry)
    rnd = random.Random(3)
    for x in range(2, 78, 5):
        openeyes.set(x + rnd.randint(0, 2), 57 + rnd.randint(0, 2), "gd")
    base = Canvas(W, H)
    base.blit(chibi("lar", "open", "open"), 24, 24)
    base.px.update({k: v for k, v in openeyes.px.items() if k[1] >= 56 and k not in base.px})
    for x, y, col in ((6, 58, "fy"), (21, 59, "fc"), (59, 58, "fc"), (73, 60, "fy"), (33, 60, "fy")):
        flower(base, x, y, col)
    closed = Canvas(W, H)
    closed.blit(chibi("lar", "closed", "open"), 24, 24)
    closed.px.update({k: v for k, v in base.px.items() if k not in closed.px})
    blink = only_diff(base, closed)

    esq = Canvas(W, H)
    esq.blit(chibi("ver", "happy", "smile"), 2, 27)
    dire = Canvas(W, H)
    dire.blit(chibi("beb", "open", "open", look=-1), 49, 30)

    fa = Canvas(W, H)
    rnd = random.Random(8)
    for ang, bx, by, ln, hw, cols in ((-62, -3, 66, 26, 9, FOLHA_VIVA), (-35, -4, 56, 20, 8, FOLHA_MEDIA),
                                      (-80, 6, 70, 22, 7, FOLHA_VIVA), (40, -4, 2, 26, 8, FOLHA_VIVA),
                                      (68, 4, -4, 22, 7, FOLHA_MEDIA), (15, -4, 12, 22, 7, FOLHA_VIVA)):
        leaf(fa, bx, by, ln, ang, hw, cols, notch=ang in (-35, 15))
    fb = Canvas(W, H)
    for ang, bx, by, ln, hw, cols in ((-118, 84, 66, 26, 9, FOLHA_VIVA), (-145, 84, 56, 20, 8, FOLHA_MEDIA),
                                      (-100, 74, 70, 22, 7, FOLHA_VIVA), (140, 84, 2, 26, 8, FOLHA_VIVA),
                                      (112, 76, -4, 22, 7, FOLHA_MEDIA), (165, 84, 12, 22, 7, FOLHA_VIVA)):
        leaf(fb, bx, by, ln, ang, hw, cols, notch=ang in (-145, 165))
    return dict(base=base, blink=blink, esq=esq, dir=dire, fa=fa, fb=fb)


def scene_bg(w, h, col, seed):
    c = Canvas(w, h)
    c.rect(0, 0, w, h, col)
    rnd = random.Random(seed)
    for _ in range(w * h // 70):
        c.set(rnd.randint(0, w - 1), rnd.randint(0, h - 1), "fw")
    return c


def scene_survive():
    c = scene_bg(48, 42, "#FFE9A8", 1)
    c.blit(chibi("ver", "open", "smile", look=1), 2, 9)
    c.blit(campfire(), 36, 28)
    c.blit(bush(), 33, 12)
    return c


def scene_tame():
    c = scene_bg(48, 42, "#CFF2B8", 2)
    c.blit(chibi("lar", "sleep", "smile"), 8, 9)
    c.blit(zzz(), 1, 4)
    c.blit(heart(), 36, 5)
    for x, y in ((41, 31), (44, 34), (39, 35)):
        c.rect(x, y, 3, 3, "berry")
        c.set(x, y, "berry_h")
    return c


def scene_build():
    c = scene_bg(48, 42, "#FFD9B8", 3)
    c.blit(chibi("beb", "happy", "open"), 1, 9)
    for i in range(2):
        x = 32 + i * 8 - 8 + 8
        c.rect(x, 34, 8, 7, "h2" if i == 0 else "h1")
        c.rect(x, 34, 8, 1, "h0")
        c.rect(x, 34, 1, 7, "h0")
    c.rect(32, 30, 16, 4, "h0")
    c.rect(33, 31, 14, 2, "h1")
    c.blit(chest(), 34, 21)
    return c


def scene_community():
    c = scene_bg(96, 46, "#BFEAA6", 4)
    for x, kind, eyes, look in ((0, "lar", "open", 1), (32, "ver", "happy", 0), (64, "beb", "open", -1)):
        c.blit(chibi(kind, eyes, "open" if kind != "ver" else "smile", look), x, 10)
    rnd = random.Random(5)
    c.rect(0, 38, 96, 8, "f_dark")
    for cols, n, lmin, lmax in ((FOLHA_MEDIA, 16, 16, 22), (FOLHA_VIVA, 18, 12, 18)):
        for _ in range(n):
            leaf(c, rnd.randint(-2, 97), 46 + rnd.randint(0, 3), rnd.randint(lmin, lmax),
                 rnd.randint(-125, -55), rnd.randint(5, 7), cols, notch=rnd.random() < .3)
    return c


def scene_peek():
    c = Canvas(40, 30)
    c.blit(chibi("beb", "open", "open", look=1), 4, 2)
    rnd = random.Random(9)
    for cols, n, lmin, lmax in ((FOLHA_MEDIA, 8, 14, 20), (FOLHA_VIVA, 10, 10, 16)):
        for _ in range(n):
            leaf(c, rnd.randint(-2, 41), 32 + rnd.randint(0, 2), rnd.randint(lmin, lmax),
                 rnd.randint(-125, -55), rnd.randint(5, 6), cols, notch=rnd.random() < .3)
    return c


def logo():
    G = {
        "D": ["1110", "1001", "1001", "1001", "1001", "1001", "1110"],
        "I": ["111", "010", "010", "010", "010", "010", "111"],
        "N": ["1001", "1101", "1101", "1011", "1011", "1001", "1001"],
        "O": ["0110", "1001", "1001", "1001", "1001", "1001", "0110"],
        "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
        "A": ["0110", "1001", "1001", "1111", "1001", "1001", "1001"],
        "L": ["1000", "1000", "1000", "1000", "1000", "1000", "1111"],
        "E": ["1111", "1000", "1000", "1110", "1000", "1000", "1111"],
    }

    def word(text, y0, base, light):
        m = Canvas(64, 40)
        x = 0
        for ch in text:
            g = G[ch]
            for j, row in enumerate(g):
                for i, b in enumerate(row):
                    if b == "1":
                        m.rect(3 + (x + i) * 2, y0 + j * 2, 2, 2, base)
                        if j == 0:
                            m.rect(3 + (x + i) * 2, y0 + j * 2, 2, 1, light)
            x += len(g[0]) + 1
        return m
    top = word("DINO", 3, "lar", "plate")
    bot = word("VALE", 21, "g1", "gh")
    full = Canvas(64, 40)
    full.px.update(top.px)
    full.px.update(bot.px)
    out = Canvas(64, 40)
    shadow = Canvas(64, 40)
    shadow.px = {(x, y + 2): "#17381F" for (x, y) in full.px}
    shadow.outline("#17381F", 2)
    out.px.update(shadow.px)
    ol = Canvas(64, 40)
    ol.px = dict(full.px)
    ol.outline("#2B3A1F", 2)
    out.px.update(ol.px)
    out.px.update(full.px)
    xs = [x for x, _ in out.px]
    ys = [y for _, y in out.px]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    res = Canvas(x1 - x0 + 1, y1 - y0 + 1)
    res.px = {(x - x0, y - y0): c for (x, y), c in out.px.items()}
    return res


def favicon():
    c = chibi("lar", "open", "open")
    f = Canvas(30, 24)
    f.px = {(x - 1, y): v for (x, y), v in c.px.items() if y < 24 and 1 <= x < 31}
    return f


def main():
    selva(160, 96, 7).save("selva.svg")
    sl_fundo = strip_lateral(64, 160, 11, [(FOLHA_FUNDO, 14, 34, 52, 9, 13), (FOLHA_MEDIA, 8, 26, 40, 7, 10)])
    sl_frente = strip_lateral(40, 100, 12, [(FOLHA_VIVA, 8, 22, 36, 6, 9)])
    sl_fundo.save("folhas-esq-fundo.svg")
    sl_fundo.mirrored().save("folhas-dir-fundo.svg")
    sl_frente.save("folhas-esq-frente.svg")
    strip_lateral(40, 100, 31, [(FOLHA_VIVA, 8, 22, 36, 6, 9)]).mirrored().save("folhas-dir-frente.svg")
    copa(192, 44, 21).save("copa.svg")
    borda(96, 16, 17).save("borda.svg")

    h = hero_layers()
    h["base"].save("cena-base.svg", label="Um dinossauro laranja sorridente, de gola dourada, no meio da selva")
    h["blink"].save("cena-piscar.svg")
    h["esq"].save("cena-esq.svg")
    h["dir"].save("cena-dir.svg")
    h["fa"].save("cena-folhas-a.svg")
    h["fb"].save("cena-folhas-b.svg")

    scene_survive().save("mec-sobreviver.svg")
    scene_tame().save("mec-domesticar.svg")
    scene_build().save("mec-construir.svg")
    scene_community().save("comunidade.svg")
    scene_peek().save("espiando.svg")
    logo().save("logo.svg", label="Dino Vale")
    favicon().save("favicon.svg")
    print("arte gerada em", OUT)


if __name__ == "__main__":
    main()
