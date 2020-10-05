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

XREF _gfx_PrintChar
XREF _kb_Scan


flags             EQU $D00080 ;As defined in ti84pce.inc
_LoadPattern      EQU $021164 ;''
_FindAlphaDn      EQU $020E90 ;''
_FindAlphaUp      EQU $020E8C ;''
_ChkFindSym       EQU $02050C ;''
_ChkInRam         EQU $021F98 ;'' NC if in RAM, C if in arc

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
      ld    hl,(hl)
      push  ix
            ld    bc,(iy+$32)       ;fontflags and hooks
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
                              jr    c,$+5
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
                              ld    (hl),0
                              inc   hl
                              ld    (hl),0
                              ld    a,c
                              ld    bc,320-13
                              add   hl,bc
                              ld    c,a
                              dec   c
                              jr    nz,DLFE_DrawLargeCharacterLoop
                        pop   de
                  pop   bc
                  dec   b
                  jp    nz,DLFE_MainLoop
            pop   bc
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
      ld    hl,(hl)
      push  ix
            ld    bc,(iy+$32)       ;fontflags and hooks
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
                              jr    c,$+5
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
                              jr    nc,DSFE_DrawThinChar
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
      ld    l,a
      ld    (Op1),hl
initvarsearch_loop:
      call  _FindAlphaUp
      jr    c,initvarsearch_finish
      call  _ChkFindSym
      call  getfontstruct
      jr    c,initvarsearch_loop
initvarsearch_finish:
      sbc   a,a
      ret
      
;rawrf.
_VarSearchNext:
      call  _FindAlphaUp
      jr    c,initvarsearch_finish
      call  _ChkFindSym
      call  getfontstruct
      jr    c,_VarSearchNext
      sbc   a,a
      ret
_VarSearchPrev:
      call  _FindAlphaDn
      jr    c,initvarsearch_finish
      call  _ChkFindSym
      call  getfontstruct
      jr    c,_VarSearchPrev
      sbc   a,a
      ret
      

;Use immediately after a chkfindsym. CA=1 if not a font. Else HL= &fontstruct
;Do not use this on a group. Use this on individual files inside a group (DE=adr)
getfontstruct:
      ret   c
      call  _ChkInRam
      ex    de,hl
      jr    nc,getfontstruct_inram
      ld    de,9
      add   hl,de
      ld    e,(hl)
      add   hl,de
      ex    de,hl
      inc   de
getfontstruct_inram:
      inc   de
      inc   de
      ld    hl,getfontstuct_header
      call  strcmp
      jr    nz,getfontstruct_failure
      ld    hl,(hl)
      add   hl,de
      or    a,a
      ret
getfontstruct_failure:
      or    a,a
      sbc   hl,hl
      scf
      ret
getfontstuct_header:
.db $EF,$7B,$18,$09,"FNTPK",0

;DE=str1, HL=str2. Z=match. NZ=nomatch.
strcmp:
      push  bc
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
      jp    getfontstruct
      

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
      
_PrintOp1:
      ld    hl,Op1
      jr    PrintNameInOp
_PrintOp4:
      ld    hl,Op4
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
      
      








