#!/usr/bin/env python3
"""生成红白机 App 图标（1024px）"""
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), "#0d1020")
d = ImageDraw.Draw(img)

# 渐变背景
for y in range(SIZE):
    t = y / SIZE
    r = int(20 * (1 - t) + 60 * t)
    g = int(24 * (1 - t) + 40 * t)
    b = int(48 * (1 - t) + 110 * t)
    d.line([(0, y), (SIZE, y)], fill=(r, g, b))

# 机身（红白机）
body_w, body_h = 720, 420
bx0 = (SIZE - body_w) // 2
by0 = 320
bx1 = bx0 + body_w
by1 = by0 + body_h
# 机身圆角
d.rounded_rectangle([bx0, by0, bx1, by1], radius=40, fill="#e8e4da", outline="#2a2a35", width=8)
# 机身上半部红条
d.rounded_rectangle([bx0, by0, bx1, by0 + 150], radius=40, fill="#e04b4b", outline="#2a2a35", width=8)
# 覆盖底部圆角
d.rectangle([bx0, by0 + 120, bx1, by0 + 160], fill="#e04b4b")

# 手柄方向键（左）
dp_x, dp_y = bx0 + 110, by0 + 250
d.rounded_rectangle([dp_x, dp_y, dp_x + 130, dp_y + 130], radius=20, fill="#3a3a48", outline="#20202a", width=6)
# 十字
cx, cy = dp_x + 65, dp_y + 65
d.rectangle([cx - 18, cy - 55, cx + 18, cy + 55], fill="#c8c8d0")
d.rectangle([cx - 55, cy - 18, cx + 55, cy + 18], fill="#c8c8d0")

# AB 键（右）
a_x, a_y = bx1 - 230, by0 + 250
d.ellipse([a_x, a_y, a_x + 90, a_y + 90], fill="#e04b4b", outline="#20202a", width=6)
d.ellipse([a_x + 130, a_y + 30, a_x + 220, a_y + 120], fill="#e04b4b", outline="#20202a", width=6)

# 品牌字
try:
    font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 120)
except Exception:
    try:
        font = ImageFont.truetype("/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc", 120)
    except Exception:
        font = ImageFont.load_default()
d.text((SIZE // 2, 150), "红白机", font=font, fill="#ffffff", anchor="mm")

img.save("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("图标已生成")
