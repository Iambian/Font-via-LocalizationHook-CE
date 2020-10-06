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
void *groupmain[257];
void *grouptemp[257];
unsigned int groupcurvar;
const uint8_t typelist[] = {0x06,0x15,0x17};
const char *typenames[] = {"PROTPROG","APPVAR","GROUP"};
const char controlchars[] = {18,29,30,31,0};
const char updown[] = {18,32,32,0};
const char leftright[] = {29,32,0};


void main(void) {
	uint8_t i;
	uint8_t vartype;
	uint8_t topfile_result;
	uint8_t groupfile_result;
	uint8_t dosmallfont;
	uint8_t typeindex;
	kb_key_t k;
	void *ptr;
      void *tempptr;
	
	gfx_Begin();
	
	gfx_SetDrawBuffer();
	
	dosmallfont = 1;
	vartype = 0x06;
	topfile_result = InitVarSearch(vartype);
	groupfile_result = 0xFF;
	typeindex = 0;
	
	k = kb_Yequ;	/* Key used to toggle lFont/sFont. Here, just priming screen */
	while (k!=kb_Mode) {
		if (k) {
			/* Perform keyboard checking here */
			if (k&kb_Yequ)		dosmallfont = !dosmallfont;
			if (k&kb_Left)		VarSearchPrev();
			if (k&kb_Right)		VarSearchNext();
			if (k&kb_Up && typeindex>0)		--typeindex;
			if (k&kb_Down && typeindex<2)	++typeindex;
			if (k&(kb_Up|kb_Down)) {
				vartype = typelist[typeindex];
				topfile_result = InitVarSearch(vartype);
			}
			
			/* Perform lookup and graphics logic here */
			gfx_FillScreen(0xDF);
			gfx_PrintStringXY("Font Previewing Program",80,4);
			gfx_HorizLine(0,14,320);
			gfx_PrintStringXY(updown,16,18);
			gfx_PrintString("Locating filetype: ");
			gfx_PrintString(typenames[typeindex]);
			gfx_SetTextXY(28,30);
			if (topfile_result) {
				gfx_PrintString("*** NO FONTS FOUND ***");
			} else {
				gfx_PrintString(leftright);
				PrintOp1();
				if (vartype==0x17) {
					gfx_PrintString(" :: ");
					PrintOp4();
				}
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

