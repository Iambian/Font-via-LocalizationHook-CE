#!/usr/bin/python3

import os,sys
from PIL import Image,ImageDraw,ImageFont,ImageOps

def quit(msg):
    print(msg)
    sys.exit(1)
def tisource(img,glyphid):
    li = [0]*14*2
    w,h = img.size
    for y in range(h):
        for x in range(w):
            if not img.getpixel((x,y)):
                if x>4:
                    li[2*y+1]   = li[2*y+1] | (1 << abs((x-5)-7))
                else:
                    li[2*y]     = li[2*y]   | (1 << abs(x-7))
    s = ''
    for v1,v2 in zip(li[0::2],li[1::2]):
        t = '.db %'+format(v1,"08b")+",%"+format(v2,"08b")
        if s=='':
            s += t+"   ;id "+glyphid+" ["+str(ord(glyphid))+"]\r\n"
        else:
            s += t + "\r\n"
    return s

#Could also use mode "L" for 8bpp gs. Change bg to 255 if you do this.
img = Image.new("1",(1024,40),1)    #wide image for large string, bg white
draw = ImageDraw.Draw(img)

if len(sys.argv) > 1:   arg1 = sys.argv[1]  #Input filename
if len(sys.argv) > 2:   arg2 = sys.argv[2]
if len(sys.argv) > 3:   arg3 = sys.argv[3]

'''DEBUG'''
arg1 = "comic.ttf"
arg2 = 10
'''ENDDEBUG'''

if arg1:    fontname = arg1
else:       quit("Input font filename required")
if arg2:    fontsize = int(arg2)
else:       fontsize = 12

ext = os.path.splitext(arg1)[1]
if ext in (".ttf",".otf"):    func = ImageFont.truetype
else:                       func = ImageFont.load

font = func(arg1,fontsize)
thing = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
draw.text((0,0),thing,font=font)
mainoffset = ImageOps.invert(img.convert("L")).getbbox()
cimg = img.crop(mainoffset)
#cimg.show()
objarr = []
f = open("output.txt","w")
print(mainoffset)
for idx,i in enumerate(thing):
    timg = Image.new("1",(30,30),1)    #wide image for large string, bg white
    tdraw = ImageDraw.Draw(timg)
    tdraw.text((0,0),i,font=font)
    suboffset = ImageOps.invert(timg.convert("L")).getbbox()
    offset = (suboffset[0],mainoffset[1],suboffset[2],suboffset[3])
    ttimg = timg.crop(offset)
    f.write(tisource(ttimg,i))
f.close()
print("File output")    
    



