"""Boss + dash asset generator for "Stick 'Em Up".
Standalone (does not re-run gen_assets). Run:  python tools/gen_boss_assets.py
Generates: assets/boss_sheet.png (576x288, 96x96 frames), skull/orb/shockwave
projectiles, and boss/dash WAV sfx.

Boss: "THE AMALGAM" — an abomination of fused stickmen. Big lumpy mass of
tangled navy+red limbs, one huge red-eyed head, smaller consumed heads
(one wearing the player's cyan headband) lolling from the blob.
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SFX = os.path.join(ASSETS, "sfx")

# ---------------------------------------------------------------- PNG writer (same as gen_assets)

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
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = bytearray(w * h * 4)

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.px[i:i + 4] = bytes(c)

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

def hash01(x, y, salt=0):
    n = (x * 374761393 + y * 668265263 + salt * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) % 1000) / 1000.0

# ---------------------------------------------------------------- palette

NAVY = (26, 28, 44, 255)        # player-stick colour (consumed victims)
NAVY_HI = (48, 52, 78, 255)
RED = (140, 30, 34, 255)        # enemy-stick colour
RED_HI = (176, 52, 56, 255)
DARK = (14, 15, 26, 255)        # deep shadow flesh
EYE = (255, 60, 50, 255)
EYE_GLOW = (255, 120, 90, 255)
BAND = (56, 182, 255, 255)      # the cyan headband of a consumed player
WHITE = (255, 255, 255, 255)
BONE = (222, 216, 200, 255)

F = 96  # frame size

def blob_mass(c, ox, oy, cx, cy, rx, ry, wob):
    """Lumpy fused-flesh mass: overlapping discs with mottled navy/red."""
    lumps = [
        (0, 0, 1.00, DARK),
        (-rx * 0.45, -ry * 0.25, 0.62, NAVY),
        (rx * 0.42, -ry * 0.18, 0.58, RED),
        (-rx * 0.15, ry * 0.30, 0.55, NAVY),
        (rx * 0.25, ry * 0.35, 0.50, RED),
        (0, -ry * 0.42, 0.48, NAVY_HI),
    ]
    for i, (dx, dy, s, col) in enumerate(lumps):
        w = math.sin(wob + i * 1.7) * 1.5
        r = min(rx, ry) * s
        c.disc(ox + cx + dx + w, oy + cy + dy, r, col)
    # mottle texture
    for yy in range(int(cy - ry), int(cy + ry)):
        for xx in range(int(cx - rx), int(cx + rx)):
            if ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0:
                r = hash01(xx, yy, 77)
                if r > 0.93:
                    c.set(ox + xx, oy + yy, RED_HI)
                elif r < 0.05:
                    c.set(ox + xx, oy + yy, DARK)

def limb(c, ox, oy, p0, p1, col, t=3, hand=True):
    c.seg((ox + p0[0], oy + p0[1]), (ox + p1[0], oy + p1[1]), col, t)
    if hand:
        c.disc(ox + p1[0], oy + p1[1], 2, col)

def small_head(c, ox, oy, x, y, col, band=False, dead=True):
    c.disc(ox + x, oy + y, 3, col)
    if band:
        for dx in range(-3, 4):
            c.set(ox + x + dx, oy + y - 1, BAND)
    if dead:
        c.set(ox + x - 1, oy + y, WHITE)
        c.set(ox + x + 2, oy + y + 1, WHITE)

def big_head(c, ox, oy, x, y, eyes=EYE, mouth=True, r=8):
    c.disc(ox + x, oy + y, r, DARK)
    c.disc(ox + x - 1, oy + y - 2, r - 3, NAVY)
    # two big glowing eyes
    c.disc(ox + x - 3, oy + y - 1, 2, eyes)
    c.disc(ox + x + 3, oy + y - 1, 2, eyes)
    c.set(ox + x - 3, oy + y - 2, WHITE)
    c.set(ox + x + 3, oy + y - 2, WHITE)
    if mouth:
        # jagged grin
        for i, dx in enumerate(range(-4, 5)):
            yy = y + 4 + (i % 2)
            c.set(ox + x + dx, oy + yy, BONE)

def legs(c, ox, oy, cx, ground, spread, wob, lift=0):
    """Four stumpy legs under the blob."""
    for i, dx in enumerate((-spread, -spread * 0.4, spread * 0.4, spread)):
        w = round(math.sin(wob * 2 + i * 2.1) * 1.5)
        col = NAVY if i % 2 == 0 else RED
        c.seg((ox + cx + dx, oy + ground - 14), (ox + cx + dx + w, oy + ground - lift), col, 3)

def frame_idle(c, ox, oy, i):
    wob = i * math.pi / 2.0
    bob = [0, 1, 2, 1][i]
    cx, cy = 48, 58 + bob
    blob_mass(c, ox, oy, cx, cy, 26, 20, wob)
    legs(c, ox, oy, cx, 92, 16, wob)
    # writhing arms out the sides
    a = math.sin(wob) * 4
    limb(c, ox, oy, (cx - 20, cy - 6), (cx - 36, cy - 14 + a), NAVY)
    limb(c, ox, oy, (cx - 16, cy + 8), (cx - 34, cy + 16 - a), RED)
    limb(c, ox, oy, (cx + 20, cy - 8), (cx + 36, cy - 16 - a), RED)
    limb(c, ox, oy, (cx + 18, cy + 6), (cx + 35, cy + 14 + a), NAVY)
    # a grasping arm reaching from the top
    limb(c, ox, oy, (cx + 6, cy - 16), (cx + 12 + a, cy - 32), NAVY)
    # consumed heads lolling from the mass
    small_head(c, ox, oy, cx - 14, cy - 16 + bob, NAVY, band=True)
    small_head(c, ox, oy, cx + 17, cy + 12, RED)
    small_head(c, ox, oy, cx - 21, cy + 10, RED)
    # the big central head
    big_head(c, ox, oy, cx + 4, cy - 22 - bob)

def frame_windup(c, ox, oy, i):
    # crouched flat + eyes flare — telegraph pose
    wob = i * 1.3
    cx, cy = 48, 66
    blob_mass(c, ox, oy, cx, cy, 30, 15, wob)
    legs(c, ox, oy, cx, 92, 20, wob)
    # arms coiled in
    limb(c, ox, oy, (cx - 22, cy - 2), (cx - 30, cy + 8), NAVY)
    limb(c, ox, oy, (cx + 22, cy - 2), (cx + 30, cy + 8), RED)
    small_head(c, ox, oy, cx - 16, cy - 10, NAVY, band=True)
    small_head(c, ox, oy, cx + 18, cy - 8, RED)
    eyes = (255, 210, 62, 255) if i == 1 else EYE
    big_head(c, ox, oy, cx + 2, cy - 16, eyes=eyes, r=8)

def frame_lunge(c, ox, oy, i):
    # stretched tall/forward, arms flung out
    wob = i * 2.1
    cx, cy = 48, 52 - i * 2
    blob_mass(c, ox, oy, cx, cy, 22, 26, wob)
    legs(c, ox, oy, cx, 92, 12, wob, lift=4)
    limb(c, ox, oy, (cx - 16, cy - 12), (cx - 34, cy - 28), NAVY)
    limb(c, ox, oy, (cx + 16, cy - 12), (cx + 34, cy - 28), RED)
    limb(c, ox, oy, (cx - 18, cy + 6), (cx - 36, cy + 2), RED)
    limb(c, ox, oy, (cx + 18, cy + 6), (cx + 36, cy + 2), NAVY)
    small_head(c, ox, oy, cx - 15, cy - 18, NAVY, band=True)
    small_head(c, ox, oy, cx + 18, cy + 14, RED)
    big_head(c, ox, oy, cx + 2, cy - 26, r=9)

def frame_death(c, ox, oy, i):
    """Blob deflates; at the end it is a pile of separated stick corpses."""
    f = i / 5.0
    cx = 48
    ry = 20 * (1.0 - f * 0.8)
    cy = 92 - 14 - ry * 0.8
    wob = i * 1.1
    if f < 0.999:
        blob_mass(c, ox, oy, cx, cy, 26 + 6 * f, max(4, ry), wob)
    if f < 0.6:
        legs(c, ox, oy, cx, 92, 16, wob)
    # limbs droop
    droop = f * 18
    limb(c, ox, oy, (cx - 18, cy), (cx - 34, min(90, cy + 6 + droop)), NAVY)
    limb(c, ox, oy, (cx + 18, cy), (cx + 34, min(90, cy + 6 + droop)), RED)
    # heads sink / roll off
    small_head(c, ox, oy, cx - 14 - f * 14, min(88, cy - 12 + f * 34), NAVY, band=True)
    small_head(c, ox, oy, cx + 16 + f * 12, min(88, cy - 6 + f * 30), RED)
    if i < 4:
        big_head(c, ox, oy, cx + 2, cy - ry - 6 + f * 10, eyes=EYE if i < 2 else (90, 90, 100, 255), mouth=(i < 3))
    else:
        # big head on the ground, eyes dead
        c.disc(ox + cx + 6, oy + 86, 8, DARK)
        c.disc(ox + cx + 5, oy + 84, 5, NAVY)
        c.set(ox + cx + 3, oy + 85, (90, 90, 100, 255))
        c.set(ox + cx + 9, oy + 85, (90, 90, 100, 255))
    if i >= 4:
        # scattered corpse sticks
        for k, (sx, sy, col) in enumerate(((16, 88, RED), (34, 90, NAVY), (62, 89, RED), (78, 88, NAVY))):
            c.seg((ox + sx, oy + sy), (ox + sx + 9, oy + sy + 1), col, 2)
            c.disc(ox + sx - 2, oy + sy, 2, col)

# sheet: 6 cols x 3 rows of 96: idle(4) / windup(2)+lunge(2) / death(6)
c = Canvas(6 * F, 3 * F)
for i in range(4):
    frame_idle(c, i * F, 0, i)
for i in range(2):
    frame_windup(c, i * F, F, i)
for i in range(2):
    frame_lunge(c, (2 + i) * F, F, i)
for i in range(6):
    frame_death(c, i * F, 2 * F, i)
c.save(os.path.join(ASSETS, "boss_sheet.png"))

# ---------------------------------------------------------------- projectiles

# skull: a severed stickman head, 12x12
g = Canvas(12, 12)
g.disc(6, 6, 5, DARK)
g.disc(5, 5, 3, NAVY)
g.disc(4, 5, 1, EYE)
g.disc(8, 5, 1, EYE)
g.set(4, 4, WHITE)
for dx in range(3, 10, 2):
    g.set(dx, 9, BONE)
g.save(os.path.join(ASSETS, "skull.png"))

# orb: red energy ball, 10x10
g = Canvas(10, 10)
g.disc(5, 5, 4, (170, 40, 40, 200))
g.disc(5, 5, 3, EYE)
g.disc(4, 4, 1.5, EYE_GLOW)
g.set(4, 3, WHITE)
g.save(os.path.join(ASSETS, "orb.png"))

# shockwave: travelling dust wave, 24x14
g = Canvas(24, 14)
for x in range(24):
    hgt = 4 + 8 * math.exp(-((x - 18) / 7.0) ** 2)
    for y in range(14):
        if y > 13 - hgt:
            r = hash01(x, y, 5)
            if r > 0.35:
                col = (168, 144, 110, 235) if r > 0.6 else (138, 110, 80, 235)
                g.set(x, y, col)
g.save(os.path.join(ASSETS, "shockwave.png"))

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
    seed = 977351
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

write_wav(os.path.join(SFX, "dash.wav"), mix(noise(0.14, 0.4, 2.6, 0.75), sweep(0.12, 500, 900, "sine", 0.18, 1.6)))
write_wav(os.path.join(SFX, "boss_roar.wav"), mix(noise(0.7, 0.4, 1.1, 0.18), sweep(0.7, 130, 55, "square", 0.3, 0.9), sweep(0.6, 66, 40, "tri", 0.3, 1.0)))
write_wav(os.path.join(SFX, "boss_slam.wav"), mix(noise(0.4, 0.65, 2.2, 0.14), sweep(0.35, 90, 34, "tri", 0.5, 1.6)))
write_wav(os.path.join(SFX, "boss_whip.wav"), mix(noise(0.16, 0.5, 2.0, 0.85), sweep(0.16, 900, 180, "sine", 0.2, 1.8)))
write_wav(os.path.join(SFX, "boss_summon.wav"), cat(sweep(0.14, 300, 520, "tri", 0.3, 0.6), sweep(0.14, 520, 300, "tri", 0.3, 0.6), sweep(0.2, 300, 640, "tri", 0.3, 1.0)))
write_wav(os.path.join(SFX, "boss_charge.wav"), mix(noise(0.9, 0.35, 0.9, 0.12), sweep(0.9, 45, 120, "tri", 0.35, 0.6)))
write_wav(os.path.join(SFX, "boss_shoot.wav"), mix(sweep(0.14, 340, 130, "square", 0.28, 1.6), noise(0.1, 0.25, 2.4, 0.5)))
write_wav(os.path.join(SFX, "boss_stun.wav"), cat(sweep(0.1, 500, 300, "square", 0.3, 0.8), sweep(0.35, 280, 120, "tri", 0.3, 1.2)))
write_wav(os.path.join(SFX, "boss_die.wav"), mix(cat(sweep(0.3, 220, 150, "square", 0.3, 0.5), sweep(0.4, 150, 70, "square", 0.32, 0.6), sweep(0.7, 90, 28, "tri", 0.4, 0.9)), noise(1.4, 0.35, 1.2, 0.2)))
write_wav(os.path.join(SFX, "gate_rumble.wav"), mix(noise(0.6, 0.5, 1.6, 0.1), sweep(0.6, 70, 38, "tri", 0.4, 1.2)))

print("boss assets generated")
