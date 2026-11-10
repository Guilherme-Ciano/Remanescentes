"""Gera poster.png (512x512) e workshop/preview.png (256x256) do Remanescentes.
Uso: python3 tools/make_poster.py  (precisa de Pillow)"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024
random.seed(7)
img = Image.new("RGB", (S, S))
px = img.load()
# ceu de fim de tarde: azul-petroleo em cima, brasa no horizonte
top, mid, hor = (14, 22, 28), (38, 44, 48), (196, 104, 46)
for y in range(S):
    t = y / S
    if t < 0.55:
        k = t / 0.55; c = [int(top[i] + (mid[i] - top[i]) * k) for i in range(3)]
    else:
        k = min(1, (t - 0.55) / 0.2); c = [int(mid[i] + (hor[i] - mid[i]) * k) for i in range(3)]
    for x in range(S): px[x, y] = tuple(c)
d = ImageDraw.Draw(img)
# fumaca ao longe
smoke = Image.new("L", (S, S), 0); sd = ImageDraw.Draw(smoke)
for i in range(18):
    r = 30 + i * 9; sd.ellipse((760 - i * 14 - r, 700 - i * 34 - r, 760 - i * 14 + r, 700 - i * 34 + r), fill=60 - i * 3)
img.paste((70, 66, 64), (0, 0), smoke.filter(ImageFilter.GaussianBlur(18)))
# predios ao fundo
ground = 760
x = 0
far = (34, 30, 30)
while x < S:
    w = random.randint(60, 150); h = random.randint(90, 260)
    d.rectangle((x, ground - h, x + w, ground), fill=far); x += w + random.randint(0, 10)
# a safehouse: casa com tabuas e uma janela acesa
house = (20, 18, 19)
d.rectangle((90, 560, 420, ground), fill=house)
d.polygon([(70, 565), (255, 450), (440, 565)], fill=house)
glow = Image.new("L", (S, S), 0); gd = ImageDraw.Draw(glow)
gd.ellipse((150, 560, 330, 720), fill=120)
img.paste((255, 170, 70), (0, 0), glow.filter(ImageFilter.GaussianBlur(40)))
d = ImageDraw.Draw(img)
d.rectangle((200, 600, 280, 680), fill=(255, 196, 96))
for yy in (622, 652):   # tabuas
    d.polygon([(190, yy - 6), (290, yy - 14), (290, yy - 2), (190, yy + 6)], fill=(60, 40, 26))
d.rectangle((330, 640, 380, ground), fill=(12, 10, 10))   # porta
# chao
for yy in range(ground, S):
    k = (yy - ground) / (S - ground); d.line((0, yy, S, yy), fill=(int(58 - 30 * k), int(44 - 22 * k), int(36 - 18 * k)))

def person(cx, base, h, gun=False, lean=0):
    head = h * 0.13; body = (8, 7, 7)
    d.ellipse((cx - head / 2 + lean, base - h, cx + head / 2 + lean, base - h + head), fill=body)
    sh = base - h + head * 1.05
    d.polygon([(cx - h * 0.13 + lean, sh + h * 0.05), (cx + h * 0.13 + lean, sh + h * 0.05),
               (cx + h * 0.11, base - h * 0.45), (cx - h * 0.11, base - h * 0.45)], fill=body)
    d.rounded_rectangle((cx - h * 0.13 + lean, sh, cx + h * 0.13 + lean, sh + h * 0.12), radius=int(h * 0.05), fill=body)
    d.polygon([(cx - h * 0.11, base - h * 0.47), (cx - h * 0.01, base - h * 0.47), (cx - h * 0.04, base), (cx - h * 0.12, base)], fill=body)
    d.polygon([(cx + h * 0.01, base - h * 0.47), (cx + h * 0.11, base - h * 0.47), (cx + h * 0.12, base), (cx + h * 0.04, base)], fill=body)
    d.polygon([(cx - h * 0.13 + lean, sh + 4), (cx - h * 0.17 + lean, base - h * 0.42), (cx - h * 0.12, base - h * 0.42), (cx - h * 0.09 + lean, sh + 10)], fill=body)
    if gun:
        d.line((cx + h * 0.1, sh + h * 0.14, cx + h * 0.45, sh - h * 0.02), fill=body, width=max(3, int(h * 0.025)))
        d.polygon([(cx + h * 0.13 + lean, sh + 4), (cx + h * 0.3, sh + h * 0.08), (cx + h * 0.28, sh + h * 0.13), (cx + h * 0.09, sh + h * 0.12)], fill=body)
    else:
        d.polygon([(cx + h * 0.13 + lean, sh + 4), (cx + h * 0.17 + lean, base - h * 0.42), (cx + h * 0.12, base - h * 0.42), (cx + h * 0.09 + lean, sh + 10)], fill=body)

def shambler(cx, base, h):
    body = (40, 34, 32)
    d.ellipse((cx + h * 0.06, base - h * 0.95, cx + h * 0.18, base - h * 0.83), fill=body)
    d.polygon([(cx - h * 0.08, base - h * 0.8), (cx + h * 0.12, base - h * 0.85), (cx + h * 0.08, base - h * 0.45), (cx - h * 0.08, base - h * 0.45)], fill=body)
    d.line((cx + h * 0.1, base - h * 0.75, cx + h * 0.35, base - h * 0.62), fill=body, width=max(2, int(h * 0.04)))
    d.line((cx - h * 0.04, base - h * 0.45, cx - h * 0.1, base), fill=body, width=max(2, int(h * 0.06)))
    d.line((cx + h * 0.04, base - h * 0.45, cx + h * 0.1, base), fill=body, width=max(2, int(h * 0.06)))

for i, zx in enumerate((640, 700, 770, 880, 940)):
    shambler(zx, ground + 6 + (i % 2) * 4, 70 + (i % 3) * 8)
person(560, 930, 300, gun=True)
person(470, 945, 270)
person(405, 950, 190)

# granulado
noise = Image.effect_noise((S, S), 18).convert("L")
img = Image.blend(img, Image.merge("RGB", (noise, noise, noise)), 0.05)
# vinheta
vig = Image.new("L", (S, S), 0); vd = ImageDraw.Draw(vig)
vd.ellipse((-200, -200, S + 200, S + 200), fill=255)
img = Image.composite(img, Image.new("RGB", (S, S), (0, 0, 0)), vig.filter(ImageFilter.GaussianBlur(160)))
d = ImageDraw.Draw(img)

def font(name, size):
    for p in ("/usr/share/fonts/TTF/" + name, "/usr/share/fonts/noto/" + name):
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()

title = "REMANESCENTES"
f = font("OpenSans-CondensedExtraBold.ttf", 150)
w = d.textlength(title, font=f)
while w > S - 110:
    f = font("OpenSans-CondensedExtraBold.ttf", f.size - 4); w = d.textlength(title, font=f)
d.text(((S - w) / 2 + 4, 74), title, font=f, fill=(0, 0, 0))
d.text(((S - w) / 2, 70), title, font=f, fill=(236, 226, 208))
sub = "SOBREVIVENTES HUMANOS  ·  BUILD 42"
fs = font("RobotoCondensed-Bold.ttf", 40)
ws = d.textlength(sub, font=fs)
d.text(((S - ws) / 2, 70 + f.size * 1.25), sub, font=fs, fill=(214, 128, 60))

img.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "poster.png"))
img.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "42", "poster.png"))
os.makedirs(os.path.join(ROOT, "workshop"), exist_ok=True)
img.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "workshop", "preview.png"))
print("ok")
