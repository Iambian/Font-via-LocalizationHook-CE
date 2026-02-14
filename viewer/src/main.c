/*
 *--------------------------------------
 * Program Name: Font Pack Previewer
 * Author: Iambian
 * License: MIT License
 * Description: A font pack previewer
 *--------------------------------------
*/

// Instructions image:
// "L/R: CHNGFONT | U/D: CHNGTYPE | DEL: (UN)INSTALL | MODE: EXIT | Y=: CHNGSIZE | 2ND: CHNGTXT"
/* Controls:
	Left/Right: Change font
	Up/Down: Change variable type (Program/Appvar/ProgramsInGroup/AppvarsInGroup)
	Delete: Install/Uninstall font pack
	2ND: Change text to display (ABC/Test Sentences)
	Y=: Change font size (Large/Small)
	Mode: Exit
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

/* Add any other headers here */
#include "extern.h"


/* Put your function prototypes here */
void drawBuffer(void);
void updateState(void);
kb_key_t keyRead(void);
void printName(uint8_t *nameptr);
void drawTestArea(void);
void printStr(uint8_t *strptr, int x, int y);
uint8_t printChr(uint8_t c, int x, int y);


/* Put all your globals here */

#define LEN(x) (sizeof(x)/sizeof(x[0]))
#define SCREEN_TOP 4
#define LINE_HEIGHT 10
#define STATUS_COLSTART 8
#define DETAILS_COLSTART 128
#define BANNER_BOTTOM (SCREEN_TOP + (4*LINE_HEIGHT) + 3)

#define COLOR_BACKGROUND 0xBE
#define COLOR_TEXT 0x00
#define COLOR_GREENTEXT 0x26
#define COLOR_REDTEXT 0xE0

state_t appstate = {
	.installed = false,
	.vartypeidx = 0,
	.fonttype = 0,
	.textdisptype = true,
	.varindex = 0,
	.maxvars = 0
};

fontvar_t fontvars;

uint8_t filetypes[] = { 0x06, 0x15, 0x17, 0x17};
uint8_t varindexbyfiletype[4];

/* -------------------------------------------------------------------------- */
int main(void) {

	kb_key_t k=0;
	bool statechanged;
	//uint8_t vartype;

	gfx_Begin();
	
	gfx_SetDrawBuffer();
	
	// Initial gather of files to populate the font count and other details
	// before initial draw, then configure variables to force that draw.
	gatherFiles(appstate.vartypeidx, &fontvars);
	updateState();
	statechanged = true;
	k = kb_2nd;

	do {
		if (k) {
			/* Perform keyboard checking here */
			if (k & kb_2nd) {
				appstate.textdisptype = !appstate.textdisptype;
				statechanged = true;
			}

			if (k & (kb_Left | kb_Right | kb_Up | kb_Down)) {
				// If changing variable, save current index for this variable type before changing
				varindexbyfiletype[appstate.vartypeidx] = appstate.varindex;
			}

			if (k & kb_Up) {
				if (appstate.vartypeidx > 0) {
					appstate.vartypeidx--;
					//vartype = filetypes[appstate.vartypeidx];
					gatherFiles(appstate.vartypeidx, &fontvars);
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Down) {
				if (appstate.vartypeidx < (LEN(filetypes)-1)) {
					appstate.vartypeidx++;
					//vartype = filetypes[appstate.vartypeidx];
					gatherFiles(appstate.vartypeidx, &fontvars);
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Left) {
				if (appstate.varindex > 0) {
					varindexbyfiletype[appstate.vartypeidx]--;
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Right) {
				if (appstate.varindex < (appstate.maxvars-1)) {
					varindexbyfiletype[appstate.vartypeidx]++;
					updateState();
					statechanged = true;
				}
			}

			if (k & kb_Yequ) {
				appstate.fonttype = !appstate.fonttype;
				statechanged = true;
			}

			if (k & kb_Del) {
				if (appstate.installed) {
					uninstallHook2();
					appstate.installed = false;
				} else {
					installHook2((uint8_t*)fontvars.vardata[appstate.varindex]);
					appstate.installed = true;
				}
				statechanged = true;
			}

			/* Draw screen if state changed */
			if (statechanged) {
				drawBuffer();
				gfx_SwapDraw();
				statechanged = false;
			}
			// Should read "keyWait" but I didn't want to add another function.
			while (keyRead());
		}
		k = keyRead();
	} while (k!=kb_Mode);
	gfx_End();
}

/* Put other functions here */

void drawBuffer(void) {
	uint8_t oldcolor;
	uint8_t i;
	// Clear screen and draw border line between status and render area
	gfx_FillScreen(COLOR_BACKGROUND);
	gfx_SetColor(COLOR_TEXT);
	gfx_HorizLine(0, SCREEN_TOP + (4*LINE_HEIGHT), 320);

	// Draw title and status box
	gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (0*LINE_HEIGHT));
	gfx_PrintString("* Font  Viewer *");

	gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (2*LINE_HEIGHT));
	if (appstate.fonttype == 0) {
		gfx_PrintString("LRG FONT");
	} else {
		gfx_PrintString("SML FONT");
	}
	gfx_SetTextXY(STATUS_COLSTART + 72,SCREEN_TOP + (2*LINE_HEIGHT));
	if (appstate.textdisptype) {
		gfx_PrintString("SNTNC");
	} else {
		gfx_PrintString("ALPHA");
	}

	// Draw variable details area
	gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (1*LINE_HEIGHT));
	switch (appstate.vartypeidx) {
		case 0:
			gfx_PrintString("PRGM");
			break;
		case 1:
			gfx_PrintString("AVAR");
			break;
		case 2:
			gfx_PrintString("GRPP");
			break;
		case 3:
			gfx_PrintString("GRPV");
			break;
	}
	gfx_PrintString(": ");
	if (appstate.maxvars > 0) {
		i = appstate.varindex;
		if (appstate.vartypeidx & 2) {	//Group variable, print group name first
			printName((uint8_t*)fontvars.groupname[i]);
			gfx_PrintString(" :: ");
		}
		printName((uint8_t*)fontvars.varname[i]);

		// TODO: Print variable name here, once implemented
		gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (2*LINE_HEIGHT));
		// NOTE: Debug printing here.
		gfx_PrintString("Var data ptr: ");
		gfx_PrintUInt((uintptr_t)fontvars.vardata[appstate.varindex], 8);
		// NOTE: Slight out of order rendering to prevent a font count with no
		// fonts available while reusing the same splitting logic.
		gfx_SetTextXY(DETAILS_COLSTART, SCREEN_TOP + (0*LINE_HEIGHT));
		gfx_PrintString("Fonts found: ");
		gfx_PrintUInt(appstate.varindex+1, 3);
		gfx_PrintChar('/');
		gfx_PrintUInt(appstate.maxvars, 3);
		gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (1*LINE_HEIGHT));
		if (appstate.installed) {
			oldcolor = gfx_SetTextFGColor(COLOR_GREENTEXT);
			gfx_PrintString("INSTALLED");
		} else {
			oldcolor = gfx_SetTextFGColor(COLOR_REDTEXT);
			gfx_PrintString("NOT  INSTALLED");
		}
	} else {
		gfx_PrintString("** No fonts found **");
		gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (1*LINE_HEIGHT));
		oldcolor = gfx_SetTextFGColor(COLOR_REDTEXT);
		gfx_PrintString("NOT  FOUND");
	}
	gfx_SetTextFGColor(oldcolor);
	gfx_SetTextXY(2,SCREEN_TOP + (3*LINE_HEIGHT));
	gfx_PrintString("\x12:Fnt  \x1D:Type  Y=:Siz  2nd:Tst  DEL:inst  MODE:Quit");
	//gfx_SetTextXY(STATUS_COLSTART,SCREEN_TOP + (4*LINE_HEIGHT));
	//gfx_PrintString("[Y=]L/S size    [2ND]Text test type    [MODE]Exit");

	// Draw font rendering test area
	drawTestArea();
}

kb_key_t keyRead(void) {
	kb_key_t k;
	kb_Scan();
	k = kb_Data[7] | kb_Data[1];	//Merge groups: dpad & 2nd/mode/del/yequ
	return k;
}

void updateState(void) {
	// Updates state in response to change in variable type or index.
	appstate.varindex = varindexbyfiletype[appstate.vartypeidx];
	appstate.maxvars = fontvars.varcount;
	appstate.installed = isInstalled((uint8_t*)fontvars.vardata[appstate.varindex]);
}

void printName(uint8_t *nameptr) {
	uint8_t *s = nameptr;
	uint8_t nlen = *s;
	while (nlen) {
		s++;
		gfx_PrintChar(*s);
		nlen--;
	}
}



#define TEST_COLSTART 0
#define SENTENCE_COLSTART 8

// Test area text has to start at y=BANNER_BOTTOM
#define LFONT_LINEHEIGHT 16
// Large font: max 22 chars per line. We need at least 12 lines.
#define SFONT_LINEHEIGHT 14
// Small font: limit 20 chars per line. We need 13 lines.


void drawTestArea(void) {
	int y;

	y = BANNER_BOTTOM;
	if (appstate.textdisptype) {
		// Render sentences (e.g. "The quick brown fox jumps over the lazy dog.")
		if (appstate.fonttype == 0) {
			// Large font: max 22 chars per line. We need at least 12 lines.
			printStr((uint8_t*)"the quick brown fox", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"jumps over the lazy", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"dog.", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"THE QUICK BROWN FOX", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"JUMPS OVER THE LAZY", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"DOG.", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"sphinx of black", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"quartz, judge", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"my vow.", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"SPHINX OF BLACK", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"QUARTZ, JUDGE", SENTENCE_COLSTART, y);
			y += LFONT_LINEHEIGHT;
			printStr((uint8_t*)"MY VOW.", SENTENCE_COLSTART, y);

		} else {
			// Small font: limit 20 chars per line. We need 13 lines.
			printStr((uint8_t*)"the quick brown", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"fox jumps over", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"the lazy dog.", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"THE QUICK BROWN", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"FOX JUMPS OVER", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"THE LAZY DOG.", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"sphinx of black", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"quartz, judge", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"my vow.", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"SPHINX OF BLACK", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"QUARTZ, JUDGE", SENTENCE_COLSTART, y);
			y += SFONT_LINEHEIGHT;
			printStr((uint8_t*)"MY VOW.", SENTENCE_COLSTART, y);
		}
	} else {
		// Render ASCII characters in order (e.g. " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")
		if (appstate.fonttype == 0) {
			// Large font: max 22 chars per line. We need at least 12 lines.
			// Programmatically display characters 0x00 to 0xF9
			uint8_t c,i,j;
			y = BANNER_BOTTOM;
			for (i=0,c=0; i<12; i++) {
				for (j=0; j<22 && c<=0xF9; j++,c++) {
					printChr(c, TEST_COLSTART + (j*14), y);
				}
				y += LFONT_LINEHEIGHT;
			}
		} else {
			// Small font: limit 20 chars per line. We need 13 lines.
			// Programmatically display characters 0x00 to 0xF9
			uint8_t c,i,j;
			y = BANNER_BOTTOM;
			for (i=0,c=0; i<13; i++) {
				for (j=0; j<20 && c<=0xF9; j++,c++) {
					printChr(c, TEST_COLSTART + (j*16), y);
				}
				y += SFONT_LINEHEIGHT;
			}
		}
	}
}


void printStr(uint8_t *strptr, int x, int y) {
	uint8_t chrwidth;
	uint8_t c;
	while ((c = *strptr)) {
		strptr++;
		chrwidth = drawGlyph((uint8_t*)fontvars.vardata[appstate.varindex], appstate.fonttype, c, x, y);
		x += chrwidth;
	}
}

uint8_t printChr(uint8_t c, int x, int y) {
	return drawGlyph((uint8_t*)fontvars.vardata[appstate.varindex], appstate.fonttype, c, x, y);
}