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
largeFontPtr = glyphIsSmall+2  ;3b, Pointer to large font data table in file.
.assert(largeFontPtr >= (glyphIsSmall+2), "largeFontPtr must be at least 2 bytes after glyphIsSmall to avoid overlap.")
largeFontSize= largeFontPtr+3  ;3b, Size of large font data table in file.


reserved     = largeFontSize+3 ;0b. Used to avoid having to modify the stuff below.
;--
;256 byte: Glyph LUT. Indexed by GlyphID, value is index to glyph data. $FF=empty.
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
    ld  (var_SP), sp
    ld  hl,err_OK
    push hl         ;Return address for no errors: Error handler returns zero.
    call _RclAns
    call _ConvOP1   ;out: DE=Ans, A=E.
    ld  hl,1000
    or  a,a
    sbc hl,de   ;If ANS was less than 1000, carry is not set and we should read.
    push af     ;So we can test the same condition twice.
        jr  nc,+_   ;If 1000>Ans, then Ans is in range. Skip.
        ;Else HL= 1000-Ans, which is negative by what we want.
        ex  de,hl   ;put our answer into DE
        or  a,a
        sbc hl,hl
        sbc hl,de   ;This sequence negates DE, returning it to a positive value.
_:      ld  (glyphID),hl    ;Loading both glyphID and glyphIsSmall at same time.
    pop af
    jp  c,main_writeMode
main_readMode:
    call findNameInString   ;throws appropriate errors. No overrides.
    call populateGlyphTables  ;populates glyphTable, glyphDataL, and glyphDataS.
    ld  hl,(glyphID)
    ld  c,h  ;Read from adjacent variable: glyphIsSmall. 0=large, 1=small.
    ld  h,1
    mlt hl   ;Set HL to the 1 byte at (glyphID)
    ld  de,glyphTable+1
    add hl,de
    or  a,a
    ld  a,(hl)  ;A = index of glyph data for this glyphID. $FF if unmapped.
    inc a
    jp  z,err_GlyphNotFound
    dec a
    inc c
    dec c
    ld  c,a
    jr  z,main_readMode_largeGlyph
    ;small glyph
    ld  b,SIZEOF_SMALL_GLYPH
    mlt bc
    ld  hl,glyphDataS
    add hl,bc   ;HL = address of small glyph data in table.
    push hl
        ld  L,(hl)
        ld  H,SMALL_GLYPH_HEIGHT
        call createMatrix   ;out: DE=pointer to matrix data object.
        inc de
        inc de
    pop ix
    ld  a,(ix+0)    ;size byte
    inc ix
    ld  L,a     ;Loop limit of first byte of glyph data row.
    ld  h,0     ;Loop limit of second byte of glyph data row.
    cp  a,9     ;if carry (width <= 8), skip past pair adjusting.
    jr  c,+_
    ld  L,8
    sub a,8
    ld  h,a
_:  ;Loop counter notes: L=byte1count, H=byte2count.
    ld  c,SMALL_GLYPH_HEIGHT
main_readMode_smallGlyph_loop:
    ld  a,(ix+0)
    inc ix
    ld  b,L
    push hl
        call writeBitsToMatrix
    pop hl
    inc h
    dec h           ;Checks if H was zero. If it was, skip past read and increment
    jr  z,+_        ;as all width<=8 fonts are packed to a single byte per row.
    ld  a,(ix+0)
    inc ix
    ld  b,H
    push hl
        call writeBitsToMatrix
    pop hl
_:  dec c
    jr  nz,main_readMode_smallGlyph_loop
    ret
;---
main_readMode_largeGlyph:
    ld  b,SIZEOF_LARGE_GLYPH
    mlt bc
    ld  hl,glyphDataL
    add hl,bc   ;HL = address of large glyph data in table.
    push hl
        ld  hl,MATRIX_DIMS(LARGE_GLYPH_WIDTH, LARGE_GLYPH_HEIGHT)
        call createMatrix   ;out: DE=pointer to matrix data object.
        inc de
        inc de
    pop ix
    ld  c,LARGE_GLYPH_HEIGHT
main_readMode_largeGlyph_loop:
    ld  a,(ix+0)
    ld  b,5
    call writeBitsToMatrix
    ld  a,(ix+1)
    ld  b,7 ;5+7=12 bits total for the first 2 bytes of glyph data.
    call writeBitsToMatrix
    lea ix,ix+2
    dec c
    jr  nz,main_readMode_largeGlyph_loop
    ret
;---
main_writeMode:
;TODO: THE ENTIRE WRITE SECTION.
;Actions to take / program flow overview
; Pull down pointers from existing file, if any. If not, create a fully
;   functional font file with no font entries, *then* pull down pointers.
;   Emit appropriate errors if there are problems here.
; Validate Matrix [J] exists and has correct size. Emit relevant errors if not.
; Calculate memory delta from existing file to new file and ensure it can
;   fit in memory. Error if not.
; Delete the old file and reconstruct it from the data tables we have.
; Return error code zero.
    ;...
    ld  hl,main_writeMode_maybeCreateNewFile
    call errorOverride
    call findNameInString   ;throws appropriate errors. No overrides.
    call errorOverrideEnd
    jr  main_writeMode_fileFound
main_writeMode_maybeCreateNewFile:
    cp  a,ERR_FONT_NOT_FOUND
    jp  nz,errorHandler     ;reraise error if any other error
    ;Create new font file with no entries.
    ;NOTE: OP1 is already loaded with the name of the file from findNameInString
    ld  hl,fontObj_stubEnd-fontObj_stubStart+(7+8)   ;stub size + max VAT size
    call _EnoughMem
    jp  c,err_OOM_OnFontCreate
    ld  a,(OP1)     ;Must create a file using the appropriate call type.
    call _CreateVar ;...or use a generic call that does the same thing.
    ;NOTE: DE points to data size bytes.
    inc de
    inc de
    ld  hl,fontObj_stubStart
    ld  bc,fontObj_stubEnd-fontObj_stubStart
    ldir
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
    ;We are now prepared to begin reading the file in earnest.
    call populateGlyphTables  ;populates glyphTable, glyphDataL, and glyphDataS.
    ;Now, we need to find which glyph we're editing, then modify the tables for it.

    ;TODO: After writing the data tables, determine if we have enough memory
    ;to actually write the new file data.




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
;destroys: E
readBitsFromMatrix:
    ld  a,8
    sub a,b ;if B was less than 8, we need to know how many leftover to finish shifting.
    push af
_:      push bc
            call _Mov9ToOP1 ;copy from HL to OP1, advancing HL.
            push hl
                call _ConvOP1   ;destroys all reg. OP1->DE/A
                sub  a,1        ;This sequence gets us the desired
                ccf             ;shiftable bit in carry.
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

;in: HL=pointer to font file address section
;out: glyphTable now populated with adjusted mappings to glyph data (OffsetLSB==codepoint)
;glyphDataL and glyphDataS now populated with large and small glyph data, respectively.
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
    add hl,de
    ld  a,(hl)  ;Preload number of mapped glyphs.
    ;NOTE: The math stops making sense if there are 0 glyphs, but as long as the
    ;table itself shows that nothing is mapped, then it shouldn't be a problem.
    ld  bc,256
    ld  de,glyphTable
    push de
        ldir    ;Copy glyph LUT to local glyphTable.
        ld  (largeFontPtr),hl
        ld  L,a
        ld  H,SIZEOF_LARGE_GLYPH
        mlt hl
        ld  bc,SIZEOF_LARGE_GLYPH
        or  a,a
        sbc hl,bc   ;HL = jump length to small glyph data after large glyph LDIR.
        ld  (largeFontSize),hl
    pop de
    inc de
    ld  c,1 ;loop counter. Doubles as codepoint.
populateGlyphTables_largeLoop:
    ld  a,(de)  ;maps codepoint to glyph index. $FF if unmapped.
    inc a
    jr  z,populateGlyphTables_largeLoop_skip
    push bc
        dec a
        push de      ;preserve address to glyph index.
            ld  b,a  ;Glyph index for calculating position in file.
            ld  a,c  ;we still need the codepoint to calc position in table.
            ld  c,SIZEOF_LARGE_GLYPH
            mlt bc  ;distance to large glyph in file
            ld  hl,(largeFontPtr)
            add hl,bc   ;HL = address of current large glyph data in file
            ld  b,a  ;codepoint to calculate position in table.
            ld  c,SIZEOF_LARGE_GLYPH
            mlt bc  ;distance to large glyph in table
            ex  de,hl
            ld  hl,glyphDataL
            add hl,bc   ;HL = address of current large glyph data in table
            ex  de,hl
            ld  bc,SIZEOF_LARGE_GLYPH
            ldir        ;copy large glyph data to table.
            ;HL is the address after the current large glyph in file.
            ld  bc,(largeFontSize)
            add hl,bc   ;HL = address of current small glyph data in file.
            ex  de,hl
            ld  bc,glyphDataS-glyphDataL
            add hl,bc   ;HL = address of current small glyph data in table.
            ld  bc,SIZEOF_SMALL_GLYPH
            ex  de,hl
            ldir        ;copy small glyph data to table.
        pop de      ;restore address to glyph index.
    pop bc
    ld  a,c     ;codepoint to set in table.
    ;jr  populateGlyphTables_largeLoop_skip
populateGlyphTables_largeLoop_skip:
    ;NOTE: Loop counter starts at 1 and terminates at (here, $FF, at the end, $00)
    ;   But index ranges are only from 0-254. So the "dec a" below does C-1=codepoint
    ;   Or (failed check) 0-1 = $FF, which is the unmapped value we want.
    dec a
    ld  (de),a  ;Write codepoint (or $FF) to glyph index.
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
    mlt bc     ;Uses known side-effect on 84CE: Clears BCU. We don't actually care what's in BC.
    ex  de,hl
    ld  c,(hl)
    inc hl
    ld  b,(hl)
    inc hl  
    ld  a,b     ;Verifies that the string isn't zero.
    or  a,c     ;Doing an LDIR-like operation on zero would be disastrous.
    jp  z,err_InvalidStringInput  ;So quit if it is zero. It's an invalid input.
    ex  de,hl
    ld  hl,OP1
    ld  a,(de)
    cp  a,AppVarObj   ;NOTE: This is also the `rowSwap(` token.
    jr  z,findNameInString_skipProgFill
    ld  a,ProtProgObj
    ld  (de),a
    inc de
findNameInString_skipProgFill:
    call copyNameToOP1  ;not a simple ldir. Must account for lowercase tokens.
    call _ChkFindSym    ;This is the call needed to find programs and appvars.
    jp  c,err_FontNotFound
    ex  de,hl
    mlt de     ;Known side effect on 84CE: Clears DEU. What's actually in DE is irrelevant at this point.
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
        jr  $+3
        inc d
        djnz -_
        ld  e,a
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

;ignore the stack things. Careful thought was put into this.
;This error system is not to be confused with the TI-OS's error handlers.
errorHandler:
    pop hl
    ld  a,(hl)
    inc hl
    push hl
    ;
    push af
        call _StoAns
    pop af
    ld  sp, (var_SP)
    ret

;in: HL= address to return to if error has happened.
;NOTE: Do not call this twice, or the second call will overwrite the return 
;address of the first call, causing a crash instead of an error code return.
errorOverride:
    push hl
        ld  hl,(var_SP)
        ld  (errorOverrideEnd+2),hl
    pop hl
    ld  (var_SP),hl
    ret

;I shouldn't have to say this, but you will have a very bad time if you
;don't call errorOverride first. I don't think $FFFFFD-$FFFFFF maps to anything
;and trying to use the "value" there as a return address likely will crash.
errorOverrideEnd:
    push hl
        ld  hl,0    ;SMC, from errorOverride.
        ld  (var_SP),hl
    pop hl
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
;Notes from the font builder, in the form of the batch file this came from.

;rem BUILDS STANDALONE FONT INSTALLER (loader+hook+data).
;rem ASSUMES CURRENT DIRECTORY IS hook
;rem IF FIRST TIME RUNNING OR WANT TO USE A NEW FONT, RUN packfont.bat

;echo #define USING_LOADER > obj\main.asm
;type src\sahead.asm >> obj\main.asm
;type src\loader.asm >> obj\main.asm
;type src\hook.asm >> obj\main.asm
;type obj\encodings.asm >> obj\main.asm
;type obj\lfont.asm >> obj\main.asm
;type obj\sfont.asm >> obj\main.asm
;..\tools\spasm-ng -E obj\main.asm obj\main.bin

;-----------------------------------------------------------------------------
; And now I've got the unenviable task of putting together the stub.
; NOTE: There was a note here about stub offsets, but those assemble for us
; since we're importing source. Not that it matters too much. The important
; thing is that you copy the compiled stubs as is from fontObj_stubStart with
; the size defined as fontObj_stubEnd-fontObj_stubStart.
; After which you must compact the data tables, mutate the glyph LUT to reflect
; these new compacted positions, then write these data tables immediately
; after the stub that was copied to the file.
; You won't actually have enough information to create the file until after you
; compact the data tables, though.


fontObj_stubStart:
.relocate(userMem-2)
#define USING_LOADER
#include "../hook/src/sahead.asm"
#include "../hook/src/loader.asm"
#include "../hook/src/hook.asm"
.endrelocate()
fontObj_stubEnd:

; You know what would be funny? If I appended $FF, then a 255 byte sequence
; of increasing values starting at 0, and nothing else. It would still be
; considered a valid file by the loader with every codepoint "mapped", but
; the glyph data would just be uninitialized space, which is allowed by the
; TI-OS because there are no read protections in that address space.
; A structure like this would never fly on a PC. Uncharitably, this would
; probably turn into an ACE. Thank goodness PCs don't use ez80, right?
; ... right???



.echo "Executable size: ", ($-programStart), " bytes"
.end
.end