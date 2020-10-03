;The following commented-out data will be inserted via batch script
;upon building this hook as a resource pack
;StandaloneHookStart:
;.db tExtTok,tAsm84CeCmp,$18,$09,"FNTPK",0,0,0,0,$C9
;

;The code that follows is position-independant.
;-------------------------------------------------------------------------------
;Localization hook -- because TI removed small font support in the font hook
;Input:  A = Event type, other registers depend on the event.
;-- Events we care about: $75=sfont, $76=lFont, $77=sFontwidth, $78=lFont_vw
;
;Input  $75:     B  = character
;Output $75: (Z) HL = location of font data
;
;Input  $76:     B  = character
;Output $76: (Z) HL = location of font data
;
;Input  $77:     B  = character
;Output $77: (Z) B  = width of small font font

;Input  $78:     B  = character
;Output $78: (Z) Contents of lFont_record+1 with font data
;
;-- Events that we MUST handle: $0A, $3A, $3B, $42-$44
;
;-- The bulk of these are due to bugs in handling the case of unhandled events.
;Input  $0A:     HL = Pointer to address of default string, E = function id
;Output $0A: (Z) HL = Pointer to len-prefixed string to use.
;
;Input  $3A:     B  = Variable ID
;Output $3A: (NZ)A  = Variable ID
;Output $3A: (Z) HL = Len-prefixed string variable ID (Window/RclWindow/TblSet)
;
;Input  $3A:     B  = Variable type
;Output $3A: (NZ)A  = Variable type
;Output $3A: (Z) HL = Len-prefixed string variable type (e.g. PRGM, AVAR)
;
;Input  $42-$44  HL = Reset type string (zero-terminated)
;Output $42-$44 (Z)   HL = Reset type string
;Output $42-$44 (NZ)  HL = Reset type string, DE = coord (D=col,E=row)
;
;Input  $D8     I haven't figured this out but it's triggered on catalog help edit
;Output $D8     (Z)   Defaults
;-- Every other event we can preserve registers and emit NZ.

LocalHookStart:
.db $83
      cp    a,$75
      jr    c,lh_HandleOtherEvents
      cp    a,$78+1
      jr    nc,lh_HandleOtherEvents
      inc   b
      dec   b
      jr    z,lh_ReturnDefaults     ;Do not process char 0
      push  hl
            call  __frameset0 ;Does freaky stack stuff.
lh_BaseAddress:               ;HL=return address, IX pushed to stack 
            pop   de          ;Even out stack with unused register
            ld    de,lh_DataStub-lh_BaseAddress
            add   hl,de
            push  hl
                  ld    e,b
                  ld    d,0
                  add   hl,de
                  ld    c,(hl)      ;Offset into table, or $FF
            pop   de
      pop   hl
      inc   c
      jr    z,lh_ReturnDefaults     ;$FF=notmapped
      dec   c
;Preload HL with start of tables and B with number of chars
      ex    de,hl
      ld    b,(hl)
      inc   h           ;increment by 256. files do not cross sector boundaries
      cp    a,$75
      jr    z,lh_HandleSFont        ;Expects A=$75 for draw, 0 for width
      sub   a,$76
      jr    z,lh_HandleLFont
      dec   a
      jr    z,lh_HandleSFont        ;Handle with lh_HandleSFont
lh_HandleLFont:
      ld    b,28
      mlt   bc
      add   hl,bc                   ;offset to large font character
      ld    bc,28
      ld    de,lFont_record+1
      ldir
	xor   a,a
	sbc   hl,hl
	ld    (lFont_record-3),hl
	ld    (lFont_record+0),a
	ld    (lFont_record+1+28),hl
	ld    (lFont_record+1+28+3),a
	ld    hl,lFont_record-3
	ret
      
lh_configvars:
lh_datatypes:
      inc   a
      ld    a,b
lh_ReturnDefaults:
      push  bc
            ld    b,a
            xor   a,a
            inc   a
            ld    a,b
      pop   bc
      ret
      
lh_HandleSFont:
      ld    e,b   ;table length
      ld    d,28  ;width of characters in large font
      mlt   de    ;
      add   hl,de
      ld    b,25  ;width of small font character
      mlt   bc
      add   hl,bc ;completed offset to small font character
      ld    b,(hl)
      or    a,a
      ret   z     ;For handling sfont_width
      ld    de,sFont_record
      ld    bc,25
      ldir
      xor   a,a
	ret   ;bottom row is cleared for us. Thanks, _Load_Sfont.

lh_HandleOtherEvents:
      cp    a,$0A
      jr    z,lh_quasifunct
      cp    a,$3A
      jr    z,lh_configvars
      cp    a,$3B
      jr    z,lh_datatypes
      cp    a,$49
      jr    z,lh_bugged49     ;matrix editor thing
      cp    a,$4A
      jr    z,lh_bugged4A     ;matrix editor thing
      cp    a,$4B
      jr    z,lh_bugged4B     ;matrix editor thing
      cp    a,$4C
      jr    z,lh_bugged4C     ;matrix editor thing. A really buggy bug there.
;     
      cp    a,$9F       ;catalog help. show "ARGUMENT FOR invNorm(" in fancy box
      ret   z
      cp    a,$C9       ;catalog help part 1 (token lookup)
      ret   z
      cp    a,$CA
      ret   z
      cp    a,$CB       ;catalog help part ? (draw help object)
      ret   z
      cp    a,$CC       ;catalog help part ?
      ret   z
      cp    a,$D8       ;catalog help part 2 (token render)
      ret   z
      cp    a,$7A       ;archive variable attempt failure message
      ret   z
;
      cp    a,$42
      jr    c,lh_TestDefaults
      cp    a,$44+1
      jr    nc,lh_TestDefaults
lh_resettype:
      cp    a,a
      ret
lh_quasifunct:
      ld    de,(hl)
      ex    de,hl
      cp    a,a
      ret
lh_TestDefaults:
      push  bc
            ld    c,a
            ld    a,2
            or    a
            ;ld    (-1),a  ;breakpoint
            xor   a
            INC   A
            ld    a,c
      pop   bc
      ret
      
lh_bugged49:
      ld    a,10
      ret
lh_bugged4A:
      ld    a,13
      ret
lh_bugged4B:
      ld    a,12
      ret
;code that would fail to run because jump at return
;isn't supposed to be unconditional
lh_bugged4C:  ;bugged. Used in matrix editor.
      ld    a,$0A
      ld    (curCol),a
      ld    a,(currListHighlight)
      call  _DispListElementOffLA
      ld    a,(curCol)
      cp    a,$0B
      ret   nz
      ld    a,$20
      jp  _PutC
lh_mystery:
      push  af
            ld    a,2
            ld    (-1),a
      pop   af
      ret



.echo "Sizeof hook stub: ",$-LocalHookStart

lh_DataStub:
;This is filled in by the packager. The data format is:
;  1 byte  Number of characters in character pack (1-255)
;255 bytes character mappings indexed by calc encoding (code 0 removed)
;--- Byte in mapped location points to offset in font data ($FF = not mapped)
;  N bytes Large font data (N= 28*numchars)
;  X bytes Small font data (size not calculated. Nothing after this section)
