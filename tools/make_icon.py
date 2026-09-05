"""Draw the original EncounterLab project icon. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw
import math

size=1024
im=Image.new('RGB',(size,size),'#050d18')
d=ImageDraw.Draw(im)
d.rounded_rectangle((32,32,992,992),radius=130,fill='#081726',outline='#284768',width=8)
d.ellipse((156,156,868,868),outline='#367cd6',width=28)
d.arc((208,208,816,816),210,330,fill='#e7ae59',width=40)
d.polygon([(512,310),(558,391),(466,391)],fill='#f3c06f')
# A simple E/L monogram, drawn as geometry rather than a bundled font.
for box in [(300,432,348,685),(348,432,490,478),(348,536,466,580),(348,639,490,685),
            (553,432,601,685),(601,639,741,685)]:
    d.rectangle(box,fill='#edf3fa')
for angle in (30,150,270):
    x=512+356*math.cos(math.radians(angle));y=512+356*math.sin(math.radians(angle))
    d.ellipse((x-29,y-29,x+29,y+29),fill='#72b8ff',outline='#081726',width=8)
out=Path(__file__).resolve().parents[1]/'docs/encounterlab-icon.png'
out.parent.mkdir(parents=True,exist_ok=True)
im.resize((512,512),Image.Resampling.LANCZOS).save(out)
print(out)
