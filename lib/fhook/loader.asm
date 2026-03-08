;Main program stub:
;Contains offset to hook at a predictable location for use in font previewing.
;Installs or uninstalls hook depending on if one is already installed
;Install: Archives itself, then installs using hook location in archive
;Uninstall: Clears hook
;-------------------------------------------------------------------------------
      bit   fontHookActive,(iy+hookflags3)
      jr    nz,fh_pgm_Uninstall
fh_ProgramMainLoop:
      call  _PushRealO1
      call  _ChkFindSym
      call  _ChkInRam
      jr    nz,fh_pgm_IsArchived
      call  _Arc_Unarc
      call  _PopRealO1
      jr    fh_ProgramMainLoop
fh_pgm_IsArchived:
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
      ld    de,1+2+2+(FontHookStart-fh_ProgramStart)
      add   hl,de
      call  _SetFontHook
      ld    hl,fh_pgm_StrInstalled
      jr    fh_pgm_DisplayResults
fh_pgm_Uninstall:
      call  _ClrFontHook
      ld    hl,fh_pgm_StrUninstalled
fh_pgm_DisplayResults:
      push  hl
            call  _ClrLCDFull
            call  _HomeUp
      pop   hl
      jp    _PutS
fh_pgm_StrInstalled:
.db "Font installed.",0
fh_pgm_StrUninstalled:
.db "Font uninstalled.",0

;Hook data would be appended here.
fh_pgm_hookstart:



