; Utility for BASIC programs to edit localization hook font objects.
; Eventually to be merged into Font-Via-LocalizationHook-CE repository.
;
;Inputs:
;Str0 = name of font object to find. (prefix with `rowSwap(` token to locate appvars)
;[J] = Matrix, if writing. Else, see output.
;Ans = Combined glyph and mode selector:
;   0-255      = Large font glyph to read and write
;   Ans+256    = Small font glyph to read and write
;   Ans+1000   = Enable write mode.
;
;Outputs:
;[J] = Matrix, if reading, else unchanged.
;Ans = 0 if successful, else error code, as (much further) below
;

.assume adl=1
#include "../include/ti84pce.inc"
#include "../include/macros.inc"
;-----------------------------------------------------------------------------

#define ERR_OK 0
#define ERR_OOM_ON_FONT_CREATE 1
#define ERR_INVALID_GLYPH 2
#define ERR_GLYPH_NOT_FOUND 3
#define ERR_OOM_OTHER 4
#define ERR_MATRIX_DIM_MISMATCH 5
#define ERR_MATRIX_COLS_OUT_OF_RANGE 6
#define ERR_FONT_NOT_FOUND 7
#define ERR_FONT_FILE_CORRUPTED 8
#define ERR_STRING_NOT_FOUND 9
#define ERR_MATRIX_CREATE_FAILED 10
#define ERR_INVALID_STRING_INPUT 11
#define ERR_MATRIX_NOT_FOUND 12
#define ERR_FILE_ARCHIVED 13
;
#define ERR_NOT_IMPLEMENTED_YET 99
;---
#define MATRIX_DIMS(width,height) (((height)<<8)|(width))
#define LARGE_GLYPH_HEIGHT 14
#define LARGE_GLYPH_WIDTH 12
#define SMALL_GLYPH_HEIGHT 12
;Small font objects are variable-width. There is no fixed width define.
;The define below assumes you are setting the width in L and the height in H.
;We don't do anything more complex because SPASM-ng won't let us define
;macros using registers as parameters.
#define SET_MATRIX_HEIGHT(height) ld  h,height


#define SAFERAM_START pixelShadow
#define SAFERAM_SIZE 25200

#define SIZEOF_LARGE_GLYPH 28
#define SIZEOF_SMALL_GLYPH 25
;-----------------------------------------------------------------------------
;Statically-allocated variables
;Using pixelShadow as BSS. Combined with adjacent pixelShadow2
;and cmdPixelShadow, this gives us 25200 bytes of storage space.
;Turns out, a copy of a fully-mapped font file takes a little over half of
;that. Those generated 5KB font files in comparison are pretty empty.
;Who would've thought?

var_SP       = SAFERAM_START   ;3b, stores SP for quick exit on error.
fontFileSize = var_SP+3        ;3b, font file size.
glyphID      = fontFileSize+3  ;1b, glyph ID. 0-255. Valid values: [1-249]
glyphIsSmall = glyphID+1       ;2b, glyph size flag. 0=large, 1=small.
.assert(glyphIsSmall == (glyphID+1), "glyphIsSmall must be immediately after glyphID due to combined variable writes.")
fontFilePtr  = glyphIsSmall+2  ;3b, Pointer to start of font file in RAM.
glyphLUTPtr  = fontFilePtr+3   ;3b, Pointer to glyph LUT in file.
largeFontPtr = glyphLUTPtr+3   ;3b, Pointer to large font data table in file.
.assert(largeFontPtr >= (glyphIsSmall+2), "largeFontPtr must be at least 2 bytes after glyphIsSmall to avoid overlap.")
largeFontSize= largeFontPtr+3  ;3b, Size of large font data table in file.
smallFontPtr = largeFontSize+3 ;3b, Pointer to small font data table in file.
unusedEntries= smallFontPtr+3  ;256b. Temp table used to store unused entries in glyphTable

reserved     = unusedEntries+256 ;0b. Used to avoid having to modify the stuff below.
;--
;256 byte: Glyph LUT.
;The first byte is a size byte indicating how many glyphs are currently mapped.
;The next 255 bytes are... a little complicated. This array is treated as
;1-indexed (or 0-indexed assuming the 0th entry is invalid for the purposes of
;glyph ID mapping). This means from the beginning of glyphTable, something like
;`glyphTable+'A'` would give us the byte that maps the codepoint 'A' to a glyph
;index. As a result, codepoint 0 is unmappable. It shouldn't be a problem but
;the TI-OS actually maps it to something. 
;The value at that byte is the index of the glyph data for that codepoint.
;If the value is $FF, then that codepoint is not mapped to any glyph.

;Indexed by GlyphID, value is index to glyph data. $FF=empty.
;The first byte is a size byte indicating how many glyphs are currently mapped.
;Technically redundant, but it vastly accelerates glyph lookup.
glyphTable   = reserved        ;
;7140 byte: Large glyph table. Fixed-size, 255 entries (index 255 not mapped)
glyphDataL   = glyphTable+256  ;
;6375 byte: Small glyph table. Fixed-size, 255 entries (index 255 not mapped)
glyphDataS   = glyphDataL+(255*SIZEOF_LARGE_GLYPH) ;
;If we need to stick anything after this, append the stuff below after the '='
;sign. Please don't do that. Put any additional variables before glyphTable,
;then update the pointers around it accordingly.
;glyphDataS+(255*SIZEOF_SMALL_GLYPH)
;-----------------------------------------------------------------------------
.org userMem-2
.db $EF, $7B

programStart:
    ld  (var_SP),sp
    ld  (errorOverrideEnd_SMC_from_errorOverride),sp
    ld  hl,err_OK
    push hl         ;Return address for no errors: Error handler returns zero.
    call _RclAns
    call _ConvOP1   ;out: DE=Ans, A=E.
    ld  hl,1000
    or  a,a
    sbc hl,de   ;If ANS was less than 1000, carry is not set and we should read.
    push af     ;So we can test the same condition twice.
        ex  de,hl   ;After: read path: original in HL. write path: Extract value from DE.
        jr  nc,+_   ;If 1000>Ans, then Ans is in range. Skip.
        ;Else HL= 1000-Ans, which is negative by what we want.
        or  a,a
        sbc hl,hl
        sbc hl,de   ;This sequence negates DE, returning it to a positive value.
_:      ld  a,h
        add a,$FF   ;Large is not carry, small (nonzero value) is carry
        ccf         ;now large font == carry.
        sbc a,a     ;Small is 0, large is $FF
        inc a       ;Small is 1, large is 0
        ld  h,a     
        ld  (glyphID),hl    ;Loading both glyphID and glyphIsSmall at same time.
        ld  a,L
        or  a,a
        jp  z,err_InvalidGlyph  ;Glyph ID cannot be zero.
    pop af
    jp  c,main_writeMode
main_readMode:
    call findNameInString    ;throws appropriate errors. No overrides.
    call populateGlyphTables ;populates glyphTable, glyphDataL, and glyphDataS.
    call locateGlyphData     ;Z=notfound, else: CA=1: small glyph.
    jp  z,err_GlyphNotFound
    push hl
        push de
            push de
            pop hl
            push af
                call createMatrix
            pop af
            inc de
            inc de
        pop bc      ;dims-> BC
        jr  c,+_
        ld  L,5 ;first loop count
        ld  h,7 ;second loop count
        jr  ++_
_:      ld  a,c
        ld  L,a     ;Loop limit of first byte of glyph data row.
        ld  h,0     ;Loop limit of second byte of glyph data row.
        cp  a,9     ;if carry (width <= 8), skip past pair adjusting.
        jr  c,+_
        ld  L,8
        sub a,8
        ld  h,a
_:  pop ix
    ld  a,b     ;height
    ;DE=ptr to matrix data, IX=ptr to glyph data. A=outer loop count. BC=dims 
main_readMode_collectLoop:
    push af
        ld  a,(ix+0)
        inc ix
        ld  b,L
        push hl
            call writeBitsToMatrix
        pop hl
        inc h       ;This sequence checks if H was zero. Compacting only occurs
        dec h       ;in small font cases. The branch never takes in large font cases.
        jr  z,+_
        ld  a,(ix+0)
        inc ix
        ld  b,H
        push hl
            call writeBitsToMatrix
        pop hl
_:  pop af
    dec a
    jr  nz,main_readMode_collectLoop
    ret

;---
main_writeMode:
    ld  hl,main_writeMode_maybeCreateNewFile
    call errorOverride
    call findNameInString   ;If errors, try to handle them
    call errorOverrideEnd
    jr  main_writeMode_fileFound
main_writeMode_maybeCreateNewFile:
    cp  a,ERR_FONT_NOT_FOUND
    jp  nz,errorHandler     ;reraise error if any other error
    ;Create new font file with no entries.
    ;NOTE: OP1 is already loaded with the name of the file from findNameInString
    ld  hl,fontObj_stubEnd-fontObj_stubStart+(256+7+8)   ;stub size + glyph LUT + max VAT size
    call _EnoughMem
    jp  c,err_OOM_OnFontCreate
    ld  a,(OP1)     ;Must create a file using the appropriate call type.
    ld  hl,fontObj_stubEnd-fontObj_stubStart+(256+0)    ;stub size + glyph LUT
    call _CreateVar ;...or use a generic call that does the same thing.
    ;NOTE: DE points to data size bytes.
    inc de
    inc de
    ld  hl,fontObj_stubStart
    ld  bc,fontObj_stubEnd-fontObj_stubStart
    ldir         ;write stub to file
    xor a,a
    ld  (de),a   ;Set size to zero, indicating no font entries.
    inc de
    dec a        ;All entries unmapped ($FF)
    ld  b,255
_:  ld  (de),a   ;Set all glyph LUT entries to unmapped.
    inc de
    djnz -_
    ;Glyph table initialized and set to empty.
    jr  main_writeMode  ;Retry lookup to pull down pointers.
main_writeMode_fileFound:
    ;OK. We now have a file, regardless of whether nor not it existed.
    ld  de,(fontFilePtr)
    call _ChkInRam
    jp  nz,err_FileArchived   ;Font file must be in RAM to write to these.
    call populateGlyphTables  ;populates glyphTable, glyphDataL, and glyphDataS.
    ; Verify that the matrix exists and they are the right size.
    call findMatrix
    jp  c,err_MatrixNotFound
    call _ChkInRam  ;in: DE=fileaddr, out: Z=RAM, NZ=Archive. Destroys: None.
    jp  nz,err_FileArchived ;Matrix must be in RAM. What kind of monster archives this, anyhow?
    ld  a,(glyphIsSmall)
    or  a,a
    jr  nz,+_   ;if small, jump to small matrix size check
    ;load large matrix size check
    ld  a,(de)  ;width
    cp  a,LARGE_GLYPH_WIDTH
    jp  nz,err_MatrixDimMismatch
    inc de
    ld  a,(de)  ;height
    cp  a,LARGE_GLYPH_HEIGHT
    jp  nz,err_MatrixDimMismatch
    jr ++_
_:  ;load small matrix size check
    ld  a,(de)  ;width
    cp  a,17
    jp  nc,err_MatrixColsOutOfRange
    or  a,a
    jp  z,err_MatrixDimMismatch     ;do not allow a zero-width glyph.
    inc de
    ld  a,(de)  ;height
    cp  a,SMALL_GLYPH_HEIGHT
    jp  nz,err_MatrixDimMismatch
_:  ;Matrix exists and is the right size. We can now prep reading the matrix to write glyph data.
    inc de      ;DE now points to matrix data, ready for reading.
    ;We are now prepared to begin reading the font file in earnest.
    push de
        call locateGlyphData     ;Z=notfound, else: CA=1: small glyph.
        ld  (ix),c  ;If it wasn't mapped, this glyph is now mapped.
        push hl
        pop ix
    pop hl
    push af     ;save code point state at since table was (potentially) modified.
;Register state:
;HL = pointer to matrix data
;IX = glyph data pointer
;C = codepoint
;B = glyph index (if mapped, B == C, else B == 0)
;E = width, D = height
        jr  c,main_writeMode_writeSmallGlyph
_:      push de
            ld  b,5
            call readBitsFromMatrix
            ld  (ix+0),c
            ld  b,7
            call readBitsFromMatrix
            ld  (ix+1),c
            lea ix,ix+2
        pop de
        dec d
        jr  nz,-_
        jr  main_writeMode_writeCollect
main_writeMode_writeSmallGlyph:
        dec hl
        dec hl
        ld  e,(hl)  ;we need to re-fetch width. The version we have in E might not
        inc hl      ;be accurate whether or not the glyph was mapped. Especially if not.
        inc hl
        ld  (ix-1),e  ;Let's update width in the glyph data table now.
_:      push de
            ld  a,e
            cp  a,9
            jr  c,$+4   ;Carry means width <= 8. Skip clamping.
            ld  e,8     ;Clamp to 8 for this byte, since a byte only has 8 bits.
            ld  b,e
            call readBitsFromMatrix
            ld  (ix+0),c
            inc ix
        pop de
        push de
            ld  a,e
            sub a,9
            jr  c,+_    ;if carry, width is less than 8 so we skip writing the second byte.
            inc a       ;otherwise, we adjust second byte to be in 1-8 range.
            ld  b,a
            call readBitsFromMatrix
            ld  (ix+0),c
            inc ix
_:      pop de
        dec d
        jr  nz,--_
main_writeMode_writeCollect:
    ;NOTE: The push/pop AF sequence preserves the Z/NZ state of the initial
    ;glyph lookup, which indicates whether or not the glyph was previously mapped.
    pop af
    jr  nz,+_       ;Skip if found since existing data won't cause a RAM delta.
    ; If it wasn't mapped, verify that the new glyph data will fit, then insert
    ; the needed memory into the file. The file will be overwritten in-place.
    ld  hl,SIZEOF_LARGE_GLYPH+SIZEOF_SMALL_GLYPH
    push hl
        call _EnoughMem ;Verify that we have enough memory to insert new data.
        jp  c,err_OOM_OnFontCreate
    pop hl
    ld  de,(largeFontPtr)
    push hl
        call _InsertMem  ;in: HL=size, DE=insertion point. Out: DE=intact.
    pop de
    ld  ix,(fontFilePtr)
    or  a,a
    sbc hl,hl   ;zeroes out HLU, since size is uint16_t
    ld  L,(ix+0)
    ld  H,(ix+1)
    add hl,de
    ld (ix+0),L
    ld (ix+1),H   ;Update file pointer to account for new data.
    ld  hl,(smallFontPtr)
    ld  bc,SIZEOF_LARGE_GLYPH
    add hl,bc
    ld  (smallFontPtr),hl   ;move small font pointer up to account for new glyph data.
_:  ;Perform compacting operation.
    ;Steps to operation. Iterating over internal glyph table.
    ;init:  curglyphcount = 0, codepoint = 1
    ;If internalLUT[codepoint] mapped:
    ;   curglyphcount -> externalLUT[codepoint]
    ;   internalLFontData[codepoint] -> externalLFontData[curglyphcount]
    ;   internalSFontData[codepoint] -> externalSFontData[curglyphcount]
    ;   curglyphcount++
    ;else:
    ;   externalLUT[codepoint] = $FF (unmapped)
    ;end;
    ;curglyphcount -> externalLUT[0]
    ;
    ;NOTE: Too many pointers.
    ;
    push iy
        ld  b,0
        ld  c,1
        ld  ix,glyphTable       ;pointer to internal LUT
        ld  iy,(glyphLUTPtr)    ;file glyph LUT pointer
main_writeMode_writeToFile_loop:
        inc ix
        ld  a,(ix)      ;Check if internal codepoint is mapped.
        or  a,a         ;internal unmapped is byte $00.
        jr  z,main_writeMode_writeToFile_unmapped
        ;Mapped. Write to file.
        push bc         ;Preserve codepoint in BC for writing glyph data after LUT update.
            ;B=curglyphcount, C=codepoint
            inc iy
            ld  (iy),b     ;Write glyph index to file LUT.
            ;Calculate LFont position in file.
            ld  d,SIZEOF_LARGE_GLYPH
            ld  e,b
            mlt de
            ld  hl,(largeFontPtr)
            add hl,de
            ex  de,hl       ;DE now write pointer
            ld  b,SIZEOF_LARGE_GLYPH
            mlt bc
            ld  hl,glyphDataL
            add hl,bc       ;HL now read pointer
            ld  bc,SIZEOF_LARGE_GLYPH
            ldir
        pop bc
        push bc
            ;Calculate SFont position in file.
            ld  d,SIZEOF_SMALL_GLYPH
            ld  e,b
            mlt de
            ld  hl,(smallFontPtr)
            add hl,de
            ex  de,hl       ;DE now write pointer
            ld  b,SIZEOF_SMALL_GLYPH
            mlt bc
            ld  hl,glyphDataS
            add hl,bc       ;HL now read pointer
            ld  bc,SIZEOF_SMALL_GLYPH
            ldir
        pop bc          ;Restore codepoint to BC for next iteration and potential unmapped handling.
        inc b           ;Advance glyph count.   
        jr  main_writeMode_writeToFile_collect
main_writeMode_writeToFile_unmapped:
        dec a    ;$00->$FF
        inc iy
        ld  (iy),a
main_writeMode_writeToFile_collect:
        inc c           ;Advance codepoint.
        jr  nz,main_writeMode_writeToFile_loop  ;End when C cycles back to 0
        ld  hl,(glyphLUTPtr)
        ld  (hl),b   ;Write final glyph count to file LUT size byte.
    pop iy
    ;File font data area overwritten. I think we're done.
    ret


;in: A=glyph data byte, B=bits to write (RLCA), DE=pointer to matrix data
;out: DE=pointer advanced to next mantissa to write.
;destroys: HL, Af
;NOTE: ABI for OP1Set0 and OP1Set1 says only A and HL are destroyed.
writeBitsToMatrix:
    rlca
    push af \ call nc,_OP1Set0 \ pop af
    push af \ call c,_OP1Set1 \ pop af
    push bc
        push ix     ;Doesn't destroy IX, but ABI doesn't guarantee this.
            call _MovFrOP1
        pop ix
    pop bc
    djnz writeBitsToMatrix
    ret


;in: B=bits to read, HL=pointer to matrix data
;out: C=glyph data byte, left-aligned
;destroys: DE
readBitsFromMatrix:
    ld  a,8
    sub a,b ;if B was less than 8, we need to know how many leftover to finish shifting.
    push af
_:      push bc
            call _Mov9ToOP1 ;copy from HL to OP1, advancing HL.
            push hl
                push ix
                    call _ConvOP1   ;destroys all reg. OP1->DE/A
                pop ix
                sub  a,1            ;This sequence gets us the desired
                ccf                 ;shiftable bit in carry.
            pop hl
        pop bc
        rl c
        djnz -_
    pop af
    jr  z,++_
    ld  b,a     ;if width was 8, this would've been zero. If not, running this
_:  sla c       ;finishes the left-alignment of C.
    djnz -_     ;I only slightly apologize for all these local labels.
_:  ret

;inputs: Must run populateGlyphTables first. Reads from (glyphID), et al.
;outputs: 
; HL = pointer to glyph data table entry
; E = width, D = height. C = codepoint, B = glyph index (if mapped, B == C)
; IX = pointer to glyph table entry (for updating mapping on write)
; Carry set if small font, reset if large font.
; Zero set (Z) if font entry not mapped (data is uninitialized)
; Zero reset (NZ) if font entry is present (data is initialized)
locateGlyphData:
    ;NOTE: In the interim format, C is both the index and the value at the index.
    ;We're only checking if it's mapped in the glyph table, but the
    ;data table is directly accessed via codepoint, since the tables are not in
    ;its compacted form. Glyphs not mapped with be $00 here.
    ld  bc,(glyphID)    ;B=1 if small. C=codepoint/index
    ld  hl,glyphTable
    ld  de,0
    ld  e,c
    add hl,de       ;E=codepoint/index
    push hl
    pop ix
    ld  a,b         ;isSmall
    ld  b,(hl)      ;B is now indexed status. C is actual index.
    push bc         ;saving glyph index status for z/nz check at end
        or  a,a
        jr  nz,+_   ;jump if small glyph
        ;large glyph
        ld  hl,glyphDataL
        ld  d,SIZEOF_LARGE_GLYPH
        mlt de      ;LGSIZE * ID = offset to that glyph data
        add hl,de
        ld  d,LARGE_GLYPH_HEIGHT
        ld  e,LARGE_GLYPH_WIDTH
        or  a,a     ;clear carry
        jr ++_
_:      ;small glyph
        ld  hl,glyphDataS
        ld  d,SIZEOF_SMALL_GLYPH
        mlt de
        add hl,de
        ld  d,SMALL_GLYPH_HEIGHT
        ld  e,(hl)  ;width, variable
        inc hl
        scf         ;set carry
_:  pop bc
    inc b
    dec b           ;Z=not found, NZ=found
    ret



;in: HL=pointer to font file address section
;out: glyphTable now populated with adjusted mappings to glyph data (OffsetLSB==codepoint)
;glyphDataL and glyphDataS now populated with large and small glyph data, respectively.
;NOTE: glyphTable will be in an interim format that directly maps codepoints to
;glyph indices. Since 0 is not a codepoint, that will be what is used to indicate
;that a glyph is unmapped. Otherwise, its value will be the same as its codepoint.
populateGlyphTables:
    push hl
        ld  hl,glyphTable
        ld  de,glyphTable+1
        ld  bc,(glyphDataS-glyphTable)-1
        xor a,a
        ld  (hl),a
        ldir     ;initialize all tables.
        ;TODO: FIGURE OUT IF THIS INITIALIZATION IS ACTUALLY NEEDED.
        ;FUNCTIONALLY, THE GLYPH TABLE BY ITSELF SHOULD BE SUFFICIENT FOR
        ;ALL VIABLE REFERENCES, AND THE TABLE IS FULLY WRITTEN TO.
    pop hl
    ld  de,(hl)
    add hl,de   ;HL now points to file's glyph LUT
    ld  (glyphLUTPtr),hl
    ld  a,(hl)  ;Preload number of mapped glyphs.
    ;NOTE: The math stops making sense if there are 0 glyphs, but as long as the
    ;table itself shows that nothing is mapped, then it shouldn't be a problem.
    ld  bc,256
    ld  de,glyphTable
    push de
        ldir    ;Copy file glyph LUT to local glyphTable.
        ;Collect file pointer and offset.
        ld  (largeFontPtr),hl       ;file pointer now at start of large glyph data.
        ld  e,a
        ld  d,SIZEOF_LARGE_GLYPH
        mlt de
        ;ld  (largeFontSize),de     ;Uncomment when we are using this.
        add hl,de
        ld  (smallFontPtr),hl   ;file pointer now at start of small glyph data.
    pop de
    inc de
    ld  c,1
    ;This loop also converts the glyph LUT to the interim format.
    ;In: DE=pointer to current glyph LUT entry, C=codepoint/index
    ;
populateGlyphTables_largeLoop:
    ld  a,(de)  ;Retrieves index of glyph data for this codepoint.
    inc a       ;Check if this codepoint was $FF (unmapped).
    jr  z,populateGlyphTables_largeLoop_skip
    dec a       ;Restore from destructive $FF check.
    push de     ;Preserve address to glyph LUT entry.
        push bc ;C=codepoint/index. B not used. Shallow stack for mid-routine recovery.
            ;Begin calculating large glyph write location. Local data table.
            ld  e,SIZEOF_LARGE_GLYPH
            ld  d,c ;codepoint
            mlt de
            ld  hl,glyphDataL
            add hl,de
            ex  de,hl
            ;Begin calculating large glyph read location. File data.
            ld  c,a
            ld  b,SIZEOF_LARGE_GLYPH
            mlt bc
            ld  hl,(largeFontPtr)
            add hl,bc
            ;Copy from file to local data table
            ld  bc,SIZEOF_LARGE_GLYPH
            ldir
        pop bc
        push bc
            ;Begin calculating small glyph write location. Local data table.
            ld  e,SIZEOF_SMALL_GLYPH
            ld  d,c  ;codepoint
            mlt de
            ld  hl,glyphDataS
            add hl,de
            ex  de,hl
            ;Begin calculating small glyph read location. File data.
            ld  c,a
            ld  b,SIZEOF_SMALL_GLYPH
            mlt bc
            ld  hl,(smallFontPtr)
            add hl,bc
            ;Copy from file to local data table
            ld  bc,SIZEOF_SMALL_GLYPH
            ldir
        pop bc
    pop de
    ld  a,c     ;codepoint to set in table.
populateGlyphTables_largeLoop_skip:
    ld  (de),a  ;Write codepoint to interim format glyph LUT. Or unmapped ($00).
    inc de
    inc c
    jr  nz,populateGlyphTables_largeLoop
    ret

;in: Str0 = String containing name of font object.
;out: if success, HL=pointer to font file address section, A=0
;     else raise fatal error with Ans=error code.
;     If program object found, (fontFileSize) = size of object, else 0.
findNameInString:
    or  a,a
    sbc hl,hl
    ld  (fontFileSize),hl
    ld  hl, str0
    call _Mov9ToOP1
    call _FindSym   ;locate the string object
    jp  c,err_StringNotFound
    call _ChkInRam  ;in: DE=fileaddr, out: Z=RAM, NZ=Archive. Destroys: None.
    jp  nz,err_FileArchived ;String must be in RAM. What kind of monster archives this, anyhow?
    mlt bc      ;Uses known side-effect on 84CE: Clears BCU. We don't actually care what's in BC.
    ex  de,hl   ;after: HL=pointer to string data
    ld  c,(hl)
    inc hl
    ld  b,(hl)
    inc hl  
    ld  a,b     ;Verifies that the string isn't zero.
    or  a,c     ;Doing an LDIR-like operation on zero would be disastrous.
    jp  z,err_InvalidStringInput  ;So quit if it is zero. It's an invalid input.
    ex  de,hl
    ld  hl,OP1
    ld  a,(de)        ;Read first byte of string to determine if it indicates a type.
    cp  a,AppVarObj   ;NOTE: This is also the `rowSwap(` token.
    jr  nz,+_         ;Jump to handle program var case
    dec bc            ;Decrement string size to skip over the initial byte.
    inc de            ;Advance string pointer to name portion, then continue
    jr ++_
_:  ld  a,ProtProgObj ;If not an appvar, then name does not have a prefix. Assume prog.
_:  ex  de,hl         ;DE=OP1, HL=start of string's name data
    ld  (de),a        ;write filetype to OP1+0.
    inc de            ;Because copyNameToOP1 wants OP1+1 in DE.
    call copyNameToOP1  ;not a simple ldir. Must account for lowercase tokens.
    call _ChkFindSym    ;This is the call needed to find programs and appvars.
    jp  c,err_FontNotFound
    call _ChkInRam  ;in: DE=fileaddr, out: Z=RAM, NZ=Archive. Destroys: None.
    ;NOTE: Removed in-RAM requirement for font files. It's up to the writer to reject these.
    ex  de,hl   ;
    jr  z,+_    ;skip if in RAM.
    ld  de,9    ;3 bytes flash header + 6 bytes for appvar header before name
    ld  e,(hl)
    inc hl
    add hl,de   ;Advance HL to file start
_:  mlt de     ;Known side effect on 84CE: Clears DEU. What's actually in DE is irrelevant at this point.
    ld  (fontFilePtr),hl   ;Pointer to start of font file in RAM.
    ld  e,(hl)
    inc hl
    ld  d,(hl)
    inc hl
    ex  de,hl   ;after: HL=size of object, DE=pointer to object
    ;Do not rely on fontFileSize until after you verify that the overridden
    ;error system (which is the only way you're accessing this if there is
    ;a problem) returned success (ERR_OK).
    ld  (fontFileSize),hl
    ld  bc,fontPackHeaderEnd-fontPackHeader
    or  a,a
    sbc hl,bc
    jp  c,err_FontFileCorrupted
    ld  hl,fontPackHeader
    ld  b,fontPackHeaderEnd-fontPackHeader
_:  ld  a,(de)
    cp  a,(hl)
    jp  nz,err_FontFileCorrupted
    inc hl
    inc de
    djnz -_
    ex  de,hl   ;after: HL=pointer to font file address section, DE=unused
    ;Extra check: Verify that the glyph LUT is valid.
    ;This does not check for duplicate mappings. A duplicate mapping 
    ;is considered an error in the font builder.
    push hl
        ld b,255
        ld e,(hl)   ;target number of glyphs
        ld d,0      ;will be the number of glyphs that are mapped
        inc hl
_:      ld a,(hl)
        inc hl
        inc a
        jr  z,$+3
        inc d       ;Only increment if this entry is mapped.
        djnz -_
        ld  a,e
        cp  a,d     ;If valid, D==E.
        jp  nz,err_FontFileCorrupted
        ;TODO: Maybe check total file size here.
    pop hl
    xor a,a
    ret

;Used to copy token string to OP1 for _ChkFindSym.
;in: DE=OP1+1, HL=pointer to string to copy, BC=size of string
;NOTE: See if we can inline this if this is only called once.
copyNameToOP1:
    ld  a,c
    and a,$1F  ;Prevent crash if string is too long. Let file-not-found do the job.
    ld  b,a
copyNameToOP1_loop:
    ld  a,(hl)
    inc hl
    cp  a,t2ByteTok
    jr  nz,copyNameToOP1_copy
    ld  a,(hl)
    inc hl
    dec b           ;Cannot go negative here unless token is corrupted.
    cp  a,t2ByteTok ;A 2 byte token cannot include itself. Is a problem...
    jr  c,$+3       ;... because this makes the character set discontinous.
    dec a           ;So if we're past that, subtract 1 to regain continuity.
    sub a,tLa-'a'   ;Subtract lowercase A token, then add back ASCII lowercase 'a'
copyNameToOP1_copy:
    ld  (de),a
    inc de
    djnz copyNameToOP1_loop
    xor a,a
    ld  (de),a      ;Null-terminate string copied to OP1.
    ret

;in: HL = size (L=columns (X), H=rows (Y))
;out: HL = vat ptr, DE = address to data object's size bytes
createMatrix:
    ld  (createMatrix_loadData),hl
createMatrix_retry:
    call findMatrix
    jr  c,createMatrix_notFound
    call _DelVarArc
    jr  createMatrix_retry
createMatrix_notFound:
    ld  hl,err_MatrixCreateFailed
    call _PushErrorHandler  ;TI-OS SYSTEM ERROR HANDLER
createMatrix_loadData = $+1
    ld  hl,0        ;SMC. Can't use stack. Error handler is mucking it up.
    call _CreateRMat ;in: HL=dims, Op1=name. out: Op4=name, HL/DE = as findsym
    call _PopErrorHandler   ;NOTE: Destroys BC. This is not documented.
    ret

;No inputs.
;outputs: Carry set if not found, else HL=VATptr, DE=filePtr, A=type byte.
findMatrix:
    ld  hl, matrixJ
    call _Mov9ToOP1
    jp  _FindSym    ;out: CA=1 if not found, B = page, A = (HL), HL = sym ptr, DE = var


;-----------------------------------------------------------------------------
; Error system

err_OK:
    ld  a,ERR_OK
    jr  errorHandler
err_OOM_OnFontCreate:
    ld  a,ERR_OOM_ON_FONT_CREATE
    jr  errorHandler
err_InvalidGlyph:
    ld  a,ERR_INVALID_GLYPH
    jr  errorHandler
err_GlyphNotFound:  
    ld  a,ERR_GLYPH_NOT_FOUND
    jr  errorHandler
err_OOM_Other:
    ld  a,ERR_OOM_OTHER
    jr  errorHandler
err_MatrixDimMismatch:
    ld  a,ERR_MATRIX_DIM_MISMATCH
    jr  errorHandler
err_MatrixColsOutOfRange:
    ld  a,ERR_MATRIX_COLS_OUT_OF_RANGE
    jr  errorHandler
err_FontNotFound:
    ld  a,ERR_FONT_NOT_FOUND
    jr  errorHandler
err_FontFileCorrupted:
    ld  a,ERR_FONT_FILE_CORRUPTED
    jr  errorHandler
err_StringNotFound:
    ld  a,ERR_STRING_NOT_FOUND
    jr  errorHandler
err_MatrixCreateFailed:
    ld  a,ERR_MATRIX_CREATE_FAILED
    jr  errorHandler
err_InvalidStringInput:
    ld  a,ERR_INVALID_STRING_INPUT
    jr  errorHandler
err_MatrixNotFound:
    ld  a,ERR_MATRIX_NOT_FOUND
    jr  errorHandler
err_FileArchived:
    ld  a,ERR_FILE_ARCHIVED
    jr  errorHandler

;This error system is not to be confused with the TI-OS's error handlers.
;In the case of no override:
; SP set to original dispatch target (OS) and is returned to.
;In the case of overridde:
; SP set to new dispatch target (handler) and is returned to.
; Dispatch target is restored to the target set in errorOverride (original)
;In the case of override and error re-raise:
; The above happens, but the original dispatch target (OS) is returned to.
;All of this breaks down if you misuse errorOverride and errorOverrideEnd.
errorHandler:
    ;
    push af
        call _SetxxOP1  ;A->OP1 (allowed range: 0-99)
        call _StoAns    ;OP1->Ans
    pop af
    ld  hl, (var_SP)    ;load dispatch target
    push hl
        ld  hl, (errorOverrideEnd_SMC_from_errorOverride)
        ld  (var_SP),hl
    pop hl
    ld  sp,hl
    ret

;in: HL= address to return to if a local error has happened.
;NOTE: Do not call this twice, or the second call will overwrite the return 
;address of the first call, causing a crash instead of an error code return.
errorOverride:
    push hl
        ld  hl,(var_SP)
        ld  (errorOverrideEnd_SMC_from_errorOverride),hl
    pop hl
    ex  (sp),hl     ;Move handler to stack, recovering return address.
    ld  (var_SP),sp ;If error happens, "return" to handler. Stack levels restored.
    jp  (hl)        ;Then return to our potentially unsafe operation.

;Don't call without calling errorOverride first. Otherwise, SP will get loaded
;with garbage on program exit and bad things will likely happen.
errorOverrideEnd:
    ld  (errorOverrideEnd_SMC_preserveInputHL),hl
errorOverrideEnd_SMC_from_errorOverride = $+1
    ld  hl,0    ;SMC, from errorOverride. Initialized from program start to stack base.
    ld  (var_SP),hl
    pop  hl     ;Retrieve return address
    ex  (sp),hl ;Store return address, swapping out and discarding error handler.
errorOverrideEnd_SMC_preserveInputHL = $+1
    ld  hl,0
    ret

;-----------------------------------------------------------------------------
; Constants
matrixJ:
.db MatObj, tVarMat, tMatJ, 0, 0
str0:
.db StrngObj, tVarStrng, tStr0, 0, 0
fontPackHeader:
.db tExtTok,tAsm84CeCmp,$18,$09,"FNTPK",0
fontPackHeaderEnd:

;-----------------------------------------------------------------------------
; The following are the installer and hook stubs needed to create
; the font file. They can be copied AS-IS into the file from here.
;
; After the stub, you must append the following data in this order:
; (1) Encodings, (2) Large glyph data, (3) Small glyph data.
;

fontObj_stubStart:
.relocate(userMem-2)
#define USING_LOADER
#include "../hook/src/sahead.asm"
#include "../hook/src/loader.asm"
#include "../hook/src/hook.asm"
.endrelocate()
fontObj_stubEnd:


.echo "Executable size: ", ($-programStart), " bytes"
.end
.end