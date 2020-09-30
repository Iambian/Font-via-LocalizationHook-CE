#!/usr/bin/python3

import os,sys
from PIL import Image,ImageDraw,ImageFont,ImageOps

def quit(msg):
    print(msg)
    sys.exit(1)
def tisource(img,glyphid):
    li = [0]*14*2
    w,h = img.size
    if w>12: w = 12
    if h>14: h = 14
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
            s += t+"   ;id "+glyphid+" ["+str(ord(glyphid))+"]\n"
        else:
            s += t + "\n"
    return s
def smallfontsource(img,glyphid):
    li = [0]*12*2
    w,h = img.size
    if w>16: w = 16
    if h>12: h = 12
    for y in range(h):
        for x in range(w):
            if not img.getpixel((x,y)):
                ofs = x//8
                li[2*y+ofs] = li[2*y+ofs] | (1 << abs(7-x%8))
    s = '.db '+str(img.size[0]+1)+'             ;id '+glyphid+" ["+str(ord(glyphid))+"]\n"
    w = w+1  #Enforce spacing
    for v1,v2 in zip(li[0::2],li[1::2]):
        if w>8:
            t = '.db %'+format(v1,"08b")+",%"+format(v2,"08b")
        else:
            t = '.db %'+format(v1,"08b")
        s += t + "\n"
    if w<9:
        s += ".db 0,0,0,0,0,0\n.db 0,0,0,0,0,0\n"
    return s
    pass
    
    
def packit(fontname="klingon2.ttf",fontsize=14,resource=None,outputname="output.txt",packfunc=None):
    img = Image.new("1",(1024,40),1)    #wide image for large string, bg white
    draw = ImageDraw.Draw(img)
    if os.path.splitext(fontname)[1] in (".ttf",".otf"):
            func = ImageFont.truetype
    else:   func = ImageFont.load
    encodestring = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    font = func(fontname,fontsize)
    draw.text((0,0),encodestring,font=font)
    mofst = list(ImageOps.invert(img.convert("L",colors=2)).getbbox())
    if packfunc==smallfontsource:
        if mofst[1] > 2:    mofst[1] -= 2
        else:               mofst[1] =  0
    f = open(outputname,"w")
    for idx,i in enumerate(encodestring):
        timg = Image.new("1",(30,30),1)    #wide image for large string, bg white
        tdraw = ImageDraw.Draw(timg)
        tdraw.text((0,0),i,font=font)
        sofst = ImageOps.invert(timg.convert("L",colors=2)).getbbox()
        if sofst:
            offset = (sofst[0],mofst[1],sofst[2],sofst[3])
            ttimg = timg.crop(offset)
        else:
            ttimg = timg
        f.write(packfunc(ttimg,i))
    f.close()
    
    
    
#Program starts here:    
packit("klingon2.ttf",14,None,"output.txt",tisource)
packit("klingon2.ttf",12,None,"output2.txt",smallfontsource)


