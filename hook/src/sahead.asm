.assume adl=1
;Header for the standalone implementation of the hook.
;This provides something for the font previewer to latch onto
;when searching the filesystem for fonts to preview/load

#include "../include/ti84pce.inc"
#ifdef USING_LOADER
.org userMem-2
#endif
.db tExtTok,tAsm84CeCmp
ProgramStart:
	jr	ProgramContinue
.db "FNTPK",0
.dl lh_DataStub-$		;distance to the data section from this location
.dl LocalHookStart-$	;distance to the hook section from this location
ProgramContinue:
#ifndef USING_LOADER
.db $C9
#endif
