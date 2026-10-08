"""
生成最小可用版的占位素材（任务 T06）。

产出三个文件到 CoinFlip/Resources/：
    sun_silver.png   日面贴图
    moon_silver.png  月面贴图
    land_silver.wav  落地撞击音效

全部由代码生成，原创图案，不涉及任何真实货币或他人作品。
以后要换精致素材时，直接替换这三个文件即可，文件名不要改。

重新生成：python3 scripts/make_assets.py
"""

import math
import struct
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024                      # 贴图边长（像素）
OUT = Path(__file__).resolve().parent.parent / "CoinFlip" / "Resources"

# 银币配色：偏冷的灰白，模拟抛光银面
SILVER_LIGHT = (232, 234, 238)
SILVER_MID = (198, 202, 209)
SILVER_DARK = (150, 155, 164)
SILVER_SHADOW = (118, 123, 132)


def silver_base() -> Image.Image:
    """画一个带斜向渐变的银色圆盘，左上偏亮、右下偏暗，看起来有金属光泽。"""
    img = Image.new("RGB", (SIZE, SIZE), SILVER_MID)
    px = np.array(img, dtype=np.float32)

    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    # 沿左上到右下的方向做渐变
    t = ((xx + yy) / (2 * SIZE)).astype(np.float32)
    light = np.array(SILVER_LIGHT, dtype=np.float32)
    dark = np.array(SILVER_DARK, dtype=np.float32)
    px = light[None, None, :] * (1 - t)[:, :, None] + dark[None, None, :] * t[:, :, None]

    img = Image.fromarray(px.astype(np.uint8))

    d = ImageDraw.Draw(img)
    c, r = SIZE / 2, SIZE / 2

    # 外圈：一圈细齿边，模仿真实硬币的滚花
    teeth = 120
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth
        a1 = a0 + math.pi / teeth
        shade = SILVER_SHADOW if i % 2 == 0 else SILVER_LIGHT
        d.arc([2, 2, SIZE - 3, SIZE - 3],
              math.degrees(a0), math.degrees(a1), fill=shade, width=26)

    # 内圈：一道凹进去的环线，把图案框住
    inset = SIZE * 0.118
    d.ellipse([inset, inset, SIZE - inset, SIZE - inset],
              outline=SILVER_SHADOW, width=5)
    d.ellipse([inset + 6, inset + 6, SIZE - inset - 6, SIZE - inset - 6],
              outline=SILVER_LIGHT, width=3)

    return img


def engrave(base: Image.Image, draw_motif, relief: float = 1.0) -> Image.Image:
    """
    把图案"刻"进银面。

    做法接近真实的浮雕打光：先把图案画成一张"高度图"（图案处高、底面低），
    模糊出坡度，再假设有一盏灯从左上方照过来——
    朝向灯的坡面提亮，背对灯的坡面压暗，中间的平面不动。
    这样细如发丝的光芒也能看出厚度，而不是糊成两个重影。
    """
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw_motif(ImageDraw.Draw(mask), 255)

    # 模糊出坡度。半径越大，浮雕的边缘越圆润
    height = np.array(mask.filter(ImageFilter.GaussianBlur(7)), dtype=np.float32) / 255.0

    # 坡度：相邻像素的高度差
    gy, gx = np.gradient(height)
    # 灯从左上方来，所以左上朝向的坡面受光
    lighting = (-gx - gy) * 1400.0 * relief
    lighting = np.clip(lighting, -70, 70)

    px = np.array(base, dtype=np.float32)
    px += lighting[:, :, None]
    # 图案本身略微压暗一点点，读起来是"刻进去"而不是"贴上去"
    px -= (np.array(mask, dtype=np.float32) / 255.0)[:, :, None] * 10.0

    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))


def sun_motif(d: ImageDraw.ImageDraw, v: int):
    """日面：中心圆盘 + 十二道放射的锥形光芒。"""
    c = SIZE / 2
    core = SIZE * 0.142
    d.ellipse([c - core, c - core, c + core, c + core], fill=v)

    rays = 12
    inner = SIZE * 0.196
    outer = SIZE * 0.355
    half = math.radians(6.2)          # 光芒根部的张角
    for i in range(rays):
        a = 2 * math.pi * i / rays - math.pi / 2
        tip = (c + outer * math.cos(a), c + outer * math.sin(a))
        p1 = (c + inner * math.cos(a - half), c + inner * math.sin(a - half))
        p2 = (c + inner * math.cos(a + half), c + inner * math.sin(a + half))
        d.polygon([p1, tip, p2], fill=v)


def moon_motif(d: ImageDraw.ImageDraw, v: int):
    """月面：一弯新月 + 三颗小星。"""
    c = SIZE / 2
    r = SIZE * 0.288

    # 大圆挖掉一个偏移的圆，剩下的就是月牙
    full = Image.new("L", (SIZE, SIZE), 0)
    fd = ImageDraw.Draw(full)
    fd.ellipse([c - r, c - r, c + r, c + r], fill=v)
    cut_r = r * 0.9
    cut_x = c + r * 0.40
    cut_y = c - r * 0.14
    fd.ellipse([cut_x - cut_r, cut_y - cut_r, cut_x + cut_r, cut_y + cut_r], fill=0)

    # 把算好的月牙形状盖回调用方的画布上
    d.bitmap((0, 0), full, fill=v)

    # 三颗四角星，疏密有致地点在月牙开口那侧
    for sx, sy, ss in [(0.700, 0.300, 0.030),
                       (0.775, 0.470, 0.020),
                       (0.655, 0.545, 0.014)]:
        x, y, s = SIZE * sx, SIZE * sy, SIZE * ss
        d.polygon([(x, y - s), (x + s * 0.32, y - s * 0.32),
                   (x + s, y), (x + s * 0.32, y + s * 0.32),
                   (x, y + s), (x - s * 0.32, y + s * 0.32),
                   (x - s, y), (x - s * 0.32, y - s * 0.32)], fill=v)


def make_textures():
    for name, motif in [("sun_silver", sun_motif), ("moon_silver", moon_motif)]:
        img = engrave(silver_base(), motif)
        path = OUT / f"{name}.png"
        img.save(path, "PNG", optimize=True)
        print(f"  {path.name}  {img.size[0]}x{img.size[1]}  {path.stat().st_size // 1024} KB")


def make_sound():
    """
    合成一声金属落地的脆响。
    原理：几个互不成整数倍的频率叠在一起（金属不像琴弦那样和谐，所以听着"当"而不是"哆"），
    各自以不同速度衰减，前面再加一点点噪声当作撞击的瞬间。
    """
    rate = 44_100
    dur = 0.42
    t = np.linspace(0, dur, int(rate * dur), endpoint=False)

    # 频率、响度、衰减快慢
    partials = [
        (1_850, 1.00, 11.0),
        (2_790, 0.62, 13.5),
        (4_120, 0.40, 17.0),
        (5_630, 0.24, 21.0),
        (7_410, 0.13, 27.0),
        (  930, 0.30,  9.0),
    ]
    wave_data = np.zeros_like(t)
    for freq, amp, decay in partials:
        wave_data += amp * np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)

    # 撞击瞬间的那一下"噗"
    rng = np.random.default_rng(7)
    click = rng.normal(0, 1, t.shape) * np.exp(-420 * t) * 0.55
    wave_data += click

    # 开头 2 毫秒淡入，避免爆音
    fade = np.clip(t / 0.002, 0, 1)
    wave_data *= fade

    wave_data /= np.max(np.abs(wave_data))
    wave_data *= 0.82
    pcm = (wave_data * 32767).astype(np.int16)

    path = OUT / "land_silver.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(b"".join(struct.pack("<h", s) for s in pcm))
    print(f"  {path.name}  {dur:.2f} 秒  {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    print("生成贴图：")
    make_textures()
    print("生成音效：")
    make_sound()
    print("完成。")
