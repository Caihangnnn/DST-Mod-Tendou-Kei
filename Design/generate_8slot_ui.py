from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


OUT = Path(__file__).parent / "ui_8slot_drafts"


def rr(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def poly(draw, pts, fill, outline=None, width=1):
    draw.polygon(pts, fill=fill)
    if outline:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def make_slot(scale):
    # A 67px cell: the inset is exactly 64px; the 3px pink surround is its rim.
    n, q = 67, 4
    im = Image.new("RGBA", (n*q, n*q), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = lambda v: int(v*q)
    rr(d, (u(0), u(0), u(67), u(67)), u(8), "#14181d", "#050607", u(1))
    rr(d, (u(1), u(1), u(66), u(66)), u(7), "#f5e4ee", "#ffb9df", u(1))
    rr(d, (u(3), u(3), u(64), u(64)), u(5), "#393a43", "#651d50", u(1))
    rr(d, (u(4), u(4), u(63), u(63)), u(4), "#24262d", "#111219", u(1))
    # Subtle upper-left metal highlight and lower-right depth shading.
    d.line((u(8), u(5), u(56), u(5)), fill="#6d7280", width=u(1))
    d.line((u(5), u(8), u(5), u(56)), fill="#5a5d69", width=u(1))
    d.line((u(10), u(62), u(57), u(62)), fill="#111116", width=u(1))
    d.line((u(62), u(10), u(62), u(57)), fill="#0d0e12", width=u(1))
    # Four restrained mechanical corner brackets.
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        x0 = 8 if sx == 1 else 59
        y0 = 8 if sy == 1 else 59
        d.line((u(x0), u(y0), u(x0 + sx*5), u(y0)), fill="#cbd0d7", width=u(1))
        d.line((u(x0), u(y0), u(x0), u(y0 + sy*5)), fill="#cbd0d7", width=u(1))
    return im.resize((67*scale, 67*scale), Image.Resampling.LANCZOS)


def make_bar(scale):
    # Inner layout is 581x77: 5px + 8*67px + 8*5px + 5px. A 10px outer shell makes 601x97.
    w, h, q = 601, 97, 4
    im = Image.new("RGBA", (w*q, h*q), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = lambda v: int(v*q)
    # Nearly black backing plate, stepped rather than a plain rounded rectangle.
    outer = [(u(12),u(10)), (u(589),u(10)), (u(596),u(17)), (u(596),u(31)),
             (u(601),u(36)), (u(601),u(61)), (u(596),u(66)), (u(596),u(80)),
             (u(589),u(87)), (u(12),u(87)), (u(5),u(80)), (u(5),u(66)),
             (u(0),u(61)), (u(0),u(36)), (u(5),u(31)), (u(5),u(17))]
    poly(d, outer, "#14161c", "#07080b", u(2))
    inner = [(u(16),u(15)), (u(585),u(15)), (u(590),u(20)), (u(590),u(77)),
             (u(585),u(82)), (u(16),u(82)), (u(11),u(77)), (u(11),u(20))]
    poly(d, inner, "#2a2e36", "#545964", u(1))
    rr(d, (u(13),u(18),u(588),u(79)), u(6), "#1a1c22", "#090a0e", u(1))
    # Eight dark recessed bays. The matching slot image sits on top of these positions.
    for i in range(8):
        x = 15 + i*72
        rr(d, (u(x), u(15), u(x+67), u(82)), u(7), "#121419", "#07080a", u(1))
        rr(d, (u(x+4),u(19),u(x+63),u(78)), u(4), "#202229", "#30343e", u(1))
    # Keep the end caps dark and low-profile: no white armor pieces overlap slots 1 or 8.
    # Top/bottom central magenta modules and cyan diagnostics.
    rr(d, (u(254),u(10),u(347),u(17)), u(2), "#20222a", "#08090d", u(1))
    rr(d, (u(263),u(12),u(338),u(15)), u(1), "#f000a5")
    rr(d, (u(254),u(80),u(347),u(87)), u(2), "#20222a", "#08090d", u(1))
    rr(d, (u(263),u(82),u(338),u(85)), u(1), "#f000a5")
    for x in (78, 87, 96, 505, 514, 523):
        rr(d, (u(x),u(12),u(x+4),u(14)), u(1), "#4df7f5")
        rr(d, (u(x),u(83),u(x+4),u(85)), u(1), "#4df7f5")
    # Hairline white edge defines the floating sci-fi shell.
    d.line((u(19),u(11),u(248),u(11)), fill="#f8f9fb", width=u(1))
    d.line((u(352),u(11),u(581),u(11)), fill="#f8f9fb", width=u(1))
    d.line((u(19),u(86),u(248),u(86)), fill="#b9bdc7", width=u(1))
    d.line((u(352),u(86),u(581),u(86)), fill="#b9bdc7", width=u(1))
    return im.resize((w*scale, h*scale), Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for scale in (1, 2, 3):
        make_bar(scale).save(OUT / f"kei_8slot_container_bg_{scale}x.png")
        make_slot(scale).save(OUT / f"kei_8slot_slot_bg_{scale}x.png")


if __name__ == "__main__":
    main()
