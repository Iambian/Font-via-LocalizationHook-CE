;Font Loader for TI-84 Plus CE BASIC programs
;
;Input: 
;   Str0 = Name of the font file to load
;   NOTE: If Str0 is empty, the currently installed font will be uninstalled.
;
;Output: 
;   Ans=0 if font successfully installed
;   Ans=1 if failure (TODO: DETERMINE IF MORE SPECIFIC ERRORS ARE REQUIRED)
;
;Input notes:
; File names containing a forward slash token '/' are treated as a type of path.
; Name before the slash: Group file name
; Name after the slash: Font file name inside the group file
;

.assume adl=1
#include "../include/ti84pce.inc"
#include "../include/macros.inc"

#define ERR_OK 0
#define ERR_FAIL 1

#define SIZEOF_MAX_AVAR_NAME (1+(8*2))+0
#define SIZEOF_MAX_GROUP_NAME (8)+0

#define MAX_STRING_SIZE SIZEOF_MAX_AVAR_NAME + 1 + SIZEOF_MAX_GROUP_NAME

;-----------------------------------------------------------------------------
; Static workspace in safe RAM

#define SAFERAM_START pixelShadow

stack_backup        =   SAFERAM_START   ;3b strack address of return
groupvar_eof_ptr    =   stack_backup+3  ;3b

.org userMem-2
.db $EF, $7B

;Let's try to do it all inline. Or as inline as possible. Some of these
;functions are doing nothign but bloating via call overhead.
programStart:
    ; -- Locate string
    ld hl,errCode_Fail
    push hl     ;default action: fail. So many fail points. Cheaper to go to it.
    ;jp $ ;debugging halt
    ld  hl,str0
    call _Mov9ToOP1
    call _FindSym
    ret c       ;Str0 must exist.
    call _ChkInRam
    ret nz      ;Str0 must be in RAM.
    ld  a,(de)  ;only need LSB of string length
    cp  a,MAX_STRING_SIZE+1 ;actual-maxexpected. Must be carry.
    ret nc      ;Str0 must be within max size.
    or  a,a
    jr  nz,handleFont_continueStringLoad
    ; -- String is empty. Re-use this condition to uninstall a font. 
    call _ClrLocalizeHook
    jp errCode_OK
handleFont_continueStringLoad:
    ld  b,a     ;store LSB for loop counter.
    inc de      ;Do not check for MSB of string length. Even if it is nonzero
    inc de      ;we will never read that far. A nonzero MSB sounds like a user problem.
    ; -- Do filename handling tasks
    ld  hl,OP1      ;Object to use ChkFindSym on (OP6 for in-group traverse, if needed)
    call writeObjectType
handleFilename_loop:
    ld  a,(de)
    inc de
    cp  a,tDiv
    jr  nz,handleFilename_continueNameCopy
    ld  (hl),0  ;null terminate
    ld  hl,OP6
    call writeObjectType
    ld  a,GroupObj
    ld  (OP1),a ;change filetype in OP1 now that we know the name is of a group
    jr  handleFilename_skipToLoopEnd
handleFilename_continueNameCopy:
    cp  a,t2ByteTok
    jr  nz,handleFilename_continueNameCopy2
    ld  a,(de)
    inc de
    dec b
    ret z           ;Corrupted 2-byte token. String must not end before this.
    cp  a,t2ByteTok ;There's a hole in the character set at this location.
    ccf             ;carry = (a >= t2ByteTok)
    sbc a,0         ;compress hole
    sub a,tLa-'a'   ;align to ASCII 'a'
handleFilename_continueNameCopy2:
    ld  (hl),a
    inc hl
handleFilename_skipToLoopEnd:
    djnz handleFilename_loop
    xor a,a
    ld  (hl),a ;null terminate
    ; -- Begin file lookup
    call _ChkFindSym
    ret c       ;Object must exist.
    sbc hl,hl   ;Carry guaranteed not set. Clears full HL for later DE swap.
    call _ChkInRam  ;Z in RAM, NZ if archive. Destroys: None.
    ex  de,hl       ;swap ahead of time
    jr  z,handleFileLookup_skipArchiveBytes
    ld  e,3+6   ;Archive header plus VAT copy preamble
    add hl,de
    ld  e,(hl)  ;VAT copy name length
    inc hl
    add hl,de
handleFileLookup_skipArchiveBytes:
    ld  e,(hl)
    inc hl
    ld  d,(hl)
    ld  a,e
    or  a,d
    ret z       ;File must not be empty.
    inc hl
    push hl
        add hl,de
        ld  (groupvar_eof_ptr),hl
    pop hl
    ld  a,(OP1)
    cp  a,GroupObj
    jr  nz,handleFileLookup_checkFont
    ; -- Traverse group file to find font file
handleFileLookup_groupLoop:
    push hl
        ld  de,(groupvar_eof_ptr)
        or  a,a
        sbc hl,de
    pop hl
    ret nc      ;if pointer at or exceed EOF, return.
    ;NOTE: Simplistic checks are in place. This will not handle a badly
    ;corrupted group file. All other checks should catch most problems,
    ;and the hook dispatch routine checks for a valid hook section.
    ld  a,(hl)      ;filetype and flags
    and a,varTypeMask
    ld  c,a
    ld  de,6
    add hl,de
    ld  b,(hl)  ;file name length
    ;inc b
    ;dec b
    ;ret z       ;This check is paranoia. The string compare would fail anyway.
    inc hl
    ld  de,OP6
    ld  a,(de)
    and a,varTypeMask   ;idk if groups would allow flags to be set.
    inc de
    cp  a,c     ;check if type matches
    jr nz,handleFileLookup_fileNotMatch
handleFileLookup_inlineStrCmp:
    ld  a,(de)
    cp  a,(hl)
    jr  nz,handleFileLookup_fileNotMatch
    inc hl
    inc de
    djnz handleFileLookup_inlineStrCmp
    ; -- file matched. Verify file integrity
    mlt bc  ;Side effect on CE. Clears DEU. Actual value of DE irrelevant.
    ld  c,(hl)
    inc hl
    ld  b,(hl)  ;Size
    inc hl
handleFileLookup_checkFont:
    push hl
        ld  hl,(fontPackHeaderEnd-fontPackHeader)-1
        or a,a
        sbc hl,bc   ;expected-actual. Bad if no carry
    pop hl
    ret nc
    ld  de,fontPackHeader
    ld  b,fontPackHeaderEnd-fontPackHeader
handleFileLookup_verifyHeader_loop:
    ld  a,(de)
    cp  a,(hl)
    ret nz
    inc hl
    inc de
    djnz handleFileLookup_verifyHeader_loop
    ; -- File header verified
    inc hl
    inc hl
    inc hl  ;skip distance to font data
    ld  de,(hl) ;get distance to font hook
    add hl,de
    call _SetLocalizeHook ;install hook at HL
errCode_OK:
    pop hl  ;remove errCode_Fail from the stack. We are done. Return success.
    ld  a,ERR_OK
    jr  errorSys
errCode_Fail:
    ld  a,ERR_FAIL
errorSys:
    call _SetxxOP1
    jp   _StoAns
    
handleFileLookup_fileNotMatch:
    inc hl  ;exhaust remaining name field
    djnz handleFileLookup_fileNotMatch
    mlt bc  ;Side effect on CE. Clears BCU. Actual value of BC irrelevant.
    ld  c,(hl)
    inc hl
    ld  b,(hl)
    add hl,bc
    jr  handleFileLookup_groupLoop


;in: HL=destination pointer, DE=string pointer
;out: HL=HL+1, DE is at start of name portion of string.
writeObjectType:
    ld  a,(de)
    cp  a,AppVarObj
    ld  a,ProtProgObj
    jr  nz,writeObjectType_continue
    ld  a,AppVarObj
    inc de
writeObjectType_continue:
    ld  (hl),a
    inc hl
    ret


str0:
.db StrngObj, tVarStrng, tStr0, 0, 0

fontPackHeader:
.db tExtTok,tAsm84CeCmp,$18,$0C,"FNTPK",0
fontPackHeaderEnd:

.echo "Executable size: ", ($-programStart), " bytes"
.end
.end