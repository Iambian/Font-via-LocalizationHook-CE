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
	
	gfx_Begin();
	
	gfx_SetDrawBuffer();
	
	dosmallfont = 0;
	vartype = 0x06;		/* Start with protprogs*/
	topfile_result = InitVarSearch(vartype);
	groupfile_result = 0xFF;
	
	k = kb_Yequ;	/* Unused key. Used to pump contents to screen */
	while (k!=kb_Mode) {
		if (k) {
			/* Perform keyboard checking here */
			
			
			
			/* Perform lookup and graphics logic here */
			gfx_FillScreen(0xDF);
			gfx_PrintStringXY("FIND PROGRAM TYPE",16,4);
			gfx_SetTextXY(24,14);
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

