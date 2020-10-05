.assume adl=1

#include "src/ti84pce.inc"


;Main program stub:
;Contains offset to hook at a predictable location for use in font previewing.
;Installs or uninstalls hook depending on if one is already installed
;Install: Archives itself, then installs using hook location in archive
;Uninstall: Clears hook
;-------------------------------------------------------------------------------
.org userMem-2
.db tExtTok,tAsm84CeCmp
ProgramStart:
      jr ProgramContinue
LocalHookOffset:
.db "FNTPK",0
.dl   lh_DataStub-$  ;Used for font previewing program
ProgramContinue:
      bit   localizeHookActive,(iy+hookflags3)
      jr    nz,pgm_Uninstall
ProgramMainLoop:
      call  _PushRealO1
      call  _ChkFindSym
      call  _ChkInRam
      jr    nz,pgm_IsArchived
      call  _Arc_Unarc
      call  _PopRealO1
      jr    ProgramMainLoop
pgm_IsArchived:
      push  de
            call  _PopRealO1        ;clean up FPS
      pop   hl
;Is archived. Now find start of actual data.
      ld    de,9
      add   hl,de
      ld    e,(hl)
      add   hl,de
;Offset is composed of: namesize, filesize, header, and dist_to_hook
;Also jump past standalone header
      ld    de,1+2+2+(LocalHookStart-ProgramStart)
      add   hl,de
      call  _SetLocalizeHook
      ld    hl,pgm_StrInstalled
      jr    pgm_DisplayResults
pgm_Uninstall:
      call  _ClrLocalizeHook
      ld    hl,pgm_StrUninstalled
pgm_DisplayResults:
      push  hl
            call  _ClrLCDFull
            call  _HomeUp
      pop   hl
      jp    _PutS
pgm_StrInstalled:
.db "Font installed.",0
pgm_StrUninstalled:
.db "Font uninstalled.",0

;Hook data would be appended here.
pgm_hookstart:



