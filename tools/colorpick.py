# Converts rgb values to closest matching index on the xlibc color palette
# and returns that value.
def color1555torgb(c:int):
    r = (c>>10)&0x1F
    g = (c>>5)&0x1F
    b = c&0x1F
    r = int(r*255/31)
    g = int(g*255/31)
    b = int(b*255/31)
    return (r,g,b)

def generatepalette():
    palette = []
    for i in range(256):
        palette.append(color1555torgb(i+i*256))
    return palette

def findnearestindex(r, g, b, palette, bias=None):
    # Finds nearest color in palette to given r,g,b values. Bias is a tuple of (r,g,b) that will be added to the distance calculation to prefer certain colors.
    bestindex = 0
    bestdist = 999999
    for i in range(len(palette)):
        pr, pg, pb = palette[i]
        dist = (r-pr)**2 + (g-pg)**2 + (b-pb)**2
        if bias is not None:
            br, bg, bb = bias
            dist += (br-pr)**2 + (bg-pg)**2 + (bb-pb)**2
        if dist < bestdist:
            bestdist = dist
            bestindex = i
    return bestindex

# Usage: python colorpick.py R G B [biasR biasG biasB]
if __name__ == "__main__":
    import sys
    r = int(sys.argv[1])
    g = int(sys.argv[2])
    b = int(sys.argv[3])
    palette = generatepalette()
    bias = None
    if len(sys.argv) == 7:
        bias = (int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]))
    index = findnearestindex(r, g, b, palette, bias)
    print(f"Closest color index for RGB({r}, {g}, {b}) is: {index} with palette color {palette[index]}")
    print(f"Index in hexadecimal: {index:#04x}")
