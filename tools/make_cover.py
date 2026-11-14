"""Builds the itch.io cover image (itch/cover.png, 630x500) from the game's own sprites.

Run from the project folder:   python tools/make_cover.py itch/cover.png      (needs: pip install pillow)
If a sprite is replaced, run it again to update the cover.
"""
import random, math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
W,H,S=210,167,3
A='art/'
def frame(path,w,i=0):
    im=Image.open(A+path).convert('RGBA'); return im.crop((i*w,0,(i+1)*w,im.height))
def tile(sheet,c,r): return sheet.crop((c*16,r*16,c*16+16,r*16+16))
ash=Image.open(A+'tiles/biome_ashen.png').convert('RGBA')
img=Image.new('RGBA',(W,H),(14,11,16,255))
# floor
for y in range(0,H,16):
    for x in range(0,W,16):
        t=random.choice([(0,0),(0,0),(1,0),(2,0),(3,0)])
        img.paste(tile(ash,*t),(x,y))
# lava river across the bottom-right
for x in range(0,W,16):
    yy=128+int(6*math.sin(x/30))
    for dy in (0,16):
        img.paste(tile(ash,6+(x//16+dy//16)%2,0),(x,yy+dy))
# wall band at top
for x in range(0,W,16):
    img.paste(tile(ash,0,1),(x,0)); img.paste(tile(ash,0,1),(x,16))
# darken + vignette
dark=Image.new('RGBA',(W,H),(10,6,12,0)); d=ImageDraw.Draw(dark)
for y in range(H):
    for x in range(W):
        dx=(x-W*0.55)/(W*0.7); dy=(y-H*0.6)/(H*0.75)
        a=int(min(1,(dx*dx+dy*dy))*200)+70
        d.point((x,y),(10,6,12,min(a,235)))
img=Image.alpha_composite(img,dark)
# glow under lava
glow=Image.new('RGBA',(W,H),(0,0,0,0)); g=ImageDraw.Draw(glow)
g.rectangle((0,118,W,H),fill=(255,110,30,70)); glow=glow.filter(ImageFilter.GaussianBlur(10))
img=Image.alpha_composite(img,glow)
def shadow(cx,y,w):
    sh=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(sh).ellipse((cx-w//2,y-3,cx+w//2,y+3),fill=(0,0,0,120)); return sh
def place(im,cx,feet,flip=False,alpha=255,tint=None):
    global img
    if flip: im=im.transpose(Image.FLIP_LEFT_RIGHT)
    if tint:
        r,gc,b,a=im.split(); t=Image.new('RGBA',im.size,tint); t.putalpha(a); im=Image.blend(im,t,0.55); 
    if alpha<255:
        a=im.getchannel('A').point(lambda v:v*alpha//255); im.putalpha(a)
    img=Image.alpha_composite(img,shadow(cx,feet,max(10,im.width//2)))
    lay=Image.new('RGBA',(W,H),(0,0,0,0)); lay.paste(im,(cx-im.width//2,feet-im.height),im); img=Image.alpha_composite(img,lay)
# background bosses (dim)
# Tyrant, big on the right
ty=frame('enemies/tyrant/tyrant_idle.png',64).resize((96,108),Image.NEAREST)
fg=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(fg).ellipse((120,60,210,150),fill=(255,90,20,90)); fg=fg.filter(ImageFilter.GaussianBlur(14)); img=Image.alpha_composite(img,fg)
place(ty,165,150,flip=True)
# minions
place(frame('enemies/spirit/spirit_idle.png',12),92,124)
place(frame('enemies/spirit/spirit_idle.png',12),118,136,flip=True)
place(frame('enemies/charger/charger_idle.png',16),130,152,flip=True)
place(frame('enemies/crawler/crawler_idle.png',16),106,158,flip=True)
# player, with a heroic glow
pg=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(pg).ellipse((40,118,84,160),fill=(255,220,140,70)); pg=pg.filter(ImageFilter.GaussianBlur(7)); img=Image.alpha_composite(img,pg)
place(frame('player/player_idle.png',16),62,152)
# bullets from player toward tyrant
bul=frame('projectiles/player_bullet_spin.png',8)
for i,(bx,by) in enumerate([(76,138),(90,133),(104,128)]):
    lay=Image.new('RGBA',(W,H),(0,0,0,0)); lay.paste(bul,(bx,by),bul); img=Image.alpha_composite(img,lay)
# ash pickups
ashp=frame('pickups/ash_idle.png',8)
for p in [(30,150),(44,160),(84,158)]:
    lay=Image.new('RGBA',(W,H),(0,0,0,0)); lay.paste(ashp,p,ashp); img=Image.alpha_composite(img,lay)
# embers
e=ImageDraw.Draw(img)
for _ in range(60):
    x=random.randrange(W); y=random.randrange(20,H)
    c=random.choice([(255,180,80,255),(255,120,40,230),(255,220,140,200)])
    e.point((x,y),c)
    if random.random()<0.3: e.point((x,y-1),(c[0],c[1],c[2],120))
# title
def text_layer(txt,size,font,fill,outline,y,shadow_col=(58,20,8,255)):
    global img
    f=ImageFont.truetype(font,size)
    m=Image.new('L',(W,H),0); md=ImageDraw.Draw(m); md.fontmode='1'
    bb=md.textbbox((0,0),txt,font=f); tw=bb[2]-bb[0]; x=(W-tw)//2-bb[0]
    md.text((x,y-bb[1]),txt,font=f,fill=255)
    m=m.point(lambda v:255 if v>127 else 0)
    def solid(mask,col,off=(0,0)):
        lay=Image.new('RGBA',(W,H),col); a=Image.new('L',(W,H),0); a.paste(mask,off); lay.putalpha(a); return lay
    out=m.filter(ImageFilter.MaxFilter(3))
    img=Image.alpha_composite(img,solid(out.filter(ImageFilter.MaxFilter(3)),(0,0,0,255),(0,2)))
    img=Image.alpha_composite(img,solid(out,outline))
    # vertical gradient fill
    grad=Image.new('RGBA',(W,H)); gd=ImageDraw.Draw(grad)
    for yy in range(H):
        t=min(1,max(0,(yy-y)/(size*0.9)))
        gd.line((0,yy,W,yy),fill=(int(255-20*t),int(224-110*t),int(138-100*t),255))
    gm=grad.copy(); gm.putalpha(m) if fill is None else None
    if fill is None: img=Image.alpha_composite(img,gm)
    else: img=Image.alpha_composite(img,solid(m,fill))
text_layer('ASHBORN',34,'/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf',None,(58,20,8,255),12)
text_layer('DIE  -  BOUNCE BACK  -  RISE STRONGER',9,'/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf',(235,215,200,255),(20,10,14,255),52)
out=img.resize((W*S,H*S),Image.NEAREST).crop((0,0,630,500)).convert('RGB')
out.save(sys.argv[1]); print(out.size)
