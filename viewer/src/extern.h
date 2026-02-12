#include <stdint.h>
extern void		DrawLFontExample( void *data );	/*Externally defined */
extern void		DrawSFontExample( void *data );	/*Externally defined */

extern void 	fn_Setup_Palette(void);
extern uint8_t 	InitVarSearch( uint8_t vartype);
extern uint8_t 	VarSearchNext(void);
extern uint8_t 	VarSearchPrev(void);
extern void*	GetFontStruct(void);
extern kb_key_t GetKbd(void);
extern void		PrintOp1(void);
extern void		PrintOp4(void);
extern kb_key_t	GetKbd(void);
extern void		InstallHook(void);
extern uint8_t	UninstallHook(void);