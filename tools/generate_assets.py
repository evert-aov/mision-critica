#!/usr/bin/env python3
"""Deterministic pixel-art PNG, BMFont, and chiptune WAV asset generator."""

import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def write_png(path: str, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    """Write an RGBA8 PNG file using only zlib & struct."""
    ensure_dir(os.path.dirname(path))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0
        row_start = y * width
        for x in range(width):
            r, g, b, a = pixels[row_start + x]
            raw.extend((r, g, b, a))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


class Canvas:
    def __init__(self, w: int, h: int, bg=(0, 0, 0, 0)):
        self.w = w
        self.h = h
        self.px = [bg] * (w * h)

    def put(self, x: int, y: int, c: tuple[int, int, int, int]) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def rect(self, x: int, y: int, w: int, h: int, c: tuple[int, int, int, int]) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def box(self, x: int, y: int, w: int, h: int, c: tuple[int, int, int, int]) -> None:
        for xx in range(x, x + w):
            self.put(xx, y, c)
            self.put(xx, y + h - 1, c)
        for yy in range(y, y + h):
            self.put(x, yy, c)
            self.put(x + w - 1, yy, c)

    def save(self, rel_path: str) -> None:
        write_png(os.path.join(ASSETS, rel_path), self.w, self.h, self.px)


# --- Palette ---
C_TRANS = (0, 0, 0, 0)
C_VOID = (10, 14, 22, 255)
C_PANEL_BG = (28, 34, 48, 255)
C_PANEL_DARK = (18, 22, 32, 255)
C_PANEL_HI = (68, 80, 104, 255)
C_PANEL_BORDER = (8, 10, 16, 255)
C_CRT_BG = (8, 22, 16, 255)
C_CRT_BORDER = (46, 56, 72, 255)
C_GREEN = (64, 232, 128, 255)
C_GREEN_DIM = (24, 96, 52, 255)
C_AMBER = (248, 184, 56, 255)
C_RED = (232, 68, 68, 255)
C_RED_DARK = (128, 28, 32, 255)
C_WHITE = (236, 242, 248, 255)
C_SILVER = (168, 180, 198, 255)
C_STEEL = (96, 110, 132, 255)
C_GOLD = (236, 178, 54, 255)
C_GOLD_DARK = (164, 112, 28, 255)
C_CYAN = (64, 200, 240, 255)
C_BLUE_SOLAR = (32, 88, 176, 255)
C_BLUE_SOLAR_HI = (68, 140, 228, 255)


def make_ninepatch(rel: str, bg, hi, lo, border, rivet=None) -> None:
    c = Canvas(24, 24, bg)
    c.box(0, 0, 24, 24, border)
    c.box(1, 1, 22, 22, lo)
    for x in range(2, 22):
        c.put(x, 2, hi)
    for y in range(2, 22):
        c.put(2, y, hi)
    if rivet:
        for rx, ry in [(3, 3), (20, 3), (3, 20), (20, 20)]:
            c.put(rx, ry, rivet)
    c.save(rel)


def make_button(rel: str, fill, top_hi, bot_lo, border=C_PANEL_BORDER) -> None:
    c = Canvas(16, 16, fill)
    c.box(0, 0, 16, 16, border)
    for x in range(1, 15):
        c.put(x, 1, top_hi)
        c.put(x, 14, bot_lo)
    for y in range(1, 15):
        c.put(1, y, top_hi)
        c.put(14, y, bot_lo)
    c.save(rel)


def generate_ui_and_cockpit() -> None:
    make_ninepatch("sprites/ui/panel_metal.png", C_PANEL_BG, C_PANEL_HI, C_PANEL_DARK, C_PANEL_BORDER, C_SILVER)
    make_ninepatch("sprites/ui/panel_crt.png", C_CRT_BG, (20, 48, 36, 255), (4, 12, 8, 255), C_CRT_BORDER)

    make_button("sprites/ui/btn_normal.png", (42, 52, 72, 255), (76, 92, 120, 255), (24, 30, 44, 255))
    make_button("sprites/ui/btn_hover.png", (56, 70, 96, 255), (104, 126, 162, 255), (32, 40, 56, 255))
    make_button("sprites/ui/btn_pressed.png", (28, 36, 52, 255), (18, 24, 34, 255), (60, 74, 98, 255))
    make_button("sprites/ui/btn_disabled.png", (28, 32, 40, 255), (40, 46, 56, 255), (18, 22, 28, 255))

    # Toggle switches (22x26)
    for state in ("off", "on"):
        for mode in ("normal", "hover", "pressed"):
            c = Canvas(22, 26, C_PANEL_DARK)
            c.box(0, 0, 22, 26, C_PANEL_BORDER)
            c.box(2, 2, 18, 22, C_STEEL if mode != "hover" else C_SILVER)
            c.rect(4, 4, 14, 18, (14, 18, 26, 255))
            # Switch lever
            if state == "on":
                c.rect(6, 5, 10, 8, C_GREEN if mode != "pressed" else C_GREEN_DIM)
                c.rect(7, 6, 8, 2, C_WHITE)
                c.rect(6, 13, 10, 3, C_SILVER)
            else:
                c.rect(6, 13, 10, 8, C_RED if mode != "pressed" else C_RED_DARK)
                c.rect(6, 10, 10, 3, C_SILVER)
                c.rect(7, 19, 8, 2, (255, 140, 140, 255))
            c.save(f"sprites/cockpit/toggle_{state}_{mode}.png")

    # Safety cover (34x28)
    for is_open in (False, True):
        for hover in (False, True):
            c = Canvas(34, 28, C_TRANS)
            border = C_WHITE if hover else C_PANEL_BORDER
            if not is_open:
                c.rect(1, 1, 32, 26, (210, 150, 24, 255))
                c.box(1, 1, 32, 26, border)
                # Hazard stripes
                for y in range(4, 24):
                    for x in range(4, 30):
                        if ((x + y) // 4) % 2 == 0:
                            c.put(x, y, (28, 28, 32, 255))
                c.rect(10, 10, 14, 7, (220, 48, 48, 255))
                c.box(10, 10, 14, 7, C_PANEL_BORDER)
            else:
                # Flipped up hinge bar
                c.rect(1, 0, 32, 7, C_AMBER if not hover else C_WHITE)
                c.box(1, 0, 32, 7, border)
                for x in range(3, 31, 4):
                    c.rect(x, 2, 2, 3, C_PANEL_BORDER)
            c.save(f"sprites/cockpit/cover_{'open' if is_open else 'closed'}_{'hover' if hover else 'normal'}.png")

    # Ignition button (30x28)
    for mode, fill, hi in [
        ("normal", C_RED, (255, 132, 120, 255)),
        ("hover", (252, 92, 84, 255), C_WHITE),
        ("pressed", C_RED_DARK, C_RED),
        ("disabled", (68, 42, 46, 255), (96, 62, 66, 255)),
    ]:
        c = Canvas(30, 28, (22, 26, 36, 255))
        c.box(0, 0, 30, 28, C_PANEL_BORDER)
        c.rect(3, 3, 24, 22, fill)
        c.box(3, 3, 24, 22, C_PANEL_BORDER)
        for x in range(4, 26):
            c.put(x, 4, hi)
        c.save(f"sprites/cockpit/ign_{mode}.png")

    # Solar deploy button (56x18)
    for mode, fill, hi in [
        ("normal", (36, 92, 168, 255), (92, 168, 248, 255)),
        ("hover", (54, 118, 200, 255), C_WHITE),
        ("pressed", (22, 56, 108, 255), (48, 100, 172, 255)),
        ("done", (28, 92, 56, 255), C_GREEN),
    ]:
        c = Canvas(56, 18, fill)
        c.box(0, 0, 56, 18, C_PANEL_BORDER)
        for x in range(1, 55):
            c.put(x, 1, hi)
        c.save(f"sprites/cockpit/deploy_{mode}.png")

    # Sensor keycap button (24x18)
    for mode, fill, hi in [
        ("normal", (48, 62, 84, 255), (92, 116, 152, 255)),
        ("hover", (68, 90, 124, 255), C_CYAN),
        ("pressed", (28, 38, 52, 255), (54, 70, 94, 255)),
        ("disabled", (28, 32, 40, 255), (42, 48, 58, 255)),
    ]:
        c = Canvas(24, 18, fill)
        c.box(0, 0, 24, 18, C_PANEL_BORDER)
        for x in range(1, 23):
            c.put(x, 1, hi)
        c.save(f"sprites/cockpit/sensor_{mode}.png")

    # LEDs 4-frame horizontal sheets (32x8)
    for name, bright, dim in [
        ("green", C_GREEN, C_GREEN_DIM),
        ("red", C_RED, C_RED_DARK),
        ("amber", C_AMBER, (112, 76, 18, 255)),
    ]:
        c = Canvas(32, 8, C_TRANS)
        for frame in range(4):
            ox = frame * 8
            col = bright if frame in (0, 1) else dim
            c.rect(ox + 1, 1, 6, 6, C_PANEL_BORDER)
            c.rect(ox + 2, 2, 4, 4, col)
            if frame in (0, 1):
                c.put(ox + 2, 2, C_WHITE)
        c.save(f"sprites/cockpit/led_{name}_sheet.png")

    # Radar AnimatedSprite2D sheet: 8 frames of 28x28 -> 224x28
    c = Canvas(224, 28, C_TRANS)
    for frame in range(8):
        ox = frame * 28
        cx, cy = ox + 14, 14
        c.rect(ox, 0, 28, 28, C_CRT_BG)
        c.box(ox, 0, 28, 28, C_CRT_BORDER)
        for r in (6, 11):
            for deg in range(0, 360, 10):
                px = int(round(cx + math.cos(math.radians(deg)) * r))
                py = int(round(cy + math.sin(math.radians(deg)) * r))
                c.put(px, py, C_GREEN_DIM)
        ang = frame * (math.pi / 4.0)
        for d in range(1, 12):
            px = int(round(cx + math.cos(ang) * d))
            py = int(round(cy + math.sin(ang) * d))
            c.put(px, py, C_GREEN)
        c.put(cx, cy, C_WHITE)
    c.save("sprites/cockpit/radar_sheet.png")

    # Spark / alert sheet: 4 frames of 16x16 -> 64x16
    c = Canvas(64, 16, C_TRANS)
    for frame in range(4):
        ox = frame * 16
        col = C_AMBER if frame % 2 == 0 else C_RED
        if frame < 3:
            for d in range(2, 7):
                if (frame + d) % 2 == 0:
                    c.put(ox + 8 + d, 8 - d // 2, col)
                    c.put(ox + 8 - d, 8 + d // 2, col)
                    c.put(ox + 8 + d // 2, 8 + d, C_WHITE)
                    c.put(ox + 8 - d // 2, 8 - d, C_WHITE)
        c.rect(ox + 7, 7, 2, 2, C_WHITE if frame % 2 == 0 else C_AMBER)
    c.save("sprites/cockpit/spark_sheet.png")


def generate_planets_and_parts() -> None:
    # Planets 64x64
    rng = random.Random(42)
    specs = {
        "earth": ((26, 74, 168, 255), (46, 148, 78, 255), (104, 184, 255, 255), True),
        "moon": ((124, 130, 140, 255), (84, 88, 98, 255), (180, 186, 196, 255), False),
        "mars": ((184, 78, 44, 255), (130, 48, 28, 255), (236, 146, 92, 255), False),
    }
    for name, (base, sec, rim, clouds) in specs.items():
        c = Canvas(64, 64, C_TRANS)
        cx, cy, r = 31.5, 31.5, 28.0
        for y in range(64):
            for x in range(64):
                dx, dy = x - cx, y - cy
                dist = math.hypot(dx, dy)
                if dist > r:
                    continue
                # Lighting from top-left
                light = (-dx * 0.65 - dy * 0.55) / r
                n = math.sin(x * 0.19 + y * 0.11) + math.cos(x * 0.08 - y * 0.23)
                col = sec if n > 0.35 else base
                if clouds and math.sin(x * 0.25 + y * 0.45) > 1.15:
                    col = (228, 238, 246, 255)
                if name == "mars" and abs(dy) > 22.5:
                    col = (232, 236, 242, 255)  # polar cap
                if dist > r - 1.6 and light > -0.2:
                    col = rim
                # Shading
                if light < -0.25:
                    shade = max(0.22, 1.0 + light * 0.75)
                    col = (int(col[0] * shade), int(col[1] * shade), int(col[2] * shade), 255)
                c.put(x, y, col)
        c.save(f"sprites/space/planet_{name}.png")

    # Mini probe 16x16
    c = Canvas(16, 16, C_TRANS)
    c.rect(5, 5, 6, 6, C_GOLD)
    c.box(5, 5, 6, 6, C_PANEL_BORDER)
    c.rect(1, 6, 4, 4, C_BLUE_SOLAR)
    c.rect(11, 6, 4, 4, C_BLUE_SOLAR)
    c.rect(7, 11, 2, 3, C_STEEL)
    c.put(7, 3, C_WHITE)
    c.put(8, 3, C_WHITE)
    c.save("sprites/space/probe_mini.png")

    # Probe bus 32x32
    c = Canvas(32, 32, C_TRANS)
    c.rect(8, 7, 16, 18, C_GOLD)
    c.box(8, 7, 16, 18, C_PANEL_BORDER)
    c.rect(10, 9, 12, 14, C_GOLD_DARK)
    c.rect(11, 10, 10, 12, C_GOLD)
    # Dish on top
    c.rect(10, 3, 12, 3, C_SILVER)
    c.box(10, 3, 12, 3, C_PANEL_BORDER)
    c.rect(15, 1, 2, 6, C_WHITE)
    # Avionics green LED
    c.rect(14, 14, 4, 3, C_GREEN)
    c.save("sprites/parts/probe_bus.png")

    # Part icons 16x16
    def icon_canvas():
        return Canvas(16, 16, C_TRANS)

    # Engines
    for eid, body_col, glow_col in [
        ("part_eng_hydrazine", C_SILVER, C_AMBER),
        ("part_eng_biprop", C_STEEL, C_RED),
        ("part_eng_ion", (88, 120, 164, 255), C_CYAN),
    ]:
        c = icon_canvas()
        c.rect(5, 2, 6, 4, body_col)
        c.rect(4, 6, 8, 5, C_STEEL)
        c.rect(3, 11, 10, 2, body_col)
        c.box(4, 6, 8, 6, C_PANEL_BORDER)
        c.rect(6, 13, 4, 2, glow_col)
        c.save(f"sprites/parts/{eid}.png")

    # Tanks
    for tid, w, col, stripe in [
        ("part_tank_small", 8, C_WHITE, C_AMBER),
        ("part_tank_medium", 10, C_SILVER, C_CYAN),
        ("part_tank_large", 12, (200, 212, 224, 255), C_RED),
    ]:
        c = icon_canvas()
        ox = (16 - w) // 2
        c.rect(ox, 2, w, 12, col)
        c.box(ox, 2, w, 12, C_PANEL_BORDER)
        c.rect(ox + 1, 7, w - 2, 2, stripe)
        c.save(f"sprites/parts/{tid}.png")

    # Solar & Batteries
    c = icon_canvas()
    c.rect(2, 4, 12, 8, C_BLUE_SOLAR)
    c.box(2, 4, 12, 8, C_SILVER)
    for x in (6, 10):
        c.rect(x, 4, 1, 8, C_BLUE_SOLAR_HI)
    c.save("sprites/parts/part_solar_compact.png")

    c = icon_canvas()
    c.rect(1, 3, 6, 10, C_BLUE_SOLAR)
    c.rect(9, 3, 6, 10, C_BLUE_SOLAR)
    c.box(1, 3, 6, 10, C_SILVER)
    c.box(9, 3, 6, 10, C_SILVER)
    c.rect(7, 6, 2, 4, C_GOLD)
    c.save("sprites/parts/part_solar_wing.png")

    for bid, col in [("part_bat_liion", C_GREEN), ("part_bat_heavy", C_AMBER)]:
        c = icon_canvas()
        c.rect(4, 3, 8, 11, C_STEEL)
        c.box(4, 3, 8, 11, C_PANEL_BORDER)
        c.rect(6, 1, 4, 2, C_SILVER)
        c.rect(6, 6, 4, 5, col)
        c.save(f"sprites/parts/{bid}.png")

    # Instruments
    c = icon_canvas()  # cam
    c.rect(3, 4, 10, 8, C_STEEL)
    c.box(3, 4, 10, 8, C_PANEL_BORDER)
    c.rect(6, 6, 4, 4, C_CYAN)
    c.put(7, 7, C_WHITE)
    c.save("sprites/parts/part_inst_cam.png")

    c = icon_canvas()  # spec
    c.rect(2, 5, 12, 7, C_GOLD_DARK)
    c.box(2, 5, 12, 7, C_PANEL_BORDER)
    c.rect(4, 7, 2, 3, C_RED)
    c.rect(7, 7, 2, 3, C_GREEN)
    c.rect(10, 7, 2, 3, C_CYAN)
    c.save("sprites/parts/part_inst_spec.png")

    c = icon_canvas()  # radar
    c.rect(2, 8, 12, 3, C_SILVER)
    c.rect(4, 5, 8, 3, C_STEEL)
    c.rect(7, 2, 2, 4, C_WHITE)
    c.box(2, 8, 12, 3, C_PANEL_BORDER)
    c.save("sprites/parts/part_inst_radar.png")


# --- Crisp 5x7 Pixel Bitmap Font (BMFont AngelCode format) ---
FONT_5X7 = {
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    '"': ["01010", "01010", "01010", "00000", "00000", "00000", "00000"],
    "#": ["01010", "11111", "01010", "01010", "11111", "01010", "00000"],
    "$": ["00100", "01111", "10100", "01110", "00101", "11110", "00100"],
    "%": ["11001", "11010", "00100", "00100", "01011", "10011", "00000"],
    "&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
    "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
    "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    ",": ["00000", "00000", "00000", "00000", "00000", "00100", "01000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "00110", "00110"],
    "/": ["00001", "00010", "00100", "00100", "01000", "10000", "00000"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    ":": ["00000", "00110", "00110", "00000", "00110", "00110", "00000"],
    ";": ["00000", "00110", "00110", "00000", "00110", "00100", "01000"],
    "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
    "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
    ">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
    "?": ["01110", "10001", "00001", "00110", "00100", "00000", "00100"],
    "@": ["01110", "10001", "10111", "10101", "10110", "10000", "01110"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11100", "10010", "10001", "10001", "10001", "10010", "11100"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "[": ["01110", "01000", "01000", "01000", "01000", "01000", "01110"],
    "]": ["01110", "00010", "00010", "00010", "00010", "00010", "01110"],
    "_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"],
    "a": ["00000", "00000", "01110", "00001", "01111", "10001", "01111"],
    "b": ["10000", "10000", "11110", "10001", "10001", "10001", "11110"],
    "c": ["00000", "00000", "01110", "10000", "10000", "10001", "01110"],
    "d": ["00001", "00001", "01111", "10001", "10001", "10001", "01111"],
    "e": ["00000", "00000", "01110", "10001", "11111", "10000", "01110"],
    "f": ["00110", "01001", "01000", "11100", "01000", "01000", "01000"],
    "g": ["00000", "01111", "10001", "10001", "01111", "00001", "01110"],
    "h": ["10000", "10000", "11110", "10001", "10001", "10001", "10001"],
    "i": ["00100", "00000", "01100", "00100", "00100", "00100", "01110"],
    "j": ["00010", "00000", "00110", "00010", "00010", "10010", "01100"],
    "k": ["10000", "10000", "10010", "10100", "11000", "10100", "10010"],
    "l": ["01100", "00100", "00100", "00100", "00100", "00100", "01110"],
    "m": ["00000", "00000", "11010", "10101", "10101", "10001", "10001"],
    "n": ["00000", "00000", "11110", "10001", "10001", "10001", "10001"],
    "o": ["00000", "00000", "01110", "10001", "10001", "10001", "01110"],
    "p": ["00000", "11110", "10001", "10001", "11110", "10000", "10000"],
    "q": ["00000", "01111", "10001", "10001", "01111", "00001", "00001"],
    "r": ["00000", "00000", "10110", "11001", "10000", "10000", "10000"],
    "s": ["00000", "00000", "01111", "10000", "01110", "00001", "11110"],
    "t": ["01000", "01000", "11100", "01000", "01000", "01001", "00110"],
    "u": ["00000", "00000", "10001", "10001", "10001", "10011", "01101"],
    "v": ["00000", "00000", "10001", "10001", "10001", "01010", "00100"],
    "w": ["00000", "00000", "10001", "10001", "10101", "10101", "01010"],
    "x": ["00000", "00000", "10001", "01010", "00100", "01010", "10001"],
    "y": ["00000", "10001", "10001", "01111", "00001", "00001", "01110"],
    "z": ["00000", "00000", "11111", "00010", "00100", "01000", "11111"],
    "Á": ["00010", "00100", "01110", "10001", "11111", "10001", "10001"],
    "É": ["00010", "01111", "10000", "11110", "10000", "10000", "11111"],
    "Í": ["00010", "01110", "00100", "00100", "00100", "00100", "01110"],
    "Ó": ["00010", "01110", "10001", "10001", "10001", "10001", "01110"],
    "Ú": ["00010", "10001", "10001", "10001", "10001", "10001", "01110"],
    "Ñ": ["01101", "00000", "10001", "11001", "10101", "10011", "10001"],
    "á": ["00010", "00100", "01110", "00001", "01111", "10001", "01111"],
    "é": ["00010", "00100", "01110", "10001", "11111", "10000", "01110"],
    "í": ["00010", "00100", "00000", "01100", "00100", "00100", "01110"],
    "ó": ["00010", "00100", "01110", "10001", "10001", "10001", "01110"],
    "ú": ["00010", "00100", "10001", "10001", "10001", "10011", "01101"],
    "ñ": ["01101", "00000", "11110", "10001", "10001", "10001", "10001"],
    "¡": ["00100", "00000", "00100", "00100", "00100", "00100", "00100"],
    "¿": ["00100", "00000", "00100", "01100", "10000", "10001", "01110"],
    "°": ["01100", "10010", "01100", "00000", "00000", "00000", "00000"],
    "Δ": ["00100", "00100", "01010", "01010", "10001", "10001", "11111"],
    "±": ["00100", "00100", "11111", "00100", "00100", "00000", "11111"],
    "|": ["00100", "00100", "00100", "00100", "00100", "00100", "00100"],
    "\\": ["10000", "01000", "00100", "00100", "00010", "00001", "00000"],
    "~": ["00000", "00000", "01001", "10110", "00000", "00000", "00000"],
    "^": ["00100", "01010", "10001", "00000", "00000", "00000", "00000"],
    "·": ["00000", "00000", "00000", "00100", "00000", "00000", "00000"],
}


def generate_bmfont() -> None:
    cols = 16
    cell_w, cell_h = 8, 8
    chars = list(FONT_5X7.keys())
    rows = (len(chars) + cols - 1) // cols
    img_w = cols * cell_w
    img_h = rows * cell_h
    c = Canvas(img_w, img_h, C_TRANS)

    fnt_lines = [
        'info face="Pixel5x7" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1 outline=0',
        f'common lineHeight=8 base=7 scaleW={img_w} scaleH={img_h} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4',
        'page id=0 file="pixel_5x7.png"',
        f"chars count={len(chars)}",
    ]

    for idx, ch in enumerate(chars):
        gx = (idx % cols) * cell_w
        gy = (idx // cols) * cell_h
        bitmap = FONT_5X7[ch]
        for r, row_bits in enumerate(bitmap):
            for col_i, bit in enumerate(row_bits):
                if bit == "1":
                    c.put(gx + col_i, gy + r, C_WHITE)
        code = ord(ch)
        fnt_lines.append(
            f"char id={code} x={gx} y={gy} width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15"
        )

    c.save("fonts/pixel_5x7.png")
    fnt_path = os.path.join(ASSETS, "fonts/pixel_5x7.fnt")
    ensure_dir(os.path.dirname(fnt_path))
    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(fnt_lines) + "\n")


def write_wav(rel: str, samples: list[int], rate: int = 22050) -> None:
    path = os.path.join(ASSETS, rel)
    ensure_dir(os.path.dirname(path))
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        data = struct.pack(f"<{len(samples)}h", *samples)
        wf.writeframes(data)


def generate_audio() -> None:
    rate = 22050

    def square_tone(freq: float, dur: float, amp: float = 0.28, decay: bool = True) -> list[int]:
        n = int(rate * dur)
        out = []
        for i in range(n):
            t = i / rate
            env = (1.0 - i / n) if decay else 1.0
            s = 1.0 if (t * freq) % 1.0 < 0.5 else -1.0
            out.append(max(-32767, min(32767, int(s * amp * env * 32767))))
        return out

    write_wav("audio/click.wav", square_tone(720.0, 0.045, 0.25))
    write_wav("audio/switch.wav", square_tone(310.0, 0.05, 0.30) + square_tone(460.0, 0.04, 0.22))
    write_wav("audio/telemetry.wav", square_tone(1120.0, 0.07, 0.20))
    write_wav("audio/science.wav", square_tone(660.0, 0.08, 0.24) + square_tone(990.0, 0.10, 0.24) + square_tone(1320.0, 0.14, 0.24))
    write_wav("audio/victory.wav", square_tone(523.25, 0.11, 0.26) + square_tone(659.25, 0.11, 0.26) + square_tone(783.99, 0.12, 0.26) + square_tone(1046.5, 0.28, 0.28))
    write_wav("audio/failure.wav", square_tone(300.0, 0.16, 0.28) + square_tone(220.0, 0.18, 0.28) + square_tone(150.0, 0.30, 0.28))

    # Low battery alarm pulse
    alarm = square_tone(520.0, 0.15, 0.24, False) + [0] * int(rate * 0.20)
    write_wav("audio/alarm_low.wav", alarm)

    # Ignition noise burst & continuous rumble
    rng = random.Random(7)
    lp = 0.0
    ign = []
    n_ign = int(rate * 0.36)
    for i in range(n_ign):
        w = rng.uniform(-1.0, 1.0)
        lp = lp * 0.84 + w * 0.16
        env = 1.0 - (i / n_ign)
        ign.append(max(-32767, min(32767, int(lp * 0.55 * env * 32767))))
    write_wav("audio/ignition.wav", ign)

    hum = []
    n_hum = int(rate * 0.5)
    for i in range(n_hum):
        w = rng.uniform(-1.0, 1.0)
        lp = lp * 0.88 + w * 0.12
        hum.append(max(-32767, min(32767, int(lp * 0.30 * 32767))))
    write_wav("audio/engine_hum.wav", hum)


if __name__ == "__main__":
    generate_ui_and_cockpit()
    generate_planets_and_parts()
    generate_bmfont()
    generate_audio()
    print("Generated all pixel-art and chiptune assets successfully.")
