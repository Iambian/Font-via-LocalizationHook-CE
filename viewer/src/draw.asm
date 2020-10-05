.assume adl=1
XDEF _DrawLFontExample


DRAW_BUFFER EQU $E30014

fontdata_offset EQU 3

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
;uint8_t DrawLFontExample( fontstruct *data )
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
                  set   (iy+$32)    ;sets fracDrawLFont to get large font pattern
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
DLFF_ExitSuccess:
                  xor   a,a
DLFE_Exit:
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
                  RES   (iy+$32)    ;resets fracDrawLFont to ensure smallfont
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
                              
                              
                              ;
                              ;The stuff following has to be adapated for smallfont.
                              ;this has not been done yet because i need the sleep.
                              ;They say sleep is for the weak.
                              ;I guess I'm just tired.
                              ;
                              
                              
                              
                              
                              ld    de,0  ;pre-clear
                              ld    a,L
                              inc   a
                              cp    a,22
                              ld    L,a
                              jr    c,$+5
                              ld    L,e   ;L=0
                              inc   h
                              ld    (DSFE_CurrentPosition),hl
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
DSFE_DrawLargeCharacterLoop:
                              ld    b,5   ;first byte
                              ld    a,(de)
                              inc   de
DSFE_DLCL_Stage1Loop:
                              add   a,a
                              jr    nc,$+4
                              ld    (hl),0
                              inc   hl
                              djnz  DSFE_DLCL_Stage1Loop
                              ld    b,7   ;second byte
                              ld    a,(de)
                              inc   de
DSFE_DLCL_Stage2Loop:
                              add   a,a
                              jr    nc,$+4
                              ld    (hl),0
                              inc   hl
                              djnz  DSFE_DLCL_Stage2Loop
                              ld    (hl),0
                              inc   hl
                              ld    (hl),0
                              ld    a,c
                              ld    bc,320-13
                              add   hl,bc
                              ld    c,a
                              dec   c
                              jr    nz,DSFE_DrawLargeCharacterLoop
                        pop   de
                  pop   bc
                  dec   b
                  jp    nz,DSFE_MainLoop
DLFF_ExitSuccess:
                  xor   a,a
DSFE_Exit:
            pop   bc
            ld    (iy+$34),bc       ;restores hooks
      pop   ix
      ret


