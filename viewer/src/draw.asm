.assume adl=1
XDEF _DrawLFontExample
XDEF _DrawSFontExample
XDEF _InitVarSearch
XDEF _VarSearchNext
XDEF _VarSearchPrev
XDEF _GetFontStruct
XDEF _GetKbd
XDEF _PrintOp1
XDEF _PrintOp4
XDEF _fn_Setup_Palette
XDEF _InstallHook
XDEF _UninstallHook

XREF _gfx_PrintChar
XREF _kb_Scan
XREF _groupmain
XREF _grouptemp
XREF _groupcurvar




flags             EQU $D00080 ;As defined in ti84pce.inc
_LoadPattern      EQU $021164 ;''
_FindAlphaDn      EQU $020E90 ;''
_FindAlphaUp      EQU $020E8C ;''
_ChkFindSym       EQU $02050C ;''
_ChkInRam         EQU $021F98 ;'' NC if in RAM, C if in arc
_PopRealO1        EQU $0205DC ;''
_PopRealO2        EQU $0205D8 ;''
_PopRealO4        EQU $0205D0 ;''
_PushRealO1       EQU $020614 ;''
_PushRealO4       EQU $020608 ;''
_SetLocalizeHook  EQU $0213F0 ;''
_ClrLocalizeHook  EQU $0213F4 ;''
_SetFontHook      EQU $021454 ;''
_ClrFontHook      EQU $021458 ;''



prevDData         EQU $D005A1 ;''
lFont_record      EQU $D005A4 ;''
sFont_record      EQU $D005C5 ;''
Op1               EQU $D005F8 ;''
Op2               EQU $D00603 ;''
Op3               EQU $D0060E ;''
Op4               EQU $D00619 ;''
Op5               EQU $D00624 ;''
Op6               EQU $D0062F ;''



DRAW_BUFFER       EQU $E30014
fontdata_offset   EQU 3



;Drawing area for large font (starting at prevDData). Offsets wrt fFont_record
;Filled in areas are what is guaranteed to render.
;Draw area is (14w by 18h, though fonts are 12w by 14h
;rw ofs byte1 byte2    fill
;00 -03 00000 00000000 0
;01 +01 00000 00000000 0
;02 +01 11111 11111110 0
;03 +03 11111 11111110 0
;04 +05 11111 11111110 0
;05 +07 11111 11111110 0
;06 +09 11111 11111110 0
;07 +0B 11111 11111110 0
;08 +0D 11111 11111110 0
;09 +0F 11111 11111110 0
;10 +11 11111 11111110 0
;11 +13 11111 11111110 0
;12 +15 11111 11111110 0
;13 +17 11111 11111110 0
;14 +19 11111 11111110 0
;15 +1B 11111 11111110 0
;16 +1D 00000 00000000 0
;17 +1F 00000 00000000 0
;--------------------------------
;22 characters fit on a line. 12 lines required to cover full range.
;Line height at 18 requires 216h. Acceptable results with LH=16 req 192.
;Starting Y coord can be either 24 or 48, respectively.
;Starting X coord at 6. This can be calculated.
;void DrawLFontExample( fontstruct *data )
;fontstruct contains: encodings,lfont,sfont
_DrawLFontExample:
      di
      ld    iy,flags
      ld    hl,fontdata_offset
      add   hl,sp
      ld    hl,(hl)
      push  ix
            ld    bc,(iy+$34)       ;fontflags and hooks
            push  bc
                  xor   a,a
                  ld    (iy+$35),a  ;temporarily clears local and font hooks
                  set   2,(iy+$32)  ;sets fracDrawLFont to get large font pattern
                  push  hl
                        ;keep font base for ease of lookup and less register juggling
                        ld    de,$000100
                        add   hl,de
                        ld    (DLFE_BaseAddress),hl
                        or    a,a
                        sbc   hl,hl
                        ld    (DLFE_CurrentPosition),hl
                  pop   de
                  inc   de
                  ld    b,255
DLFE_MainLoop:
                  push  bc
                        ld    a,(de)
                        inc   de
                        push  de
                              push  hl
                                    inc   a
                                    jr    nz,DLFE_LoadCharacterFromFontmap
                                    ld    a,b
                                    neg
                                    call  _LoadPattern
                                    jr    DLFE_DrawPattern
DLFE_LoadCharacterFromFontmap:
                                    dec   a
DLFE_BaseAddress  EQU $+1
                                    ld    hl,0
                                    ld    e,28
                                    ld    d,a
                                    mlt   de
                                    add   hl,de
                                    ld    de,lFont_record+1
                                    ld    bc,28
                                    ldir
DLFE_DrawPattern:
                              pop   hl
DLFE_CurrentPosition EQU $+1
                              ld    hl,0  ;H=row (0-11), L=col (0-21)
                              ld    de,0  ;pre-clear
                              ld    a,L
                              inc   a
                              cp    a,22
                              ld    L,a
                              jr    c,$+4
                              ld    L,e   ;L=0
                              inc   h
                              ld    (DLFE_CurrentPosition),hl
                              ld    e,L   ;E=column
                              ld    d,14  ;D=pix per column
                              mlt   de    ;partial X-offset
                              ld    L,160 ;L=scrnw/2, H=row
                              mlt   hl
                              add   hl,hl ;Y offset in pixels
                              add   hl,hl
                              add   hl,hl
                              add   hl,hl
                              add   hl,hl ;x16 = Y offset in 16px tall rows.
                              add   hl,de ;Somewhat completed X+Y offset
                              ld    de,(DRAW_BUFFER)
                              add   hl,de ;Somewhat complete screen address
                              ld    de,(320*48)+6     ;Additional looks-good offsets
                              add   hl,de ;Completed screen address
                              ld    c,14  ;14 characters tall
                              ld    de,lFont_record+1
DLFE_DrawLargeCharacterLoop:
                              ld    b,5   ;first byte
                              ld    a,(de)
                              inc   de
DLFE_DLCL_Stage1Loop:
                              add   a,a
                              jr    nc,$+4
                              ld    (hl),0
                              inc   hl
                              djnz  DLFE_DLCL_Stage1Loop
                              ld    b,7   ;second byte
                              ld    a,(de)
                              inc   de
DLFE_DLCL_Stage2Loop:
                              add   a,a
                              jr    nc,$+4
                              ld    (hl),0
                              inc   hl
                              djnz  DLFE_DLCL_Stage2Loop
                              ld    a,c
                              ld    bc,320-12
                              add   hl,bc
                              ld    c,a
                              dec   c
                              jr    nz,DLFE_DrawLargeCharacterLoop
                        pop   de
                  pop   bc
                  dec   b
                  jp    nz,DLFE_MainLoop
            pop   bc
            res   2,(iy+$32)        ;docs says to reset this flag on exit
            ld    (iy+$34),bc       ;restores hooks
      pop   ix
      ret









;This one is going to be a touch tricky. We should probably fill in as much of
;a line as possible before going onto the next one. Characters can be up to
;16 pixels wide but they'll most certainly not all be that fat. Let's assume
;that they will so super fat fonts won't break this. (20 chr per line)
;These characters are 12 px high, so the line height can be 14.
;
;I... guess we could just grid it like the large font? 20 chr per line 
;gives us 13 lines required for a height of 182 pixels (Y start at 58).
;
;So an X start of 0 and a Y start of 48. For consistency.
;
;



;FOLLOWING CODE NOT WORK. YOU MUST ADAPT THIS TO WORK ON SMALL FONT.
;WHICH PROBABLY MEANS OVER HALF THIS CODE WILL BE BROKEN APART AND REPLACED
;WITH SOMETHING THAT WILL WORK WITH SMALL FONTS. BECAUSE THEY'RE JUST THAT
;DIFFERENT ONCE YOU GET PAST THE OVERHEAD OF WRITING THE PATTERN.
;
;void DrawSFontExample( fontstruct *data )
;fontstruct contains: encodings,lfont,sfont
_DrawSFontExample:
      di
      ld    iy,flags
      ld    hl,fontdata_offset
      add   hl,sp
      ld    hl,(hl)
      push  ix
            ld    bc,(iy+$34)       ;hooks
            push  bc
                  xor   a,a
                  ld    (iy+$35),a  ;temporarily clears local and font hooks
                  res   2,(iy+$32)  ;resets fracDrawLFont to ensure smallfont
                  push  hl
                        ;keep font base for ease of lookup and less register juggling
                        ld    c,(hl)
                        ld    b,28
                        mlt   bc
                        ld    de,$000100
                        add   hl,de
                        add   hl,bc
                        ld    (DSFE_BaseAddress),hl   ;smallfont base address
                        or    a,a
                        sbc   hl,hl
                        ld    (DSFE_CurrentPosition),hl
                  pop   de
                  inc   de
                  ld    b,255
DSFE_MainLoop:
                  push  bc
                        ld    a,(de)
                        inc   de
                        push  de
                              push  hl
                                    inc   a
                                    jr    nz,DSFE_LoadCharacterFromFontmap
                                    ld    a,b
                                    neg
                                    call  _LoadPattern
                                    jr    DSFE_DrawPattern
DSFE_LoadCharacterFromFontmap:
                                    dec   a
DSFE_BaseAddress  EQU $+1
                                    ld    hl,0
                                    ld    e,25
                                    ld    d,a
                                    mlt   de
                                    add   hl,de
                                    ld    de,sFont_record
                                    ld    bc,25
                                    ldir
DSFE_DrawPattern:
                              pop   hl
DSFE_CurrentPosition EQU $+1
                              ld    hl,0  ;ok. not sure how to do positioning.
                              ld    de,0  ;pre-clear
                              ld    a,L
                              inc   a
                              cp    a,20
                              ld    L,a
                              jr    c,$+4
                              ld    L,e   ;L=0
                              inc   h
                              ld    (DSFE_CurrentPosition),hl
                              
                              ld    c,L   ;C=column
                              ld    b,16  ;B=pix per column
                              mlt   bc    ;partial X-offset. Also sets BCU to 0
                              ld    L,14  ;H= line num (0-12) L=line height (res < 255)
                              mlt   hl
                              ld    h,160 ;half screen width
                              mlt   hl
                              add   hl,hl ;finish width
                              add   hl,bc ;Somewhat completed X+Y offset
                              ld    de,(DRAW_BUFFER)
                              add   hl,de ;Somewhat complete screen address
                              ld    de,(320*48)+0     ;Additional looks-good offsets
                              add   hl,de ;Completed screen address
                              
                              ld    de,sFont_record   ;first byte is object width
                              ld    c,12              ;characters are 12 px tall
                              ld    a,(de)
                              inc   de
                              cp    a,9
                              jr    c,DSFE_DrawThinChar
                              sub   a,8
                              ld    (DSFE_DrawWideCharWidth),a
DSFE_DrawWideCharMainLoop:
                              push  hl
                                    ld    b,8
                                    ld    a,(de)
                                    inc   de
DSFE_DrawWideCharLoop1:
                                    add   a,a
                                    jr    nc,$+4
                                    ld    (hl),0
                                    inc   hl
                                    djnz  DSFE_DrawWideCharLoop1
DSFE_DrawWideCharWidth EQU $+1
                                    ld    b,0
                                    ld    a,(de)
                                    inc   de
DSFE_DrawWideCharLoop2:
                                    add   a,a
                                    jr    nc,$+4
                                    ld    (hl),0
                                    inc   hl
                                    djnz  DSFE_DrawWideCharLoop2
                              pop   hl
                              ld    a,c
                              inc   b     ;B is always zero when reach here, so sets 1.
                              ld    c,64  ;256+64 = 320. The number we're after.
                              add   hl,bc
                              ld    c,a
                              dec   c
                              jr    nz,DSFE_DrawWideCharMainLoop
                              jr    DFSE_FinishCharDraw
DSFE_DrawThinChar:
                              ld    (DSFE_DrawThinCharWidth),a
DSFE_DrawThinCharMainLoop:
                              push  hl
DSFE_DrawThinCharWidth  EQU $+1
                                    ld    b,0
                                    ld    a,(de)
                                    inc   de
DSFE_DrawThinCharLoop:
                                    add   a,a
                                    jr    nc,$+4
                                    ld    (hl),0
                                    inc   hl
                                    djnz  DSFE_DrawThinCharLoop
                              pop   hl
                              ld    a,c
                              inc   b     ;B is always zero when reach here, so sets 1.
                              ld    c,64  ;256+64 = 320. The number we're after.
                              add   hl,bc
                              ld    c,a
                              dec   c
                              jr    nz,DSFE_DrawThinCharMainLoop
DFSE_FinishCharDraw:
                        pop   de
                  pop   bc
                  dec   b
                  jp    nz,DSFE_MainLoop
            pop   bc
            ld    (iy+$34),bc       ;restores hooks
      pop   ix
      ret
      
;---------------------------

_PrintOp1:
      ld    hl,Op1+1
      jr    PrintNameInOp
_PrintOp4:
      ld    hl,Op4+1
PrintNameInOp:
      ld    b,8
PrintNameInOpLoop:
      ld    a,(hl)
      inc   hl
      or    a
      ret   z
      push  hl
            ld    c,a
            push  bc
                  call _gfx_PrintChar
            pop   bc
      pop   hl
      djnz PrintNameInOpLoop
      ret
      
;------------------------

_fn_Setup_Palette:
	LD    HL,0E30019h
	RES   0,(HL)       ;Reset BGR bit to make our mapping correct
	LD	BC,0
	LD	IY,0E30200h  ;Address of palette
;palette index format: IIRRGGBB palette entry: IBBBBBGG GGGRRRRR
setupPaletteLoop:
	LD	HL,0
	;PROCESS BLUE. TARGET 0bbii0--
	LD	A,B
	RRCA               ;BIIRRGGB
	LD    E,A          ;Keep for red processing
	RRCA               ;BBIIRRGG
	LD	C,A          ;Keep for green processing
	RRCA               ;GBBIIRRG
	AND	A,01111000b  ;0BBII000
	LD	H,A          ;Blue set.
	;PROCESS GREEN. TARGET ii0000gg, MASK LOW NIBBLE INTO HIGH BYTE
	LD    A,C           ;BBIIRRGG
	XOR	H            ;xxxxxxyy
	AND	A,00000011b  ;keep low bits to mask back to original
	XOR	H            ;0BBII0GG
	LD	H,A          ;Green high set (------GG)
	LD	L,B          ;Green low set  (II------)
	;PROCESS RED. TARGET 000rrii0
	LD	A,B          ;IIRRGGBB
	RLC   A            ;IRRGGBBI      
	RLC   A            ;RRGGBBII      
	RLC   A            ;RGGBBIIR
	XOR	E            ;-----xx-
	AND	A,00000110b
	XOR	E            ;biiRRIIb
	XOR   A,L          ;---xxxx-
	AND   A,00011110b
	XOR	L            ;IIxRRIIx
	AND	A,11011110b  ;II0RRII0
	LD	L,A
      SET   7,H
	LD	(IY+0),HL
	LEA   IY,IY+2
	INC   B
	JR    NZ,setupPaletteLoop
	RET
      
;======================================================================================
;======================================================================================
;======================================================================================

;Warning: DO NOT RUN THE FOLLOWING IF InitVarSearch FAILED, ELSE INFINITE LOOP HAPPENS
;uint8_t VarSearchNext(void)
;uint8_t VarSearchPrev(void)




;The following three routines requires Op1 to remain intact between runnings.
;You could probably use Op4-Op6 as temporary storage if you're doing subsearching.
;No inputs, but same outputs as VarSearchNext.

;Return values: 0=success, $FF=failure
;uint8_t InitVarSearch(uint8_t vartype) - $05=prog,$06=protprog, $15=appvar, $17=group
_InitVarSearch:
      ld    hl,3
      add   hl,sp       ;should reset carry.
      ld    a,(hl)
      sbc   hl,hl
      ld    (_groupcurvar),hl
      ld    (_groupmain),hl
      ld    l,a
      ld    (Op1),hl
      push  ix
initvarsearch_loop:
            ld    a,1
            call  iteratefiles
            
            ;call  _FindAlphaUp
            jr    c,initvarsearch_finish
            ;call  _ChkFindSym
            ;and   a,$3F
            ;cp    a,$17
            ;jr    nz,initvarsearch_normalvar
            ;call  EnumGroup
            ;or    a,a
            ;jr    z,initvarsearch_loop    ;keep searching if group has no fonts
            jr    initvarsearch_finish
initvarsearch_normalvar:
            call  getfontstruct
            jr    c,initvarsearch_loop
initvarsearch_finish:
      pop   ix
      sbc   a,a
      ret
      
;----------------------------------------------------------------
_VarSearchNext:
      push  ix
            call  _PushRealO1
            call  _PushRealO4
_VarSearchNextLoop:
            ld    a,1
            call  iteratefiles
            
            ;call  _FindAlphaUp
            jr    c,varsarch_filenotfound
            ;call  _ChkFindSym
            ;call  getfontstruct
            ;jr    c,_VarSearchNextLoop
            sbc   a,a
varsearch_entryfound:
            call  _PopRealO2  ;Evens out stack without overwriting OP1.
            call  _PopRealO2  ;Evens out stack without overwriting OP1.
      pop   ix
      ret
varsarch_filenotfound:
            call  _PopRealO4
            call  _PopRealO1
      pop   ix
      ret
;----------------------------------------------------------------
      
      
_VarSearchPrev:
      push  ix
            call  _PushRealO1
            call  _PushRealO4
_VarSearchPrevLoop:
            ld    a,-1
            call  iteratefiles
            ;call  _FindAlphaDn
            jr    c,varsarch_filenotfound
            ;call  _ChkFindSym
            ;call  getfontstruct
            ;jr    c,_VarSearchPrevLoop
            jr    varsearch_entryfound
      
;----------------------------------------------------------------

getdatasection:
      call  _ChkInRam
      ret   nc
      ex    de,hl
      ld    de,9
      add   hl,de
      ld    e,(hl)
      add   hl,de
      ex    de,hl
      inc   de
      ret

;Use immediately after a chkfindsym. CA=1 if not a font. Else HL= &fontstruct
;Do not use this on a group. Use this on individual files inside a group (DE=adr)
getfontstruct:
      call  getdatasection
      inc   de
      inc   de
      ld    hl,getfontstuct_header
      call  strcmp
      jr    nz,getfontstruct_failure
      ex    de,hl       ;HL=ptr to offset
      ld    de,(hl)     ;DE=offset
      ex    de,hl
      add   hl,de       ;HL= &fontstruct, DE=location of offset table
      or    a,a
      ret
getfontstruct_failure:
      or    a,a
      sbc   hl,hl
      scf
      ret
getfontstuct_header:
.db $EF,$7B,$18,$0C,"FNTPK",0
sizeof_fontheader equ $-getfontstuct_header

;DE=str1, HL=str2. Z=match. NZ=nomatch.
strcmp:
      push  bc
            ld    c,$FF
strcmp_loop:
            ld    a,(de)
            inc   de
            cpi
            jr    nz,strcmp_fail
            or    a,a
            jr    nz,strcmp_loop
strcmp_fail:
      pop   bc
      ret
            
            
      



;Possible solution for group support: If a group is in Op1, run a search for
;a file named in Op4 within the group? Idk, but it would need to be supported
;as a subpart of FindAlphaUp/Dn combined with ChkFindSym/self rollout for such
;as a search-within-group thing.
;Input: Op1 = varname.
;fonstruct* GetFontStruct(void)
;Returns NULL if not found.
_GetFontStruct:
      call  _ChkFindSym
      and   a,$3F
      cp    a,$17
      jp    nz,getfontstruct
      call  lookupgroupentry
      ld    de,(hl)
      ex    de,hl
      add   hl,de
      ret
      
      
      
      

getkbd_prevkey: db 0
;out: A=newkey
_GetKbd:
	CALL _kb_Scan
	LD	 A,(16056338)
	LD	 C,A
	LD	 A,(16056350)
	LD	 HL,getkbd_prevkey
	OR	 A,C	;COMBINE KEYGROUPS 1 AND 7.
	LD	 C,A
	LD	 A,(HL)
	XOR	 A,C
	AND	 A,C	;(prevkey^curkey)&curkey = nextkey (return value)
	LD	 (HL),C	;SAVE CURKEY TO PREVKEY
	RET
      
      
;Carry if error condition encountered.
;A and HL = numentries that are fonts (start of ARCVAT for name retrieval)
EnumGroup:
      call  getdatasection
      or    a,a
      sbc   hl,hl
      ld    (_grouptemp),hl   ;clear out item count
      ex    de,hl
      ld    e,(hl)
      inc   hl
      ld    d,(hl)
      inc   hl
      push  hl
            add   hl,de
            ex    (sp),hl     ;stack: endaddress, HL=curaddress
enumgroup_mainloop:
            ld    a,(hl)
            cp    a,$06
            jr    z,enumgroup_keepgoing
            cp    a,$15
            jr    z,enumgroup_keepgoing
enumgroup_stop:
      pop   hl
      xor   a,a
      sbc   hl,hl
      scf
      ret
enumgroup_keepgoing:
            push  hl          ;stack: address at archived VAT entry
                  ld    bc,6
                  add   hl,bc
                  ld    c,(hl)
                  inc   hl
                  ld    de,Op4
                  ld    (de),a
                  inc   de
                  ldir
                  ld    (de),a
                  ld    c,(hl)
                  inc   hl
                  ld    b,(hl)
                  inc   hl
                  push  hl
                        add   hl,bc
                        ex    (sp),hl  ;stack: end of variable, HL=SoF
                        ld    de,getfontstuct_header
                        call  strcmp
                  pop   hl          ;EoV
                  ex    (sp),hl     ;stack: EoV, HL=ARCVAT start
                  jr    nz,enumgroup_notfont
                  ex    de,hl
                  ld    hl,_grouptemp
                  ld    bc,(hl)
                  inc   bc
                  ld    (hl),bc
                  ld    b,3
                  mlt   bc
                  add   hl,bc
                  ld    (hl),de
enumgroup_notfont:
            pop   hl          ;End of Variable
      pop   de                ;End of Group (should always be larger)
      or    a,a
      sbc   hl,de             ;When it isn't, it's time to quit.
      jr    nc,enumgroup_finish
      push  de
            add   hl,de       ;Undo the subtract and keep trucking along
            jr enumgroup_mainloop
enumgroup_finish:
      ld    a,(_grouptemp)
      or    a,a
      jr    z,enumgroup_stop+1
      ld    hl,1
      ld    (_groupcurvar),hl       ;if found, then start copying
      ld    hl,_grouptemp           ;grouptemp to groupmain and
      push  hl
            ld    de,_groupmain           ;use that as the base for searches
            ld    bc,3*256
            ldir
      pop   hl
      ld    a,(hl)
      ld    hl,(hl)
      or    a,a
      ret
               


;A= -1 for prev, 1 for next. Op1 for type
iteratefiles:
      ld    (iteratefiles_iterdir),a
iteratefilesloop:
      ld    a,(Op1)
      cp    a,$17
iteratefiles_nogrouptest:
iteratefiles_iterdir    EQU   $+1
      ld    b,0
      jr    nz,iterate_over_filesystem
      push  bc
            ld    hl,(_groupmain)
            ld    de,(_groupcurvar)
            ;ld    a,2
            ;ld    (-1),a
            call  checkgroupcount
      pop   bc
      ret   nc    ;next object found if not carry, otherwise try to find next file
iterate_over_filesystem:
      call  iteratefiles_filesystraverse  ;alphaup or alphadn
      ret   c                             ;no more files to find
      call  _ChkFindSym                   ;if found, get details
      ret   c
      and   a,$3F
      cp    a,$17
      jr    nz,iteratefiles_normalfile    ;if not group, normalfile stuffs
      call  EnumGroup                     ;Check if valid group and set
      or    a,a                           ;up pointers if so
      ld    a,(iteratefiles_iterdir)
      ld    b,a
      jr    z,iterate_over_filesystem     ;otherwise set B and check next file
      inc   a
      jr    z,iteratefiles_setlast
      ld    hl,1
      jr    iteratefiles_setgroupcurvar
iteratefiles_setlast:
      ld    hl,(_groupmain)
iteratefiles_setgroupcurvar:
      ld    (_groupcurvar),hl
      jp    lookupgroupentry        ;ensure Op4 is correctly set before exiting
iteratefiles_normalfile:
      call  getfontstruct
      ret   nc
      jr    iteratefilesloop

iteratefiles_filesystraverse:
      inc   b
      jp    z,_FindAlphaDn
      jp    _FindAlphaUp

;in: B= groupcurvar delta.
;out: groupmain changed, C if out of range. Else HL=AddressOfOffsetFields
checkgroupcount:
      ld    hl,_groupcurvar
      ld    a,(hl)
      add   a,b
      ld    b,a
      jr    z,checkgroupcount_empty
      ld    a,(_groupmain)
      or    a,a
      jr    z,checkgroupcount_empty
      cp    a,b
      ret   c
      ld    (hl),b
      jr    lookupgroupentry
checkgroupcount_empty:
      scf
      ret

;input:   _groupmain and _groupcurvar set correctly.
;output: HL=start of offsets in header, Op4 set to var name. Carry reset.
lookupgroupentry:
      ld    de,(_groupcurvar)
      ld    hl,_groupmain
      ld    d,3
      mlt   de
      add   hl,de
      ld    hl,(hl)
      ld    de,Op4
      ldi
      ld    bc,6-1
      add   hl,bc
      ld    c,(hl)
      inc   hl
      ldir
      xor   a,a
      ld    (de),a
      ld    de,2+sizeof_fontheader
      add   hl,de
      ret

;---------------------------------------------------------------------------



_InstallHook:
      ld    iy,flags
      call  _GetFontStruct
      ex    de,hl
      inc   hl
      inc   hl
      inc   hl
      ld    de,(hl)
      add   hl,de
      jp    _SetLocalizeHook
      
_UninstallHook:
      ld    iy,flags
      ld    a,(flags+$35)
      bit   1,a         ;localize hook
      jr    z,uninstallhook_notinstalled
      call  _ClrLocalizeHook
      xor   a,a
      ret
uninstallhook_notinstalled:
      scf
      sbc   a,a
      ret










