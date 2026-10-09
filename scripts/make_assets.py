"""
生成硬币素材（任务 T06）。

产出三个文件到 CoinFlip/Resources/：
    sun_silver.png   日面贴图
    moon_silver.png  月面贴图
    land_silver.wav  落地撞击音效

全部由代码生成，原创图案，不涉及任何真实货币。
以后要换素材时，直接替换这三个文件即可，文件名不要改。

重新生成：python3 scripts/make_assets.py

── 版面结构（从外到内）──
    凸起外缘 → 珠圈 → 拉丁文环 → 珠圈 → 同心细纹底 → 中央图案
"""

import math
import struct
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024                 # 成品贴图边长
SS = 2                      # 先按 2 倍画再缩小，边缘才不会有锯齿
BIG = SIZE * SS
OUT = Path(__file__).resolve().parent.parent / "CoinFlip" / "Resources"

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSerifCondensed-Bold.ttf"

# 各圈的半径，用占半径的比例表示
R_RIM_OUT = 0.995           # 外缘最外沿
R_RIM_IN = 0.900            # 外缘内沿
R_BEAD_OUTER = 0.868        # 外侧珠圈
R_TEXT = 0.800              # 文字环中心线
R_BEAD_INNER = 0.726        # 内侧珠圈
R_FIELD = 0.706             # 同心细纹底的外沿

SUN_TEXT = "SOL · INVICTUS · LUX · AETERNA · MMXXVI"
MOON_TEXT = "LUNA · REGINA · SILENTII · NOCTIS · MMXXVI"


# ─────────────────────────── 画高度图的小工具 ───────────────────────────
# 先把图案画成一张"高度图"（高的地方是凸起的浮雕），
# 之后再假设一盏灯照上去，按坡度算明暗。这样出来的立体感最接近真实压铸。

def new_layer() -> Image.Image:
    return Image.new("L", (BIG, BIG), 0)


def polar(r: float, a: float) -> tuple[float, float]:
    """极坐标转画布坐标。r 是占半径的比例，a 是弧度。"""
    c = BIG / 2
    return c + c * r * math.cos(a), c + c * r * math.sin(a)


def ring(d: ImageDraw.ImageDraw, r_in: float, r_out: float, v: int):
    """画一个圆环"""
    c = BIG / 2
    d.ellipse([c - c * r_out, c - c * r_out, c + c * r_out, c + c * r_out], fill=v)
    d.ellipse([c - c * r_in, c - c * r_in, c + c * r_in, c + c * r_in], fill=0)


def beads(d: ImageDraw.ImageDraw, r: float, count: int, size: float, v: int):
    """沿一圈画一串小圆珠"""
    for i in range(count):
        a = 2 * math.pi * i / count
        x, y = polar(r, a)
        s = BIG / 2 * size
        d.ellipse([x - s, y - s, x + s, y + s], fill=v)


def circular_text(layer: Image.Image, text: str, r: float, height: float, v: int):
    """
    把文字排成一圈。每个字母都转到"头朝外"的方向，
    这是纪念币上刻字的传统排法。
    """
    px = int(BIG / 2 * height)
    font = ImageFont.truetype(FONT_PATH, px)

    # 先量出每个字母多宽，好按宽度分配角度，字距才均匀
    widths = []
    for ch in text:
        box = font.getbbox(ch)
        widths.append(max(box[2] - box[0], px * 0.33))
    spacing = px * 0.52                       # 字与字之间留的空
    total = sum(widths) + spacing * len(text)
    circumference = 2 * math.pi * (BIG / 2 * r)
    scale = circumference / total             # 正好绕满一圈

    angle = -math.pi / 2                      # 从正上方开始排
    for ch, w in zip(text, widths):
        step = (w + spacing) * scale / (BIG / 2 * r)
        a = angle + step / 2

        glyph = Image.new("L", (px * 2, px * 2), 0)
        ImageDraw.Draw(glyph).text((px, px), ch, font=font, fill=v, anchor="mm")
        # 转到头朝外：字母底边对着圆心
        glyph = glyph.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)

        x, y = polar(r, a)
        layer.paste(glyph, (int(x - px), int(y - px)), glyph)
        angle += step


# ─────────────────────────── 两面的图案 ───────────────────────────

def sun_motif(major: Image.Image, fine: Image.Image):
    """日面：中央圆盘 + 长短交错的光芒"""
    d = ImageDraw.Draw(major)
    c = BIG / 2

    # 长光芒和短光芒交替，长的更尖更细
    long_rays, short_rays = 12, 12
    for i in range(long_rays):
        a = 2 * math.pi * i / long_rays - math.pi / 2
        tip = polar(0.620, a)
        base = 0.185
        half = math.radians(4.4)
        d.polygon([polar(base, a - half), tip, polar(base, a + half)], fill=235)

    for i in range(short_rays):
        a = 2 * math.pi * (i + 0.5) / short_rays - math.pi / 2
        tip = polar(0.470, a)
        base = 0.185
        half = math.radians(3.0)
        d.polygon([polar(base, a - half), tip, polar(base, a + half)], fill=205)

    # 一圈很密的细放射线，铺在粗光芒底下，让中间不空
    fd = ImageDraw.Draw(fine)
    hair = 150
    for i in range(hair):
        a = 2 * math.pi * i / hair
        fd.line([polar(0.200, a), polar(0.600, a)], fill=255, width=max(2, int(BIG * 0.0013)))

    # 中央圆盘，边上围一圈小珠
    r_core = 0.150
    d.ellipse([c - c * r_core, c - c * r_core, c + c * r_core, c + c * r_core], fill=170)
    beads(d, r_core, 40, 0.0125, 225)

    # 圆盘内部也压上同心细纹
    fd = ImageDraw.Draw(fine)
    rr = 0.018
    while rr < r_core - 0.012:
        fd.ellipse([c - c * rr, c - c * rr, c + c * rr, c + c * rr],
                   outline=255, width=max(2, int(BIG * 0.0012)))
        rr += 0.0170


def moon_motif(major: Image.Image, fine: Image.Image):
    """月面：一弯新月 + 环形坑 + 散落的星"""
    c = BIG / 2

    # 大圆挖掉一个偏移的圆，剩下的就是月牙
    crescent = Image.new("L", (BIG, BIG), 0)
    cd = ImageDraw.Draw(crescent)
    r = 0.470
    cd.ellipse([c - c * r, c - c * r, c + c * r, c + c * r], fill=225)
    cut_r, cx, cy = r * 0.880, c + c * r * 0.395, c - c * r * 0.120
    cd.ellipse([cx - c * cut_r, cy - c * cut_r, cx + c * cut_r, cy + c * cut_r], fill=0)

    # 月面上几处环形坑，做成凹进去的
    hd = ImageDraw.Draw(crescent)
    for ox, oy, orr in [(-0.250, -0.195, 0.052), (-0.330, 0.090, 0.038),
                        (-0.175, 0.265, 0.044), (-0.085, -0.300, 0.030),
                        (-0.300, -0.030, 0.024), (-0.130, 0.055, 0.020)]:
        x, y = c + c * ox, c + c * oy
        s = c * orr
        hd.ellipse([x - s, y - s, x + s, y + s], fill=150)

    major.paste(crescent, (0, 0), crescent)

    # 星星：四角星，大小不一地散在月牙开口那侧
    d = ImageDraw.Draw(major)
    for sx, sy, ss, v in [(0.300, -0.330, 0.042, 240), (0.455, -0.090, 0.028, 225),
                          (0.250, 0.230, 0.034, 232), (0.420, 0.330, 0.020, 215),
                          (0.115, -0.470, 0.022, 220), (0.520, 0.120, 0.016, 205)]:
        x, y, s = c + c * sx, c + c * sy, c * ss
        d.polygon([(x, y - s), (x + s * 0.22, y - s * 0.22),
                   (x + s, y), (x + s * 0.22, y + s * 0.22),
                   (x, y + s), (x - s * 0.22, y + s * 0.22),
                   (x - s, y), (x - s * 0.22, y - s * 0.22)], fill=v)


# ─────────────────────────── 组装一面 ───────────────────────────

def build_face(text: str, motif) -> tuple[Image.Image, Image.Image]:
    """画出一面的高度图，再产出两张贴图：看得见的彩色图，和描述起伏的法线图"""
    major = new_layer()     # 大块浮雕：外缘、珠圈、文字、图案
    fine = new_layer()      # 细纹：底子上的同心线
    d = ImageDraw.Draw(major)
    c = BIG / 2

    # 凸起的外缘
    ring(d, R_RIM_IN, R_RIM_OUT, 215)
    ring(d, R_RIM_IN, R_RIM_IN + 0.012, 120)        # 内沿一道小台阶

    # 两道珠圈
    beads(d, R_BEAD_OUTER, 132, 0.0098, 205)
    beads(d, R_BEAD_INNER, 108, 0.0072, 190)

    # 拉丁文环
    circular_text(major, text, R_TEXT, 0.088, 225)

    # 底子上的同心细纹，从中心一直铺到文字环内侧
    fd = ImageDraw.Draw(fine)
    rr = 0.020
    while rr < R_FIELD:
        fd.ellipse([c - c * rr, c - c * rr, c + c * rr, c + c * rr],
                   outline=255, width=max(2, int(BIG * 0.0011)))
        rr += 0.0178

    # 中央主图案
    motif(major, fine)

    return light(major, fine), normal_map(major, fine)


def light(major: Image.Image, fine: Image.Image) -> Image.Image:
    """
    给高度图打光。
    灯在左上方：朝着灯的坡面提亮，背着灯的坡面压暗，平面不动。
    大块浮雕和细纹分开处理——细纹要锐利，大浮雕要圆润。
    """
    major = major.resize((SIZE, SIZE), Image.LANCZOS)
    fine = fine.resize((SIZE, SIZE), Image.LANCZOS)

    hm = np.array(major.filter(ImageFilter.GaussianBlur(2.6)), dtype=np.float32) / 255
    hf = np.array(fine.filter(ImageFilter.GaussianBlur(1.1)), dtype=np.float32) / 255

    gy, gx = np.gradient(hm)
    shade = np.clip((-gx - gy) * 2600, -118, 118)

    fy, fx = np.gradient(hf)
    shade += np.clip((-fx - fy) * 700, -20, 20)

    px = base_silver()
    px += shade[:, :, None]
    # 浮雕本身略微压暗，读起来才是金属而不是发光的
    px -= (np.array(major, dtype=np.float32) / 255)[:, :, None] * 4

    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(circular_alpha())
    return img


def normal_map(major: Image.Image, fine: Image.Image) -> Image.Image:
    """
    把高度图转成"法线图"。

    彩色贴图里的明暗是**画死的**——光从左上来，就永远是左上亮。
    硬币一翻转，这些高光跟着转，看着就像印上去的花纹，不像刻出来的。

    法线图不存颜色，存的是"这一点的表面朝哪个方向"。有了它，
    手机就能实时算出每一点该多亮——硬币转到哪，高光就跟着在哪，
    浮雕才真正"活"起来。

    这是把贴图从"印花"变成"浮雕"最便宜的一步，不用加一个三角形。
    """
    major = major.resize((SIZE, SIZE), Image.LANCZOS)
    fine = fine.resize((SIZE, SIZE), Image.LANCZOS)

    hm = np.array(major.filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float32) / 255
    hf = np.array(fine.filter(ImageFilter.GaussianBlur(0.9)), dtype=np.float32) / 255
    height = hm + hf * 0.22                     # 细纹只占一点点起伏

    gy, gx = np.gradient(height)
    strength = 96.0                             # 浮雕的"深浅"，越大越立体
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(gx)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / norm, ny / norm, nz / norm

    rgb = np.stack([nx, ny, nz], axis=-1) * 0.5 + 0.5
    img = Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(circular_alpha())
    return img


def base_silver() -> np.ndarray:
    """抛光银的底色：左上偏亮、右下偏暗，中间还有一道柔和的高光带"""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    t = (xx + yy) / (2 * SIZE)
    light_c = np.array([250, 251, 253], dtype=np.float32)
    dark_c = np.array([214, 218, 226], dtype=np.float32)
    px = light_c[None, None, :] * (1 - t)[:, :, None] + dark_c[None, None, :] * t[:, :, None]

    # 斜向扫过的一道高光，像镜面反射
    band = np.exp(-(((xx - yy) / SIZE + 0.18) ** 2) / 0.085) * 5
    return px + band[:, :, None]


def circular_alpha() -> Image.Image:
    """圆形遮罩：圆内不透明、圆外透明，四角要挖掉"""
    mask = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, BIG - 1, BIG - 1], fill=255)
    return mask.resize((SIZE, SIZE), Image.LANCZOS)


# ─────────────────────────── 环境贴图 ───────────────────────────

def make_environment():
    """
    画一张"虚拟摄影棚"。

    真金属之所以好看，是因为它**映出周围的环境**——灯箱、墙面、反光板。
    我们的场景除了黑背景什么都没有，金属就显得死板发灰。
    这张图就是给硬币造一个可以反射的世界。

    它是一张"全景展开图"：横向一圈是四周 360 度，纵向从头顶到脚下。
    手机会把它卷成一个球罩在场景外面，硬币表面映出的就是它。

    棚里布了：头顶一块大灯箱、左右两块侧灯箱、斜前方一块主灯箱，
    还有一圈很暗的地面。灯箱边缘都是柔的，这样映在硬币上才是柔和的光带，
    而不是一个个硬邦邦的亮点。
    """
    W, H = 1024, 512

    # 底色不是全黑，而是中等偏暗的灰。
    # 实测参考图里最暗处也有 90 左右，不是死黑——金属背光面映的是棚里的墙，
    # 不是虚空。底色压太黑，硬币会一半没在黑里。
    img = Image.new("L", (W, H), 96)
    d = ImageDraw.Draw(img)

    def box(az, el, w_deg, h_deg, value):
        x = (az % 360) / 360 * W
        y = (90 - el) / 180 * H
        hw, hh = w_deg / 360 * W / 2, h_deg / 180 * H / 2
        for shift in (-W, 0, W):
            d.ellipse([x + shift - hw, y - hh, x + shift + hw, y + hh], fill=value)

    # 一块占掉大半个天空的主灯箱。
    # 实测参考图有 37% 的像素落在最亮那一档，说明光源面积很大，
    # 不是几个小灯泡——所以这里铺得很开。
    box(-30, 58, 230, 132, 255)
    box(0, 90, 360, 72, 255)          # 头顶接上，连成一整片
    box(-110, 16, 96, 64, 250)        # 左侧灯箱

    # 两块暗区，用来在币面上压出深色的带子。
    # 没有暗区就全是亮的，看着就"平"。
    box(78, 30, 86, 70, 40)
    box(150, -8, 100, 60, 46)

    # 地面：暗，但留一点
    box(0, -90, 360, 66, 52)

    # 只稍微糊一下。糊过头，亮暗之间会填满中间调，
    # 币面就从"黑白分明"变成"一片灰"——这正是上一版发灰的原因。
    img = img.filter(ImageFilter.GaussianBlur(9))

    rgb = Image.merge("RGB", (img, img, img.point(lambda v: min(255, int(v * 1.04)))))
    path = OUT / "studio_env.png"
    rgb.save(path, "PNG", optimize=True)
    print(f"  {path.name}  {W}x{H}  {path.stat().st_size // 1024} KB")


# ─────────────────────────── 地面与阴影 ───────────────────────────

def radial_png(name, size, color, peak, falloff, power=2.0):
    """
    画一张"中间浓、四周化开"的圆形贴图。

    透明度按到中心的距离平滑衰减到 0，所以贴到场景里不会有任何硬边——
    这是"地面和背景自然融合、看不出地平线"的关键。
    """
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c

    alpha = np.exp(-((r / falloff) ** power)) * peak
    alpha[r > 1] = 0                                  # 圆外一律全透明
    # 贴着边缘再收一道，杜绝圆形的轮廓线
    alpha *= np.clip((1 - r) / 0.55, 0, 1) ** 1.4

    rgb = np.zeros((size, size, 3), dtype=np.uint8)
    rgb[:, :] = color
    img = Image.fromarray(rgb, "RGB").convert("RGBA")
    img.putalpha(Image.fromarray((alpha * 255).astype(np.uint8), "L"))

    path = OUT / f"{name}.png"
    img.save(path, "PNG", optimize=True)
    print(f"  {path.name}  {size}x{size}  {path.stat().st_size // 1024} KB")


def make_ground_and_shadow():
    # 地面：硬币脚下一小片微亮的地，半透明，向外化进黑背景。
    #
    # 它必须是半透明的：半透明的东西不写深度，才不会挡住穿过它的硬币。
    # 它和阴影谁先画，不靠透明度决定，由 GroundShadow 里的排序分组指定。
    radial_png("ground_fade", 512, color=(74, 76, 84),
               peak=0.95, falloff=0.34, power=1.6)

    # 阴影：纯黑，中间最浓，边缘很散，压在地面上。
    # 硬币越高，这张图会被放得越大、调得越淡，自然就"变大变散变淡"。
    radial_png("shadow_soft", 512, color=(0, 0, 0),
               peak=1.0, falloff=0.36, power=1.7)


# ─────────────────────────── 音效 ───────────────────────────

def metal_ring(partials, dur, fast, slow, slow_share, noise=0.0, grain=0.0, seed=11):
    """
    合成一声金属的响。

    关键在两点，都是从真实录音里量出来的：

    ① 几乎全是高频。参考音里 88% 的能量在 4kHz 以上。
       低频一多就"实"，听起来像敲木头或塑料，不像硬币。

    ② 两段式衰减。先很快掉一半（38 毫秒），然后拖着一条长长的余韵
       （300 毫秒才衰到十分之一）。只有快衰减就干巴巴，只有慢衰减就发闷。

    另外频率是成簇的（比如 5310/5410/5510 挤在一起），
    它们互相干涉会产生细微的颤动，这就是金属特有的那种"嗡"的质感。
    """
    rate = 44_100
    t = np.linspace(0, dur, int(rate * dur), endpoint=False)
    env = (1 - slow_share) * np.exp(-fast * t) + slow_share * np.exp(-slow * t)

    w = np.zeros_like(t)
    for freq, amp in partials:
        # 每个分音的余韵长短略有不同，听起来才不呆板
        jitter = 1 + 0.25 * ((freq % 7) / 7 - 0.5)
        w += amp * np.sin(2 * np.pi * freq * t) * env ** jitter

    rng = np.random.default_rng(seed)

    # 撞击瞬间那一下极短的噪声，给声音一个"尖"的起头
    if noise > 0:
        w += rng.normal(0, 1, t.shape) * np.exp(-1500 * t) * noise

    # 颗粒感：跟着余韵一起慢慢消失的高频沙沙声。
    # 真金属的响声不是纯净的正弦，表面的不规则会带出这层细碎的毛刺，
    # 少了它就显得太"电子"。先做个简单的高通，把低频隆隆去掉。
    if grain > 0:
        nz = rng.normal(0, 1, t.shape)
        nz = np.diff(nz, prepend=nz[0])
        w += nz * env * grain

    w *= np.clip(t / 0.0008, 0, 1)            # 开头淡入，避免爆音
    w *= np.clip((dur - t) / 0.02, 0, 1)      # 结尾淡出，避免断得生硬
    return w / np.max(np.abs(w))


def write_wav(name, w, gain=0.85):
    pcm = (w * gain * 32767).astype(np.int16)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(44_100)
        f.writeframes(b"".join(struct.pack("<h", s) for s in pcm))
    print(f"  {path.name}  {len(w) / 44_100:.2f} 秒  {path.stat().st_size // 1024} KB")


def make_sounds():
    # 抛起：手指弹开硬币的那一声。
    # 要亮、要长——硬币升到最高点时它还在响，这是"仪式"的起手式。
    toss = metal_ring(
        partials=[
            (5_246, 1.00), (5_340, 0.88), (5_443, 0.76), (5_556, 0.68),
            (5_693, 0.56), (6_880, 0.52), (7_640, 0.40), (9_320, 0.40),
            (11_400, 0.28), (13_700, 0.20), (16_200, 0.12),
            (4_750, 0.34),
            (2_180, 0.05),                              # 中频只留一丝，多了就闷
        ],
        dur=1.7, fast=22, slow=2.3, slow_share=0.46, noise=0.06, grain=0.17,
    )
    write_wav("toss_silver", toss, gain=0.60)

    # 落地：比抛起短，但也要带得住余韵，不能是"啪"的一下死响
    land = metal_ring(
        partials=[
            (5_310, 0.92), (5_410, 1.00), (5_510, 0.82), (5_600, 0.70),
            (6_290, 0.76), (6_380, 0.64), (6_900, 0.58),
            (9_350, 0.46), (11_840, 0.34), (11_940, 0.28),
            (13_900, 0.22), (16_500, 0.13),
            (190, 0.05),                                  # 平面的一点回应，很轻
        ],
        dur=0.95, fast=36, slow=5.0, slow_share=0.30, noise=0.11, grain=0.21, seed=5,
    )
    write_wav("land_silver", land, gain=0.88)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    print("生成贴图：")
    for name, text, motif in [("sun_silver", SUN_TEXT, sun_motif),
                              ("moon_silver", MOON_TEXT, moon_motif)]:
        color, normal = build_face(text, motif)
        for suffix, img in [("", color), ("_normal", normal)]:
            path = OUT / f"{name}{suffix}.png"
            img.save(path, "PNG", optimize=True)
            print(f"  {path.name}  {img.size[0]}x{img.size[1]}  {path.stat().st_size // 1024} KB")
    print("生成环境贴图：")
    make_environment()
    print("生成地面与阴影：")
    make_ground_and_shadow()
    print("生成音效：")
    make_sounds()
    print("完成。")
