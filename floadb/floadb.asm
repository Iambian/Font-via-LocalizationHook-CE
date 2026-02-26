;Font Loader for TI-84 Plus CE BASIC programs
;
;Input: 
;   Str0 = name of the font file to load
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

;-----------------------------------------------------------------------------
; Static workspace in safe RAM

#define SAFERAM_START pixelShadow

strDataPtr       = SAFERAM_START       ;3b
strDataLen       = strDataPtr+3        ;2b
pathHasSlash     = strDataLen+2        ;1b
seg1Ptr          = pathHasSlash+1      ;3b
seg1Len          = seg1Ptr+3           ;2b
seg2Ptr          = seg1Len+2           ;3b
seg2Len          = seg2Ptr+3           ;2b
wantedType       = seg2Len+2           ;1b
wantedNameLen    = wantedType+1        ;1b
groupEOFPtr      = wantedNameLen+1     ;3b
memberNamePtr    = groupEOFPtr+3       ;3b
memberDataPtr    = memberNamePtr+3     ;3b
memberNextPtr    = memberDataPtr+3     ;3b

;-----------------------------------------------------------------------------

.org userMem-2
.db $EF, $7B

programStart:
	call installFromStr0
	jp  c,returnFail
returnOK:
	ld  a,ERR_OK
	jr  returnResult
returnFail:
	ld  a,ERR_FAIL
returnResult:
	call _SetxxOP1
	call _StoAns
	ret

;-----------------------------------------------------------------------------
; Top-level loader
; Out: Carry set on failure, reset on success.

installFromStr0:
	call fetchInputString
	ret c
	call parsePath
	ret c
	ld  a,(pathHasSlash)
	or  a,a
	jr  z,installFromStr0_notGroupPath
	call locateFontInGroupPath
	ret c
	jp  _SetLocalizeHook
installFromStr0_notGroupPath:
	call locateStandaloneFont
	ret c
	jp  _SetLocalizeHook

;-----------------------------------------------------------------------------
; Input parsing

; Reads Str0 and stores pointer/length.
; Out: Carry set on failure.
fetchInputString:
	ld  hl,str0
	call _Mov9ToOP1
	call _FindSym
	scf
	ret c
	call _ChkInRam
	scf
	ret nz
	mlt bc
	ex  de,hl
	ld  c,(hl)
	inc hl
	ld  b,(hl)
	inc hl
	ld  a,b
	or  a,c
	scf
	ret z
	ld  (strDataPtr),hl
	ld  (strDataLen),bc
	or  a,a
	ret

; Splits string around '/' token if present.
; Out: Carry set if malformed (e.g. empty segment around '/').
parsePath:
	ld  hl,(strDataPtr)
	ld  bc,(strDataLen)
	ld  (seg1Ptr),hl
	ld  (seg1Len),bc
	xor a,a
	ld  (pathHasSlash),a
	ld  de,0
parsePath_loop:
	ld  a,b
	or  a,c
	jr  z,parsePath_noSlash
	ld  a,(hl)
	cp  a,tDiv
	jr  z,parsePath_foundSlash
	inc hl
	inc de
	dec bc
	jr  parsePath_loop
parsePath_noSlash:
	or  a,a
	ret
parsePath_foundSlash:
	ld  a,d
	or  a,e
	scf
	ret z
	dec bc
	ld  a,b
	or  a,c
	scf
	ret z
	ld  (seg1Len),de
	inc hl
	ld  (seg2Ptr),hl
	ld  (seg2Len),bc
	ld  a,1
	ld  (pathHasSlash),a
	or  a,a
	ret

;-----------------------------------------------------------------------------
; Standalone lookup path (program/appvar)

; Out: HL = hook location, Carry set on failure.
locateStandaloneFont:
	ld  hl,(seg1Ptr)
	ld  bc,(seg1Len)
	call resolveTypePrefix
	ret c
	ld  (wantedType),a
	call makeOP1FromName
	call getOp1NameLength
	ld  a,b
	ld  (wantedNameLen),a
	call _ChkFindSym
	scf
	ret c
	call getVarDataStart
	jp  getHookLocation

;-----------------------------------------------------------------------------
; Group lookup path (GROUP/FONT)

; Out: HL = hook location, Carry set on failure.
locateFontInGroupPath:
	; Build target child object name from second segment.
	ld  hl,(seg2Ptr)
	ld  bc,(seg2Len)
	call resolveTypePrefix
	ret c
	ld  (wantedType),a
	call makeOP1FromName
	call getOp1NameLength
	ld  a,b
	ld  (wantedNameLen),a

	; Find group object from first segment.
	ld  hl,(seg1Ptr)
	ld  bc,(seg1Len)
	ld  a,GroupObj
	call makeOP1FromName
	call _ChkFindSym
	scf
	ret c
	call getVarDataStart
	ex  de,hl

	; Group layout handling:
	; [groupNameLen][groupName...][groupDataSize(2)][member0...]
	ld  c,(hl)
	ld  b,0
	inc hl
	add hl,bc
	ld  c,(hl)
	inc hl
	ld  b,(hl)
	inc hl
	push hl
		add hl,bc
		ld  (groupEOFPtr),hl
	pop hl

locateFontInGroupPath_loop:
	push hl
		ld  de,(groupEOFPtr)
		or  a,a
		sbc hl,de
	pop hl
	jr  nc,locateFontInGroupPath_fail

	ld  a,(hl)
	and a,$1F
	ld  d,a
	ld  bc,6
	add hl,bc
	ld  (memberNamePtr),hl
	ld  c,(hl)
	inc hl
	add hl,bc
	ld  c,(hl)
	inc hl
	ld  b,(hl)
	inc hl
	ld  (memberDataPtr),hl
	push hl
		add hl,bc
		ld  (memberNextPtr),hl
	pop hl

	ld  a,(wantedType)
	cp  a,d
	jr  nz,locateFontInGroupPath_next

	ld  hl,(memberNamePtr)
	ld  a,(hl)
	ld  d,a
	ld  a,(wantedNameLen)
	cp  a,d
	jr  nz,locateFontInGroupPath_next

	inc hl
	ld  de,OP1+1
locateFontInGroupPath_nameCmpLoop:
	ld  a,d
	or  a,a
	jr  z,locateFontInGroupPath_nameMatch
	ld  a,(de)
	cp  a,(hl)
	jr  nz,locateFontInGroupPath_next
	inc de
	inc hl
	dec d
	jr  locateFontInGroupPath_nameCmpLoop

locateFontInGroupPath_nameMatch:
	ld  de,(memberDataPtr)
	jp  getHookLocation

locateFontInGroupPath_next:
	ld  hl,(memberNextPtr)
	jr  locateFontInGroupPath_loop

locateFontInGroupPath_fail:
	scf
	ret

;-----------------------------------------------------------------------------
; Name/type helpers

; In: HL=name start, BC=name length (token string segment)
; Out: A=ProtProgObj or AppVarObj, HL/BC adjusted to name body
;      Carry set if invalid input.
resolveTypePrefix:
	ld  a,b
	or  a,c
	scf
	ret z
	ld  a,(hl)
	cp  a,AppVarObj
	jr  nz,resolveTypePrefix_program
	dec bc
	inc hl
	ld  a,b
	or  a,c
	scf
	ret z
	ld  a,AppVarObj
	or  a,a
	ret
resolveTypePrefix_program:
	ld  a,ProtProgObj
	or  a,a
	ret

; In: A=type, HL=name ptr, BC=token string length
; Out: OP1 prepared for _ChkFindSym, name converted/token-decoded.
makeOP1FromName:
	ld  (OP1),a
	ld  de,OP1+1
	jp  copyNameToOP1

; Out: B = string length of OP1+1, clamped to 31.
getOp1NameLength:
	ld  hl,OP1+1
	ld  b,0
getOp1NameLength_loop:
	ld  a,b
	cp  a,31
	ret z
	ld  a,(hl)
	or  a,a
	ret z
	inc hl
	inc b
	jr  getOp1NameLength_loop

; Used to copy token string to OP1 for _ChkFindSym.
; In: DE=destination, HL=source, BC=size of source token string
copyNameToOP1:
	ld  a,c
	and a,$1F
	ld  b,a
copyNameToOP1_loop:
	ld  a,b
	or  a,a
	jr  z,copyNameToOP1_term
	ld  a,(hl)
	inc hl
	cp  a,t2ByteTok
	jr  nz,copyNameToOP1_copy
	ld  a,(hl)
	inc hl
	dec b
	cp  a,t2ByteTok
	jr  c,$+3
	dec a
	sub a,tLa-'a'
copyNameToOP1_copy:
	ld  (de),a
	inc de
	djnz copyNameToOP1_loop
copyNameToOP1_term:
	xor a,a
	ld  (de),a
	ret

;-----------------------------------------------------------------------------
; Variable access helpers

; In: successful _ChkFindSym result context.
; Out: DE=pointer to start of variable data.
getVarDataStart:
	call _ChkInRam
	ex  de,hl
	jr  z,getVarDataStart_inRam
	ld  de,9
	ld  e,(hl)
	inc hl
	add hl,de
getVarDataStart_inRam:
	mlt de
	ld  e,(hl)
	inc hl
	ld  d,(hl)
	inc hl
	ex  de,hl
	ret

; In: DE = pointer to start of variable data.
; Out: HL = pointer to hook section if valid font.
;      Carry set on invalid/malformed font object.
getHookLocation:
	ex  de,hl
	ld  de,fontPackHeader
	call strcmp
	ret c
	inc hl
	inc hl
	inc hl
	ld  bc,(hl)
	add hl,bc
	or  a,a
	ret

; In: HL=str1, DE=str2
; Out: Carry set if not equal, reset if equal.
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
; Constants

str0:
.db StrngObj, tVarStrng, tStr0, 0, 0

fontPackHeader:
.db tExtTok,tAsm84CeCmp,$18,$0C,"FNTPK",0

.echo "Executable size: ", ($-programStart), " bytes"
.end











