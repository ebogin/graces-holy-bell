from PIL import Image, ImageDraw, ImageFont

FONT = "/Users/ericbogin/Developer/graces-holy-bell/Graces Holy Bell/Fonts/PressStart2P-Regular.ttf"
lines = ["YOU'RE ON", "THE LIST"]
scale = 3                      # render small for crisp pixels, then upscale NEAREST
size = 16
font = ImageFont.truetype(FONT, size)

bg   = (192, 208, 168)         # #c0d0a8  (email card background)
fg   = (26, 42, 10)            # #1a2a0a  (lcd-dark)

# measure
tmp = Image.new("RGB", (10, 10))
d = ImageDraw.Draw(tmp)
line_h = size + 8
widths = [d.textlength(t, font=font) for t in lines]
W = int(max(widths)) + 24
H = line_h * len(lines) + 16

img = Image.new("RGB", (W, H), bg)
d = ImageDraw.Draw(img)
y = 8
for t, w in zip(lines, widths):
    x = (W - w) / 2
    d.text((x, y), t, font=font, fill=fg)
    y += line_h

img = img.resize((W*scale, H*scale), Image.NEAREST)
img.save("/tmp/grace-waitlist-title.png")
print("saved", img.size)
