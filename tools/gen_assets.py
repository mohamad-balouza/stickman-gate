"""Procedural pixel-art + SFX generator for "Stick 'Em Up".
Generates all game assets (PNG sprite sheets, tiles, backgrounds, WAV sfx)
with zero external dependencies. Run from project root:  python tools/gen_assets.py
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SFX = os.path.join(ASSETS, "sfx")
os.makedirs(ASSETS, exist_ok=True)
os.makedirs(SFX, exist_ok=True)

# ---------------------------------------------------------------- PNG writer

def _chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

def write_png(path, w, h, px):
    raw = b"".join(b"\x00" + bytes(px[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(raw, 9))
           + _chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", os.path.relpath(path, ROOT), f"{w}x{h}")

class Canvas:
    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)
        if bg[3]:
            for i in range(w * h):
                self.px[i * 4:i * 4 + 4] = bytes(bg)

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.px[i:i + 4] = bytes(c)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (int(y) * self.w + int(x)) * 4
            return tuple(self.px[i:i + 4])
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, c)

    def disc(self, cx, cy, r, c):
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r), int(cx + r) + 1):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.5:
                    self.set(xx, yy, c)

    def seg(self, p0, p1, c, t=2):
        """Thick line segment: stamp t x t squares along the line."""
        x0, y0 = p0
        x1, y1 = p1
        dist = max(abs(x1 - x0), abs(y1 - y0))
        n = int(dist * 2) + 2
        for i in range(n):
            f = i / (n - 1)
            x = round(x0 + (x1 - x0) * f)
            y = round(y0 + (y1 - y0) * f)
            for dy in range(t):
                for dx in range(t):
                    self.set(x + dx - t // 2, y + dy - t // 2, c)

    def save(self, path):
        write_png(path, self.w, self.h, self.px)

# ---------------------------------------------------------------- stickman

FR = 32  # frame size

def draw_stick(c, ox, oy, body, head, segs, eye=True, band=None, dead=False):
    hx, hy = head
    c.disc(ox + hx, oy + hy, 3, body)
    for p0, p1 in segs:
        c.seg((ox + p0[0], oy + p0[1]), (ox + p1[0], oy + p1[1]), body, 2)
    if band:
        for dx in range(-3, 4):
            c.set(ox + hx + dx, oy + hy - 1, band)
        c.set(ox + hx - 4, oy + hy, band)
        c.set(ox + hx - 5, oy + hy + 1, band)
    if eye and not dead:
        c.set(ox + hx + 2, oy + hy, (255, 255, 255, 255))

def pose_idle(i):
    dy = [0, 1, 1, 0][i]
    sw = [0, 1, 0, -1][i]
    head = (16, 8 + dy)
    segs = [((16, 11 + dy), (16, 20 + dy)),
            ((16, 14 + dy), (23, 14 + dy)),
            ((16, 14 + dy), (13 + sw, 19 + dy)),
            ((16, 20 + dy), (13, 30)),
            ((16, 20 + dy), (19, 30))]
    return head, segs

def pose_run(i):
    t = 2 * math.pi * i / 6.0
    s = math.sin(t)
    fa = round(5 * s)
    lift_a = max(0, round(2.5 * s))
    lift_b = max(0, round(-2.5 * s))
    dy = -1 if abs(s) > 0.7 else 0
    head = (17, 8 + dy)
    hip = (16, 20 + dy)
    segs = [((17, 11 + dy), hip),
            ((16, 14 + dy), (23, 14 + dy)),
            ((16, 14 + dy), (16 - round(4 * s), 18 + dy)),
            (hip, (16 + fa, 30 - lift_a)),
            (hip, (16 - fa, 30 - lift_b))]
    return head, segs

POSE_JUMP = ((16, 7), [((16, 10), (16, 19)), ((16, 13), (23, 13)),
                       ((16, 13), (11, 9)), ((16, 19), (12, 25)), ((16, 19), (20, 24))])
POSE_FALL = ((16, 9), [((16, 12), (16, 21)), ((16, 15), (23, 14)),
                       ((16, 15), (10, 11)), ((16, 21), (11, 29)), ((16, 21), (21, 28))])
POSE_SHOOT = [
    ((15, 8), [((15, 11), (16, 20)), ((16, 14), (21, 13)), ((16, 14), (13, 19)),
               ((16, 20), (12, 30)), ((16, 20), (20, 30))]),
    ((16, 8), [((16, 11), (16, 20)), ((16, 14), (23, 14)), ((16, 14), (13, 19)),
               ((16, 20), (13, 30)), ((16, 20), (19, 30))]),
]
POSE_DEATH = [
    ((14, 9), [((15, 12), (16, 21)), ((15, 14), (10, 17)), ((15, 14), (21, 16)),
               ((16, 21), (12, 30)), ((16, 21), (20, 29))]),
    ((12, 13), [((13, 15), (16, 22)), ((14, 17), (8, 19)), ((14, 17), (20, 19)),
                ((16, 22), (11, 30)), ((16, 22), (21, 29))]),
    ((10, 19), [((11, 21), (17, 24)), ((12, 22), (7, 25)), ((12, 22), (16, 27)),
                ((17, 24), (13, 30)), ((17, 24), (23, 28))]),
    ((8, 25), [((10, 27), (18, 28)), ((12, 27), (9, 30)), ((12, 27), (15, 29)),
               ((18, 28), (24, 27)), ((18, 28), (23, 30))]),
    ((7, 28), [((10, 29), (19, 29)), ((13, 29), (16, 27)), ((13, 29), (11, 30)),
               ((19, 29), (26, 28)), ((19, 29), (25, 30))]),
]

def make_sheet(path, body, band):
    # 6 cols x 5 rows of 32x32: idle(4) / run(6) / jump,fall / shoot(2) / death(5)
    c = Canvas(6 * FR, 5 * FR)
    for i in range(4):
        h, s = pose_idle(i)
        draw_stick(c, i * FR, 0, body, h, s, band=band)
    for i in range(6):
        h, s = pose_run(i)
        draw_stick(c, i * FR, FR, body, h, s, band=band)
    draw_stick(c, 0, 2 * FR, body, *POSE_JUMP, band=band)
    draw_stick(c, FR, 2 * FR, body, *POSE_FALL, band=band)
    for i, (h, s) in enumerate(POSE_SHOOT):
        draw_stick(c, i * FR, 3 * FR, body, h, s, band=band)
    for i, (h, s) in enumerate(POSE_DEATH):
        draw_stick(c, i * FR, 4 * FR, body, h, s, band=band, dead=(i >= 2))
    c.save(path)

make_sheet(os.path.join(ASSETS, "player_sheet.png"), (26, 28, 44, 255), (56, 182, 255, 255))
make_sheet(os.path.join(ASSETS, "enemy_sheet.png"), (140, 30, 34, 255), None)

# ---------------------------------------------------------------- tiles (4 x 16px in 64x16... use 64x64 grid 4x4, row 0 used)

def hash01(x, y, salt=0):
    n = (x * 374761393 + y * 668265263 + salt * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) % 1000) / 1000.0

tiles = Canvas(64, 64)
# tile (0,0): grass-topped dirt
for y in range(16):
    for x in range(16):
        r = hash01(x, y, 1)
        if y < 4 or (y == 4 and r > 0.5):
            col = (63, 163, 77, 255) if r > 0.25 else (111, 207, 111, 255)
            if y == 0:
                col = (111, 207, 111, 255) if r > 0.4 else (63, 163, 77, 255)
        else:
            col = (138, 90, 59, 255) if r > 0.2 else (110, 68, 41, 255)
        tiles.set(x, y, col)
# tile (1,0): dirt
for y in range(16):
    for x in range(16):
        r = hash01(x, y, 2)
        col = (138, 90, 59, 255)
        if r < 0.18:
            col = (110, 68, 41, 255)
        elif r > 0.93:
            col = (166, 118, 82, 255)
        tiles.set(16 + x, y, col)
# tile (2,0): stone bricks
for y in range(16):
    for x in range(16):
        r = hash01(x, y, 3)
        col = (139, 139, 153, 255) if r > 0.2 else (120, 120, 134, 255)
        row = y // 8
        if y % 8 == 7 or (x + row * 8) % 16 == 15:
            col = (94, 94, 108, 255)
        tiles.set(32 + x, y, col)
# tile (3,0): wooden plank platform
for y in range(16):
    for x in range(16):
        r = hash01(x, y, 4)
        col = (176, 128, 70, 255) if r > 0.2 else (156, 110, 56, 255)
        if y in (0, 5, 10, 15):
            col = (122, 84, 38, 255)
        if (x, y) in ((2, 2), (13, 2), (2, 12), (13, 12)):
            col = (80, 56, 28, 255)
        tiles.set(48 + x, y, col)
tiles.save(os.path.join(ASSETS, "tiles.png"))

# ---------------------------------------------------------------- props

# pistol 12x8
g = Canvas(12, 8)
g.rect(1, 1, 10, 3, (52, 54, 66, 255))       # slide/barrel
g.rect(1, 1, 10, 1, (86, 90, 106, 255))      # highlight
g.rect(2, 4, 3, 4, (35, 36, 46, 255))        # grip
g.set(5, 4, (35, 36, 46, 255))               # trigger guard
g.save(os.path.join(ASSETS, "pistol.png"))

# rifle 18x8
g = Canvas(18, 8)
g.rect(0, 2, 4, 3, (122, 84, 38, 255))       # stock
g.rect(3, 1, 13, 3, (52, 54, 66, 255))       # body+barrel
g.rect(3, 1, 13, 1, (86, 90, 106, 255))
g.rect(16, 2, 2, 1, (35, 36, 46, 255))       # muzzle tip
g.rect(6, 4, 2, 3, (35, 36, 46, 255))        # magazine
g.rect(10, 0, 3, 1, (255, 210, 62, 255))     # brass sight (fancy!)
g.save(os.path.join(ASSETS, "rifle.png"))

# bullet 8x4
g = Canvas(8, 4)
g.rect(0, 1, 6, 2, (255, 210, 62, 255))
g.rect(5, 0, 3, 4, (255, 244, 178, 255))
g.save(os.path.join(ASSETS, "bullet.png"))

# muzzle flash 10x10 star
g = Canvas(10, 10)
g.seg((1, 5), (9, 5), (255, 210, 62, 255), 2)
g.seg((5, 1), (5, 9), (255, 210, 62, 255), 2)
g.seg((2, 2), (8, 8), (255, 244, 178, 255), 2)
g.seg((8, 2), (2, 8), (255, 244, 178, 255), 2)
g.disc(5, 5, 2, (255, 255, 255, 255))
g.save(os.path.join(ASSETS, "muzzle_flash.png"))

# crate 16x16 weapon pickup
g = Canvas(16, 16)
g.rect(0, 0, 16, 16, (156, 107, 48, 255))
g.rect(1, 1, 14, 14, (176, 128, 70, 255))
for i in range(16):
    g.set(i, i, (122, 84, 38, 255))
    g.set(15 - i, i, (122, 84, 38, 255))
g.rect(0, 0, 16, 2, (122, 84, 38, 255))
g.rect(0, 14, 16, 2, (122, 84, 38, 255))
g.rect(0, 0, 2, 16, (122, 84, 38, 255))
g.rect(14, 0, 2, 16, (122, 84, 38, 255))
# up arrow icon
g.rect(7, 4, 2, 8, (255, 210, 62, 255))
g.seg((5, 7), (8, 4), (255, 210, 62, 255), 2)
g.seg((10, 7), (8, 4), (255, 210, 62, 255), 2)
g.save(os.path.join(ASSETS, "crate.png"))

# hearts 8x8
def heart(path, fill, outline):
    g = Canvas(8, 8)
    pts = ["01100110",
           "11111111",
           "11111111",
           "11111111",
           "01111110",
           "00111100",
           "00011000",
           "00000000"]
    for y, row in enumerate(pts):
        for x, ch in enumerate(row):
            if ch == "1":
                g.set(x, y, fill)
    g.set(2, 1, (255, 255, 255, 255)) if fill[0] > 100 else None
    g.save(path)

heart(os.path.join(ASSETS, "heart_full.png"), (226, 59, 74, 255), None)
heart(os.path.join(ASSETS, "heart_empty.png"), (70, 74, 90, 255), None)

# flag 16x32
g = Canvas(16, 32)
g.rect(3, 2, 2, 30, (139, 139, 153, 255))
g.set(3, 2, (200, 200, 210, 255))
for i in range(9):
    g.rect(5, 3 + i // 2, 10 - i, 1, (63, 163, 77, 255))
g.save(os.path.join(ASSETS, "flag.png"))

# ---------------------------------------------------------------- background

# sky 320x180 gradient + sun
g = Canvas(320, 180)
top = (58, 123, 213)
bot = (168, 216, 240)
for y in range(180):
    f = y / 179.0
    # ordered dither between gradient bands
    for x in range(320):
        fd = f + (hash01(x, y, 9) - 0.5) * 0.04
        fd = min(1.0, max(0.0, fd))
        col = tuple(int(top[i] + (bot[i] - top[i]) * fd) for i in range(3)) + (255,)
        g.set(x, y, col)
g.disc(250, 42, 14, (255, 242, 168, 255))
g.disc(250, 42, 10, (255, 250, 214, 255))
g.save(os.path.join(ASSETS, "sky.png"))

# far hills 320x120 with clouds
g = Canvas(320, 120)
for x in range(320):
    hgt = 46 + 18 * math.sin(x * 0.021) + 10 * math.sin(x * 0.052 + 1.7) + 4 * math.sin(x * 0.11 + 0.4)
    for y in range(120):
        if y > 120 - hgt:
            g.set(x, y, (44, 93, 99, 255))
        elif y == int(120 - hgt) :
            g.set(x, y, (63, 121, 128, 255))
for cx, cy, r in ((40, 18, 7), (52, 20, 9), (66, 17, 6), (180, 30, 8), (196, 32, 10), (210, 28, 6), (290, 12, 7), (302, 14, 8)):
    g.disc(cx, cy, r, (245, 247, 250, 235))
    g.rect(cx - r, cy, 2 * r + 1, r, (245, 247, 250, 235))
g.save(os.path.join(ASSETS, "hills_far.png"))

# near hills 320x120
g = Canvas(320, 120)
for x in range(320):
    hgt = 30 + 22 * math.sin(x * 0.033 + 2.2) + 8 * math.sin(x * 0.09 + 0.9)
    for y in range(120):
        if y > 120 - hgt:
            g.set(x, y, (62, 125, 79, 255))
        elif y == int(120 - hgt):
            g.set(x, y, (88, 158, 106, 255))
g.save(os.path.join(ASSETS, "hills_near.png"))

# ---------------------------------------------------------------- WAV sfx

RATE = 22050

def write_wav(path, samples):
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(data)) + data)
    print("wrote", os.path.relpath(path, ROOT), f"{len(samples)/RATE:.2f}s")

def env(i, n, attack=0.005, decay=1.0):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-decay * t / dur * 5)
    return a * d

def sweep(dur, f0, f1, wave="square", vol=0.35, decay=1.0):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        if wave == "square":
            s = 1.0 if (phase % 1.0) < 0.5 else -1.0
        elif wave == "tri":
            s = 4 * abs((phase % 1.0) - 0.5) - 1
        else:
            s = math.sin(2 * math.pi * phase)
        out.append(s * vol * env(i, n, decay=decay))
    return out

def noise(dur, vol=0.4, decay=2.0, lp=0.4):
    n = int(dur * RATE)
    out = []
    v = 0.0
    seed = 12345
    for i in range(n):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        r = (seed / 0x3FFFFFFF) - 1.0
        v = v + lp * (r - v)
        out.append(v * vol * env(i, n, decay=decay))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]

def cat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out

write_wav(os.path.join(SFX, "jump.wav"), sweep(0.18, 280, 660, "square", 0.28, 1.4))
write_wav(os.path.join(SFX, "shoot_pistol.wav"), mix(noise(0.09, 0.5, 3.0, 0.55), sweep(0.07, 240, 90, "square", 0.22, 2.0)))
write_wav(os.path.join(SFX, "shoot_rifle.wav"), mix(noise(0.13, 0.55, 2.4, 0.4), sweep(0.1, 180, 60, "square", 0.26, 1.8)))
write_wav(os.path.join(SFX, "hit.wav"), sweep(0.14, 200, 70, "square", 0.3, 1.6))
write_wav(os.path.join(SFX, "enemy_die.wav"), mix(noise(0.25, 0.4, 2.0, 0.3), sweep(0.25, 420, 90, "tri", 0.3, 1.2)))
write_wav(os.path.join(SFX, "player_die.wav"), sweep(0.55, 480, 55, "tri", 0.35, 1.0))
write_wav(os.path.join(SFX, "pickup.wav"), cat(sweep(0.07, 620, 620, "square", 0.25, 0.4), sweep(0.1, 930, 930, "square", 0.25, 0.8)))
write_wav(os.path.join(SFX, "win.wav"), cat(sweep(0.11, 523, 523, "square", 0.25, 0.3), sweep(0.11, 659, 659, "square", 0.25, 0.3), sweep(0.11, 784, 784, "square", 0.25, 0.3), sweep(0.3, 1046, 1046, "square", 0.25, 0.9)))

print("all assets generated")
