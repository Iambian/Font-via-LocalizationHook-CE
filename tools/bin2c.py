import os,sys,math

if len(sys.argv) < 3:
    print("Usage: py bin2c.py <input.bin> <output.h>")
    os.exit()

infile = os.path.normpath(sys.argv[1])
outfile = os.path.normpath(sys.argv[2])

with open(infile,"rb") as f:
    b = bytearray(f.read())
s = "#include <stdint.h>\n\n"
s += "uint8_t "
s += os.path.splitext(os.path.split(outfile)[1])[0]
s += "[] {\n";
idx = 0
for i in range(int(math.ceil(len(b)/16))):
    for j in range(16):
        v = b[idx]
        idx += 1
        if (idx == len(b)): break
        s += "0x" + format(v,"02X") + ","
    s += "\n"
s += "};\n\n"
with open(outfile,"w") as f:
    f.write(s)
        
        
        
        
