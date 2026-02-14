import os,sys
#binconv: Converts binary file to .8xp/.8xv source
#
#
infile  = os.path.normpath(sys.argv[1])
outfile = os.path.normpath(sys.argv[2])
filename= os.path.splitext(os.path.split(outfile)[1])[0]
fileext = os.path.splitext(outfile)[1].lower()

with open(infile,"rb") as f:
    filedata = f.read()
   
TI_VAR_PROG_TYPE = 0x05
TI_VAR_PROTPROG_TYPE = 0x06
TI_VAR_APPVAR_TYPE = 0x15
TI_VAR_FLAG_RAM = 0x00
TI_VAR_FLAG_ARCHIVED = 0x80

if fileext == ".8xp":
    TI_VARTYPE = TI_VAR_PROTPROG_TYPE
    filename = filename.upper()
elif fileext == ".8xv":
    TI_VARTYPE = TI_VAR_APPVAR_TYPE
else:
    raise ValueError("Given target type "+fileext+", expected .8xv or .8xp")

# Ensure that filedata is a string
filedata = bytearray(filedata)
# Add size bytes to file data as per (PROT)PROG/APPVAR data structure
dsl = len(filedata)&0xFF
dsh = (len(filedata)>>8)&0xFF
filedata = bytearray([dsl,dsh])+filedata
# Construct variable header
vsl = len(filedata)&0xFF
vsh = (len(filedata)>>8)&0xFF
vh  = bytearray([0x0D,0x00,vsl,vsh,TI_VARTYPE])
vh += bytearray(filename.ljust(8,'\x00')[:8].encode("ascii"))
vh += bytearray([0x00,TI_VAR_FLAG_RAM,vsl,vsh])
# Pull together variable metadata for TI8X file header
varentry = vh + filedata
varsizel = len(varentry)&0xFF
varsizeh = (len(varentry)>>8)&0xFF
varchksum = sum([i for i in varentry])
vchkl = varchksum&0xFF
vchkh = (varchksum>>8)&0xFF
# Construct TI8X file header
h  = "**TI83F*".encode("ascii")
h += bytearray([0x1A,0x0A,0x00])
#Always makes comments exactly 42 chars wide.
h += "Rawr. Gravy. Steaks. Cherries!".ljust(42)[:42].encode("ascii")
h += bytearray([varsizel,varsizeh])
h += varentry
h += bytearray([vchkl,vchkh])
# Write data out to file
with open(outfile,"wb") as f:
    f.write(h)
#

