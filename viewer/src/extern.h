#include <stdint.h>

//Always declare an instance of this in global. 
//The stack will not hold this without crashing.
typedef struct {
    uint8_t varcount;
    intptr_t groupname[255];
    intptr_t varname[255];
    intptr_t vardata[255];
} fontvar_t;

typedef struct {
	bool installed;
	uint8_t vartypeidx;
	uint8_t fonttype;
	bool textdisptype;
	uint8_t varindex;
	uint8_t maxvars;
} state_t;

extern void		DrawLFontExample( void *data );	/*Externally defined */
extern void		DrawSFontExample( void *data );	/*Externally defined */

/* Deprecate these functions */
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

/* New functions here */
extern void gatherFiles(uint8_t vartypeidx, fontvar_t *fontvars);

