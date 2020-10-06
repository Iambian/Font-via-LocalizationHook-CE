/*
 *--------------------------------------
 * Program Name: Font Pack Previewer
 * Author: hehe
 * License: do whatever
 * Description: A font pack previewer
 *--------------------------------------
*/

/* Keep these headers */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <tice.h>

/* Standard headers (recommended) */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* External library headers */
#include <debug.h>
#include <keypadc.h>
#include <graphx.h>
#include <fileioc.h>
#include <compression.h>

/* Put your function prototypes here */


void		DrawLFontExample( void *data );	/*Externally defined */
void		DrawSFontExample( void *data );	/*Externally defined */

uint8_t 	InitVarSearch( uint8_t vartype);
uint8_t 	VarSearchNext(void);
uint8_t 	VarSearchPrev(void);
void*		GetFontStruct(void);
kb_key_t 	GetKbd(void);
void		PrintOp1(void);
void		PrintOp4(void);
kb_key_t	GetKbd(void);


/*	Controls:
	Left/right changes vartype between progs, appvars, groups 
	Up/Down Cycles through programs, but only if there's something to view
 
 */

/* Put all your globals here */

void main(void) {
	uint8_t i;
	uint8_t vartype;
	uint8_t topfile_result;
	uint8_t groupfile_result;
	uint8_t dosmallfont;
	kb_key_t k;
	void *ptr;
      void *tempptr;
	
	gfx_Begin();
	
	gfx_SetDrawBuffer();
	
	dosmallfont = 1;
	vartype = 0x06;		/* Start with protprogs*/
	topfile_result = InitVarSearch(vartype);
	groupfile_result = 0xFF;
	
	k = kb_Yequ;	/* Key used to toggle lFont/sFont. Here, just priming screen */
	while (k!=kb_Mode) {
		if (k) {
			/* Perform keyboard checking here */
			if (k&kb_Yequ)    dosmallfont = !dosmallfont;
                  if (k&kb_Left)    VarSearchPrev();
                  if (k&kb_Right)   VarSearchNext();
			
			
			/* Perform lookup and graphics logic here */
			gfx_FillScreen(0xDF);
                  gfx_PrintStringXY("Font Previewing Program",80,4);
                  gfx_HorizLine(0,14,320);
			gfx_PrintStringXY("Locating filetype: PROTPRGM ",16,18);
			gfx_SetTextXY(24,28);
			if (topfile_result) {
				gfx_PrintString("*** NO FONTS FOUND ***");
			} else {
				PrintOp1();
				ptr = GetFontStruct();
				if (ptr) {
					if (dosmallfont) {
						DrawSFontExample(ptr);
					} else {
						DrawLFontExample(ptr);
					}
				}
			}
			gfx_SwapDraw();
		}
		k = GetKbd();
	}
	gfx_End();
}

/* Put other functions here */

