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
	bool installed;		//Whether the hook is currently installed. Should be true if any fonts are found, but this is technically separate.
	uint8_t vartypeidx;	//Index into filetypes array for the current variable type. Should be 0-3, but no bounds checking is done.
	uint8_t fonttype;	//0 for large, 1 for small. Could be extended if more font types are added, but that seems unlikely.
	bool textdisptype;	//0 for normal text display, 1 for sentence case. Could be extended if more display types are added, but that also seems unlikely.
	uint8_t varindex;	//Index into the current variable type's variables for the currently selected variable. Should be 0-(varcount-1), but no bounds checking is done.
	uint8_t maxvars;	//Number of variables found for the current variable type. Should be <=255 due to varcount being a uint8_t, but no bounds checking is done. If 0, varindex is invalid and should not be used to index into fontvars.
} state_t;

/* New functions here */
extern void gatherFiles(uint8_t vartypeidx, fontvar_t *fontvars);
extern bool isInstalled(uint8_t *startOfVarData);
extern void installHook2(uint8_t *startOfVarData);
extern void uninstallHook2(void);
extern uint8_t drawGlyph(uint8_t *fontDataStart, uint8_t fontType, uint8_t glyphIndex, int16_t x, int16_t y);

extern const uint8_t fontpackHeader[];

