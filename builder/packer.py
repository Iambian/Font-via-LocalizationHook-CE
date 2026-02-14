#!/usr/bin/python3

import os,sys,json,io,unicodedata
from PIL import Image,ImageDraw,ImageFont,ImageOps

def quit(msg):  sys.exit(1 or print(msg))

def largefontsource(img,glyphid):
    s   = ''
    li  = [0]*28
    w,h = img.size
    if w > 12:  w = 12
    if h > 14:  h = 14
    for y in range(h):
        for x in range(w):
            if not img.getpixel((x,y)):
                offset = 2*y + (x > 4)
                if x > 4:   li[offset] |= 1 << abs(x-12)
                else:       li[offset] |= 1 << abs(x-7)
    for a,b in zip(li[0::2],li[1::2]):
        tmpstr = '.db %'+format(a,"08b")+",%"+format(b,"08b")
        if s:
            s += tmpstr + "\n"
        else:
            if ord(glyphid) > 127:
                glyph = unicodedata.name(glyphid)
            else:
                glyph = glyphid
            s += tmpstr +"  ;chr "+glyph+" ["+str(ord(glyphid))+"]\n"
    return s

def smallfontsource(img,glyphid):
    li = [0]*24
    w,h = img.size
    w += 1      #Enforce spacing requirements
    if w>16: w = 16
    if h>12: h = 12
    for y in range(h):
        for x in range(w-1):
            if not img.getpixel((x,y)):
                offset =     2*y + (x//8)
                shift  = abs( 7  -  x%8 )
                li[offset] = li[offset] | (1 << shift)
    s  = '.db ' + str(w) + '            ;chr '
    if ord(glyphid) > 127:
        glyph = unicodedata.name(glyphid)
    else:
        glyph = glyphid
    s += glyph + ' [' + str(ord(glyphid)) + ']\n'
    for a,b in zip(li[0::2],li[1::2]):
        if w>8:
            s += '.db %'+format(a,"08b")+",%"+format(b,"08b")+'\n'
        else:
            s += '.db %'+format(a,"08b")+'\n'
    if w<9:
        s += ".db 0,0,0,0,0,0\n.db 0,0,0,0,0,0\n"
    return s

def packit(fontname,fontsize,encoding,outputname,packerfunct):
    testimg = Image.new("1",(1024,40),1)
    drawimg = ImageDraw.Draw(testimg)
    try:
        fontobj = ImageFont.truetype(fontname,fontsize)
    except:
        fontobj = ImageFont.load(fontname,fontsize)
        #If error at this point, leave unhandled and let it err out
    drawimg.text((0,0),encoding,font=fontobj)
    mainoffset = list(ImageOps.invert(testimg.convert("L",colors=2)).getbbox())
    if packerfunct == smallfontsource:
        if mainoffset[1] > 2:   mainoffset[1] -= 2
        else:                   mainoffset[1] = 0
    with open(outputname,"w") as f:
        for idx,i in enumerate(encoding):
            glyphimg = Image.new('1',(30,30),1)
            ImageDraw.Draw(glyphimg).text((0,0),i,font=fontobj)
            charoffset = ImageOps.invert(glyphimg.convert("L",colors=2)).getbbox()
            if charoffset:
                offset = (charoffset[0],mainoffset[1],charoffset[2],charoffset[3])
                glyphimg = glyphimg.crop(offset)
            s = packerfunct(glyphimg,i)
            f.write(s)
    #yargh.
    
## Json file format: Series of...
#1. Strings indicating typical ASCII encodings
#2. 2-lists composed of [unicode char, ticodepoint]
## Return values
#1. Outputs file encodings.z80 containing TICodepoint-indexed mappings
#2. Returns string of characters that will be printed and written to (l|s)font
## Order of objects in mappings will match order of letters in return string
def reencode(jsonfilename,outputfilename):
    mappings = []   #format: [ (glyph,glyphord,mapstoTICoord) ]
    def codemap(instring):  #default formatting
        m = []
        for c in instring:
            o = ord(c)
            if o > 127:
                raise ValueError("Character "+c+" cannot be automatically tied to a TI codepoint")
            m.append( (c,o,o) )
        return m
    if jsonfilename:
        arr = json.load(open(jsonfilename,"r"))
    else:
        arr = ["0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"]
    for obj in arr:
        if isinstance(obj,str):
            mappings.extend(codemap(obj))
        else:
            c = obj[0]
            m = obj[1]
            if isinstance(c,int):   c = chr(c)
            if isinstance(m,str):   m = ord(m)
            mappings.append( (c,ord(c),m) )
    s = '.db '+str(len(mappings))+' ;numobjs\n'
    glyphs,computer_indices,ticalc_indices = zip(*mappings)
    #There is no 0 index here, so start at 1.
    for cur_index in range(1,256):
        if cur_index in ticalc_indices:
            idx = ticalc_indices.index(cur_index)
            s += '.db $'+format(idx,"02X")
            glyphid = glyphs[idx]
            if ord(glyphid) > 127:
                glyph = unicodedata.name(glyphid)
            else:
                glyph = glyphid
            s += '  ;idx $'+format(cur_index,'02X')+', chr '+glyph
            s += ' [0x'+format(computer_indices[idx],"02X")+']\n'
        else:
            s += '.db $FF  ; idx $'+format(cur_index,'02X')+" not mapped\n"
    with open(outputfilename,'w') as f:
        f.write(s)
    return ''.join( [c[0] for c in mappings] )
''' ~~~~~~~~~~~~~~~~~~~~~~~~~~~ SCRIPT START ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ '''
encodings_in_my_json_file = None
encodings_in_my_json_file = "encoding/asciish.json"

encoding = reencode(encodings_in_my_json_file,"encodings.z80")
packit("fonts/OpenSans.ttf",14,encoding,"lfont.z80",largefontsource)
packit("fonts/OpenSans.ttf",12,encoding,"sfont.z80",smallfontsource)






