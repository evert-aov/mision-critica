#!/usr/bin/env python3
"""
Motion Graphics Pitch Video Generator for Misión Crítica (NASA Space Apps Challenge).
Renders a 54-second 1920x1080 @ 30fps H.264 MP4 with synchronized stereo synth + game SFX.
"""

from __future__ import annotations

import math
import multiprocessing as mp
import os
import random
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT_DIR = Path(__file__).resolve().parent.parent
PITCH_DIR = Path(__file__).resolve().parent
ASSETS_DIR = ROOT_DIR / "assets"
OUTPUT_MP4 = PITCH_DIR / "mision_critica_nasa_pitch.mp4"
TEMP_AUDIO_WAV = PITCH_DIR / "pitch_audio.wav"

W, H = 1920, 1080
FPS = 30
DURATION_S = 54.0
TOTAL_FRAMES = int(DURATION_S * FPS)

# Aerospace Motion-Graphics Palette
C_BG = (6, 10, 20)
C_BG_ALT = (10, 17, 32)
C_PANEL = (13, 22, 40, 232)
C_PANEL_LIGHT = (19, 32, 58, 240)
C_BORDER = (44, 82, 130, 255)
C_WHITE = (238, 246, 255)
C_MUTED = (145, 168, 200)
C_CYAN = (56, 217, 255)
C_GREEN = (61, 245, 167)
C_AMBER = (255, 184, 77)
C_RED = (255, 92, 108)
C_MARS = (232, 106, 74)
C_VIOLET = (162, 128, 255)

# Global worker cache initialized per process
_CTX: dict = {}


# ---------------------------------------------------------------------------
# Easing & Math Helpers
# ---------------------------------------------------------------------------

def clamp01(x: float) -> float:
    return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x)


def ease_out_cubic(x: float) -> float:
    t = clamp01(x)
    return 1.0 - (1.0 - t) ** 3


def ease_in_out_cubic(x: float) -> float:
    t = clamp01(x)
    return 4.0 * t * t * t if t < 0.5 else 1.0 - ((-2.0 * t + 2.0) ** 3) / 2.0


def ease_out_back(x: float) -> float:
    t = clamp01(x)
    c1 = 1.70158
    c3 = c1 + 1.0
    return 1.0 + c3 * ((t - 1.0) ** 3) + c1 * ((t - 1.0) ** 2)


def win(t: float, t0: float, duration: float) -> float:
    if duration <= 0.0:
        return 1.0 if t >= t0 else 0.0
    return clamp01((t - t0) / duration)


def lerp(a: float, b: float, u: float) -> float:
    return a + (b - a) * u


def lerp_color(c1: tuple[int, ...], c2: tuple[int, ...], u: float) -> tuple[int, ...]:
    k = clamp01(u)
    rgb = tuple(int(c1[i] + (c2[i] - c1[i]) * k) for i in range(3))
    if len(c1) == 4 or len(c2) == 4:
        a1 = c1[3] if len(c1) == 4 else 255
        a2 = c2[3] if len(c2) == 4 else 255
        return rgb + (int(a1 + (a2 - a1) * k),)
    return rgb


def quad_bezier(p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float], u: float) -> tuple[float, float]:
    iu = 1.0 - u
    return (
        iu * iu * p0[0] + 2.0 * iu * u * p1[0] + u * u * p2[0],
        iu * iu * p0[1] + 2.0 * iu * u * p1[1] + u * u * p2[1],
    )


# ---------------------------------------------------------------------------
# Asset Pre-Rendering (Once at Startup / Per Worker)
# ---------------------------------------------------------------------------

def _find_font(candidates: list[str], fallback_family: str) -> str | None:
    for path in candidates:
        if os.path.exists(path):
            return path
    try:
        out = subprocess.check_output(["fc-match", "-f", "%{file}", fallback_family], text=True).strip()
        if out and os.path.exists(out):
            return out
    except Exception:
        pass
    return None


def _load_fonts() -> dict[str, ImageFont.FreeTypeFont]:
    mono_bold_path = _find_font(
        [
            "/nix/store/vhrgr22c955gv41yb6nhxq4d5z9yw238-nerd-fonts-jetbrains-mono-3.5.0+2.304/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFontPropo-Bold.ttf",
        ],
        "JetBrainsMono:bold",
    )
    mono_med_path = _find_font(
        [
            "/nix/store/vhrgr22c955gv41yb6nhxq4d5z9yw238-nerd-fonts-jetbrains-mono-3.5.0+2.304/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFontMono-Medium.ttf",
        ],
        "JetBrainsMono:medium",
    )
    sans_bold_path = _find_font(
        [
            "/nix/store/jdq08clri1ps0dv4c3zvkbm9alnfzv56-dejavu-fonts-2.37/share/fonts/truetype/DejaVuSans-Bold.ttf",
        ],
        "DejaVu Sans:bold",
    )
    sans_reg_path = _find_font(
        [
            "/nix/store/jdq08clri1ps0dv4c3zvkbm9alnfzv56-dejavu-fonts-2.37/share/fonts/truetype/DejaVuSans.ttf",
        ],
        "DejaVu Sans",
    )

    def make(p: str | None, sz: int):
        return ImageFont.truetype(p, sz) if p else ImageFont.load_default()

    return {
        "hero": make(mono_bold_path or sans_bold_path, 112),
        "h1": make(mono_bold_path or sans_bold_path, 54),
        "h2": make(mono_bold_path or sans_bold_path, 34),
        "h3": make(sans_bold_path or mono_bold_path, 26),
        "body": make(sans_reg_path or mono_med_path, 22),
        "body_b": make(sans_bold_path or mono_bold_path, 22),
        "mono": make(mono_med_path or sans_reg_path, 21),
        "mono_sm": make(mono_med_path or sans_reg_path, 17),
        "mono_lg": make(mono_bold_path or sans_bold_path, 28),
        "badge": make(mono_bold_path or sans_bold_path, 18),
        "stat": make(mono_bold_path or sans_bold_path, 64),
    }


def _make_planet_globe(kind: str, radius: int) -> Image.Image:
    """Renders a crisp lit planet sphere with surface bands/craters and atmospheric glow."""
    pad = int(radius * 0.35)
    size = (radius + pad) * 2
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size // 2
    lx, ly, lz = -0.62, -0.42, 0.66

    palettes = {
        "earth": ((24, 92, 188), (46, 168, 112), (225, 240, 255), (72, 175, 255)),
        "mars": ((176, 68, 42), (218, 116, 68), (245, 220, 200), (255, 130, 86)),
        "moon": ((125, 132, 146), (170, 178, 192), (210, 216, 226), (180, 195, 220)),
        "venus": ((205, 164, 92), (235, 198, 128), (252, 232, 176), (255, 206, 115)),
        "sun": ((255, 148, 36), (255, 214, 72), (255, 248, 205), (255, 190, 64)),
    }
    c_a, c_b, c_hi, c_glow = palettes.get(kind, palettes["earth"])

    r2 = float(radius * radius)
    outer_r = radius + pad
    for y in range(size):
        dy = y - cy
        for x in range(size):
            dx = x - cx
            d2 = dx * dx + dy * dy
            d = math.sqrt(d2)
            if d <= radius:
                nx = dx / radius
                ny = dy / radius
                nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                # Deterministic pseudo-procedural surface pattern
                u = math.atan2(nx, nz)
                v = math.asin(max(-1.0, min(1.0, ny)))
                pat = (
                    math.sin(u * 4.2 + math.cos(v * 3.1) * 1.4)
                    + 0.5 * math.cos(v * 7.5 + u * 2.1)
                    + 0.35 * math.sin((u + v) * 11.0)
                )
                if kind == "earth":
                    if abs(ny) > 0.84 - 0.06 * math.sin(u * 5.0):
                        base = c_hi
                    elif pat > 0.25:
                        base = c_b
                    else:
                        base = c_a
                    if abs(math.sin(v * 9.0 + u * 3.0) + math.cos(u * 6.0)) > 1.38:
                        base = lerp_color(base, (245, 250, 255), 0.7)
                elif kind == "mars":
                    if abs(ny) > 0.88:
                        base = c_hi
                    elif pat > 0.1:
                        base = c_b
                    else:
                        base = c_a
                elif kind == "sun":
                    base = lerp_color(c_a, c_b, clamp01(0.5 + 0.45 * pat))
                    if nz > 0.6:
                        base = lerp_color(base, c_hi, (nz - 0.6) * 1.8)
                else:
                    base = lerp_color(c_a, c_b, clamp01(0.5 + 0.5 * pat))

                if kind == "sun":
                    lit = 1.0
                else:
                    ndotl = max(0.0, nx * lx + ny * ly + nz * lz)
                    # Subtle crisp step + smooth shade
                    lit = 0.14 + 0.86 * (0.65 * ndotl + 0.35 * math.floor(ndotl * 5.0) / 5.0)
                    rim = max(0.0, 1.0 - nz) ** 2.6 * max(0.15, ndotl + 0.25)
                    base = lerp_color(base, c_glow, min(0.55, rim * 0.65))
                alpha = 255 if d <= radius - 1.2 else int(clamp01(radius - d + 0.8) * 255)
                px[x, y] = (
                    min(255, int(base[0] * lit)),
                    min(255, int(base[1] * lit)),
                    min(255, int(base[2] * lit)),
                    alpha,
                )
            elif d < outer_r:
                fall = (1.0 - (d - radius) / pad) ** 2.6
                ga = int((115 if kind == "sun" else 65) * fall)
                if ga > 1:
                    px[x, y] = (c_glow[0], c_glow[1], c_glow[2], ga)
    return img


def _load_pixel_sprite(name: str, scale: int) -> Image.Image:
    p = ASSETS_DIR / "sprites" / "parts" / name
    im = Image.open(p).convert("RGBA")
    return im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)


def _make_base_backdrop() -> Image.Image:
    bg = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / H
        col = lerp_color((5, 9, 20), (11, 18, 36), t)
        draw.line([(0, y), (W, y)], fill=col)
    # Soft nebula blooms
    neb = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    nd = ImageDraw.Draw(neb)
    nd.ellipse([1120, -180, 2120, 740], fill=(20, 72, 130, 38))
    nd.ellipse([-260, 420, 760, 1280], fill=(95, 36, 56, 28))
    nd.ellipse([540, 240, 1460, 960], fill=(18, 65, 92, 24))
    neb = neb.filter(ImageFilter.GaussianBlur(90))
    bg_rgba = Image.alpha_composite(bg.convert("RGBA"), neb)
    # Subtle static grid
    gd = ImageDraw.Draw(bg_rgba)
    for gx in range(0, W, 120):
        gd.line([(gx, 0), (gx, H)], fill=(28, 48, 82, 26), width=1)
    for gy in range(0, H, 120):
        gd.line([(0, gy), (W, gy)], fill=(28, 48, 82, 26), width=1)
    return bg_rgba.convert("RGB")


def _build_stars() -> list[tuple[float, float, float, float, tuple[int, int, int]]]:
    rng = random.Random(2026)
    stars = []
    cols = [(235, 244, 255), (175, 224, 255), (255, 226, 185), (195, 205, 245)]
    for _ in range(150):
        stars.append((
            rng.uniform(0, W),
            rng.uniform(0, H),
            rng.uniform(1.0, 2.8),
            rng.uniform(8.0, 34.0),
            rng.choice(cols),
        ))
    return stars


def _init_worker() -> None:
    _CTX["fonts"] = _load_fonts()
    _CTX["backdrop"] = _make_base_backdrop()
    _CTX["stars"] = _build_stars()
    _CTX["planets"] = {
        "earth_lg": _make_planet_globe("earth", 175),
        "earth_md": _make_planet_globe("earth", 72),
        "earth_sm": _make_planet_globe("earth", 42),
        "mars_lg": _make_planet_globe("mars", 160),
        "mars_md": _make_planet_globe("mars", 78),
        "mars_sm": _make_planet_globe("mars", 42),
        "moon_sm": _make_planet_globe("moon", 42),
        "venus_sm": _make_planet_globe("venus", 34),
        "sun_sm": _make_planet_globe("sun", 42),
    }
    _CTX["sprites"] = {
        "bus": _load_pixel_sprite("probe_bus.png", 4),
        "ion": _load_pixel_sprite("part_eng_ion.png", 3),
        "ka": _load_pixel_sprite("part_comm_kaband.png", 3),
        "radar": _load_pixel_sprite("part_inst_radar.png", 3),
        "solar": _load_pixel_sprite("part_solar_wing.png", 3),
        "lv_heavy": _load_pixel_sprite("lv_heavy.png", 3),
        "cam": _load_pixel_sprite("part_inst_cam.png", 3),
        "spec": _load_pixel_sprite("part_inst_spec.png", 3),
    }


# ---------------------------------------------------------------------------
# Drawing Primitives
# ---------------------------------------------------------------------------

def _paste_center(canvas: Image.Image, sprite: Image.Image, cx: float, cy: float) -> None:
    x = int(cx - sprite.width * 0.5)
    y = int(cy - sprite.height * 0.5)
    canvas.alpha_composite(sprite, dest=(x, y))


def _draw_rounded_panel(
    draw: ImageDraw.ImageDraw,
    rect: tuple[float, float, float, float],
    fill=C_PANEL,
    outline=C_BORDER,
    radius: int = 16,
    width: int = 2,
) -> None:
    x0, y0, x1, y1 = [int(round(v)) for v in rect]
    if x1 <= x0 + 4 or y1 <= y0 + 4:
        return
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)


def _draw_glow_line(
    overlay: Image.Image,
    pts: list[tuple[float, float]],
    color: tuple[int, int, int],
    width: int = 4,
    alpha: int = 230,
) -> None:
    if len(pts) < 2:
        return
    d = ImageDraw.Draw(overlay)
    d.line(pts, fill=(color[0], color[1], color[2], max(25, alpha // 5)), width=width + 8, joint="curve")
    d.line(pts, fill=(color[0], color[1], color[2], alpha), width=width, joint="curve")


def _draw_probe_vector(draw: ImageDraw.ImageDraw, cx: float, cy: float, angle_rad: float, scale: float = 1.0, firing: bool = True) -> None:
    ca, sa = math.cos(angle_rad), math.sin(angle_rad)

    def rot(px: float, py: float) -> tuple[float, float]:
        return (cx + (px * ca - py * sa) * scale, cy + (px * sa + py * ca) * scale)

    # Solar wings
    for side in (-1.0, 1.0):
        pts = [rot(-6, side * 12), rot(6, side * 12), rot(6, side * 38), rot(-6, side * 38)]
        draw.polygon(pts, fill=(38, 128, 224), outline=(145, 220, 255))
    # Bus octagon
    bus = [rot(-12, -10), rot(12, -10), rot(15, 0), rot(12, 10), rot(-12, 10), rot(-15, 0)]
    draw.polygon(bus, fill=(235, 185, 68), outline=(255, 240, 175))
    # HGA Dish
    dish = [rot(14, -9), rot(22, -13), rot(22, 13), rot(14, 9)]
    draw.polygon(dish, fill=(210, 228, 246), outline=C_CYAN)
    if firing:
        plume = [rot(-15, -5), rot(-42, 0), rot(-15, 5)]
        draw.polygon(plume, fill=(80, 225, 255, 220))
        inner = [rot(-15, -2.5), rot(-30, 0), rot(-15, 2.5)]
        draw.polygon(inner, fill=(235, 252, 255, 255))


def _draw_stars(canvas: Image.Image, t: float) -> None:
    d = ImageDraw.Draw(canvas)
    for sx, sy, sz, spd, col in _CTX["stars"]:
        px = (sx - t * spd) % W
        tw = 0.65 + 0.35 * math.sin(t * 2.4 + sx * 0.05)
        alpha = int(175 * tw)
        r = sz
        d.ellipse([px - r, sy - r, px + r, sy + r], fill=(col[0], col[1], col[2], alpha))


def _draw_hud_chrome(canvas: Image.Image, t: float, slide_idx: int, slide_tag: str) -> None:
    d = ImageDraw.Draw(canvas)
    fonts = _CTX["fonts"]
    # Top bar
    d.line([(64, 56), (W - 64, 56)], fill=(45, 86, 138, 140), width=1)
    d.ellipse([64, 29, 76, 41], fill=C_GREEN)
    d.text((88, 23), f"NASA SPACE APPS CHALLENGE  //  {slide_tag}", font=fonts["mono_sm"], fill=C_CYAN)
    right_txt = f"MISIÓN CRÍTICA  |  {slide_idx:02d} / 06  |  T+{t:04.1f}s"
    rw = d.textlength(right_txt, font=fonts["mono_sm"])
    d.text((W - 64 - rw, 23), right_txt, font=fonts["mono_sm"], fill=C_MUTED)

    # Bottom progress track
    d.rectangle([64, H - 28, W - 64, H - 24], fill=(24, 40, 72, 200))
    prog = clamp01(t / DURATION_S)
    d.rectangle([64, H - 28, int(64 + (W - 128) * prog), H - 24], fill=C_CYAN)


def _draw_scene_header(draw: ImageDraw.ImageDraw, lt: float, kicker: str, title: str, subtitle: str) -> None:
    fonts = _CTX["fonts"]
    u1 = ease_out_cubic(win(lt, 0.05, 0.45))
    u2 = ease_out_cubic(win(lt, 0.18, 0.50))
    y_off1 = int((1.0 - u1) * 28)
    y_off2 = int((1.0 - u2) * 32)
    alpha1 = int(255 * u1)
    alpha2 = int(255 * u2)
    draw.text((76, 78 + y_off1), kicker, font=fonts["mono"], fill=(C_AMBER[0], C_AMBER[1], C_AMBER[2], alpha1))
    draw.text((76, 108 + y_off1), title, font=fonts["h1"], fill=(C_WHITE[0], C_WHITE[1], C_WHITE[2], alpha1))
    draw.text((76, 174 + y_off2), subtitle, font=fonts["body"], fill=(C_MUTED[0], C_MUTED[1], C_MUTED[2], alpha2))
    bar_w = int(340 * ease_out_cubic(win(lt, 0.25, 0.55)))
    draw.rectangle([76, 212, 76 + bar_w, 216], fill=(C_CYAN[0], C_CYAN[1], C_CYAN[2], alpha2))


# ---------------------------------------------------------------------------
# The 6 Motion-Graphics Scenes
# ---------------------------------------------------------------------------

def _render_scene_1(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """0.0 - 7.5s: Hero Title, Orbital Sweep & Spacecraft Launch Hook."""
    fonts = _CTX["fonts"]
    # Giant curved orbital rings
    u_orb = ease_out_cubic(win(lt, 0.0, 1.4))
    earth = _CTX["planets"]["earth_lg"]
    earth_x = lerp(1640, 1480, ease_out_cubic(win(lt, 0.0, 2.2)))
    earth_y = lerp(890, 740, ease_out_cubic(win(lt, 0.0, 2.2)))

    # Transfer arc cleanly arching from Earth to Mars on the right showcase half
    pts = []
    steps = max(2, int(60 * u_orb))
    p0, p1, p2 = (1480, 740), (1340, 390), (1690, 260)
    for i in range(steps + 1):
        pts.append(quad_bezier(p0, p1, p2, i / 60.0))
    _draw_glow_line(canvas, pts, C_AMBER, width=4, alpha=210)
    _paste_center(canvas, earth, earth_x, earth_y)

    mars = _CTX["planets"]["mars_sm"]
    _paste_center(canvas, mars, 1690, 260)

    # Flying probe along trajectory
    probe_u = clamp01(0.08 + (lt / 7.5) * 0.80)
    px, py = quad_bezier(p0, p1, p2, probe_u)
    nx, ny = quad_bezier(p0, p1, p2, min(1.0, probe_u + 0.02))
    ang = math.atan2(ny - py, nx - px)
    _draw_probe_vector(draw, px, py, ang, scale=1.55, firing=True)

    # Tag pill
    u_tag = ease_out_back(win(lt, 0.3, 0.55))
    pill_y = int(205 + (1.0 - u_tag) * 30)
    _draw_rounded_panel(draw, (80, pill_y, 700, pill_y + 46), fill=(16, 46, 78, 230), outline=C_CYAN, radius=22)
    draw.text((104, pill_y + 11), "NASA SPACE APPS  ·  SPACE MISSION DESIGN GAME", font=fonts["mono_sm"], fill=C_CYAN)

    # Hero title kinetic slam
    u_tit = ease_out_cubic(win(lt, 0.55, 0.7))
    tx = int(80 - (1.0 - u_tit) * 90)
    draw.text((tx, 275), "MISIÓN CRÍTICA", font=fonts["hero"], fill=(C_WHITE[0], C_WHITE[1], C_WHITE[2], int(255 * u_tit)))
    line_w = int(760 * ease_out_cubic(win(lt, 1.0, 0.65)))
    draw.rectangle([80, 412, 80 + line_w, 418], fill=C_GREEN)

    # Subtitle & Metrics pills
    u_sub = ease_out_cubic(win(lt, 1.25, 0.6))
    sy = int(445 + (1.0 - u_sub) * 24)
    draw.text((80, sy), "Simulador de ingeniería espacial 2.5D + vista interna en Godot 4.7", font=fonts["h2"], fill=(C_CYAN[0], C_CYAN[1], C_CYAN[2], int(255 * u_sub)))
    draw.text((80, sy + 52), "Equilibra masa, energía, radio, presupuesto y mecánica orbital con marco real NASA.", font=fonts["body"], fill=(C_MUTED[0], C_MUTED[1], C_MUTED[2], int(255 * u_sub)))

    badges = [
        ("9 EXIGENCIAS", "Ingeniería contrapuesta", C_CYAN, 2.0),
        ("CML 1–5 + GMAT", "Estándares NASA / JPL", C_GREEN, 2.3),
        ("EXT 2.5D + INT", "Cabinas por modelo", C_AMBER, 2.6),
    ]
    for idx, (top_t, bot_t, col, t_start) in enumerate(badges):
        ub = ease_out_back(win(lt, t_start, 0.5))
        if ub <= 0.01:
            continue
        bx = 80 + idx * 310
        by = int(600 + (1.0 - ub) * 40)
        _draw_rounded_panel(draw, (bx, by, bx + 286, by + 106), fill=C_PANEL, outline=col, radius=14)
        draw.text((bx + 20, by + 18), top_t, font=fonts["mono_lg"], fill=col)
        draw.text((bx + 20, by + 60), bot_t, font=fonts["mono_sm"], fill=C_WHITE)


def _render_scene_2(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """7.5 - 17.0s: The Problem — 9 Competing Spaceflight Engineering Demands."""
    fonts = _CTX["fonts"]
    _draw_scene_header(
        draw,
        lt,
        "01 / EL PROBLEMA DE DISEÑO ESPACIAL",
        "9 Exigencias Contrapuestas en Tiempo Real",
        "Mejorar un subsistema impacta de inmediato masa, Δv, energía, cofia y comunicaciones.",
    )

    items = [
        ("01 OBJETIVOS", "Ciencia mínima + sensores *", C_GREEN, "cam"),
        ("02 ARQUITECTURA", "Bus octogonal y ranuras cofia", C_CYAN, "bus"),
        ("03 INSTRUMENTOS", "pts vs kg vs W vs MB datos", C_AMBER, "radar"),
        ("04 LANZADORES", "Vega-C / Ariane-62 / Vulcan-H", C_CYAN, "lv_heavy"),
        ("05 PRESUPUESTO", "Lanzador + Bus + Carga útil", C_GREEN, "spec"),
        ("06 ENERGÍA 1/d²", "Sol al 43% en Marte + eclipses", C_AMBER, "solar"),
        ("07 TSIOLKOVSKI", "Δv = Isp·g0·ln(m0/mf) y TWR", C_RED, "ion"),
        ("08 RADIO 1/d²", "S / Banda-X / Ka-Band kbps", C_CYAN, "ka"),
        ("09 ORBITAL", "TCM · Honda · Inserción 180°", C_VIOLET, None),
    ]

    for i, (head, desc, col, sp_key) in enumerate(items):
        col_i = i % 3
        row_i = i // 3
        u = ease_out_back(win(lt, 0.55 + i * 0.24, 0.48))
        if u <= 0.01:
            continue
        x0 = 76 + col_i * 596
        y0 = int(244 + row_i * 194 + (1.0 - u) * 35)
        w, h = 572, 168
        pulse = 0.5 + 0.5 * math.sin(lt * 3.0 - i * 0.7)
        outline_c = lerp_color(C_BORDER, col, 0.55 + 0.45 * pulse)
        _draw_rounded_panel(draw, (x0, y0, x0 + w, y0 + h), fill=C_PANEL, outline=outline_c, radius=16)
        draw.rectangle([x0 + 18, y0 + 22, x0 + 24, y0 + h - 22], fill=col)
        if sp_key and sp_key in _CTX["sprites"]:
            sp = _CTX["sprites"][sp_key]
            _paste_center(canvas, sp, x0 + 66, y0 + 84)
            tx = x0 + 114
        else:
            tx = x0 + 42
        draw.text((tx, y0 + 30), head, font=fonts["h3"], fill=col)
        draw.text((tx, y0 + 74), desc, font=fonts["body"], fill=C_WHITE)
        bar_fill = int((w - (tx - x0) - 34) * clamp01((u * (0.62 + 0.04 * i))))
        draw.rectangle([tx, y0 + 124, w + x0 - 34, y0 + 132], fill=(24, 40, 68))
        draw.rectangle([tx, y0 + 124, tx + bar_fill, y0 + 132], fill=col)

    # Bottom trade-off ticker
    ut = ease_out_cubic(win(lt, 3.2, 0.7))
    if ut > 0.02:
        by = int(848 + (1.0 - ut) * 30)
        _draw_rounded_panel(draw, (76, by, W - 76, by + 132), fill=(14, 28, 52, 240), outline=C_AMBER, radius=16)
        draw.text((104, by + 18), "EJEMPLO EN VIVO // INSTALAR RADAR SAR (+350 pts):", font=fonts["mono_lg"], fill=C_AMBER)
        sweep = ease_in_out_cubic(win(lt, 3.6, 2.2))
        dv_val = int(lerp(3620, 3410, sweep))
        pwr_val = int(lerp(36, 4, sweep))
        mb_val = int(lerp(54, 144, sweep))
        draw.text(
            (104, by + 68),
            f"+42 kg masa  ->  Δv cae a {dv_val} m/s    |    +32 W consumo  ->  Margen +{pwr_val} W    |    Descarga sube a {mb_val} MB",
            font=fonts["mono"],
            fill=C_WHITE,
        )


def _render_scene_3(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """17.0 - 27.5s: Official NASA Integration — CML 1-5, SMD, CubeSat 101 & GMAT R2026a."""
    fonts = _CTX["fonts"]
    _draw_scene_header(
        draw,
        lt,
        "02 / MARCO OFICIAL NASA INTEGRADO",
        "JPL CML 1–5, CubeSat 101 y Exportador GMAT R2026a",
        "Cada nave diseñada se audita con métricas del Mission Design Lab (MDL / Team X).",
    )

    # Left: CML 1..5 Staircase
    _draw_rounded_panel(draw, (76, 244, 930, 976), fill=C_PANEL, outline=C_CYAN, radius=18)
    draw.text((108, 274), "ESCALERA DE MADUREZ JPL (CML)", font=fonts["h2"], fill=C_CYAN)

    cmls = [
        ("CML 1", "Concepto Inicial (Objetivo y Destino)", C_MUTED),
        ("CML 2", "Viabilidad Inicial (Lanzador + Δv)", C_CYAN),
        ("CML 3", "Trade Space (Masa / Presup. / Ciencia)", C_CYAN),
        ("CML 4", "Team X (>=35% Masa/Potencia, >=3/6 dB)", C_GREEN),
        ("CML 5", "Baseline / MCR + ODAR EOL (>=3% res.)", C_AMBER),
    ]
    for i, (code, label, col) in enumerate(cmls):
        u = ease_out_back(win(lt, 0.8 + i * 0.55, 0.6))
        if u <= 0.01:
            continue
        bx = 108
        by = 342 + i * 116
        bw = int((420 + i * 95) * u)
        _draw_rounded_panel(draw, (bx, by, bx + bw, by + 88), fill=(18, 36, 66, 235), outline=col, radius=12)
        draw.text((bx + 20, by + 14), code, font=fonts["mono_lg"], fill=col)
        if u > 0.65:
            draw.text((bx + 20, by + 50), label, font=fonts["mono_sm"], fill=C_WHITE)

    # Right Top: 4 NASA SMD Segments + CubeSat 101
    u_r1 = ease_out_cubic(win(lt, 1.0, 0.7))
    _draw_rounded_panel(draw, (966, 244, W - 76, 550), fill=C_PANEL, outline=C_GREEN, radius=18)
    draw.text((998, 272), "4 SEGMENTOS SMD + CUBESAT 101", font=fonts["h2"], fill=C_GREEN)
    segs = [
        ("LANZAMIENTO", "Vega-C / Ariane-62 / Vulcan-H"),
        ("ESPACIO", "SmallSat <300 kg o Bus Medio + MEL/TVAC"),
        ("TIERRA (MOS)", "Atenuación 1/d² + Margen dB Team X"),
        ("USUARIO", "Análogos PUNCH · CAPSTONE · MAVEN"),
    ]
    for idx, (s_head, s_txt) in enumerate(segs):
        us = ease_out_cubic(win(lt, 1.3 + idx * 0.35, 0.5))
        sx = 998
        sy = 330 + idx * 52
        alpha = int(255 * us)
        draw.ellipse([sx, sy + 9, sx + 14, sy + 23], fill=(C_GREEN[0], C_GREEN[1], C_GREEN[2], alpha))
        draw.text((sx + 28, sy), f"{s_head}: ", font=fonts["mono"], fill=(C_CYAN[0], C_CYAN[1], C_CYAN[2], alpha))
        draw.text((sx + 215, sy + 2), s_txt, font=fonts["body"], fill=(C_WHITE[0], C_WHITE[1], C_WHITE[2], alpha))

    # Right Bottom: Animated GMAT Script Terminal
    _draw_rounded_panel(draw, (966, 578, W - 76, 976), fill=(7, 13, 24, 245), outline=C_AMBER, radius=18)
    draw.text((998, 606), "EXPORTADOR EN VIVO: NASA GMAT R2026a (.script)", font=fonts["h3"], fill=C_AMBER)
    gmat_lines = [
        "Create Spacecraft Probe;",
        "GMAT Probe.DryMass = 294.00;  % Masa real ensamblada",
        "GMAT MainTank.FuelMass = 640.00;  % Propelente",
        "GMAT FM_Mission.GravityField.Mars.PotentialFile = 'Mars50c.cof';",
        "GMAT FM_Mission.SRP.Flux = 1358;  % Nominal_Sun = 149597870.691",
        "Create ImpulsiveBurn TCM1;  GMAT TCM1.Axes = VNB;",
        "BeginMissionSequence;  Propagate PropRK89(Probe);",
    ]
    total_chars = sum(len(s) for s in gmat_lines)
    typed_chars = int(total_chars * clamp01(win(lt, 2.2, 5.2)))
    cur_y = 660
    rem = typed_chars
    for ln in gmat_lines:
        if rem <= 0:
            break
        vis = ln[:rem]
        rem -= len(ln)
        col = C_GREEN if "GMAT" in ln or "Create" in ln else C_CYAN
        draw.text((998, cur_y), vis, font=fonts["mono_sm"], fill=col)
        cur_y += 40


def _render_scene_4(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """27.5 - 38.0s: Dual View Cockpit — 2.5D External Orbit + Internal Cabin by Model."""
    fonts = _CTX["fonts"]
    _draw_scene_header(
        draw,
        lt,
        "03 / EXPERIENCIA DE VUELO Y CABINA [K]",
        "Vista Espacial 2.5D + Vista Interna Adaptada al Modelo",
        "Alterna en vuelo con [K]: física orbital, piloto automático explicable y sonido interior.",
    )

    # Main 16:9 Simulator Frame
    fx0, fy0, fx1, fy1 = 76, 242, W - 76, 980
    _draw_rounded_panel(draw, (fx0, fy0, fx1, fy1), fill=(8, 13, 24, 250), outline=C_CYAN, radius=18, width=3)

    # Split between External 2.5D (lt < 5.0) and Internal Cabin (lt >= 5.0) with smooth wipe
    wipe = ease_in_out_cubic(win(lt, 4.6, 1.0))

    # --- External 2.5D View (left/full before wipe) ---
    split_x = int(lerp(fx1, fx0 + 42, wipe))
    if split_x > fx0 + 60:
        # 70% space scene
        scene_bot = fy0 + 520
        _paste_center(canvas, _CTX["planets"]["sun_sm"], fx0 + 460, fy0 + 95)
        _paste_center(canvas, _CTX["planets"]["earth_sm"], fx0 + 210, scene_bot - 125)
        mars_grow = _CTX["planets"]["mars_md"]
        _paste_center(canvas, mars_grow, fx1 - 300, fy0 + 235)
        # Prediction curve
        pts = [quad_bezier((fx0 + 250, scene_bot - 125), (fx0 + 900, fy0 + 130), (fx1 - 300, fy0 + 235), k / 40.0) for k in range(41)]
        _draw_glow_line(canvas, pts, C_AMBER, width=3, alpha=190)
        pu = clamp01(0.15 + (lt / 5.2) * 0.7)
        spx, spy = quad_bezier((fx0 + 250, scene_bot - 125), (fx0 + 900, fy0 + 130), (fx1 - 300, fy0 + 235), pu)
        _draw_probe_vector(draw, spx, spy, -0.35 if pu < 0.7 else 2.75, scale=1.5, firing=True)
        # Orbit ring around Mars
        draw.arc([fx1 - 430, fy0 + 150, fx1 - 170, fy0 + 320], start=0, end=360, fill=C_GREEN, width=2)
        draw.text((fx0 + 28, fy0 + 20), "VISTA EXTERNA 2.5D  //  TRAYECTORIA CURVA + PRO/RET 180°", font=fonts["mono"], fill=C_GREEN)

    # --- Internal Bridge View (wipes in from right) ---
    if wipe > 0.02:
        ix0 = int(lerp(fx1, fx0 + 12, wipe))
        iy0 = fy0 + 12
        ix1 = fx1 - 12
        iy1 = fy0 + 530
        _draw_rounded_panel(draw, (ix0, iy0, ix1, iy1), fill=(15, 23, 38, 245), outline=C_AMBER, radius=14)
        if ix1 - ix0 > 460:
            # Viewport glass
            vx0, vy0, vx1, vy1 = ix0 + 190, iy0 + 58, ix1 - 190, iy1 - 76
            draw.rounded_rectangle([vx0, vy0, vx1, vy1], radius=22, fill=(4, 9, 20, 255), outline=(92, 132, 182), width=6)
            # Mars centered outside window + radial 3D stars
            vcx, vcy = (vx0 + vx1) * 0.5, (vy0 + vy1) * 0.5
            _paste_center(canvas, _CTX["planets"]["mars_md"], vcx + 80, vcy - 10)
            for k in range(18):
                ang = k * (math.tau / 18.0) + 0.2
                r_flow = ((lt * 190.0 + k * 42.0) % 290.0) + 45.0
                sx = vcx + math.cos(ang) * r_flow * 1.4
                sy = vcy + math.sin(ang) * r_flow * 0.75
                if vx0 + 12 < sx < vx1 - 12 and vy0 + 12 < sy < vy1 - 12:
                    draw.line([(sx, sy), (sx + math.cos(ang) * 18, sy + math.sin(ang) * 10)], fill=C_CYAN, width=2)
            # External parts peeking outside glass (solar wing + Ka dish + RCS puffs)
            draw.polygon([(vx0, vcy + 25), (vx0 + 135, vcy + 12), (vx0 + 135, vcy + 58), (vx0, vcy + 75)], fill=(38, 128, 224), outline=C_CYAN)
            draw.polygon([(vx1, vcy + 25), (vx1 - 135, vcy + 12), (vx1 - 135, vcy + 58), (vx1, vcy + 75)], fill=(38, 128, 224), outline=C_CYAN)
            draw.arc([vx1 - 180, vy1 - 105, vx1 - 70, vy1 - 20], start=180, end=330, fill=(210, 232, 250), width=4)
            # RCS corner gas puffs pulsing
            if int(lt * 6) % 2 == 0:
                draw.ellipse([vx0 + 16, vy0 + 16, vx0 + 52, vy0 + 44], fill=(235, 248, 255, 190))
                draw.ellipse([vx1 - 52, vy0 + 16, vx1 - 16, vy0 + 44], fill=(235, 248, 255, 190))
            # Side monitors inside cabin
            _draw_rounded_panel(draw, (ix0 + 22, iy0 + 120, ix0 + 165, iy1 - 110), fill=(10, 26, 32, 255), outline=C_GREEN, radius=8)
            draw.text((ix0 + 36, iy0 + 145), "CABINA\nPUENTE\nXEN-9\nKa-BAND\nRCS: OK", font=fonts["mono_sm"], fill=C_GREEN)
            _draw_rounded_panel(draw, (ix1 - 165, iy0 + 120, ix1 - 22, iy1 - 110), fill=(12, 24, 38, 255), outline=C_CYAN, radius=8)
            draw.text((ix1 - 150, iy0 + 145), "AUDIO:\nINTERIOR\nFILTRO\nTORMENTA\nNOMINAL", font=fonts["mono_sm"], fill=C_CYAN)
            draw.text((ix0 + 28, iy0 + 16), "VISTA INTERNA POR MODELO [K]  //  PUENTE ESPACIO PROFUNDO", font=fonts["mono"], fill=C_AMBER)

    # Bottom 30% Cockpit Deck Strip
    deck_y = fy0 + 544
    cards = [
        ("ENERGÍA", "Buses [F2-F4] · Batería · Sol", C_GREEN),
        ("ACTITUD", "RW + RCS [R] · PRO/RET/SOL/TX", C_CYAN),
        ("PROPULSIÓN", "Tapa [C] · Turbo [T] · Palanca", C_AMBER),
        ("AUTO [M]", "Piloto explicable paso a paso", C_VIOLET),
    ]
    for ci, (ct, cd, ccol) in enumerate(cards):
        cx0 = fx0 + 22 + ci * 432
        _draw_rounded_panel(draw, (cx0, deck_y, cx0 + 414, fy1 - 20), fill=C_PANEL_LIGHT, outline=ccol, radius=12)
        draw.text((cx0 + 20, deck_y + 22), ct, font=fonts["h3"], fill=ccol)
        draw.text((cx0 + 20, deck_y + 66), cd, font=fonts["mono_sm"], fill=C_WHITE)


def _render_scene_5(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """38.0 - 46.5s: Campaign Persistence, Passwordless Profiles & Verified Quality."""
    fonts = _CTX["fonts"]
    _draw_scene_header(
        draw,
        lt,
        "04 / CAMPAÑA, PERFILES Y VERIFICACIÓN",
        "Persistencia Sin Contraseña y Pruebas Automatizadas",
        "Regístrate solo con Nombre + Username y conserva tus CML, insignias y diseños ganadores.",
    )

    missions = [
        ("01 // LEO 420 KM", "Análogo: NASA PUNCH", "earth_sm", C_GREEN, "CML 5 · 150 PTS"),
        ("02 // LUNA CISLUNAR", "Análogo: NASA CAPSTONE", "moon_sm", C_CYAN, "CML 4 · 400 PTS"),
        ("03 // MARTE ARES-IV", "Análogo: NASA MAVEN", "mars_sm", C_MARS, "CML 5 · 600 PTS"),
    ]
    for idx, (m_t, m_a, p_key, m_col, m_rec) in enumerate(missions):
        um = ease_out_back(win(lt, 0.4 + idx * 0.35, 0.55))
        if um <= 0.01:
            continue
        mx = 76 + idx * 596
        my = int(246 + (1.0 - um) * 35)
        _draw_rounded_panel(draw, (mx, my, mx + 572, my + 240), fill=C_PANEL, outline=m_col, radius=16)
        _paste_center(canvas, _CTX["planets"][p_key], mx + 92, my + 120)
        draw.text((mx + 178, my + 34), m_t, font=fonts["h3"], fill=m_col)
        draw.text((mx + 178, my + 78), m_a, font=fonts["body"], fill=C_WHITE)
        draw.text((mx + 178, my + 124), m_rec, font=fonts["mono"], fill=C_GREEN)
        _draw_rounded_panel(draw, (mx + 178, my + 168, mx + 420, my + 208), fill=(18, 44, 62, 230), outline=C_CYAN, radius=8)
        draw.text((mx + 196, my + 177), "CARGAR DISEÑO", font=fonts["mono_sm"], fill=C_CYAN)

    # Commander profile banner
    up = ease_out_cubic(win(lt, 1.5, 0.6))
    if up > 0.02:
        py = int(516 + (1.0 - up) * 28)
        _draw_rounded_panel(draw, (76, py, W - 76, py + 150), fill=(12, 29, 54, 245), outline=C_AMBER, radius=16)
        draw.text((108, py + 24), "COMANDANTE ACTIVO: Elena Vance (@evance)   ·   SIN CONTRASEÑA   ·   user://profiles.json", font=fonts["h3"], fill=C_AMBER)
        draw.text((108, py + 76), "INSIGNIAS:   [CML 5]   [TEAM X >=35%]   [ODAR EOL >=3%]   [RF TEAM X]   [PILOTO MANUAL]", font=fonts["mono"], fill=C_GREEN)

    # Bottom metrics counters
    stats = [
        (349, "Pruebas Unitarias PASS", "Física, CML, GMAT y Cabinas", C_GREEN, 2.1),
        (121, "Pruebas Integración PASS", "UI real, Audio y Persistencia", C_CYAN, 2.3),
        (2, "Idiomas ES / EN [F2]", "Tipografía Crisp Pixel Art", C_AMBER, 2.5),
    ]
    for si, (target, s_lbl, s_sub, s_col, ts) in enumerate(stats):
        us = ease_out_cubic(win(lt, ts, 0.9))
        if us <= 0.01:
            continue
        sx = 76 + si * 596
        sy = 702
        _draw_rounded_panel(draw, (sx, sy, sx + 572, sy + 260), fill=C_PANEL_LIGHT, outline=s_col, radius=18)
        val = int(target * us)
        num_str = f"{val}" if target != 2 else "ES / EN"
        draw.text((sx + 34, sy + 32), num_str, font=fonts["stat"], fill=s_col)
        draw.text((sx + 34, sy + 124), s_lbl, font=fonts["h3"], fill=C_WHITE)
        draw.text((sx + 34, sy + 170), s_sub, font=fonts["body"], fill=C_MUTED)


def _render_scene_6(canvas: Image.Image, draw: ImageDraw.ImageDraw, lt: float, gt: float) -> None:
    """46.5 - 54.0s: Finale — Captured Mars Orbit & Call to Action."""
    fonts = _CTX["fonts"]
    u = ease_out_cubic(win(lt, 0.0, 1.0))
    _paste_center(canvas, _CTX["planets"]["mars_lg"], W * 0.5, 560)
    # Orbit ring + orbiting probe
    rx, ry = 360, 130
    draw.ellipse([W * 0.5 - rx, 560 - ry, W * 0.5 + rx, 560 + ry], outline=(C_GREEN[0], C_GREEN[1], C_GREEN[2], int(220 * u)), width=3)
    orb_a = lt * 1.15
    px = W * 0.5 + math.cos(orb_a) * rx
    py = 560 + math.sin(orb_a) * ry
    _draw_probe_vector(draw, px, py, orb_a + math.pi * 0.5, scale=1.45, firing=False)

    # Center Lockup
    _draw_rounded_panel(draw, (280, 120, W - 280, 355), fill=(7, 13, 26, 225), outline=C_CYAN, radius=22, width=3)
    draw.text((340, 146), "ÓRBITA CAPTURADA  //  MISIÓN CUMPLIDA", font=fonts["mono_lg"], fill=C_GREEN)
    draw.text((340, 198), "MISIÓN CRÍTICA", font=fonts["hero"], fill=C_WHITE)

    u2 = ease_out_cubic(win(lt, 0.6, 0.7))
    by = int(760 + (1.0 - u2) * 30)
    _draw_rounded_panel(draw, (140, by, W - 140, by + 165), fill=(8, 15, 29, 235), outline=C_AMBER, radius=18)
    cta_line = "Aprende ingeniería de misiones NASA diseñando y pilotando cada compromiso."
    cw = draw.textlength(cta_line, font=fonts["h2"])
    draw.text(((W - cw) * 0.5, by + 28), cta_line, font=fonts["h2"], fill=(C_WHITE[0], C_WHITE[1], C_WHITE[2], int(255 * u2)))
    foot_line = "Godot 4.7 Clean Architecture   ·   JPL CML 1–5   ·   NASA GMAT R2026a   ·   Bilingüe ES / EN"
    fw = draw.textlength(foot_line, font=fonts["mono"])
    draw.text(((W - fw) * 0.5, by + 92), foot_line, font=fonts["mono"], fill=(C_CYAN[0], C_CYAN[1], C_CYAN[2], int(255 * u2)))


SCENES: list[tuple[float, float, str, Callable]] = [
    (0.0, 7.5, "PRESENTACIÓN", _render_scene_1),
    (7.5, 17.0, "EL RETO DE INGENIERÍA", _render_scene_2),
    (17.0, 27.5, "ESTÁNDARES NASA & GMAT", _render_scene_3),
    (27.5, 38.0, "CABINA DUAL 2.5D + INTERNA", _render_scene_4),
    (38.0, 46.5, "CAMPAÑA & CALIDAD", _render_scene_5),
    (46.5, 54.0, "CIERRE", _render_scene_6),
]


def _render_frame(frame_idx: int) -> bytes:
    t = frame_idx / FPS
    base = _CTX["backdrop"].copy().convert("RGBA")
    _draw_stars(base, t)
    draw = ImageDraw.Draw(base, "RGBA")

    scene_idx = 1
    scene_tag = SCENES[0][2]
    for idx, (s0, s1, tag, fn) in enumerate(SCENES):
        if s0 <= t < s1 or (idx == len(SCENES) - 1 and t >= s0):
            scene_idx = idx + 1
            scene_tag = tag
            fn(base, draw, t - s0, t)
            # Smooth cross-transition dip to deep navy at slide boundaries (0.28s)
            fade = 1.0
            if t - s0 < 0.28 and idx > 0:
                fade = (t - s0) / 0.28
            elif s1 - t < 0.28 and idx < len(SCENES) - 1:
                fade = (s1 - t) / 0.28
            if fade < 1.0:
                dark = int(215 * (1.0 - clamp01(fade)))
                draw.rectangle([0, 0, W, H], fill=(C_BG[0], C_BG[1], C_BG[2], dark))
            break

    _draw_hud_chrome(base, t, scene_idx, scene_tag)

    # Final fade-out at the very end
    if t > DURATION_S - 0.6:
        fade_out = clamp01((t - (DURATION_S - 0.6)) / 0.6)
        draw.rectangle([0, 0, W, H], fill=(C_BG[0], C_BG[1], C_BG[2], int(255 * fade_out)))

    return base.convert("RGB").tobytes()


# ---------------------------------------------------------------------------
# Audio Synthesis & Game SFX Mix
# ---------------------------------------------------------------------------

def _load_wav_as_44100_mono(path: Path) -> list[float]:
    if not path.exists():
        return []
    with wave.open(str(path), "rb") as wf:
        sr = wf.getframerate()
        nch = wf.getnchannels()
        sw = wf.getsampwidth()
        raw = wf.readframes(wf.getnframes())
    if sw != 2:
        return []
    vals = struct.unpack("<" + "h" * (len(raw) // 2), raw)
    mono = [vals[i] / 32768.0 for i in range(0, len(vals), nch)]
    if sr == 44100:
        return mono
    ratio = sr / 44100.0
    out_len = int(len(mono) / ratio)
    out = []
    for i in range(out_len):
        pos = i * ratio
        idx = int(pos)
        frac = pos - idx
        s0 = mono[min(idx, len(mono) - 1)]
        s1 = mono[min(idx + 1, len(mono) - 1)]
        out.append(s0 + (s1 - s0) * frac)
    return out


def _generate_audio(out_wav: Path) -> None:
    sr = 44100
    n_samples = int(DURATION_S * sr)
    left = [0.0] * n_samples
    right = [0.0] * n_samples

    # Ambient deep-space synth progression: Am7 -> Fmaj7 -> Cmaj7 -> Em7 (8s cycles)
    chords = [
        (110.0, 220.0, 261.63, 329.63, 392.00),  # Am7
        (87.31, 174.61, 220.00, 261.63, 329.63), # Fmaj7
        (130.81, 261.63, 329.63, 392.00, 493.88),# Cmaj7
        (82.41, 164.81, 246.94, 293.66, 392.00), # Em7
    ]
    arp_step = 0.25  # 4 notes per second crisp pulse

    for i in range(n_samples):
        t = i / sr
        chord_idx = int(t / 7.5) % len(chords)
        bass_f, n1, n2, n3, n4 = chords[chord_idx]
        bar_t = (t % 7.5) / 7.5
        pad_env = min(1.0, bar_t * 6.0) * min(1.0, (1.0 - bar_t) * 6.0)
        global_env = min(1.0, t / 1.2) * min(1.0, max(0.0, (DURATION_S - t) / 1.5))

        # Warm sub + fifth pad
        pad = (
            0.22 * math.sin(math.tau * bass_f * t)
            + 0.11 * math.sin(math.tau * n1 * t)
            + 0.08 * math.sin(math.tau * n2 * t)
            + 0.06 * math.sin(math.tau * n3 * t + 0.4)
        ) * (0.45 + 0.55 * pad_env)

        # Gentle arpeggio pulse (stereo widening)
        step_idx = int(t / arp_step)
        step_t = (t % arp_step) / arp_step
        arp_freq = [n1, n2, n3, n4][step_idx % 4]
        arp_env = math.exp(-step_t * 6.5) * 0.11
        arp_l = arp_env * math.sin(math.tau * arp_freq * t)
        arp_r = arp_env * math.sin(math.tau * arp_freq * (t - 0.004))

        left[i] = (pad + arp_l) * global_env
        right[i] = (pad + arp_r) * global_env

    # Mix authentic softened game SFX synced to slide milestones
    sfx_events = [
        ("deploy.wav", 0.55, 0.24),
        ("click.wav", 8.1, 0.22),
        ("click.wav", 9.6, 0.22),
        ("telemetry.wav", 17.6, 0.24),
        ("science.wav", 21.8, 0.24),
        ("turbo.wav", 29.0, 0.20),
        ("switch.wav", 32.5, 0.26),
        ("telemetry.wav", 38.4, 0.22),
        ("victory.wav", 47.2, 0.30),
    ]
    sfx_cache: dict[str, list[float]] = {}
    for fname, at_s, gain in sfx_events:
        if fname not in sfx_cache:
            sfx_cache[fname] = _load_wav_as_44100_mono(ASSETS_DIR / "audio" / fname)
        samples = sfx_cache[fname]
        start = int(at_s * sr)
        for j, s in enumerate(samples):
            idx = start + j
            if 0 <= idx < n_samples:
                left[idx] += s * gain
                right[idx] += s * gain

    pcm = bytearray()
    for i in range(n_samples):
        sl = max(-0.96, min(0.96, left[i]))
        sr_v = max(-0.96, min(0.96, right[i]))
        pcm += struct.pack("<hh", int(sl * 32767), int(sr_v * 32767))

    with wave.open(str(out_wav), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(bytes(pcm))


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

def main() -> int:
    if shutil.which("ffmpeg") is None:
        print("ERROR: ffmpeg is required on PATH.", file=sys.stderr)
        return 1

    PITCH_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[1/3] Synthesizing soundtrack -> {TEMP_AUDIO_WAV.name}")
    _generate_audio(TEMP_AUDIO_WAV)

    print(f"[2/3] Rendering {TOTAL_FRAMES} motion-graphics frames ({W}x{H} @ {FPS}fps) via {min(6, os.cpu_count() or 2)} workers...")
    ffmpeg_cmd = [
        "ffmpeg",
        "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}",
        "-r", str(FPS),
        "-i", "-",
        "-i", str(TEMP_AUDIO_WAV),
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        "-movflags", "+faststart",
        str(OUTPUT_MP4),
    ]

    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    assert proc.stdin is not None

    workers = min(6, max(1, os.cpu_count() or 2))
    batch_size = 24
    with mp.Pool(processes=workers, initializer=_init_worker) as pool:
        for start in range(0, TOTAL_FRAMES, batch_size):
            end = min(TOTAL_FRAMES, start + batch_size)
            frames = pool.map(_render_frame, range(start, end))
            for raw in frames:
                proc.stdin.write(raw)
            if start % 240 == 0:
                print(f"  Rendered {end}/{TOTAL_FRAMES} frames ({int(end * 100 / TOTAL_FRAMES)}%)")

    proc.stdin.close()
    stderr_out = proc.stderr.read().decode("utf-8", errors="replace") if proc.stderr else ""
    ret = proc.wait()
    if ret != 0:
        print("FFmpeg failed:\n" + stderr_out, file=sys.stderr)
        return ret

    if TEMP_AUDIO_WAV.exists():
        TEMP_AUDIO_WAV.unlink()

    size_mb = OUTPUT_MP4.stat().st_size / (1024.0 * 1024.0)
    print(f"[3/3] Done! Video saved at {OUTPUT_MP4} ({size_mb:.2f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
