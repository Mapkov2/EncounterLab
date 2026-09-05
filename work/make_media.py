"""Original procedural UI textures. No input images or third-party assets."""
import math
import pathlib
import struct

root = pathlib.Path(__file__).parent / "EncounterLab" / "Media"
root.mkdir(exist_ok=True)

def write_tga(name, size, paint):
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            rgba = paint((x + .5) / size * 2 - 1, (y + .5) / size * 2 - 1)
            r, g, b, a = (max(0, min(255, round(c))) for c in rgba)
            pixels.extend((b, g, r, a))
    # Uncompressed 32-bit BGRA, top-left origin, 8-bit alpha.
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 40)
    (root / name).write_bytes(header + pixels)

def lava(x, y):
    r = math.hypot(x, y)
    edge = max(0, min(1, (1-r)*18))
    angle = math.atan2(y,x)
    flow = math.sin(18*x + 7*math.sin(5*y)) * math.sin(16*y + 4*math.cos(6*x))
    hot = max(0, 1-abs(flow)*3.3)
    rim = max(0, 1-abs(r-.87)*15)
    pulse = .82+.18*math.sin(angle*8+r*31)
    return 100+145*max(hot,rim), 16+118*hot+35*rim, 4+22*hot, 220*edge*pulse

def wave(x,y):
    r=math.hypot(x,y)
    edge=max(0,min(1,(1-r)*14))
    ring=math.exp(-((r-.66)*5)**2)
    core=max(0,1-r*1.3)
    streak=.7+.3*math.sin(27*x+math.sin(y*11)*3)*math.cos(y*17)
    return 255, 95+120*ring+35*core, 12+80*core, edge*(80+150*ring)*streak

def floor(x,y):
    grain=(math.sin(x*97+y*137)+math.sin(x*49-y*81))*.5
    crack=math.exp(-abs(math.sin(6*x+math.cos(4*y)))*32)
    return 49+grain*5+crack*9, 39+grain*4+crack*3, 35+grain*3, 255

def rounded_mask(x,y):
    # Original antialiased 32px rounded rectangle; 8px slices keep 6px corners.
    qx, qy = abs(x*16)-10, abs(y*16)-10
    distance = math.hypot(max(qx,0),max(qy,0))+min(max(qx,qy),0)-6
    return 255,255,255,max(0,min(1,.5-distance))*255

write_tga('LavaPool.tga',128,lava)
write_tga('LavaWave.tga',128,wave)
write_tga('Basalt.tga',64,floor)
write_tga('RoundedMask.tga',32,rounded_mask)
print('Generated 4 original TGA textures:', sum(p.stat().st_size for p in root.glob('*.tga')), 'bytes')
