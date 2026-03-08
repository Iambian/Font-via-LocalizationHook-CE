;The following commented-out data will be inserted via batch script
;upon building this hook as a resource pack
;fh_StandaloneHookStart:
;.db tExtTok,tAsm84CeCmp,$18,$09,"LFNPK",0,0,0,0,0,0,0,$C9
;

;The code that follows is position-independant.
;-------------------------------------------------------------------------------
;Font Hook - Small font rendering is bugged (associated events are never called)
;  so this hook is only good for rendering fixed-width large font objects. The
;  "known inputs" are taken from earlier versions of the OS, as they largely
;  work the same way. Except in cases where it doesn't.
;
;Legacy information:
;  in: B=char, HL=chardatAdr, A= hook mode
;  out:
;     Cancel hook action: NZ, retain B,HL
;     Accept hook action: Z. Other outputs are as follows:
;Inputs: B=chr, HL=adrToChrFont, A= (0=smf, 1=lgf_fix, 2=smfwidth, 3=lgf_vwd)
;Return value: NZ=cancel hook action (B,HL must be intact). Z=accept hook action
;Return values: Z=accept hook action.
;	Mode 0: HL in RAM where font data is copied to. prefer sFont_record.
;	Mode 1: HL in RAM where font data is copied to. prefer lFont_record
;	Mode 2: B is the width of the small font character.
;	Mode 3: HL in RAM where font data is copied to. Must be offset by +1.
;
;We will only be handling mode 1 calls.
;
#include "macros.inc"

FontHookStart:
.db $83
    dec a       ;processing only event 1 (large font fixed-width)
    ret nz      ;return if not event 1
    inc b
    dec b
    jr  z,fh_ReturnDefaults     ;Do not process char 0
    push hl
        ;Below is a boot call used by C runtimes to set up the stack frame.
        ;All we care about is the return address, which is set in HL.
        ;We don't know what IX was nor do we care. It gets popped off the stack.
        call __frameset0
fh_BaseAddress:
        pop de    ;Discard pushed data that __frameset0 put on the stack.
        ld  de,fh_DataStub-fh_BaseAddress
        assert((fh_DataStub-fh_BaseAddress) < 256, "fh_DataStub must be within 256 bytes of fh_BaseAddress")
        add hl,de   ;Advance HL to data stub (mapping table)
        ex  de,hl   ;DE=ptr, HL=offset (limit 1 byte, others zeroed.)
        ld  L,b
        add hl,de
        ld  a,(hl)  ;Mapping retrieved, DE still preserved.
        inc d
    pop hl
    inc a
    jr  z,fh_ReturnDefaults     ;$FF=notmapped
    dec a
;We now know that we can override the font data. Begin calculations.
    ld  ix,lFont_record
    ld  L,28
    ld  H,a
    mlt hl
    add hl,de   ;pointer to font data entry
    ld  bc,28
    lea de,ix+1
    ldir
    xor a,a
    sbc hl,hl
    ld  (ix-3),hl
    ld  (ix+0),a
    ld  (ix+29),a
    ld  (ix+30),hl
    lea hl,ix-3
    ret ;37

fh_ReturnDefaults:
      inc a       ;A=0 (or at least not $FF) on entry. Inc to return NZ.
      ret


.echo "Sizeof hook stub: ",$-FontHookStart

fh_DataStub:
;This is filled in by the packager. The data format is:
;  1 byte  Number of characters in character pack (1-255)
;255 bytes character mappings indexed by calc encoding (code 0 removed)
;--- Byte in mapped location points to offset in font data ($FF = not mapped)
;  N bytes Large font data (N= 28*numchars)
