; Utility file to replace draw.asm 
;

assume adl=1

flags             EQU $D00080 ;As defined in ti84pce.inc
_LoadPattern      EQU $021164 ;''
_FindAlphaDn      EQU $020E90 ;''
_FindAlphaUp      EQU $020E8C ;''
_ChkFindSym       EQU $02050C ;''
_ChkInRam         EQU $021F98 ;'' In: DE=adr. Out: NC if in RAM, C if in arc.
_PopRealO1        EQU $0205DC ;''
_PopRealO2        EQU $0205D8 ;''
_PopRealO4        EQU $0205D0 ;''
_PushRealO1       EQU $020614 ;''
_PushRealO4       EQU $020608 ;''
_SetLocalizeHook  EQU $0213F0 ;''
_ClrLocalizeHook  EQU $0213F4 ;''
_SetFontHook      EQU $021454 ;''
_ClrFontHook      EQU $021458 ;''

fontHookPtr		EQU 0D025EDh
parserHookPtr	EQU 0D025F9h
catalog1HookPtr	EQU 0D025FFh
helpHookPtr		EQU 0D02602h
menuHookPtr		EQU 0D02608h
catalog2HookPtr	EQU 0D0260Bh
tokenHookPtr	EQU 0D0260Eh
localizeHookPtr	EQU 0D02611h

prevDData         EQU $D005A1 ;''
lFont_record      EQU $D005A4 ;''
sFont_record      EQU $D005C5 ;''
Op1               EQU $D005F8 ;''
Op2               EQU $D00603 ;''
Op3               EQU $D0060E ;''
Op4               EQU $D00619 ;''
Op5               EQU $D00624 ;''
Op6               EQU $D0062F ;''
pTemp			EQU 0D0259Ah
progPtr			EQU 0D0259Dh
ProtProgObj		EQU 6
AppVarObj		EQU 15h	;application variable
GroupObj		EQU 17h ;group.

DRAW_BUFFER       EQU $E30014
fontdata_offset   EQU 3



;ABI notes so I don't have to keep looking back at the documentation:
;   NOTE: This section uses UHL/UDE/UBC to refer to the entire 3 byte register.
;       not merely the upper byte of the register mentioned.
;   Assembly routines must preserve IX and SP. All other registers are free.
;   Arguments pushed from last to first corresponding to the C prototype.
;   In this way, you can repeatedly pop arguments to access variables from
;   first to last. The first pop is always the return address; retain it.
;   Return values are always in registers. for 1 byte returns, use A.
;   For 2 byte returns, use HL. For 3 byte returns, use UHL.
;   3 byte returns are used both for int and pointers.
;   We will not deal in returns more than 3 bytes, but if you must, the pattern
;   continues by consuming DE, and then BC. The longest is BC:UDE:UHL


;-----------------------------------------------------------------------------
;void gatherFiles(uint8_t vartypeidx, fontvar_t *fontvars);
;typedef struct {
;    uint8_t varcount;
;    intptr_t groupname[255];
;    intptr_t varname[255];
;    intptr_t vardata[255];
;} fontvar_t;
; This method iterates over the filesystem, filling out the above struct with
; as many values as findable. Searching stops if varcount reaches 255.
; A varcount of 0 means that there were no files found. Entries in each array
; that is not in range of varcount is OOB and should not be used.

section .text

;The two equates below have +3 added to overcome the push ix at the start of _gatherFiles.
vartypeidx equ 6
fontvars equ 9

public _gatherFiles
require strcmp
require _fontpackHeader
_gatherFiles:
    push ix     ;MUST PRESERVE THIS
    ;---
    or  a,a
    sbc hl,hl
    add hl,sp
    push hl
    pop iy
    ld  hl,(iy+fontvars)
    ld  (hl),0    ;init varcount to 0
    ld  ix,(progPtr)
    jr  gatherFiles_detecting
    ; Below is the main loop for traversing the VAT and locating suitable files
    ; based on vartypeidx, splitting into two branches that handles not-group
    ; and group files 
gatherFiles_detectLoop:
    call traverseVat
    jr  c,gatherFiles_lookupConcluded
    ;---
gatherFiles_detecting:
    ld  a,(ix+0)    ;VAT entry: Type+flags byte
    and a,$1F       ;strip flags, retaining type.
    ld  b,a
    call gatherFiles_retrieveFiletype
    cp  a,b
    jr  nz,gatherFiles_detectLoop   ;If not type match, iterate.
    ld  de,(ix-7)   ;puts "page" byte in DEU
    ld  e,(ix-3)    ;and construct the rest of DE because who the hell writes a
    ld  d,(ix-4)    ;pointer BACKWARDS without direct access to its upper byte?
    call _ChkInRam
    jr  nc,gatherFiles_detectLoop   ;If in RAM, iterate. We don't do RAM objects.
    ld  a,b
    cp  a,GroupObj
    jr  z,gatherFiles_actOnGroup
    ;--- HANDLE PROTPROG/APPVAR OBJECTS
    or  a,a
    sbc hl,hl
    ld  (gatherFiles_traverseAndUpdateFontvars_groupNamePtrSMC),hl
    ; Below is set to zero to force terminate-on loop end. No need to
    ; figure out where the end of the file is. Is easy.
    ld  (gatherFiles_traverseAndUpdateFontvars_groupEOFSMC),hl
    ex  de,hl   ;HL=pointer to variable header area
    inc hl
    inc hl
    inc hl      ;Skip past Flash flag and pre-variable size bytes.
    call gatherFiles_traverseAndUpdateFontvars
    jr  gatherFiles_detectLoop
gatherFiles_actOnGroup:
    ;--- HANDLE GROUP OBJECTS
    push ix
    push iy
    ;---
    ld  bc,9    ;1 flash flag byte, 2 pre-var size bytes, 6 VAT backup bytes.
    ex  de,hl   ;HL=pointer to variable header area
    add hl,bc
    ld  (gatherFiles_traverseAndUpdateFontvars_groupNamePtrSMC),hl
    ld  c,(hl)
    inc hl
    add hl,bc
    ld  c,(hl)
    inc hl
    ld  b,(hl)
    inc hl
    push hl
        add hl,bc
        ld  (gatherFiles_traverseAndUpdateFontvars_groupEOFSMC),hl
    pop hl
    call gatherFiles_traverseAndUpdateFontvars  ;entire loop inside this.
    ;---
    pop iy 
    pop ix
    jr  gatherFiles_detectLoop  
gatherFiles_lookupConcluded:
    ;---
    pop ix
    ret

;in: HL = pointer to start of variable header area in an archived variable
;    IY = _gatherFiles stack frame pointer at entry
;    Also, write the internal group name pointer, as this won't write that.
;NOTE: There is no difference between a group variable header and a non-group
;   variable header inside a group variable.
gatherFiles_traverseAndUpdateFontvars:
    ;We are either inside a group file containing these types
    ;or we are looking at a non-group file of these types.
    ld  a,(iy+vartypeidx)
    and a,1
    jr  nz,$+6
    ld  a,ProtProgObj
    jr  $+4
    ld  a,AppVarObj
    ;---
    ld  e,a
    ld  a,(hl)
    and a,$1F   ;| The check we need to do has to be done AFTER the pointer has
    ld  d,a     ;| advanced to the next file. At that point do we choose to commit.
    ld  bc,6
    add hl,bc
    ld  (gatherFiles_traverseAndUpdateFontvars_varNamePtrSMC),hl
    ld  c,(hl)
    inc hl
    add hl,bc
    ld  c,(hl)
    inc hl
    ld  b,(hl)  ;var filesize
    inc hl
    ld  (gatherFiles_traverseAndUpdateFontvars_varDataPtrSMC),hl
    push hl
        push de
            ld  de,_fontpackHeader
            call strcmp
        pop de
    pop hl
    push af
        add hl,bc   ;skip to start of next var inside group
    pop af
    jp  c,gatherFiles_traverseAndUpdateFontvars_conclude    ;Mismatched header
    ld  a,e
    cp  a,d
    jr  nz,gatherFiles_traverseAndUpdateFontvars_conclude   ;Mismatched filetyep
    ld  de,(iy+fontvars)
    ld  a,(de)             ;Current varcount
    inc a
    jr  z,gatherFiles_traverseAndUpdateFontvars_conclude    ;Ran out of slots
    ld  (de),a
    inc de
    push hl
        dec a       ;referencing position N-1
        ld  h,a
        ld  l,3
        mlt hl
        add hl,de   ;Advance to groupname[varcount-1]
        ld  bc,255*3
        ;write the thing below externally
gatherFiles_traverseAndUpdateFontvars_groupNamePtrSMC = $+1
        ld  de,0    ;NOTE: This will be uninitialized if not group. That's fine, as it will not be read in that case.
        ld  (hl),de
        add hl,bc
gatherFiles_traverseAndUpdateFontvars_varNamePtrSMC  = $+1
        ld  de,0
        ld  (hl),de
        add hl,bc
gatherFiles_traverseAndUpdateFontvars_varDataPtrSMC  = $+1
        ld  de,0
        ld  (hl),de
    pop hl
gatherFiles_traverseAndUpdateFontvars_conclude:
    push hl
gatherFiles_traverseAndUpdateFontvars_groupEOFSMC = $+1
        ld  de,0
        or  a,a
        sbc hl,de   ;curptr-EOF. If not carry, we are at or past EOF.
    pop hl
    ret nc
    jp  gatherFiles_traverseAndUpdateFontvars

;---
;in: stack frame in IY.
;out: A=filetype to look for (group, appvar, or protprog)
gatherFiles_retrieveFiletype:
    ld  a,(iy+vartypeidx)
    bit 1,a
    jr  z,gatherFiles_retrieveFiletype_notGroup
    ld  a,GroupObj
    ret
gatherFiles_retrieveFiletype_notGroup:
    rrca
    jr  nc,gatherFiles_retrieveFiletype_notAppVar
    ld  a,AppVarObj
    ret
gatherFiles_retrieveFiletype_notAppVar:
    ld  a,ProtProgObj
    ret

;-----------------------------------------------------------------------------
;Internal routine. Do not expose to the C runtime.
;Input: IX = Pointer in VAT
;Output: carry if IX is at or after end of program VAT

section .text
private traverseVat
traverseVat:
    ld  hl,(pTemp)
    lea de,ix+0
    or  a,a
    sbc hl,de   ;If this stops carrying, we are no longer in program VAT.
    ccf
    ret c
    sbc hl,hl
    ;T=-0, T2=-1, Ver=-2 DAL=-3, DAH=-4, PAGE=-5, NL=-6, NAME=-7-N
    lea de,ix-6
    ex  de,hl
    ld  e,(hl)
    sbc hl,de   ;always results in NC
    dec hl
    push hl
    pop ix
    ret

;-----------------------------------------------------------------------------
;Internal routine. Do not expose to the C runtime.
;In: HL=str1, DE=str2.
;Out: C=not equal, NC=equal
;Destroys: HL, DE, A

section .text
private strcmp
strcmp:
    ld  a,(de)
    cp  a,(hl)
    inc de
    inc hl
    jr  nz,strcmp_notEqual
    or  a,a
    ret z
    jr  strcmp
strcmp_notEqual:
    scf
    ret

;-----------------------------------------------------------------------------
;Do not expose to the C runtime. Internal routine.
;In: HL=pointer to start of variable data for a font variable.
;Out: HL=pointer to start of hook section for that variable.
;     Carry set if not actually a font. In that case, HL is invalid.

section .text
private getHookLocation
getHookLocation:
    ld  de,_fontpackHeader
    call strcmp ;Uses this to advance HL to the offset block.
    ret c
    ; HL now points to "distance to data section from here"
    inc hl
    inc hl
    inc hl
    ; HL now points to "distance to hook section from here"
    ld  bc,(hl)
    add hl,bc
    or  a,a
    ret



;-----------------------------------------------------------------------------
;bool isInstalled(uint8_t *startOfVarData);
;Returns true if the font hook is installed, false if not. 
;Does this by finding the start of the hook code and matching it against
;the address at localizeHookPtr.
;The internal version of this function also uses carry set to indicate that
;the variable is not a font variable. Also returns hook location in DE.

section .text
public _isInstalled
private isInstalled_internal
require _fontpackHeader
require strcmp

_isInstalled:
    or  a,a
    sbc hl,hl
    add hl,sp
    push hl
    pop iy
isInstalled_internal:
    ld  hl,(iy+3)   ;pointer to start of variable data is passed on stack.
    call getHookLocation
    ex  de,hl   ;DE=pointer to start of hook section
    ld  a,0
    ret c
    xor a,a
    ld  iy,flags
    bit 1,(iy+$35)  ;Check flags to see if hook is installed.
    ret z           ;If not installed, return false.
    ld  hl,(localizeHookPtr)
    sbc hl,de
    ret nz  ;Returns false for this hook not installed.
    inc a
    ret     ;Returns true for this hook installed.


;-----------------------------------------------------------------------------
;void installHook2(uint8_t *startOfVarData);
;Installs the font hook for the variable whose data starts at the given pointer.
;If a problem happens, the hook is not installed.

section .text
public _installHook2
require isInstalled_internal
_installHook2:
    or  a,a
    sbc hl,hl
    add hl,sp
    push hl
    pop iy
    call isInstalled_internal
    ret c   ;If not a font variable, do not install.
    or  a,a
    ret nz  ;If already installed, do not install again.
    ex  de,hl   ;HL=start of hook section
    jp  _SetLocalizeHook

;-----------------------------------------------------------------------------
;void uninstallHook2(void);
;Uninstalls the font hook, if it exists.

section .text
public _uninstallHook2
_uninstallHook2:
    ld  iy,flags
    bit 1,(iy+$35)  ;Check flags to see if hook is installed.
    ret z           ;If not installed, nothing to uninstall.
    jp  _ClrLocalizeHook


;-----------------------------------------------------------------------------
; extern const uint8_t fontpackHeader[];

section .text
public _fontpackHeader
_fontpackHeader:
db $EF,$7B,$18,$0C,"FNTPK",0

;-----------------------------------------------------------------------------
;TODO: PREP FOR UNIFIED COPY/RENDER
;SAVE ON SOME CODE BY PASSING THROUGH THE FONT OBJECT AND STAGING A MOCK
;HOOK EVENT TO GET THE DATA WHERE IT NEEDS TO BE PRIOR TO RENDERING.
;THEN, RENDER BASED ON SMALL FONT OR LARGE FONT VARIANTS. FOR THIS TO WORK,
;USE THE APPROPRIATE SYSTEM CALLS TO STAGE THE DEFAULT FONT DATA AND THEN CALL
;THE HOOK TO, AT ITS OPTION, OVERRIDE IT.

;Large font data is copied to lFont_record, with glyph width at offset 0 and
;actual data at lFont_record+1. Actual homescreen rendering starts with rendering
;the three bytes at prevDData, pre-cleared prior to rendering. The homescreen
;renderer also manually clears the width byte and draws 18 rows of 14 pixels.
;The actual font data is 14 rows of 12 pixels stored.
;Only the 5 most significant bits in the first byte are used for rendering.
;The three least significant bytes are unused. The entire second byte is used.
;e.g.: db %11111000, %11111111 ;represents a full row of 12 pixels. The first 
;byte's last three bits are ignored. (We're going to pretend for a hot minute
;that the final bit in the 2nd byte is also unused because including that
;causes the number of bits we have to add up to 13, not 12.)
;
;Small font data is copied to sFont_record, with glyph width at offset 0 and
;actual data at sFont_record+1. If the width is 8 or less, one byte represents
;a full row of pixels, left-aligned. If the width is more than 8, two bytes are
;used. If the width is greater than 16, clamp the width to 16 internally.
;Any string rendering code does not clamp this way and will space accordingly.
;
;If there are any questions about the above, use the build tools to build a
;font, then examine the sources in the `obj` and `src` folders to see how
;the data is formed and used.
;

;extern uint8_t drawGlyph(uint8_t *fontDataStart, uint8_t fontType, uint8_t glyphIndex, int16_t x, int16_t y);
;Returns width of character drawn.

section .text

dgoffset        EQU 12
fontdatastart   = 3+dgoffset
fonttype        = 6+dgoffset
glyphindex      = 9+dgoffset
xcoord          = 12+dgoffset
ycoord          = 15+dgoffset

public _drawGlyph
_drawGlyph:
    push ix
    ld  iy,flags
    ld  a,(iy+$35)  ;Preserve hooks relevant to font rendering.
    push af
    ld  (iy+$35),0  ;Temporarily kill those hooks.
    ld  hl,(fontHookPtr)
    push hl
    ld  hl,(localizeHookPtr)
    push hl
    or  a,a
    sbc hl,hl
    add hl,sp
    push hl
    pop ix
    ;---
    or  a,a
    sbc hl,hl   ;ensure HLU is cleared
    ex  de,hl
    ld  e,(ix+xcoord+0)
    ld  d,(ix+xcoord+1)     ;x pos is up to 2 bytes (0-320)
    ld  L,(ix+ycoord+0)     ;y pos is just one byte (0-240). We can cast like this.
    ld  H,160               ;half of 320. We factored out the other half.
    mlt hl
    add hl,hl               ;factored back in. Now have row start in buffer.
    add hl,de               ;now have position in a buffer.
    ld  de,(DRAW_BUFFER)    ;select the buffer
    add hl,de               ;We now have full address.
    push hl
        ld  hl,(ix+fontdatastart)   ;Pointer to start of font data
        call getHookLocation
        push ix
            call _SetLocalizeHook ;temporarily install this hook. _LoadPattern uses this.
        pop ix
        ld  a,(ix+fonttype) ;0=large,1=small
        sub a,1     ;carry if large
        sbc a,a     ;$FF if large, 0 if small.
        and a,00000100b   ;isolate new fracDrawLFont bit.
        ld  b,a
        cpl
        and a,(iy+$32)  ;clear out our target bit
        or  a,b         ;set it to the new value
        ld  (iy+$32),a
        ld  a,(ix+glyphindex)
        call _LoadPattern   ;Returns HL = target location (width-prefix)
        bit 2,(iy+$32)
    pop de
    push hl  ;###
        jr  z,drawGlyph_smallFont
        ;--- LARGE FONT RENDERING
        ;ENTRY POINT TO SPLIT:
        ;HL = drawing font data from this address.
        ;DE = buffer location to draw to
        inc hl
        ld  c,14
drawGlyph_largeFont_rowLoop:
        ld  b,5
drawGlyph_largeFont_innerLoopA:
        rl  (hl)    ;nc=transparent, c=black
        ccf
        sbc a,a     ;$FF if empty, 0 if filled
        jr  z,$+3   ;black is color 0 so skip if not transparent.
        ld  a,(de)  ;old color if transparent
        ld  (de),a
        inc de
        djnz drawGlyph_largeFont_innerLoopA
        inc hl
        ld  b,8
drawGlyph_largeFont_innerLoopB:
        rl  (hl)    ;nc=transparent, c=black
        ccf
        sbc a,a     ;$FF if empty, 0 if filled  
        jr  z,$+3   ;black is color 0 so skip if not transparent.
        ld  a,(de)  ;old color if transparent
        ld  (de),a
        inc de
        djnz drawGlyph_largeFont_innerLoopB
        inc hl
        push hl
            ld hl,320-13
            add hl,de
            ex  de,hl
        pop hl
        dec c
        jr  nz,drawGlyph_largeFont_rowLoop
        jr  drawGlyph_end
drawGlyph_smallFont:
        ;--- SMALL FONT RENDERING
        ;ENTRY POINT TO SPLIT:
        ;HL = drawing font data from this address.
        ;DE = buffer location to draw to
        ld  a,(hl) ;width byte
        or  a,a
        jr  z,drawGlyph_end   ;If width is zero, skip drawing.
        inc hl
        cp  a,9
        ld  c,12
        jr  c,drawGlyph_smallFont_narrow
        ;--- WIDE SMALL FONT RENDERING (9-16 pixels wide)
drawGlyph_smallFont_wide_rowLoop:
        ld  b,8
drawGlyph_smallFont_wide_innerLoopA:
        rl  (hl)    ;nc=transparent, c=black
        ccf
        sbc a,a     ;$FF if empty, 0 if filled
        jr  z,$+3   ;black is color 0 so skip if not transparent.
        ld  a,(de)  ;old color if transparent
        ld  (de),a
        inc de
        djnz drawGlyph_smallFont_wide_innerLoopA
        inc hl
        ld  b,8
drawGlyph_smallFont_wide_innerLoopB:
        rl  (hl)    ;nc=transparent, c=black
        ccf
        sbc a,a     ;$FF if empty, 0 if filled
        jr  z,$+3   ;black is color 0 so skip if not transparent.
        ld  a,(de)  ;old color if transparent
        ld  (de),a
        inc de
        djnz drawGlyph_smallFont_wide_innerLoopB
        inc hl
        push hl
            ld hl,320-16
            add hl,de
            ex  de,hl
        pop hl
        dec c
        jr  nz,drawGlyph_smallFont_wide_rowLoop
        jr  drawGlyph_end
drawGlyph_smallFont_narrow:
drawGlyph_smallFont_narrow_rowLoop:
        ld  b,8 
drawGlyph_smallFont_narrow_innerLoop:
        rl  (hl)    ;nc=transparent, c=black
        ccf
        sbc a,a     ;$FF if empty, 0 if filled
        jr  z,$+3   ;black is color 0 so skip if not transparent.
        ld  a,(de)  ;old color if transparent
        ld  (de),a
        inc de
        djnz drawGlyph_smallFont_narrow_innerLoop
        inc hl
        push hl
            ld hl,320-8
            add hl,de
            ex  de,hl
        pop hl
        dec c
        jr  nz,drawGlyph_smallFont_narrow_rowLoop
drawGlyph_end:
    pop hl ;###
    ld  b,(hl)
    ;---
    pop hl
    ld (localizeHookPtr),hl
    pop hl
    ld (fontHookPtr),hl
    pop af
    ld  (flags+$35),a
    pop ix
    ld  a,b
    ret


