#!/usr/bin/env python3
"""Generate the Roomi Arts app icon: a rounded-square with a navy->violet
diagonal gradient, a white shopping bag with an amber handle, and a violet
"R" (Sora Bold) inside the bag. Outputs a 1024x1024 transparent-safe PNG."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont

S = 1024
PAD = 84                      # padding around the rounded square
BODY = S - 2 * PAD           # rounded-square side
RADIUS = 210                 # corner radius of the square

NAVY = (0x2A, 0x1A, 0x5E)
VIOLET = (0x6C, 0x4C, 0xFF)
AMBER = (0xFF, 0xB0, 0x20)
WHITE = (0xFF, 0xFF, 0xFF)

# ---- 1. Diagonal gradient (navy top-left -> violet bottom-right) ----
ys, xs = np.mgrid[0:BODY, 0:BODY]
t = (xs + ys) / (2.0 * (BODY - 1))          # 0 at TL, 1 at BR
t = t[..., None]
grad = (np.array(NAVY) * (1 - t) + np.array(VIOLET) * t).astype(np.uint8)
grad_img = Image.fromarray(np.dstack([grad, np.full((BODY, BODY), 255, np.uint8)]), "RGBA")

# ---- 2. Rounded-square mask, paste gradient onto transparent canvas ----
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
mask = Image.new("L", (BODY, BODY), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, BODY - 1, BODY - 1], RADIUS, fill=255)
icon.paste(grad_img, (PAD, PAD), mask)

d = ImageDraw.Draw(icon)
cx = S // 2

# ---- 3. Shopping bag ----
# Handle first (amber arc) so the bag body overlaps its base.
handle_w = 46
d.arc([cx - 118, 300, cx + 118, 545], start=180, end=360, fill=AMBER, width=handle_w)

# Bag body: white rounded rectangle, slightly trapezoid feel via rounded corners.
bag = [cx - 210, 430, cx + 210, 792]
d.rounded_rectangle(bag, radius=54, fill=WHITE)

# ---- 4. Violet "R" monogram (Sora Bold), centered in the bag ----
font = ImageFont.truetype("assets/fonts/Sora.ttf", 300)
try:
    font.set_variation_by_name("Bold")
except Exception:
    pass
bag_cx = cx
bag_cy = (bag[1] + bag[3]) // 2 + 8
l, t2, r, b = d.textbbox((0, 0), "R", font=font)
d.text((bag_cx - (l + r) / 2, bag_cy - (t2 + b) / 2), "R", font=font, fill=VIOLET)

import os
os.makedirs("assets/icon", exist_ok=True)
out = "assets/icon/roomi_icon.png"
icon.save(out)
print("wrote", out, icon.size)

# ---- iOS variant: full-bleed, opaque (iOS forbids alpha and applies its own
# rounding, so the gradient must reach every edge with no transparent corners).
ios = Image.new("RGBA", (S, S), (0, 0, 0, 255))
full_grad = (np.array(NAVY) * (1 - (np.mgrid[0:S, 0:S][1] + np.mgrid[0:S, 0:S][0])[..., None] / (2.0 * (S - 1)))
             + np.array(VIOLET) * (np.mgrid[0:S, 0:S][1] + np.mgrid[0:S, 0:S][0])[..., None] / (2.0 * (S - 1))).astype(np.uint8)
ios = Image.fromarray(np.dstack([full_grad, np.full((S, S), 255, np.uint8)]).astype(np.uint8), "RGBA")
di = ImageDraw.Draw(ios)
di.arc([cx - 118, 300, cx + 118, 545], start=180, end=360, fill=AMBER, width=handle_w)
di.rounded_rectangle(bag, radius=54, fill=WHITE)
di.text((bag_cx - (l + r) / 2, bag_cy - (t2 + b) / 2), "R", font=font, fill=VIOLET)
ios_rgb = ios.convert("RGB")  # drop alpha entirely for iOS
ios_out = "assets/icon/roomi_icon_ios.png"
ios_rgb.save(ios_out)
print("wrote", ios_out, ios_rgb.size)

# ---- Android adaptive icon: separate background (gradient) + foreground
# (bag+R). Android masks the icon (circle/squircle) and only the centre ~66%
# of the foreground is guaranteed visible, so the mark is drawn smaller and
# centred with transparent margins around it. ----
bg = Image.fromarray(
    np.dstack([full_grad, np.full((S, S), 255, np.uint8)]).astype(np.uint8),
    "RGBA").convert("RGB")
bg_out = "assets/icon/roomi_adaptive_bg.png"
bg.save(bg_out)
print("wrote", bg_out, bg.size)

# Foreground: bag+handle+R on transparent, scaled to ~58% and centred so the
# adaptive mask never clips it.
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fgd = ImageDraw.Draw(fg)
fgd.arc([cx - 118, 300, cx + 118, 545], start=180, end=360, fill=AMBER, width=handle_w)
fgd.rounded_rectangle(bag, radius=54, fill=WHITE)
fgd.text((bag_cx - (l + r) / 2, bag_cy - (t2 + b) / 2), "R", font=font, fill=VIOLET)
# Crop to the mark, then paste scaled into the safe zone of a fresh canvas.
mark = fg.crop(fg.getbbox())
scale = int(S * 0.56)
mw, mh = mark.size
ratio = min(scale / mw, scale / mh)
mark = mark.resize((int(mw * ratio), int(mh * ratio)), Image.LANCZOS)
fg2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fg2.paste(mark, ((S - mark.width) // 2, (S - mark.height) // 2), mark)
fg_out = "assets/icon/roomi_adaptive_fg.png"
fg2.save(fg_out)
print("wrote", fg_out, fg2.size)
