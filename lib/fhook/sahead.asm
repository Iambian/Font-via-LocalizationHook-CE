.assume adl=1
;Header for the standalone implementation of the hook.
;This provides something for the font previewer to latch onto
;when searching the filesystem for fonts to preview/load

#include "ti84pce.inc"
#ifdef USING_LOADER
.org userMem-2
#endif
.db tExtTok,tAsm84CeCmp
fh_ProgramStart:
	jr	fh_ProgramContinue
.db "LFNPK",0
.dl fh_DataStub-$		;distance to the data section from this location
.dl FontHookStart-$		;distance to the hook section from this location
fh_ProgramContinue:
#ifndef USING_LOADER
.db $C9
#endif
