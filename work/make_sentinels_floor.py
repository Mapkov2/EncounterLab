"""Bake original vector stonework; no reference pixels or game assets as input."""
from pathlib import Path
import subprocess, random, struct
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parent
rows=subprocess.check_output(['lua',str(root/'sentinels_floor.lua')],text=True).splitlines()
size=1024
im=Image.new('RGB',(size,size));draw=ImageDraw.Draw(im)
svg=[]
for row in rows:
    color,points=row.split('|')
    rgb=tuple(round(float(c)*255) for c in color.split(','))
    xy=list(map(float,points.split(',')))
    points=[((xy[i]+75)/150*size,(68-xy[i+1])/136*size) for i in range(0,len(xy),2)]
    draw.polygon(points,fill=rgb)
    svg.append('<polygon points="'+ ' '.join(f'{x:.3f},{y:.3f}' for x,y in points)+'" fill="rgb'+str(rgb)+'"/>')
# Fine deterministic stone grain, baked once; no per-frame noise or animation.
rng=random.Random(8801);pixels=im.load()
for y in range(size):
    for x in range(size):
        r,g,b=pixels[x,y];noise=rng.randrange(-5,6)
        pixels[x,y]=tuple(max(0,min(255,c+noise)) for c in (r,g,b))
im=im.resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
dest=root/'EncounterLab/Media/SentinelsFloor.tga'
header=struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,512,512,32,40)
dest.write_bytes(header+im.tobytes('raw','BGRA'))
scratch=root/'scratch';scratch.mkdir(exist_ok=True)
im.save(scratch/'sentinels-floor-preview.png')
(scratch/'sentinels-floor.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'+''.join(svg)+'</svg>',encoding='utf-8')
print(f'Original Sentinels floor: {dest.stat().st_size} bytes; {len(rows)} baked polygons.')
